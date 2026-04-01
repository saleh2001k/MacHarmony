//
//  ServicesFastScanEngine.swift
//  Detox
//
//  Created by saleh on 16/03/2026.
//

import Foundation
import Darwin

// MARK: - DiscoveredEntry

/// An entry found during scanning.
/// - For directories: `fileSize` is 0 — use SizeCalculator (du -sk) for accurate recursive size.
/// - For individual files: `fileSize` is populated from fts_statp.st_size (no subprocess needed).
struct DiscoveredEntry: Sendable {
    let path: String
    let modifiedDate: Date
    let fileSize: Int64   // 0 for directories
}

// MARK: - FastScanEngine

/// POSIX fts_open/fts_read based directory scanner.
///
/// Why fts over FileManager.enumerator:
///   fts is a kernel-level C API that reuses a single directory handle across
///   all traversal, avoiding repeated open/close cycles. It also pre-fills the
///   stat struct (fts_statp) for each entry at no extra cost, eliminating the
///   need for separate lstat() calls per entry.
///
/// Flags used: FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV
///   - FTS_PHYSICAL:  don't follow symlinks (avoids infinite loops)
///   - FTS_NOCHDIR:   don't chdir during traversal (thread-safe)
///   - FTS_XDEV:      stay on the same filesystem (skip network mounts, disk images)
actor FastScanEngine {

    private static let ftsFlags: Int32 = FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV

    // MARK: - Public API

    /// Deep scan: traverses `roots` recursively, yielding every directory whose
    /// leaf name is in `targetNames`. Matched directories are pruned (not recursed into).
    ///
    /// Concurrency: up to 6 roots are scanned in parallel to maximize throughput
    /// without thrashing the disk scheduler.
    nonisolated func scan(roots: [String], targetNames: Set<String>) -> AsyncStream<DiscoveredEntry> {
        return AsyncStream { continuation in
            Task {
                // nonisolated workers run concurrently on the cooperative pool — cap at 6 batches
                // to avoid spawning hundreds of fts sessions on very large root lists.
                let batches = roots.chunked(into: 6)
                for batch in batches {
                    await withTaskGroup(of: Void.self) { group in
                        for root in batch {
                            let r = root
                            group.addTask {
                                Self.runDeepFTS(
                                    root: r, targetNames: targetNames, continuation: continuation
                                )
                            }
                        }
                    }
                }
                continuation.finish()
            }
        }
    }

    /// Shallow scan: yields all immediate child directories of `root`.
    /// Does not recurse. Used for cache/archive directories where each child is one item.
    nonisolated func scanTopLevel(root: String) -> AsyncStream<DiscoveredEntry> {
        return AsyncStream { continuation in
            Task {
                Self.runTopLevelFTS(root: root, continuation: continuation)
                continuation.finish()
            }
        }
    }

    /// Shallow scan: yields all immediate children (files AND directories) of `root`.
    /// Used for the Downloads category where both files and folders are items to manage.
    nonisolated func scanTopLevelAll(root: String) -> AsyncStream<DiscoveredEntry> {
        return AsyncStream { continuation in
            Task {
                Self.runTopLevelAllFTS(root: root, continuation: continuation)
                continuation.finish()
            }
        }
    }

    /// Deep file scan: traverses `root` recursively, yielding every regular file.
    /// File sizes are read from the fts stat struct — no du subprocess needed.
    nonisolated func scanFilesDeep(root: String) -> AsyncStream<DiscoveredEntry> {
        return AsyncStream { continuation in
            Task {
                Self.runFilesDeepFTS(root: root, continuation: continuation)
                continuation.finish()
            }
        }
    }

    // MARK: - Private: Deep FTS (recursive, name-matched, pruning)

    /// nonisolated: no actor state accessed — runs concurrently on cooperative pool.
    private nonisolated static func runDeepFTS(
        root: String,
        targetNames: Set<String>,
        continuation: AsyncStream<DiscoveredEntry>.Continuation
    ) {
        let cPath = strdup(root)
        defer { free(cPath) }
        var paths: [UnsafeMutablePointer<CChar>?] = [cPath, nil]

        guard let fts = Darwin.fts_open(&paths, Self.ftsFlags, nil) else { return }
        defer { Darwin.fts_close(fts) }

        while let ent = Darwin.fts_read(fts) {
            // Only process directory entries in pre-order (FTS_D)
            guard ent.pointee.fts_info == FTS_D else { continue }

            // Copy path NOW — fts_path pointer is only valid until the next fts_read()
            let path = String(cString: ent.pointee.fts_path)
            // Derive name from path to avoid fts_name flexible-array deprecation in Swift 6
            let name = (path as NSString).lastPathComponent

            if targetNames.contains(name) {
                let mtime = Date(
                    timeIntervalSince1970: Double(ent.pointee.fts_statp.pointee.st_mtimespec.tv_sec)
                )
                continuation.yield(DiscoveredEntry(path: path, modifiedDate: mtime, fileSize: 0))
                // Skip recursing into this directory — it's already our target
                Darwin.fts_set(fts, ent, FTS_SKIP)
            }
        }
    }

    // MARK: - Private: Top-Level FTS (shallow, directories only)

    /// nonisolated: no actor state accessed — runs concurrently on cooperative pool.
    private nonisolated static func runTopLevelFTS(
        root: String,
        continuation: AsyncStream<DiscoveredEntry>.Continuation
    ) {
        let cPath = strdup(root)
        defer { free(cPath) }
        var paths: [UnsafeMutablePointer<CChar>?] = [cPath, nil]

        guard let fts = Darwin.fts_open(&paths, Self.ftsFlags, nil) else { return }
        defer { Darwin.fts_close(fts) }

        // fts_level is Int16 (FTS_LEVEL_T on macOS)
        var depth: Int16 = -1

        while let ent = Darwin.fts_read(fts) {
            let info = ent.pointee.fts_info
            let level = ent.pointee.fts_level

            // Record the root's level on first FTS_D entry
            if info == FTS_D && depth == -1 {
                depth = level
                continue  // skip the root itself
            }

            // We only want direct children (one level below root) that are directories
            if info == FTS_D && level == depth &+ 1 {
                let path = String(cString: ent.pointee.fts_path)
                let mtime = Date(
                    timeIntervalSince1970: Double(ent.pointee.fts_statp.pointee.st_mtimespec.tv_sec)
                )
                continuation.yield(DiscoveredEntry(path: path, modifiedDate: mtime, fileSize: 0))
                // Skip recursing into this child — we only want one level
                Darwin.fts_set(fts, ent, FTS_SKIP)
            }
        }
    }

    // MARK: - Private: Top-Level FTS (shallow, files + dirs)

    /// Yields all immediate children — both files (FTS_F) and directories (FTS_D) — at depth+1.
    private nonisolated static func runTopLevelAllFTS(
        root: String,
        continuation: AsyncStream<DiscoveredEntry>.Continuation
    ) {
        let cPath = strdup(root)
        defer { free(cPath) }
        var paths: [UnsafeMutablePointer<CChar>?] = [cPath, nil]

        guard let fts = Darwin.fts_open(&paths, Self.ftsFlags, nil) else { return }
        defer { Darwin.fts_close(fts) }

        var depth: Int16 = -1

        while let ent = Darwin.fts_read(fts) {
            let info = ent.pointee.fts_info
            let level = ent.pointee.fts_level

            // Record root's level on first FTS_D entry
            if info == FTS_D && depth == -1 {
                depth = level
                continue
            }

            // Yield both files and directories at exactly one level below root
            if level == depth &+ 1 && (info == FTS_D || info == FTS_F) {
                let path = String(cString: ent.pointee.fts_path)
                let mtime = Date(
                    timeIntervalSince1970: Double(ent.pointee.fts_statp.pointee.st_mtimespec.tv_sec)
                )
                let size = info == FTS_F ? Int64(ent.pointee.fts_statp.pointee.st_size) : 0
                continuation.yield(DiscoveredEntry(path: path, modifiedDate: mtime, fileSize: size))
                // Don't recurse into subdirectories — we only want one level
                if info == FTS_D {
                    Darwin.fts_set(fts, ent, FTS_SKIP)
                }
            }
        }
    }

    // MARK: - Private: Deep File FTS (recursive, all regular files)

    /// Traverses all files recursively under `root`, yielding each regular file with its size.
    /// Never skips directories — descends fully. File size comes from st_size (no du subprocess).
    private nonisolated static func runFilesDeepFTS(
        root: String,
        continuation: AsyncStream<DiscoveredEntry>.Continuation
    ) {
        let cPath = strdup(root)
        defer { free(cPath) }
        var paths: [UnsafeMutablePointer<CChar>?] = [cPath, nil]

        guard let fts = Darwin.fts_open(&paths, Self.ftsFlags, nil) else { return }
        defer { Darwin.fts_close(fts) }

        while let ent = Darwin.fts_read(fts) {
            let info = ent.pointee.fts_info

            // Skip hidden directories and app bundles/frameworks —
            // they contain system/app data, not user content like photos or videos.
            if info == FTS_D {
                let path = String(cString: ent.pointee.fts_path)
                let name = (path as NSString).lastPathComponent
                if name.hasPrefix(".") || name.hasSuffix(".app") || name.hasSuffix(".framework")
                    || name.hasSuffix(".bundle") || name.hasSuffix(".plugin") || name.hasSuffix(".kext") {
                    Darwin.fts_set(fts, ent, FTS_SKIP)
                    continue
                }
            }

            guard info == FTS_F else { continue }
            let path = String(cString: ent.pointee.fts_path)
            let mtime = Date(
                timeIntervalSince1970: Double(ent.pointee.fts_statp.pointee.st_mtimespec.tv_sec)
            )
            let size = Int64(ent.pointee.fts_statp.pointee.st_size)
            continuation.yield(DiscoveredEntry(path: path, modifiedDate: mtime, fileSize: size))
        }
    }
}

// MARK: - Array Helper

private extension Array {
    /// Splits the array into sub-arrays of at most `size` elements.
    nonisolated func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
