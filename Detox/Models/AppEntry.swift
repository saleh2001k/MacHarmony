//
//  ModelsAppEntry.swift
//  Detox
//

import Foundation

struct AppEntry: Identifiable, Sendable {
    let id: UUID
    let name: String
    let bundleID: String
    let version: String
    let installPath: String
    var bundleSize: Int64
    var supportItems: [StorageItem]

    nonisolated init(name: String, bundleID: String, version: String, installPath: String,
         bundleSize: Int64, supportItems: [StorageItem] = []) {
        self.id = UUID()
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.installPath = installPath
        self.bundleSize = bundleSize
        self.supportItems = supportItems
    }

    nonisolated var totalSize: Int64 {
        bundleSize + supportItems.reduce(0) { $0 + $1.size }
    }

    nonisolated var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    nonisolated var formattedBundleSize: String {
        ByteCountFormatter.string(fromByteCount: bundleSize, countStyle: .file)
    }
}
