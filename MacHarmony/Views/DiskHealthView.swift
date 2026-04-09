//
//  ViewsDiskHealthView.swift
//  MacHarmony
//

import SwiftUI

struct ViewsDiskHealthView: View {
    @ObservedObject var storageManager: StorageManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: ToolType.diskHealth.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ToolType.diskHealth.color)
                    .themeIconBadge(color: ToolType.diskHealth.color, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolType.diskHealth.title).font(.title3).fontWeight(.semibold)
                    if let info = storageManager.diskHealthInfo {
                        Text(info.mediaName.isEmpty ? info.deviceName : info.mediaName)
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("SMART status, capacity, and filesystem info")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    Task { await storageManager.loadDiskHealth() }
                } label: {
                    if storageManager.isDiskHealthLoading {
                        HStack(spacing: 6) { IndeterminateSpinner(size: 16, color: .secondary); Text("Loading…") }
                    } else {
                        Label(storageManager.diskHealthInfo == nil ? "Load" : "Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(storageManager.isDiskHealthLoading)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()

            Divider()

            if storageManager.isDiskHealthLoading {
                ToolLoadingView(message: "Reading disk information…")
            } else if let info = storageManager.diskHealthInfo {
                diskInfoContent(info)
            } else {
                ToolEmptyView(
                    icon: ToolType.diskHealth.icon,
                    title: "Disk Info Not Loaded",
                    subtitle: "Press Load to read SMART status, capacity,\nand filesystem info via diskutil.",
                    color: ToolType.diskHealth.color
                )
            }
        }
        .task {
            if storageManager.diskHealthInfo == nil {
                await storageManager.loadDiskHealth()
            }
        }
    }

    private func diskInfoContent(_ info: DiskHealthInfo) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // SMART Status card
                HStack(spacing: 20) {
                    VStack {
                        Image(systemName: info.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(info.isHealthy ? Theme.accentGreen : Theme.accentRed)
                        Text(info.smartStatus)
                            .font(.headline).fontWeight(.semibold)
                            .foregroundStyle(info.isHealthy ? Theme.accentGreen : Theme.accentRed)
                        Text("SMART Status").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 80)

                    VStack(spacing: 8) {
                        DiskInfoRow(label: "Device", value: info.deviceName)
                        DiskInfoRow(label: "Filesystem", value: info.fileSystem)
                        DiskInfoRow(label: "Type", value: info.isSSD ? "SSD" : "HDD")
                        DiskInfoRow(label: "Internal", value: info.isInternal ? "Yes" : "No")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .themeCard(padding: 20, cornerRadius: 14)

                // Capacity card
                VStack(alignment: .leading, spacing: 14) {
                    Label("Capacity", systemImage: "externaldrive.fill")
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(info.formattedSize).font(.title2).fontWeight(.bold)
                            Text("Total").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(info.formattedFree).font(.title2).fontWeight(.bold).foregroundStyle(Theme.accentGreen)
                            Text("Free").font(.caption2).foregroundStyle(.secondary)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Theme.borderMedium).frame(height: 10)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(colors: [
                                        Theme.healthColor(for: info.usedFraction).opacity(0.7),
                                        Theme.healthColor(for: info.usedFraction)
                                    ], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * info.usedFraction, height: 10)
                        }
                    }
                    .frame(height: 10)

                    Text("\(Int(info.usedFraction * 100))% used · \(ByteCountFormatter.string(fromByteCount: info.diskSize - info.freeSpace, countStyle: .file)) of \(info.formattedSize)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .themeCard(padding: 20, cornerRadius: 14)
            }
            .padding(24)
        }
    }
}

private struct DiskInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
            Text(value).font(.caption).fontWeight(.medium)
        }
    }
}
