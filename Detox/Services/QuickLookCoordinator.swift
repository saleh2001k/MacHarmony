//
//  ServicesQuickLookCoordinator.swift
//  Detox
//

import AppKit
import Quartz

final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {

    var previewURL: URL?

    func show(path: String) {
        previewURL = URL(fileURLWithPath: path)
        let panel = QLPreviewPanel.shared()!
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL != nil ? 1 : 0
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURL as QLPreviewItem?
    }
}
