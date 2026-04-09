//
//  ViewsAppUninstallerView.swift
//  MacHarmony
//

import SwiftUI

struct ViewsAppUninstallerView: View {
    @ObservedObject var storageManager: StorageManager
    @State private var searchText = ""
    @State private var appToRemove: AppEntry?
    @State private var showRemoveAlert = false
    @State private var showAskAlert = false
    @AppStorage("deletionMode") private var deletionModeRaw = DeletionMode.ask.rawValue

    private var deletionMode: DeletionMode { DeletionMode(rawValue: deletionModeRaw) ?? .ask }

    private var filteredApps: [AppEntry] {
        guard !searchText.isEmpty else { return storageManager.appEntries }
        return storageManager.appEntries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var totalFootprint: Int64 {
        storageManager.appEntries.reduce(0) { $0 + $1.totalSize }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: ToolType.appUninstaller.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ToolType.appUninstaller.color)
                    .themeIconBadge(color: ToolType.appUninstaller.color, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolType.appUninstaller.title).font(.title3).fontWeight(.semibold)
                    if storageManager.appEntries.isEmpty {
                        Text("Uninstall apps and all their support files")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("\(storageManager.appEntries.count) apps · \(ByteCountFormatter.string(fromByteCount: totalFootprint, countStyle: .file)) total")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    Task { await storageManager.scanApps() }
                } label: {
                    if storageManager.isAppScanRunning {
                        HStack(spacing: 6) { IndeterminateSpinner(size: 16, color: .secondary); Text("Scanning…") }
                    } else {
                        Label(storageManager.appEntries.isEmpty ? "Scan Apps" : "Re-Scan", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(storageManager.isAppScanRunning)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()

            Divider()

            if storageManager.isAppScanRunning {
                ToolLoadingView(message: "Scanning installed apps and support files…")
            } else if storageManager.appEntries.isEmpty {
                ToolEmptyView(
                    icon: ToolType.appUninstaller.icon,
                    title: "No Apps Scanned",
                    subtitle: "Press Scan Apps to find all installed applications\nand their support files footprint.",
                    color: ToolType.appUninstaller.color
                )
            } else {
                VStack(spacing: 0) {
                    SearchBar(searchText: $searchText, placeholder: "Search \(storageManager.appEntries.count) apps…")
                    Divider()
                    List(filteredApps) { app in
                        AppEntryRow(app: app) {
                            appToRemove = app
                            if deletionMode == .ask { showAskAlert = true }
                            else { showRemoveAlert = true }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .confirmationDialog("Remove \"\(appToRemove?.name ?? "")\"?",
                            isPresented: $showAskAlert, titleVisibility: .visible) {
            Button("Move to Trash") { performRemove(mode: .trash) }
            Button("Delete Permanently", role: .destructive) { performRemove(mode: .permanent) }
            Button("Cancel", role: .cancel) { appToRemove = nil }
        } message: {
            if let app = appToRemove {
                Text("This will remove the app bundle (\(app.formattedBundleSize)) and all \(app.supportItems.count) associated support file(s).\nTotal: \(app.formattedTotalSize)")
            }
        }
        .alert("Remove \"\(appToRemove?.name ?? "")\"?", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) { appToRemove = nil }
            Button("Remove", role: .destructive) { performRemove(mode: deletionMode) }
        } message: {
            if let app = appToRemove {
                Text("App bundle + \(app.supportItems.count) support file(s) will be removed. Total: \(app.formattedTotalSize)")
            }
        }
    }

    private func performRemove(mode: DeletionMode) {
        guard let app = appToRemove else { return }
        appToRemove = nil
        Task { await storageManager.removeApp(app, mode: mode) }
    }
}

// MARK: - App Entry Row

private struct AppEntryRow: View {
    let app: AppEntry
    let onRemove: () -> Void
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // App icon from bundle
                AppIconView(path: app.installPath)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.subheadline).fontWeight(.semibold)
                    Text(app.bundleID.isEmpty ? app.version : "\(app.bundleID) · v\(app.version)")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(app.formattedTotalSize)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(Theme.accentRed.opacity(0.9))
                    if !app.supportItems.isEmpty {
                        Text("+ \(app.supportItems.count) support files")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button("Remove", action: onRemove)
                    .buttonStyle(ThemeDestructiveButton())
                    .controlSize(.small)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(isHovered ? Theme.backgroundElevated : Color.clear)
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: isHovered)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    AppSupportRow(label: "App Bundle", path: app.installPath, size: app.bundleSize)
                    ForEach(app.supportItems) { item in
                        AppSupportRow(label: item.name, path: item.path, size: item.size)
                    }
                }
                .padding(.horizontal, 62).padding(.bottom, 10)
            }
        }
    }
}

private struct AppIconView: View {
    let path: String

    private var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: path)
    }

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill").font(.title2).foregroundStyle(.secondary)
            }
        }
    }
}

private struct AppSupportRow: View {
    let label: String
    let path: String
    let size: Int64

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption).fontWeight(.medium)
                Text(path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}
