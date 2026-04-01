//
//  ModelsCustomCategory.swift
//  Detox
//

import Foundation
import SwiftUI

// MARK: - CustomScanCategory

struct CustomScanCategory: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var extensions: [String]   // without dot, e.g. ["svg", "log", "tmp"]
    var searchPaths: [String]  // absolute paths to scan
    var colorHex: String       // e.g. "#5E8FFF"
    var icon: String           // SF Symbol name
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        extensions: [String],
        searchPaths: [String],
        colorHex: String = "#5E8FFF",
        icon: String = "doc.badge.plus"
    ) {
        self.id = id
        self.name = name
        self.extensions = extensions
        self.searchPaths = searchPaths
        self.colorHex = colorHex
        self.icon = icon
        self.createdAt = Date()
    }

    var color: Color {
        Color(hexString: colorHex) ?? .blue
    }

    static let presetColors: [String] = [
        "#5E8FFF", "#A855F7", "#22C55E", "#EF4444",
        "#F97316", "#EAB308", "#14B8A6", "#EC4899"
    ]

    static let presetIcons: [String] = [
        "doc.badge.plus", "folder.badge.plus", "doc.fill",
        "photo.fill", "film.fill", "music.note",
        "archivebox.fill", "cube.fill", "gearshape.fill",
        "textformat", "paintbrush.fill", "camera.fill"
    ]
}

// MARK: - Color Hex Extension

extension Color {
    init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex = String(hex.dropFirst()) }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8)  & 0xFF) / 255,
            blue:  Double(value         & 0xFF) / 255
        )
    }
}
