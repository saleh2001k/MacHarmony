//
//  FileAccessService.swift
//  Detox
//
//  Created by saleh on 16/03/2026.
//

import AppKit
import Foundation

@MainActor
class FileAccessService {

    /// The security-scoped URL granted by the user via NSOpenPanel.
    /// Must be retained for the app's lifetime — releasing it revokes file access.
    private var securityScopedURL: URL?

    /// Request user to grant read-write access to their home directory.
    /// Returns the path if access was granted; nil if the user cancelled.
    func requestFileAccess() async -> String? {
        let panel = NSOpenPanel()
        panel.message = "Grant access to your home folder to scan and clean storage"
        panel.prompt = "Grant Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        // Use the async begin(completionHandler:) instead of runModal().
        // runModal() enters a blocking modal run loop synchronously, which
        // AppKit forbids when called inside a SwiftUI view transaction (the
        // window hasn't finished committing yet when .task fires on appear).
        // begin(completionHandler:) schedules presentation on the next run-loop
        // pass, safely after SwiftUI's transaction has settled.
        let response = await withCheckedContinuation { (continuation: CheckedContinuation<NSApplication.ModalResponse, Never>) in
            panel.begin { response in
                continuation.resume(returning: response)
            }
        }

        guard response == .OK, let url = panel.url else {
            return nil
        }

        // Keep the URL alive — releasing it stops security-scoped access.
        // startAccessingSecurityScopedResource() activates read-write access to
        // this directory and all its subdirectories for the app's lifetime.
        securityScopedURL = url
        let granted = url.startAccessingSecurityScopedResource()
        #if DEBUG
        print("🔐 Security-scoped access granted: \(granted) for \(url.path)")
        #endif

        return url.path
    }

    /// Open system settings to Full Disk Access (fallback for users who prefer it).
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
