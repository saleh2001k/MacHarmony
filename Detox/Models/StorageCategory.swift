//
//  StorageCategory.swift
//  Detox
//
//  Created by saleh on 16/03/2026.
//

import Foundation
import SwiftUI

// MARK: - ScanStyle

/// Describes how a category's paths should be scanned.
enum ScanStyle {
    /// Yield only immediate child directories (existing behaviour).
    case topLevelDirs
    /// Yield immediate children — both files and directories (e.g. Downloads).
    case topLevelAll
    /// Recursively yield all files matching the given extensions (e.g. Images, Videos).
    case deepFiles(extensions: [String])
    /// Recursively yield all files at or above the given byte threshold (e.g. Large Files).
    case deepLargeFiles(minBytes: Int64)
    /// Special deep-search for node_modules folders.
    case nodeModules
    /// List local Time Machine snapshots via tmutil.
    case timeMachine
    /// Enumerate all trash locations (home + per-volume) using FileManager.
    case trashDirectories
}

// MARK: - StorageCategory

enum StorageCategory: String, CaseIterable, Identifiable, Hashable {
    // Apple Developer
    case xcodeDerivedData
    case xcodeArchives
    case xcodeDeviceSupport
    case nodeModules
    case podCache
    case brewCache
    case simulatorData
    // Android Developer
    case gradleCache
    case androidEmulators
    case apkFiles
    // System
    case systemCaches
    case applicationCaches
    case logFiles
    // User files
    case downloads
    case images
    case videos
    case largeFiles
    // Backups
    case iOSBackups
    // New categories
    case mailAttachments
    case iCloudPlaceholders
    case browserCache
    case timeMachineSnapshots
    // Trash
    case trash

    nonisolated var id: String { rawValue }

    // MARK: - Scan strategy

    nonisolated var scanStyle: ScanStyle {
        switch self {
        case .xcodeDerivedData, .xcodeArchives, .xcodeDeviceSupport,
             .podCache, .brewCache, .simulatorData,
             .logFiles, .iOSBackups:
            return .topLevelDirs

        case .gradleCache:
            return .topLevelDirs

        case .androidEmulators:
            return .topLevelAll

        case .apkFiles:
            return .deepFiles(extensions: ["apk", "aab", "aar"])

        case .systemCaches, .applicationCaches:
            return .topLevelDirs   // scanner applies 1 MB threshold for these

        case .nodeModules:
            return .nodeModules

        case .downloads:
            return .topLevelAll

        case .images:
            return .deepFiles(extensions: [
                "jpg", "jpeg", "png", "heic", "heif",
                "gif", "webp", "tiff", "tif", "bmp"
            ])

        case .videos:
            return .deepFiles(extensions: [
                "mp4", "mov", "mkv", "avi", "m4v",
                "wmv", "webm", "mpg", "mpeg", "flv",
                "3gp", "m2ts", "rm",
                "rmvb", "divx", "ogv", "vob", "f4v"
            ])

        case .largeFiles:
            return .deepLargeFiles(minBytes: 100 * 1024 * 1024)   // 100 MB

        case .mailAttachments:
            return .topLevelDirs

        case .iCloudPlaceholders:
            return .deepFiles(extensions: ["icloud"])

        case .browserCache:
            return .topLevelDirs

        case .timeMachineSnapshots:
            return .timeMachine

        case .trash:
            return .trashDirectories
        }
    }

    // MARK: - Display

    nonisolated var title: String {
        switch self {
        case .xcodeDerivedData: return "Xcode Derived Data"
        case .xcodeArchives: return "Xcode Archives"
        case .xcodeDeviceSupport: return "Device Support"
        case .nodeModules: return "Node Modules"
        case .podCache: return "CocoaPods Cache"
        case .brewCache: return "Homebrew Cache"
        case .simulatorData: return "Simulator Data"
        case .gradleCache: return "Gradle Cache"
        case .androidEmulators: return "Android Emulators"
        case .apkFiles: return "APK / AAB Files"
        case .systemCaches: return "System Caches"
        case .applicationCaches: return "Application Caches"
        case .logFiles: return "Log Files"
        case .downloads: return "Downloads"
        case .images: return "Images"
        case .videos: return "Videos"
        case .largeFiles: return "Large Files"
        case .iOSBackups: return "iOS Backups"
        case .mailAttachments: return "Mail Attachments"
        case .iCloudPlaceholders: return "iCloud Placeholders"
        case .browserCache: return "Browser Cache"
        case .timeMachineSnapshots: return "TM Snapshots"
        case .trash: return "Trash"
        }
    }

    nonisolated var icon: String {
        switch self {
        case .xcodeDerivedData: return "hammer.fill"
        case .xcodeArchives: return "archivebox.fill"
        case .xcodeDeviceSupport: return "iphone"
        case .nodeModules: return "shippingbox.fill"
        case .podCache: return "cube.fill"
        case .brewCache: return "mug.fill"
        case .simulatorData: return "apps.iphone"
        case .gradleCache: return "cylinder.fill"
        case .androidEmulators: return "rectangle.portrait.fill"
        case .apkFiles: return "doc.zipper"
        case .systemCaches: return "gearshape.fill"
        case .applicationCaches: return "app.fill"
        case .logFiles: return "doc.text.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .images: return "photo.fill"
        case .videos: return "film.fill"
        case .largeFiles: return "internaldrive.fill"
        case .iOSBackups: return "iphone.badge.play"
        case .mailAttachments: return "envelope.fill"
        case .iCloudPlaceholders: return "icloud.fill"
        case .browserCache: return "globe"
        case .timeMachineSnapshots: return "clock.arrow.circlepath"
        case .trash: return "trash.fill"
        }
    }

