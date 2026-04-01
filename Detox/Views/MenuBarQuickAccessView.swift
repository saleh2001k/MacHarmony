//
//  ViewsMenuBarQuickAccessView.swift
//  Detox
//

import SwiftUI
import AppKit

struct MenuBarQuickAccessView: View {
    @EnvironmentObject var storageManager: StorageManager
    @State private var isScanning = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Disk Usage Header ─────────────────────────────────────
                MenuBarDiskHeader(storageManager: storageManager)
                    .padding(.bottom, 10)

                MenuDivider()

                // ── Quick Stats Row ───────────────────────────────────────
                MenuBarStatsRow(storageManager: storageManager)
                    .padding(.vertical, 10)

                MenuDivider()

                // ── Top Categories ────────────────────────────────────────
                MenuBarTopCategories(storageManager: storageManager)
                    .padding(.vertical, 10)

                MenuDivider()

                // ── Show / Hide Categories ────────────────────────────────
                MenuBarCategoryToggles(storageManager: storageManager)
                    .padding(.vertical, 10)

                MenuDivider()

                // ── Actions ───────────────────────────────────────────────
                MenuBarActions(isScanning: $isScanning, storageManager: storageManager)
                    .padding(.top, 10)
            }
            .padding(14)
        }
        .frame(width: 320, height: min(620, NSScreen.main.map { $0.visibleFrame.height * 0.8 } ?? 580))
    }
}

// MARK: - Divider helper

private struct MenuDivider: View {
    var body: some View {
        Divider().opacity(0.5)
    }
}

// MARK: - Disk Usage Header

private struct MenuBarDiskHeader: View {
    @ObservedObject var storageManager: StorageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: storageManager.usedPercentage)
                        .stroke(
                            storageManager.usedPercentage > 0.85
                                ? LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Theme.accentGreen.opacity(0.7), Theme.accentGreen], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8), value: storageManager.usedPercentage)
                    Text("\(Int(storageManager.usedPercentage * 100))%")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac Storage")
                        .font(.subheadline).fontWeight(.semibold)
                    Text(storageManager.diskUsageSummary)
                        .font(.caption).foregroundStyle(.secondary)
                    if let date = storageManager.lastScanDate {
                        Text("Scanned \(date.formatted(.relative(presentation: .named)))")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
        }
    }
}

// MARK: - Stats Row

private struct MenuBarStatsRow: View {
    @ObservedObject var storageManager: StorageManager

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                MenuStatChip(
                    icon: "sparkles",
                    value: storageManager.totalCleanableSize,
                    label: "Cleanable",
                    color: Theme.accentGreen
                )

                let totalItems = storageManager.storageItems.values.reduce(0) { $0 + $1.count }
                    + storageManager.customItems.values.reduce(0) { $0 + $1.count }
                MenuStatChip(
                    icon: "doc.on.doc.fill",
                    value: "\(totalItems)",
                    label: "Items",
                    color: .purple
                )
            }
            HStack(spacing: 8) {
                if storageManager.trashSize > 0 {
                    MenuStatChip(
                        icon: "trash.fill",
                        value: ByteCountFormatter.string(fromByteCount: storageManager.trashSize, countStyle: .file),
                        label: "In Trash",
                        color: .red
                    )
                }
                if storageManager.totalBytesFreed > 0 {
                    MenuStatChip(
                        icon: "checkmark.circle.fill",
                        value: ByteCountFormatter.string(fromByteCount: storageManager.totalBytesFreed, countStyle: .file),
                        label: "Space Freed",
                        color: .green
                    )
                }
            }
        }
    }
}

private struct MenuStatChip: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption).fontWeight(.semibold).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
                Text(label)
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Top Categories

private struct MenuBarTopCategories: View {
    @ObservedObject var storageManager: StorageManager

    private var topCategories: [(StorageCategory, Int64)] {
        storageManager.visibleCategories
            .compactMap { category -> (StorageCategory, Int64)? in
                let size = storageManager.storageItems[category]?.reduce(0) { $0 + $1.size } ?? 0
                return size > 0 ? (category, size) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Top Categories", systemImage: "chart.bar.fill")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)

            if topCategories.isEmpty {
                Text("No scan data yet")
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                ForEach(topCategories, id: \.0) { category, size in
                    HStack(spacing: 8) {
                        Image(systemName: category.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(category.color)
                            .themeIconBadge(color: category.color, size: 22)
                        Text(category.title)
                            .font(.subheadline)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
        }
    }
}

// MARK: - Category Toggles

private struct MenuBarCategoryToggles: View {
    @ObservedObject var storageManager: StorageManager
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.35)) { expanded.toggle() }
            } label: {
                HStack {
                    Label("Show / Hide Categories", systemImage: "eye")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 2) {
                    ForEach(storageManager.orderedCategories) { category in
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(category.color.opacity(0.12))
                                    .frame(width: 20, height: 20)
                                Image(systemName: category.icon)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(category.color)
                            }
                            Text(category.title)
                                .font(.caption)
                                .foregroundStyle(storageManager.isCategoryHidden(category) ? .secondary : .primary)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { !storageManager.isCategoryHidden(category) },
                                set: { _ in
                                    withAnimation { storageManager.toggleCategoryVisibility(category) }
                                }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Actions

private struct MenuBarActions: View {
    @Binding var isScanning: Bool
    @ObservedObject var storageManager: StorageManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 6) {
            Button {
                Task {
                    isScanning = true
                    await storageManager.scan()
                    isScanning = false
                }
            } label: {
                HStack {
                    if isScanning {
                        IndeterminateSpinner(size: 16, color: .secondary)
                        Text("Scanning… \(Int(storageManager.scanProgress * 100))%")
                    } else {
                        Image(systemName: "arrow.clockwise")
                        Text("Scan Now")
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accentGreen)
            .disabled(isScanning)

            HStack(spacing: 6) {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    HStack {
                        Image(systemName: "macwindow")
                        Text("Open")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    NSApp.terminate(nil)
                } label: {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accentRed)
            }
        }
    }
}
