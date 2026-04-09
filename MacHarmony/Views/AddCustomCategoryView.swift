//
//  ViewsAddCustomCategoryView.swift
//  MacHarmony
//

import SwiftUI
import AppKit

struct AddCustomCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var storageManager: StorageManager

    // Editing mode
    var editingCategory: CustomScanCategory?

    @State private var name: String = ""
    @State private var extensions: [String] = [""]
    @State private var searchPaths: [String] = []
    @State private var selectedColor: String = CustomScanCategory.presetColors[0]
    @State private var selectedIcon: String = CustomScanCategory.presetIcons[0]
    @State private var showIconPicker = false

    private var isEditing: Bool { editingCategory != nil }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        extensions.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) &&
        !searchPaths.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Custom Scanner" : "New Custom Scanner")
                    .font(.headline)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button(isEditing ? "Save" : "Add") {
                    save()
                }
                .buttonStyle(ThemePrimaryButton())
                .disabled(!isValid)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Preview + Name
                    HStack(spacing: 14) {
                        // Icon preview
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(hexString: selectedColor)?.opacity(0.2) ?? Color.blue.opacity(0.2))
                                .frame(width: 52, height: 52)
                            Image(systemName: selectedIcon)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color(hexString: selectedColor) ?? .blue)
                        }
                        .onTapGesture { showIconPicker.toggle() }
                        .help("Tap to change icon")

                        TextField("Scanner name (e.g. SVG Files)", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3)
                    }
                    .padding(.top, 4)

                    // Icon picker
                    if showIconPicker {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon").font(.caption).foregroundStyle(.secondary)
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 6), spacing: 8) {
                                ForEach(CustomScanCategory.presetIcons, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                        showIconPicker = false
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(selectedIcon == icon
                                                      ? (Color(hexString: selectedColor) ?? .blue).opacity(0.2)
                                                      : Color.secondary.opacity(0.08))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: icon)
                                                .font(.system(size: 15))
                                                .foregroundStyle(selectedIcon == icon
                                                                 ? (Color(hexString: selectedColor) ?? .blue)
                                                                 : .secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Color
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            ForEach(CustomScanCategory.presetColors, id: \.self) { hex in
                                let c = Color(hexString: hex) ?? .blue
                                Button {
                                    selectedColor = hex
                                } label: {
                                    Circle()
                                        .fill(c)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.white, lineWidth: selectedColor == hex ? 3 : 0)
                                        )
                                        .shadow(color: c.opacity(0.5), radius: 3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Extensions
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("File Extensions").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                extensions.append("")
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Theme.accentGreen)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Without the dot — e.g. svg, log, tmp")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        ForEach(extensions.indices, id: \.self) { i in
                            HStack {
                                Text(".")
                                    .foregroundStyle(.secondary)
                                    .font(.system(.body, design: .monospaced))
                                TextField("extension", text: $extensions[i])
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                if extensions.count > 1 {
                                    Button {
                                        extensions.remove(at: i)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Directories
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Directories to Scan").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                pickDirectory()
                            } label: {
                                Label("Add Directory", systemImage: "plus.circle.fill")
                                    .foregroundStyle(Theme.accentGreen)
                            }
                            .buttonStyle(.plain)
                        }
                        if searchPaths.isEmpty {
                            Text("No directories added yet")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(searchPaths, id: \.self) { path in
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(Theme.accentGreen)
                                        .font(.caption)
                                    Text(path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button {
                                        searchPaths.removeAll { $0 == path }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 560)
        .onAppear { populateIfEditing() }
    }

    // MARK: - Private

    private func populateIfEditing() {
        guard let cat = editingCategory else { return }
        name = cat.name
        extensions = cat.extensions.isEmpty ? [""] : cat.extensions
        searchPaths = cat.searchPaths
        selectedColor = cat.colorHex
        selectedIcon = cat.icon
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.title = "Select a directory to scan"
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            if !searchPaths.contains(path) {
                searchPaths.append(path)
            }
        }
    }

    private func save() {
        let cleanedExtensions = extensions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        if let existing = editingCategory {
            var updated = existing
            updated.name = name.trimmingCharacters(in: .whitespaces)
            updated.extensions = cleanedExtensions
            updated.searchPaths = searchPaths
            updated.colorHex = selectedColor
            updated.icon = selectedIcon
            Task { await storageManager.updateCustomCategory(updated) }
        } else {
            let category = CustomScanCategory(
                name: name.trimmingCharacters(in: .whitespaces),
                extensions: cleanedExtensions,
                searchPaths: searchPaths,
                colorHex: selectedColor,
                icon: selectedIcon
            )
            Task { await storageManager.addCustomCategory(category) }
        }
        dismiss()
    }
}
