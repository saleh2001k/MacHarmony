//
//  StorageManager.swift
//  MacHarmony
//

import Foundation
import SwiftUI
import Combine
import UserNotifications
import Darwin

// MARK: - Notification names

extension Notification.Name {
    static let showHelp = Notification.Name("com.macharmony.showHelp")
    static let startFullScan = Notification.Name("com.macharmony.startFullScan")
}

// MARK: - DeletionMode

enum DeletionMode: String, CaseIterable {
    case trash = "trash"
    case permanent = "permanent"
    case ask = "ask"

    var displayName: String {
        switch self {
        case .trash: return "Move to Trash"
        case .permanent: return "Delete Permanently"
        case .ask: return "Ask Each Time"
        }
    }
}

// MARK: - StorageManager

@MainActor
class StorageManager: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedCategory: StorageCategory?
    @Published var selectedCustomCategory: CustomScanCategory?
    @Published var selectedTool: ToolType?
    @Published var storageItems: [StorageCategory: [StorageItem]] = [:]
    @Published var customItems: [UUID: [StorageItem]] = [:]
    @Published var customCategories: [CustomScanCategory] = []
    @Published var currentScanPath = ""
    @Published var totalCleanableSize = "0 bytes"
    @Published var usedPercentage: Double = 0.0
    @Published var diskUsageSummary: String = "Calculating..."
    @Published var scanProgress: Double = 0.0
    @Published var rootPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @Published var deletionErrors: [String] = []
    @Published var showDeletionError = false
    @Published var lastScanDate: Date? = nil
    @Published var hasResults: Bool = false
    @Published var scanningCategories: Set<StorageCategory> = []
    @Published var isIndexBuilding = false
    @Published var indexedFileCount = 0
    @Published var scanningCustomCategories: Set<UUID> = []
    @Published var hiddenCategories: Set<String> = {
        let stored = UserDefaults.standard.stringArray(forKey: "hiddenCategories") ?? []
        return Set(stored)
    }()
    /// Which categories are included in a full scan. Empty set = all categories (default / backward-compatible).
    @Published var enabledScanCategories: Set<String> = {
        let stored = UserDefaults.standard.stringArray(forKey: "enabledScanCategories") ?? []
        return Set(stored)
    }()
    @Published var menuBarCategories: Set<String> = {
        let stored = UserDefaults.standard.stringArray(forKey: "menuBarCategories")
        if let stored, !stored.isEmpty { return Set(stored) }
        return Set(["xcodeDerivedData", "nodeModules"])
    }()
    @Published var categoryOrder: [String] = {
        let stored = UserDefaults.standard.stringArray(forKey: "categoryOrder") ?? []
        return stored
    }()
    @Published var ignoredPatterns: [String] = {
        UserDefaults.standard.stringArray(forKey: "ignoredPatterns")
            ?? ["node_modules", ".git", ".hg", ".svn", "build", "dist", ".cache", ".next", "__pycache__", ".gradle"]
    }()
    @Published var excludedScanPaths: [String] = {
        UserDefaults.standard.stringArray(forKey: "excludedScanPaths") ?? []
    }()
    @Published var trashSize: Int64 = 0
    @Published var trashAccessDenied: Bool = false
    @Published var totalBytesFreed: Int64 = {
        Int64(UserDefaults.standard.double(forKey: "totalBytesFreed"))
    }()
    @Published var isDeletingItems = false
    @Published var deletionProgress: Double = 0
    @Published var deletionCurrentName: String = ""
    @Published var deletionCompleted: Int = 0
    @Published var deletionTotal: Int = 0

    // MARK: - Tool: Large File Browser
    @Published var largeFileGroups: [LargeFileGroup] = []
    @Published var isFullScanRunning = false
    @Published var isMenuBarScanRunning = false
    @Published var isLargeFileScanRunning = false

    // MARK: - Tool: Old & Unused Files
    @Published var oldFiles: [StorageItem] = []
    @Published var isOldFileScanRunning = false

    // MARK: - Tool: Empty Folders
    @Published var emptyFolders: [StorageItem] = []
    @Published var isEmptyFolderScanRunning = false

    // MARK: - Tool: App Uninstaller
    @Published var appEntries: [AppEntry] = []
    @Published var isAppScanRunning = false

    // MARK: - Tool: App Cache Breakdown
    @Published var appCacheItems: [StorageItem] = []
    @Published var isAppCacheScanRunning = false

    // MARK: - Tool: Leftover Files
    @Published var leftoverItems: [StorageItem] = []
    @Published var isLeftoverScanRunning = false

    // MARK: - Tool: Startup Items
    @Published var startupItems: [StartupItem] = []
    @Published var isStartupScanRunning = false

    // MARK: - Tool: Memory Monitor
    @Published var memoryStats: MemoryStats? = nil
    @Published var memoryReleaseUIState: MemoryReleaseUIState = .idle

    // MARK: - Tool: Disk Health
    @Published var diskHealthInfo: DiskHealthInfo? = nil
    @Published var isDiskHealthLoading = false

    // MARK: - Tool: Scan History
    @Published var scanHistory: [ScanRecord] = []

    // MARK: - Tool: Safe Mode
    @Published var stagedForDeletion: [StorageItem] = []

    // MARK: - Tool: iCloud Cleaner
    @Published var iCloudItems: [StorageItem] = []
    @Published var isICloudScanRunning = false

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private let scanner = StorageScanner()
    private let customCategoryStore = CustomCategoryStore()
    private let resultsCache = ResultsCache()
    private var lastFileIndex: FileIndex?
    private let emptyFolderScanner = EmptyFolderScanner()
    private let appScanner = AppScanner()
    private let leftoverScanner = LeftoverScanner()
    private let scanHistoryService = ScanHistoryService()
    private let startupItemScanner = StartupItemScanner()
    private let diskHealthService = DiskHealthService()

    // MARK: - Init

    init() {
        normalizeCategoryOrder()
        Task {
            await loadCustomCategories()
            lastScanDate = await resultsCache.getLastScanDate()
            await loadScanHistory()
        }
    }

    // MARK: - Scan

    func scan() async {
        let scanStart = Date()
        let scanID = Int.random(in: 1000...9999)
        #if DEBUG
        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔍 [\(scanID)] FULL SCAN STARTED at \(Self.timestamp())")
        print("   rootPath : \(rootPath)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        #endif

        await Task.yield()

        storageItems.removeAll()
        customItems.removeAll()
        scanProgress = 0
        currentScanPath = ""
        scanningCategories = Set(categoriesToScan)

        // Invalidate the results cache (category item lists) so categories are rebuilt fresh.
        // ScanCache (directory sizes) is intentionally kept — entries are validated by mtime via stat(),
        // so unchanged directories are served from cache, speeding up repeated scans significantly.
        #if DEBUG
        print("🗑️ [\(scanID)] Invalidating ResultsCache (ScanCache preserved for mtime-validated hits)…")
        #endif
        await resultsCache.invalidate()
        #if DEBUG
        print("✅ [\(scanID)] ResultsCache cleared — ScanCache will serve hits for unchanged directories")
        #endif

        // Configure scanner with current user preferences
        let minBytes = Int64(UserDefaults.standard.double(forKey: "minScanFileSizeBytes"))
        #if DEBUG
        print("⚙️ [\(scanID)] Scanner config — minBytes:\(minBytes)  ignoredPatterns:\(ignoredPatterns.count)  excludedPaths:\(excludedScanPaths.count)")
        #endif
        await scanner.configure(
            ignoredNames: ignoredPatterns,
            excludedPaths: excludedScanPaths,
            globalMinBytes: minBytes
        )

        // Phase 1 — build shared file index (one parallel traversal)
        let indexStart = Date()
        #if DEBUG
        print("📇 [\(scanID)] Building FileIndex from \(rootPath)…")
        #endif
        isIndexBuilding = true
        indexedFileCount = 0
        let fileIndex = await scanner.buildIndex(rootPath: rootPath) { [weak self] count, path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.indexedFileCount = count
                if !path.isEmpty { self.currentScanPath = path }
            }
        }
        isIndexBuilding = false
        scanProgress = 0.05
        lastFileIndex = fileIndex
        #if DEBUG
        print("📇 [\(scanID)] FileIndex ready — \(indexedFileCount) files in \(Self.elapsed(since: indexStart))")
        #endif

        let categories = categoriesToScan
        #if DEBUG
        print("🚀 [\(scanID)] Scanning \(categories.count) of \(orderedCategories.count) categories in parallel…")
        #endif
        let categoriesStart = Date()

        await performCategoryScan(categories, fileIndex: fileIndex, scanID: scanID)

        #if DEBUG
        print("⏱️ [\(scanID)] All \(categories.count) categories done in \(Self.elapsed(since: categoriesStart))")
        #endif

        // Scan custom categories in parallel (second group, after built-in scan)
        if !customCategories.isEmpty {
            let customCats = customCategories
            await withTaskGroup(of: (UUID, [StorageItem]).self) { group in
                for category in customCats {
                    group.addTask {
                        let items = await self.scanner.scanCustomCategory(category) { path in
                            Task { @MainActor [weak self] in
                                self?.currentScanPath = path
                            }
                        }
                        return (category.id, items)
                    }
                }
                for await (id, items) in group {
                    customItems[id] = items
                    let name = customCats.first(where: { $0.id == id })?.name ?? id.uuidString
                    #if DEBUG
                    print("📦 Custom '\(name)': \(items.count) items")
                    #endif
                }
            }
        }

        // Drain any pending main-actor callbacks that were queued during parallel scanning
        // before triggering the expensive view transition.
        for _ in 0..<8 { await Task.yield() }

        currentScanPath = ""
        updateTotalSize()
        updateDiskUsage()

        // Sync trashSize from the scanned trash items so the stat card stays accurate.
        // If the trash folder is readable but empty, items will be [] — that's fine.
        // If FDA was denied, the scanner sets trashScanWasDenied; use that directly
        // instead of re-probing (re-probing gives a false-negative when the pre-flight
        // check passes but the actual directory enumeration fails).
        let trashItems = storageItems[.trash] ?? []
        trashSize = trashItems.reduce(0) { $0 + $1.size }
        trashAccessDenied = await scanner.trashScanWasDenied

        lastScanDate = Date()

        // Yield once more so SwiftUI can settle before switching to the results view.
        await Task.yield()
        hasResults = true

        // Execute the user's default action after scan preference
        let postScanAction = UserDefaults.standard.string(forKey: "defaultActionAfterScan") ?? "dashboard"
        if postScanAction == "biggestCategory" {
            let biggest = storageItems.max {
                $0.value.reduce(0) { $0 + $1.size } < $1.value.reduce(0) { $0 + $1.size }
            }
            if let cat = biggest?.key {
                selectedCategory = cat
                selectedCustomCategory = nil
            }
        }

        let builtinSnapshot = storageItems.reduce(into: [String: [StorageItem]]()) { $0[$1.key.rawValue] = $1.value }
        let customSnapshot  = customItems.reduce(into: [String: [StorageItem]]())  { $0[$1.key.uuidString] = $1.value }
        await resultsCache.save(ResultsCache.CachedResults(
            scannedAt: lastScanDate!,
            builtinItems: builtinSnapshot,
            customItems: customSnapshot
        ))

        // Log ScanCache hit/miss ratio so it's clear whether anything was served from cache
        let stats = await scanner.cacheStats()
        let totalItems = storageItems.values.flatMap { $0 }.count
        let totalBytes = storageItems.values.flatMap { $0 }.reduce(0) { $0 + $1.size }
        #if DEBUG
        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✨ [\(scanID)] SCAN COMPLETE in \(Self.elapsed(since: scanStart))")
        print("   Items    : \(totalItems) across \(storageItems.count) categories")
        print("   Total    : \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))")
        print("   Cache    : \(stats.hits) hits / \(stats.misses) misses")
        if stats.hits > 0 {
            print("   ⚠️  Cache hits > 0 — some sizes came from cache, not fresh disk reads")
        } else {
            print("   ✅ Zero cache hits — all sizes read fresh from disk")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")
        #endif

        // Record this scan in history
        await recordScanSession()
    }

    // MARK: - Shared Category Scan Helper

    private func performCategoryScan(
        _ categories: [StorageCategory],
        fileIndex: FileIndex,
        scanID: Int
    ) async {
        let categoryCount = Double(categories.count)
        var completedCategories = 0

        await withTaskGroup(of: (StorageCategory, [StorageItem]).self) { group in
            for (index, category) in categories.enumerated() {
                let categoryBase = Double(index) / categoryCount
                let categorySlice = 1.0 / categoryCount

                group.addTask {
                    nonisolated(unsafe) var filesScanned = 0
                    let catStart = Date()
                    let items = await self.scanner.scanCategory(
                        category,
                        rootPath: self.rootPath,
                        index: fileIndex,
                        onFileScanned: { path in
                            filesScanned += 1
                            guard filesScanned % 25 == 0 else { return }
                            let n = filesScanned
                            let p = path
                            Task { @MainActor [weak self] in
                                guard let self else { return }
                                let intra = 1.0 - exp(-Double(n) / 300.0)
                                let proposed = categoryBase + categorySlice * intra
                                if proposed > self.scanProgress {
                                    self.scanProgress = proposed
                                }
                                self.currentScanPath = p
                            }
                        }
                    )
                    let totalSize = items.reduce(0) { $0 + $1.size }
                    #if DEBUG
                    print("   📦 [\(scanID)] \(category.title): \(items.count) items  \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))  (\(Self.elapsed(since: catStart)))")
                    #endif
                    return (category, items)
                }
            }

            for await (category, items) in group {
                storageItems[category] = items
                scanningCategories.remove(category)
                completedCategories += 1
                scanProgress = 0.05 + 0.95 * Double(completedCategories) / categoryCount
            }
        }
        scanningCategories = []
    }

    // MARK: - Menu Bar Partial Scan

    func scanMenuBarCategories() async {
        let categoriesToScan = menuBarVisibleCategories
        guard !categoriesToScan.isEmpty else { return }
        isMenuBarScanRunning = true
        defer { isMenuBarScanRunning = false }

        let scanID = Int.random(in: 1000...9999)
        #if DEBUG
        print("🔍 [\(scanID)] MENU BAR SCAN: \(categoriesToScan.map(\.title).joined(separator: ", "))")
        #endif

        await Task.yield()

        for cat in categoriesToScan { storageItems[cat] = nil }
        scanProgress = 0
        currentScanPath = ""
        scanningCategories = Set(categoriesToScan)

        let minBytes = Int64(UserDefaults.standard.double(forKey: "minScanFileSizeBytes"))
        await scanner.configure(
            ignoredNames: ignoredPatterns,
            excludedPaths: excludedScanPaths,
            globalMinBytes: minBytes
        )

        isIndexBuilding = true
        indexedFileCount = 0
        let fileIndex = await scanner.buildIndex(rootPath: rootPath) { [weak self] count, path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.indexedFileCount = count
                if !path.isEmpty { self.currentScanPath = path }
            }
        }
        isIndexBuilding = false
        scanProgress = 0.05
        lastFileIndex = fileIndex

        await performCategoryScan(categoriesToScan, fileIndex: fileIndex, scanID: scanID)

        for _ in 0..<4 { await Task.yield() }
        currentScanPath = ""
        updateTotalSize()
        updateDiskUsage()
        lastScanDate = Date()
        hasResults = !storageItems.isEmpty

        #if DEBUG
        print("✅ [\(scanID)] Menu bar scan complete.")
        #endif
    }

    // MARK: - Log helpers

    nonisolated private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }

    nonisolated private static func elapsed(since start: Date) -> String {
        let s = Date().timeIntervalSince(start)
        return s >= 1 ? String(format: "%.2fs", s) : String(format: "%.0fms", s * 1000)
    }

    // MARK: - Load Cached Results

    func loadCachedResultsIfFresh() async -> Bool {
        let storedTTL = UserDefaults.standard.double(forKey: "resultsCacheTTL")
        let ttl = storedTTL > 0 ? storedTTL : 3600
        guard let cached = await resultsCache.load(ttl: ttl) else { return false }

        for (key, items) in cached.builtinItems {
            if let category = StorageCategory(rawValue: key) {
                storageItems[category] = items
            }
        }
        for (key, items) in cached.customItems {
            if let uuid = UUID(uuidString: key) {
                customItems[uuid] = items
            }
        }
        lastScanDate = cached.scannedAt
        hasResults = true
        updateTotalSize()
        updateDiskUsage()

        await loadScanHistory()
        if scanHistory.isEmpty {
            let cleanable = storageItems.values.flatMap { $0 }.reduce(0) { $0 + $1.size }
                + customItems.values.flatMap { $0 }.reduce(0) { $0 + $1.size }
            let record = ScanRecord(
                date: cached.scannedAt,
                bytesFreed: totalBytesFreed,
                totalCleanableBytes: cleanable,
                usedFraction: usedPercentage
            )
            await scanHistoryService.record(record)
            scanHistory = await scanHistoryService.loadAll()
        }
        return true
    }

    // MARK: - Delete Items

    func deleteItems(_ items: [StorageItem], from category: StorageCategory, mode: DeletionMode = .permanent) async {
        let (deleted, failed) = await performDeletion(items, mode: mode) { [weak self] deletedItem in
            // Remove each item from the list immediately as it's deleted (live feedback)
            self?.storageItems[category]?.removeAll { $0.path == deletedItem.path }
            self?.updateTotalSize()
        }

        updateDiskUsage()

        if !deleted.isEmpty {
            await scanner.evictCache(for: deleted)
            await resultsCache.invalidate()
        }
        if !failed.isEmpty {
            deletionErrors = failed
            showDeletionError = true
        }
    }

    func deleteItems(_ items: [StorageItem], fromCustom categoryId: UUID, mode: DeletionMode = .permanent) async {
        let (deleted, failed) = await performDeletion(items, mode: mode) { [weak self] deletedItem in
            self?.customItems[categoryId]?.removeAll { $0.path == deletedItem.path }
            self?.updateTotalSize()
        }

        updateDiskUsage()

        if !deleted.isEmpty {
            await scanner.evictCache(for: deleted)
            await resultsCache.invalidate()
        }
        if !failed.isEmpty {
            deletionErrors = failed
            showDeletionError = true
        }
    }

    // MARK: - Accessors

    func items(for category: StorageCategory) -> [StorageItem] {
        storageItems[category] ?? []
    }

    // MARK: - Category Visibility

    var visibleCategories: [StorageCategory] {
        let base = orderedCategories.filter { !hiddenCategories.contains($0.rawValue) }
        guard !enabledScanCategories.isEmpty else { return base }
        return base.filter { enabledScanCategories.contains($0.rawValue) }
    }

    var menuBarVisibleCategories: [StorageCategory] {
        orderedCategories.filter { menuBarCategories.contains($0.rawValue) }
    }

    /// Categories that will actually be scanned on the next full scan.
    /// Respects `enabledScanCategories` — empty set means all categories.
    var categoriesToScan: [StorageCategory] {
        guard !enabledScanCategories.isEmpty else { return orderedCategories }
        return orderedCategories.filter { enabledScanCategories.contains($0.rawValue) }
    }

    func isCategoryEnabled(_ category: StorageCategory) -> Bool {
        enabledScanCategories.isEmpty || enabledScanCategories.contains(category.rawValue)
    }

    func setEnabledCategories(_ rawValues: Set<String>) {
        enabledScanCategories = rawValues
        UserDefaults.standard.set(Array(rawValues), forKey: "enabledScanCategories")
    }

    func toggleCategoryEnabled(_ category: StorageCategory) {
        if enabledScanCategories.isEmpty {
            // Expand from "all" to "all minus this one"
            enabledScanCategories = Set(StorageCategory.allCases.map(\.rawValue))
        }
        if enabledScanCategories.contains(category.rawValue) {
            enabledScanCategories.remove(category.rawValue)
        } else {
            enabledScanCategories.insert(category.rawValue)
        }
        // Collapse back to "all" if every category is re-enabled
        if enabledScanCategories.count == StorageCategory.allCases.count {
            enabledScanCategories = Set()
        }
        UserDefaults.standard.set(Array(enabledScanCategories), forKey: "enabledScanCategories")
    }

    /// Re-reads `enabledScanCategories` from UserDefaults — call after onboarding writes it.
    func syncEnabledCategoriesFromDefaults() {
        let stored = UserDefaults.standard.stringArray(forKey: "enabledScanCategories") ?? []
        enabledScanCategories = Set(stored)
    }

    var orderedCategories: [StorageCategory] {
        let stored = categoryOrder.compactMap { StorageCategory(rawValue: $0) }
        let missing = StorageCategory.allCases.filter { cat in
            !stored.contains(cat)
        }
        return stored + missing
    }

    func moveCategories(fromOffsets: IndexSet, toOffset: Int) {
        var ordered = orderedCategories
        ordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        categoryOrder = ordered.map(\.rawValue)
        UserDefaults.standard.set(categoryOrder, forKey: "categoryOrder")
    }

    func resetCategoryOrder() {
        let defaultOrder = StorageCategory.allCases.map(\.rawValue)
        categoryOrder = defaultOrder
        UserDefaults.standard.set(defaultOrder, forKey: "categoryOrder")
    }

    // MARK: - Ignored Patterns

    func addIgnoredPattern(_ pattern: String) {
        guard !ignoredPatterns.contains(pattern) else { return }
        ignoredPatterns.append(pattern)
        UserDefaults.standard.set(ignoredPatterns, forKey: "ignoredPatterns")
    }

    func removeIgnoredPattern(_ pattern: String) {
        ignoredPatterns.removeAll { $0 == pattern }
        UserDefaults.standard.set(ignoredPatterns, forKey: "ignoredPatterns")
    }

    // MARK: - Excluded Paths

    func addExcludedPath(_ path: String) {
        guard !excludedScanPaths.contains(path) else { return }
        excludedScanPaths.append(path)
        UserDefaults.standard.set(excludedScanPaths, forKey: "excludedScanPaths")
    }

    func removeExcludedPath(_ path: String) {
        excludedScanPaths.removeAll { $0 == path }
        UserDefaults.standard.set(excludedScanPaths, forKey: "excludedScanPaths")
    }

    // MARK: - Reset All Preferences

    func resetAllPreferences() {
        // Category order
        resetCategoryOrder()

        // Ignored patterns
        let defaultPatterns = ["node_modules", ".git", ".hg", ".svn", "build", "dist", ".cache", ".next", "__pycache__", ".gradle"]
        ignoredPatterns = defaultPatterns
        UserDefaults.standard.set(defaultPatterns, forKey: "ignoredPatterns")

        // Excluded paths
        excludedScanPaths = []
        UserDefaults.standard.set([], forKey: "excludedScanPaths")

        // AppStorage-backed keys
        let ud = UserDefaults.standard
        ud.set("ask",       forKey: "deletionMode")
        ud.set(3600.0,      forKey: "resultsCacheTTL")
        ud.set(false,       forKey: "autoScanEnabled")
        ud.set(86400.0,     forKey: "autoScanInterval")
        ud.set(true,        forKey: "useDarkMode")
        ud.set(true,        forKey: "notificationsEnabled")
        ud.set(0.85,        forKey: "notificationThreshold")
        ud.set("dashboard", forKey: "defaultActionAfterScan")
        ud.set("fast",      forKey: "performanceMode")
        ud.set(0.0,         forKey: "minScanFileSizeBytes")
        ud.set("csv",       forKey: "exportFormat")
        ud.set(false,       forKey: "exportIncludeHidden")
        ud.set("",          forKey: "exportDestination")

        menuBarCategories = Set(["xcodeDerivedData", "nodeModules"])
        ud.set(["xcodeDerivedData", "nodeModules"], forKey: "menuBarCategories")

        #if DEBUG
        print("🔄 All preferences reset to defaults.")
        #endif
    }

    func toggleCategoryVisibility(_ category: StorageCategory) {
        if hiddenCategories.contains(category.rawValue) {
            hiddenCategories.remove(category.rawValue)
        } else {
            hiddenCategories.insert(category.rawValue)
        }
        UserDefaults.standard.set(Array(hiddenCategories), forKey: "hiddenCategories")
    }

    func isCategoryHidden(_ category: StorageCategory) -> Bool {
        hiddenCategories.contains(category.rawValue)
    }

    func isInMenuBar(_ category: StorageCategory) -> Bool {
        menuBarCategories.contains(category.rawValue)
    }

    func toggleMenuBarCategory(_ category: StorageCategory) {
        if menuBarCategories.contains(category.rawValue) {
            menuBarCategories.remove(category.rawValue)
        } else {
            menuBarCategories.insert(category.rawValue)
        }
        UserDefaults.standard.set(Array(menuBarCategories), forKey: "menuBarCategories")
    }

    // MARK: - Single Custom Category Scan

    func scanSingleCustomCategory(_ category: CustomScanCategory) async {
        scanningCustomCategories.insert(category.id)
        let items = await scanner.scanCustomCategory(category) { path in
            Task { @MainActor [weak self] in
                self?.currentScanPath = path
            }
        }
        customItems[category.id] = items
        scanningCustomCategories.remove(category.id)
        updateTotalSize()
        // Persist updated results to cache
        let builtinSnapshot = storageItems.reduce(into: [String: [StorageItem]]()) { $0[$1.key.rawValue] = $1.value }
        let customSnapshot  = customItems.reduce(into: [String: [StorageItem]]()) { $0[$1.key.uuidString] = $1.value }
        let scanDate = lastScanDate ?? Date()
        await resultsCache.save(ResultsCache.CachedResults(
            scannedAt: scanDate,
            builtinItems: builtinSnapshot,
            customItems: customSnapshot
        ))
    }

    func categorySize(for category: StorageCategory) -> String {
        let total = (storageItems[category] ?? []).reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    func customCategorySize(for id: UUID) -> String {
        let total = (customItems[id] ?? []).reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    // MARK: - Custom Category CRUD

    func loadCustomCategories() async {
        customCategories = await customCategoryStore.all()
    }

    func addCustomCategory(_ category: CustomScanCategory) async {
        await customCategoryStore.add(category)
        customCategories = await customCategoryStore.all()
        // Auto-scan the new category immediately
        await scanSingleCustomCategory(category)
    }

    func updateCustomCategory(_ category: CustomScanCategory) async {
        await customCategoryStore.update(category)
        customCategories = await customCategoryStore.all()
    }

    func deleteCustomCategory(id: UUID) async {
        await customCategoryStore.delete(id: id)
        customCategories = await customCategoryStore.all()
        customItems.removeValue(forKey: id)
        if selectedCustomCategory?.id == id {
            selectedCustomCategory = nil
        }
        updateTotalSize()
        await resultsCache.invalidate()
    }

    // MARK: - Private Helpers

    /// Deletes items one-by-one on a background thread, calling `onItemDeleted` on the
    /// main actor after each success so the list updates live without blocking the UI.
    private func performDeletion(
        _ items: [StorageItem],
        mode: DeletionMode = .permanent,
        onItemDeleted: ((StorageItem) -> Void)? = nil
    ) async -> (deleted: [String], failed: [String]) {
        isDeletingItems = true
        deletionTotal = items.count
        deletionCompleted = 0
        deletionProgress = 0
        deletionCurrentName = items.first?.name ?? ""

        var deleted: [String] = []
        var failed: [String] = []

        for item in items {
            deletionCurrentName = item.name

            // Run the actual file-system call off the main thread so the UI stays responsive.
            // `await Task.detached.value` suspends the main actor during I/O, allowing
            // SwiftUI to render progress updates between each file deletion.
            let path = item.path
            let success = await Task.detached(priority: .userInitiated) {
                let url = URL(fileURLWithPath: path)
                do {
                    if mode == .trash {
                        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    } else {
                        try FileManager.default.removeItem(at: url)
                    }
                    return true
                } catch {
                    #if DEBUG
                    print("⚠️ Delete failed: \(path) — \(error)")
                    #endif
                    return false
                }
            }.value

            if success {
                deleted.append(item.path)
                totalBytesFreed += item.size
                onItemDeleted?(item)
                #if DEBUG
                print("🗑️ Deleted: \(item.path)")
                #endif
            } else {
                failed.append(item.name)
            }

            deletionCompleted += 1
            deletionProgress = Double(deletionCompleted) / Double(max(1, items.count))
        }

        isDeletingItems = false
        deletionCurrentName = ""
        UserDefaults.standard.set(Double(totalBytesFreed), forKey: "totalBytesFreed")
        await refreshTrashSize()
        return (deleted, failed)
    }

    private func updateTotalSize() {
        let builtin = storageItems.values.flatMap { $0 }.reduce(0) { $0 + $1.size }
        let custom  = customItems.values.flatMap { $0 }.reduce(0) { $0 + $1.size }
        totalCleanableSize = ByteCountFormatter.string(fromByteCount: builtin + custom, countStyle: .file)
    }

    private func updateDiskUsage() {
        let url = URL(fileURLWithPath: rootPath)
        if let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
           let total = values.volumeTotalCapacity,
           let available = values.volumeAvailableCapacity {
            let used = total - available
            usedPercentage = max(0, min(1, Double(used) / Double(total)))
            let fmt = ByteCountFormatter()
            fmt.countStyle = .file
            diskUsageSummary = "\(fmt.string(fromByteCount: Int64(used))) used of \(fmt.string(fromByteCount: Int64(total)))"
        } else {
            diskUsageSummary = "Storage info unavailable"
            usedPercentage = 0
        }
    }

    private func normalizeCategoryOrder() {
        let validSet = Set(StorageCategory.allCases.map(\.rawValue))
        let cleaned = categoryOrder.filter { validSet.contains($0) }
        let missing = StorageCategory.allCases
            .map(\.rawValue)
            .filter { !cleaned.contains($0) }
        let normalized = cleaned + missing
        if normalized != categoryOrder {
            categoryOrder = normalized
            UserDefaults.standard.set(categoryOrder, forKey: "categoryOrder")
        }
    }

    // MARK: - Trash Size

    func refreshTrashSize() async {
        let fm = FileManager.default
        var total: Int64 = 0

        var trashRoots: [URL] = [
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        ]

        let uid = getuid()
        if let volumeURLs = fm.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) {
            for volume in volumeURLs {
                let perVolumeTrash = volume
                    .appendingPathComponent(".Trashes", isDirectory: true)
                    .appendingPathComponent(String(uid), isDirectory: true)
                trashRoots.append(perVolumeTrash)
            }
        }

        // Avoid double-counting if multiple roots resolve to the same path.
        var seenRoots = Set<String>()
        for root in trashRoots {
            let normalizedRoot = root.standardizedFileURL.path
            guard seenRoots.insert(normalizedRoot).inserted else { continue }
            guard fm.fileExists(atPath: normalizedRoot) else { continue }

            // Prefer `du -sk` because it reflects Finder-visible directory sizes more reliably.
            let duSize = await Task.detached(priority: .utility) {
                Self.directorySizeUsingDU(path: normalizedRoot)
            }.value

            if duSize > 0 {
                total += duSize
                continue
            }

            // Fallback: recursive file summation.
            if let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: normalizedRoot),
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey],
                options: []
            ) {
                while let url = enumerator.nextObject() as? URL {
                    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey]),
                          values.isRegularFile == true else { continue }
                    if let alloc = values.totalFileAllocatedSize {
                        total += Int64(alloc)
                    } else if let size = values.fileSize {
                        total += Int64(size)
                    }
                }
            }
        }

        trashSize = total
    }

    nonisolated private static func directorySizeUsingDU(path: String) -> Int64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do { try process.run() } catch { return 0 }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return 0 }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return 0 }
        guard let firstField = output.split(whereSeparator: \.isWhitespace).first,
              let kiloBytes = Int64(firstField) else { return 0 }
        return kiloBytes * 1024
    }

    /// Opens the Full Disk Access pane in System Settings so the user can grant it.
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Tool: Large File Browser

    /// Merges built-in + custom scan results (deduped by path) for tools when `FileIndex` is unavailable.
    private func mergedScanItemsForTools() -> [StorageItem] {
        var byPath: [String: StorageItem] = [:]
        for item in storageItems.values.flatMap({ $0 }) {
            if let existing = byPath[item.path] {
                if item.size > existing.size { byPath[item.path] = item }
            } else {
                byPath[item.path] = item
            }
        }
        for item in customItems.values.flatMap({ $0 }) {
            if let existing = byPath[item.path] {
                if item.size > existing.size { byPath[item.path] = item }
            } else {
                byPath[item.path] = item
            }
        }
        return Array(byPath.values)
    }

    func scanLargeFiles(minBytes: Int64) async {
        isLargeFileScanRunning = true
        defer { isLargeFileScanRunning = false }

        var items: [StorageItem] = []
        if let index = lastFileIndex, await index.isReady {
            items = await index.filter(minBytes: minBytes, ignoredNames: Set(ignoredPatterns))
        } else {
            items = mergedScanItemsForTools().filter { $0.size >= minBytes }
        }

        let grouped = Dictionary(grouping: items) { item -> String in
            let ext = (item.path as NSString).pathExtension.lowercased()
            return Self.largeFileTypeGroup(for: ext)
        }
        largeFileGroups = grouped
            .map { LargeFileGroup(typeName: $0.key, items: $0.value.sorted { $0.size > $1.size }) }
            .sorted { $0.totalSize > $1.totalSize }
    }

    private static func largeFileTypeGroup(for ext: String) -> String {
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp", "webp": return "Images"
        case "mp4", "mov", "avi", "mkv", "m4v", "wmv", "webm":           return "Videos"
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar", "dmg", "pkg": return "Archives"
        case "mp3", "aac", "flac", "wav", "aiff", "m4a":                 return "Audio"
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx":        return "Documents"
        case "ipa", "xcarchive":                                          return "App Bundles"
        default:                                                          return "Other"
        }
    }

    func deleteLargeFiles(_ items: [StorageItem], mode: DeletionMode) async {
        let (deleted, failed) = await performDeletion(items, mode: mode)
        let deletedSet = Set(deleted)
        for i in largeFileGroups.indices {
            largeFileGroups[i].items.removeAll { deletedSet.contains($0.path) }
        }
        largeFileGroups.removeAll { $0.items.isEmpty }
        if !failed.isEmpty { deletionErrors = failed; showDeletionError = true }
    }

    // MARK: - Tool: Old & Unused Files

    func scanOldFiles(olderThanMonths months: Int) async {
        isOldFileScanRunning = true
        defer { isOldFileScanRunning = false }

        let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()

        if let index = lastFileIndex, await index.isReady {
            let allEntries = await index.entries
            oldFiles = allEntries
                .filter { $0.modifiedDate < cutoff }
                .map { StorageItem(name: $0.name, path: $0.path, size: $0.size, modifiedDate: $0.modifiedDate) }
                .sorted { $0.size > $1.size }
        } else {
            oldFiles = mergedScanItemsForTools()
                .filter { $0.modifiedDate < cutoff }
                .sorted { $0.size > $1.size }
        }
    }

    func deleteOldFiles(_ items: [StorageItem], mode: DeletionMode) async {
        let (deleted, failed) = await performDeletion(items, mode: mode)
        let deletedSet = Set(deleted)
        oldFiles.removeAll { deletedSet.contains($0.path) }
        if !failed.isEmpty { deletionErrors = failed; showDeletionError = true }
    }

    // MARK: - Tool: Empty Folders

    func scanEmptyFolders() async {
        isEmptyFolderScanRunning = true
        defer { isEmptyFolderScanRunning = false }
        emptyFolders = await emptyFolderScanner.scan(rootPath: rootPath)
    }

    func deleteEmptyFolders(_ items: [StorageItem], mode: DeletionMode) async {
        let (deleted, failed) = await performDeletion(items, mode: mode)
        let deletedSet = Set(deleted)
        emptyFolders.removeAll { deletedSet.contains($0.path) }
        if !failed.isEmpty { deletionErrors = failed; showDeletionError = true }
    }

    // MARK: - Tool: App Uninstaller

    func scanApps() async {
        isAppScanRunning = true
        defer { isAppScanRunning = false }
        appEntries = await appScanner.scanApps(homeDir: rootPath)
    }

    func removeApp(_ app: AppEntry, mode: DeletionMode) async {
        var paths: [StorageItem] = []
        // Bundle
        let bundleAttrs = try? fileManager.attributesOfItem(atPath: app.installPath)
        let modDate = bundleAttrs?[.modificationDate] as? Date ?? Date()
        paths.append(StorageItem(name: app.name, path: app.installPath, size: app.bundleSize, modifiedDate: modDate))
        // Support items
        paths.append(contentsOf: app.supportItems)

        let (deleted, failed) = await performDeletion(paths, mode: mode)
        let deletedSet = Set(deleted)
        appEntries.removeAll { $0.installPath == app.installPath || deletedSet.contains($0.installPath) }
        if !failed.isEmpty { deletionErrors = failed; showDeletionError = true }
    }

    // MARK: - Tool: App Cache Breakdown

    func scanAppCaches() async {
        isAppCacheScanRunning = true
        defer { isAppCacheScanRunning = false }

        let cacheDir = "\(rootPath)/Library/Caches"
        guard let contents = try? fileManager.contentsOfDirectory(atPath: cacheDir) else { return }

        var items: [StorageItem] = []
        await withTaskGroup(of: StorageItem?.self) { group in
            for name in contents where !name.hasPrefix(".") {
                let fullPath = "\(cacheDir)/\(name)"
                group.addTask {
                    let size = await Task.detached(priority: .utility) {
                        var total: Int64 = 0
                        if let e = FileManager.default.enumerator(atPath: fullPath) {
                            while let p = e.nextObject() as? String {
                                let fp = (fullPath as NSString).appendingPathComponent(p)
                                let s = (try? FileManager.default.attributesOfItem(atPath: fp))?[.size] as? Int64 ?? 0
                                total += s
                            }
                        } else {
                            total = (try? FileManager.default.attributesOfItem(atPath: fullPath))?[.size] as? Int64 ?? 0
                        }
                        return total
                    }.value
                    guard size > 0 else { return nil }
                    let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath)
                    let modDate = attrs?[.modificationDate] as? Date ?? Date()
                    return StorageItem(name: name, path: fullPath, size: size, modifiedDate: modDate)
                }
            }
            for await item in group {
                if let item { items.append(item) }
            }
        }
        appCacheItems = items.sorted { $0.size > $1.size }
    }

    func deleteAppCacheItems(_ items: [StorageItem], mode: DeletionMode) async {
        let (deleted, failed) = await performDeletion(items, mode: mode)
        let deletedSet = Set(deleted)
        appCacheItems.removeAll { deletedSet.contains($0.path) }
        if !failed.isEmpty { deletionErrors = failed; showDeletionError = true }
    }

    // MARK: - Tool: Leftover Files

    func scanLeftovers() async {
        isLeftoverScanRunning = true
        defer { isLeftoverScanRunning = false }

        let installedIDs = Set(appEntries.map { $0.bundleID }.filter { !$0.isEmpty })
        leftoverItems = await leftoverScanner.scan(homeDir: rootPath, installedBundleIDs: installedIDs)
    }

    func deleteLeftoverItems(_ items: [StorageItem], mode: DeletionMode) async {
        let (deleted, failed) = await performDeletion(items, mode: mode)
        let deletedSet = Set(deleted)
        leftoverItems.removeAll { deletedSet.contains($0.path) }
        if !failed.isEmpty { deletionErrors = failed; showDeletionError = true }
    }

    // MARK: - Tool: Startup Items

    func scanStartupItems() async {
        isStartupScanRunning = true
        defer { isStartupScanRunning = false }
        startupItems = await startupItemScanner.scan(homeDir: rootPath)
    }

    func disableStartupItem(_ item: StartupItem) async {
        do {
            try await startupItemScanner.disable(item)
            if let idx = startupItems.firstIndex(where: { $0.id == item.id }) {
                startupItems[idx] = StartupItem(
                    id: item.id, label: item.label,
                    path: item.path + ".disabled",
                    source: item.source, isEnabled: false,
                    programPath: item.programPath, runAtLoad: item.runAtLoad
                )
            }
        } catch {
            deletionErrors = [error.localizedDescription]
            showDeletionError = true
        }
    }

    func enableStartupItem(_ item: StartupItem) async {
        do {
            try await startupItemScanner.enable(item)
            let enabledPath = String(item.path.dropLast(".disabled".count))
            if let idx = startupItems.firstIndex(where: { $0.id == item.id }) {
                startupItems[idx] = StartupItem(
                    id: item.id, label: item.label,
                    path: enabledPath,
                    source: item.source, isEnabled: true,
                    programPath: item.programPath, runAtLoad: item.runAtLoad
                )
            }
        } catch {
            deletionErrors = [error.localizedDescription]
            showDeletionError = true
        }
    }

    // MARK: - Tool: Memory Monitor

    func refreshMemoryStats() {
        memoryStats = MemoryMonitor.current()
    }

    func releaseMemory() {
        memoryReleaseUIState = .working
        MemoryMonitor.releaseInactiveMemory()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            refreshMemoryStats()
            memoryReleaseUIState = .success
            try? await Task.sleep(for: .seconds(2))
            if memoryReleaseUIState == .success {
                memoryReleaseUIState = .idle
            }
        }
    }

    // MARK: - Tool: Disk Health

    func loadDiskHealth() async {
        isDiskHealthLoading = true
        defer { isDiskHealthLoading = false }
        diskHealthInfo = await diskHealthService.load()
    }

    // MARK: - Tool: Scan History

    func loadScanHistory() async {
        scanHistory = await scanHistoryService.loadAll()
    }

    private func recordScanSession() async {
        let cleanableBytes = storageItems.values.flatMap { $0 }.reduce(0) { $0 + $1.size }
            + customItems.values.flatMap { $0 }.reduce(0) { $0 + $1.size }
        let record = ScanRecord(
            date: Date(),
            bytesFreed: totalBytesFreed,
            totalCleanableBytes: cleanableBytes,
            usedFraction: usedPercentage
        )
        await scanHistoryService.record(record)
        scanHistory = await scanHistoryService.loadAll()
    }

    // MARK: - Tool: Safe Mode

    func stageForDeletion(_ items: [StorageItem]) {
        for item in items where !stagedForDeletion.contains(where: { $0.path == item.path }) {
            stagedForDeletion.append(item)
        }
    }

    func removeFromStaged(_ item: StorageItem) {
        stagedForDeletion.removeAll { $0.path == item.path }
    }

    func commitStagedDeletions(mode: DeletionMode) async {
        let items = stagedForDeletion
        let (deleted, failed) = await performDeletion(items, mode: mode)
        let deletedSet = Set(deleted)
        stagedForDeletion.removeAll { deletedSet.contains($0.path) }
        // Remove from relevant categories too
        for cat in storageItems.keys {
            storageItems[cat]?.removeAll { deletedSet.contains($0.path) }
        }
        updateTotalSize()
        if !failed.isEmpty { deletionErrors = failed; showDeletionError = true }
    }

    func clearStagedDeletions() {
        stagedForDeletion.removeAll()
    }

    // MARK: - Tool: iCloud Cleaner

    func scanICloudItems() async {
        isICloudScanRunning = true
        defer { isICloudScanRunning = false }

        let searchPaths = [
            "\(rootPath)/Downloads",
            "\(rootPath)/Desktop",
            "\(rootPath)/Documents",
        ]

        var results: [StorageItem] = []

        await withTaskGroup(of: [StorageItem].self) { group in
            for dir in searchPaths {
                group.addTask {
                    await Self.findICloudItems(in: dir)
                }
            }
            for await items in group {
                results.append(contentsOf: items)
            }
        }

        iCloudItems = results.sorted { $0.size > $1.size }
    }

    private static func findICloudItems(in dir: String) async -> [StorageItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: dir),
            includingPropertiesForKeys: [
                .isUbiquitousItemKey,
                .ubiquitousItemIsUploadedKey,
                .fileSizeKey,
                .contentModificationDateKey
            ],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [StorageItem] = []
        for url in contents {
            guard let rv = try? url.resourceValues(forKeys: [
                .isUbiquitousItemKey, .ubiquitousItemIsUploadedKey,
                .fileSizeKey, .contentModificationDateKey
            ]) else { continue }

            guard rv.isUbiquitousItem == true,
                  rv.ubiquitousItemIsUploaded == true else { continue }

            let size = Int64(rv.fileSize ?? 0)
            guard size > 1024 * 1024 else { continue } // skip tiny files

            let modDate = rv.contentModificationDate ?? Date()
            items.append(StorageItem(name: url.lastPathComponent, path: url.path, size: size, modifiedDate: modDate))
        }
        return items
    }

    func evictFromLocal(_ item: StorageItem) async {
        do {
            try fileManager.evictUbiquitousItem(at: URL(fileURLWithPath: item.path))
            iCloudItems.removeAll { $0.path == item.path }
        } catch {
            deletionErrors = [error.localizedDescription]
            showDeletionError = true
        }
    }

    // MARK: - Time Machine Snapshots

    func deleteTimeMachineItems(_ items: [StorageItem]) async {
        var failed: [String] = []
        for item in items {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
            // item.path is the snapshot name like com.apple.TimeMachine.2024-01-01-120000.local
            let parts = item.path.components(separatedBy: ".")
            if let datePart = parts.first(where: { $0.contains("-") }) {
                process.arguments = ["deletelocalsnapshots", datePart]
                process.standardOutput = Pipe()
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus != 0 { failed.append(item.name) }
                } catch {
                    failed.append(item.name)
                }
            } else {
                failed.append(item.name)
            }
        }
        // Refresh TM items
        let newItems = await scanner.scanCategory(.timeMachineSnapshots, rootPath: rootPath)
        storageItems[.timeMachineSnapshots] = newItems
        if !failed.isEmpty { deletionErrors = failed; showDeletionError = true }
    }

    // MARK: - Scheduled Auto-Scan

    func scheduleAutoScanIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "autoScanEnabled") else { return }
        let storedInterval = UserDefaults.standard.double(forKey: "autoScanInterval")
        let interval = storedInterval > 0 ? storedInterval : 86400
        let activity = NSBackgroundActivityScheduler(identifier: "com.macharmony.autoscan")
        activity.repeats = true
        activity.interval = interval
        activity.tolerance = interval * 0.1
        activity.schedule { [weak self] completion in
            Task { @MainActor [weak self] in
                await self?.scan()
                self?.sendStorageNotificationIfNeeded()
            }
            completion(.finished)
        }
        #if DEBUG
        print("⏰ Auto-scan scheduled every \(Int(interval/3600))h")
        #endif
    }

    private func sendStorageNotificationIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        let storedThreshold = UserDefaults.standard.double(forKey: "notificationThreshold")
        let threshold = storedThreshold > 0 ? storedThreshold : 0.85
        guard usedPercentage > threshold else { return }
        let content = UNMutableNotificationContent()
        content.title = "Storage Getting Full"
        content.body = "Your Mac is \(Int(usedPercentage * 100))% full. MacHarmony found \(totalCleanableSize) to clean."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "storage-warning", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Derived Data Auto-Clean

    func scheduleDerivedDataAutocleanIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "derivedDataAutocleanEnabled") else { return }
        let storedInterval = UserDefaults.standard.double(forKey: "derivedDataAutocleanInterval")
        let interval = storedInterval > 0 ? storedInterval : 604800

        let activity = NSBackgroundActivityScheduler(identifier: "com.macharmony.derivedDataAutoclean")
        activity.repeats = true
        activity.interval = interval
        activity.tolerance = interval * 0.1
        activity.qualityOfService = .background
        activity.schedule { [weak self] completion in
            Task { @MainActor [weak self] in
                guard let self else { completion(.finished); return }
                #if DEBUG
                print("🧹 Auto-clean: scanning Derived Data…")
                #endif
                await self.scanner.configure(
                    ignoredNames: self.ignoredPatterns,
                    excludedPaths: self.excludedScanPaths,
                    globalMinBytes: Int64(UserDefaults.standard.double(forKey: "minScanFileSizeBytes"))
                )
                let fileIndex = await self.scanner.buildIndex(rootPath: self.rootPath) { _, _ in }
                let items = await self.scanner.scanCategory(.xcodeDerivedData, rootPath: self.rootPath, index: fileIndex)
                if !items.isEmpty {
                    #if DEBUG
                    print("🧹 Auto-clean: deleting \(items.count) Derived Data items…")
                    #endif
                    self.storageItems[.xcodeDerivedData] = items
                    await self.deleteItems(items, from: .xcodeDerivedData, mode: .permanent)
                    let bytesDeleted = items.reduce(0) { $0 + $1.size }
                    self.sendDerivedDataAutocleanNotification(bytesDeleted: bytesDeleted)
                }
            }
            completion(.finished)
        }
        #if DEBUG
        print("⏰ Derived Data auto-clean scheduled every \(Int(interval / 86400))d")
        #endif
    }

    private func sendDerivedDataAutocleanNotification(bytesDeleted: Int64) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        let content = UNMutableNotificationContent()
        content.title = "Derived Data Cleaned"
        content.body = "MacHarmony automatically deleted \(ByteCountFormatter.string(fromByteCount: bytesDeleted, countStyle: .file)) of Derived Data."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "derived-data-autoclean-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
