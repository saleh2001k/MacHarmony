//
//  ViewsSidebarView.swift
//  Detox
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var storageManager: StorageManager
    @State private var showAddCustomCategory = false
    @State private var categoryToDelete: CustomScanCategory?
    @State private var showDeleteAlert = false
    @State private var showHidden = false

    var body: some View {
        List {
            // Built-in categories
            Section {
                ForEach(storageManager.orderedCategories) { category in
                    if !storageManager.isCategoryHidden(category) || showHidden {
                        CategoryRow(
                            category: category,
                            storageManager: storageManager
                        )
                        .opacity(storageManager.isCategoryHidden(category) ? 0.4 : 1.0)
                        .contextMenu {
                            Button {
                                withAnimation {
                                    storageManager.toggleCategoryVisibility(category)
                                }
                            } label: {
                                Label(
                                    storageManager.isCategoryHidden(category) ? "Show in Sidebar" : "Hide from Sidebar",
                                    systemImage: storageManager.isCategoryHidden(category) ? "eye" : "eye.slash"
                                )
                            }
                        }
                    }
                }

                // Show hidden toggle
                if storageManager.hiddenCategories.count > 0 {
                    Button {
                        withAnimation { showHidden.toggle() }
                    } label: {
                        Label(
                            showHidden ? "Hide \(storageManager.hiddenCategories.count) hidden" : "Show \(storageManager.hiddenCategories.count) hidden",
                            systemImage: showHidden ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }
            } header: {
                Label("Storage Categories", systemImage: "internaldrive.fill")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accentGreen.opacity(0.8))
                    .textCase(nil)
            }

            // Tools section
            Section {
                ForEach(ToolType.allCases) { tool in
                    ToolRow(tool: tool, storageManager: storageManager)
                }
            } header: {
                Label("Tools", systemImage: "wrench.and.screwdriver.fill")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accentGreen.opacity(0.8))
                    .textCase(nil)
            }

            // Custom categories
            Section {
                if storageManager.customCategories.isEmpty {
                    Button {
                        showAddCustomCategory = true
                    } label: {
                        Label("Add Custom Scanner", systemImage: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(Theme.accentGreen)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                    .accessibilityLabel("Add custom scanner")
                } else {
                    ForEach(storageManager.customCategories) { category in
                        CustomCategoryRow(category: category, storageManager: storageManager)
                            .contextMenu {
                                Button {
                                    Task { await storageManager.scanSingleCustomCategory(category) }
                                } label: {
                                    Label("Scan Now", systemImage: "arrow.clockwise")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    categoryToDelete = category
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                HStack {
                    Label("Custom Scanners", systemImage: "slider.horizontal.3")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accentGreen.opacity(0.8))
                        .textCase(nil)
                    Spacer()
                    if !storageManager.customCategories.isEmpty {
                        Button {
                            showAddCustomCategory = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.caption)
                                .foregroundStyle(Theme.accentGreen)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.backgroundSidebar)
        .navigationSplitViewColumnWidth(min: 210, ideal: 250)
        .sheet(isPresented: $showAddCustomCategory) {
            AddCustomCategoryView()
                .environmentObject(storageManager)
        }
        .alert("Delete \"\(categoryToDelete?.name ?? "")\"?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { categoryToDelete = nil }
            Button("Delete", role: .destructive) {
                if let cat = categoryToDelete {
                    Task { await storageManager.deleteCustomCategory(id: cat.id) }
                    categoryToDelete = nil
                }
            }
        } message: {
            Text("This will remove the custom scanner and all its scanned results. The actual files will not be deleted.")
        }
    }
}

// MARK: - Custom Category Row

struct CustomCategoryRow: View {
    let category: CustomScanCategory
    @ObservedObject var storageManager: StorageManager

    private var items: [StorageItem] { storageManager.customItems[category.id] ?? [] }
    private var isSelected: Bool { storageManager.selectedCustomCategory?.id == category.id }

    private var sizeText: String {
        items.isEmpty ? "" : storageManager.customCategorySize(for: category.id)
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                if storageManager.scanningCustomCategories.contains(category.id) {
                    IndeterminateSpinner(size: 16, color: category.color)
                        .themeIconBadge(color: category.color, size: 30, selected: isSelected)
                } else {
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(category.color.opacity(isSelected ? 0.7 : 1.0))
                        .themeIconBadge(color: category.color, size: 30, selected: isSelected)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(category.name)
                    .font(.system(size: 13, weight: .medium))
                if !items.isEmpty {
                    Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !sizeText.isEmpty {
                Text(sizeText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .secondary : category.color.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (isSelected ? Theme.borderMedium : category.color.opacity(0.12)),
                        in: Capsule()
                    )
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.name)\(sizeText.isEmpty ? "" : ", \(sizeText)")")
        .accessibilityAddTraits(.isButton)
        .listRowBackground(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.backgroundElevated)
                        .padding(.horizontal, 4)
                }
            }
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                storageManager.selectedCustomCategory = category
                storageManager.selectedCategory = nil
            }
        }
    }
}

// MARK: - Tool Row

struct ToolRow: View {
    let tool: ToolType
    @ObservedObject var storageManager: StorageManager

    private var isSelected: Bool { storageManager.selectedTool == tool }

    private var badgeText: String? {
        switch tool {
        case .safeMode:
            let count = storageManager.stagedForDeletion.count
            return count > 0 ? "\(count)" : nil
        default:
            return nil
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tool.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tool.color.opacity(isSelected ? 0.7 : 1.0))
                .themeIconBadge(color: tool.color, size: 30, selected: isSelected)

            Text(tool.title)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            if let badge = badgeText {
                Text(badge)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .secondary : tool.color.opacity(0.9))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(
                        (isSelected ? Theme.borderMedium : tool.color.opacity(0.12)),
                        in: Capsule()
                    )
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tool.title)
        .accessibilityAddTraits(.isButton)
        .listRowBackground(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.backgroundElevated)
                        .padding(.horizontal, 4)
                }
            }
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                storageManager.selectedTool = tool
                storageManager.selectedCategory = nil
                storageManager.selectedCustomCategory = nil
            }
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: StorageCategory
    @ObservedObject var storageManager: StorageManager

    private var items: [StorageItem] { storageManager.items(for: category) }
    private var isSelected: Bool { storageManager.selectedCategory == category }
    private var isScanning: Bool { storageManager.scanningCategories.contains(category) }
    private var isDone: Bool { storageManager.storageItems[category] != nil }
    private var isTrashDenied: Bool {
        category == .trash && storageManager.trashAccessDenied
    }

    private var sizeText: String {
        items.isEmpty ? "" : storageManager.categorySize(for: category)
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                if isScanning && !isDone {
                    IndeterminateSpinner(size: 16, color: category.color)
                        .themeIconBadge(color: category.color, size: 30, selected: isSelected)
                } else if isTrashDenied {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.orange)
                        .themeIconBadge(color: .orange, size: 30, selected: isSelected)
                } else {
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(category.color.opacity(isSelected ? 0.7 : 1.0))
                        .themeIconBadge(color: category.color, size: 30, selected: isSelected)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(category.title)
                    .font(.system(size: 13, weight: .medium))
                if isTrashDenied {
                    Text("No Access")
                        .font(.caption2)
                        .foregroundStyle(Color.orange)
                } else if !items.isEmpty {
                    Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isTrashDenied {
                Text("Allow")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .secondary : Color.orange.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (isSelected ? Theme.borderMedium : Color.orange.opacity(0.12)),
                        in: Capsule()
                    )
            } else if !sizeText.isEmpty {
                Text(sizeText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .secondary : category.color.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (isSelected ? Theme.borderMedium : category.color.opacity(0.12)),
                        in: Capsule()
                    )
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.title)\(sizeText.isEmpty ? "" : ", \(sizeText)")")
        .accessibilityAddTraits(.isButton)
        .listRowBackground(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.backgroundElevated)
                        .padding(.horizontal, 4)
                }
            }
        )
        .onTapGesture {
            if isTrashDenied {
                storageManager.openFullDiskAccessSettings()
            } else {
                withAnimation(.spring(response: 0.3)) {
                    storageManager.selectedCategory = category
                    storageManager.selectedCustomCategory = nil
                }
            }
        }
    }
}


