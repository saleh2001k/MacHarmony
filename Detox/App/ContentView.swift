//
//  ContentView.swift
//  Detox
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject var storageManager: StorageManager
    @State private var fileAccessService = FileAccessService()
    @State private var showPermissionAlert = false
    @State private var showHelp = false
    @State private var hasLaunched = false
    @AppStorage("hasShownOnboarding") private var hasShownOnboarding = false

    private var isScanning: Bool { storageManager.isFullScanRunning || storageManager.isMenuBarScanRunning }

    var body: some View {
        Group {
            if isScanning {
                // No NavigationSplitView → no sidebar toggle button exists at all
                ScanningFullView(storageManager: storageManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NavigationSplitView {
                    SidebarView(storageManager: storageManager)
                } detail: {
                    DetailContentView(
                        storageManager: storageManager,
                        isScanning: false
                    )
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if !isScanning {
                    // Home button — visible only when a category is selected
                    if storageManager.selectedCategory != nil
                        || storageManager.selectedCustomCategory != nil
                        || storageManager.selectedTool != nil {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                storageManager.selectedCategory = nil
                                storageManager.selectedCustomCategory = nil
                                storageManager.selectedTool = nil
                            }
                        } label: {
                            Label("Home", systemImage: "house.fill")
                        }
                        .accessibilityLabel("Go to Home")
                    }
                }
                ScanButton(storageManager: storageManager)
                if !isScanning && storageManager.hasResults {
                    Button {
                        ReportExporter.export(storageManager: storageManager)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export report")
                }
                if !isScanning {
                    PermissionsButton(showPermissionAlert: $showPermissionAlert)
                    Button {
                        showHelp = true
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                    .accessibilityLabel("Help")
                    if #available(macOS 14.0, *) {
                        SettingsLink {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    } else {
                        Button { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isScanning)
        .opacity(hasLaunched ? 1 : 0)
        .task {
            withAnimation(.easeOut(duration: 0.28).delay(0.04)) {
                hasLaunched = true
            }
            guard hasShownOnboarding else { return }
            await performInitialSetup()
        }
        .alert("File Access Required", isPresented: $showPermissionAlert) {
            Button("Open System Settings") {
                fileAccessService.openFullDiskAccessSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This app needs Full Disk Access to scan and clean storage.\n\n1. Open System Settings\n2. Go to Privacy & Security → Full Disk Access\n3. Add this app and enable it\n4. Restart the app")
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(isPresented: .init(get: { !hasShownOnboarding }, set: { _ in })) {
            OnboardingView { requestNotifications in
                hasShownOnboarding = true
                if requestNotifications {
                    UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                }
                Task { await performInitialSetup() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showHelp)) { _ in
            showHelp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .startFullScan)) { _ in
            guard !storageManager.isFullScanRunning else { return }
            Task { await runFullScan() }
        }
    }

    // MARK: - Private Methods

    private func performInitialSetup() async {
        if let path = await fileAccessService.requestFileAccess() {
            storageManager.rootPath = path
        }

        // Try loading from cache first — skip scan if results are fresh
        let loaded = await storageManager.loadCachedResultsIfFresh()
        if !loaded {
            await runFullScan()
        }

        // Refresh trash size now that file access is granted
        await storageManager.refreshTrashSize()
    }

    private func runFullScan() async {
        storageManager.isFullScanRunning = true
        await storageManager.scan()
        storageManager.isFullScanRunning = false
    }
}

// MARK: - Detail Content View

struct DetailContentView: View {
    @ObservedObject var storageManager: StorageManager
    let isScanning: Bool

    var body: some View {
        if let category = storageManager.selectedCategory {
            VStack(spacing: 0) {
                StorageOverviewView(storageManager: storageManager)
                Divider()
                CategoryDetailView(
                    category: category,
                    items: storageManager.items(for: category),
                    storageManager: storageManager
                )
                .id(category)
            }
        } else if let custom = storageManager.selectedCustomCategory {
            VStack(spacing: 0) {
                StorageOverviewView(storageManager: storageManager)
                Divider()
                CustomCategoryDetailView(
                    category: custom,
                    items: storageManager.customItems[custom.id] ?? [],
                    storageManager: storageManager
                )
                .id(custom.id)
            }
        } else if let tool = storageManager.selectedTool {
            ToolRouterView(tool: tool, storageManager: storageManager)
        } else if storageManager.hasResults || !storageManager.storageItems.isEmpty {
            DashboardView(storageManager: storageManager)
        } else {
            EmptyCategorySelectionView()
        }
    }
}

// MARK: - Tool Router View

struct ToolRouterView: View {
    let tool: ToolType
    @ObservedObject var storageManager: StorageManager

    var body: some View {
        switch tool {
        case .largeFileBrowser:  ViewsLargeFileBrowserView(storageManager: storageManager)
        case .oldUnusedFiles:    ViewsOldUnusedFilesView(storageManager: storageManager)
        case .emptyFolders:      ViewsEmptyFolderView(storageManager: storageManager)
        case .appUninstaller:    ViewsAppUninstallerView(storageManager: storageManager)
        case .appCacheBreakdown: ViewsAppCacheView(storageManager: storageManager)
        case .leftoverFiles:     ViewsLeftoverFilesView(storageManager: storageManager)
        case .startupItems:      ViewsStartupItemsView(storageManager: storageManager)
        case .memoryMonitor:     ViewsMemoryMonitorView(storageManager: storageManager)
        case .diskHealth:        ViewsDiskHealthView(storageManager: storageManager)
        case .scanHistory:       ViewsScanHistoryView(storageManager: storageManager)
        case .safeMode:          ViewsSafeModeView(storageManager: storageManager)
        case .iCloudCleaner:     ViewsiCloudCleanerView(storageManager: storageManager)
        }
    }
}

// MARK: - Empty Category Selection View

struct EmptyCategorySelectionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var iconOffset: CGFloat = 0
    @State private var appeared = false

    private let steps: [(String, String)] = [
        ("folder.badge.gear", "Grant access to your home folder when prompted"),
        ("arrow.clockwise.circle.fill", "Press Scan in the toolbar to analyze storage"),
        ("sidebar.leading", "Select a category from the sidebar to review items")
    ]

    private let stepColors: [Color] = [Theme.accentGreen, .purple, .teal]

    private var appIcon: NSImage? {
        if let url = Bundle.main.url(forResource: "mac-cleaner-icon", withExtension: "svg") {
            return NSImage(contentsOf: url)
        }
        return NSImage(named: "AppIcon")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero icon
                ZStack {
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Theme.accentGreen.opacity(0.12 - Double(i) * 0.05), .clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 70 + CGFloat(i) * 20
                                )
                            )
                            .frame(width: 130 + CGFloat(i) * 40, height: 130 + CGFloat(i) * 40)
                            .scaleEffect(appeared ? 1.0 : 0.6)
                            .opacity(appeared ? 1.0 : 0)
                            .animation(.spring(response: 0.8).delay(Double(i) * 0.15), value: appeared)
                    }

                    if let icon = appIcon {
                        Group {
                            if colorScheme == .dark {
                                Image(nsImage: icon).resizable().colorInvert()
                            } else {
                                Image(nsImage: icon).resizable()
                            }
                        }
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .offset(y: iconOffset)
                        .scaleEffect(appeared ? 1.0 : 0.5)
                        .opacity(appeared ? 1.0 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appeared)
                    } else {
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 52, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Theme.accentGreen, Theme.accentGreen.opacity(0.6)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .offset(y: iconOffset)
                            .scaleEffect(appeared ? 1.0 : 0.5)
                            .opacity(appeared ? 1.0 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appeared)
                    }
                }
                .frame(height: 140)

                VStack(spacing: 8) {
                    Text("Detox")
                        .font(.largeTitle).fontWeight(.bold)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.5).delay(0.15), value: appeared)
                    Text("Free up space by removing caches, build artifacts,\nand other safe-to-delete files.")
                        .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary)
                        .frame(maxWidth: 380)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                        .animation(.spring(response: 0.5).delay(0.22), value: appeared)
                }

                VStack(spacing: 12) {
                    Text("Getting Started")
                        .font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(appeared ? 1 : 0).animation(.easeOut.delay(0.3), value: appeared)
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(stepColors[index].opacity(0.15)).frame(width: 36, height: 36)
                                Image(systemName: step.0).font(.system(size: 15, weight: .medium)).foregroundStyle(stepColors[index])
                            }
                            Text(step.1).font(.subheadline)
                            Spacer()
                        }
                        .padding(12)
                        .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.borderSubtle, lineWidth: 1)
                        )
                        .opacity(appeared ? 1 : 0).offset(x: appeared ? 0 : -16)
                        .animation(.spring(response: 0.45).delay(0.35 + Double(index) * 0.08), value: appeared)
                    }
                }
                .frame(maxWidth: 460)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Re-scan after deleting to update the storage overview.", systemImage: "info.circle")
                    Label("Only delete items you recognize to stay safe.", systemImage: "info.circle")
                }
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: 460, alignment: .leading)
                .opacity(appeared ? 1 : 0).animation(.easeOut.delay(0.65), value: appeared)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            appeared = true
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                iconOffset = -6
            }
        }
    }
}

// MARK: - Scan Button

struct ScanButton: View {
    @ObservedObject var storageManager: StorageManager

    var body: some View {
        Button {
            Task {
                storageManager.isFullScanRunning = true
                await storageManager.scan()
                storageManager.isFullScanRunning = false
            }
        } label: {
            Label("Scan", systemImage: "arrow.clockwise")
        }
        .disabled(storageManager.isFullScanRunning)
        .accessibilityLabel("Scan storage")
        .accessibilityHint("Analyzes your Mac for cleanable files")
    }
}

// MARK: - Permissions Button

struct PermissionsButton: View {
    @Binding var showPermissionAlert: Bool

    var body: some View {
        Button {
            showPermissionAlert = true
        } label: {
            Label("Permissions", systemImage: "lock.shield")
        }
        .accessibilityLabel("Permissions")
        .accessibilityHint("Opens Full Disk Access settings")
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(StorageManager())
        .frame(minWidth: 800, minHeight: 600)
}
