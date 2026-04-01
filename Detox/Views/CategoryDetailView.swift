//
//  CategoryDetailView.swift
//  Detox
//
//  Created by saleh on 16/03/2026.
//

import SwiftUI
import AppKit

struct CategoryDetailView: View {
    let category: StorageCategory
    let items: [StorageItem]
    @ObservedObject var storageManager: StorageManager
    @State private var selectedItems = Set<StorageItem.ID>()
    @State private var showingDeleteAlert = false
    @State private var showingAskDeleteAlert = false
    @State private var searchText = ""
    @AppStorage("deletionMode") private var deletionModeRaw: String = DeletionMode.ask.rawValue
    @AppStorage("safeModeEnabled") private var safeModeEnabled = false
    @State private var ql = QuickLookCoordinator()

    // MARK: - Performance: O(1) size lookup instead of O(n) filter every render

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
            CategoryHeader(
                category: category,
                hasSelection: !selectedItems.isEmpty,
                totalSelectedSize: totalSelectedSize,
                isDeleting: storageManager.isDeletingItems,
                isSafeMode: safeModeEnabled,
                descriptionOverride: (category == .trash && storageManager.trashAccessDenied)
                    ? "Full Disk Access required to scan Trash"
                    : nil,
                onClean: { triggerDelete() },
                onSelectAbove: { threshold in
                    selectedItems = Set(filteredItems.filter { $0.size > threshold }.map(\.id))
                },
                onSelectAll: { selectedItems = Set(filteredItems.map(\.id)) },
                onDeselectAll: { selectedItems.removeAll() }
            )

            Divider()

            // Search bar
            if !items.isEmpty {
                SearchBar(searchText: $searchText, placeholder: "Filter \(items.count) items…")
                Divider()
            }

