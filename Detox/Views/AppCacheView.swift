//
//  ViewsAppCacheView.swift
//  Detox
//

import SwiftUI

struct ViewsAppCacheView: View {
    @ObservedObject var storageManager: StorageManager
    @State private var selectedItems = Set<StorageItem.ID>()
    @State private var showDeleteAlert = false
    @State private var showAskAlert = false
    @AppStorage("deletionMode") private var deletionModeRaw = DeletionMode.ask.rawValue
    @AppStorage("safeModeEnabled") private var safeModeEnabled = false

    private var deletionMode: DeletionMode { DeletionMode(rawValue: deletionModeRaw) ?? .ask }

    private var totalSize: Int64 {
        storageManager.appCacheItems.reduce(0) { $0 + $1.size }
    }

    private var totalSelectedSize: Int64 {
        storageManager.appCacheItems.filter { selectedItems.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: ToolType.appCacheBreakdown.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ToolType.appCacheBreakdown.color)
                    .themeIconBadge(color: ToolType.appCacheBreakdown.color, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolType.appCacheBreakdown.title).font(.title3).fontWeight(.semibold)
                    if storageManager.appCacheItems.isEmpty {
                        Text("Per-app breakdown of ~/Library/Caches")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("\(storageManager.appCacheItems.count) entries · \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)) total")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !storageManager.appCacheItems.isEmpty {
                    Button { selectedItems = Set(storageManager.appCacheItems.map(\.id)) } label: {
                        Text("Select All")
                    }
                    .buttonStyle(.bordered)
                }

                if !selectedItems.isEmpty {
                    Button {
                        if safeModeEnabled { stageSelected() }
                        else if deletionMode == .ask { showAskAlert = true }
                        else { showDeleteAlert = true }
                    } label: {
                        Label(safeModeEnabled ? "Stage (\(selectedItems.count))" : "Delete (\(selectedItems.count))",
                              systemImage: safeModeEnabled ? "checkmark.circle.fill" : "trash")
                    }
                    .buttonStyle(ThemePrimaryButton(color: safeModeEnabled ? Theme.accentAmber : Theme.accentRed))
                }

                Button {
                    selectedItems.removeAll()
                    Task { await storageManager.scanAppCaches() }
                } label: {
                    if storageManager.isAppCacheScanRunning {
                        HStack(spacing: 6) { IndeterminateSpinner(size: 16, color: .secondary); Text("Scanning…") }
                    } else {
                        Label(storageManager.appCacheItems.isEmpty ? "Scan" : "Re-Scan", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(storageManager.isAppCacheScanRunning)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()

            Divider()

            if storageManager.isAppCacheScanRunning {
                ToolLoadingView(message: "Scanning ~/Library/Caches…")
            } else if storageManager.appCacheItems.isEmpty {
                ToolEmptyView(
                    icon: ToolType.appCacheBreakdown.icon,
                    title: "No Cache Entries Found",
                    subtitle: "Press Scan to see a breakdown of\n~/Library/Caches by app.",
                    color: ToolType.appCacheBreakdown.color
                )
            } else {
                List(storageManager.appCacheItems, selection: $selectedItems) { item in
                    AppCacheRow(item: item, isSelected: selectedItems.contains(item.id), maxSize: storageManager.appCacheItems.first?.size ?? 1)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedItems.contains(item.id) { selectedItems.remove(item.id) }
                            else { selectedItems.insert(item.id) }
                        }
                }
                .listStyle(.plain)
            }
        }
        .confirmationDialog("Remove \(selectedItems.count) cache entr\(selectedItems.count == 1 ? "y" : "ies")?",
                            isPresented: $showAskAlert, titleVisibility: .visible) {
            Button("Move to Trash") { performDelete(mode: .trash) }
            Button("Delete Permanently", role: .destructive) { performDelete(mode: .permanent) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file) + " will be freed")
        }
        .alert("Delete Cache?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { performDelete(mode: deletionMode) }
        }
    }

    private func stageSelected() {
        let items = storageManager.appCacheItems.filter { selectedItems.contains($0.id) }
        storageManager.stageForDeletion(items)
        selectedItems.removeAll()
    }

    private func performDelete(mode: DeletionMode) {
        let items = storageManager.appCacheItems.filter { selectedItems.contains($0.id) }
        Task {
            await storageManager.deleteAppCacheItems(items, mode: mode)
            selectedItems.removeAll()
        }
    }
}

private struct AppCacheRow: View {
    let item: StorageItem
    let isSelected: Bool
    let maxSize: Int64
    @State private var isHovered = false

    private var fraction: Double {
        maxSize > 0 ? Double(item.size) / Double(maxSize) : 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? ToolType.appCacheBreakdown.color : .secondary)
                .animation(.spring(response: 0.2), value: isSelected)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Theme.borderMedium).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ToolType.appCacheBreakdown.color.opacity(0.8))
                            .frame(width: geo.size.width * fraction, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()
            Text(item.formattedSize)
                .font(.caption).monospacedDigit().fontWeight(.medium)
        }
        .padding(.vertical, 6)
        .background(isHovered ? Theme.backgroundElevated : Color.clear)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
