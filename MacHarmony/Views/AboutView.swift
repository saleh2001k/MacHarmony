//
//  AboutView.swift
//  MacHarmony
//

import SwiftUI
import AppKit

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: AboutSection = .about
    @State private var appeared = false

    enum AboutSection: String, CaseIterable {
        case about       = "About"
        case reportBug   = "Report a Bug"
        case suggest     = "Suggest a Feature"
        case contact     = "Contact Us"
        case privacy     = "Privacy Policy"

        var icon: String {
            switch self {
            case .about:     return "info.circle.fill"
            case .reportBug: return "ant.fill"
            case .suggest:   return "lightbulb.fill"
            case .contact:   return "envelope.fill"
            case .privacy:   return "lock.shield.fill"
            }
        }

        var color: Color {
            switch self {
            case .about:     return Theme.accentGreen
            case .reportBug: return .red
            case .suggest:   return .orange
            case .contact:   return .blue
            case .privacy:   return .purple
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // ── Sidebar ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                // App identity
                VStack(spacing: 10) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.accentGreen, Theme.accentGreen.opacity(0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 2) {
                        Text("MacHarmony")
                            .font(.title3).fontWeight(.bold)
                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)

                Divider().opacity(0.5)

                // Nav items
                VStack(spacing: 2) {
                    ForEach(AboutSection.allCases, id: \.self) { section in
                        AboutNavRow(
                            section: section,
                            isSelected: selectedSection == section
                        ) {
                            withAnimation(.spring(response: 0.25)) {
                                selectedSection = section
                            }
                        }
                    }
                }
                .padding(.top, 8)

                Spacer()

                // Copyright
                Text("© 2026 MacHarmony")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
            }
            .frame(width: 180)
            .background(Theme.backgroundSidebar)

            Divider()

            // ── Content ───────────────────────────────────────────────
            Group {
                switch selectedSection {
                case .about:     AboutSection_About()
                case .reportBug: AboutSection_ReportBug()
                case .suggest:   AboutSection_Suggest()
                case .contact:   AboutSection_Contact(selectedSection: $selectedSection)
                case .privacy:   AboutSection_Privacy()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 620, height: 440)
        .background(Theme.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Sidebar Nav Row

private struct AboutNavRow: View {
    let section: AboutView.AboutSection
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .white : section.color)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSelected ? section.color : section.color.opacity(0.12))
                    )

                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Theme.backgroundElevated : (isHovered ? Theme.backgroundCard : .clear))
                    .padding(.horizontal, 6)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - About Section

private struct AboutSection_About: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AboutSectionHeader(
                    icon: "info.circle.fill",
                    color: Theme.accentGreen,
                    title: "About MacHarmony",
                    subtitle: "A smart, privacy-first storage cleaner for macOS"
                )

                VStack(alignment: .leading, spacing: 12) {
                    AboutFeatureRow(icon: "lock.shield.fill", color: .green,
                                   title: "100% Private",
                                   detail: "No network access, no telemetry, no analytics. Everything stays on your Mac.")
                    AboutFeatureRow(icon: "bolt.fill", color: .yellow,
                                   title: "Fast Scanning",
                                   detail: "File-index powered scanning finds gigabytes of cleanable data in seconds.")
                    AboutFeatureRow(icon: "trash.fill", color: .red,
                                   title: "Safe Deletion",
                                   detail: "Only targets well-known safe-to-delete directories. Never touches system files.")
                    AboutFeatureRow(icon: "slider.horizontal.3", color: .blue,
                                   title: "Fully Customizable",
                                   detail: "Add your own scan targets, configure the menu bar, and set auto-clean schedules.")
                }

                Divider().opacity(0.5)

                HStack(spacing: 20) {
                    AboutInfoChip(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    AboutInfoChip(label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    AboutInfoChip(label: "Platform", value: "macOS 14+")
                }
            }
            .padding(28)
        }
    }
}

// MARK: - Report Bug Section

