import SwiftUI

// MARK: - Design System (track-side instrument language)
//
// Direction: a coach's timing console used at the track.
//   Character: precise, athletic, quiet.
//   World: rubber track, lane paint, stopwatch steel.
//   Rule: one neutral graphite ramp carries every surface; a discipline
//         colour appears only as a lane tick — never as a surface wash.
//         One moment per screen carries the richness (figures, splits,
//         the 21-lane table).

enum DS {

    // MARK: - Colors
    enum Colors {
        // Discipline identities — markers only (tick, dot, single number),
        // never used to tint a whole surface.
        static let paceRun    = Color(red: 0.184, green: 0.420, blue: 1.000) // #2F6BFF
        static let interval   = Color(red: 0.941, green: 0.463, blue: 0.102) // #F0761A
        static let model400   = Color(red: 0.184, green: 0.722, blue: 0.431) // #2FB86E
        static let miniHurdle = Color(red: 0.773, green: 0.639, blue: 0.357) // #C5A35B

        // Ink variants — for coloured text/icons on the dark ramp (≥ 4.5:1).
        static let paceRunInk    = Color(red: 0.427, green: 0.580, blue: 1.000) // #6D94FF
        static let intervalInk   = Color(red: 1.000, green: 0.604, blue: 0.322) // #FF9A52
        static let model400Ink   = Color(red: 0.337, green: 0.843, blue: 0.608) // #56D79B
        static let miniHurdleInk = Color(red: 0.871, green: 0.733, blue: 0.471) // #DEBB78

        // Semantic — meaning only, toned into the ramp.
        static let success = Color(red: 0.243, green: 0.812, blue: 0.557) // #3ECF8E
        static let warning = Color(red: 0.910, green: 0.690, blue: 0.294) // #E8B04B
        static let error   = Color(red: 0.937, green: 0.373, blue: 0.373) // #EF5F5F
        static let rest    = Color(red: 0.486, green: 0.612, blue: 0.769) // #7C9CC4

        // Surfaces — one graphite ramp with a whisper of instrument blue.
        static let bg          = Color(red: 0.043, green: 0.047, blue: 0.059) // #0B0C0F
        static let card        = Color(red: 0.075, green: 0.078, blue: 0.094) // #131418
        static let cardHover   = Color(red: 0.106, green: 0.114, blue: 0.133) // #1B1D22
        static let field       = Color(red: 0.133, green: 0.145, blue: 0.169) // #22252B
        static let fieldBorder = Color.white.opacity(0.10)
        static let border      = Color.white.opacity(0.09)
        static let borderLight = Color.white.opacity(0.06)
        static let divider     = Color.white.opacity(0.07)

        // Text — three roles, no more.
        static let textPrimary   = Color(red: 0.961, green: 0.965, blue: 0.973) // #F5F6F8
        static let textSecondary = Color.white.opacity(0.66)
        static let textTertiary  = Color.white.opacity(0.46)
        static let textHint      = Color.white.opacity(0.26)

        /// Ink variant for a discipline colour used as text.
        static func ink(for accent: Color) -> Color {
            if accent == paceRun { return paceRunInk }
            if accent == interval { return intervalInk }
            if accent == model400 { return model400Ink }
            if accent == miniHurdle { return miniHurdleInk }
            return accent
        }
    }

    // MARK: - Typography
    enum Typo {
        // Timing figures — scoreboard numerals, not display type.
        static let countdownHero = Font.system(size: 88, weight: .semibold, design: .rounded)
        static let timerLarge    = Font.system(size: 36, weight: .semibold, design: .rounded)
        static let timerMedium   = Font.system(size: 26, weight: .semibold, design: .rounded)
        static let timerSmall    = Font.system(size: 18, weight: .medium, design: .rounded)
        static let timeBadge     = Font.system(size: 15, weight: .medium, design: .rounded)

        // UI text
        static let sectionLabel = Font.system(size: 12, weight: .medium)
        static let statusLabel  = Font.system(size: 12, weight: .regular)
        static let cardTitle    = Font.system(size: 16, weight: .semibold)
        static let cardSubtitle = Font.system(size: 13, weight: .regular)

        // Page furniture
        static let pageTitle  = Font.system(size: 27, weight: .semibold)
        static let pageDate   = Font.system(size: 12, weight: .medium, design: .monospaced)
        static let figure     = Font.system(size: 27, weight: .medium, design: .rounded)
        static let meta       = Font.system(size: 11, weight: .medium, design: .monospaced)
        static let rowTitle   = Font.system(size: 16, weight: .semibold)
        static let rowDetail  = Font.system(size: 13, weight: .regular)
    }

    // MARK: - Spacing (4pt grid)
    enum Space {
        static let xxs:  CGFloat = 4
        static let xs:   CGFloat = 6
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 20
        static let xxl:  CGFloat = 24
        static let xxxl: CGFloat = 32
        /// Page edge inset.
        static let page: CGFloat = 20
    }

