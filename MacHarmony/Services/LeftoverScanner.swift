//
//  ServicesLeftoverScanner.swift
//  MacHarmony
//

import Foundation

actor LeftoverScanner {

    private let fm = FileManager.default

    /// Scans ~/Library support dirs for items whose name doesn't match any installed bundle ID.
    func scan(homeDir: String, installedBundleIDs: Set<String>) async -> [StorageItem] {
        let locations: [(String, String)] = [
            ("\(homeDir)/Library/Application Support", "Application Support"),
            ("\(homeDir)/Library/Containers", "Containers"),
            ("\(homeDir)/Library/Caches", "Caches"),
        ]

        // Build lookup sets for fast matching
        let bundleIDSet = installedBundleIDs.map { $0.lowercased() }

        var result: [StorageItem] = []

        for (dirPath, _) in locations {
            guard let contents = try? fm.contentsOfDirectory(atPath: dirPath) else { continue }
            for itemName in contents {
                // Skip hidden items
                guard !itemName.hasPrefix(".") else { continue }

                let lowerName = itemName.lowercased()

                // Only flag bundle-ID-shaped names (contain a dot) — reduces false positives
                let looksLikeBundleID = itemName.contains(".") && !itemName.hasSuffix(".plist")
                guard looksLikeBundleID else { continue }

                // Check if any installed bundle ID matches
                let isOrphaned = !bundleIDSet.contains(where: { installed in
                    installed.contains(lowerName) || lowerName.contains(installed)
                })

                guard isOrphaned else { continue }

                let fullPath = "\(dirPath)/\(itemName)"
                let size = await sizeOfItem(at: fullPath)
                let attrs = try? fm.attributesOfItem(atPath: fullPath)
                let modDate = attrs?[.modificationDate] as? Date ?? Date()
                result.append(StorageItem(name: itemName, path: fullPath, size: size, modifiedDate: modDate))
            }
        }

        return result.sorted { $0.size > $1.size }
    }

    private func sizeOfItem(at path: String) async -> Int64 {
        await Task.detached(priority: .utility) {
            DiskUsage.totalSize(atPath: path)
        }.value
    }
}
