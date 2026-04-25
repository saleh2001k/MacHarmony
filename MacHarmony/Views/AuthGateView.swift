//
//  AuthGateView.swift
//  MacHarmony
//
//  Auth screens: sign-in gate, native login form (magic link + password),
//  trial sign-up, trial paywall, and offline grace banner.
//

import SwiftUI

// MARK: - Colors

private let green  = Color(red: 0.176, green: 0.792, blue: 0.451)
private let bg     = Color(nsColor: NSColor(red: 0.039, green: 0.039, blue: 0.047, alpha: 1))
private let surf   = Color(nsColor: NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1))
private let border = Color.white.opacity(0.09)
private let muted  = Color.white.opacity(0.45)
private let subtle = Color.white.opacity(0.25)

// MARK: - AuthGatedView (router)

struct AuthGatedView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var storageManager: StorageManager

    var body: some View {
        switch authManager.state {

        case .authenticated:
            ContentView()

        case .offlineGrace(let days):
            ContentView()
                .overlay(alignment: .top) { OfflineGraceBanner(daysRemaining: days) }

        case .trial(let daysLeft):
            ContentView()
                .overlay(alignment: .top) { TrialBanner(daysLeft: daysLeft) }

        case .trialExpired:
            TrialPaywallView()

        case .unknown, .validating:
            LoadingView()

        case .authSuccess:
            AuthSuccessView()

        case .unauthenticated, .authenticating, .waitingForBrowser, .expired, .deviceConflict:
            AuthGateView()
        }
    }
}

// MARK: - LoadingView

