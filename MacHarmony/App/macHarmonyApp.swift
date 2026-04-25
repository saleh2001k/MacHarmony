//
//  macHarmonyApp.swift
//  MacHarmony
//

import SwiftUI
import AppKit

// Keeps the app alive after the last window closes.
// Dynamically shows/hides the Dock icon based on whether the main window is visible.
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var authManager: AuthManager?

    // Set by MacHarmonyApp.body once the StateObject is ready
    var storageManager: StorageManager? {
        didSet {
            guard let sm = storageManager, statusItem == nil else { return }
            setupStatusItem(storageManager: sm)
        }
    }

    // When true, the next applicationShouldTerminate call actually quits
    var isExplicitQuit = false

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowBecameKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    // MARK: - Menu Bar Status Item

    func setupStatusItem(storageManager: StorageManager) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.action = #selector(toggleMenuBarPopover(_:))
            button.target = self
        }

        let hosting = NSHostingController(
            rootView: MenuBarQuickAccessView().environmentObject(storageManager)
        )
        hosting.sizingOptions = .intrinsicContentSize

        let p = NSPopover()
        p.behavior = .transient
        p.contentViewController = hosting
        self.popover = p
    }

    @objc func toggleMenuBarPopover(_ sender: AnyObject?) {
        guard let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Terminate / Quit

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isExplicitQuit { return .terminateNow }
        // Cmd+Q: hide all main windows, keep running in the menu bar
        hideAllMainWindows()
        return .terminateCancel
    }

    // MARK: - Deep Link

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first,
              url.scheme == "macharmony",
              url.host == "auth"
        else { return }

        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in
            await authManager?.handleDeepLink(url)
        }
    }

    // MARK: - Window Delegate

    // Intercept titled-window close so we hide instead of destroy.
    // This ensures "Open" in the menu bar popover can always bring the window back.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender.styleMask.contains(.titled), !(sender is NSPanel) else { return true }
        sender.orderOut(nil)
        DispatchQueue.main.async { self.updateDockVisibility() }
        return false
    }

    // MARK: - Helpers

    @objc private func handleWindowBecameKey(_ note: Notification) {
        guard let win = note.object as? NSWindow,
              win.styleMask.contains(.titled), !(win is NSPanel) else { return }
        win.delegate = self
        NSApp.setActivationPolicy(.regular)
    }

    private func hideAllMainWindows() {
        NSApp.windows.forEach { win in
            guard win.styleMask.contains(.titled), !(win is NSPanel) else { return }
            win.orderOut(nil)
        }
        NSApp.setActivationPolicy(.accessory)
    }

    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let win = NSApp.windows.first(where: { $0.styleMask.contains(.titled) && !($0 is NSPanel) }) {
            win.makeKeyAndOrderFront(nil)
        }
        updateDockVisibility()
    }

    private func updateDockVisibility() {
        let hasVisible = NSApp.windows.contains {
            $0.isVisible && $0.styleMask.contains(.titled) && !($0 is NSPanel)
        }
        NSApp.setActivationPolicy(hasVisible ? .regular : .accessory)
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
                    appDelegate.authManager = authManager
                    appDelegate.storageManager = storageManager

                    await authManager.validateOnLaunch()

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
