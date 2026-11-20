import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var storage = StorageManager.shared
    let languages = [("system", "follow_system"), ("zh-Hans", "chinese"), ("en", "english")]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DSModalHeader(
                    title: "language_settings".localized,
                    trailingTitle: "done".localized,
                    trailingIdentifier: "language_settings_done_button"
                ) {
                    dismiss()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        VStack(spacing: 0) {
                            ForEach(Array(languages.enumerated()), id: \.element.0) { index, language in
                                languageRow(code: language.0, key: language.1)

                                if index < languages.count - 1 {
                                    Rectangle()
                                        .fill(DS.Colors.divider)
                                        .frame(height: 1)
                                        .padding(.leading, DS.Space.lg)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .fill(DS.Colors.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .stroke(DS.Colors.borderLight, lineWidth: 1)
                        )

                        Text("language_settings_note".localized)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, DS.Space.xs)
                    }
                    .padding(.horizontal, DS.Space.page)
                    .padding(.top, DS.Space.xl)
                    .padding(.bottom, DS.Space.xxxl)
                }
            }
            .background(DS.Colors.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func languageRow(code: String, key: String) -> some View {
        let selected = localization.currentLanguage == code

        return Button(action: { selectLanguage(code) }) {
            HStack(spacing: DS.Space.md) {
                DSLaneTick(length: 14, thickness: 2, color: selected ? DS.Colors.paceRun : Color.clear)

                Text(key.localized)
                    .font(.system(size: 15, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? DS.Colors.textPrimary : DS.Colors.textSecondary)

                Spacer(minLength: DS.Space.sm)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Colors.paceRun)
                }
            }
            .padding(.horizontal, DS.Space.lg)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func selectLanguage(_ language: String) {
        var settings = storage.loadSettings()
        settings.language = language
        storage.saveSettings(settings)
        localization.setLanguage(language)
        // Sync language to Watch
        PhoneConnectivityManager.shared.syncLanguageToWatch(language)
    }
}

#Preview { LanguageSettingsView() }
