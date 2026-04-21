//
//  OnboardingView.swift
//  MacHarmony
//

import SwiftUI
import AppKit

// MARK: - Onboarding View

struct OnboardingView: View {
    var onComplete: (_ requestNotifications: Bool) -> Void

    @State private var step = 0
    @State private var appeared = false
    @State private var selectedProfileID: String? = nil

    /// Continue is blocked on step 2 until the user picks a profile.
    private var canAdvance: Bool {
        step != 2 || selectedProfileID != nil
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                StepIndicator(currentStep: step, totalSteps: 4)
                    .padding(.top, 32)
                    .padding(.bottom, 20)

                Group {
                    switch step {
                    case 0: WelcomeStep(appeared: $appeared)
                    case 1: PermissionsStep(appeared: $appeared)
                    case 2: ScopeStep(appeared: $appeared, selectedProfileID: $selectedProfileID)
                    case 3: NotificationsStep(appeared: $appeared, onComplete: onComplete)
                    default: EmptyView()
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.88), value: step)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if step < 3 {
                    VStack(spacing: 6) {
                        OnboardingNavButton(label: step == 0 ? "Get Started" : "Continue") {
                            advanceStep()
                        }
                        .disabled(!canAdvance)
                        .opacity(canAdvance ? 1 : 0.4)

                        if step == 2 && selectedProfileID == nil {
                            Text("Choose a profile to continue")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: canAdvance)
                    .padding(.bottom, 32)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(minWidth: 640, minHeight: 540)
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
                    Text("Welcome to MacHarmony")
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

                    Text("MacHarmony needs Full Disk Access to scan your entire Mac, including the Trash and Library folders. Without it, many categories can't be scanned.")
                        .font(.subheadline).multilineTextAlignment(.center)
                        .foregroundStyle(.secondary).frame(maxWidth: 400)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                        .animation(.spring(response: 0.5).delay(0.18), value: appeared)
                }

                // Steps card
                VStack(alignment: .leading, spacing: 10) {
                    PermissionStepRow(number: "1", text: "Open System Settings")
                    PermissionStepRow(number: "2", text: "Go to Privacy & Security → Full Disk Access")
                    PermissionStepRow(number: "3", text: "Find MacHarmony in the list and enable it")
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

// MARK: - Step 2: Scope (Profile & Category Selection)

private struct ScopeStep: View {
    @Binding var appeared: Bool
    @Binding var selectedProfileID: String?

    @State private var enabledRawValues: Set<String> = []
    @State private var showMoreCategories = false

    // MARK: Profile definitions

    struct WorkProfile: Identifiable {
        let id: String
        let name: String
        let icon: String
        let color: Color
        let tagline: String
        let categories: [StorageCategory]   // empty = all
    }

    private let profiles: [WorkProfile] = [
        // ── Apple Platform ──────────────────────────────────────────────
        WorkProfile(
            id: "ios",
            name: "iOS / macOS",
            icon: "hammer.fill",
            color: .blue,
            tagline: "Swift, Xcode, CocoaPods",
            categories: [.xcodeDerivedData, .xcodeArchives, .xcodeDeviceSupport,
                         .simulatorData, .podCache, .brewCache, .swiftPackages,
                         .systemCaches, .applicationCaches, .logFiles, .downloads, .trash]
        ),
        WorkProfile(
            id: "flutter",
            name: "Flutter Dev",
            icon: "diamond.fill",
            color: Color(red: 0.02, green: 0.61, blue: 0.84),
            tagline: "Dart, Flutter SDK, pub cache",
            categories: [.xcodeDerivedData, .xcodeDeviceSupport, .simulatorData,
                         .podCache, .gradleCache, .androidEmulators,
                         .dartPubCache, .swiftPackages,
                         .applicationCaches, .systemCaches, .logFiles, .downloads, .trash]
        ),
        WorkProfile(
            id: "reactnative",
            name: "React Native",
            icon: "iphone.and.arrow.forward",
            color: .cyan,
            tagline: "npm, Metro, Xcode, Gradle",
            categories: [.nodeModules, .xcodeDerivedData, .xcodeDeviceSupport,
                         .simulatorData, .podCache, .gradleCache, .androidEmulators,
                         .systemCaches, .applicationCaches, .logFiles, .downloads, .trash]
        ),
        // ── Web & Backend ────────────────────────────────────────────────
        WorkProfile(
            id: "web",
            name: "Web Developer",
            icon: "globe",
            color: .orange,
            tagline: "Node.js, npm, browsers",
            categories: [.nodeModules, .browserCache, .downloads,
                         .applicationCaches, .systemCaches, .logFiles, .trash]
        ),
        WorkProfile(
            id: "python",
            name: "Python Dev",
            icon: "chevron.left.forwardslash.chevron.right",
            color: Color(red: 0.22, green: 0.49, blue: 0.72),
            tagline: "pip, virtualenv, Jupyter, conda",
            categories: [.pipCache, .condaEnvs,
                         .applicationCaches, .systemCaches, .logFiles,
                         .downloads, .largeFiles, .browserCache, .trash]
        ),
        WorkProfile(
            id: "java",
            name: "Java / Kotlin",
            icon: "cup.and.saucer.fill",
            color: Color(red: 0.85, green: 0.33, blue: 0.10),
            tagline: "Maven, Gradle, IntelliJ IDEA",
            categories: [.gradleCache, .mavenCache, .jetBrainsCache,
                         .applicationCaches, .systemCaches,
                         .logFiles, .downloads, .largeFiles, .trash]
        ),
        // ── Mobile ───────────────────────────────────────────────────────
        WorkProfile(
            id: "android",
            name: "Android Dev",
            icon: "rectangle.portrait.fill",
            color: Color(red: 0.20, green: 0.72, blue: 0.32),
            tagline: "Gradle, Android Studio, AVD",
            categories: [.gradleCache, .androidEmulators, .apkFiles, .nodeModules,
                         .jetBrainsCache,
                         .systemCaches, .applicationCaches, .logFiles, .downloads, .trash]
        ),
        // ── Systems & Cloud ──────────────────────────────────────────────
        WorkProfile(
            id: "devops",
            name: "DevOps / Cloud",
            icon: "cloud.fill",
            color: Color(red: 0.30, green: 0.55, blue: 0.90),
            tagline: "Docker, Terraform, CI/CD, Brew",
            categories: [.brewCache, .dockerData,
                         .applicationCaches, .systemCaches,
                         .logFiles, .downloads, .largeFiles, .trash]
        ),
        WorkProfile(
            id: "sysadmin",
            name: "System Admin",
            icon: "terminal.fill",
            color: Color(red: 0.20, green: 0.78, blue: 0.35),
            tagline: "Logs, SSH, monitoring tools",
            categories: [.logFiles, .systemCaches, .applicationCaches,
                         .brewCache, .rubyGemsCache, .downloads, .largeFiles, .trash]
        ),
        // ── Games ─────────────────────────────────────────────────────────
        WorkProfile(
            id: "gamedev",
            name: "Game Developer",
            icon: "gamecontroller.fill",
            color: Color(red: 0.55, green: 0.20, blue: 0.90),
            tagline: "Unity, Unreal, assets",
            categories: [.largeFiles, .unityCache,
                         .applicationCaches, .systemCaches,
                         .downloads, .videos, .images, .trash]
        ),
        // ── Data & AI ────────────────────────────────────────────────────
        WorkProfile(
            id: "data",
            name: "Data / ML / AI",
            icon: "chart.bar.xaxis",
            color: .purple,
            tagline: "Datasets, models, notebooks",
            categories: [.largeFiles, .downloads, .videos, .images,
                         .pipCache, .condaEnvs, .huggingFaceCache,
                         .systemCaches, .applicationCaches, .logFiles, .trash]
        ),
        // ── Creative ─────────────────────────────────────────────────────
        WorkProfile(
            id: "designer",
            name: "UI / UX Designer",
            icon: "paintpalette.fill",
            color: .pink,
            tagline: "Figma, Sketch, exports, assets",
            categories: [.images, .videos, .largeFiles, .downloads,
                         .applicationCaches, .systemCaches, .browserCache, .trash]
        ),
        WorkProfile(
            id: "videoeditor",
            name: "Video Editor",
            icon: "film.stack.fill",
            color: Color(red: 0.60, green: 0.10, blue: 0.80),
            tagline: "Final Cut, DaVinci, Premiere",
            categories: [.videos, .largeFiles, .downloads,
                         .applicationCaches, .systemCaches, .trash]
        ),
        WorkProfile(
            id: "photographer",
            name: "Photographer",
            icon: "camera.fill",
            color: Color(red: 0.10, green: 0.65, blue: 0.55),
            tagline: "Lightroom, Capture One, RAW files",
            categories: [.images, .largeFiles, .downloads,
                         .applicationCaches, .systemCaches, .iCloudPlaceholders, .trash]
        ),
        WorkProfile(
            id: "musician",
            name: "Musician / Audio",
            icon: "waveform",
            color: Color(red: 0.90, green: 0.30, blue: 0.50),
            tagline: "Logic Pro, GarageBand, samples",
            categories: [.largeFiles, .applicationCaches, .systemCaches,
                         .downloads, .iCloudPlaceholders, .trash]
        ),
        WorkProfile(
            id: "creator",
            name: "Content Creator",
            icon: "sparkles.tv.fill",
            color: Color(red: 0.95, green: 0.45, blue: 0.10),
            tagline: "YouTube, podcasts, streaming",
            categories: [.videos, .images, .largeFiles, .downloads,
                         .applicationCaches, .systemCaches, .browserCache, .trash]
        ),
        // ── Education & Office ────────────────────────────────────────────
        WorkProfile(
            id: "student",
            name: "Student",
            icon: "graduationcap.fill",
            color: .indigo,
            tagline: "School files, browsers, apps",
            categories: [.downloads, .browserCache, .applicationCaches,
                         .systemCaches, .logFiles, .trash]
        ),
        WorkProfile(
            id: "writer",
            name: "Writer / Blogger",
            icon: "doc.text.fill",
            color: Color(red: 0.30, green: 0.60, blue: 0.45),
            tagline: "Docs, research, browser tabs",
            categories: [.downloads, .browserCache, .applicationCaches,
                         .systemCaches, .mailAttachments, .trash]
        ),
        WorkProfile(
            id: "business",
            name: "Business / Office",
            icon: "briefcase.fill",
            color: Color(red: 0.20, green: 0.45, blue: 0.70),
            tagline: "Email, Office, meetings, cloud",
            categories: [.downloads, .mailAttachments, .browserCache,
                         .applicationCaches, .systemCaches, .iCloudPlaceholders, .trash]
        ),
        // ── Catch-all ─────────────────────────────────────────────────────
        WorkProfile(
            id: "general",
            name: "General User",
            icon: "person.fill",
            color: .gray,
            tagline: "Everyday Mac use",
            categories: [.downloads, .images, .videos, .largeFiles,
                         .trash, .systemCaches, .applicationCaches, .browserCache]
        ),
        WorkProfile(
            id: "everything",
            name: "Scan Everything",
            icon: "square.grid.3x3.fill",
            color: Theme.accentGreen,
            tagline: "All categories included",
            categories: []   // empty = all
        ),
    ]

    // MARK: Profile groups

    private struct ProfileGroup {
        let title: String
        let ids: [String]
    }

    private let profileGroups: [ProfileGroup] = [
        ProfileGroup(title: "DEVELOPERS", ids: [
            "ios", "flutter", "reactnative",
            "web", "python", "java",
            "android", "devops", "sysadmin", "gamedev"
        ]),
        ProfileGroup(title: "CREATIVE & MEDIA", ids: [
            "designer", "videoeditor", "photographer",
            "musician", "creator"
        ]),
        ProfileGroup(title: "WORK & EVERYDAY", ids: [
            "data", "student", "writer",
            "business", "general", "everything"
        ]),
    ]

    // MARK: Helpers

    private var includedCategories: [StorageCategory] {
        StorageCategory.allCases.filter { enabledRawValues.contains($0.rawValue) }
    }

    private var excludedCategories: [StorageCategory] {
        StorageCategory.allCases.filter { !enabledRawValues.contains($0.rawValue) }
    }

    private var isEverythingMode: Bool { selectedProfileID == "everything" }

    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Title
                VStack(alignment: .leading, spacing: 6) {
                    Text("What do you use your Mac for?")
                        .font(.title2).fontWeight(.bold)
                    Text("We'll scan only the categories that matter to your workflow. You can change this any time in Settings.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                .animation(.spring(response: 0.5).delay(0.08), value: appeared)

                // Grouped profile grids
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(profileGroups.enumerated()), id: \.offset) { groupIdx, group in
                        let groupProfiles = profiles.filter { group.ids.contains($0.id) }
                            .sorted { group.ids.firstIndex(of: $0.id) ?? 0 < group.ids.firstIndex(of: $1.id) ?? 0 }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.0)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: gridColumns, spacing: 8) {
                                ForEach(groupProfiles) { profile in
                                    ProfileCard(
                                        profile: profile,
                                        isSelected: selectedProfileID == profile.id
                                    ) {
                                        selectProfile(profile)
                                    }
                                }
                            }
                        }
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                        .animation(.spring(response: 0.5).delay(0.12 + Double(groupIdx) * 0.06), value: appeared)
                    }
                }

                // Category customization (shown after profile is picked)
                if selectedProfileID != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(isEverythingMode ? "ALL CATEGORIES INCLUDED" : "INCLUDED CATEGORIES")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.0)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !isEverythingMode {
                                Text("\(enabledRawValues.count) of \(StorageCategory.allCases.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        if isEverythingMode {
                            // Show all as enabled
                            ForEach(StorageCategory.allCases) { cat in
                                ScopeCategoryRow(category: cat, isEnabled: true) {
                                    // Tapping on "everything" mode deselects → switch to custom
                                    selectedProfileID = "custom"
                                    enabledRawValues = Set(StorageCategory.allCases.map(\.rawValue))
                                    toggle(cat)
                                }
                            }
                        } else {
                            // Enabled categories
                            ForEach(includedCategories) { cat in
                                ScopeCategoryRow(category: cat, isEnabled: true) {
                                    toggle(cat)
                                }
                            }

                            if !excludedCategories.isEmpty {
                                Button {
                                    withAnimation(.spring(response: 0.35)) {
                                        showMoreCategories.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: showMoreCategories ? "minus.circle" : "plus.circle")
                                            .font(.system(size: 13))
                                        Text(showMoreCategories
                                             ? "Hide other categories"
                                             : "Add more categories (\(excludedCategories.count))")
                                            .font(.subheadline)
                                    }
                                    .foregroundStyle(Theme.accentGreen)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 2)

                                if showMoreCategories {
                                    ForEach(excludedCategories) { cat in
                                        ScopeCategoryRow(category: cat, isEnabled: false) {
                                            toggle(cat)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.borderSubtle, lineWidth: 1))
                    .transition(.opacity.combined(with: .offset(y: 8)))
                    .animation(.spring(response: 0.42), value: selectedProfileID)
                }

                if selectedProfileID == nil {
                    Text("Select a profile that best matches your workflow.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut.delay(0.3), value: appeared)
                }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: Actions

    private func selectProfile(_ profile: WorkProfile) {
        withAnimation(.spring(response: 0.35)) {
            selectedProfileID = profile.id
            showMoreCategories = false
            if profile.categories.isEmpty {
                // "Everything" — write empty set (= all enabled)
                enabledRawValues = Set(StorageCategory.allCases.map(\.rawValue))
                UserDefaults.standard.set([], forKey: "enabledScanCategories")
            } else {
                enabledRawValues = Set(profile.categories.map(\.rawValue))
                UserDefaults.standard.set(Array(enabledRawValues), forKey: "enabledScanCategories")
            }
        }
    }

    private func toggle(_ category: StorageCategory) {
        withAnimation(.spring(response: 0.25)) {
            if enabledRawValues.contains(category.rawValue) {
                enabledRawValues.remove(category.rawValue)
            } else {
                enabledRawValues.insert(category.rawValue)
            }
            // Collapse to "all" if every category is enabled
            let allRaw = Set(StorageCategory.allCases.map(\.rawValue))
            if enabledRawValues == allRaw {
                UserDefaults.standard.set([], forKey: "enabledScanCategories")
            } else {
                UserDefaults.standard.set(Array(enabledRawValues), forKey: "enabledScanCategories")
            }
        }
    }
}

// MARK: - Profile Card

private struct ProfileCard: View {
    let profile: ScopeStep.WorkProfile
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: profile.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(profile.color)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(profile.color.opacity(0.12))
                        )
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(profile.color)
                        .opacity(isSelected ? 1 : 0)
                }

                Spacer(minLength: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(profile.tagline)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected
                          ? profile.color.opacity(0.10)
                          : (isHovered ? Theme.backgroundElevated : Theme.backgroundCard))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isSelected ? profile.color.opacity(0.5) : Theme.borderSubtle,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .accessibilityLabel(profile.name)
        .accessibilityHint(profile.tagline)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Scope Category Row

private struct ScopeCategoryRow: View {
    let category: StorageCategory
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isEnabled ? category.color : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(category.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isEnabled ? .primary : .secondary)
                    Text(category.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(isEnabled ? AnyShapeStyle(category.color) : AnyShapeStyle(.tertiary))
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 4)
            .background(isHovered ? Theme.backgroundElevated : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Step 3: Notifications

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

                Text("MacHarmony can notify you when a scan finishes or when significant storage is found. You can always change this in Settings.")
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