    nonisolated var color: Color {
        switch self {
        case .xcodeDerivedData: return .blue
        case .xcodeArchives: return .purple
        case .xcodeDeviceSupport: return .indigo
        case .nodeModules: return .green
        case .podCache: return .orange
        case .brewCache: return Color(red: 0.6, green: 0.4, blue: 0.2)
        case .simulatorData: return .indigo
        case .gradleCache: return Color(red: 0.07, green: 0.56, blue: 0.29)   // Gradle green
        case .androidEmulators: return Color(red: 0.20, green: 0.72, blue: 0.32)  // Android green
        case .apkFiles: return Color(red: 0.18, green: 0.60, blue: 0.18)
        case .systemCaches: return .gray
        case .applicationCaches: return .pink
        case .logFiles: return .yellow
        case .downloads: return .cyan
        case .images: return .mint
        case .videos: return .purple
        case .largeFiles: return .red
        case .iOSBackups: return .teal
        case .mailAttachments: return .indigo
        case .iCloudPlaceholders: return .cyan
        case .browserCache: return .orange
        case .timeMachineSnapshots: return .brown
        case .trash: return Color(red: 0.90, green: 0.25, blue: 0.25)
        }
    }

    nonisolated var description: String {
        switch self {
        case .xcodeDerivedData:
            return "Build artifacts and indexes generated by Xcode"
        case .xcodeArchives:
            return "Archived builds for distribution"
        case .xcodeDeviceSupport:
            return "Device debugging symbols"
        case .nodeModules:
            return "JavaScript dependencies from npm/yarn"
        case .podCache:
            return "Downloaded CocoaPods dependencies"
        case .brewCache:
            return "Homebrew package downloads"
        case .simulatorData:
            return "Xcode simulator device data"
        case .gradleCache:
            return "Gradle build caches and wrapper distributions"
        case .androidEmulators:
            return "Android Virtual Device (AVD) disk images"
        case .apkFiles:
            return "Android app packages (.apk, .aab, .aar)"
        case .systemCaches:
            return "System-level cache files"
        case .applicationCaches:
            return "Application cache data"
        case .logFiles:
            return "App and system log files"
        case .downloads:
            return "Files and folders in ~/Downloads"
        case .images:
            return "Photos and images in ~/Pictures"
        case .videos:
            return "Video files (mp4, mov, mkv, avi, and more) across your entire home folder"
        case .largeFiles:
            return "Files larger than 100 MB in common locations"
        case .iOSBackups:
            return "iPhone and iPad backups stored on this Mac"
        case .mailAttachments:
            return "Attachments downloaded by the Mail app"
        case .iCloudPlaceholders:
            return "iCloud placeholder (.icloud) files not yet downloaded"
        case .browserCache:
            return "Safari, Chrome, Firefox, and Edge cache files"
        case .timeMachineSnapshots:
            return "Local Time Machine snapshots stored on this Mac"
        case .trash:
            return "Files and folders waiting in your Trash"
        }
    }

    // MARK: - Paths

    nonisolated func paths(from homeDir: String) -> [String] {
        switch self {
        case .xcodeDerivedData:
            return ["\(homeDir)/Library/Developer/Xcode/DerivedData"]
        case .xcodeArchives:
            return ["\(homeDir)/Library/Developer/Xcode/Archives"]
        case .xcodeDeviceSupport:
            return [
                "\(homeDir)/Library/Developer/Xcode/iOS DeviceSupport",
                "\(homeDir)/Library/Developer/Xcode/watchOS DeviceSupport",
                "\(homeDir)/Library/Developer/Xcode/tvOS DeviceSupport"
            ]
        case .nodeModules:
            return [homeDir]   // deep-searched for node_modules folders
        case .podCache:
            return ["\(homeDir)/Library/Caches/CocoaPods"]
        case .brewCache:
            return ["\(homeDir)/Library/Caches/Homebrew"]
        case .simulatorData:
            return ["\(homeDir)/Library/Developer/CoreSimulator/Devices"]
        case .gradleCache:
            return [
                "\(homeDir)/.gradle/caches",
                "\(homeDir)/.gradle/wrapper/dists"
            ]
        case .androidEmulators:
            return ["\(homeDir)/.android/avd"]
        case .apkFiles:
            return [homeDir]
        case .systemCaches:
            return ["\(homeDir)/Library/Caches"]
        case .applicationCaches:
            return ["\(homeDir)/Library/Application Support"]
        case .logFiles:
            return ["\(homeDir)/Library/Logs"]
        case .downloads:
            return ["\(homeDir)/Downloads"]
        case .images:
            return [homeDir]
        case .videos:
            return [homeDir]
        case .largeFiles:
            return [
                "\(homeDir)/Documents",
                "\(homeDir)/Downloads",
                "\(homeDir)/Desktop"
            ]
        case .iOSBackups:
            return ["\(homeDir)/Library/Application Support/MobileSync/Backup"]
        case .mailAttachments:
            return ["\(homeDir)/Library/Mail"]
        case .iCloudPlaceholders:
            return ["\(homeDir)/Library/Mobile Documents", homeDir]
        case .browserCache:
            return [
                "\(homeDir)/Library/Caches/com.apple.Safari",
                "\(homeDir)/Library/Caches/com.google.Chrome",
                "\(homeDir)/Library/Application Support/Google/Chrome/Default/Cache",
                "\(homeDir)/Library/Application Support/Microsoft Edge/Default/Cache",
                "\(homeDir)/Library/Application Support/Firefox/Profiles"
            ]
        case .timeMachineSnapshots:
            return []

        case .trash:
            // Path discovery is handled internally by scanTrashDirectories,
            // which covers ~/.Trash and all per-volume /Volumes/*/.Trashes/{uid}/ paths.
            return []
        }
    }
}
