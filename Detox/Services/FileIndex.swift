//
//  ServicesFileIndex.swift
//  Detox
//

import Foundation

/// In-memory flat index of every file under the user's home directory.
/// Built once per scan (one parallel FTS traversal); all deepFiles/deepLargeFiles
/// categories then filter this index in O(n) instead of re-traversing the disk.
actor FileIndex: Sendable {

    struct Entry: Sendable {
        let path: String
        let name: String
        let ext: String       // lowercased, no dot
        let size: Int64
        let modifiedDate: Date
    }

    private(set) var entries: [Entry] = []
    private(set) var isReady = false
    private(set) var indexedRoots: [String] = []

    private static let skipTopLevel: Set<String> = [
        "Library", ".Trash", "Trash", "System", "private"
    ]

    // MARK: - Build

    /// Traverses rootPath in parallel sub-tasks, populating `entries`.
    func build(
        rootPath: String,
        engine: FastScanEngine,
        onProgress: (@Sendable (Int, String) -> Void)? = nil
    ) async {
        let fm = FileManager.default
        var scanRoots: [String] = [rootPath]

        if let children = try? fm.contentsOfDirectory(atPath: rootPath), children.count > 5 {
            let subs = children
                .filter { !Self.skipTopLevel.contains($0) && !$0.hasPrefix(".") }
                .map { "\(rootPath)/\($0)" }
                .filter { p -> Bool in
                    var d: ObjCBool = false
                    return fm.fileExists(atPath: p, isDirectory: &d) && d.boolValue
                }
            if !subs.isEmpty { scanRoots = subs }
        }

        var allEntries: [Entry] = []

        await withTaskGroup(of: [Entry].self) { group in
            for root in scanRoots {
                let r = root
                group.addTask {
                    var sub: [Entry] = []
                    var localCount = 0
                    for await discovered in engine.scanFilesDeep(root: r) {
                        let p = discovered.path
                        let ext = (p as NSString).pathExtension.lowercased()
                        sub.append(Entry(
                            path: p,
                            name: (p as NSString).lastPathComponent,
                            ext: ext,
                            size: discovered.fileSize,
                            modifiedDate: discovered.modifiedDate
                        ))
                        localCount += 1
                        if localCount % 1000 == 0 { onProgress?(localCount, p) }
                    }
                    return sub
                }
            }
            for await sub in group {
                allEntries.append(contentsOf: sub)
                onProgress?(allEntries.count, "")
            }
        }

        entries = allEntries
        indexedRoots = scanRoots
        isReady = true
        #if DEBUG
        print("📇 FileIndex: indexed \(entries.count) files")
        #endif
    }

    // MARK: - Coverage Check

    /// Returns true if the given path falls within the indexed roots.
    func covers(_ path: String) -> Bool {
        indexedRoots.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    // MARK: - Filter

    func filter(extensions: Set<String>, withinPaths paths: [String]? = nil, ignoredNames: Set<String> = []) -> [StorageItem] {
        entries
            .filter { entry in
                guard extensions.contains(entry.ext) else { return false }
                if entry.ext == "ts" && entry.name.lowercased().hasSuffix(".d.ts") { return false }
                if !ignoredNames.isEmpty {
                    let components = (entry.path as NSString).pathComponents
                    if components.contains(where: { ignoredNames.contains($0) }) { return false }
                }
                guard let paths else { return true }
                return paths.contains { entry.path.hasPrefix($0 + "/") || entry.path == $0 }
            }
            .map { StorageItem(name: $0.name, path: $0.path, size: $0.size, modifiedDate: $0.modifiedDate) }
    }

    func filter(minBytes: Int64, withinPaths paths: [String]? = nil, ignoredNames: Set<String> = []) -> [StorageItem] {
        entries
            .filter { entry in
                guard entry.size >= minBytes else { return false }
                if !ignoredNames.isEmpty {
                    let components = (entry.path as NSString).pathComponents
                    if components.contains(where: { ignoredNames.contains($0) }) { return false }
                }
                guard let paths else { return true }
                return paths.contains { entry.path.hasPrefix($0 + "/") || entry.path == $0 }
            }
            .map { StorageItem(name: $0.name, path: $0.path, size: $0.size, modifiedDate: $0.modifiedDate) }
    }
}
