import SwiftUI

/// The console's cue palette. Browse mode when `selection` is nil, picker mode
/// otherwise. A speaker button auditions a cue without leaving the list.
struct SoundPaletteList: View {
    var selection: Binding<SoundType>?
    var showsHints: Bool = true
    var sounds: [SoundType] = SoundType.paletteOrder
    var accent: Color = DS.Colors.paceRun

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(sounds.enumerated()), id: \.element) { index, type in
                row(type)

                if index < sounds.count - 1 {
                    Rectangle()
                        .fill(DS.Colors.divider)
                        .frame(height: 1)
                        .padding(.leading, DS.Space.xxl)
                }
            }
        }
    }

    private func row(_ type: SoundType) -> some View {
        let isSelected = selection?.wrappedValue == type

        return HStack(spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayNameKey.localized)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)

                if showsHints {
                    Text(type.roleHintKey.localized)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: DS.Space.sm)

            Button {
                SoundManager.shared.playSound(type)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("sound_preview_a11y".localized)

            if let selection {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(selection.wrappedValue == type ? accent : Color.clear)
                    .frame(width: 14)
            }
        }
        .padding(.vertical, DS.Space.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let selection else { return }
            selection.wrappedValue = type
            SoundManager.shared.playSound(type)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("sound_palette_row_\(type.rawValue)")
    }
}

/// One cue row in a group editor: current choice, opening a full cue picker.
struct SoundCueRow: View {
    var label: String
    @Binding var selection: SoundType
    var identifier: String? = nil
    var accent: Color = DS.Colors.paceRun

    @State private var isPickerPresented = false

    var body: some View {
        Button {
            isPickerPresented = true
        } label: {
            HStack(spacing: DS.Space.sm) {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(DS.Colors.textPrimary)

                Spacer(minLength: DS.Space.sm)

                Text(selection.displayNameKey.localized)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? "sound_cue_row")
        .fullScreenCover(isPresented: $isPickerPresented) {
            SoundCuePickerScreen(title: label, selection: $selection, accent: accent)
        }
    }
}

/// Full-screen cue picker: every cue with its role hint, auditioned in place.
struct SoundCuePickerScreen: View {
    var title: String
    @Binding var selection: SoundType
    var accent: Color = DS.Colors.paceRun

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DS.Colors.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xl) {
                    group("sound_group_timing", SoundType.timingCases)
                    group("sound_group_field", SoundType.fieldCases)
                }
                .padding(.horizontal, DS.Space.page)
                .padding(.top, DS.Space.lg)
                .padding(.bottom, DS.Space.xxxl)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            DSModalHeader(
                title: title,
                trailingTitle: "done".localized,
                trailingIdentifier: "sound_picker_done_button",
                trailingAction: { dismiss() }
            )
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func group(_ titleKey: String, _ sounds: [SoundType]) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            DSSectionLabel(text: titleKey.localized)

            SoundPaletteList(selection: $selection, showsHints: true, sounds: sounds, accent: accent)
                .dsCard()
        }
    }
}
