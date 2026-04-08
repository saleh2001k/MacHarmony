//
//  ViewsDashboardView.swift
//  Detox
//

import SwiftUI
import Charts

// MARK: - Chart Entry (shared type used across views)

struct ChartEntry: Identifiable {
    let id: String
    let title: String
    let size: Int64
    let color: Color
    let icon: String
}

// MARK: - Dashboard View

struct DashboardView: View {
    @ObservedObject var storageManager: StorageManager

    @State private var diskVisible   = false
    @State private var heroVisible   = false
    @State private var statsVisible  = false
    @State private var chartVisible  = false
    @State private var listVisible   = false
    @State private var toolsVisible  = false
    @State private var trashRefreshTask: Task<Void, Never>?

    // MARK: Computed data

    private var sortedEntries: [ChartEntry] {
        var entries: [ChartEntry] = []
        for cat in storageManager.visibleCategories {
            let size = storageManager.storageItems[cat]?.reduce(0) { $0 + $1.size } ?? 0
            if size > 0 {
                entries.append(ChartEntry(id: cat.rawValue, title: cat.title,
                                          size: size, color: cat.color, icon: cat.icon))
            }
        }
        for cat in storageManager.customCategories {
            let size = storageManager.customItems[cat.id]?.reduce(0) { $0 + $1.size } ?? 0
            if size > 0 {
                entries.append(ChartEntry(id: cat.id.uuidString, title: cat.name,
                                          size: size, color: cat.color, icon: cat.icon))
            }
        }
        return entries.sorted { $0.size > $1.size }
    }

    private var chartEntries: [ChartEntry] {
        guard sortedEntries.count > 6 else { return sortedEntries }
        let otherSize = sortedEntries.dropFirst(6).reduce(0) { $0 + $1.size }
        var result = Array(sortedEntries.prefix(6))
        if otherSize > 0 {
            result.append(ChartEntry(id: "other", title: "Other", size: otherSize,
                                     color: .gray, icon: "ellipsis.circle"))
        }
        return result
    }

    private var totalItems: Int {
        storageManager.storageItems.values.reduce(0) { $0 + $1.count } +
        storageManager.customItems.values.reduce(0) { $0 + $1.count }
    }

    private var totalCleanableBytes: Int64 {
        sortedEntries.reduce(0) { $0 + $1.size }
    }

    private var healthColor: Color {
        Theme.healthColor(for: storageManager.usedPercentage)
    }

    private var sectionHeaderColor: Color {
        Color.primary.opacity(0.62)
    }

