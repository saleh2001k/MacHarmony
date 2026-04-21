//
//  ViewsEmptyFolderView.swift
//  MacHarmony
//

import SwiftUI

struct ViewsEmptyFolderView: View {
    @ObservedObject var storageManager: StorageManager
    @State private var selectedItems = Set<StorageItem.ID>()
    @State private var showDeleteAlert = false
    @AppStorage("safeModeEnabled") private var safeModeEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: "folder.badge.minus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.teal)
                    .themeIconBadge(color: .teal, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Empty Folders")
                        .font(.title3).fontWeight(.semibold)
                    Text("\(storageManager.emptyFolders.count) empty director\(storageManager.emptyFolders.count == 1 ? "y" : "ies") found")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                if !storageManager.emptyFolders.isEmpty {
                    Button {
                        selectedItems = Set(storageManager.emptyFolders.map(\.id))
                    } label: {
                        Text("Select All")
                    }
                    .buttonStyle(.bordered)
                }

                if !selectedItems.isEmpty {
                    Button {
                        if safeModeEnabled {
                            stageSelected()
                        } else {
                            showDeleteAlert = true
                        }
                    } label: {
                        Label(safeModeEnabled ? "Stage (\(selectedItems.count))" : "Delete (\(selectedItems.count))",
                              systemImage: safeModeEnabled ? "checkmark.circle.fill" : "trash")
                    }
                    .buttonStyle(ThemePrimaryButton(color: safeModeEnabled ? Theme.accentAmber : Theme.accentRed))
                }

                Button {
                    selectedItems.removeAll()
                    Task { await storageManager.scanEmptyFolders() }
                } label: {
                    if storageManager.isEmptyFolderScanRunning {
                        HStack(spacing: 6) { IndeterminateSpinner(size: 16, color: .secondary); Text("Scanning…") }
                    } else {
                        Label(storageManager.emptyFolders.isEmpty ? "Scan" : "Re-Scan", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(storageManager.isEmptyFolderScanRunning)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()

            Divider()

            if storageManager.isEmptyFolderScanRunning {
                ToolLoadingView(message: "Scanning for empty folders…")
            } else if storageManager.emptyFolders.isEmpty {
                ToolEmptyView(
                    icon: "folder.badge.minus",
                    title: "No Empty Folders Found",
                    subtitle: "Press Scan to search for empty directories\nin your home folder.",
                    color: .teal
                )
            } else {
                List(storageManager.emptyFolders, selection: $selectedItems) { item in
                    EmptyFolderRow(item: item, isSelected: selectedItems.contains(item.id))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedItems.contains(item.id) { selectedItems.remove(item.id) }
                            else { selectedItems.insert(item.id) }
                        }
                }
                .listStyle(.plain)
            }
        }
        .alert("Delete \(selectedItems.count) Empty Folder(s)?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                let items = storageManager.emptyFolders.filter { selectedItems.contains($0.id) }
                Task {
                    await storageManager.deleteEmptyFolders(items, mode: .permanent)
                    selectedItems.removeAll()
                }
            }
        } message: {
            Text("Empty folders will be permanently removed.")
        }
    }

    private func stageSelected() {
        let items = storageManager.emptyFolders.filter { selectedItems.contains($0.id) }
        storageManager.stageForDeletion(items)
        selectedItems.removeAll()
    }
}

private struct EmptyFolderRow: View {
    let item: StorageItem
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? Color.teal : .secondary)
                .animation(.spring(response: 0.2), value: isSelected)

            Image(systemName: "folder")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.teal)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline).fontWeight(.medium)
                Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(item.formattedDate).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .background(isHovered ? Theme.backgroundElevated : Color.clear)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
