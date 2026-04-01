//
//  ViewsiCloudCleanerView.swift
//  Detox
//

import SwiftUI

struct ViewsiCloudCleanerView: View {
    @ObservedObject var storageManager: StorageManager
    @State private var selectedItems = Set<StorageItem.ID>()
    @State private var showEvictAlert = false

    private var totalSelectedSize: Int64 {
        storageManager.iCloudItems.filter { selectedItems.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    private var totalReclaimable: Int64 {
        storageManager.iCloudItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: ToolType.iCloudCleaner.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ToolType.iCloudCleaner.color)
                    .themeIconBadge(color: ToolType.iCloudCleaner.color, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolType.iCloudCleaner.title).font(.title3).fontWeight(.semibold)
                    if storageManager.iCloudItems.isEmpty {
                        Text("Files already backed up to iCloud")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("\(storageManager.iCloudItems.count) files · \(ByteCountFormatter.string(fromByteCount: totalReclaimable, countStyle: .file)) reclaimable")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !selectedItems.isEmpty {
                    Button {
                        showEvictAlert = true
                    } label: {
                        Label("Optimize (\(selectedItems.count))", systemImage: "icloud.and.arrow.up")
                    }
                    .buttonStyle(ThemePrimaryButton(color: ToolType.iCloudCleaner.color))
                }

                Button {
                    selectedItems.removeAll()
                    Task { await storageManager.scanICloudItems() }
                } label: {
                    if storageManager.isICloudScanRunning {
                        HStack(spacing: 6) { IndeterminateSpinner(size: 16, color: .secondary); Text("Scanning…") }
                    } else {
                        Label(storageManager.iCloudItems.isEmpty ? "Scan" : "Re-Scan", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(storageManager.isICloudScanRunning)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()

            Divider()

            // Explanation banner
            HStack(spacing: 10) {
                Image(systemName: "info.circle").foregroundStyle(ToolType.iCloudCleaner.color)
                Text("\"Optimize\" removes the local copy of files that are already uploaded to iCloud. Files re-download automatically when you open them — no data is lost.")
                    .font(.caption)
            }
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(ToolType.iCloudCleaner.color.opacity(0.06))
            Divider()

            if storageManager.isICloudScanRunning {
                ToolLoadingView(message: "Checking Downloads, Desktop, Documents for iCloud files…")
            } else if storageManager.iCloudItems.isEmpty {
                ToolEmptyView(
                    icon: ToolType.iCloudCleaner.icon,
                    title: "No iCloud Files Found",
                    subtitle: "Press Scan to find large files in Downloads,\nDesktop, and Documents that are already in iCloud.",
                    color: ToolType.iCloudCleaner.color
                )
            } else {
                List(storageManager.iCloudItems, selection: $selectedItems) { item in
                    ICloudItemRow(item: item, isSelected: selectedItems.contains(item.id))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedItems.contains(item.id) { selectedItems.remove(item.id) }
                            else { selectedItems.insert(item.id) }
                        }
                }
                .listStyle(.plain)
            }
        }
        .alert("Optimize Local Storage?", isPresented: $showEvictAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Optimize", role: .destructive) {
                let items = storageManager.iCloudItems.filter { selectedItems.contains($0.id) }
                selectedItems.removeAll()
                Task {
                    for item in items {
                        await storageManager.evictFromLocal(item)
                    }
                }
            }
        } message: {
            Text("This will remove the local copies of \(selectedItems.count) file(s) totaling \(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)). Files remain safely in iCloud and re-download when accessed.")
        }
    }
}

private struct ICloudItemRow: View {
    let item: StorageItem
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? ToolType.iCloudCleaner.color : .secondary)
                .animation(.spring(response: 0.2), value: isSelected)

            Image(systemName: "icloud.fill")
                .font(.system(size: 14))
                .foregroundStyle(ToolType.iCloudCleaner.color.opacity(0.8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
                Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.formattedSize).font(.caption).monospacedDigit().fontWeight(.medium)
                Text(item.formattedDate).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
        .background(isHovered ? Theme.backgroundElevated : Color.clear)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
