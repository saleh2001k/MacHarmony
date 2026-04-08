//
//  ServicesCustomCategoryStore.swift
//  Detox
//

import Foundation

actor CustomCategoryStore {
    private var categories: [CustomScanCategory] = []
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                  .appendingPathComponent("Library/Application Support", isDirectory: true)
        let dir = appSupport.appendingPathComponent("Detox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("custom-categories.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([CustomScanCategory].self, from: data) {
            categories = decoded
        }
    }

    func all() -> [CustomScanCategory] {
        categories
    }

    func add(_ category: CustomScanCategory) {
        categories.append(category)
        save()
    }

    func update(_ category: CustomScanCategory) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            save()
        }
    }

    func delete(id: UUID) {
        categories.removeAll { $0.id == id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