private struct AboutSection_ReportBug: View {
    @State private var title = ""
    @State private var steps = ""
    @State private var expected = ""
    @State private var actual = ""
    @State private var submitting = false
    @State private var submitted = false
    @State private var errorMsg = ""

    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AboutSectionHeader(
                    icon: "ant.fill",
                    color: .red,
                    title: "Report a Bug",
                    subtitle: "Help us improve by describing what went wrong"
                )

                if submitted {
                    AboutSubmittedState(
                        icon: "checkmark.circle.fill",
                        color: .green,
                        message: "Thanks for the report! We'll look into it."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        AboutFormField(label: "Bug Title *", placeholder: "Short description of the issue", text: $title)
                        AboutFormArea(label: "Steps to Reproduce", placeholder: "1. Open the app\n2. Press Scan\n3. ...", text: $steps)
                        AboutFormArea(label: "Expected Behavior", placeholder: "What should have happened?", text: $expected)
                        AboutFormArea(label: "Actual Behavior", placeholder: "What actually happened?", text: $actual)
                    }

                    if !errorMsg.isEmpty {
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Spacer()
                        Button(submitting ? "Submitting…" : "Submit Report") {
                            Task { await submit() }
                        }
                        .buttonStyle(ThemePrimaryButton(color: .red))
                        .disabled(!isValid || submitting)
                    }
                }
            }
            .padding(28)
        }
    }

    private func submit() async {
        submitting = true
        errorMsg = ""
        let message = """
            Bug: \(title)

            Steps to Reproduce:
            \(steps.isEmpty ? "Not provided" : steps)

            Expected:
            \(expected.isEmpty ? "Not provided" : expected)

            Actual:
            \(actual.isEmpty ? "Not provided" : actual)
            """
        let err = await submitFeedback(
            type: "bug",
            subject: "[Bug] \(title)",
            message: message
        )
        submitting = false
        if let err { errorMsg = err } else { submitted = true }
    }
}

// MARK: - Suggest Feature Section

private struct AboutSection_Suggest: View {
    @State private var feature = ""
    @State private var reason = ""
    @State private var submitting = false
    @State private var submitted = false
    @State private var errorMsg = ""

    private var isValid: Bool { !feature.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AboutSectionHeader(
                    icon: "lightbulb.fill",
                    color: .orange,
                    title: "Suggest a Feature",
                    subtitle: "We'd love to hear your ideas for making MacHarmony better"
                )

                if submitted {
                    AboutSubmittedState(
                        icon: "star.fill",
                        color: .orange,
                        message: "Great idea! We'll consider it for a future update."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        AboutFormField(label: "Feature *", placeholder: "What would you like to see?", text: $feature)
                        AboutFormArea(label: "Why would this be useful?", placeholder: "Describe the problem it solves or the workflow it improves...", text: $reason)
                    }

                    if !errorMsg.isEmpty {
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Spacer()
                        Button(submitting ? "Submitting…" : "Submit Suggestion") {
                            Task { await submit() }
                        }
                        .buttonStyle(ThemePrimaryButton(color: .orange))
                        .disabled(!isValid || submitting)
                    }
                }
            }
            .padding(28)
        }
    }

    private func submit() async {
        submitting = true
        errorMsg = ""
        let message = "Feature Request: \(feature)\n\nWhy it would be useful:\n\(reason.isEmpty ? "Not provided" : reason)"
        let err = await submitFeedback(
            type: "feature",
            subject: "[Feature] \(feature)",
            message: message
        )
        submitting = false
        if let err { errorMsg = err } else { submitted = true }
    }
}

// MARK: - Contact Section

private struct AboutSection_Contact: View {
    @Binding var selectedSection: AboutView.AboutSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AboutSectionHeader(
                    icon: "envelope.fill",
                    color: .blue,
                    title: "Contact Us",
                    subtitle: "Get in touch — we usually respond within 1–2 business days"
                )

