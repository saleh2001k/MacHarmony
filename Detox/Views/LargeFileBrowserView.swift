//
//  ViewsLargeFileBrowserView.swift
//  Detox
//

import SwiftUI

struct ViewsLargeFileBrowserView: View {
    @ObservedObject var storageManager: StorageManager
    @State private var minSizeGB: Double = 0.1   // default 100 MB
    @State private var selectedItems = Set<StorageItem.ID>()
    @State private var showDeleteAlert = false
    @State private var showAskAlert = false
    @State private var sliderRescanTask: Task<Void, Never>?
    @AppStorage("deletionMode") private var deletionModeRaw = DeletionMode.ask.rawValue
    @AppStorage("safeModeEnabled") private var safeModeEnabled = false

    private var minBytes: Int64 { Int64(minSizeGB * 1024 * 1024 * 1024) }

    private var formattedThreshold: String {
        if minSizeGB < 1 {
            return "\(Int(minSizeGB * 1024)) MB"
        }
        return String(format: "%.1f GB", minSizeGB)
    }

    private var totalSelectedSize: Int64 {
        storageManager.largeFileGroups
            .flatMap(\.items)
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    private var deletionMode: DeletionMode { DeletionMode(rawValue: deletionModeRaw) ?? .ask }

    var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 720
            VStack(spacing: 0) {
                largeFileHeader(isCompact: isCompact)

                Divider()

            if storageManager.isLargeFileScanRunning {
                ToolLoadingView(message: "Scanning for large files…")
            } else if storageManager.largeFileGroups.isEmpty {
                ToolEmptyView(
                    icon: ToolType.largeFileBrowser.icon,
                    title: "No Large Files Found",
                    subtitle: "Press Scan to find files larger than \(formattedThreshold).\nResults are grouped by file type.",
                    color: ToolType.largeFileBrowser.color
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(storageManager.largeFileGroups) { group in
                            LargeFileGroupSection(
                                group: group,
                                selectedItems: $selectedItems
                            )
                        }
                    }
                    .padding(20)
                }
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: minSizeGB) { _, _ in
            sliderRescanTask?.cancel()
            sliderRescanTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                let bytes = Int64(minSizeGB * 1024 * 1024 * 1024)
                await storageManager.scanLargeFiles(minBytes: bytes)
            }
        }
        .onDisappear { sliderRescanTask?.cancel() }
        .confirmationDialog("How would you like to remove \(selectedItems.count) item(s)?",
                            isPresented: $showAskAlert, titleVisibility: .visible) {
            Button("Move to Trash") { performDelete(mode: .trash) }
            Button("Delete Permanently", role: .destructive) { performDelete(mode: .permanent) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file) + " selected")
        }
        .alert("Delete Selected Items?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button(deletionMode == .trash ? "Move to Trash" : "Delete", role: .destructive) {
                performDelete(mode: deletionMode)
            }
        } message: {
            Text("This will remove \(selectedItems.count) item(s) totaling \(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)).")
        }
    }

    @ViewBuilder
    private func largeFileHeader(isCompact: Bool) -> some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: ToolType.largeFileBrowser.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(ToolType.largeFileBrowser.color)
                        .themeIconBadge(color: ToolType.largeFileBrowser.color, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ToolType.largeFileBrowser.title)
                            .font(.title3).fontWeight(.semibold)
                        Text("Files larger than \(formattedThreshold)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    Text("Min size:").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $minSizeGB, in: 0.05...5.0, step: 0.05)
                    Text(formattedThreshold)
                        .font(.caption).monospacedDigit()
                        .frame(minWidth: 56, alignment: .leading)
                }
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
                        Task { await storageManager.scanLargeFiles(minBytes: minBytes) }
                    } label: {
                        if storageManager.isLargeFileScanRunning {
                            HStack(spacing: 6) { IndeterminateSpinner(size: 16, color: .secondary); Text("Scanning…") }
                        } else {
                            Label(storageManager.largeFileGroups.isEmpty ? "Scan" : "Re-Scan", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(storageManager.isLargeFileScanRunning)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()
        } else {
            HStack(spacing: 14) {
                Image(systemName: ToolType.largeFileBrowser.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ToolType.largeFileBrowser.color)
                    .themeIconBadge(color: ToolType.largeFileBrowser.color, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolType.largeFileBrowser.title)
                        .font(.title3).fontWeight(.semibold)
                    Text("Files larger than \(formattedThreshold)")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("Min size:")
                        .font(.caption).foregroundStyle(.secondary)
                    Slider(value: $minSizeGB, in: 0.05...5.0, step: 0.05)
                        .frame(minWidth: 120, maxWidth: 200)
                    Text(formattedThreshold)
                        .font(.caption).monospacedDigit()
                        .frame(width: 56, alignment: .leading)
                }

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
                    Task { await storageManager.scanLargeFiles(minBytes: minBytes) }
                } label: {
                    if storageManager.isLargeFileScanRunning {
                        HStack(spacing: 6) { IndeterminateSpinner(size: 16, color: .secondary); Text("Scanning…") }
                    } else {
                        Label(storageManager.largeFileGroups.isEmpty ? "Scan" : "Re-Scan", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(storageManager.isLargeFileScanRunning)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()
        }
    }

    private func stageSelected() {
        let items = storageManager.largeFileGroups.flatMap(\.items).filter { selectedItems.contains($0.id) }
        storageManager.stageForDeletion(items)
        selectedItems.removeAll()
    }

    private func performDelete(mode: DeletionMode) {
        let items = storageManager.largeFileGroups.flatMap(\.items).filter { selectedItems.contains($0.id) }
        Task {
            await storageManager.deleteLargeFiles(items, mode: mode)
            selectedItems.removeAll()
        }
    }
}

// MARK: - Large File Group Section

private struct LargeFileGroupSection: View {
    let group: LargeFileGroup
    @Binding var selectedItems: Set<StorageItem.ID>
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2).foregroundStyle(.tertiary).frame(width: 12)
                    Text(group.typeName)
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text("\(group.items.count) files · \(ByteCountFormatter.string(fromByteCount: group.totalSize, countStyle: .file))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, item in
                        LargeFileRow(item: item, isSelected: selectedItems.contains(item.id)) {
                            if selectedItems.contains(item.id) {
                                selectedItems.remove(item.id)
                            } else {
                                selectedItems.insert(item.id)
                            }
                        }
                        if idx < group.items.count - 1 {
                            Divider().padding(.leading, 42)
                        }
                    }
                }
                .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.borderSubtle, lineWidth: 1))
            }
        }
    }
}

private struct LargeFileRow: View {
    let item: StorageItem
    let isSelected: Bool
    let onToggle: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? Theme.accentGreen : .secondary)
                .animation(.spring(response: 0.2), value: isSelected)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
                Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(item.formattedSize)
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(isHovered || isSelected ? Theme.backgroundElevated : Color.clear)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
