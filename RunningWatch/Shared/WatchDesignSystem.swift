import SwiftUI

// Watch Design System — adapted from iOS DS for smaller screens

enum WDS {
    // MARK: - Colors (same as iOS — pure dark theme)
    enum Colors {
        static let paceRun  = Color(red: 0.18, green: 0.45, blue: 0.96)
        static let interval = Color(red: 1.00, green: 0.50, blue: 0.05)

        static let success = Color(red: 0.30, green: 0.80, blue: 0.46)
        static let warning = Color(red: 0.96, green: 0.68, blue: 0.24)
        static let error   = Color(red: 0.94, green: 0.36, blue: 0.36)

        static let bg          = Color.black
        static let card        = Color(red: 0.07, green: 0.07, blue: 0.08)
        static let cardHover   = Color(red: 0.10, green: 0.10, blue: 0.11)
        static let border      = Color.white.opacity(0.12)
        static let divider     = Color.white.opacity(0.09)

        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.75)
        static let textTertiary  = Color.white.opacity(0.55)
    }

    // MARK: - Typography (scaled down for watch)
    enum Typo {
        static let countdownHero = Font.system(size: 56, weight: .bold, design: .rounded)
        static let timerLarge    = Font.system(size: 32, weight: .black, design: .rounded)
        static let timerMedium   = Font.system(size: 22, weight: .bold, design: .rounded)
        static let timerSmall    = Font.system(size: 16, weight: .heavy, design: .rounded)

        static let cardTitle    = Font.system(size: 14, weight: .medium)
        static let cardSubtitle = Font.system(size: 12, weight: .regular)
        static let caption      = Font.system(size: 11, weight: .regular)
    }

    // MARK: - Spacing
    enum Space {
        static let xs:  CGFloat = 2
        static let sm:  CGFloat = 4
        static let md:  CGFloat = 6
        static let lg:  CGFloat = 8
        static let xl:  CGFloat = 12
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
    }
}
