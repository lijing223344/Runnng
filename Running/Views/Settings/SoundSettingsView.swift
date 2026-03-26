import SwiftUI

struct SoundSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var soundManager = SoundManager.shared
    @ObservedObject private var storage = StorageManager.shared
    @State private var settings: UserSettings = UserSettings()
    @State private var playingSlot: SoundSlot? = nil
    @State private var didLoad = false

    // Describes each configurable sound slot
    private enum SoundSlot: String, CaseIterable, Identifiable {
        case countdown, runStart, restStart, segmentMark, trainingComplete
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .countdown:        return "timer"
            case .runStart:         return "figure.run"
            case .restStart:        return "pause.circle.fill"
            case .segmentMark:      return "flag.fill"
            case .trainingComplete: return "checkmark.seal.fill"
            }
        }

        var color: Color {
            switch self {
            case .countdown:        return .orange
            case .runStart:         return .green
            case .restStart:        return .blue
            case .segmentMark:      return .yellow
            case .trainingComplete: return .purple
            }
        }

        var titleKey: String {
            switch self {
            case .countdown:        return "countdown"
            case .runStart:         return "run_start_sound"
            case .restStart:        return "rest_start_sound"
            case .segmentMark:      return "stage_complete"
            case .trainingComplete: return "training_complete"
            }
        }

        var descKey: String {
            switch self {
            case .countdown:        return "sound_desc_countdown"
            case .runStart:         return "sound_desc_run_start"
            case .restStart:        return "sound_desc_rest_start"
            case .segmentMark:      return "sound_desc_segment"
            case .trainingComplete: return "sound_desc_complete"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Volume ──────────────────────────────────────────
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Slider(value: $settings.soundConfig.volume, in: 0...1)
                                .tint(.blue)
                                .onChange(of: settings.soundConfig.volume) { _, v in
                                    soundManager.setVolume(v)
                                    storage.saveSettings(settings)
                                }
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                        }
                        HStack {
                            Spacer()
                            Text("\(Int(settings.soundConfig.volume * 100))%")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Divider()

                        HStack(spacing: 12) {
                            Image(systemName: settings.soundConfig.vibrationEnabled ? "iphone.radiowaves.left.and.right" : "iphone")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Toggle("sound_vibration".localized, isOn: $settings.soundConfig.vibrationEnabled)
                                .onChange(of: settings.soundConfig.vibrationEnabled) { _, enabled in
                                    soundManager.setVibrationEnabled(enabled)
                                    storage.saveSettings(settings)
                                }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("sound_volume".localized)
                }

                // ── Sound slots ─────────────────────────────────────
                Section {
                    ForEach(SoundSlot.allCases) { slot in
                        soundRow(slot: slot)
                    }
                } header: {
                    Text("sound_settings".localized)
                } footer: {
                    Text("sound_footer_hint".localized)
                        .font(.system(size: 12))
                }

                // ── Pre-warning info ─────────────────────────────────
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.orange)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("pre_warning_title".localized)
                                .font(.system(size: 15, weight: .medium))
                            Text("pre_warning_desc".localized)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("pre_warning_title".localized)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DS.Colors.bg)
            .navigationTitle("sound_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) { saveSettings(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                settings = StorageManager.shared.loadSettings()
                soundManager.setVolume(settings.soundConfig.volume)
                soundManager.setVibrationEnabled(settings.soundConfig.vibrationEnabled)
            }
        }
    }

    // MARK: - Sound Row
    @ViewBuilder
    private func soundRow(slot: SoundSlot) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(slot.color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: slot.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(slot.color)
                }

                // Title + description
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.titleKey.localized)
                        .font(.system(size: 15, weight: .medium))
                    Text(slot.descKey.localized)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Preview button
                Button(action: { previewSound(slot) }) {
                    Image(systemName: playingSlot == slot ? "speaker.wave.2.fill" : "play.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(playingSlot == slot ? slot.color : .secondary)
                        .symbolEffect(.bounce, value: playingSlot == slot)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(slot.titleKey.localized)
            }

            // Picker — menu style handles multiple options cleanly
            Picker("", selection: binding(for: slot)) {
                ForEach(SoundType.allCases) { sound in
                    Text(sound.displayNameKey.localized).tag(sound)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: binding(for: slot).wrappedValue) { _, newValue in
                soundManager.playSound(newValue)
                playingSlot = slot
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if playingSlot == slot { playingSlot = nil }
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func previewSound(_ slot: SoundSlot) {
        soundManager.playSound(binding(for: slot).wrappedValue)
        playingSlot = slot
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if playingSlot == slot { playingSlot = nil }
        }
    }

    private func binding(for slot: SoundSlot) -> Binding<SoundType> {
        switch slot {
        case .countdown:        return $settings.soundConfig.countdownSound
        case .runStart:         return $settings.soundConfig.runStartSound
        case .restStart:        return $settings.soundConfig.restStartSound
        case .segmentMark:      return $settings.soundConfig.stageCompleteSound
        case .trainingComplete: return $settings.soundConfig.trainingCompleteSound
        }
    }

    private func saveSettings() { storage.saveSettings(settings) }
}

#Preview { SoundSettingsView() }
