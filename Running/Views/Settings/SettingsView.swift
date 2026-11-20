import SwiftUI

struct SettingsView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var storage = StorageManager.shared
    @ObservedObject private var cloudSync = CloudSyncManager.shared
    private let appVersion = AppVersionProvider.displayString()
    @State private var showLanguageSheet = false
    @State private var showLoginSheet = false
    @State private var showSoundSettings = false
    @State private var showDeleteAccountAlert = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                DSPageHeader(
                    title: "settings".localized,
                    subtitle: nil,
                    dateLine: nil,
                    tick: DS.Colors.paceRun
                )
                .padding(.bottom, DS.Space.xs)

                accountCard
                preferencesCard
                aboutCard
            }
            .padding(.horizontal, DS.Space.page)
            .padding(.top, DS.Space.sm)
            .padding(.bottom, 112)
            .dsReadableColumn()
        }
        .background(DS.Colors.bg.ignoresSafeArea())
        .navigationTitle("settings".localized)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showLanguageSheet) { LanguageSettingsView() }
        .fullScreenCover(isPresented: $showSoundSettings) { SoundSettingsView() }
        .fullScreenCover(isPresented: $showLoginSheet) { LoginView() }
        .alert("delete_account_title".localized, isPresented: $showDeleteAccountAlert) {
            Button("cancel".localized, role: .cancel) {}
            Button("delete".localized, role: .destructive) {
                storage.deleteCurrentAccount()
            }
        } message: {
            Text("delete_account_message".localized)
        }
    }

    // MARK: - Account

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            sectionHeader("account".localized)

            HStack(spacing: DS.Space.md) {
                Image(systemName: storage.isLoggedIn ? "person.crop.circle.fill" : "person.circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(storage.currentUser?.nickname ?? "guest".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(storage.isLoggedIn ? "login".localized : "guest_mode".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Spacer(minLength: 0)

                HStack(spacing: DS.Space.xxs) {
                    Image(systemName: syncIcon)
                        .font(.system(size: 11, weight: .regular))
                    Text(syncLabel)
                        .font(DS.Typo.meta)
                }
                .foregroundStyle(syncColor)
            }
            .frame(minHeight: 48)

            Rectangle().fill(DS.Colors.divider).frame(height: 1)

            if storage.isLoggedIn {
                Button(action: { storage.logout() }) {
                    row(icon: "rectangle.portrait.and.arrow.right", title: "logout".localized, destructive: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings_logout_button")

                Rectangle().fill(DS.Colors.divider).frame(height: 1)

                Button(action: { showDeleteAccountAlert = true }) {
                    row(icon: "trash", title: "delete_account".localized, destructive: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings_delete_account_button")
            } else {
                Button(action: { showLoginSheet = true }) {
                    row(icon: "person.badge.plus", title: "login".localized, showChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings_login_button")

                if storage.isGuest {
                    Rectangle().fill(DS.Colors.divider).frame(height: 1)

                    Button(action: { storage.logout() }) {
                        row(icon: "rectangle.portrait.and.arrow.right", title: "logout".localized, destructive: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings_logout_button")
                }
            }
        }
        .dsCard()
    }

    private var syncIcon: String {
        switch cloudSync.syncStatus {
        case .synced:  return "checkmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .offline: return "icloud.slash"
        case .idle:    return "icloud"
        }
    }

    private var syncColor: Color {
        switch cloudSync.syncStatus {
        case .synced:  return DS.Colors.success
        case .syncing: return DS.Colors.warning
        case .offline: return DS.Colors.error
        case .idle:    return DS.Colors.textTertiary
        }
    }

    private var syncLabel: String {
        switch cloudSync.syncStatus {
        case .synced:  return "sync_synced".localized
        case .syncing: return "sync_syncing".localized
        case .offline: return "sync_offline".localized
        case .idle:    return "icloud_sync".localized
        }
    }

    // MARK: - Preferences

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            sectionHeader("settings".localized)

            Button(action: { showSoundSettings = true }) {
                row(icon: "speaker.wave.2", title: "sound_settings".localized, showChevron: true)
            }
            .buttonStyle(.plain)

            Rectangle().fill(DS.Colors.divider).frame(height: 1)

            Button(action: { showLanguageSheet = true }) {
                HStack {
                    row(icon: "globe", title: "language_settings".localized, showChevron: false)
                    Spacer(minLength: DS.Space.sm)
                    Text(localization.displayLanguageName)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Colors.textHint)
                }
            }
            .buttonStyle(.plain)
        }
        .dsCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            sectionHeader("about".localized)
            HStack {
                row(icon: "info.circle", title: "version".localized, showChevron: false)
                Spacer(minLength: DS.Space.sm)
                Text(appVersion)
                    .font(.system(size: 13, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .dsCard()
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DS.Colors.textTertiary)
    }

    private func row(icon: String, title: String, showChevron: Bool = false, destructive: Bool = false) -> some View {
        HStack(spacing: DS.Space.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(destructive ? DS.Colors.error.opacity(0.85) : DS.Colors.textSecondary)
                .frame(width: 22, alignment: .center)

            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(destructive ? DS.Colors.error.opacity(0.85) : DS.Colors.textPrimary)

            if showChevron {
                Spacer(minLength: DS.Space.sm)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Colors.textHint)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}
