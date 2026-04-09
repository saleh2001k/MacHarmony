//
//  ViewsMenuBarQuickAccessView.swift
//  MacHarmony
//

import SwiftUI
import AppKit

struct MenuBarQuickAccessView: View {
    @EnvironmentObject var storageManager: StorageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Disk Usage Header ─────────────────────────────────────
            MenuBarDiskHeader(storageManager: storageManager)
                .padding(.bottom, 10)

            MenuDivider()

            if storageManager.isMenuBarScanRunning {
                // ── Scan Progress ─────────────────────────────────────
                MenuBarScanProgress(storageManager: storageManager)
                    .padding(.vertical, 10)
            } else {
                // ── Menu Bar Categories ───────────────────────────────
                MenuBarTopCategories(storageManager: storageManager)
                    .padding(.vertical, 10)
            }

            MenuDivider()

            // ── Actions ───────────────────────────────────────────────
            MenuBarActions(storageManager: storageManager)
                .padding(.top, 10)
        }
        .padding(14)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
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

// MARK: - Scan Progress

private struct MenuBarScanProgress: View {
    @ObservedObject var storageManager: StorageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                IndeterminateSpinner(size: 13, color: Theme.accentGreen)
                Text(storageManager.isIndexBuilding ? "Building index…" : "Scanning…")
                    .font(.caption).fontWeight(.semibold)
                Spacer()
                Text("\(Int(storageManager.scanProgress * 100))%")
                    .font(.caption).fontWeight(.semibold).monospacedDigit()
                    .foregroundStyle(Theme.accentGreen)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.15), value: storageManager.scanProgress)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Theme.accentGreen.opacity(0.7), Theme.accentGreen],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: max(6, geo.size.width * storageManager.scanProgress))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: storageManager.scanProgress)
                }
            }
            .frame(height: 5)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            if !storageManager.currentScanPath.isEmpty {
                Text((storageManager.currentScanPath as NSString).lastPathComponent)
                    .font(.caption2).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
        }
    }
}

// MARK: - Top Categories

private let xcodeExpandableCategories: Set<StorageCategory> = [
    .xcodeDerivedData, .xcodeArchives, .xcodeDeviceSupport
]

private struct MenuBarTopCategories: View {
    @ObservedObject var storageManager: StorageManager