    // MARK: - Corner Radius (nested, never a pill by default)
    enum Radius {
        static let sm: CGFloat = 6   // keycap / tag
        static let md: CGFloat = 10  // row, input, control
        static let lg: CGFloat = 14  // card
        static let xl: CGFloat = 18  // sheet / panel
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

    // MARK: - Motion (one curve)
    enum Motion {
        static let curve = Animation.easeOut(duration: 0.18)
        static let enter = Animation.easeOut(duration: 0.24)
    }
}

// MARK: - Cards

extension View {
    /// Quiet card: one surface step plus a hairline, no shadow, no glow.
    func dsCard(
        color: Color = DS.Colors.card,
        radius: CGFloat = DS.Radius.lg,
        padding: CGFloat = DS.Space.lg,
        borderColor: Color = DS.Colors.borderLight
    ) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    /// Selected / raised card — a surface step and an accent hairline,
    /// never a tinted wash.
    func dsCardAccent(accent: Color, radius: CGFloat = DS.Radius.lg, padding: CGFloat = DS.Space.lg) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DS.Colors.cardHover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(accent.opacity(0.40), lineWidth: 1)
            )
    }
}

// MARK: - Lane tick (the product's signature detail)
//
// A short lane-paint stroke that marks a discipline. Used on entry rows,
// page headers and group cards — nowhere else.

struct DSLaneTick: View {
    var length: CGFloat = 18
    var thickness: CGFloat = 3
    var color: Color = DS.Colors.paceRun

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(color)
            .frame(width: thickness, height: length)
    }
}

struct DSLaneRule: View {
    var color: Color = DS.Colors.paceRun
    var width: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(color)
            .frame(width: width, height: 2)
    }
}

// MARK: - Page header

struct DSPageHeader: View {
    var title: String
    var subtitle: String?
    var dateLine: String?
    var tick: Color = DS.Colors.paceRun

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            if let dateLine {
                Text(dateLine)
                    .font(DS.Typo.pageDate)
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            DSLaneRule(color: tick)

            Text(title)
                .font(DS.Typo.pageTitle)
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(.top, DS.Space.xxs)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(DS.Typo.bodyText)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension DS.Typo {
    static let bodyText = Font.system(size: 14, weight: .regular)
}

// MARK: - Modal header (owned instead of the system sheet chrome)

struct DSModalHeader: View {
    var title: String = ""
    var leadingTitle: String = ""
    var leadingIdentifier: String = ""
    var trailingTitle: String = ""
    var trailingIdentifier: String = ""
    var trailingDisabled: Bool = false
    var leadingAction: () -> Void = {}
    var trailingAction: () -> Void = {}

    var body: some View {
        ZStack {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
            }

            HStack(spacing: DS.Space.sm) {
                if !leadingTitle.isEmpty {
                    Button(action: leadingAction) {
                        Text(leadingTitle)
                            .font(.system(size: 15))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(leadingIdentifier)
                }

                Spacer(minLength: 0)

                if !trailingTitle.isEmpty {
                    Button(action: trailingAction) {
                        Text(trailingTitle)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(trailingDisabled ? DS.Colors.textTertiary : DS.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(trailingDisabled)
                    .accessibilityIdentifier(trailingIdentifier)
                }
            }
        }
        .frame(height: 52)
        .padding(.horizontal, DS.Space.lg)
        .background(DS.Colors.bg.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Colors.borderLight).frame(height: 1)
        }
    }
}

// MARK: - Inline section label

struct DSSectionLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(DS.Typo.sectionLabel)
            .foregroundStyle(DS.Colors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Quiet segmented control (surface step, no accent wash)

struct DSSegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    var accent: Color = DS.Colors.paceRun
    let label: (T) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    guard !selected else { return }
                    selection = option
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(label(option))
                        .font(.system(size: 14, weight: selected ? .medium : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .foregroundStyle(selected ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .fill(selected ? DS.Colors.field : Color.clear)
                        )
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(selected ? accent : Color.clear)
                                .frame(height: 2)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 1)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md + 2, style: .continuous)
                .fill(DS.Colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md + 2, style: .continuous)
                .stroke(DS.Colors.borderLight, lineWidth: 1)
        )
    }
}

/// Quiet preset option: flat text when idle, one surface step when selected.
struct DSPresetTile: View {
    var title: String
    var isSelected: Bool
    var height: CGFloat = 36
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(isSelected ? DS.Colors.field : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(isSelected ? DS.Colors.border : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Buttons

struct ScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.98 : 1.0))
            .animation(reduceMotion ? nil : DS.Motion.curve, value: configuration.isPressed)
    }
}

/// Quiet secondary button: raised surface, hairline, primary text.
struct DSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(DS.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(configuration.isPressed ? DS.Colors.cardHover : DS.Colors.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
            .animation(DS.Motion.curve, value: configuration.isPressed)
    }
}
