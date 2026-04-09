//
//  ServicesResultsCache.swift
//  MacHarmony
//

import Foundation

actor ResultsCache {

    // MARK: - Nested Types

    struct CachedResults: Codable {
        let scannedAt: Date
        let builtinItems: [String: [StorageItem]]   // StorageCategory.rawValue → items
        let customItems: [String: [StorageItem]]    // UUID.uuidString → items
    }

    // MARK: - Properties

    private let fileURL: URL
    private var cached: CachedResults?


    // MARK: - Init

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                  .appendingPathComponent("Library/Application Support", isDirectory: true)
        let dir = appSupport.appendingPathComponent("MacHarmony", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let jsonURL  = dir.appendingPathComponent("results-cache.json")
        let plistURL = dir.appendingPathComponent("results-cache.plist")
        fileURL = jsonURL

        if let data = try? Data(contentsOf: jsonURL),
           let decoded = try? JSONDecoder().decode(CachedResults.self, from: data) {
            cached = decoded
            #if DEBUG
            print("📦 ResultsCache: loaded \(decoded.builtinItems.values.map(\.count).reduce(0,+)) items")
            #endif
        }
        // Remove any stale plist left over from the previous encoder
        try? FileManager.default.removeItem(at: plistURL)
    }

    // MARK: - Public Methods

    /// Returns cached results if they are within the TTL window; nil if stale or missing.
    func load(ttl: TimeInterval = 3600) -> CachedResults? {
        guard let cached else { return nil }
        let age = Date().timeIntervalSince(cached.scannedAt)
        return age < ttl ? cached : nil
    }

    func save(_ results: CachedResults) {
        cached = results
        let url = fileURL
        Task.detached(priority: .background) {
            guard let data = try? JSONEncoder().encode(results) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    func invalidate() {
        cached = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    func getLastScanDate() -> Date? {
        cached?.scannedAt
    }
}
