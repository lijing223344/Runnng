import SwiftUI

struct SoundSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var soundManager = SoundManager.shared
    @ObservedObject private var storage = StorageManager.shared
    @State private var settings: UserSettings = UserSettings()
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DSModalHeader(
                    title: "sound_settings".localized,
                    trailingTitle: "done".localized,
                    trailingIdentifier: "sound_settings_done_button"
                ) {
                    dismiss()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.xxl) {
                        volumeSection
                        paletteSection
                        warningSection
                    }
                    .padding(.horizontal, DS.Space.page)
                    .padding(.top, DS.Space.xl)
                    .padding(.bottom, DS.Space.xxxl)
                }
            }
            .background(DS.Colors.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                settings = StorageManager.shared.loadSettings()
                soundManager.setVolume(settings.soundConfig.volume)
                soundManager.setVibrationEnabled(settings.soundConfig.vibrationEnabled)
            }
        }
    }

    // MARK: - Volume and haptics

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            DSSectionLabel(text: "sound_volume".localized)

            VStack(spacing: DS.Space.md) {
                HStack(spacing: DS.Space.md) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 16)

                    Slider(value: $settings.soundConfig.volume, in: 0...1)
                        .tint(DS.Colors.paceRun)
                        .onChange(of: settings.soundConfig.volume) { _, value in
                            soundManager.setVolume(value)
                            storage.saveSettings(settings)
                            PhoneConnectivityManager.shared.syncSoundVolumeToWatch(value)
                        }

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 20)
                }

                HStack {
                    Spacer()
                    Text("\(Int(settings.soundConfig.volume * 100))%")
                        .font(.system(size: 12, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(DS.Colors.textSecondary)
                }

                Rectangle().fill(DS.Colors.divider).frame(height: 1)

                HStack(spacing: DS.Space.md) {
                    Image(systemName: settings.soundConfig.vibrationEnabled ? "iphone.radiowaves.left.and.right" : "iphone")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 16)

                    Toggle("sound_vibration".localized, isOn: $settings.soundConfig.vibrationEnabled)
                        .font(.system(size: 15))
                        .tint(DS.Colors.paceRun)
                        .onChange(of: settings.soundConfig.vibrationEnabled) { _, enabled in
                            soundManager.setVibrationEnabled(enabled)
                            storage.saveSettings(settings)
                            PhoneConnectivityManager.shared.syncVibrationToWatch(enabled)
                        }
                }
            }
            .dsCard()
        }
    }

    // MARK: - Cue palette

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            DSSectionLabel(text: "sound_library".localized)

            VStack(alignment: .leading, spacing: 0) {
                paletteCaption("sound_group_timing")
                SoundPaletteList(sounds: SoundType.timingCases)

                paletteCaption("sound_group_field")
                    .padding(.top, DS.Space.sm)
                SoundPaletteList(sounds: SoundType.fieldCases)

                Text("sound_library_note".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DS.Space.sm)
            }
            .dsCard()
        }
    }

    private func paletteCaption(_ key: String) -> some View {
        Text(key.localized)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DS.Colors.textTertiary)
            .padding(.top, DS.Space.xs)
            .padding(.bottom, 2)
    }

    // MARK: - Countdown pre-warning

    private var warningSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            DSSectionLabel(text: "pre_warning_title".localized)

            HStack(alignment: .top, spacing: DS.Space.md) {
                DSLaneTick(length: 16, thickness: 2, color: DS.Colors.paceRun)

                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text("pre_warning_desc".localized)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DS.Space.sm)

                Text("sound_warning_fixed".localized)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .dsCard()
        }
    }
}

#Preview { SoundSettingsView() }
