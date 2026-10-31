import SwiftUI

// MARK: - Design System (Linear / Stripe inspired — zero AI tropes)

enum DS {

    // MARK: - Colors
    enum Colors {
        // Accent — Immersive Vibrant Solids
        static let paceRun  = Color(red: 0.18, green: 0.45, blue: 0.96)  // Vibrant Royal Blue
        static let interval = Color(red: 1.00, green: 0.50, blue: 0.05)  // Vibrant Orange
        static let model400 = Color(red: 0.15, green: 0.82, blue: 0.38)  // Energetic Green
        static let miniHurdle = Color(red: 0.00, green: 0.72, blue: 0.78) // Technical Teal

        // Semantic
        static let success = Color(red: 0.30, green: 0.80, blue: 0.46)
        static let warning = Color(red: 0.96, green: 0.68, blue: 0.24)
        static let error   = Color(red: 0.94, green: 0.36, blue: 0.36)
        // Cool accent reserved for rest/countdown phases (audit B1 —
        // replaces scattered Color.cyan usages across training editors).
        static let rest    = Color(red: 0.20, green: 0.78, blue: 0.95)

        // Surfaces — Pure Black
        static let bg          = Color(red: 0.0, green: 0.0, blue: 0.0)       // #000000 - True Black
        static let card        = Color(red: 0.07, green: 0.07, blue: 0.08)    // #121214
        static let cardHover   = Color(red: 0.10, green: 0.10, blue: 0.11)    // #1A1A1C
        static let field       = Color(red: 0.11, green: 0.11, blue: 0.12)    // #1C1C1F
        static let fieldBorder = Color.white.opacity(0.10)
        static let border      = Color.white.opacity(0.12)
        static let borderLight = Color.white.opacity(0.07)
        static let divider     = Color.white.opacity(0.09)

        // Text
        static let textPrimary   = Color.white.opacity(1.0)
        static let textSecondary = Color.white.opacity(0.75)
        static let textTertiary  = Color.white.opacity(0.55)
        static let textHint      = Color.white.opacity(0.35)  // decorative only
    }

    // MARK: - Typography
    enum Typo {
        // Training numbers — rounded monospace feel
        static let countdownHero = Font.system(size: 96, weight: .bold, design: .rounded)
        static let timerLarge    = Font.system(size: 38, weight: .black, design: .rounded)
        static let timerMedium   = Font.system(size: 26, weight: .black, design: .rounded)
        static let timerSmall    = Font.system(size: 18, weight: .heavy, design: .rounded)
        static let timeBadge     = Font.system(size: 15, weight: .bold, design: .rounded)

        // UI text
        static let sectionLabel = Font.system(size: 11, weight: .medium)
        static let statusLabel  = Font.system(size: 12, weight: .medium)
        static let cardTitle    = Font.system(size: 15, weight: .medium)
        static let cardSubtitle = Font.system(size: 13, weight: .regular)
    }

    // MARK: - Spacing (4pt grid, tight)
    enum Space {
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 6
        static let md:   CGFloat = 10
        static let lg:   CGFloat = 14
        static let xl:   CGFloat = 18
        static let xxl:  CGFloat = 24
    }

    // MARK: - Corner Radius (small, functional)
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
    }

    // MARK: - Opacity
    enum Opacity {
        static let subtle:    Double = 0.04
        static let light:     Double = 0.08
        static let medium:    Double = 0.12
        static let regular:   Double = 0.18
        static let strong:    Double = 0.30
        static let prominent: Double = 0.50
    }
}

// MARK: - Card modifier (flat, bordered, no glow)

extension View {
    /// Standard card container
    func dsCard(
        color: Color = DS.Colors.card,
        radius: CGFloat = DS.Radius.lg,
        padding: CGFloat = DS.Space.lg
    ) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(color)
            )
    }

    /// Accent-tinted card (selected state).
    func dsCardAccent(accent: Color, radius: CGFloat = DS.Radius.lg, padding: CGFloat = DS.Space.lg) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(accent.opacity(DS.Opacity.subtle))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(accent.opacity(DS.Opacity.regular), lineWidth: 1)
            )
    }
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