            if category == .trash && storageManager.trashAccessDenied {
                TrashAccessDeniedView {
                    storageManager.openFullDiskAccessSettings()
                }
            } else if filteredItems.isEmpty {
                EmptyStateView(category: category)
            } else {
                HStack(spacing: 0) {
                    ItemsTableView(
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
        .overlay(alignment: .bottom) {
            if storageManager.isDeletingItems {
                DeletionProgressHUD(
                    currentName: storageManager.deletionCurrentName,
                    completed: storageManager.deletionCompleted,
                    total: storageManager.deletionTotal,
                    progress: storageManager.deletionProgress,
                    accentColor: category.color
                )
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: storageManager.isDeletingItems)
        .onAppear { rebuildSizeMap() }
        .onChange(of: items) { rebuildSizeMap(); selectedItems.removeAll() }
        .onChange(of: searchText) { selectedItems.removeAll() }
        .onChange(of: selectedItems) { _, newVal in
            totalSelectedSize = newVal.reduce(0) { $0 + (sizeByID[$1] ?? 0) }
        }
        // "Ask" mode alert with Trash / Delete permanently
        .confirmationDialog("How would you like to remove \(selectedItems.count) item(s)?",
                            isPresented: $showingAskDeleteAlert,
                            titleVisibility: .visible) {
            Button("Move to Trash") {
                performDelete(mode: .trash)
            }
            Button("Delete Permanently", role: .destructive) {
                performDelete(mode: .permanent)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("\(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)) selected")
        }
        // Permanent delete confirmation
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
            Text("The following items could not be removed (check permissions):\n\n" +
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
        let itemsToDelete: [StorageItem]
        if category == .timeMachineSnapshots {
            itemsToDelete = filteredItems.filter { selectedItems.contains($0.id) }
            Task {
                await storageManager.deleteTimeMachineItems(itemsToDelete)
                selectedItems.removeAll()
            }
        } else {
            itemsToDelete = filteredItems.filter { selectedItems.contains($0.id) }
            Task {
                await storageManager.deleteItems(itemsToDelete, from: category, mode: mode)
                selectedItems.removeAll()
            }
        }
    }

    private func rebuildSizeMap() {
        sizeByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.size) })
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var searchText: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
            TextField(placeholder, text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .themeHeader()
    }
}

// MARK: - Category Header

struct CategoryHeader: View {
    let category: StorageCategory
    let hasSelection: Bool
    let totalSelectedSize: Int64
    var isDeleting: Bool = false
    var isSafeMode: Bool = false
    var descriptionOverride: String? = nil
    let onClean: () -> Void
    let onSelectAbove: (Int64) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    private var displayDescription: String {
        descriptionOverride ?? category.description
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(category.color)
                .themeIconBadge(color: category.color, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(.title3).fontWeight(.semibold)
                Text(displayDescription)
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            // Smart select menu
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
            .disabled(isDeleting)

            if hasSelection {
                if isSafeMode {
                    Button { onClean() } label: {
                        Label("Stage \(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(ThemePrimaryButton(color: Theme.accentAmber))
                    .disabled(isDeleting)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button { onClean() } label: {
                        HStack(spacing: 6) {
                            if isDeleting { IndeterminateSpinner(size: 12, color: .primary) }
                            else { Image(systemName: "trash.fill").font(.caption) }
                            Text(isDeleting ? "Deleting…" : "Clean \(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))")
                        }
                    }
                    .buttonStyle(ThemeDestructiveButton())
                    .disabled(isDeleting)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .themeHeader()
        .animation(.spring(response: 0.35), value: hasSelection)
        .animation(.spring(response: 0.25), value: isDeleting)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let category: StorageCategory
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
            Text("No cleanable items found in this category.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { scale = 1.0; opacity = 1.0 }
        }
    }
}

// MARK: - Trash Access Denied View

struct TrashAccessDeniedView: View {
    let onOpenSettings: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.orange)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 6) {
                Text("Full Disk Access Required")
                    .font(.title3).fontWeight(.semibold)
                    .opacity(appeared ? 1 : 0)

                Text("Detox can't read your Trash because it doesn't have Full Disk Access.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                    .opacity(appeared ? 1 : 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Open **System Settings**", systemImage: "gear")
                Label("Go to **Privacy & Security → Full Disk Access**", systemImage: "lock.open")
                Label("Enable **Detox** in the list", systemImage: "checkmark.circle")
                Label("Re-scan when done", systemImage: "arrow.clockwise")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 340, alignment: .leading)
            .opacity(appeared ? 1 : 0)

            Button {
                onOpenSettings()
            } label: {
                Label("Open Privacy & Security Settings", systemImage: "arrow.up.forward.app")
                    .frame(minWidth: 260)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .opacity(appeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        }
    }
}

// MARK: - Items Table View

struct ItemsTableView: View {
    let category: StorageCategory
    let items: [StorageItem]
    @Binding var selectedItems: Set<StorageItem.ID>

    var body: some View {
        Table(items, selection: $selectedItems) {
            TableColumn("Name") { item in
                NameCell(item: item, icon: category.icon, color: category.color)
            }
            .width(min: 300)

            TableColumn("Size") { item in
                Text(item.formattedSize)
                    .monospacedDigit()
                    .fontWeight(.medium)
                    .foregroundStyle(sizeColor(for: item.size))
            }
            .width(min: 100, max: 120)

            // PERF FIX: Use static formattedDate — .relative fires a timer every second
            // per visible row, causing constant re-renders with large lists.
            TableColumn("Modified") { item in
                Text(item.formattedDate)
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, max: 160)
        }
    }

    private func sizeColor(for bytes: Int64) -> Color {
        Theme.sizeColor(for: bytes)
    }
}

// MARK: - Name Cell

/// Extracted as a standalone view so SwiftUI can diff it independently per row.
private struct NameCell: View {
    let item: StorageItem
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ItemThumbnailView(path: item.path, fallbackIcon: icon, fallbackColor: color)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - File Detail Panel

struct FileDetailPanel: View {
    let item: StorageItem
    let selectedCount: Int
    let totalSelectedSize: Int64
    let accentColor: Color
    let fallbackIcon: String
    var onPreview: (() -> Void)? = nil

    private var isImage: Bool { ThumbnailCache.isImageFile(item.path) }

    var body: some View {
        VStack(spacing: 0) {
            // ── Thumbnail / Icon ─────────────────────────────────────
            if isImage {
                ZStack {
                    Rectangle().fill(accentColor.opacity(0.05))
                    LargePreviewImage(path: item.path)
                }
                .frame(height: 170)
                .frame(maxWidth: .infinity)
            } else {
                ZStack {
                    Rectangle()
                        .fill(accentColor.opacity(0.07))
                    ItemThumbnailView(path: item.path, fallbackIcon: fallbackIcon, fallbackColor: accentColor)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                }
                .frame(height: 110)
                .frame(maxWidth: .infinity)
            }

            Divider()

            // ── Details ──────────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Name
                    Text(item.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)

                    // Stats rows
                    VStack(alignment: .leading, spacing: 8) {
                        DetailInfoRow(label: "Size", value: item.formattedSize, valueColor: sizeColor(item.size))
                        DetailInfoRow(label: "Modified", value: item.modifiedDate.formatted(date: .abbreviated, time: .shortened))
                        DetailInfoRow(label: "Kind", value: fileKind(for: item.path))
                        DetailInfoRow(label: "Location", value: (item.path as NSString).deletingLastPathComponent)
                    }

                    if selectedCount > 1 {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(selectedCount) items selected")
                                .font(.caption).fontWeight(.semibold).foregroundStyle(accentColor)
                            Text(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file) + " total")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    // Actions
                    if let onPreview {
                        Button {
                            onPreview()
                        } label: {
                            Label("Quick Look", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(14)
            }
        }
        .frame(width: 230)
        .background(Theme.backgroundCard)
    }

    private func sizeColor(_ bytes: Int64) -> Color {
        Theme.sizeColor(for: bytes)
    }

    private func fileKind(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "JPEG Image"
        case "png": return "PNG Image"
        case "heic", "heif": return "HEIC Image"
        case "gif": return "GIF Image"
        case "webp": return "WebP Image"
        case "mp4": return "MPEG-4 Video"
        case "mov": return "QuickTime Video"
        case "mkv": return "Matroska Video"
        case "avi": return "AVI Video"
        case "mp3": return "MP3 Audio"
        case "m4a": return "AAC Audio"
        case "pdf": return "PDF Document"
        case "zip": return "ZIP Archive"
        case "dmg": return "Disk Image"
        case "pkg": return "Installer Package"
        case "app": return "Application"
        default: return ext.isEmpty ? "File" : "\(ext.uppercased()) File"
        }
    }
}

// MARK: - Deletion Progress HUD

struct DeletionProgressHUD: View {
    let currentName: String
    let completed: Int
    let total: Int
    let progress: Double
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                IndeterminateSpinner(size: 16, color: .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(total > 1
                             ? "Deleting \(min(completed + 1, total)) of \(total)"
                             : "Deleting…")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                        if total > 1 {
                            Text("\(Int(progress * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    Text(currentName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if total > 1 {
                LinearProgressFill(value: progress, tint: accentColor, height: 4)
                    .animation(.linear(duration: 0.2), value: progress)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 380)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
    }
}

// MARK: - Large Preview Image (for image files in the detail panel)

private struct LargePreviewImage: View {
    let path: String
    @State private var thumbnail: NSImage? = nil

    var body: some View {
        Group {
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                    .padding(12)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                Color.clear
                    .frame(height: 170)
                    .overlay { ProgressView().scaleEffect(0.6) }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: thumbnail != nil)
        .task(id: path) {
            // Use a separate cache key so large previews don't evict the small row thumbnails
            let key = "large_\(path)"
            if let cached = ThumbnailCache.shared.cached(for: key) {
                thumbnail = cached; return
            }
            guard let image = await ThumbnailCache.load(path: path, pixelSize: 460) else { return }
            ThumbnailCache.shared.store(image, for: key)
            guard !Task.isCancelled else { return }
            thumbnail = image
        }
    }
}

// MARK: - Detail Info Row

struct DetailInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2).fontWeight(.medium).foregroundStyle(.secondary)
            Text(value)
                .font(.caption).foregroundStyle(valueColor)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
