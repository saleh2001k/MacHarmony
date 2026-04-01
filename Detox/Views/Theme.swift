//
//  ViewsTheme.swift
//  Detox
//

import SwiftUI

// MARK: - Theme Tokens

enum Theme {

    // ── Background Hierarchy ────────────────────────────────────────────
    // Named Color assets defined in Assets.xcassets — adapt to dark/light mode.

    /// Deepest app background
    static let backgroundPrimary   = Color("ThemeBackgroundPrimary")
    /// Sidebar / header surfaces
    static let backgroundSidebar   = Color("ThemeBackgroundSidebar")
    /// Card / panel surfaces
    static let backgroundCard      = Color("ThemeBackgroundCard")
    /// Hovered / selected elevated surface
    static let backgroundElevated  = Color("ThemeBackgroundElevated")

    // ── Accent Colors ───────────────────────────────────────────────────
    // Static — same in dark and light modes.

    /// CMM-style primary green
    static let accentGreen     = Color(red: 0.176, green: 0.792, blue: 0.451)
    /// Green glow for shadows
    static let accentGreenGlow = Color(red: 0.176, green: 0.792, blue: 0.451, opacity: 0.35)
    /// Amber warning
    static let accentAmber     = Color(red: 0.961, green: 0.651, blue: 0.137)
    /// Red destructive
    static let accentRed       = Color(red: 1.0,   green: 0.231, blue: 0.188)

    // ── Borders ──────────────────────────────────────────────────────────

    /// Subtle 1pt card border (white 7% in dark mode)
    static let borderSubtle = Color.white.opacity(0.07)
    /// Medium border for focus / progress tracks
    static let borderMedium = Color.white.opacity(0.12)

    // ── Semantic Helpers ─────────────────────────────────────────────────

    /// Health color based on disk usage fraction
    static func healthColor(for fraction: Double) -> Color {
        switch fraction {
        case ..<0.6:  return accentGreen
        case ..<0.8:  return accentAmber
        default:      return accentRed
        }
    }

    /// Color for file size severity
    static func sizeColor(for bytes: Int64) -> Color {
        switch bytes {
        case ..<(100 * 1024 * 1024):   return .primary
        case ..<(1024 * 1024 * 1024):  return accentAmber
        default:                        return accentRed
        }
    }
}

// MARK: - Card Style

struct ThemeCardStyle: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.backgroundCard,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.borderSubtle, lineWidth: 1)
            )
    }
}

// MARK: - Gradient Card Style

struct ThemeGradientCardStyle: ViewModifier {
    var accent: Color
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.backgroundCard)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LinearGradient(
                        colors: [accent.opacity(0.06), accent.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [accent.opacity(0.25), Theme.borderSubtle],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: accent.opacity(0.10), radius: 12, x: 0, y: 4)
            .shadow(color: accent.opacity(0.06), radius: 24, x: 0, y: 8)
    }
}

// MARK: - Header Bar Style

struct ThemeHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.backgroundSidebar)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.borderSubtle)
                    .frame(height: 1)
            }
    }
}

// MARK: - Icon Badge Style

struct ThemeIconBadge: ViewModifier {
    let color: Color
    let size: CGFloat
    var selected: Bool = false

    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                    .fill(color.opacity(selected ? 0.22 : 0.18))
            )
    }
}

// MARK: - Button Styles

/// Green-tinted primary action button
struct ThemePrimaryButton: ButtonStyle {
    var color: Color = Theme.accentGreen

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color)
                    .shadow(color: color.opacity(0.4),
                            radius: configuration.isPressed ? 3 : 7,
                            y: configuration.isPressed ? 1 : 3)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

/// Red-tinted destructive action button
struct ThemeDestructiveButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.accentRed)
                    .shadow(color: Theme.accentRed.opacity(0.4),
                            radius: configuration.isPressed ? 3 : 7,
                            y: configuration.isPressed ? 1 : 3)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply card styling: backgroundCard fill + borderSubtle stroke
    func themeCard(padding: CGFloat = 16, cornerRadius: CGFloat = 14) -> some View {
        modifier(ThemeCardStyle(padding: padding, cornerRadius: cornerRadius))
    }

    /// Apply header bar styling: backgroundSidebar fill + bottom separator
    func themeHeader() -> some View {
        modifier(ThemeHeaderStyle())
    }

    /// Wrap in a rounded-square icon badge
    func themeIconBadge(color: Color, size: CGFloat = 30, selected: Bool = false) -> some View {
        modifier(ThemeIconBadge(color: color, size: size, selected: selected))
    }

    /// Apply gradient-tinted card: accent-colored gradient overlay, gradient border, layered shadows
    func themeGradientCard(accent: Color, padding: CGFloat = 16, cornerRadius: CGFloat = 14) -> some View {
        modifier(ThemeGradientCardStyle(accent: accent, padding: padding, cornerRadius: cornerRadius))
    }

    /// Convenience glow drop shadow with accent color at 18% opacity
    func glowShadow(color: Color, radius: CGFloat = 12, y: CGFloat = 4) -> some View {
        self.shadow(color: color.opacity(0.18), radius: radius, x: 0, y: y)
    }
}
