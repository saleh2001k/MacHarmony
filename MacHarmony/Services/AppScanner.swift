//
//  ServicesAppScanner.swift
//  MacHarmony
//

import Foundation

actor AppScanner {

    private let fm = FileManager.default

    func scanApps(homeDir: String) async -> [AppEntry] {
        let appDirs = ["/Applications", "\(homeDir)/Applications"]
        var entries: [AppEntry] = []

        for dir in appDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for name in contents where name.hasSuffix(".app") {
                let path = "\(dir)/\(name)"
                if let entry = await buildEntry(path: path, homeDir: homeDir) {
                    entries.append(entry)
                }
            }
        }

        return entries.sorted { $0.totalSize > $1.totalSize }
    }

    private func buildEntry(path: String, homeDir: String) async -> AppEntry? {
        let plistPath = "\(path)/Contents/Info.plist"
        guard let plist = NSDictionary(contentsOfFile: plistPath) else { return nil }

        let bundleID = plist["CFBundleIdentifier"] as? String ?? ""
        let version  = plist["CFBundleShortVersionString"] as? String ?? ""
        let name     = (plist["CFBundleDisplayName"] as? String)
                       ?? (plist["CFBundleName"] as? String)
                       ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension

        let bundleSize = await sizeOfItem(at: path)

        // Collect support files
        var supportItems: [StorageItem] = []

        if !bundleID.isEmpty {
            let supportPaths: [(String, String)] = [
                ("\(homeDir)/Library/Application Support/\(bundleID)", "App Support"),
                ("\(homeDir)/Library/Caches/\(bundleID)", "Cache"),
                ("\(homeDir)/Library/Containers/\(bundleID)", "Container"),
                ("\(homeDir)/Library/Preferences/\(bundleID).plist", "Preferences"),
            ]

            for (supportPath, label) in supportPaths {
                guard fm.fileExists(atPath: supportPath) else { continue }
                let size = await sizeOfItem(at: supportPath)
                if size > 0 {
                    let attrs = try? fm.attributesOfItem(atPath: supportPath)
                    let modDate = attrs?[.modificationDate] as? Date ?? Date()
                    supportItems.append(StorageItem(name: label, path: supportPath, size: size, modifiedDate: modDate))
                }
            }
        }

        return AppEntry(name: name, bundleID: bundleID, version: version,
                        installPath: path, bundleSize: bundleSize, supportItems: supportItems)
    }

    private func sizeOfItem(at path: String) async -> Int64 {
        await Task.detached(priority: .utility) {
            DiskUsage.totalSize(atPath: path)
        }.value
    }
}
