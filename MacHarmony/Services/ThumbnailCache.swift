//
//  ServicesThumbnailCache.swift
//  MacHarmony
//

import AppKit
import CoreGraphics
import Foundation

// MARK: - Thumbnail Cache

/// Thread-safe, memory-pressure-aware thumbnail cache backed by NSCache.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 600
        c.totalCostLimit = 100 * 1024 * 1024  // 100 MB
        return c
    }()

    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif",
        "gif", "webp", "tiff", "tif", "bmp"
    ]

    static func isImageFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return imageExtensions.contains(ext)
    }

    func cached(for path: String) -> NSImage? {
        cache.object(forKey: path as NSString)
    }

    func store(_ image: NSImage, for path: String) {
        // cost in bytes ≈ pixels × 4 channels
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: path as NSString, cost: cost)
    }

    /// Loads a thumbnail using CGImageSource — reads only the tiles needed for the
    /// requested pixel size, so it's fast even for large RAW/HEIC files.
    static func load(path: String, pixelSize: CGFloat = 60) async -> NSImage? {
        await Task.detached(priority: .utility) {
            let url = URL(fileURLWithPath: path) as CFURL
            guard let src = CGImageSourceCreateWithURL(url, nil) else { return nil }

            let opts: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: pixelSize,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: false
            ]

            guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
            else { return nil }

            let pts = CGFloat(pixelSize) / 2.0  // @2x → logical points
            return NSImage(cgImage: cg, size: CGSize(width: pts, height: pts))
        }.value
    }
}

// MARK: - ItemThumbnailView

import SwiftUI

/// Shows a thumbnail for image files; falls back to the category icon for everything else.
/// Thumbnail is loaded asynchronously and cached; cancelled automatically when the row scrolls away.
struct ItemThumbnailView: View {
    let path: String
    let fallbackIcon: String
    let fallbackColor: Color

    @State private var thumbnail: NSImage? = nil

    private var isImage: Bool { ThumbnailCache.isImageFile(path) }

    var body: some View {
        Group {
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(fallbackColor.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: fallbackIcon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(fallbackColor)
                }
            }
        }
        // task(id:) cancels the previous task when path changes (row recycled)
        .task(id: path) {
            guard isImage else { return }

            // Instant cache hit — no async needed
            if let cached = ThumbnailCache.shared.cached(for: path) {
                thumbnail = cached
                return
            }

            guard let image = await ThumbnailCache.load(path: path) else { return }
            ThumbnailCache.shared.store(image, for: path)
            // Guard against cancellation before assigning
            guard !Task.isCancelled else { return }
            thumbnail = image
        }
        // Reset when row is reused for a different item
        .onChange(of: path) {
            thumbnail = ThumbnailCache.shared.cached(for: path)
        }
    }
}
