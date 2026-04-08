//
//  DetoxApp.swift
//  Detox
//
//  Created by saleh on 16/03/2026.
//

import SwiftUI
import AppKit

// Keeps the app alive after the last window closes.
// Dynamically shows/hides the Dock icon based on whether the main window is open.
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start hidden from the Dock — run as a menu-bar-only app by default
        NSApp.setActivationPolicy(.accessory)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // A regular titled window gained focus → show in Dock
    @objc private func windowDidBecomeKey(_ note: Notification) {
        guard let win = note.object as? NSWindow,
              win.styleMask.contains(.titled), !(win is NSPanel) else { return }
        NSApp.setActivationPolicy(.regular)
    }

    // A window closed → if no more titled windows remain, hide from Dock
    @objc private func windowWillClose(_ note: Notification) {
        DispatchQueue.main.async {
            let hasVisibleWindow = NSApp.windows.contains {
                $0.isVisible && $0.styleMask.contains(.titled) && !($0 is NSPanel)
            }
            if !hasVisibleWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

@main
struct DetoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var storageManager = StorageManager()
    @AppStorage("useDarkMode") private var useDarkMode = true

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(storageManager)
                .preferredColorScheme(useDarkMode ? .dark : .light)
                .task {
                    storageManager.scheduleAutoScanIfNeeded()
                    storageManager.scheduleDerivedDataAutocleanIfNeeded()
                }
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("Detox Help") {
                    NotificationCenter.default.post(name: .showHelp, object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarQuickAccessView()
                .environmentObject(storageManager)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(storageManager)
        }
    }
}
