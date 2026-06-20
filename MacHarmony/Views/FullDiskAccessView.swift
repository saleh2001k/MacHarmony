//
//  FullDiskAccessView.swift
//  MacHarmony

import SwiftUI
import AppKit

struct FullDiskAccessView: View {
    @Environment(\.dismiss) private var dismiss

    var onGranted: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.green)
                    .padding(.top, 32)

                VStack(spacing: 8) {
                    Text("Full Disk Access Needed")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("MacHarmony needs Full Disk Access to scan your Library folders, app caches, and other system directories. Without it, many cleaning features won't work.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(steps, id: \.number) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(step.number)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 22, height: 22)
                                .background(Color.green)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                if let detail = step.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 400)
            }
            .padding(.horizontal, 32)

            Divider()
                .padding(.top, 28)

            HStack(spacing: 12) {
                Button("Not Now") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Open System Settings") {
                    openPrivacySettings()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(20)
        }
        .frame(width: 480)
    }

    private var steps: [Step] {
        [
            Step(number: 1, title: "Open System Settings", detail: nil),
            Step(number: 2, title: "Go to Privacy & Security → Full Disk Access", detail: nil),
            Step(number: 3, title: "Find MacHarmony and toggle it on", detail: "You may need to unlock with Touch ID or your password"),
            Step(number: 4, title: "Relaunch MacHarmony", detail: nil),
        ]
    }

    private func openPrivacySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        )
        dismiss()
    }
}

struct Step: Identifiable {
    let number: Int
    let title: String
    let detail: String?
    var id: Int { number }
}

// MARK: - FDA check

/// Returns true if the app has Full Disk Access.
/// Uses a path that's readable only with FDA as a proxy.
func hasFullDiskAccess() -> Bool {
    FileManager.default.isReadableFile(atPath: "/Library/Preferences/com.apple.TimeMachine.plist")
}
