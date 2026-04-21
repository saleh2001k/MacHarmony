//
//  macHarmonyApp.swift
//  MacHarmony
//

import SwiftUI
import AppKit

// Keeps the app alive after the last window closes.
// Dynamically shows/hides the Dock icon based on whether the main window is open.
class AppDelegate: NSObject, NSApplicationDelegate {

    // Injected by MacHarmonyApp so deep links can reach AuthManager
    var authManager: AuthManager?

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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Cmd+Q / right-click Quit → just close the main window, keep running in menu bar
        NSApp.windows.forEach { $0.close() }
        return .terminateCancel
    }

    // Handle macharmony://auth?token=<x> deep links from the browser
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first,
              url.scheme == "macharmony",
              url.host == "auth"
        else { return }

        // Bring the window to front
        NSApp.activate(ignoringOtherApps: true)

        Task { @MainActor in
            await authManager?.handleDeepLink(url)
        }
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
struct MacHarmonyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var storageManager = StorageManager()
    @StateObject private var authManager    = AuthManager()
    @AppStorage("useDarkMode") private var useDarkMode = true

    init() {
        #if DEBUG
        UserDefaults.standard.set(false, forKey: "hasShownOnboarding")
        #endif
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            AuthGatedView()
                .environmentObject(storageManager)
                .environmentObject(authManager)
                .preferredColorScheme(useDarkMode ? .dark : .light)
                .task {
                    // Give AppDelegate a reference so deep links reach AuthManager
                    appDelegate.authManager = authManager

                    // Validate license on every launch
                    await authManager.validateOnLaunch()

                    // Background tasks run for all active users (paid, trial, offline grace)
                    switch authManager.state {
                    case .authenticated, .offlineGrace, .trial:
                        storageManager.scheduleAutoScanIfNeeded()
                        storageManager.scheduleDerivedDataAutocleanIfNeeded()
                    default:
                        break
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("MacHarmony Help") {
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

        WindowGroup(id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(storageManager)
        }
    }
}
