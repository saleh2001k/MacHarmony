//
//  ViewsStartupItemsView.swift
//  MacHarmony
//

import SwiftUI

struct ViewsStartupItemsView: View {
    @ObservedObject var storageManager: StorageManager

    private var enabledCount: Int { storageManager.startupItems.filter(\.isEnabled).count }
    private var disabledCount: Int { storageManager.startupItems.filter { !$0.isEnabled }.count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: ToolType.startupItems.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ToolType.startupItems.color)
                    .themeIconBadge(color: ToolType.startupItems.color, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolType.startupItems.title).font(.title3).fontWeight(.semibold)
                    if storageManager.startupItems.isEmpty {
                        Text("Login Items and Launch Agents")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("\(enabledCount) enabled · \(disabledCount) disabled")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    Task { await storageManager.scanStartupItems() }
                } label: {
                    if storageManager.isStartupScanRunning {
                        HStack(spacing: 6) { IndeterminateSpinner(size: 16, color: .secondary); Text("Scanning…") }
                    } else {
                        Label(storageManager.startupItems.isEmpty ? "Scan" : "Re-Scan", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(storageManager.isStartupScanRunning)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()

            Divider()

            if storageManager.isStartupScanRunning {
                ToolLoadingView(message: "Reading Launch Agents and Daemons…")
            } else if storageManager.startupItems.isEmpty {
                ToolEmptyView(
                    icon: ToolType.startupItems.icon,
                    title: "No Startup Items Found",
                    subtitle: "Press Scan to read ~/Library/LaunchAgents\nand /Library/LaunchAgents.",
                    color: ToolType.startupItems.color
                )
            } else {
                startupList
            }
        }
    }

    private var startupList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                startupSection(
                    title: "User Launch Agents",
                    items: storageManager.startupItems.filter { $0.source == .userLaunchAgent }
                )
                startupSection(
                    title: "System Launch Agents",
                    items: storageManager.startupItems.filter { $0.source == .systemLaunchAgent }
                )
                startupSection(
                    title: "System Launch Daemons",
                    items: storageManager.startupItems.filter { $0.source == .systemLaunchDaemon }
                )
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func startupSection(title: String, items: [StartupItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        StartupItemRow(item: item, storageManager: storageManager)
                        if idx < items.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.borderSubtle, lineWidth: 1))
            }
        }
    }
}

// MARK: - Startup Item Row

private struct StartupItemRow: View {
    let item: StartupItem
    @ObservedObject var storageManager: StorageManager
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isEnabled ? "bolt.fill" : "bolt.slash.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(item.isEnabled ? ToolType.startupItems.color : Color.secondary)
                .themeIconBadge(color: item.isEnabled ? ToolType.startupItems.color : Color.secondary, size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: .medium))
                if let prog = item.programPath {
                    Text(prog).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text(item.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Spacer()

            if !item.runAtLoad {
                Text("On-demand")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.borderMedium, in: Capsule())
            }

            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { newVal in
                    Task {
                        if newVal {
                            await storageManager.enableStartupItem(item)
                        } else {
                            await storageManager.disableStartupItem(item)
                        }
                    }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(ToolType.startupItems.color)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(isHovered ? Theme.backgroundElevated : Color.clear)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
