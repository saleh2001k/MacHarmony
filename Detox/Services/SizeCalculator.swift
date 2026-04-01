//
//  ServicesSizeCalculator.swift
//  Detox
//
//  Created by saleh on 16/03/2026.
//

import Foundation
import Darwin

// MARK: - SizeCalculator

/// Calculates directory sizes using /usr/bin/du (primary) with an fts-based fallback.
///
/// Why du -sk:
///   `du` is a C-level system utility that reads block counts from the filesystem
///   without stat-ing each individual file — typically 10–20× faster than
///   FileManager.enumerator() for large directories.
actor SizeCalculator {

    // MARK: - Public API

    /// Primary: spawn /usr/bin/du -sk and parse its output.
    /// nonisolated so multiple du processes can run concurrently across categories.
    /// Falls back to manual fts traversal if du fails or is inaccessible.
    nonisolated func calculateSize(at path: String) async -> Int64 {
        // Only trust du -sk when it returns a positive size.
        // Subprocesses don't inherit security-scoped resource access or FDA from
        // the parent app, so du can exit 0 but report 0 blocks for directories
        // the app itself can read fine. Fall back to in-process fts traversal
        // whenever du returns zero or fails.
        if let size = try? await runDu(at: path), size > 0 {
            return size
        }
        return calculateSizeFallback(at: path)
    }

    // MARK: - Private: du subprocess

    private nonisolated func runDu(at path: String) async throws -> Int64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        // -s: summarize (don't recurse output), -k: 1024-byte blocks
        process.arguments = ["-sk", path]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe  // silence permission errors on inaccessible subdirs

        try process.run()
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 || process.terminationStatus == 1,
              let output = String(data: data, encoding: .utf8),
              !output.isEmpty,
              let size = parseDuOutput(output) else {
            throw DuError.parseFailed
        }
        return size
    }

    /// Parses output of `du -sk <path>`.
    /// Format on macOS: "<1024-byte blocks>\t<path>\n"
    private nonisolated func parseDuOutput(_ output: String) -> Int64? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let tab = trimmed.firstIndex(of: "\t") else { return nil }
        let blockStr = String(trimmed[trimmed.startIndex..<tab])
            .trimmingCharacters(in: .whitespaces)
        guard let blocks = Int64(blockStr) else { return nil }
        return blocks * 1024  // du -k reports 1024-byte blocks
    }

    // MARK: - Private: fts fallback

    /// Manual fts traversal that accumulates st_size for each regular file.
    /// nonisolated: accesses no actor state, runs on cooperative pool.
    nonisolated func calculateSizeFallback(at path: String) -> Int64 {
        typealias StatInfo = stat
        var total: Int64 = 0

        let cPath = strdup(path)
        defer { free(cPath) }
        var paths: [UnsafeMutablePointer<CChar>?] = [cPath, nil]

        guard let fts = Darwin.fts_open(
            &paths,
            FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV,
            nil
        ) else { return 0 }
        defer { Darwin.fts_close(fts) }

        while let ent = Darwin.fts_read(fts) {
            guard ent.pointee.fts_info == FTS_F else { continue }
            total += Int64(ent.pointee.fts_statp.pointee.st_size)
        }
        return total
    }

    // MARK: - Errors

    private enum DuError: Error {
        case parseFailed
    }
}
