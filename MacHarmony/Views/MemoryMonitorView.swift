//
//  ViewsMemoryMonitorView.swift
//  MacHarmony
//

import SwiftUI

struct ViewsMemoryMonitorView: View {
    @ObservedObject var storageManager: StorageManager
    @State private var refreshTimer: Timer?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: ToolType.memoryMonitor.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ToolType.memoryMonitor.color)
                    .themeIconBadge(color: ToolType.memoryMonitor.color, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolType.memoryMonitor.title).font(.title3).fontWeight(.semibold)
                    if let stats = storageManager.memoryStats {
                        Text("Physical memory: \(stats.formatted(stats.totalBytes)) · \(Int(stats.usedFraction * 100))% used")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Real-time RAM usage monitor").font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    storageManager.releaseMemory()
                } label: {
                    HStack(spacing: 8) {
                        if storageManager.memoryReleaseUIState == .working {
                            IndeterminateSpinner(size: 16, color: .primary)
                        }
                        Label("Free Inactive Memory", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(ThemePrimaryButton(color: ToolType.memoryMonitor.color))
                .disabled(storageManager.memoryReleaseUIState == .working)

                Button {
                    storageManager.refreshMemoryStats()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()

            Divider()

            if let stats = storageManager.memoryStats {
                ScrollView {
                    VStack(spacing: 20) {
                        // Ring
                        MemoryRingView(stats: stats)
                            .frame(width: 200, height: 200)
                            .padding(.top, 20)

                        // Breakdown cards
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MemoryStatCard(label: "Wired", bytes: stats.wiredBytes, color: .red, total: stats.totalBytes)
                            MemoryStatCard(label: "Active", bytes: stats.activeBytes, color: .orange, total: stats.totalBytes)
                            MemoryStatCard(label: "Inactive", bytes: stats.inactiveBytes, color: .yellow, total: stats.totalBytes)
                            MemoryStatCard(label: "Compressed", bytes: stats.compressedBytes, color: .purple, total: stats.totalBytes)
                            MemoryStatCard(label: "Free", bytes: stats.freeBytes, color: ToolType.memoryMonitor.color, total: stats.totalBytes)
                        }

                        Text("\"Free Inactive Memory\" releases the malloc cache without requiring root access.\nWired memory is locked by the kernel and cannot be released.")
                            .font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(24)
                }
            } else {
                ToolEmptyView(
                    icon: ToolType.memoryMonitor.icon,
                    title: "Memory Stats Unavailable",
                    subtitle: "Could not read memory statistics.",
                    color: ToolType.memoryMonitor.color
                )
            }
            }

            if storageManager.memoryReleaseUIState == .working {
                MemoryReleaseOverlay(style: .working, message: "Releasing malloc cache…")
            } else if storageManager.memoryReleaseUIState == .success {
                MemoryReleaseOverlay(style: .success, message: "Done — stats refreshed")
            }
        }
        .animation(.easeInOut(duration: 0.25), value: storageManager.memoryReleaseUIState)
        .onAppear {
            storageManager.refreshMemoryStats()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                Task { @MainActor in
                    storageManager.refreshMemoryStats()
                }
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
}

// MARK: - Memory Ring View

private struct MemoryRingView: View {
    let stats: MemoryStats
    @State private var appeared = false

    private var segments: [(Double, Color)] {
        let t = Double(stats.totalBytes)
        guard t > 0 else { return [] }
        return [
            (Double(stats.wiredBytes) / t,      .red),
            (Double(stats.activeBytes) / t,     .orange),
            (Double(stats.compressedBytes) / t, .purple),
            (Double(stats.inactiveBytes) / t,   .yellow),
        ]
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.borderMedium, lineWidth: 16)

            ForEach(Array(segments.enumerated()), id: \.offset) { idx, seg in
                let offset = segments.prefix(idx).reduce(0) { $0 + $1.0 }
                Circle()
                    .trim(from: offset, to: offset + seg.0 * (appeared ? 1 : 0))
                    .stroke(seg.1, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(Double(idx) * 0.1), value: appeared)
            }

            VStack(spacing: 2) {
                Text("\(Int(stats.usedFraction * 100))%")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(ToolType.memoryMonitor.color)
                    .monospacedDigit()
                Text("of \(stats.formatted(stats.totalBytes))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Memory Stat Card

private struct MemoryStatCard: View {
    let label: String
    let bytes: UInt64
    let color: Color
    let total: UInt64

    private var fraction: Double { total > 0 ? Double(bytes) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.caption).fontWeight(.medium)
            }
            Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory))
                .font(.title3).fontWeight(.bold).monospacedDigit()
            Text(String(format: "%.1f%%", fraction * 100))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(padding: 14, cornerRadius: 12)
    }
}

// MARK: - Release overlay

private struct MemoryReleaseOverlay: View {
    enum Style {
        case working
        case success
    }

    let style: Style
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.22).ignoresSafeArea()
            VStack(spacing: 16) {
                if style == .working {
                    IndeterminateSpinner(size: 28, color: .secondary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.accentGreen)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(message)
                    .font(.subheadline).fontWeight(.semibold)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(minWidth: 220)
            .background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.borderSubtle, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        }
    }
}
