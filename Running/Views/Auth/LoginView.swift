import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var storage = StorageManager.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // MARK: - Hero
                VStack(spacing: DS.Space.lg) {
                    ZStack {
                        Circle()
                            .fill(DS.Colors.paceRun.opacity(DS.Opacity.light))
                            .frame(width: 100, height: 100)
                        Image(systemName: "figure.run")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(DS.Colors.paceRun)
                    }

                    Text("app_name".localized)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text("sign_in_prompt".localized)
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // MARK: - Actions
                VStack(spacing: DS.Space.lg) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .accessibilityIdentifier("login_apple_button")
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))

                    // Divider
                    HStack(spacing: DS.Space.md) {
                        Rectangle().fill(DS.Colors.divider).frame(height: 1)
                        Text("or".localized)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textTertiary)
                        Rectangle().fill(DS.Colors.divider).frame(height: 1)
                    }

                    Button(action: { loginAsGuest() }) {
                        Text("guest_mode".localized)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DS.Colors.card)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.xl)
                                    .stroke(DS.Colors.border, lineWidth: 1)
                            )
                    }
                    .accessibilityIdentifier("login_guest_button")

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.error)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, DS.Space.xxl)

                Spacer()
                    .frame(height: 60)
            }
            .background(DS.Colors.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func loginAsGuest() {
        storage.loginAsGuest()
        dismiss()
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let appleUserId = credential.user.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !appleUserId.isEmpty else {
                    errorMessage = "apple_sign_in_invalid_credential".localized
                    return
                }
                let suggestedName = credential.fullName?.givenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let nickname = suggestedName.isEmpty ? "default_nickname".localized : suggestedName

                // Use the credential returned by Apple's authorization callback directly.
                // Credential state checks are better suited for later session validation.
                storage.saveUser(
                    User(
                        id: appleUserId,
                        appleId: appleUserId,
                        nickname: nickname
                    )
                )
                dismiss()
                return
            }
            errorMessage = "apple_sign_in_invalid_credential".localized
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            errorMessage = error.localizedDescription
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
