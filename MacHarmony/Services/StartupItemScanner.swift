//
//  ServicesStartupItemScanner.swift
//  MacHarmony
//

import Foundation

// MARK: - Startup Item Source

enum StartupItemSource: String, Sendable {
    case userLaunchAgent    = "~/Library/LaunchAgents"
    case systemLaunchAgent  = "/Library/LaunchAgents"
    case systemLaunchDaemon = "/Library/LaunchDaemons"
}

// MARK: - Startup Item

struct StartupItem: Identifiable, Sendable {
    let id: UUID
    let label: String
    let path: String
    let source: StartupItemSource
    var isEnabled: Bool
    let programPath: String?
    let runAtLoad: Bool

    var displayName: String {
        // Extract readable name from reverse-DNS label
        let components = label.split(separator: ".")
        if components.count >= 3 {
            return components.dropFirst(2).joined(separator: " ").capitalized
        }
        return label
    }
}

// MARK: - Startup Item Scanner

actor StartupItemScanner {

    private let fm = FileManager.default

    func scan(homeDir: String) -> [StartupItem] {
        var items: [StartupItem] = []

        let locations: [(String, StartupItemSource)] = [
            ("\(homeDir)/Library/LaunchAgents", .userLaunchAgent),
            ("/Library/LaunchAgents", .systemLaunchAgent),
            ("/Library/LaunchDaemons", .systemLaunchDaemon),
        ]

        for (dir, source) in locations {
            let plists = plistFiles(in: dir)
            for path in plists {
                if let item = parseItem(at: path, source: source) {
                    items.append(item)
                }
            }
        }

        return items.sorted { $0.label < $1.label }
    }

    func disable(_ item: StartupItem) throws {
        guard item.isEnabled else { return }
        let disabledPath = item.path + ".disabled"
        try fm.moveItem(atPath: item.path, toPath: disabledPath)
    }

    func enable(_ item: StartupItem) throws {
        guard !item.isEnabled else { return }
        let disabledPath = item.path + ".disabled"
        let enabledPath = String(item.path.dropLast(".disabled".count))
        try fm.moveItem(atPath: disabledPath, toPath: enabledPath)
    }

    // MARK: - Private

    private func plistFiles(in dir: String) -> [String] {
        guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { return [] }
        var paths: [String] = []
        for name in contents {
            if name.hasSuffix(".plist") || name.hasSuffix(".plist.disabled") {
                paths.append("\(dir)/\(name)")
            }
        }
        return paths
    }

    private func parseItem(at path: String, source: StartupItemSource) -> StartupItem? {
        let isEnabled = !path.hasSuffix(".disabled")
        let plistPath = isEnabled ? path : String(path.dropLast(".disabled".count))

        guard let plist = NSDictionary(contentsOfFile: plistPath) ?? NSDictionary(contentsOfFile: path) else {
            return nil
        }

        let label = plist["Label"] as? String ?? (URL(fileURLWithPath: plistPath).deletingPathExtension().lastPathComponent)
        let runAtLoad = plist["RunAtLoad"] as? Bool ?? false

        // Extract executable path
        var programPath: String? = plist["Program"] as? String
        if programPath == nil, let args = plist["ProgramArguments"] as? [String] {
            programPath = args.first
        }

        return StartupItem(
            id: UUID(),
            label: label,
            path: path,
            source: source,
            isEnabled: isEnabled,
            programPath: programPath,
            runAtLoad: runAtLoad
        )
    }
}
