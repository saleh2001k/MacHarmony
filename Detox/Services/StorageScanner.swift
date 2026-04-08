//
//  StorageScanner.swift
//  Detox
//
//  Created by saleh on 16/03/2026.
//

import Foundation

/// Handles the actual scanning of directories and file size calculations.
///
/// Uses FastScanEngine (fts_open) for traversal, SizeCalculator (du -sk) for sizing,
/// and ScanCache for persistent caching across app launches.
actor StorageScanner {

    private let engine = FastScanEngine()
    private let sizeCalc = SizeCalculator()
    private let cache = ScanCache()

    // User-configurable scan filters (set before each scan via configure())
    private var ignoredNames: Set<String> = []
    private var excludedPaths: [String] = []
    private var globalMinBytes: Int64 = 0

    /// Set to true during a scan if any trash root was inaccessible due to missing FDA.
    private(set) var trashScanWasDenied: Bool = false

    // MARK: - Configuration

    func configure(ignoredNames: [String], excludedPaths: [String], globalMinBytes: Int64) {
        self.ignoredNames = Set(ignoredNames)
        self.excludedPaths = excludedPaths
        self.globalMinBytes = globalMinBytes
    }

    // MARK: - Public Methods

    func scanCategory(
        _ category: StorageCategory,
        rootPath: String,
        index: FileIndex? = nil,
        onFileScanned: (@Sendable (String) -> Void)? = nil
    ) async -> [StorageItem] {
        let paths = category.paths(from: rootPath)
        let items: [StorageItem]

        switch category.scanStyle {
        case .nodeModules:
            items = await scanNodeModules(rootPath: rootPath, onFileScanned: onFileScanned)

        case .topLevelDirs:
            let threshold: Int64 = (category == .systemCaches || category == .applicationCaches)
                ? 1024 * 1024   // 1 MB minimum for noisy cache dirs
                : 0
            items = await scanTopLevelDirs(paths: paths, sizeThreshold: threshold, onFileScanned: onFileScanned)

        case .topLevelAll:
            items = await scanTopLevelAll(paths: paths, onFileScanned: onFileScanned)

        case .deepFiles(let extensions):
            if let index, await index.isReady {
                let isHomeWide = paths.count == 1 && paths[0] == rootPath
                var covered = isHomeWide
                if !covered {
                    var allCovered = true
                    for p in paths { if !(await index.covers(p)) { allCovered = false; break } }
                    covered = allCovered
                }
                if covered {
                    items = await index.filter(extensions: Set(extensions), withinPaths: isHomeWide ? nil : paths, ignoredNames: ignoredNames)
                    onFileScanned?("")
                } else {
                    items = await scanFilesDeep(paths: paths, extensions: Set(extensions), minBytes: 0, onFileScanned: onFileScanned)
                }
            } else {
                items = await scanFilesDeep(paths: paths, extensions: Set(extensions), minBytes: 0, onFileScanned: onFileScanned)
            }

        case .deepLargeFiles(let minBytes):
            if let index, await index.isReady {
                items = await index.filter(minBytes: minBytes, withinPaths: paths, ignoredNames: ignoredNames)
                onFileScanned?("")
            } else {
                items = await scanFilesDeep(paths: paths, extensions: nil, minBytes: minBytes, onFileScanned: onFileScanned)
            }

        case .timeMachine:
            items = await scanTimeMachineSnapshots()

        case .trashDirectories:
            items = await scanTrashDirectories(onFileScanned: onFileScanned)
        }

        #if DEBUG
        print("📊 \(category.title): \(items.count) items")
        #endif
        return items.sorted { $0.size > $1.size }
    }

    /// Clears the size cache. Call this after user deletes items.
    func invalidateCache() async {
        await cache.resetStats()
        await cache.invalidateAll()
    }

    /// Returns (hits, misses) from the ScanCache since the last resetStats().
    func cacheStats() async -> (hits: Int, misses: Int) {
        let h = await cache.hitCount
        let m = await cache.missCount
        return (h, m)
    }

    /// Evicts specific paths from the cache. More efficient than invalidateCache()
    /// when only a small number of items were deleted.
    func evictCache(for paths: [String]) async {
        await cache.evict(paths: paths)
    }

    /// Builds a shared FileIndex by traversing rootPath in parallel.
    /// Call once per scan; pass the result to scanCategory(_:rootPath:index:) for instant filtering.
    func buildIndex(
        rootPath: String,
        onProgress: (@Sendable (Int, String) -> Void)? = nil
    ) async -> FileIndex {
        let idx = FileIndex()
        await idx.build(rootPath: rootPath, engine: engine, onProgress: onProgress)
        return idx
    }

    /// Scans a user-defined custom category using the deepFiles strategy.
    func scanCustomCategory(
        _ category: CustomScanCategory,
        onFileScanned: (@Sendable (String) -> Void)? = nil
    ) async -> [StorageItem] {
        let extensions = Set(category.extensions.map { $0.lowercased() })
        let items = await scanFilesDeep(
            paths: category.searchPaths,
            extensions: extensions.isEmpty ? nil : extensions,
            minBytes: 0,
            onFileScanned: onFileScanned
        )
        #if DEBUG
        print("📊 Custom '\(category.name)': \(items.count) items")
        #endif
        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Private: Top-level directory scan

    /// Scans all immediate child directories of each path in `paths`.
    /// Each child directory becomes one StorageItem. Applies `sizeThreshold` filter (bytes).
    private func scanTopLevelDirs(
        paths: [String],
        sizeThreshold: Int64,
        onFileScanned: (@Sendable (String) -> Void)?
    ) async -> [StorageItem] {
        var items: [StorageItem] = []

        for path in paths {
            guard FileManager.default.fileExists(atPath: path) else {
                #if DEBUG
                print("❌ Path does not exist: \(path)")
                #endif
                continue
            }
            #if DEBUG
            print("✅ Scanning top-level: \(path)")
            #endif

            let stream = engine.scanTopLevel(root: path)
            for await entry in stream {
                let size = await resolveSize(for: entry, onFileScanned: onFileScanned)
                guard size > sizeThreshold else { continue }

                items.append(StorageItem(
                    name: (entry.path as NSString).lastPathComponent,
                    path: entry.path,
                    size: size,
                    modifiedDate: entry.modifiedDate
                ))
            }
        }

        return items
    }

    // MARK: - Private: Top-level all (files + dirs)

    /// Scans all immediate children (files and directories) of each path.
    /// Files get their size from the FTS stat struct; directories use SizeCalculator.
    private func scanTopLevelAll(
        paths: [String],
        onFileScanned: (@Sendable (String) -> Void)?
    ) async -> [StorageItem] {
        var items: [StorageItem] = []

        for path in paths {
            guard FileManager.default.fileExists(atPath: path) else {
                #if DEBUG
                print("❌ Path does not exist: \(path)")
                #endif
                continue
            }
            #if DEBUG
            print("✅ Scanning top-level (all): \(path)")
            #endif

            let stream = engine.scanTopLevelAll(root: path)
            for await entry in stream {
                onFileScanned?(entry.path)

                let size: Int64
                if entry.fileSize > 0 {
                    // Regular file — size already known from fts stat
                    size = entry.fileSize
                } else {
                    // Directory — use du -sk via SizeCalculator
                    size = await resolveSize(for: entry, onFileScanned: nil)
                }
                guard size > 0 else { continue }

                items.append(StorageItem(
                    name: (entry.path as NSString).lastPathComponent,
                    path: entry.path,
                    size: size,
                    modifiedDate: entry.modifiedDate
                ))
            }
        }

        return items
    }

    // MARK: - Private: Deep file scan (images, videos, large files)

    /// Recursively finds all files under `paths`, filtered by extension and/or minimum size.
    /// Splits each path into parallel sub-roots for concurrent scanning.
    private func scanFilesDeep(
        paths: [String],
        extensions: Set<String>?,
        minBytes: Int64,
        onFileScanned: (@Sendable (String) -> Void)?
    ) async -> [StorageItem] {
        let fm = FileManager.default

        // Directories to skip when expanding a root into parallel sub-roots
        let skipTopLevel: Set<String> = ["Library", ".Trash", "Trash", "System", "private"]

        // Build list of parallel scan roots
        var scanRoots: [String] = []
        for path in paths {
            guard fm.fileExists(atPath: path) else {
                #if DEBUG
                print("❌ Path does not exist: \(path)")
                #endif
                continue
            }
            #if DEBUG
            print("✅ Scanning files deep (parallel): \(path)")
            #endif

            // Expand to top-level subdirectories for parallelism
            if let children = try? fm.contentsOfDirectory(atPath: path), children.count > 5 {
                let subs = children
                    .filter { !skipTopLevel.contains($0) && !$0.hasPrefix(".") }
                    .map { "\(path)/\($0)" }
                    .filter {
                        var isDir: ObjCBool = false
                        return fm.fileExists(atPath: $0, isDirectory: &isDir) && isDir.boolValue
                    }
                if !subs.isEmpty {
                    scanRoots.append(contentsOf: subs)
                    continue
                }
            }
            scanRoots.append(path)
        }

        guard !scanRoots.isEmpty else { return [] }

        let eng = engine          // capture actor refs (Sendable) before task group
        let ignored = ignoredNames
        let excluded = excludedPaths
        let effectiveMin = max(minBytes, globalMinBytes)

        var items: [StorageItem] = []
        await withTaskGroup(of: [StorageItem].self) { group in
            for root in scanRoots {
                let r = root
                let ext = extensions
                let min = effectiveMin
                group.addTask {
                    var subItems: [StorageItem] = []
                    for await entry in eng.scanFilesDeep(root: r) {
                        onFileScanned?(entry.path)

                        // Skip files inside ignored folder names (e.g. node_modules, .git, build)
                        if !ignored.isEmpty {
                            let components = (entry.path as NSString).pathComponents
                            if components.contains(where: { ignored.contains($0) }) { continue }
                        }

                        // Skip files inside explicitly excluded paths
                        if !excluded.isEmpty {
                            if excluded.contains(where: { entry.path.hasPrefix($0 + "/") || entry.path == $0 }) { continue }
                        }

                        if let ext {
                            let fileExt = (entry.path as NSString).pathExtension.lowercased()
                            if fileExt == "ts" {
                                let name = (entry.path as NSString).lastPathComponent.lowercased()
                                if name.hasSuffix(".d.ts") { continue } // exclude TS declaration files
                            }
                            guard ext.contains(fileExt) else { continue }
                        }
                        guard entry.fileSize >= min else { continue }
                        subItems.append(StorageItem(
                            name: (entry.path as NSString).lastPathComponent,
                            path: entry.path,
                            size: entry.fileSize,
                            modifiedDate: entry.modifiedDate
                        ))
                    }
                    return subItems
                }
            }
            for await subItems in group {
                items.append(contentsOf: subItems)
            }
        }

        return items
    }

    // MARK: - Private: node_modules deep scan

    /// Searches common developer directories for node_modules folders using fts.
    /// FTS_SKIP is set on each found node_modules so we never recurse inside them.
    private func scanNodeModules(
        rootPath: String,
        onFileScanned: (@Sendable (String) -> Void)?
    ) async -> [StorageItem] {
        // Common places developers keep projects
        let searchRoots = [
            "Developer", "Documents", "Desktop", "Projects",
            "src", "code", "workspace", "Sites", "GitHub", "git", "repos"
        ]
        .map { "\(rootPath)/\($0)" }
        .filter { FileManager.default.fileExists(atPath: $0) }

        guard !searchRoots.isEmpty else { return [] }
        #if DEBUG
        print("✅ Scanning node_modules in \(searchRoots.count) roots")
        #endif

        var items: [StorageItem] = []
        let stream = engine.scan(roots: searchRoots, targetNames: ["node_modules"])

        for await entry in stream {
            let size = await resolveSize(for: entry, onFileScanned: onFileScanned)
            guard size > 0 else { continue }

            // Label item with the parent project name: "MyApp (node_modules)"
            let parentName = (entry.path as NSString).deletingLastPathComponent
            let projectName = (parentName as NSString).lastPathComponent
            items.append(StorageItem(
                name: "\(projectName) (node_modules)",
                path: entry.path,
                size: size,
                modifiedDate: entry.modifiedDate
            ))
        }

        return items
    }

    // MARK: - Private: Time Machine Snapshots

    /// Lists local Time Machine snapshots via `tmutil listlocalsnapshots /`.
    private func scanTimeMachineSnapshots() async -> [StorageItem] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["listlocalsnapshots", "/"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return [] }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        var items: [StorageItem] = []
        for line in output.components(separatedBy: .newlines) {
            let name = line.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            // Format: com.apple.TimeMachine.YYYY-MM-DD-HHMMSS.local
            let parts = name.components(separatedBy: ".")
            let dateStr: String
            if let datePart = parts.first(where: { $0.contains("-") }) {
                dateStr = datePart
            } else {
                dateStr = name
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
            let date = formatter.date(from: dateStr) ?? Date()
            items.append(StorageItem(name: name, path: name, size: 0, modifiedDate: date))
        }
        return items
    }

    // MARK: - Private: Trash scan (all locations, FileManager-based)

    /// Enumerates every trash root on the system:
    ///   • ~/.Trash                       (user's home-volume trash)
    ///   • /Volumes/*/.Trashes/{uid}/     (per-volume trash for external drives)
    ///
    /// Uses FileManager.contentsOfDirectory so permission errors are surfaced
    /// as thrown errors rather than silently swallowed by fts_open.
    /// Requires Full Disk Access to be granted to the app; returns an empty array
    /// and logs a warning when access is denied.
    private func scanTrashDirectories(
        onFileScanned: (@Sendable (String) -> Void)?
    ) async -> [StorageItem] {
        trashScanWasDenied = false
        let fm = FileManager.default
        let uid = String(getuid())

        // Collect candidate trash roots, deduplicating by standardized path.
        var seen = Set<String>()
        var roots: [String] = []

        func addRoot(_ url: URL) {
            let p = url.standardizedFileURL.path
            if seen.insert(p).inserted { roots.append(p) }
        }

        // 1. Home-volume trash via the official Foundation API
        for url in fm.urls(for: .trashDirectory, in: .userDomainMask) {
            addRoot(url)
        }
        // 2. Direct path fallback (catches unusual home-dir configurations)
        addRoot(fm.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"))

        // 3. Per-volume trash — mirrors the shell script's /Volumes/*/.Trashes/{uid} logic
        if let volumes = fm.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsRemovableKey, .volumeIsLocalKey],
            options: [.skipHiddenVolumes]
        ) {
            for vol in volumes {
                addRoot(vol.appendingPathComponent(".Trashes/\(uid)"))
            }
        }

        var items: [StorageItem] = []

        for root in roots {
            guard fm.fileExists(atPath: root) else { continue }

            let names: [String]
            do {
                names = try fm.contentsOfDirectory(atPath: root)
            } catch {
                #if DEBUG
                print("⚠️ Trash access denied at \(root): \(error.localizedDescription)")
                print("   → Grant Full Disk Access to Detox in System Settings → Privacy & Security")
                #endif
                trashScanWasDenied = true
                continue
            }

            for name in names {
                guard name != ".DS_Store" else { continue }
                let itemPath = "\(root)/\(name)"
                onFileScanned?(itemPath)

                // File: use stat size directly (no subprocess needed)
                // Directory: use du -sk via SizeCalculator for accurate recursive size
                var isDir: ObjCBool = false
                fm.fileExists(atPath: itemPath, isDirectory: &isDir)

                let size: Int64
                if isDir.boolValue {
                    size = await sizeCalc.calculateSize(at: itemPath)
                } else {
                    // Read allocated size from the filesystem — same as du does
                    if let attrs = try? fm.attributesOfItem(atPath: itemPath),
                       let fileSize = attrs[.size] as? Int64, fileSize > 0 {
                        size = fileSize
                    } else {
                        size = await sizeCalc.calculateSize(at: itemPath)
                    }
                }

                guard size > 0 else { continue }

                let attrs = try? fm.attributesOfItem(atPath: itemPath)
                let modDate = (attrs?[.modificationDate] as? Date) ?? Date()

                items.append(StorageItem(name: name, path: itemPath, size: size, modifiedDate: modDate))
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Private: Cache-first size resolution

    /// Returns size for a discovered entry: cache hit → instant; miss → du -sk + cache write.
    private func resolveSize(
        for entry: DiscoveredEntry,
        onFileScanned: (@Sendable (String) -> Void)?
    ) async -> Int64 {
        // Fire progress callback immediately on discovery, before du completes
        onFileScanned?(entry.path)

        if let cached = await cache.getCached(path: entry.path) {
            #if DEBUG
            print("⚡️ ScanCache HIT: \((entry.path as NSString).lastPathComponent) → \(ByteCountFormatter.string(fromByteCount: cached.size, countStyle: .file))")
            #endif
            return cached.size
        }

        let size = await sizeCalc.calculateSize(at: entry.path)
        #if DEBUG
        print("📐 ScanCache MISS (fresh): \((entry.path as NSString).lastPathComponent) → \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
        #endif

        if size > 0 {
            await cache.cache(path: entry.path, size: size, lastModified: entry.modifiedDate)
        }
        return size
    }
}
