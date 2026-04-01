//
//  ServicesScanHistory.swift
//  Detox
//

import Foundation

// MARK: - Scan Record

struct ScanRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let bytesFreed: Int64
    let totalCleanableBytes: Int64
    let usedFraction: Double

    init(date: Date, bytesFreed: Int64, totalCleanableBytes: Int64, usedFraction: Double) {
        self.id = UUID()
        self.date = date
        self.bytesFreed = bytesFreed
        self.totalCleanableBytes = totalCleanableBytes
        self.usedFraction = usedFraction
    }

    var formattedBytesFreed: String {
        ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)
    }

    var formattedCleanable: String {
        ByteCountFormatter.string(fromByteCount: totalCleanableBytes, countStyle: .file)
    }
}

// MARK: - Scan History Service

actor ScanHistoryService {

    private let storageURL: URL
    private let maxRecords = 90

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Detox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("scan_history.json")
    }

    func record(_ record: ScanRecord) {
        var records = load()
        records.append(record)
        if records.count > maxRecords {
            records = Array(records.suffix(maxRecords))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    func loadAll() -> [ScanRecord] {
        load().sorted { $0.date < $1.date }
    }

    private func load() -> [ScanRecord] {
        guard let data = try? Data(contentsOf: storageURL),
              let records = try? JSONDecoder().decode([ScanRecord].self, from: data)
        else { return [] }
        return records
    }
}
