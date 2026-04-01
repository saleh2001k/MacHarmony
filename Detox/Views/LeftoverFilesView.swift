//
//  ViewsLeftoverFilesView.swift
//  Detox
//

import SwiftUI

struct ViewsLeftoverFilesView: View {
    @ObservedObject var storageManager: StorageManager
    @State private var selectedItems = Set<StorageItem.ID>()
    @State private var showDeleteAlert = false
    @State private var showAskAlert = false
    @AppStorage("deletionMode") private var deletionModeRaw = DeletionMode.ask.rawValue
    @AppStorage("safeModeEnabled") private var safeModeEnabled = false

    private var deletionMode: DeletionMode { DeletionMode(rawValue: deletionModeRaw) ?? .ask }

    private var totalSelectedSize: Int64 {
        storageManager.leftoverItems.filter { selectedItems.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    private var totalSize: Int64 {
        storageManager.leftoverItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: ToolType.leftoverFiles.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ToolType.leftoverFiles.color)
                    .themeIconBadge(color: ToolType.leftoverFiles.color, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolType.leftoverFiles.title).font(.title3).fontWeight(.semibold)
                    if storageManager.leftoverItems.isEmpty {
                        Text("Orphaned support files from deleted apps")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("\(storageManager.leftoverItems.count) orphaned items · \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !storageManager.leftoverItems.isEmpty {
                    Button { selectedItems = Set(storageManager.leftoverItems.map(\.id)) } label: {
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
                    Task {
                        if storageManager.appEntries.isEmpty {
                            await storageManager.scanApps()
                        }
                        await storageManager.scanLeftovers()
                    }
                } label: {
                    if storageManager.isLeftoverScanRunning {
                        HStack(spacing: 6) { IndeterminateSpinner(size: 16, color: .secondary); Text("Scanning…") }
                    } else {
                        Label(storageManager.leftoverItems.isEmpty ? "Scan" : "Re-Scan", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(storageManager.isLeftoverScanRunning)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()

            Divider()

            if storageManager.isLeftoverScanRunning {
                ToolLoadingView(message: "Looking for orphaned support files…")
            } else if storageManager.leftoverItems.isEmpty {
                ToolEmptyView(
                    icon: ToolType.leftoverFiles.icon,
                    title: "No Leftovers Found",
                    subtitle: "Press Scan to search for bundle-ID-shaped folders\nin Library that don't match any installed app.\nNote: requires App Uninstaller scan first.",
                    color: ToolType.leftoverFiles.color
                )
            } else {
                List(storageManager.leftoverItems, selection: $selectedItems) { item in
                    LeftoverRow(item: item, isSelected: selectedItems.contains(item.id))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedItems.contains(item.id) { selectedItems.remove(item.id) }
                            else { selectedItems.insert(item.id) }
                        }
                }
                .listStyle(.plain)
            }
        }
        .confirmationDialog("Remove \(selectedItems.count) item(s)?",
                            isPresented: $showAskAlert, titleVisibility: .visible) {
            Button("Move to Trash") { performDelete(mode: .trash) }
            Button("Delete Permanently", role: .destructive) { performDelete(mode: .permanent) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file) + " will be freed")
        }
        .alert("Delete Leftover Items?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { performDelete(mode: deletionMode) }
        } message: {
            Text("Double-check these are truly orphaned before deleting.")
        }
    }

    private func stageSelected() {
        let items = storageManager.leftoverItems.filter { selectedItems.contains($0.id) }
        storageManager.stageForDeletion(items)
        selectedItems.removeAll()
    }

    private func performDelete(mode: DeletionMode) {
        let items = storageManager.leftoverItems.filter { selectedItems.contains($0.id) }
        Task {
            await storageManager.deleteLeftoverItems(items, mode: mode)
            selectedItems.removeAll()
        }
    }
}

private struct LeftoverRow: View {
    let item: StorageItem
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? ToolType.leftoverFiles.color : .secondary)
                .animation(.spring(response: 0.2), value: isSelected)

            Image(systemName: "questionmark.folder.fill")
                .font(.system(size: 14))
                .foregroundStyle(ToolType.leftoverFiles.color.opacity(0.8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
                Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(item.formattedSize).font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
        .background(isHovered ? Theme.backgroundElevated : Color.clear)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
