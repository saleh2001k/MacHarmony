//
//  ModelsToolType.swift
//  MacHarmony
//

import SwiftUI

enum ToolType: String, CaseIterable, Identifiable {
    case largeFileBrowser
    case oldUnusedFiles
    case appUninstaller
    case appCacheBreakdown
    case leftoverFiles
    case startupItems
    case memoryMonitor
    case diskHealth
    case scanHistory
    case safeMode
    case iCloudCleaner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .largeFileBrowser:   return "Large File Browser"
        case .oldUnusedFiles:     return "Old & Unused Files"
        case .appUninstaller:     return "App Uninstaller"
        case .appCacheBreakdown:  return "App Cache Breakdown"
        case .leftoverFiles:      return "Leftover Files"
        case .startupItems:       return "Startup Items"
        case .memoryMonitor:      return "Memory Monitor"
        case .diskHealth:         return "Disk Health"
        case .scanHistory:        return "Scan History"
        case .safeMode:           return "Safe Mode Queue"
        case .iCloudCleaner:      return "iCloud Cleaner"
        }
    }

    var icon: String {
        switch self {
        case .largeFileBrowser:   return "doc.text.magnifyingglass"
        case .oldUnusedFiles:     return "clock.badge.xmark"
        case .appUninstaller:     return "trash.circle.fill"
        case .appCacheBreakdown:  return "square.stack.3d.up.fill"
        case .leftoverFiles:      return "questionmark.folder.fill"
        case .startupItems:       return "bolt.fill"
        case .memoryMonitor:      return "memorychip.fill"
        case .diskHealth:         return "heart.circle.fill"
        case .scanHistory:        return "chart.line.uptrend.xyaxis"
        case .safeMode:           return "checkmark.circle.fill"
        case .iCloudCleaner:      return "icloud.and.arrow.down"
        }
    }

    var color: Color {
        switch self {
        case .largeFileBrowser:   return .orange
        case .oldUnusedFiles:     return .indigo
        case .appUninstaller:     return .red
        case .appCacheBreakdown:  return .purple
        case .leftoverFiles:      return Color(red: 0.6, green: 0.4, blue: 0.2)
        case .startupItems:       return .yellow
        case .memoryMonitor:      return .cyan
        case .diskHealth:         return Theme.accentGreen
        case .scanHistory:        return .blue
        case .safeMode:           return Theme.accentAmber
        case .iCloudCleaner:      return Color(red: 0.0, green: 0.48, blue: 1.0)
        }
    }

    var description: String {
        switch self {
        case .largeFileBrowser:   return "Find files larger than a custom threshold"
        case .oldUnusedFiles:     return "Surface files not modified in months"
        case .appUninstaller:     return "Uninstall apps and all their support files"
        case .appCacheBreakdown:  return "See which app eats the most cache space"
        case .leftoverFiles:      return "Orphaned files from deleted apps"
        case .startupItems:       return "Manage Login Items and Launch Agents"
        case .memoryMonitor:      return "Monitor RAM usage and pressure"
        case .diskHealth:         return "Check SMART status and disk capacity"
        case .scanHistory:        return "Track space freed over time"
        case .safeMode:           return "Stage deletions and review before committing"
        case .iCloudCleaner:      return "Reclaim space from iCloud-backed files"
        }
    }
}

// MARK: - Large File Group (used by Large File Browser tool)

struct LargeFileGroup: Identifiable, Sendable {
    let id: UUID = UUID()
    let typeName: String
    var items: [StorageItem]
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}
