//
//  ServicesMemoryMonitor.swift
//  MacHarmony
//

import Foundation
import Darwin.Mach

// MARK: - Memory Stats

struct MemoryStats: Sendable {
    let totalBytes: UInt64
    let wiredBytes: UInt64
    let activeBytes: UInt64
    let inactiveBytes: UInt64
    let freeBytes: UInt64
    let compressedBytes: UInt64

    var usedBytes: UInt64 { wiredBytes + activeBytes + compressedBytes }
    var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }

    func formatted(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

// MARK: - Memory Monitor

enum MemoryMonitor {
    static func current() -> MemoryStats? {
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)
        let total = ProcessInfo.processInfo.physicalMemory

        return MemoryStats(
            totalBytes: total,
            wiredBytes: UInt64(info.wire_count) * pageSize,
            activeBytes: UInt64(info.active_count) * pageSize,
            inactiveBytes: UInt64(info.inactive_count) * pageSize,
            freeBytes: UInt64(info.free_count) * pageSize,
            compressedBytes: UInt64(info.compressor_page_count) * pageSize
        )
    }

    /// Best-effort inactive memory release (no root required).
    static func releaseInactiveMemory() {
        malloc_zone_pressure_relief(nil, 0)
    }
}

// MARK: - UI state for “Free inactive memory” feedback

enum MemoryReleaseUIState: Equatable {
    case idle
    case working
    case success
    case failed(String)
}