    private var topCategories: [(StorageCategory, Int64)] {
        storageManager.menuBarVisibleCategories
            .compactMap { category -> (StorageCategory, Int64)? in
                let size = storageManager.storageItems[category]?.reduce(0) { $0 + $1.size } ?? 0
                return (category, size)
            }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Menu Categories", systemImage: "chart.bar.fill")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)

            if storageManager.menuBarVisibleCategories.isEmpty {
                Text("No categories selected — tap Customize Menu")
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                ForEach(topCategories, id: \.0) { category, size in
                    if xcodeExpandableCategories.contains(category) {
                        MenuBarXcodeSection(storageManager: storageManager, category: category)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(category.color)
                                .themeIconBadge(color: category.color, size: 22)
                            Text(category.title)
                                .font(.subheadline)
                            Spacer()
                            if size > 0 {
                                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(.secondary).monospacedDigit()
                            } else {
                                Text("Not scanned")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Xcode Expandable Section

private struct MenuBarXcodeSection: View {
    @ObservedObject var storageManager: StorageManager
    let category: StorageCategory

    @State private var isExpanded = true
    @State private var selectedIDs: Set<UUID> = []
    @State private var isDeleting = false

    private var items: [StorageItem] {
        (storageManager.storageItems[category] ?? []).sorted { $0.size > $1.size }
    }

    private var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    private var selectedItems: [StorageItem] { items.filter { selectedIDs.contains($0.id) } }

    /// For DerivedData, strip the trailing `-xxxxxxxx` build hash from folder names.
    private func displayName(for item: StorageItem) -> String {
        guard category == .xcodeDerivedData else { return item.name }
        // Format: "ProjectName-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" — strip the last hyphen+hex segment
        let name = item.name
        if let range = name.range(of: #"-[0-9a-z]{16,}$"#, options: .regularExpression) {
            return String(name[name.startIndex..<range.lowerBound])
        }
        return name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──────────────────────────────────────────────
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 10)

                    Image(systemName: category.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(category.color)
                        .themeIconBadge(color: category.color, size: 22)

                    Text(category.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()

                    if totalSize > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(.secondary).monospacedDigit()
                    } else {
                        Text("Not scanned")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category.title), \(isExpanded ? "expanded" : "collapsed")")

            // ── Expanded Items ───────────────────────────────────────
            if isExpanded && !items.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(items) { item in
                        let selected = selectedIDs.contains(item.id)
                        Button {
                            if selected { selectedIDs.remove(item.id) }
                            else { selectedIDs.insert(item.id) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selected ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 12))
                                    .foregroundStyle(selected ? category.color : Color.secondary.opacity(0.6))

                                Text(displayName(for: item))
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer(minLength: 4)

                                Text(item.formattedSize)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(
                                selected ? category.color.opacity(0.08) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 18)

                // ── Delete Buttons ───────────────────────────────────
                HStack(spacing: 6) {
                    if !selectedItems.isEmpty {
                        Button {
                            let toDelete = selectedItems
                            Task {
                                isDeleting = true
                                await storageManager.deleteItems(toDelete, from: category)
                                selectedIDs = []
                                isDeleting = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if isDeleting { ProgressView().scaleEffect(0.6) }
                                Text("Delete Selected (\(selectedItems.count))")
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.accentRed)
                        .controlSize(.small)
                        .disabled(isDeleting)
                    }

                    Button {
                        let all = items
                        Task {
                            isDeleting = true
                            await storageManager.deleteItems(all, from: category)
                            selectedIDs = []
                            isDeleting = false
                        }
                    } label: {
                        Text(selectedItems.isEmpty ? "Delete All" : "All")
                            .frame(maxWidth: selectedItems.isEmpty ? .infinity : nil)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accentRed)
                    .controlSize(.small)
                    .disabled(isDeleting)
                }
                .padding(.top, 8)
                .padding(.leading, 18)
            }
        }
    }
}

// MARK: - Actions

private struct MenuBarActions: View {
    @ObservedObject var storageManager: StorageManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @AppStorage("settingsSelectedTab") private var settingsSelectedTab = "general"

    var body: some View {
        VStack(spacing: 6) {
            Button {
                Task { await storageManager.scanMenuBarCategories() }
            } label: {
                HStack {
                    if storageManager.isMenuBarScanRunning {
                        IndeterminateSpinner(size: 14, color: .white)
                        Text("Scanning… \(Int(storageManager.scanProgress * 100))%")
                            .monospacedDigit()
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
            .disabled(storageManager.isMenuBarScanRunning)
            .accessibilityLabel(storageManager.isMenuBarScanRunning ? "Scanning in progress" : "Scan now")
            .accessibilityHint("Scans selected menu bar categories")

            Button {
                settingsSelectedTab = "menubar"
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Customize Menu")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Customize menu bar categories")

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
                .accessibilityLabel("Open MacHarmony main window")

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
                .accessibilityLabel("Quit MacHarmony")
            }

            Divider().opacity(0.5).padding(.vertical, 2)

            // About / Bug / Feature / Contact quick links
            HStack(spacing: 6) {
                MenuBarAboutButton(icon: "info.circle", label: "About", windowID: "about")
                MenuBarAboutButton(icon: "ant", label: "Report Bug", windowID: "about")
                MenuBarAboutButton(icon: "lightbulb", label: "Suggest", windowID: "about")
                MenuBarAboutButton(icon: "envelope", label: "Contact", windowID: "about")
            }
        }
    }
}

// MARK: - About Quick Button

private struct MenuBarAboutButton: View {
    let icon: String
    let label: String
    let windowID: String
    @Environment(\.openWindow) private var openWindow
    @State private var isHovered = false

    var body: some View {
        Button {
            openWindow(id: "about")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(isHovered ? .primary : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? Theme.backgroundElevated : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .accessibilityLabel(label)
    }
}
