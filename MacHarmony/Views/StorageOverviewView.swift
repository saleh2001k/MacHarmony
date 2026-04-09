//
//  StorageOverviewView.swift
//  MacHarmony
//

import SwiftUI

struct StorageOverviewView: View {
    @ObservedObject var storageManager: StorageManager
    @State private var animatedPercentage: CGFloat = 0

    private var healthColor: Color {
        Theme.healthColor(for: storageManager.usedPercentage)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac Storage")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(storageManager.diskUsageSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(storageManager.totalCleanableSize)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.accentGreen)
                    Text("cleanable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.borderMedium)
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [healthColor.opacity(0.7), healthColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * animatedPercentage, height: 12)
                        .shadow(color: healthColor.opacity(0.45), radius: 4, x: 0, y: 2)
                }
            }
            .frame(height: 12)

            HStack {
                Circle()
                    .fill(healthColor)
                    .frame(width: 8, height: 8)
                Text("\(Int(storageManager.usedPercentage * 100))% used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let date = storageManager.lastScanDate {
                    Text("Scanned \(date, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .themeHeader()
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1)) {
                animatedPercentage = storageManager.usedPercentage
            }
        }
        .onChange(of: storageManager.usedPercentage) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animatedPercentage = newValue
            }
        }
    }
}
