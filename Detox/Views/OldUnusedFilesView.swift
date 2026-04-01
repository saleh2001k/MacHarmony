//
//  ViewsOldUnusedFilesView.swift
//  Detox
//

import SwiftUI

struct ViewsOldUnusedFilesView: View {
    @ObservedObject var storageManager: StorageManager
    @State private var selectedMonths = 12
    @State private var selectedItems = Set<StorageItem.ID>()
    @State private var showDeleteAlert = false
    @State private var showAskAlert = false
    @AppStorage("deletionMode") private var deletionModeRaw = DeletionMode.ask.rawValue
    @AppStorage("safeModeEnabled") private var safeModeEnabled = false

    private let monthOptions = [6, 12, 24]
    private var deletionMode: DeletionMode { DeletionMode(rawValue: deletionModeRaw) ?? .ask }

    private var totalSelectedSize: Int64 {
        storageManager.oldFiles.filter { selectedItems.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 780
            VStack(spacing: 0) {
                oldFilesHeader(isCompact: isCompact)

                Divider()

            if storageManager.isOldFileScanRunning {
                ToolLoadingView(message: "Scanning for old files…")
            } else if storageManager.oldFiles.isEmpty {
                ToolEmptyView(
                    icon: ToolType.oldUnusedFiles.icon,
                    title: "No Old Files Found",
                    subtitle: "Press Scan to find files not modified in \(selectedMonths)+ months.\nUses data from your last full scan (or cached results).",
                    color: ToolType.oldUnusedFiles.color
                )
            } else {
                List(storageManager.oldFiles, selection: $selectedItems) { item in
                    OldFileRow(item: item, isSelected: selectedItems.contains(item.id))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedItems.contains(item.id) { selectedItems.remove(item.id) }
                            else { selectedItems.insert(item.id) }
                        }
                }
                .listStyle(.plain)
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .confirmationDialog("Remove \(selectedItems.count) item(s)?",
                            isPresented: $showAskAlert, titleVisibility: .visible) {
            Button("Move to Trash") { performDelete(mode: .trash) }
            Button("Delete Permanently", role: .destructive) { performDelete(mode: .permanent) }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Delete Selected Items?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { performDelete(mode: deletionMode) }
        }
    }

    @ViewBuilder
    private func oldFilesHeader(isCompact: Bool) -> some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: ToolType.oldUnusedFiles.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(ToolType.oldUnusedFiles.color)
                        .themeIconBadge(color: ToolType.oldUnusedFiles.color, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ToolType.oldUnusedFiles.title)
                            .font(.title3).fontWeight(.semibold)
                        Text("Not modified in \(selectedMonths)+ months · \(storageManager.oldFiles.count) found")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                Picker("Age", selection: $selectedMonths) {
                    ForEach(monthOptions, id: \.self) { m in
                        Text("\(m) mo").tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
                HStack(spacing: 10) {
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
                    Spacer(minLength: 0)
                    Button {
                        selectedItems.removeAll()
                        Task { await storageManager.scanOldFiles(olderThanMonths: selectedMonths) }
                    } label: {
                        if storageManager.isOldFileScanRunning {
                            HStack(spacing: 6) { IndeterminateSpinner(size: 16, color: .secondary); Text("Scanning…") }
                        } else {
                            Label(storageManager.oldFiles.isEmpty ? "Scan" : "Re-Scan", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(storageManager.isOldFileScanRunning)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()
        } else {
            HStack(spacing: 14) {
                Image(systemName: ToolType.oldUnusedFiles.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ToolType.oldUnusedFiles.color)
                    .themeIconBadge(color: ToolType.oldUnusedFiles.color, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolType.oldUnusedFiles.title)
                        .font(.title3).fontWeight(.semibold)
                    Text("Not modified in \(selectedMonths)+ months · \(storageManager.oldFiles.count) found")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Age", selection: $selectedMonths) {
                    ForEach(monthOptions, id: \.self) { m in
                        Text("\(m) months").tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 220, idealWidth: 280, maxWidth: 340)

                if !selectedItems.isEmpty {
                    Button {
                        if safeModeEnabled {
                            stageSelected()
                        } else if deletionMode == .ask {
                            showAskAlert = true
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
                    Task { await storageManager.scanOldFiles(olderThanMonths: selectedMonths) }
                } label: {
                    if storageManager.isOldFileScanRunning {
                        HStack(spacing: 6) { IndeterminateSpinner(size: 16, color: .secondary); Text("Scanning…") }
                    } else {
                        Label(storageManager.oldFiles.isEmpty ? "Scan" : "Re-Scan", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(storageManager.isOldFileScanRunning)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()
        }
    }

    private func stageSelected() {
        let items = storageManager.oldFiles.filter { selectedItems.contains($0.id) }
        storageManager.stageForDeletion(items)
        selectedItems.removeAll()
    }

    private func performDelete(mode: DeletionMode) {
        let items = storageManager.oldFiles.filter { selectedItems.contains($0.id) }
        Task {
            await storageManager.deleteOldFiles(items, mode: mode)
            selectedItems.removeAll()
        }
    }
}

private struct OldFileRow: View {
    let item: StorageItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? ToolType.oldUnusedFiles.color : .secondary)
                .animation(.spring(response: 0.2), value: isSelected)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
                Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.formattedSize).font(.caption).monospacedDigit()
                Text(item.formattedDate).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
