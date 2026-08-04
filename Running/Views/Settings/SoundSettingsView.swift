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
                                    PhoneConnectivityManager.shared.syncSoundVolumeToWatch(v)
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
                                    PhoneConnectivityManager.shared.syncVibrationToWatch(enabled)
                                }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("sound_volume".localized)
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

    private func saveSettings() { storage.saveSettings(settings) }
}

#Preview { SoundSettingsView() }
