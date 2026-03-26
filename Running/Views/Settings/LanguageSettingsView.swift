import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var storage = StorageManager.shared
    let languages = [("system", "follow_system"), ("zh-Hans", "chinese"), ("en", "english")]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(languages, id: \.0) { code, key in
                    Button(action: { selectLanguage(code) }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill((localization.currentLanguage == code ? Color.blue : Color.secondary).opacity(0.14))
                                    .frame(width: 38, height: 38)
                                Image(systemName: localization.currentLanguage == code ? "checkmark.circle.fill" : "globe")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(localization.currentLanguage == code ? .blue : .secondary)
                            }

                            Text(key.localized)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)

                            Spacer()

                            if localization.currentLanguage == code {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(localization.currentLanguage == code ? DS.Colors.paceRun.opacity(0.08) : DS.Colors.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(localization.currentLanguage == code ? DS.Colors.paceRun.opacity(0.28) : DS.Colors.border, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DS.Colors.bg)
            .navigationTitle("language_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("done".localized) { dismiss() } } }
        }
    }
    
    private func selectLanguage(_ language: String) {
        var settings = storage.loadSettings()
        settings.language = language
        storage.saveSettings(settings)
        localization.setLanguage(language)
    }
}

#Preview { LanguageSettingsView() }
