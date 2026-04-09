//
//  ServicesDiskHealth.swift
//  MacHarmony
//

import Foundation

// MARK: - Disk Health Info

struct DiskHealthInfo: Sendable {
    let deviceName: String
    let mediaName: String
    let diskSize: Int64
    let freeSpace: Int64
    let smartStatus: String
    let fileSystem: String
    let isInternal: Bool
    let isSSD: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: diskSize, countStyle: .file)
    }
    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)
    }
    var usedFraction: Double {
        diskSize > 0 ? Double(diskSize - freeSpace) / Double(diskSize) : 0
    }
    var isHealthy: Bool { smartStatus.lowercased().contains("verified") || smartStatus.lowercased() == "not supported" }
}

// MARK: - Disk Health Service

actor DiskHealthService {

    func load() async -> DiskHealthInfo? {
        return await Task.detached(priority: .utility) {
            Self.runDiskutil()
        }.value
    }

    private static func runDiskutil() -> DiskHealthInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "-plist", "/"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any]
        else { return nil }

        let deviceName   = dict["DeviceNode"] as? String ?? "disk0"
        let mediaName    = dict["MediaName"] as? String ?? "Unknown Disk"
        let diskSize     = dict["TotalSize"] as? Int64 ?? 0
        let freeSpace    = dict["FreeSpace"] as? Int64 ?? (dict["DeviceBlockCount"] as? Int64 ?? 0)
        let smartStatus  = dict["SMARTStatus"] as? String ?? "Not Supported"
        let fileSystem   = dict["FilesystemType"] as? String ?? dict["Content"] as? String ?? "Unknown"
        let isInternal   = dict["Internal"] as? Bool ?? true
        let isSSD        = (dict["SolidState"] as? Bool) ?? false

        // Better free space: use volume resource values
        let actualFree = volumeFreeSpace() ?? freeSpace

        return DiskHealthInfo(
            deviceName: deviceName,
            mediaName: mediaName,
            diskSize: diskSize,
            freeSpace: actualFree,
            smartStatus: smartStatus,
            fileSystem: fileSystem,
            isInternal: isInternal,
            isSSD: isSSD
        )
    }

    private static func volumeFreeSpace() -> Int64? {
        let url = URL(fileURLWithPath: "/")
        let rv = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        if let cap = rv?.volumeAvailableCapacity {
            return Int64(cap)
        }
        return nil
    }
}
