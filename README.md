# MacHarmony

<p align="center">
  <img src="./assets/MacHarmony-App-Icon.png" alt="MacHarmony Hero" width="200" />
</p>

A fast, modern macOS app for scanning, analyzing, and cleaning storage — built for developers and power users.

---

## Features

- **Parallel scanning** — all categories scan concurrently using Swift structured concurrency; results stream in as each finishes
- **Shared file index** — one `fts_open` traversal builds an in-memory index upfront; all `deepFiles` and `deepLargeFiles` categories filter it in O(n) instead of re-traversing disk
- **Disk cache** — scan results are persisted to JSON with a configurable TTL (default 1h); reopening the app loads instantly
- **Incremental deletion** — items disappear from the list one-by-one as each file is deleted; file I/O runs on a background thread so the UI never freezes
- **Deletion progress HUD** — a floating pill at the bottom shows current file name, batch count, and a linear progress bar
- **Custom scanners** — define your own categories by extension + directory
- **Category ordering** — drag-and-drop reorder in Settings; persisted across launches
- **Ignored patterns** — folder names to skip in deep scans (e.g. `.git`, `build`, `dist`)
- **Excluded paths** — explicit directories to skip entirely during all scans
- **Menu bar access** — quick stats and scan trigger from the menu bar
- **Quick Look** — press Space on a selected item in category detail to preview it
- **Export** — save scan results as CSV, JSON, or plain text
- **Settings** — 6-tab settings window (General, Scan, Categories, Notifications, Export, Custom Scanners)
- **Tools (sidebar)** — twelve standalone utilities (see [Tools](#tools-sidebar) below); routed by `ToolRouterView` in `ContentView.swift`
- **Loading indicators** — indeterminate spinners use pure SwiftUI (`IndeterminateSpinner` in `ViewsToolSharedComponents.swift`), not AppKit `NSProgressIndicator`, to avoid layout console noise

---

## Tools (sidebar)

The sidebar lists **Tools** in `ToolType` / `ToolType.allCases` order. Each row opens a dedicated view via `ToolRouterView`.

| Tool                    | View file                         | What it does                                                                                                                        |
| ----------------------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Large File Browser**  | `ViewsLargeFileBrowserView.swift` | Files larger than a user-chosen size threshold; grouped by type                                                                     |
| **Old & Unused Files**  | `ViewsOldUnusedFilesView.swift`   | Files not modified in **6**, **12**, or **24** months (segmented control); uses file index after a full scan or merged cached paths |
| **Empty Folders**       | `ViewsEmptyFolderView.swift`      | Finds empty directories under the home folder                                                                                       |
| **App Uninstaller**     | `ViewsAppUninstallerView.swift`   | Lists apps; drives uninstall / support-file cleanup                                                                                 |
| **App Cache Breakdown** | `ViewsAppCacheView.swift`         | Per-app cache size breakdown                                                                                                        |
| **Leftover Files**      | `ViewsLeftoverFilesView.swift`    | Orphaned Library folders after app removal (pairs with uninstaller scan)                                                            |
| **Startup Items**       | `ViewsStartupItemsView.swift`     | Login items and launch agents                                                                                                       |
| **Memory Monitor**      | `ViewsMemoryMonitorView.swift`    | RAM usage and “free inactive memory”                                                                                                |
| **Disk Health**         | `ViewsDiskHealthView.swift`       | Volume / SMART-style disk info                                                                                                      |
| **Scan History**        | `ViewsScanHistoryView.swift`      | History of space freed over time                                                                                                    |
| **Safe Mode Queue**     | `ViewsSafeModeView.swift`         | Stage items before committing deletion                                                                                              |
| **iCloud Cleaner**      | `ViewsiCloudCleanerView.swift`    | iCloud-backed files reclaim hints                                                                                                   |

Supporting types: `ModelsToolType.swift` (enum + `LargeFileGroup`), `ModelsAppEntry.swift` (app entries for uninstaller/cache tools). Tool-specific services include `ServicesAppScanner`, `ServicesEmptyFolderScanner`, `ServicesLeftoverScanner`, `ServicesStartupItemScanner`, `ServicesDiskHealth`, `ServicesDiskUsage`, `ServicesMemoryMonitor`, `ServicesScanHistory`.

---

## Project Structure

Flat layout under `MacHarmony/` (Xcode may group files visually; names match the repo).

```
MacHarmony/
│
├── MacHarmonyApp.swift              # App entry, scenes, menu bar, Settings
├── ContentView.swift                   # NavigationSplitView, toolbar, ToolRouterView
│
├── Models/
│   ├── ModelsStorageCategory.swift     # StorageCategory + ScanStyle
│   ├── ModelsStorageItem.swift         # StorageItem (Codable)
│   ├── ModelsCustomCategory.swift      # CustomScanCategory
│   ├── ModelsToolType.swift            # ToolType enum + LargeFileGroup
│   └── ModelsAppEntry.swift            # App bundle entries (uninstaller / cache tools)
│
├── ViewModels/
│   └── ViewModelsStorageManager.swift  # StorageManager — state, scan, delete, tools, cache
│
├── Services/
│   ├── ServicesStorageScanner.swift    # Actor — category scans, deep scans, custom scans
│   ├── ServicesFastScanEngine.swift    # fts-based traversal (async streams)
│   ├── ServicesFileIndex.swift         # Shared in-memory index for one pass per scan
│   ├── ServicesSizeCalculator.swift    # du -sk sizing
│   ├── ServicesScanCache.swift          # On-disk size cache (paths + TTL)
│   ├── ServicesResultsCache.swift      # Full scan results JSON for relaunch
│   ├── ServicesThumbnailCache.swift    # Thumbnail NSCache
│   ├── ServicesCustomCategoryStore.swift
│   ├── ServicesReportExporter.swift
│   ├── ServicesFileAccessService.swift # Home folder security-scoped access
│   ├── ServicesQuickLookCoordinator.swift
│   ├── ServicesDiskUsage.swift         # Tool: volume usage
│   ├── ServicesDiskHealth.swift
│   ├── ServicesMemoryMonitor.swift
│   ├── ServicesScanHistory.swift
│   ├── ServicesAppScanner.swift
│   ├── ServicesEmptyFolderScanner.swift
│   ├── ServicesLeftoverScanner.swift
│   └── ServicesStartupItemScanner.swift
│
├── Views/  (main UI + tools)
│   ├── ViewsSidebarView.swift          # Storage categories, Tools, custom scanners
│   ├── ViewsCategoryDetailView.swift
│   ├── ViewsCustomCategoryDetailView.swift
│   ├── ViewsStorageOverviewView.swift
│   ├── ViewsDashboardView.swift
│   ├── ViewsScanningView.swift         # ScanProgressBanner, ScanningFullView, category chips
│   ├── ViewsSettingsView.swift
│   ├── ViewsMenuBarQuickAccessView.swift
│   ├── ViewsAddCustomCategoryView.swift
│   ├── ViewsHelpView.swift
│   ├── ViewsTheme.swift
│   ├── ViewsToolSharedComponents.swift # IndeterminateSpinner, LinearProgressFill, ToolLoadingView, …
│   │
│   ├── ViewsLargeFileBrowserView.swift
│   ├── ViewsOldUnusedFilesView.swift
│   ├── ViewsEmptyFolderView.swift
│   ├── ViewsAppUninstallerView.swift
│   ├── ViewsAppCacheView.swift
│   ├── ViewsLeftoverFilesView.swift
│   ├── ViewsStartupItemsView.swift
│   ├── ViewsMemoryMonitorView.swift
│   ├── ViewsDiskHealthView.swift
│   ├── ViewsScanHistoryView.swift
│   ├── ViewsSafeModeView.swift
│   └── ViewsiCloudCleanerView.swift
│
└── (Assets & entitlements in Xcode project)
```

---

## Architecture

### MVVM + Actor Services

```
View  ──────────────────────►  StorageManager (@MainActor ObservableObject)
                                      │
                   ┌──────────────────┤
                   │                  │
             StorageScanner     ResultsCache
               (actor)            (actor)
                   │
        ┌──────────┼──────────┐
        │          │          │
  FastScanEngine FileIndex SizeCalculator
  (async stream) (in-memory) (du subprocess)
        │
    ScanCache
  (JSON on disk)
```

- `**StorageManager**` is the single source of truth. All `@Published` state lives here; Views bind to it directly.
- `**StorageScanner**` is an actor. `StorageManager.scan()` calls it from the main actor; the actor runs all work off-thread.
- `**FileIndex**` is built once per scan (one parallel FTS traversal). Categories that use `deepFiles` or `deepLargeFiles` filter the index in memory instead of re-traversing disk — dramatically faster for repeated scans.
- `**ResultsCache**` persists the full `[String: [StorageItem]]` dictionary to a JSON file. On relaunch, if the cache is within the TTL, results load in milliseconds.

---

## Scanning Pipeline

```
StorageManager.scan()
  │
  ├─ scanner.configure(ignoredNames:excludedPaths:globalMinBytes:)
  │
  ├─ scanner.buildIndex(rootPath:)       ← one fts_open pass, builds FileIndex
  │
  └─ withTaskGroup { for each category }
        │
        └─ scanner.scanCategory(_:rootPath:index:)
              │
              ├─ .nodeModules    → scanNodeModules       ← FTS name-match + du -sk
              ├─ .topLevelDirs   → scanTopLevelDirs      ← shallow dirs + du -sk, size threshold
              ├─ .topLevelAll    → scanTopLevelAll        ← shallow files+dirs, size from fts stat
              ├─ .deepFiles      → index.filter(ext:)    ← O(n) in-memory (or scanFilesDeep)
              ├─ .deepLargeFiles → index.filter(min:)    ← O(n) in-memory (or scanFilesDeep)
              └─ .timeMachine    → tmutil listlocalsnapshots

  scanFilesDeep (fallback when index misses)
        ├─ expands root into parallel sub-dirs
        ├─ filters: ignoredNames, excludedPaths, extensions, minBytes
        └─ fts stat for file size (no subprocess)
```

---

## Deletion Flow

```
User selects → confirmation → deleteItems(_:from:mode:)
  │
  └─ performDeletion(_:mode:onItemDeleted:)
        │
        for each item:
          ├─ Task.detached { FileManager.trashItem / removeItem }  ← background thread
          ├─ await result                                           ← main actor suspended (UI responsive)
          ├─ onItemDeleted(item) → storageItems[category].remove   ← item vanishes from list live
          └─ publish: deletionCurrentName, deletionCompleted, deletionProgress
        │
        ├─ scanner.evictCache(for: deleted)
        └─ resultsCache.invalidate()
```

---

## Categories

### Apple Developer

| Category           | Paths                                           | Strategy         |
| ------------------ | ----------------------------------------------- | ---------------- |
| Xcode Derived Data | `~/Library/Developer/Xcode/DerivedData`         | Top-level dirs   |
| Xcode Archives     | `~/Library/Developer/Xcode/Archives`            | Top-level dirs   |
| Device Support     | `~/Library/Developer/Xcode/*DeviceSupport`      | Top-level dirs   |
| iOS Simulators     | `~/Library/Developer/CoreSimulator/Devices`     | Top-level dirs   |
| Node Modules       | `~/Developer`, `~/Documents`, `~/Desktop`, etc. | Deep name search |
| CocoaPods Cache    | `~/Library/Caches/CocoaPods`                    | Top-level dirs   |
| Homebrew Cache     | `~/Library/Caches/Homebrew`                     | Top-level dirs   |

### Android Developer

| Category          | Paths                                         | Strategy                          |
| ----------------- | --------------------------------------------- | --------------------------------- |
| Gradle Cache      | `~/.gradle/caches`, `~/.gradle/wrapper/dists` | Top-level dirs                    |
| Android Emulators | `~/.android/avd`                              | Top-level (files + dirs)          |
| APK / AAB Files   | `~/` (whole home)                             | Deep file scan (.apk, .aab, .aar) |

### System

| Category            | Paths                           | Strategy                |
| ------------------- | ------------------------------- | ----------------------- |
| System Caches       | `~/Library/Caches`              | Top-level dirs (> 1 MB) |
| Application Support | `~/Library/Application Support` | Top-level dirs (> 1 MB) |
| Log Files           | `~/Library/Logs`                | Top-level dirs          |

### User Files

| Category    | Paths                                     | Strategy                                     |
| ----------- | ----------------------------------------- | -------------------------------------------- |
| Downloads   | `~/Downloads`                             | Top-level (files + dirs)                     |
| Images      | `~/` (whole home)                         | Deep file scan (.jpg, .png, .heic, .webp, …) |
| Videos      | `~/` (whole home)                         | Deep file scan (.mp4, .mov, .mkv, .avi, …)   |
| Large Files | `~/Documents`, `~/Downloads`, `~/Desktop` | Deep file scan (> 100 MB)                    |

### Backups

| Category               | Paths                                             | Strategy       |
| ---------------------- | ------------------------------------------------- | -------------- |
| iOS Backups            | `~/Library/Application Support/MobileSync/Backup` | Top-level dirs |
| Time Machine Snapshots | `tmutil listlocalsnapshots`                       | Shell command  |

---

## Settings

Accessible via **⌘ ,** or the gear button in the toolbar.

| Tab                 | Contents                                                                                                        |
| ------------------- | --------------------------------------------------------------------------------------------------------------- |
| **General**         | Color scheme (dark/light), default action after scan, deletion safety mode, reset all preferences               |
| **Scan**            | Performance mode, global minimum file size, ignored folder names, excluded paths, cache TTL, auto-scan schedule |
| **Categories**      | Drag-and-drop reorder for sidebar and scan progress display                                                     |
| **Notifications**   | Enable/disable storage alerts, threshold picker (75 – 95%)                                                      |
| **Export**          | Format (CSV / JSON / Plain Text), include hidden categories, default export folder                              |
| **Custom Scanners** | Create and manage user-defined scanners by extension + directory                                                |

---

## Key Behaviours

- **Old & Unused Files tool** — shows files whose modification date is older than a segmented threshold (**6**, **12**, or **24** months). Uses the shared file index when available after a full scan, otherwise merges paths from cached category results.
- **No full re-scan after delete** — items are removed from the in-memory list instantly; disk usage is recomputed from current state
- **Background file I/O** — deletions run on a detached task; the main actor is suspended (not blocked) so the UI stays at 60 fps
- **Live deletion HUD** — a floating progress card shows current file, count, and a progress bar; the list updates row-by-row as each file is removed
- **Ignored patterns are scoped** — ignored folder names (e.g. `node_modules`) skip entries in `deepFiles`/`deepLargeFiles` scans; they do **not** affect the dedicated Node Modules category scanner which specifically targets those folders
- `**.d.ts` filtering\*\* — TypeScript declaration files are explicitly excluded from the Videos and other extension-matched scans
- **Thumbnail caching** — `NSCache` backs per-path thumbnail generation; cache is cleared when the app is in the background
- **Auto-scan** — uses `NSBackgroundActivityScheduler`; fires a notification if disk usage exceeds the configured threshold

---

## Permissions

The app runs sandboxed with `ENABLE_USER_SELECTED_FILES = readwrite`.

On first launch an `NSOpenPanel` prompts for home directory access. The returned security-scoped URL is retained for the session — this grants read-write access to all subdirectories under `~/`.

**Full Disk Access** (System Settings → Privacy & Security → Full Disk Access) is recommended for complete coverage including `~/Library`. Use the lock icon in the toolbar to open the relevant settings pane.

Failed deletions (permission errors, system-protected files) surface a named-item alert rather than silently swallowing the error.

---

## Requirements

- macOS 13.0 (Ventura)+
- Xcode 15.0+
- Swift 5.9+

---

## Adding a New Category

1. Add a case to `StorageCategory` in `ModelsStorageCategory.swift`
2. Implement `scanStyle`, `title`, `icon`, `color`, `description`, and `paths(from:)` for the new case
3. The existing scan strategies (`topLevelDirs`, `deepFiles`, `deepLargeFiles`, etc.) cover most cases — only add a new `ScanStyle` case if none fit
4. If a new traversal is needed, add a private method to `ServicesStorageScanner.swift` and a corresponding FTS function in `ServicesFastScanEngine.swift`

---

## Adding a New Tool

1. Add a case to `ToolType` in `ModelsToolType.swift` (`title`, `icon`, `color`, `description`)
2. Create `ViewsYourToolView.swift` and switch it in `ToolRouterView` inside `ContentView.swift`
3. Add any dedicated scanner logic under `Services/` and wire through `StorageManager` as needed
