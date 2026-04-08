//
//  OnboardingView.swift
//  Detox
//

import SwiftUI
import AppKit

// MARK: - Onboarding View

struct OnboardingView: View {
    var onComplete: (_ requestNotifications: Bool) -> Void

    @State private var step = 0
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                StepIndicator(currentStep: step, totalSteps: 3)
                    .padding(.top, 32)
                    .padding(.bottom, 20)

                Group {
                    switch step {
                    case 0: WelcomeStep(appeared: $appeared)
                    case 1: PermissionsStep(appeared: $appeared)
                    case 2: NotificationsStep(appeared: $appeared, onComplete: onComplete)
                    default: EmptyView()
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.88), value: step)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if step < 2 {
                    OnboardingNavButton(label: step == 0 ? "Get Started" : "Continue") {
                        advanceStep()
                    }
                    .padding(.bottom, 32)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(minWidth: 520, minHeight: 480)
        .onAppear { appeared = true }
    }

    private func advanceStep() {
        appeared = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            step += 1
            appeared = true
        }
    }
}

// MARK: - Step Indicator

private struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == currentStep ? Theme.accentGreen : Theme.borderMedium)
                    .frame(width: i == currentStep ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.35), value: currentStep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeStep: View {
    @Binding var appeared: Bool

    private let features: [(String, Color, String, String)] = [
        ("internaldrive.fill", Theme.accentGreen, "Smart Scan", "Finds Xcode caches, node_modules, and more"),
        ("trash.fill",         Theme.accentAmber, "Safe Deletion", "Move to Trash or delete permanently"),
        ("bell.fill",          .blue,             "Auto Clean",    "Scheduled scans keep your Mac tidy")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Hero
                ZStack {
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .fill(RadialGradient(
                                colors: [Theme.accentGreen.opacity(0.12 - Double(i) * 0.05), .clear],
                                center: .center, startRadius: 20,
                                endRadius: 70 + CGFloat(i) * 20
                            ))
                            .frame(width: 130 + CGFloat(i) * 40, height: 130 + CGFloat(i) * 40)
                            .scaleEffect(appeared ? 1.0 : 0.6)
                            .opacity(appeared ? 1.0 : 0)
                            .animation(.spring(response: 0.8).delay(Double(i) * 0.15), value: appeared)
                    }
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(LinearGradient(
                            colors: [Theme.accentGreen, Theme.accentGreen.opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .scaleEffect(appeared ? 1.0 : 0.5)
                        .opacity(appeared ? 1.0 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appeared)
                }
                .frame(height: 140)
                .accessibilityHidden(true)

                // Text
                VStack(spacing: 8) {
                    Text("Welcome to Detox")
                        .font(.largeTitle).fontWeight(.bold)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.5).delay(0.15), value: appeared)

                    Text("The smart storage cleaner for your Mac.\nSafely remove caches, build artifacts, and junk files.")
                        .font(.subheadline).multilineTextAlignment(.center)
                        .foregroundStyle(.secondary).frame(maxWidth: 380)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                        .animation(.spring(response: 0.5).delay(0.22), value: appeared)
                }

                // Feature bullets
                VStack(spacing: 10) {
                    ForEach(Array(features.enumerated()), id: \.offset) { i, feature in
                        HStack(spacing: 14) {
                            Image(systemName: feature.0)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(feature.1)
                                .themeIconBadge(color: feature.1, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.2).font(.subheadline.weight(.semibold))
                                Text(feature.3).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.borderSubtle, lineWidth: 1))
                        .opacity(appeared ? 1 : 0).offset(x: appeared ? 0 : -16)
                        .animation(.spring(response: 0.45).delay(0.30 + Double(i) * 0.08), value: appeared)
                    }
                }
                .frame(maxWidth: 420)
            }
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Step 1: Permissions

