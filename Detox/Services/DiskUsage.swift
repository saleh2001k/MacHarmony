//
//  ServicesDiskUsage.swift
//  Detox
//

import Foundation

/// Walks a file tree **without following symbolic links**, summing file sizes.
/// Avoids inflated totals (e.g. Docker.app → VM disk) from symlink traversal.
enum DiskUsage {
    nonisolated static func totalSize(atPath path: String) -> Int64 {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            let attrs = try? fm.attributesOfItem(atPath: path)
            return attrs?[.size] as? Int64 ?? 0
        }

        guard let dirEnum = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [
                .isSymbolicLinkKey,
                .isRegularFileKey,
                .isDirectoryKey,
                .fileSizeKey,
                .totalFileAllocatedSizeKey
            ],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        while let fileURL = dirEnum.nextObject() as? URL {
            let rv = try? fileURL.resourceValues(forKeys: [
                .isSymbolicLinkKey,
                .isRegularFileKey,
                .isDirectoryKey,
                .fileSizeKey,
                .totalFileAllocatedSizeKey
            ])
            if rv?.isSymbolicLink == true {
                dirEnum.skipDescendants()
                continue
            }
            if rv?.isDirectory == true { continue }
            if let alloc = rv?.totalFileAllocatedSize {
                total += Int64(alloc)
            } else if let sz = rv?.fileSize {
                total += Int64(sz)
            }
        }
        return total
    }
}
