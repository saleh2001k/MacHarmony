//
//  ViewsCustomCategoryDetailView.swift
//  Detox
//

import SwiftUI
import AppKit

struct CustomCategoryDetailView: View {
    let category: CustomScanCategory
    let items: [StorageItem]
    @ObservedObject var storageManager: StorageManager
    @State private var selectedItems = Set<StorageItem.ID>()
    @State private var showingDeleteAlert = false
    @State private var showingAskDeleteAlert = false
    @State private var searchText = ""
    @AppStorage("deletionMode") private var deletionModeRaw: String = DeletionMode.ask.rawValue
    @AppStorage("safeModeEnabled") private var safeModeEnabled = false
    @State private var ql = QuickLookCoordinator()

    // MARK: - Performance: O(1) size lookup

    @State private var sizeByID: [StorageItem.ID: Int64] = [:]
    @State private var totalSelectedSize: Int64 = 0

    private var filteredItems: [StorageItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.path.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var currentDeletionMode: DeletionMode {
        DeletionMode(rawValue: deletionModeRaw) ?? .ask
    }

    var body: some View {
        VStack(spacing: 0) {
            CustomCategoryHeader(
                category: category,
                hasSelection: !selectedItems.isEmpty,
                totalSelectedSize: totalSelectedSize,
                isSafeMode: safeModeEnabled,
                onClean: { triggerDelete() },
                onSelectAbove: { threshold in
                    selectedItems = Set(filteredItems.filter { $0.size > threshold }.map(\.id))
                },
                onSelectAll: { selectedItems = Set(filteredItems.map(\.id)) },
                onDeselectAll: { selectedItems.removeAll() }
            )

            Divider()

            if storageManager.scanningCustomCategories.contains(category.id) {
                CustomScanBanner(category: category, storageManager: storageManager)
                Divider()
            }

            // Search bar
            if !items.isEmpty {
                SearchBar(searchText: $searchText, placeholder: "Filter \(items.count) items…")
                Divider()
            }

            if filteredItems.isEmpty {
                CustomEmptyStateView(category: category)
            } else {
                HStack(spacing: 0) {
                    CustomItemsTableView(
                        category: category,
                        items: filteredItems,
                        selectedItems: $selectedItems
                    )
                    .onKeyPress(.space) {
                        if let firstId = selectedItems.first,
                           let first = filteredItems.first(where: { $0.id == firstId }) {
                            ql.show(path: first.path)
                        }
                        return .handled
                    }

                    if let firstId = selectedItems.first,
                       let first = filteredItems.first(where: { $0.id == firstId }) {
                        Divider()
                        FileDetailPanel(
                            item: first,
                            selectedCount: selectedItems.count,
                            totalSelectedSize: totalSelectedSize,
                            accentColor: category.color,
                            fallbackIcon: category.icon,
                            onPreview: { ql.show(path: first.path) }
                        )
                    }
                }
            }
        }
        .onAppear { rebuildSizeMap() }
        .onChange(of: items) { rebuildSizeMap(); selectedItems.removeAll() }
        .onChange(of: searchText) { selectedItems.removeAll() }
        .onChange(of: selectedItems) { _, newVal in
            totalSelectedSize = newVal.reduce(0) { $0 + (sizeByID[$1] ?? 0) }
        }
        .confirmationDialog("How would you like to remove \(selectedItems.count) item(s)?",
                            isPresented: $showingAskDeleteAlert,
                            titleVisibility: .visible) {
            Button("Move to Trash") { performDelete(mode: .trash) }
            Button("Delete Permanently", role: .destructive) { performDelete(mode: .permanent) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("\(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)) selected")
        }
        .alert("Delete Selected Items?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button(currentDeletionMode == .trash ? "Move to Trash" : "Delete", role: .destructive) {
                performDelete(mode: currentDeletionMode)
            }
        } message: {
            let verb = currentDeletionMode == .trash ? "move to Trash" : "permanently delete"
            Text("This will \(verb) \(selectedItems.count) item(s) totaling \(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)).")
        }
        .alert("Some Items Could Not Be Deleted", isPresented: $storageManager.showDeletionError) {
            Button("OK", role: .cancel) {
                storageManager.deletionErrors.removeAll()
                storageManager.showDeletionError = false
            }
        } message: {
            Text("The following items could not be removed:\n\n" +
                 storageManager.deletionErrors.joined(separator: "\n"))
        }
    }

    private func triggerDelete() {
        if safeModeEnabled {
            let itemsToStage = filteredItems.filter { selectedItems.contains($0.id) }
            storageManager.stageForDeletion(itemsToStage)
            selectedItems.removeAll()
            storageManager.selectedTool = .safeMode
            return
        }
        if currentDeletionMode == .ask {
            showingAskDeleteAlert = true
        } else {
            showingDeleteAlert = true
        }
    }

    private func performDelete(mode: DeletionMode) {
        let toDelete = filteredItems.filter { selectedItems.contains($0.id) }
        Task {
            await storageManager.deleteItems(toDelete, fromCustom: category.id, mode: mode)
            selectedItems.removeAll()
        }
    }

    private func rebuildSizeMap() {
        sizeByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.size) })
    }
}

