//
//  ViewsSafeModeView.swift
//  Detox
//

import SwiftUI

struct ViewsSafeModeView: View {
    @ObservedObject var storageManager: StorageManager
    @State private var showCommitAlert = false
    @State private var showAskAlert = false
    @State private var showClearAlert = false
    @AppStorage("safeModeEnabled") private var safeModeEnabled = false
    @AppStorage("deletionMode") private var deletionModeRaw = DeletionMode.ask.rawValue

    private var deletionMode: DeletionMode { DeletionMode(rawValue: deletionModeRaw) ?? .ask }

    private var totalStagedSize: Int64 {
        storageManager.stagedForDeletion.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: ToolType.safeMode.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ToolType.safeMode.color)
                    .themeIconBadge(color: ToolType.safeMode.color, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolType.safeMode.title).font(.title3).fontWeight(.semibold)
                    Text("\(storageManager.stagedForDeletion.count) items staged · \(ByteCountFormatter.string(fromByteCount: totalStagedSize, countStyle: .file))")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                Toggle(isOn: $safeModeEnabled) {
                    Label("Safe Mode", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)
                .tint(ToolType.safeMode.color)
                .help("When on, delete buttons stage items here instead of deleting immediately")

                if !storageManager.stagedForDeletion.isEmpty {
                    Button("Clear All") { showClearAlert = true }
                        .buttonStyle(.bordered)
                        .foregroundStyle(.secondary)

                    Button {
                        if deletionMode == .ask { showAskAlert = true }
                        else { showCommitAlert = true }
                    } label: {
                        Label("Commit Deletions", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(ThemePrimaryButton(color: ToolType.safeMode.color))
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .themeHeader()

            Divider()

            // Safe Mode explanation banner
            if !safeModeEnabled {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(ToolType.safeMode.color)
                    Text("Enable Safe Mode to have deletion buttons across the app stage items here instead of deleting immediately. Review staged items, then commit all at once.")
                        .font(.caption)
                    Spacer()
                    Button("Enable Safe Mode") { safeModeEnabled = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(ToolType.safeMode.color.opacity(0.06))
                Divider()
            }

            if storageManager.stagedForDeletion.isEmpty {
                ToolEmptyView(
                    icon: ToolType.safeMode.icon,
                    title: "No Items Staged",
                    subtitle: "Enable Safe Mode above, then use \"Stage\" buttons\nthroughout the app to queue items for review.",
                    color: ToolType.safeMode.color
                )
            } else {
                List {
                    ForEach(storageManager.stagedForDeletion) { item in
                        StagedItemRow(item: item) {
                            withAnimation { storageManager.removeFromStaged(item) }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .confirmationDialog("Commit \(storageManager.stagedForDeletion.count) staged deletion(s)?",
                            isPresented: $showAskAlert, titleVisibility: .visible) {
            Button("Move to Trash") { commitDeletion(mode: .trash) }
            Button("Delete Permanently", role: .destructive) { commitDeletion(mode: .permanent) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(ByteCountFormatter.string(fromByteCount: totalStagedSize, countStyle: .file) + " will be freed")
        }
        .alert("Commit Staged Deletions?", isPresented: $showCommitAlert) {
            Button("Cancel", role: .cancel) { }
            Button(deletionMode == .trash ? "Move to Trash" : "Delete Permanently", role: .destructive) {
                commitDeletion(mode: deletionMode)
            }
        } message: {
            Text("This will permanently process \(storageManager.stagedForDeletion.count) item(s) totaling \(ByteCountFormatter.string(fromByteCount: totalStagedSize, countStyle: .file)).")
        }
        .alert("Clear Staged Queue?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                withAnimation { storageManager.clearStagedDeletions() }
            }
        } message: {
            Text("All \(storageManager.stagedForDeletion.count) staged item(s) will be removed from the queue. No files will be deleted.")
        }
    }

    private func commitDeletion(mode: DeletionMode) {
        Task { await storageManager.commitStagedDeletions(mode: mode) }
    }
}

// MARK: - Staged Item Row

private struct StagedItemRow: View {
    let item: StorageItem
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(ToolType.safeMode.color)
                .themeIconBadge(color: ToolType.safeMode.color, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
                Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(item.formattedSize).font(.caption).monospacedDigit().foregroundStyle(.secondary)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .background(isHovered ? Theme.backgroundElevated : Color.clear)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
