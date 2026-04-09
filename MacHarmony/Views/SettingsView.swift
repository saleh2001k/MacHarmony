//
//  ViewsSettingsView.swift
//  MacHarmony
//

import SwiftUI
import AppKit

// MARK: - Root

struct SettingsView: View {
    @AppStorage("settingsSelectedTab") private var selectedTab = "general"

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag("general")
            ScanSettingsTab()
                .tabItem { Label("Scan", systemImage: "magnifyingglass") }
                .tag("scan")
            CategoriesSettingsTab()
                .tabItem { Label("Categories", systemImage: "square.grid.2x2") }
                .tag("categories")
            MenuBarSettingsTab()
                .tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
                .tag("menubar")
            NotificationsSettingsTab()
                .tabItem { Label("Notifications", systemImage: "bell") }
                .tag("notifications")
            ExportSettingsTab()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
                .tag("export")
            CustomScannersSettingsTab()
                .tabItem { Label("Custom Scanners", systemImage: "slider.horizontal.3") }
                .tag("custom")
        }
        .frame(width: 640, height: 580)
    }
}

// MARK: - Menu Bar Tab

private struct MenuBarSettingsTab: View {
    @EnvironmentObject var storageManager: StorageManager
    @AppStorage("derivedDataAutocleanEnabled") private var autocleanEnabled = false
    @AppStorage("derivedDataAutocleanInterval") private var autocleanInterval: Double = 604800

    private let intervalOptions: [(String, Double)] = [
        ("Daily", 86400),
        ("Weekly", 604800),
        ("Monthly", 2_592_000),
    ]