private struct LoadingView: View {
    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 10) {
                ProgressView().scaleEffect(1.2).tint(green)
                Text("Checking license…")
                    .font(.system(size: 13))
                    .foregroundStyle(muted)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

// MARK: - AuthGateView

struct AuthGateView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var appeared = false

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            // Glow
            RadialGradient(
                colors: [green.opacity(0.10), .clear],
                center: .center, startRadius: 10, endRadius: 220
            )
            .frame(width: 440, height: 440)
            .blur(radius: 30).offset(y: -40)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 1.2), value: appeared)

            mainGateContent
        }
        .frame(minWidth: 500, minHeight: 420)
        .onAppear { appeared = true }
    }

    @ViewBuilder
    private var mainGateContent: some View {
        VStack(spacing: 0) {
            // App icon
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable().frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: green.opacity(0.25), radius: 20, y: 8)
                    .scaleEffect(appeared ? 1 : 0.7).opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appeared)
            }

            Spacer().frame(height: 22)

            // Headline
            VStack(spacing: 6) {
                Text("MacHarmony")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                mainMessage
                    .font(.system(size: 14))
                    .foregroundStyle(muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .offset(y: appeared ? 0 : 12).opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5).delay(0.12), value: appeared)

            Spacer().frame(height: 28)

            // Primary action
            primaryButton
                .offset(y: appeared ? 0 : 10).opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.22), value: appeared)

            // Secondary
            secondaryContent
                .offset(y: appeared ? 0 : 6).opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.34), value: appeared)
        }
        .padding(48)
    }

    @ViewBuilder
    private var mainMessage: some View {
        switch authManager.state {
        case .unauthenticated:
            Text("Sign in to access MacHarmony.")
        case .authenticating, .waitingForBrowser:
            Text("Complete sign-in in your browser.\nThis window will activate automatically.")
        case .expired:
            Text("You've been offline for over 7 days.\nSign in to continue.")
        case .deviceConflict:
            Text("This license is active on another Mac.\nTransfer it to use it here.")
        default:
            Text("Verifying your license…")
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch authManager.state {
        case .unauthenticated, .expired:
            AuthButton(title: "Sign In to MacHarmony →") {
                authManager.openBrowserForLogin()
            }

        case .authenticating, .waitingForBrowser:
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7).tint(green)
                    Text("Waiting for browser sign-in…")
                        .font(.system(size: 13)).foregroundStyle(muted)
                }
                Button("Cancel") {
                    authManager.stopPolling()
                    authManager.state = .unauthenticated
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(subtle)
            }

        case .deviceConflict:
            VStack(spacing: 10) {
                AuthButton(title: "Transfer License to This Mac →") {
                    NSWorkspace.shared.open(MacHarmonySite.transferURL)
                }
                Button("Use a different account") {
                    authManager.signOut()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(subtle)
            }

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var secondaryContent: some View {
        if authManager.state == .unauthenticated || authManager.state == .expired {
            VStack(spacing: 5) {
                Spacer().frame(height: 8)
                Button {
                    NSWorkspace.shared.open(MacHarmonySite.purchaseURL)
                } label: {
                    Text("Buy MacHarmony — $29.99")
                        .font(.system(size: 11)).foregroundStyle(subtle).underline()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Auth Success View

private struct AuthSuccessView: View {
    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(green)
                Text("You're signed in!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("MacHarmony is now active.")
                    .font(.system(size: 14))
                    .foregroundStyle(muted)
            }
        }
        .frame(minWidth: 500, minHeight: 420)
    }
}

// MARK: - Trial Banner

struct TrialBanner: View {
    let daysLeft: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.8))
            Text(daysLeft == 0
                 ? "Your free trial expires today."
                 : "Free trial: \(daysLeft) day\(daysLeft == 1 ? "" : "s") remaining.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Button("Buy MacHarmony") {
                NSWorkspace.shared.open(MacHarmonySite.purchaseURL)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(
            Color(red: 0.95, green: 0.65, blue: 0.15).opacity(0.9)
        )
    }
}

// MARK: - Trial Paywall

private struct TrialPaywallView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var appeared = false

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            RadialGradient(
                colors: [green.opacity(0.07), .clear],
                center: .center, startRadius: 10, endRadius: 180
            )
            .frame(width: 380, height: 380).blur(radius: 30)

            VStack(spacing: 0) {
                // Icon
                ZStack {
                    Circle()
                        .fill(green.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(green)
                }
                .scaleEffect(appeared ? 1 : 0.6).opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appeared)

                Spacer().frame(height: 20)

                Text("Your free trial has ended")
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                    .animation(.spring(response: 0.5).delay(0.1), value: appeared)

                Text("Purchase a license to continue using MacHarmony.")
                    .font(.system(size: 14)).foregroundStyle(muted)
                    .multilineTextAlignment(.center).frame(maxWidth: 280)
                    .padding(.top, 8)
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                    .animation(.spring(response: 0.5).delay(0.18), value: appeared)

                Spacer().frame(height: 28)

                // Buy button
                AuthButton(title: "Buy MacHarmony") {
                    NSWorkspace.shared.open(MacHarmonySite.purchaseURL)
                }
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                .animation(.spring(response: 0.5).delay(0.26), value: appeared)

                // Value props
                VStack(spacing: 8) {
                    ForEach([
                        ("checkmark.circle.fill", "One-time purchase — yours forever"),
                        ("lock.shield.fill",       "100% private — no telemetry"),
                        ("arrow.triangle.2.circlepath", "Free updates included"),
                    ], id: \.0) { icon, text in
                        HStack(spacing: 8) {
                            Image(systemName: icon)
                                .font(.system(size: 12))
                                .foregroundStyle(green)
                            Text(text)
                                .font(.system(size: 12))
                                .foregroundStyle(muted)
                        }
                    }
                }
                .padding(.top, 18)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.35), value: appeared)

                Spacer().frame(height: 16)

                Button("Sign in with a different account") {
                    authManager.signOut()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(subtle)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.42), value: appeared)
            }
            .padding(48)
        }
        .frame(minWidth: 500, minHeight: 440)
        .onAppear { appeared = true }
    }
}

// MARK: - Offline Grace Banner

struct OfflineGraceBanner: View {
    let daysRemaining: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash").font(.system(size: 10))
            Text("License server unreachable — \(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left before sign-in required.")
                .font(.system(size: 11))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(
            Color(red: 1, green: 0.75, blue: 0.1).opacity(0.9),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .padding(.top, 8)
    }
}

// MARK: - Shared components

struct AuthButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(nsColor: NSColor(red: 0.039, green: 0.039, blue: 0.047, alpha: 1)))
                .frame(maxWidth: 280)
                .padding(.vertical, 13)
                .background(
                    green.opacity(disabled ? 0.5 : 1),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .shadow(color: green.opacity(disabled ? 0 : 0.3), radius: 12, y: 4)
        .padding(.bottom, 12)
    }
}