// MARK: - Header

private struct CustomCategoryHeader: View {
    let category: CustomScanCategory
    let hasSelection: Bool
    let totalSelectedSize: Int64
    var isSafeMode: Bool = false
    let onClean: () -> Void
    let onSelectAbove: (Int64) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(category.color)
                .themeIconBadge(color: category.color, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name).font(.title3).fontWeight(.semibold)
                Text("Extensions: \(category.extensions.map { ".\($0)" }.joined(separator: ", "))")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button("Select all > 100 MB") { onSelectAbove(100 * 1024 * 1024) }
                Button("Select all > 500 MB") { onSelectAbove(500 * 1024 * 1024) }
                Button("Select all > 1 GB")   { onSelectAbove(1_073_741_824) }
                Divider()
                Button("Select All")   { onSelectAll() }
                Button("Deselect All") { onDeselectAll() }
            } label: {
                Image(systemName: "checklist").font(.caption)
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)

            if hasSelection {
                if isSafeMode {
                    Button { onClean() } label: {
                        Label("Stage \(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(ThemePrimaryButton(color: Theme.accentAmber))
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button { onClean() } label: {
                        Label("Clean \(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))", systemImage: "trash.fill")
                    }
                    .buttonStyle(ThemeDestructiveButton())
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .themeHeader()
        .animation(.spring(response: 0.35), value: hasSelection)
    }
}

// MARK: - Empty State

private struct CustomEmptyStateView: View {
    let category: CustomScanCategory
    @State private var scale = 0.7
    @State private var opacity = 0.0

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(category.color.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 36)).foregroundStyle(category.color)
            }
            .scaleEffect(scale).opacity(opacity)
            Text("All Clean!").font(.title3).fontWeight(.semibold).opacity(opacity)
            Text("No matching files found in the selected directories.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { scale = 1.0; opacity = 1.0 }
        }
    }
}

// MARK: - Table

private struct CustomItemsTableView: View {
    let category: CustomScanCategory
    let items: [StorageItem]
    @Binding var selectedItems: Set<StorageItem.ID>

    var body: some View {
        Table(items, selection: $selectedItems) {
            TableColumn("Name") { item in
                CustomNameCell(item: item, icon: category.icon, color: category.color)
            }
            .width(min: 300)

            TableColumn("Size") { item in
                Text(item.formattedSize)
                    .monospacedDigit().fontWeight(.medium)
                    .foregroundStyle(sizeColor(for: item.size))
            }
            .width(min: 100, max: 120)

            // PERF FIX: static date — no per-second timer re-renders
            TableColumn("Modified") { item in
                Text(item.formattedDate).foregroundStyle(.secondary)
            }
            .width(min: 120, max: 160)
        }
    }

    private func sizeColor(for bytes: Int64) -> Color {
        Theme.sizeColor(for: bytes)
    }
}

// MARK: - Name Cell

private struct CustomNameCell: View {
    let item: StorageItem
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ItemThumbnailView(path: item.path, fallbackIcon: icon, fallbackColor: color)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).fontWeight(.medium).lineLimit(1)
                Text(item.path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
        }
    }
}

// MARK: - Scan Banner

private struct CustomScanBanner: View {
    let category: CustomScanCategory
    @ObservedObject var storageManager: StorageManager

    var body: some View {
        HStack(spacing: 10) {
            IndeterminateSpinner(size: 14, color: .secondary)
            Text("Scanning \(category.name)…")
                .font(.subheadline).fontWeight(.semibold)
            Text("·").foregroundStyle(.tertiary)
            Text(storageManager.currentScanPath.isEmpty
                 ? "Preparing…"
                 : (storageManager.currentScanPath as NSString).lastPathComponent)
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .themeHeader()
    }
}
