//
//  DetoxApp.swift
//  Detox
//
//  Created by saleh on 16/03/2026.
//

import SwiftUI
import AppKit
import UserNotifications

// Keeps the app alive after the last window closes
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct DetoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var storageManager = StorageManager()
    @AppStorage("useDarkMode") private var useDarkMode = true

    init() {
        // Request notification permission on first launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(storageManager)
                .preferredColorScheme(useDarkMode ? .dark : .light)
                .task {
                    storageManager.scheduleAutoScanIfNeeded()
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
