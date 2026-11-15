import SwiftUI
import Observation

/// Sign-in only. Accounts are created on the WebBlock website.
@MainActor @Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var showGoogleChooser = false
    var isLoading = false
    var errorMessage: String?

    private let service: WebBlockService
    init(service: WebBlockService = ServiceLocator.current) { self.service = service }

    var isEmailValid: Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !email.contains(" ")
    }
    var emailError: String? { email.isEmpty || isEmailValid ? nil : "Enter a valid email address." }
    var canSignIn: Bool { isEmailValid && !password.isEmpty && !isLoading }

    func signIn(appState: AppState) async {
        await run { appState.signedIn(try await service.signIn(email: email, password: password)) }
    }

    func signInWithGoogle(appState: AppState) async {
        await run {
            let profile = try await service.signInWithGoogle()
            showGoogleChooser = false
            appState.signedIn(profile)
        }
    }

    private func run(_ work: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { try await work() } catch { errorMessage = error.localizedDescription }
    }
}
