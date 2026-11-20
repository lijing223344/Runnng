import SwiftUI
import Combine
import UIKit
import AuthenticationServices

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var storage = StorageManager.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var errorMessage = ""
    @StateObject private var appleSignIn = AppleSignInCoordinator()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DSModalHeader(
                    leadingTitle: "cancel".localized,
                    leadingIdentifier: "login_cancel_button"
                ) {
                    dismiss()
                }

                Spacer(minLength: 0)

                VStack(spacing: DS.Space.md) {
                    DSLaneRule(color: DS.Colors.paceRun, width: 28)

                    Text("app_name".localized)
                        .font(.system(size: 27, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("sign_in_prompt".localized)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Space.xxxl)
                }
                .padding(.horizontal, DS.Space.page)

                Spacer(minLength: 0)

                VStack(spacing: DS.Space.lg) {
                    // Custom-rendered button: the system control takes the
                    // device locale, which left a Chinese label in the
                    // English interface. Copy follows the app language.
                    Button {
                        appleSignIn.start { result in
                            handleAppleSignIn(result)
                        }
                    } label: {
                        HStack(spacing: DS.Space.sm) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 17, weight: .medium))
                            Text("sign_in_with_apple".localized)
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .fill(Color.white)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("login_apple_button")

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
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .fill(DS.Colors.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .stroke(DS.Colors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("login_guest_button")

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.error)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, DS.Space.page)
                .padding(.bottom, DS.Space.xxxl)
            }
            .background(DS.Colors.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
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

final class AppleSignInCoordinator: NSObject, ObservableObject,
    ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let objectWillChange = ObservableObjectPublisher()
    private var completion: ((Result<ASAuthorization, Error>) -> Void)?

    func start(_ completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        completion?(.success(authorization))
        completion = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        completion?(.failure(error))
        completion = nil
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
