import SwiftUI

struct SettingsView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var storage = StorageManager.shared
    @ObservedObject private var cloudSync = CloudSyncManager.shared
    @State private var showLanguageSheet = false
    @State private var showLoginSheet = false
    @State private var showSoundSettings = false
    @State private var showDeleteAccountAlert = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Space.md) {
                accountCard
                preferencesCard
                aboutCard
            }
            .padding(.horizontal, DS.Space.xl)
            .padding(.vertical, DS.Space.xl)
        }
        .background(DS.Colors.bg.ignoresSafeArea())
        .navigationTitle("settings".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLanguageSheet) { LanguageSettingsView() }
        .sheet(isPresented: $showSoundSettings) { SoundSettingsView() }
        .sheet(isPresented: $showLoginSheet) { LoginView() }
        .alert("delete_account_title".localized, isPresented: $showDeleteAccountAlert) {
            Button("cancel".localized, role: .cancel) {}
            Button("delete".localized, role: .destructive) {
                storage.deleteCurrentAccount()
            }
        } message: {
            Text("delete_account_message".localized)
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            sectionHeader("account".localized)

            HStack(spacing: DS.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DS.Colors.paceRun)
                        .frame(width: 42, height: 42)
                    Image(systemName: storage.isLoggedIn ? "person.crop.circle.fill" : "person.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(storage.currentUser?.nickname ?? "guest".localized)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(storage.isLoggedIn ? "login".localized : "guest_mode".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
            }

            // iCloud sync status
            HStack(spacing: DS.Space.sm) {
                Image(systemName: syncIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(syncColor)
                Text(syncLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Colors.textTertiary)
                Spacer()
            }
            .padding(.vertical, 2)

            if storage.isLoggedIn {
                Button(action: { storage.logout() }) {
                    row(icon: "rectangle.portrait.and.arrow.right", tint: DS.Colors.error, title: "logout".localized)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings_logout_button")

                Rectangle().fill(DS.Colors.divider).frame(height: 1)

                Button(action: { showDeleteAccountAlert = true }) {
                    row(icon: "trash", tint: DS.Colors.error, title: "delete_account".localized)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings_delete_account_button")
            } else {
                Button(action: { showLoginSheet = true }) {
                    row(icon: "person.badge.plus", tint: DS.Colors.paceRun, title: "login".localized, showChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings_login_button")

                if storage.isGuest {
                    Rectangle().fill(DS.Colors.divider).frame(height: 1)

                    Button(action: { storage.logout() }) {
                        row(icon: "rectangle.portrait.and.arrow.right", tint: DS.Colors.error, title: "logout".localized)
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

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            sectionHeader("settings".localized)

            Button(action: { showSoundSettings = true }) {
                row(icon: "speaker.wave.2", tint: DS.Colors.paceRun, title: "sound_settings".localized, showChevron: true)
            }
            .buttonStyle(.plain)

            Rectangle().fill(DS.Colors.divider).frame(height: 1)

            Button(action: { showLanguageSheet = true }) {
                HStack {
                    row(icon: "globe", tint: DS.Colors.interval, title: "language_settings".localized, showChevron: false)
                    Spacer()
                    Text(localization.displayLanguageName)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
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
                row(icon: "info.circle", tint: DS.Colors.warning, title: "version".localized, showChevron: false)
                Spacer()
                Text("1.0.0")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .dsCard()
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DS.Colors.textTertiary)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    private func row(icon: String, tint: Color, title: String, showChevron: Bool = false) -> some View {
        HStack(spacing: DS.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(DS.Colors.textPrimary)
            if showChevron {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .contentShape(Rectangle())
    }
}
