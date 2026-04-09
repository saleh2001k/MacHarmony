//
//  ViewsScanHistoryView.swift
//  MacHarmony
//

import SwiftUI
import Charts

struct ViewsScanHistoryView: View {
    @ObservedObject var storageManager: StorageManager

    private var totalFreed: Int64 {
        storageManager.scanHistory.reduce(0) { $0 + $1.bytesFreed }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: ToolType.scanHistory.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ToolType.scanHistory.color)
                    .themeIconBadge(color: ToolType.scanHistory.color, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolType.scanHistory.title).font(.title3).fontWeight(.semibold)
                    Text("\(storageManager.scanHistory.count) sessions recorded")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await storageManager.loadScanHistory() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()

            Divider()

            if storageManager.scanHistory.isEmpty {
                ToolEmptyView(
                    icon: ToolType.scanHistory.icon,
                    title: "No Scan History Yet",
                    subtitle: "Run a scan to start recording history.\nEach session is logged automatically.",
                    color: ToolType.scanHistory.color
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Summary cards
                        HStack(spacing: 12) {
                            HistoryStatCard(
                                value: ByteCountFormatter.string(fromByteCount: totalFreed, countStyle: .file),
                                label: "Total Freed",
                                icon: "checkmark.circle.fill",
                                color: Theme.accentGreen
                            )
                            HistoryStatCard(
                                value: "\(storageManager.scanHistory.count)",
                                label: "Scans Run",
                                icon: "arrow.clockwise.circle.fill",
                                color: ToolType.scanHistory.color
                            )
                            if let last = storageManager.scanHistory.last {
                                HistoryStatCard(
                                    value: last.formattedCleanable,
                                    label: "Last Cleanable",
                                    icon: "sparkles",
                                    color: Theme.accentAmber
                                )
                            }
                        }

                        // Cleanable size chart
                        if storageManager.scanHistory.count > 1 {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Cleanable Space Over Time", systemImage: "chart.line.uptrend.xyaxis")
                                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)

                                Chart(storageManager.scanHistory) { record in
                                    AreaMark(
                                        x: .value("Date", record.date),
                                        y: .value("Bytes", record.totalCleanableBytes)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [ToolType.scanHistory.color.opacity(0.4), ToolType.scanHistory.color.opacity(0.05)],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                                    LineMark(
                                        x: .value("Date", record.date),
                                        y: .value("Bytes", record.totalCleanableBytes)
                                    )
                                    .foregroundStyle(ToolType.scanHistory.color)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisValueLabel {
                                            if let bytes = value.as(Int64.self) {
                                                Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 180)
                            }
                            .themeCard()
                        }

                        // Session list
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Sessions", systemImage: "list.bullet")
                                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)

                            VStack(spacing: 0) {
                                ForEach(Array(storageManager.scanHistory.reversed().enumerated()), id: \.element.id) { idx, record in
                                    ScanSessionRow(record: record)
                                    if idx < storageManager.scanHistory.count - 1 {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.borderSubtle, lineWidth: 1))
                        }
                    }
                    .padding(24)
                }
            }
        }
        .task { await storageManager.loadScanHistory() }
    }
}

// MARK: - Scan Session Row

private struct ScanSessionRow: View {
    let record: ScanRecord

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline).fontWeight(.medium)
                Text("\(record.formattedCleanable) cleanable · \(Int(record.usedFraction * 100))% disk used")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(record.formattedBytesFreed)
                .font(.caption).monospacedDigit()
                .foregroundStyle(record.bytesFreed > 0 ? Theme.accentGreen : .secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// MARK: - History Stat Card

private struct HistoryStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .themeIconBadge(color: color, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.title3).fontWeight(.bold).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(padding: 14, cornerRadius: 12)
    }
}