    private var healthLabel: String {
        switch storageManager.usedPercentage {
        case ..<0.6: return "Healthy"
        case ..<0.8: return "Warning"
        default:     return "Critical"
        }
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                diskSection
                    .opacity(diskVisible  ? 1 : 0)
                    .offset(y: diskVisible  ? 0 : 8)

                Divider().padding(.horizontal, 24)

                heroSection
                    .opacity(heroVisible  ? 1 : 0)
                    .offset(y: heroVisible  ? 0 : 10)

                if sortedEntries.isEmpty {
                    emptyState
                        .opacity(heroVisible ? 1 : 0)
                } else {
                    statsStrip
                        .opacity(statsVisible ? 1 : 0)
                        .offset(y: statsVisible ? 0 : 8)

                    Divider().padding(.horizontal, 24)

                    chartSection
                        .opacity(chartVisible ? 1 : 0)
                        .offset(y: chartVisible ? 0 : 8)

                    Divider().padding(.horizontal, 24)

                    categoryList
                        .opacity(listVisible  ? 1 : 0)
                        .offset(y: listVisible  ? 0 : 8)

                    Divider().padding(.horizontal, 24)

                    quickToolsSection
                        .opacity(toolsVisible ? 1 : 0)
                        .offset(y: toolsVisible ? 0 : 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.backgroundPrimary)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88))             { diskVisible  = true }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88).delay(0.07)) { heroVisible  = true }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88).delay(0.13)) { statsVisible = true }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88).delay(0.19)) { chartVisible = true }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88).delay(0.25)) { listVisible  = true }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88).delay(0.31)) { toolsVisible = true }

            trashRefreshTask?.cancel()
            trashRefreshTask = Task {
                await storageManager.refreshTrashSize()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(12))
                    if Task.isCancelled { break }
                    await storageManager.refreshTrashSize()
                }
            }
        }
        .onDisappear {
            trashRefreshTask?.cancel()
            trashRefreshTask = nil
        }
    }

    // MARK: - Disk Usage Section

    private var diskSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DISK USAGE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(sectionHeaderColor)

            DiskBarView(fraction: storageManager.usedPercentage)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int(storageManager.usedPercentage * 100))")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(healthColor)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("%")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(healthColor.opacity(0.7))
                    }
                    HStack(spacing: 5) {
                        Circle().fill(healthColor).frame(width: 6, height: 6)
                        Text(healthLabel)
                            .font(.caption)
                            .foregroundStyle(healthColor)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(storageManager.diskUsageSummary)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if let date = storageManager.lastScanDate {
                        Text("Scanned \(date.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Segmented breakdown of cleanable space
            if !sortedEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CLEANABLE BREAKDOWN")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(sectionHeaderColor.opacity(0.9))

                    SegmentedCategoryBar(entries: sortedEntries, total: totalCleanableBytes)
                }
                .padding(.top, 4)
            }
        }
        .padding(24)
    }

    // MARK: - Cleanable Hero Section

    private var heroSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                let raw   = storageManager.totalCleanableSize
                let parts = raw.split(separator: " ", maxSplits: 1)
                let value = parts.count > 0 ? String(parts[0]) : raw
                let unit  = parts.count > 1 ? String(parts[1]) : ""

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(Theme.accentGreen)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.accentGreen.opacity(0.6))
                        .padding(.bottom, 2)
                }

                Text("cleanable")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if storageManager.totalBytesFreed > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.accentGreen)
                        Text(ByteCountFormatter.string(fromByteCount: storageManager.totalBytesFreed,
                                                       countStyle: .file) + " freed this session")
                            .font(.caption)
                            .foregroundStyle(Theme.accentGreen.opacity(0.8))
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(24)
        .padding(.bottom, 4)
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "doc.fill",
                iconColor: .blue,
                value: "\(totalItems)",
                label: "Items Found"
            )
            StatCard(
                icon: "trash.fill",
                iconColor: Theme.accentAmber,
                value: {
                    if storageManager.trashAccessDenied { return "No Access" }
                    let scanned = storageManager.storageItems[.trash]?.reduce(0) { $0 + $1.size } ?? 0
                    let display = scanned > 0 ? scanned : storageManager.trashSize
                    return display > 0
                        ? ByteCountFormatter.string(fromByteCount: display, countStyle: .file)
                        : "Empty"
                }(),
                label: storageManager.trashAccessDenied ? "Tap to allow access" : "Trash",
                action: storageManager.trashAccessDenied
                    ? { storageManager.openFullDiskAccessSettings() }
                    : nil
            )
            StatCard(
                icon: "sparkles",
                iconColor: Theme.accentGreen,
                value: storageManager.totalBytesFreed > 0
                    ? ByteCountFormatter.string(fromByteCount: storageManager.totalBytesFreed, countStyle: .file)
                    : "—",
                label: "Freed"
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Distribution Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("DISTRIBUTION")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(sectionHeaderColor)

            if #available(macOS 14.0, *) {
                HStack(alignment: .top, spacing: 28) {
                    // Donut
                    Chart(chartEntries) { entry in
                        SectorMark(
                            angle: .value("Size", entry.size),
                            innerRadius: .ratio(0.66),
                            angularInset: 2.5
                        )
                        .foregroundStyle(entry.color)
                        .cornerRadius(4)
                    }
                    .chartLegend(.hidden)
                    .frame(width: 140, height: 140)
                    .overlay {
                        VStack(spacing: 3) {
                            Text(storageManager.totalCleanableSize)
                                .font(.system(size: 13, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text("cleanable")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 76)
                    }

                    // Rows
                    VStack(spacing: 10) {
                        ForEach(chartEntries) { entry in
                            DistributionRow(entry: entry, total: totalCleanableBytes)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Category List

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BREAKDOWN")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(sectionHeaderColor)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)

            ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { idx, entry in
                DashboardCategoryRow(entry: entry) {
                    withAnimation(.spring(response: 0.3)) {
                        if let cat = StorageCategory(rawValue: entry.id) {
                            storageManager.selectedCategory = cat
                            storageManager.selectedCustomCategory = nil
                        } else if let uuid = UUID(uuidString: entry.id),
                                  let cat = storageManager.customCategories.first(where: { $0.id == uuid }) {
                            storageManager.selectedCustomCategory = cat
                            storageManager.selectedCategory = nil
                        }
                    }
                }
                if idx < sortedEntries.count - 1 {
                    Divider().padding(.leading, 24)
                }
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Quick Tools Section

    private let featuredTools: [ToolType] = [
        .largeFileBrowser, .appUninstaller, .emptyFolders,
        .oldUnusedFiles, .diskHealth, .memoryMonitor
    ]

    private var quickToolsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TOOLS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(sectionHeaderColor)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(featuredTools) { tool in
                    QuickToolCard(tool: tool) {
                        withAnimation(.spring(response: 0.3)) {
                            storageManager.selectedTool = tool
                            storageManager.selectedCategory = nil
                            storageManager.selectedCustomCategory = nil
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)
            Text("No scan data")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Press Scan in the toolbar to analyze your storage.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
    }
}

// MARK: - Segmented Category Bar

private struct SegmentedCategoryBar: View {
    let entries: [ChartEntry]
    let total: Int64

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(entries.prefix(8))) { entry in
                    let fraction = total > 0 ? CGFloat(entry.size) / CGFloat(total) : 0
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(entry.color)
                        .frame(width: max(geo.size.width * fraction - 2, 4))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 5)
        .background(
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Theme.borderMedium)
        )
    }
}

// MARK: - Distribution Row

private struct DistributionRow: View {
    let entry: ChartEntry
    let total: Int64

    @State private var barWidth: CGFloat = 0

    private var fraction: Double {
        total > 0 ? Double(entry.size) / Double(total) : 0
    }

    private var pct: String {
        "\(Int((fraction * 100).rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(entry.color)
                    .frame(width: 10, height: 10)
                Text(entry.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(pct)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(entry.color)
                Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(entry.color.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(entry.color.opacity(0.75))
                        .frame(width: barWidth == 0
                               ? 0
                               : max(6, geo.size.width * fraction))
                        .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.05), value: barWidth)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        barWidth = geo.size.width
                    }
                }
            }
            .frame(height: 5)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    var action: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        let cardContent = VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(iconColor.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(action != nil ? iconColor : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered && action != nil ? Theme.backgroundElevated : Theme.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            action != nil && isHovered ? iconColor.opacity(0.3) : Theme.borderSubtle,
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")

        if let action {
            Button(action: action) { cardContent }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
        } else {
            cardContent
        }
    }
}

// MARK: - Quick Tool Card

private struct QuickToolCard: View {
    let tool: ToolType
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tool.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tool.color)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tool.color.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(tool.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? Theme.backgroundElevated : Theme.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isHovered ? tool.color.opacity(0.2) : Theme.borderSubtle, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .accessibilityLabel(tool.title)
        .accessibilityHint(tool.description)
    }
}

// MARK: - Disk Bar

private struct DiskBarView: View {
    let fraction: Double
    @State private var animatedFraction: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.borderMedium)
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.healthColor(for: fraction))
                    .frame(width: geo.size.width * animatedFraction, height: 6)
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1)) {
                animatedFraction = fraction
            }
        }
        .onChange(of: fraction) { _, newValue in
            withAnimation(.spring(response: 0.6)) { animatedFraction = newValue }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Disk usage: \(Int(fraction * 100)) percent")
    }
}

// MARK: - Category Row

private struct DashboardCategoryRow: View {
    let entry: ChartEntry
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: entry.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(entry.color)
                    .frame(width: 18)

                Text(entry.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.quaternary)
                    .frame(width: 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 11)
            .background(isHovered ? Theme.backgroundElevated : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .accessibilityLabel("\(entry.title), \(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)) cleanable")
        .accessibilityHint("Opens \(entry.title) detail view")
    }
}
