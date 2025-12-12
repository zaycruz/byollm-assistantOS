//
//  DesignSystem.swift
//  byollm-assistantOS
//
//  Created by master on 12/10/25.
//

import SwiftUI

// MARK: - Design System Root
struct DesignSystem {
    // MARK: - Colors
    struct Colors {
        // MARK: - Japanese-inspired (Light + Dark), semantic tokens
        // NOTE: All colors are dynamic and automatically adapt to Light/Dark.
        // Views should reference semantic tokens rather than raw hex values.
        
        // Base (washi / sumi)
        static let bg = dynamicHex(light: "F9F6EF", dark: "0B0C0B")
        static let bgSecondary = dynamicHex(light: "F3EEE3", dark: "101310")
        
        // Surfaces (3 levels)
        static let surface1 = dynamicHex(light: "FFFFFB", dark: "141714")
        static let surface2 = dynamicHex(light: "F5F0E6", dark: "181C18")
        static let surface3 = dynamicHex(light: "EDE6D8", dark: "1D221D")
        
        // Chrome (bars/headers/tab bar)
        static let chrome = dynamicHex(light: "F5F0E6", dark: "141714")
        
        // Lines
        static let separator = dynamicHex(light: "DED6C6", dark: "2A302A")
        static let border = dynamicHex(light: "D2C9B7", dark: "333A33")
        
        // Text
        static let textPrimary = dynamicHex(light: "1A1A17", dark: "F2EFE7")
        static let textSecondary = dynamicHex(light: "3E3B34", dark: "CFC8BC")
        static let textTertiary = dynamicHex(light: "6E6A61", dark: "A79F92")
        // Text color for content on top of accent fills (dynamic for contrast).
        static let onAccent = dynamicHex(light: "FFFFFF", dark: "0B0C0B")
        
        // Status
        static let error = Color(hex: "FF453A")
        static let success = Color(hex: "32D74B")
        static let warning = Color(hex: "FFD60A")
        
        // Accent (single brand accent; sage green)
        static let accent = dynamicHex(light: "5A8F73", dark: "7CCAA0")
        static let accentSoft = accent.opacity(0.11)
        static let accentStroke = accent.opacity(0.30)
        
        static func backgroundGradient() -> some ShapeStyle {
            // Paper-like depth (very subtle).
            LinearGradient(
                colors: [
                    bg,
                    bgSecondary
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        
        // Compatibility aliases (remove once migrated)
        static let background = bg
        static let background2 = bgSecondary
        static let surface = surface1
        static let surfaceElevated = surface2
        static let surfaceHighlight = surface3
        static let surfacePressed = dynamicHex(light: "E9DFCF", dark: "273233")
    }
    
    // MARK: - Typography
    struct Typography {
        // Standard iOS system typography (no user-selectable font styles).
        static func display() -> Font { .system(size: 34, weight: .light, design: .default) }
        static func title() -> Font { .system(size: 22, weight: .semibold, design: .default) }
        static func header() -> Font { .system(size: 18, weight: .semibold, design: .default) }
        static func body() -> Font { .system(size: 16, weight: .regular, design: .default) }
        static func caption() -> Font { .system(size: 13, weight: .regular, design: .default) }
        static func code() -> Font { .system(size: 13, weight: .regular, design: .default) }
    }
    
    // MARK: - Layout
    struct Layout {
        // Slightly more “ma” (space) and softer radii.
        static let spacing: CGFloat = 10
        static let cornerRadius: CGFloat = 14
        static let cornerRadiusSmall: CGFloat = 10
        static let cornerRadiusTiny: CGFloat = 8
        static let borderWidth: CGFloat = 0.5
    }
}

// MARK: - View Modifiers

struct GlassPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.Layout.cornerRadius
    
    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Colors.surfaceElevated.opacity(0.96))
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.border.opacity(0.55), lineWidth: DesignSystem.Layout.borderWidth)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 6)
    }
}

struct MattePanelModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.Layout.cornerRadius
    
    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Colors.surfaceElevated.opacity(0.97))
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.separator.opacity(0.9), lineWidth: DesignSystem.Layout.borderWidth)
            )
    }
}

// MARK: - Extensions

extension View {
    func glassPanel(radius: CGFloat = DesignSystem.Layout.cornerRadius) -> some View {
        modifier(GlassPanelModifier(cornerRadius: radius))
    }
    
    func mattePanel(radius: CGFloat = DesignSystem.Layout.cornerRadius) -> some View {
        modifier(MattePanelModifier(cornerRadius: radius))
    }
    
    func natureTechBackground() -> some View {
        background(
            NatureTechBackground()
                .ignoresSafeArea()
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Dynamic color helpers

extension DesignSystem.Colors {
    fileprivate static func dynamicHex(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return UIColor(hex: isDark ? dark : light) ?? .magenta
        })
    }
}

extension UIColor {
    fileprivate convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }
}

// MARK: - Custom Buttons (legacy)
// NOTE: Kept for compatibility with older call sites; uses brand accent.

struct ConsoleButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.body())
            .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textPrimary)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                ZStack {
                    if isSelected || configuration.isPressed {
                        DesignSystem.Colors.accent.opacity(0.10)
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(
                        isSelected || configuration.isPressed ? DesignSystem.Colors.accent.opacity(0.45) : DesignSystem.Colors.border,
                        lineWidth: 1
                    )
            )
            .clipShape(.rect(cornerRadius: 4, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Background

struct NatureTechBackground: View {
    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.backgroundGradient())
            .overlay(
                // Subtle “paper” lift.
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.03),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .overlay(
                // Gentle vignette (keeps focus toward center).
                RadialGradient(
                    colors: [
                        Color.black.opacity(0.00),
                        Color.black.opacity(0.10)
                    ],
                    center: .center,
                    startRadius: 60,
                    endRadius: 520
                )
                .blendMode(.multiply)
                .opacity(0.35)
            )
    }
}

// MARK: - Buttons (reusable)

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.body())
            .foregroundStyle(DesignSystem.Colors.onAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                    .fill(DesignSystem.Colors.accent)
                    .opacity(configuration.isPressed ? 0.85 : 1.0)
            )
            .shadow(color: DesignSystem.Colors.accent.opacity(0.18), radius: 10, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.body())
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                    .fill(configuration.isPressed ? DesignSystem.Colors.surfacePressed : DesignSystem.Colors.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                    .stroke(DesignSystem.Colors.border.opacity(configuration.isPressed ? 0.9 : 0.6), lineWidth: DesignSystem.Layout.borderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Small UI atoms

struct DSSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(DesignSystem.Typography.caption())
            .foregroundStyle(DesignSystem.Colors.textTertiary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

struct DSChip: View {
    let text: String
    var isActive: Bool = false
    
    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption())
            .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous)
                    .fill(isActive ? DesignSystem.Colors.accent.opacity(0.18) : DesignSystem.Colors.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusTiny, style: .continuous)
                    .stroke(isActive ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.border.opacity(0.6), lineWidth: DesignSystem.Layout.borderWidth)
            )
    }
}
