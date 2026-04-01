//
//  StorageItem.swift
//  Detox
//
//  Created by saleh on 16/03/2026.
//

import Foundation

struct StorageItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let name: String
    let path: String
    let size: Int64
    let modifiedDate: Date

    nonisolated init(name: String, path: String, size: Int64, modifiedDate: Date) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.size = size
        self.modifiedDate = modifiedDate
    }

    nonisolated var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// Static date string — no live timer, safe in large lists.
    nonisolated var formattedDate: String {
        modifiedDate.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
