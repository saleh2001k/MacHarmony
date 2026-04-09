//
//  ServicesEmptyFolderScanner.swift
//  MacHarmony
//

import Foundation

actor EmptyFolderScanner {

    private let skipNames: Set<String> = [
        "Library", ".Trash", ".local", "Applications", "System", "private",
        "Network", "Volumes", ".git", "node_modules", ".cache"
    ]

    func scan(rootPath: String) async -> [StorageItem] {
        var result: [StorageItem] = []
        let root = URL(fileURLWithPath: rootPath)
        await collectEmptyFolders(in: root, depth: 0, result: &result)
        return result.sorted { $0.path < $1.path }
    }

    private func collectEmptyFolders(in url: URL, depth: Int, result: inout [StorageItem]) async {
        guard depth < 10 else { return }

        let fm = FileManager.default
        let name = url.lastPathComponent

        // Skip system and hidden dirs
        guard !name.hasPrefix(".") || depth == 0 else { return }
        guard !skipNames.contains(name) || depth == 0 else { return }

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: []
        ) else { return }

        // Check if this dir is a package (app bundle etc.) — skip descending into it
        if let rv = try? url.resourceValues(forKeys: [.isPackageKey]), rv.isPackage == true, depth > 0 {
            return
        }

        let visibleItems = contents.filter { !$0.lastPathComponent.hasPrefix(".") }

        if visibleItems.isEmpty {
            // Effectively empty folder
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            let modDate = attrs?[.modificationDate] as? Date ?? Date()
            result.append(StorageItem(name: name, path: url.path, size: 0, modifiedDate: modDate))
        } else {
            // Recurse into subdirectories
            for item in visibleItems {
                if let rv = try? item.resourceValues(forKeys: [.isDirectoryKey]), rv.isDirectory == true {
                    await collectEmptyFolders(in: item, depth: depth + 1, result: &result)
                }
            }
        }
    }
}
