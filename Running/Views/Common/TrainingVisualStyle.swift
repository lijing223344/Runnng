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
                .stroke(isSelected ? accent : DS.Colors.border, lineWidth: 1.5)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Card Modifiers

extension View {

    /// Standard card container — solid dark fill, 1px border.
    func trainingCardContainer(cornerRadius: CGFloat = DS.Radius.lg) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DS.Colors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
    }

    /// Selectable card with accent left bar and solid border.
    func trainingSelectableCardContainer(
        accent: Color,
        isSelected: Bool,
        cornerRadius: CGFloat = DS.Radius.lg
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DS.Colors.card) // Always strictly dark card, no muddy tinted glass
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    // Brighter stroke on selection instead of full background tint
                    .stroke(isSelected ? accent.opacity(0.8) : DS.Colors.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 4, height: 36)
                    .padding(.leading, -1) // overlapping the stroke
                    .opacity(isSelected ? 1 : 0)
            }
    }

    /// Primary action button — solid accent fill when enabled, muted when disabled.
    /// Height: 56, cornerRadius: 14 — unified across all pages.
    func trainingPrimaryActionSurface(
        isEnabled: Bool,
        cornerRadius: CGFloat = 14,
        colors: [Color] = [DS.Colors.paceRun]
    ) -> some View {
        let accent = colors.first ?? DS.Colors.paceRun
        return self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isEnabled ? accent : DS.Colors.cardHover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isEnabled ? accent.opacity(0.30) : DS.Colors.border, lineWidth: 1)
            )
    }

    /// Training control button — pause/resume (neutral or accent).
    func trainingControlSurface(
        highlighted: Bool,
        accent: Color,
        cornerRadius: CGFloat = 14
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(highlighted ? accent : DS.Colors.cardHover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(highlighted ? accent.opacity(0.35) : DS.Colors.border, lineWidth: 1)
            )
    }

    /// Stop button — danger style with error color border.
    func trainingStopSurface(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DS.Colors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DS.Colors.error.opacity(0.40), lineWidth: 1)
            )
    }
}
