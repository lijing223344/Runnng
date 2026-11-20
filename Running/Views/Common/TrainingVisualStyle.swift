import SwiftUI

// MARK: - Page Background

struct TrainingPageBackground: View {
    var body: some View {
        DS.Colors.bg.ignoresSafeArea()
    }
}

// MARK: - Selection Indicator

struct TrainingSelectionIndicator: View {
    let isSelected: Bool
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? accent : Color.clear)
            Circle()
                .stroke(isSelected ? accent : DS.Colors.border, lineWidth: 1)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Colors.bg)
            }
        }
        .frame(width: 22, height: 22)
        .animation(DS.Motion.curve, value: isSelected)
    }
}

// MARK: - Card Modifiers

extension View {

    /// Quiet card container — one surface step, one hairline.
    func trainingCardContainer(cornerRadius: CGFloat = DS.Radius.lg) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DS.Colors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DS.Colors.borderLight, lineWidth: 1)
            )
    }

    /// Selectable card — selection is a surface step plus an accent hairline,
    /// never a tinted wash or an extra accent bar.
    func trainingSelectableCardContainer(
        accent: Color,
        isSelected: Bool,
        cornerRadius: CGFloat = DS.Radius.lg
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isSelected ? DS.Colors.cardHover : DS.Colors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? accent.opacity(0.40) : DS.Colors.borderLight,
                        lineWidth: 1
                    )
            )
    }

    /// Primary action — the single bright control on a screen: an off-white
    /// key from the ramp with dark text. Works for every discipline accent.
    func trainingPrimaryActionSurface(
        isEnabled: Bool,
        cornerRadius: CGFloat = DS.Radius.md,
        colors: [Color] = [DS.Colors.paceRun]
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isEnabled ? DS.Colors.textPrimary : DS.Colors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isEnabled ? Color.white.opacity(0.20) : DS.Colors.borderLight,
                        lineWidth: 1
                    )
            )
    }

    /// Text colour that belongs on a primary action surface.
    func trainingPrimaryActionForeground(isEnabled: Bool) -> some View {
        self.foregroundStyle(isEnabled ? DS.Colors.bg : DS.Colors.textTertiary)
    }

    /// Training control button — pause/resume (neutral or accent).
    func trainingControlSurface(
        highlighted: Bool,
        accent: Color,
        cornerRadius: CGFloat = DS.Radius.md
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(highlighted ? accent : DS.Colors.cardHover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(highlighted ? accent.opacity(0.40) : DS.Colors.borderLight, lineWidth: 1)
            )
    }

    /// Stop button — quiet surface with a semantic hairline.
    func trainingStopSurface(cornerRadius: CGFloat = DS.Radius.md) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DS.Colors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DS.Colors.error.opacity(0.35), lineWidth: 1)
            )
    }
}
