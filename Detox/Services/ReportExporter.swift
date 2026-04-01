//
//  ServicesReportExporter.swift
//  Detox
//

import AppKit
import UniformTypeIdentifiers

struct ReportExporter {

    @MainActor
    static func export(storageManager: StorageManager) {
        let panel = NSSavePanel()
        let dateStr = Date().formatted(.iso8601.year().month().day())
        panel.nameFieldStringValue = "storage-report-\(dateStr).csv"
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var csv = "Category,Name,Path,Size (bytes),Size,Modified\n"
        for (cat, items) in storageManager.storageItems.sorted(by: { $0.key.title < $1.key.title }) {
            for item in items {
                let name = item.name.replacingOccurrences(of: "\"", with: "\"\"")
                let path = item.path.replacingOccurrences(of: "\"", with: "\"\"")
                csv += "\"\(cat.title)\",\"\(name)\",\"\(path)\",\(item.size),\"\(item.formattedSize)\",\"\(item.formattedDate)\"\n"
            }
        }
        for (catId, items) in storageManager.customItems {
            let catName = storageManager.customCategories.first(where: { $0.id == catId })?.name ?? catId.uuidString
            for item in items {
                let name = item.name.replacingOccurrences(of: "\"", with: "\"\"")
                let path = item.path.replacingOccurrences(of: "\"", with: "\"\"")
                csv += "\"\(catName)\",\"\(name)\",\"\(path)\",\(item.size),\"\(item.formattedSize)\",\"\(item.formattedDate)\"\n"
            }
        }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}
