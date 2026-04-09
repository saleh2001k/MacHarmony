//
//  ViewsScanningView.swift
//  MacHarmony
//

import SwiftUI

// MARK: - Compact Progress Banner (shown on top while results are visible)

struct ScanProgressBanner: View {
    let progress: Double
    let currentPath: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                IndeterminateSpinner(size: 14, color: .secondary)

                Text("Scanning")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("·")
                    .foregroundStyle(.tertiary)

                Text(currentPath.isEmpty ? "Preparing…" : (currentPath as NSString).lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(Theme.accentGreen)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.15), value: progress)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)

            // Thin animated progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.borderMedium)
                    LinearGradient(
                        colors: [Theme.accentGreen.opacity(0.6), Theme.accentGreen],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * max(progress, 0.02))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 2)
        }
        .themeHeader()
    }
}

// MARK: - Full-page Scanning View (shown before any results arrive)

struct ScanningFullView: View {
    @ObservedObject var storageManager: StorageManager

    @State private var rotationAngle: Double = 0
    @State private var pulsing = false

    private let columns = [GridItem(.adaptive(minimum: 155, maximum: 210), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // ── Animated Header ──────────────────────────────────────
                VStack(spacing: 14) {
                    ZStack {
                        // Pulsing rings
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Theme.accentGreen.opacity(0.35), Theme.accentGreen.opacity(0.08)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                                .frame(width: 58 + CGFloat(i) * 22, height: 58 + CGFloat(i) * 22)
                                .scaleEffect(pulsing ? 1.45 : 1.0)
                                .opacity(pulsing ? 0 : 0.55)
                                .animation(
                                    .easeOut(duration: 1.7)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(i) * 0.55),
                                    value: pulsing
                                )
                        }

                        // Spinning arc
                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.accentGreen.opacity(0.7), Theme.accentGreen],
                                    startPoint: .leading, endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .frame(width: 52, height: 52)
                            .rotationEffect(.degrees(rotationAngle))
                            .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: rotationAngle)

                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.accentGreen)
                    }
                    .frame(width: 120, height: 120)

                    VStack(spacing: 5) {
                        Text(storageManager.isIndexBuilding ? "Building File Index" : "Scanning your Mac")
                            .font(.title3).fontWeight(.semibold)
                            .animation(.easeInOut(duration: 0.3), value: storageManager.isIndexBuilding)

                        if storageManager.isIndexBuilding {
                            Text("\(storageManager.indexedFileCount.formatted()) files found")
                                .font(.caption).foregroundStyle(Theme.accentGreen).monospacedDigit()
                                .contentTransition(.numericText())
                                .animation(.linear(duration: 0.1), value: storageManager.indexedFileCount)
                        } else {
                            Text(storageManager.currentScanPath.isEmpty
                                 ? "Filtering categories…"
                                 : storageManager.currentScanPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 400)
                                .animation(.easeInOut(duration: 0.2), value: storageManager.currentScanPath)
                        }
                    }
                }

                // ── Category Grid ────────────────────────────────────────
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(storageManager.orderedCategories.enumerated()), id: \.element) { idx, category in
                        CategoryScanChip(
                            category: category,
                            items: storageManager.storageItems[category],
                            isScanning: storageManager.scanningCategories.contains(category),
                            accessDenied: category == .trash && storageManager.trashAccessDenied,
                            appearDelay: Double(idx) * 0.04
                        )
                    }
                }

                // ── Progress Bar ─────────────────────────────────────────
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Theme.borderMedium)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Theme.accentGreen.opacity(0.7), Theme.accentGreen],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: max(8, geo.size.width * storageManager.scanProgress))
                                .shadow(color: Theme.accentGreenGlow, radius: 4, y: 2)
                                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: storageManager.scanProgress)
                        }
                    }
                    .frame(width: 320, height: 7)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    let remaining = storageManager.scanningCategories.count
                    Text(storageManager.isIndexBuilding
                         ? "Indexing files, this only happens once per scan…"
                         : (remaining == 0 ? "Finishing up…" : "\(Int(storageManager.scanProgress * 100))%  ·  \(remaining) categor\(remaining == 1 ? "y" : "ies") remaining"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.15), value: storageManager.scanProgress)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            pulsing = true
            rotationAngle = 360
        }
    }
}

// MARK: - Category Scan Chip

private struct CategoryScanChip: View {
    let category: StorageCategory
    let items: [StorageItem]?
    let isScanning: Bool
    var accessDenied: Bool = false
    let appearDelay: Double

    private var isDone: Bool { items != nil }
    private var itemCount: Int { items?.count ?? 0 }
    private var totalSize: Int64 { items?.reduce(0) { $0 + $1.size } ?? 0 }

    @State private var appeared = false

    private var accessibilityChipLabel: String {
        if accessDenied { return "\(category.title): permission needed" }
        if isDone {
            if itemCount > 0 {
                return "\(category.title): \(itemCount) item\(itemCount == 1 ? "" : "s"), \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))"
            }
            return "\(category.title): nothing found"
        }
        return "\(category.title): \(isScanning ? "scanning" : "waiting")"
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                if isScanning && !isDone {
                    IndeterminateSpinner(size: 18, color: category.color)
                        .themeIconBadge(color: category.color, size: 34)
                } else if accessDenied {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.orange)
                        .themeIconBadge(color: .orange, size: 34)
                } else {
                    Image(systemName: category.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(category.color.opacity(isDone ? 1.0 : 0.3))
                        .themeIconBadge(color: category.color, size: 34)
                }
            }
            .animation(.spring(response: 0.3), value: isDone)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(isDone ? .primary : .secondary)

                Group {
                    if isDone {
                        if accessDenied {
                            Text("Permission needed")
                                .foregroundStyle(Color.orange)
                        } else {
                            let statusText: String = {
                                if itemCount > 0 {
                                    return "\(itemCount) · \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))"
                                }
                                if category == .trash {
                                    return "Checking access…"
                                }
                                return "Nothing found"
                            }()

                            Text(statusText)
                                .foregroundStyle(itemCount == 0 ? Color.secondary : category.color)
                        }
                    } else {
                        Text(isScanning ? "Scanning…" : "Waiting…")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption2)
                .lineLimit(1)
                .animation(.easeInOut(duration: 0.2), value: isDone)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.backgroundCard,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isDone ? category.color.opacity(0.25) : Theme.borderSubtle,
                    lineWidth: 1
                )
                .animation(.easeInOut(duration: 0.3), value: isDone)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityChipLabel)
        .scaleEffect(appeared ? 1 : 0.88)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(appearDelay)) {
                appeared = true
            }
        }
    }
}
