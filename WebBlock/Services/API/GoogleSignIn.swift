import AuthenticationServices
import CryptoKit
import UIKit

/// Keycloak authorization-code flow with PKCE (S256) for "Continue with Google"
/// (docs/API-MAPPING.md 2.1): `client_id=webblock-ios`, `kc_idp_hint=google`,
/// redirect `com.webblock.app:/oauth2redirect`. The code is then sent to `POST /sessions/google`.
@MainActor
enum GoogleSignIn {
    struct Result {
        let code: String
        let codeVerifier: String
    }

    private final class Anchor: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }

    private static var activeSession: ASWebAuthenticationSession?
    private static let anchor = Anchor()

    static func authorize() async throws -> Result {
        let verifier = randomString(byteCount: 48)
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = randomString(byteCount: 16)

        var components = URLComponents(string: APIConfig.authRealmURL + "/protocol/openid-connect/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: APIConfig.googleClientID),
            URLQueryItem(name: "redirect_uri", value: APIConfig.googleRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: APIConfig.googleScope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "kc_idp_hint", value: "google"),
        ]
        guard let url = components.url else { throw APIError(message: ApiMessages.generic) }

        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: APIConfig.googleRedirectScheme) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: APIError(message: "Google sign-in was cancelled."))
                } else {
                    continuation.resume(throwing: APIError(message: "Google sign-in didn't finish. Try again."))
                }
            }
            session.presentationContextProvider = anchor
            session.prefersEphemeralWebBrowserSession = false
            activeSession = session
            if !session.start() {
                continuation.resume(throwing: APIError(message: "Google sign-in didn't finish. Try again."))
            }
        }
        activeSession = nil

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else {
            throw APIError(message: "Google sign-in didn't finish. Try again.")
        }
        return Result(code: code, codeVerifier: verifier)
    }

    private static func randomString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
