//
//  ServicesScanCache.swift
//  MacHarmony
//
//  Created by saleh on 16/03/2026.
//

import Foundation
import Darwin

// MARK: - ScanCacheEntry

struct ScanCacheEntry: Codable, Sendable {
    let path: String
    let size: Int64
    let lastModified: Date   // directory mtime at scan time
    let cachedAt: Date       // when this entry was cached
}

// MARK: - ScanCache

/// Thread-safe, JSON-persisted cache for directory sizes.
/// Entries are validated against:
///   1. A 24-hour TTL
///   2. The directory's mtime (via a single stat() call — O(1))
actor ScanCache {

    private var entries: [String: ScanCacheEntry] = [:]
    private let cacheFileURL: URL

    // MARK: - Init

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                  .appendingPathComponent("Library/Application Support", isDirectory: true)
        let dir = appSupport.appendingPathComponent("MacHarmony", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheFileURL = dir.appendingPathComponent("scan-cache.json")

        // Inline load to avoid calling an actor-isolated method from nonisolated init context
        if let data = try? Data(contentsOf: dir.appendingPathComponent("scan-cache.json")),
           let decoded = try? JSONDecoder().decode([String: ScanCacheEntry].self, from: data) {
            entries = decoded
            #if DEBUG
            print("📦 ScanCache: loaded \(decoded.count) entries from disk")
            #endif
        }
    }

    // MARK: - Stats (for logging)

    private(set) var hitCount: Int = 0
    private(set) var missCount: Int = 0

    func resetStats() {
        hitCount = 0
        missCount = 0
    }

    // MARK: - Public API

    /// Returns a valid cache entry for `path`, or nil if missing/stale.
    func getCached(path: String) -> ScanCacheEntry? {
        guard let entry = entries[path] else {
            missCount += 1
            return nil
        }

        // 1. TTL check: expire after 24 hours
        if Date().timeIntervalSince(entry.cachedAt) > 86_400 {
            entries.removeValue(forKey: path)
            missCount += 1
            return nil
        }

        // 2. mtime check: O(1) stat() — no directory traversal
        guard let currentMtime = directoryMtime(at: path),
              abs(currentMtime.timeIntervalSince(entry.lastModified)) < 1.0 else {
            entries.removeValue(forKey: path)
            missCount += 1
            return nil
        }

        hitCount += 1
        return entry
    }

    /// Stores a new cache entry for `path`.
    func cache(path: String, size: Int64, lastModified: Date) {
        entries[path] = ScanCacheEntry(
            path: path,
            size: size,
            lastModified: lastModified,
            cachedAt: Date()
        )
    }

    /// Wipes all entries and persists the empty cache.
    /// Call this after the user deletes items.
    func invalidateAll() {
        let before = entries.count
        entries.removeAll()
        save()
        #if DEBUG
        print("🗑️ ScanCache: cleared \(before) entr\(before == 1 ? "y" : "ies") from disk")
        #endif
    }

    /// Removes cache entries for specific paths only. More efficient than invalidateAll()
    /// when only a small number of items were deleted.
    func evict(paths: [String]) {
        for path in paths { entries.removeValue(forKey: path) }
        save()
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("⚠️ ScanCache: failed to save — \(error)")
            #endif
        }
    }

    // MARK: - Private Helpers

    /// Returns the mtime of `path` using a single stat() syscall. Never reads directory contents.
    private func directoryMtime(at path: String) -> Date? {
        // Create an uninitialized stat struct
        var info = stat()
        // Convert Swift String to C string for the stat() call
        let result = path.withCString { cPath in
            stat(cPath, &info)
        }
        guard result == 0 else { return nil }
        return Date(timeIntervalSince1970: Double(info.st_mtimespec.tv_sec))
    }
}