    var body: some View {
        Form {
            Section {
                ForEach(storageManager.orderedCategories) { category in
                    HStack(spacing: 10) {
                        Image(systemName: category.icon)
                            .foregroundStyle(category.color)
                            .frame(width: 20)
                        Text(category.title)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { storageManager.isInMenuBar(category) },
                            set: { _ in
                                withAnimation { storageManager.toggleMenuBarCategory(category) }
                            }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                    }
                }
            } header: {
                Text("Visible in Menu Bar")
            } footer: {
                Text("Only selected categories appear in the menu bar popup and are scanned when you tap \"Scan Now\" from the menu.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle("Automatically clean Derived Data", isOn: $autocleanEnabled)
                    .onChange(of: autocleanEnabled) { _, _ in
                        storageManager.scheduleDerivedDataAutocleanIfNeeded()
                    }

                if autocleanEnabled {
                    Picker("Frequency", selection: $autocleanInterval) {
                        ForEach(intervalOptions, id: \.1) { label, value in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: autocleanInterval) { _, _ in
                        storageManager.scheduleDerivedDataAutocleanIfNeeded()
                    }
                }
            } header: {
                Text("Derived Data Auto-Clean")
            } footer: {
                Text("MacHarmony will automatically scan and permanently delete all Derived Data on the chosen schedule. This runs silently in the background.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .animation(.easeInOut(duration: 0.2), value: autocleanEnabled)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @AppStorage("useDarkMode") private var useDarkMode = true
    @AppStorage("defaultActionAfterScan") private var defaultActionAfterScan = "dashboard"
    @AppStorage("deletionMode") private var deletionModeRaw = DeletionMode.ask.rawValue
    @EnvironmentObject var storageManager: StorageManager
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Color scheme", selection: $useDarkMode) {
                    Text("Dark").tag(true)
                    Text("Light").tag(false)
                }
                .pickerStyle(.radioGroup)
            }

            Section {
                Picker("Default action", selection: $defaultActionAfterScan) {
                    Text("Stay on Dashboard").tag("dashboard")
                    Text("Open Biggest Category").tag("biggestCategory")
                    Text("Do Nothing").tag("nothing")
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("After Scan")
            } footer: {
                Text("Controls what the app shows automatically when a scan finishes.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Picker("When cleaning items", selection: $deletionModeRaw) {
                    ForEach(DeletionMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Safety")
            } footer: {
                Text("\"Ask Each Time\" prompts you to choose trash or permanent deletion before each operation.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Button("Reset All Preferences to Defaults", role: .destructive) {
                    showResetConfirm = true
                }
            } header: {
                Text("Reset")
            } footer: {
                Text("Restores category order, ignored patterns, excluded paths, and all settings to their defaults.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Reset all preferences to defaults?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                storageManager.resetAllPreferences()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }
}

// MARK: - Scan Tab

private struct ScanSettingsTab: View {
    @AppStorage("performanceMode") private var performanceMode = "fast"
    @AppStorage("minScanFileSizeBytes") private var minScanFileSizeBytes: Double = 0
    @AppStorage("resultsCacheTTL") private var cacheTTL: Double = 3600
    @AppStorage("autoScanEnabled") private var autoScanEnabled = false
    @AppStorage("autoScanInterval") private var autoScanInterval: Double = 86400
    @EnvironmentObject var storageManager: StorageManager
    @State private var newPattern = ""

    private let sizeOptions: [(String, Double)] = [
        ("No minimum", 0),
        ("100 KB", 100_000),
        ("1 MB", 1_000_000),
        ("10 MB", 10_000_000),
        ("50 MB", 50_000_000),
    ]
    private let ttlOptions: [(String, Double)] = [
        ("30 minutes", 1800), ("1 hour", 3600), ("6 hours", 21600), ("24 hours", 86400),
    ]
    private let intervalOptions: [(String, Double)] = [
        ("Daily", 86400), ("Weekly", 604800),
    ]

    var body: some View {
        Form {
            Section {
                Picker("Priority", selection: $performanceMode) {
                    Text("Fast  (higher CPU, quicker results)").tag("fast")
                    Text("Balanced").tag("balanced")
                    Text("Low Power  (background priority)").tag("lowPower")
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Performance Mode")
            }

            Section {
                Picker("Minimum file size to include", selection: $minScanFileSizeBytes) {
                    ForEach(sizeOptions, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("File Size Filter")
            } footer: {
                Text("Files smaller than this are skipped in Images, Videos, and other deep scans.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                ForEach(storageManager.ignoredPatterns, id: \.self) { pattern in
                    HStack {
                        Text(pattern)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            storageManager.removeIgnoredPattern(pattern)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack(spacing: 8) {
                    TextField("Add pattern (e.g. .git, build, dist)", text: $newPattern)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addPattern() }
                    Button("Add") { addPattern() }
                        .disabled(newPattern.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Ignored Folder Names")
            } footer: {
                Text("Folders whose name matches any of these patterns are skipped during deep scans (Images, Videos, Large Files, APKs).")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                ForEach(storageManager.excludedScanPaths, id: \.self) { path in
                    HStack {
                        Text(path)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            storageManager.removeExcludedPath(path)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button("Add Excluded Folder…") { pickExcludedFolder() }
            } header: {
                Text("Excluded Paths")
            } footer: {
                Text("These directories are completely skipped during all scans.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Picker("Cache scan results for", selection: $cacheTTL) {
                    ForEach(ttlOptions, id: \.1) { label, value in Text(label).tag(value) }
                }
                .pickerStyle(.menu)

                Toggle("Automatically scan in the background", isOn: $autoScanEnabled)
                    .onChange(of: autoScanEnabled) { _, _ in
                        storageManager.scheduleAutoScanIfNeeded()
                    }

                if autoScanEnabled {
                    Picker("Frequency", selection: $autoScanInterval) {
                        ForEach(intervalOptions, id: \.1) { label, value in Text(label).tag(value) }
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text("Schedule")
            } footer: {
                Text("Cached results load instantly on relaunch. Press Scan in the toolbar to force a fresh scan at any time.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func addPattern() {
        let p = newPattern.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty else { return }
        storageManager.addIgnoredPattern(p)
        newPattern = ""
    }

    private func pickExcludedFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Exclude"
        if panel.runModal() == .OK, let url = panel.url {
            storageManager.addExcludedPath(url.path)
        }
    }
}

// MARK: - Categories Tab
// Standalone List (not inside Form) so .onMove drag handles work on macOS

private struct CategoriesSettingsTab: View {
    @EnvironmentObject var storageManager: StorageManager

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Category Order")
                        .font(.headline)
                    Text("Drag rows to reorder the sidebar and scan progress display.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reset to Default") {
                    storageManager.resetCategoryOrder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            Divider()

            List {
                ForEach(storageManager.orderedCategories) { category in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Image(systemName: category.icon)
                            .foregroundStyle(category.color)
                            .frame(width: 18)
                        Text(category.title)
                            .font(.system(size: 13))
                        Spacer()
                        if storageManager.isCategoryHidden(category) {
                            Text("Hidden")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.secondary.opacity(0.15), in: Capsule())
                        }
                    }
                    .padding(.vertical, 3)
                }
                .onMove { from, to in
                    storageManager.moveCategories(fromOffsets: from, toOffset: to)
                }
            }
        }
    }
}

// MARK: - Notifications Tab

private struct NotificationsSettingsTab: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notificationThreshold") private var notificationThreshold: Double = 0.85

    private let thresholdOptions: [(String, Double)] = [
        ("75%", 0.75), ("80%", 0.80), ("85%", 0.85), ("90%", 0.90), ("95%", 0.95),
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Enable storage alert notifications", isOn: $notificationsEnabled)
            } header: {
                Text("Storage Alerts")
            } footer: {
                Text("Notifications are sent after background scans when disk usage exceeds the threshold you set below.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if notificationsEnabled {
                Section {
                    Picker("Alert when disk is above", selection: $notificationThreshold) {
                        ForEach(thresholdOptions, id: \.1) { label, value in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.radioGroup)
                } header: {
                    Text("Alert Threshold")
                }
            }
        }
        .formStyle(.grouped)
        .animation(.easeInOut(duration: 0.2), value: notificationsEnabled)
    }
}

// MARK: - Export Tab

private struct ExportSettingsTab: View {
    @AppStorage("exportFormat") private var exportFormat = "csv"
    @AppStorage("exportIncludeHidden") private var exportIncludeHidden = false
    @AppStorage("exportDestination") private var exportDestination = ""

    var body: some View {
        Form {
            Section("Format") {
                Picker("Export file format", selection: $exportFormat) {
                    Text("CSV  (spreadsheet-friendly)").tag("csv")
                    Text("JSON  (developer-friendly)").tag("json")
                    Text("Plain Text").tag("txt")
                }
                .pickerStyle(.radioGroup)
            }

            Section("Options") {
                Toggle("Include hidden categories in export", isOn: $exportIncludeHidden)
            }

            Section {
                HStack {
                    if exportDestination.isEmpty {
                        Text("Default (~/Desktop)")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(exportDestination)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Choose…") { pickExportFolder() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    if !exportDestination.isEmpty {
                        Button("Reset") { exportDestination = "" }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            } header: {
                Text("Default Export Location")
            }
        }
        .formStyle(.grouped)
    }

    private func pickExportFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            exportDestination = url.path
        }
    }
}

// MARK: - Custom Scanners Tab

private struct CustomScannersSettingsTab: View {
    @EnvironmentObject var storageManager: StorageManager
    @State private var showAddSheet = false
    @State private var editingCategory: CustomScanCategory?

    var body: some View {
        VStack(spacing: 0) {
            if storageManager.customCategories.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Custom Scanners")
                        .font(.headline)
                    Text("Create a scanner to find files by extension in directories you choose.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).frame(maxWidth: 300)
                    Button("Add Custom Scanner") { showAddSheet = true }
                        .buttonStyle(.borderedProminent).tint(Theme.accentGreen)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(storageManager.customCategories) { category in
                        HStack(spacing: 12) {
                            Image(systemName: category.icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(category.color)
                                .themeIconBadge(color: category.color, size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name).font(.subheadline).fontWeight(.medium)
                                Text(category.extensions.map { ".\($0)" }.joined(separator: ", "))
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("\(category.searchPaths.count) director\(category.searchPaths.count == 1 ? "y" : "ies")")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Button { editingCategory = category } label: {
                                Image(systemName: "pencil").foregroundStyle(Theme.accentGreen)
                            }
                            .buttonStyle(.borderless)
                            Button {
                                Task { await storageManager.deleteCustomCategory(id: category.id) }
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
                Divider()
                HStack {
                    Spacer()
                    Button("Add Custom Scanner") { showAddSheet = true }
                        .buttonStyle(.borderedProminent).tint(Theme.accentGreen)
                }
                .padding(12)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddCustomCategoryView().environmentObject(storageManager)
        }
        .sheet(item: $editingCategory) { cat in
            AddCustomCategoryView(editingCategory: cat).environmentObject(storageManager)
        }
    }
}
