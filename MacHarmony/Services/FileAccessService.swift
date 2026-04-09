//
//  FileAccessService.swift
//  MacHarmony
//
//  Created by saleh on 16/03/2026.
//

import AppKit
import Foundation

@MainActor
class FileAccessService {

    private static let bookmarkKey = "homeDirectoryBookmark"

    /// The security-scoped URL granted by the user via NSOpenPanel.
    /// Must be retained for the app's lifetime — releasing it revokes file access.
    private var securityScopedURL: URL?

    /// Request read-write access to the home directory.
    /// On subsequent launches, resolves the saved bookmark instead of prompting the user again.
    /// Returns the granted path, or nil if the user cancelled.
    func requestFileAccess() async -> String? {
        // Try to restore from a previously saved bookmark first
        if let path = resolveBookmark() {
            return path
        }

        // First launch — show the open panel
        let panel = NSOpenPanel()
        panel.message = "Grant access to your home folder to scan and clean storage"
        panel.prompt = "Grant Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        let response = await withCheckedContinuation { (continuation: CheckedContinuation<NSApplication.ModalResponse, Never>) in
            panel.begin { response in
                continuation.resume(returning: response)
            }
        }

        guard response == .OK, let url = panel.url else {
            return nil
        }

        // Persist a security-scoped bookmark so we never prompt again
        saveBookmark(for: url)

        securityScopedURL = url
        url.startAccessingSecurityScopedResource()

        #if DEBUG
        print("🔐 Security-scoped access granted for \(url.path)")
        #endif

        return url.path
    }

    /// Open system settings to Full Disk Access (fallback for users who prefer it).
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Bookmark helpers

    private func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
        } catch {
            #if DEBUG
            print("⚠️ Failed to save bookmark: \(error)")
            #endif
        }
    }

    private func resolveBookmark() -> String? {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return nil }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Bookmark is stale — re-save a fresh one and continue
                saveBookmark(for: url)
            }

            securityScopedURL = url
            url.startAccessingSecurityScopedResource()

            #if DEBUG
            print("🔐 Restored security-scoped access for \(url.path)")
            #endif

            return url.path
        } catch {
            // Bookmark invalid — clear it so the panel shows next launch
            UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
            #if DEBUG
            print("⚠️ Failed to resolve bookmark: \(error)")
            #endif
            return nil
        }
    }
}