                VStack(spacing: 10) {
                    AboutContactRow(
                        icon: "envelope.fill", color: .blue,
                        title: "General Support",
                        detail: "Opens the support form"
                    ) {
                        withAnimation(.spring(response: 0.25)) { selectedSection = .contact }
                    }

                    AboutContactRow(
                        icon: "ant.fill", color: .red,
                        title: "Report a Bug",
                        detail: "Opens the bug report form"
                    ) {
                        withAnimation(.spring(response: 0.25)) { selectedSection = .reportBug }
                    }

                    AboutContactRow(
                        icon: "lightbulb.fill", color: .orange,
                        title: "Feature Requests",
                        detail: "Opens the suggestion form"
                    ) {
                        withAnimation(.spring(response: 0.25)) { selectedSection = .suggest }
                    }
                }

                Divider().opacity(0.5)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Response Time")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    Text("We aim to respond to all messages within 1–2 business days. For urgent issues, include URGENT in the subject line.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(28)
        }
    }
}

// MARK: - Privacy Policy Section

private struct AboutSection_Privacy: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AboutSectionHeader(
                    icon: "lock.shield.fill",
                    color: .purple,
                    title: "Privacy Policy",
                    subtitle: "How MacHarmony handles your data"
                )

                VStack(alignment: .leading, spacing: 12) {
                    AboutFeatureRow(icon: "wifi.slash", color: .purple,
                                   title: "No Network Access",
                                   detail: "MacHarmony never connects to the internet. All operations run entirely on your Mac.")
                    AboutFeatureRow(icon: "eye.slash.fill", color: .indigo,
                                   title: "No Telemetry or Analytics",
                                   detail: "We collect zero usage data, crash reports, or analytics. Your activity is never tracked.")
                    AboutFeatureRow(icon: "externaldrive.fill", color: .blue,
                                   title: "Files Stay on Your Mac",
                                   detail: "Scanned files and storage data never leave your device. Nothing is uploaded anywhere.")
                }

                Divider().opacity(0.5)

                HStack {
                    Spacer()
                    Button("View Full Privacy Policy") {
                        NSWorkspace.shared.open(URL(string: "https://macharmony.com/privacy")!)
                    }
                    .buttonStyle(ThemePrimaryButton(color: .purple))
                    Spacer()
                }
            }
            .padding(28)
        }
    }
}

// MARK: - Shared Components

private struct AboutSectionHeader: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3).fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AboutFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AboutInfoChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.borderSubtle, lineWidth: 1))
    }
}

private struct AboutFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct AboutFormArea: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 70, maxHeight: 90)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.borderSubtle, lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

private struct AboutContactRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color.opacity(0.1)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? Theme.backgroundElevated : Theme.backgroundCard)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(isHovered ? color.opacity(0.25) : Theme.borderSubtle, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

private struct AboutSubmittedState: View {
    let icon: String
    let color: Color
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(color)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Feedback submission helper

private func submitFeedback(type: String, subject: String, message: String) async -> String? {
    let url = URL(string: "https://pjrmiyopkqzammvjcevo.supabase.co/functions/v1/submit-feedback")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    let macOS = ProcessInfo.processInfo.operatingSystemVersionString

    let payload: [String: Any] = [
        "type": type,
        "subject": subject,
        "message": message,
        "source": "app",
        "metadata": ["app_version": version, "macos": macOS],
    ]

    guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
        print("[Feedback] ❌ Failed to encode payload")
        return "Failed to encode request"
    }
    req.httpBody = body

    print("[Feedback] → POST \(url.absoluteString) type=\(type)")

    do {
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let responseBody = String(data: data, encoding: .utf8) ?? "<empty>"
        print("[Feedback] ← \(status) \(responseBody.prefix(200))")

        if status != 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? String { return err }
            return "Server error (\(status))"
        }
        return nil
    } catch {
        print("[Feedback] ❌ Network error: \(error)")
        return "Network error. Please check your connection."
    }
}
