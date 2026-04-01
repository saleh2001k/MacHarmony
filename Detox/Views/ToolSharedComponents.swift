//
//  ViewsToolSharedComponents.swift
//  Detox
//

import SwiftUI

// MARK: - Indeterminate Spinner (pure SwiftUI — avoids AppKitProgressView constraint spam)

/// Circular indeterminate progress without `ProgressView`, which bridges to `NSProgressIndicator`
/// and triggers bogus Auto Layout warnings on macOS (min == max constraint “unsatisfied”).
struct IndeterminateSpinner: View {
    var size: CGFloat = 16
    var color: Color = .secondary

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let angle = (t.truncatingRemainder(dividingBy: 1.0)) / 1.0 * 360
            Circle()
                .trim(from: 0.08, to: 0.92)
                .stroke(color, style: StrokeStyle(lineWidth: max(1.5, size * 0.11), lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(angle))
        }
    }
}

// MARK: - Linear progress (determinate, pure SwiftUI)

struct LinearProgressFill: View {
    let value: Double
    var tint: Color = .accentColor
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.22))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Tool Loading View

struct ToolLoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            IndeterminateSpinner(size: 22, color: .secondary)
            Text(message)
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tool Empty View

struct ToolEmptyView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(color.opacity(0.7))
            Text(title)
                .font(.title3).fontWeight(.semibold)
            Text(subtitle)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tool Header

struct ToolHeaderView<Trailing: View>: View {
    let tool: ToolType
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: tool.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tool.color)
                .themeIconBadge(color: tool.color, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(tool.title).font(.title3).fontWeight(.semibold)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .themeHeader()
    }
}