private struct PermissionsStep: View {
    @Binding var appeared: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Theme.accentGreen)
                    .themeIconBadge(color: Theme.accentGreen, size: 88)
                    .scaleEffect(appeared ? 1 : 0.6).opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.7), value: appeared)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Full Disk Access")
                        .font(.largeTitle).fontWeight(.bold)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                        .animation(.spring(response: 0.5).delay(0.12), value: appeared)

                    Text("Detox needs Full Disk Access to scan your entire Mac, including the Trash and Library folders. Without it, many categories can't be scanned.")
                        .font(.subheadline).multilineTextAlignment(.center)
                        .foregroundStyle(.secondary).frame(maxWidth: 400)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                        .animation(.spring(response: 0.5).delay(0.18), value: appeared)
                }

                // Steps card
                VStack(alignment: .leading, spacing: 10) {
                    PermissionStepRow(number: "1", text: "Open System Settings")
                    PermissionStepRow(number: "2", text: "Go to Privacy & Security → Full Disk Access")
                    PermissionStepRow(number: "3", text: "Find Detox in the list and enable it")
                }
                .padding(16)
                .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.borderSubtle, lineWidth: 1))
                .frame(maxWidth: 400)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                .animation(.spring(response: 0.5).delay(0.26), value: appeared)

                Button {
                    FileAccessService().openFullDiskAccessSettings()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open System Settings")
                    }
                    .frame(maxWidth: 260)
                }
                .buttonStyle(ThemePrimaryButton())
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.34), value: appeared)
                .accessibilityLabel("Open Full Disk Access settings")
                .accessibilityHint("Opens Privacy & Security in System Settings")

                Text("You can also grant access when prompted for your home folder.")
                    .font(.caption).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.40), value: appeared)
            }
            .padding(.bottom, 8)
        }
    }
}

private struct PermissionStepRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Theme.accentGreen, in: Circle())
            Text(text).font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - Step 2: Notifications

private struct NotificationsStep: View {
    @Binding var appeared: Bool
    var onComplete: (_ requestNotifications: Bool) -> Void

    private let bullets: [(String, Color, String)] = [
        ("checkmark.circle.fill",         Theme.accentGreen, "Scan completion alerts"),
        ("exclamationmark.triangle.fill",  Theme.accentAmber, "Storage warning notifications")
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.blue)
                .themeIconBadge(color: .blue, size: 88)
                .scaleEffect(appeared ? 1 : 0.6).opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.7), value: appeared)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Stay Informed")
                    .font(.largeTitle).fontWeight(.bold)
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                    .animation(.spring(response: 0.5).delay(0.12), value: appeared)

                Text("Detox can notify you when a scan finishes or when significant storage is found. You can always change this in Settings.")
                    .font(.subheadline).multilineTextAlignment(.center)
                    .foregroundStyle(.secondary).frame(maxWidth: 380)
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                    .animation(.spring(response: 0.5).delay(0.18), value: appeared)
            }

            // Bullets
            VStack(spacing: 10) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                    HStack(spacing: 12) {
                        Image(systemName: bullet.0)
                            .font(.system(size: 14))
                            .foregroundStyle(bullet.1)
                        Text(bullet.2).font(.subheadline)
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: 320)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut.delay(0.26), value: appeared)

            // Buttons
            VStack(spacing: 12) {
                Button {
                    onComplete(true)
                } label: {
                    Text("Allow Notifications")
                        .frame(maxWidth: 260)
                }
                .buttonStyle(ThemePrimaryButton())
                .accessibilityLabel("Allow notifications")
                .accessibilityHint("Requests permission to send scan and storage notifications")

                Button {
                    onComplete(false)
                } label: {
                    Text("Skip for Now")
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Skip notifications")
                .accessibilityHint("Continues without enabling notifications")
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut.delay(0.34), value: appeared)

            Spacer()
        }
    }
}

// MARK: - Nav Button

private struct OnboardingNavButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label).frame(maxWidth: 260)
        }
        .buttonStyle(ThemePrimaryButton())
        .accessibilityLabel(label)
    }
}
