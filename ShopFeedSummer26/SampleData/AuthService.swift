import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

/// Manages Shop account sign-in via the web session OAuth flow.
/// Uses ASWebAuthenticationSession so the system browser handles all MFA
/// (Okta, YubiKey, etc.) natively — works in the simulator too.
///
/// Flow:
/// 1. signInWithWebSessionInitiate → get authorizeUrl, clientId, scope
/// 2. Open authorizeUrl in ASWebAuthenticationSession with PKCE
/// 3. User authenticates in browser (handles Okta/YubiKey/etc.)
/// 4. Browser redirects back with auth code
/// 5. signInWithWebSessionComplete → accessToken + refreshToken
@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private let endpoint = URL(string: "https://server.shop.app/graphql")!
    private let callbackScheme = "shopapp"

    enum State: Equatable {
        case unknown
        case signedOut
        case signingIn
        case signedIn
        case error(String)
    }

    var state: State = .unknown
    var userEmail: String?

    /// The current valid access token, or nil.
    var accessToken: String? {
        guard let token = stored.accessToken,
              let expiry = stored.accessTokenExpiry,
              Date() < expiry else {
            return nil
        }
        return token
    }

    /// Whether we have a refresh token (even if access token is expired).
    var hasSession: Bool {
        stored.refreshToken != nil
    }

    private var stored = StoredTokens.load()

    private init() {
        if stored.refreshToken != nil {
            state = .signedIn
            userEmail = stored.email
        } else {
            state = .signedOut
        }
    }

    // MARK: - Public

    /// Trigger the Shop account web sign-in flow.
    func signIn() async {
        state = .signingIn

        do {
            // Step 1: Initiate — get authorize URL from Shop Server
            let session = try await initiateWebSession()

            // Step 2: Generate PKCE pair
            let pkce = PKCE.generate()

            // Step 3: Open browser for authentication
            let code = try await openAuthBrowser(
                authorizeUrl: session.authorizeUrl,
                clientId: session.clientId,
                scope: session.scope,
                codeChallenge: pkce.challenge
            )

            // Step 4: Complete — exchange code for tokens
            let redirectUri = "\(session.authorizeUrl)/complete"
            let tokens = try await completeWebSession(
                code: code,
                codeVerifier: pkce.verifier,
                redirectUri: redirectUri
            )

            stored = tokens
            stored.save()
            userEmail = stored.email
            state = .signedIn
        } catch AuthError.cancelled {
            state = .signedOut
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Get a valid authorization header, refreshing if needed.
    func getAuthorization() async throws -> String {
        if let token = accessToken {
            return "Bearer \(token)"
        }

        guard let refreshToken = stored.refreshToken else {
            throw AuthError.notSignedIn
        }

        let tokens = try await refreshAccessToken(refreshToken: refreshToken)
        stored.accessToken = tokens.accessToken
        stored.refreshToken = tokens.refreshToken ?? stored.refreshToken
        stored.accessTokenExpiry = tokens.accessTokenExpiry
        stored.save()

        guard let token = stored.accessToken else {
            throw AuthError.refreshFailed
        }
        return "Bearer \(token)"
    }

    /// Sign out and clear stored tokens.
    func signOut() {
        stored = StoredTokens()
        stored.save()
        state = .signedOut
        userEmail = nil
    }

    // MARK: - Step 1: Initiate

    private struct WebSessionInfo {
        let authorizeUrl: String
        let clientId: String
        let scope: String
    }

    private func initiateWebSession() async throws -> WebSessionInfo {
        let mutation = """
        mutation { signInWithWebSessionInitiate { clientId scope authorizeUrl } }
        """

        let data = try await executeGraphQL(query: mutation, variables: nil)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let initiate = dataObj["signInWithWebSessionInitiate"] as? [String: Any],
              let authorizeUrl = initiate["authorizeUrl"] as? String,
              let clientId = initiate["clientId"] as? String,
              let scope = initiate["scope"] as? String else {
            throw AuthError.invalidResponse
        }

        return WebSessionInfo(authorizeUrl: authorizeUrl, clientId: clientId, scope: scope)
    }

    // MARK: - Step 2: Browser Auth

    private func openAuthBrowser(authorizeUrl: String, clientId: String, scope: String, codeChallenge: String) async throws -> String {
        let redirectUri = "\(authorizeUrl)/complete"
        let state = UUID().uuidString

        var components = URLComponents(string: authorizeUrl)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_type", value: "top_frame"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]

        guard let authURL = components.url else {
            throw AuthError.invalidResponse
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { url, error in
                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let url else {
                    continuation.resume(throwing: AuthError.invalidResponse)
                    return
                }
                continuation.resume(returning: url)
            }
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = WebAuthPresenter.shared

            DispatchQueue.main.async {
                session.start()
            }
        }

        // Parse the callback URL for the code
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let returnedCode = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            // Check for error
            if let errorMsg = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "error_description" })?.value {
                throw AuthError.serverError(errorMsg)
            }
            throw AuthError.invalidResponse
        }

        // Verify state matches
        let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value
        guard returnedState == state else {
            throw AuthError.serverError("State mismatch — possible CSRF attack.")
        }

        return returnedCode
    }

    // MARK: - Step 3: Complete

    private func completeWebSession(code: String, codeVerifier: String, redirectUri: String) async throws -> StoredTokens {
        let mutation = """
        mutation SignInWithWebSessionComplete($code: String!, $codeVerifier: String!, $redirectUri: String!) {
          signInWithWebSessionComplete(code: $code, codeVerifier: $codeVerifier, redirectUri: $redirectUri) {
            webAuthPayload {
              ... on WebAuthVerified {
                authTokens { accessToken refreshToken expiresIn }
              }
              ... on WebAuthUnverified {
                email
              }
            }
            userErrors { message }
          }
        }
        """

        let variables: [String: Any] = [
            "code": code,
            "codeVerifier": codeVerifier,
            "redirectUri": redirectUri
        ]

        let data = try await executeGraphQL(query: mutation, variables: variables)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let complete = dataObj["signInWithWebSessionComplete"] as? [String: Any] else {
            throw AuthError.invalidResponse
        }

        if let errors = complete["userErrors"] as? [[String: Any]], !errors.isEmpty {
            let msg = errors.compactMap { $0["message"] as? String }.joined(separator: ", ")
            throw AuthError.serverError(msg)
        }

        guard let payload = complete["webAuthPayload"] as? [String: Any] else {
            throw AuthError.invalidResponse
        }

        // Check if verified (has authTokens)
        if let authTokens = payload["authTokens"] as? [String: Any],
           let accessToken = authTokens["accessToken"] as? String,
           let refreshToken = authTokens["refreshToken"] as? String {
            let expiresIn = authTokens["expiresIn"] as? Int ?? 3600
            var tokens = StoredTokens()
            tokens.accessToken = accessToken
            tokens.refreshToken = refreshToken
            tokens.accessTokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            return tokens
        }

        // Unverified — user needs to verify email
        if let email = payload["email"] as? String {
            throw AuthError.serverError("Account not verified. Check \(email) for a verification link.")
        }

        throw AuthError.invalidResponse
    }

    // MARK: - Token Refresh

    private struct RefreshResult {
        let accessToken: String?
        let refreshToken: String?
        let accessTokenExpiry: Date?
    }

    private func refreshAccessToken(refreshToken: String) async throws -> RefreshResult {
        let mutation = """
        mutation RefreshAccessToken($refreshToken: String!) {
          accessTokenRefresh(refreshToken: $refreshToken) {
            authPayload { accessToken refreshToken expiresIn }
            userErrors { message }
          }
        }
        """

        let variables: [String: Any] = ["refreshToken": refreshToken]
        let data = try await executeGraphQL(query: mutation, variables: variables)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let refresh = dataObj["accessTokenRefresh"] as? [String: Any] else {
            throw AuthError.refreshFailed
        }

        if let errors = refresh["userErrors"] as? [[String: Any]], !errors.isEmpty {
            signOut()
            let msg = errors.compactMap { $0["message"] as? String }.joined(separator: ", ")
            throw AuthError.serverError(msg)
        }

        guard let payload = refresh["authPayload"] as? [String: Any],
              let newAccessToken = payload["accessToken"] as? String else {
            throw AuthError.refreshFailed
        }

        let expiresIn = payload["expiresIn"] as? Int ?? 3600
        return RefreshResult(
            accessToken: newAccessToken,
            refreshToken: payload["refreshToken"] as? String,
            accessTokenExpiry: Date().addingTimeInterval(TimeInterval(expiresIn))
        )
    }

    // MARK: - Network

    private func executeGraphQL(query: String, variables: [String: Any]?) async throws -> Data {
        var body: [String: Any] = ["query": query]
        if let variables { body["variables"] = variables }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "User-Agent")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "X-User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw AuthError.httpError(status)
        }
        return data
    }
}

// MARK: - PKCE

private struct PKCE {
    let verifier: String
    let challenge: String

    static func generate() -> PKCE {
        // Generate 32 random bytes as the verifier
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier = Data(bytes).map { String(format: "%02x", $0) }.joined()

        // SHA256 hash → base64url encode
        let hash = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return PKCE(verifier: verifier, challenge: challenge)
    }
}

// MARK: - ASWebAuthenticationSession Presenter

private class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresenter()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Token Storage

private struct StoredTokens {
    var accessToken: String?
    var refreshToken: String?
    var accessTokenExpiry: Date?
    var email: String?

    private static let defaults = UserDefaults.standard
    private enum Key {
        static let accessToken = "ShopAuth_accessToken"
        static let refreshToken = "ShopAuth_refreshToken"
        static let expiry = "ShopAuth_expiry"
        static let email = "ShopAuth_email"
    }

    static func load() -> StoredTokens {
        StoredTokens(
            accessToken: defaults.string(forKey: Key.accessToken),
            refreshToken: defaults.string(forKey: Key.refreshToken),
            accessTokenExpiry: defaults.object(forKey: Key.expiry) as? Date,
            email: defaults.string(forKey: Key.email)
        )
    }

    func save() {
        Self.defaults.set(accessToken, forKey: Key.accessToken)
        Self.defaults.set(refreshToken, forKey: Key.refreshToken)
        Self.defaults.set(accessTokenExpiry, forKey: Key.expiry)
        Self.defaults.set(email, forKey: Key.email)
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidResponse
    case serverError(String)
    case refreshFailed
    case notSignedIn
    case httpError(Int)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Shop Server."
        case .serverError(let msg): return msg
        case .refreshFailed: return "Token refresh failed. Please sign in again."
        case .notSignedIn: return "Not signed in."
        case .httpError(let code): return "HTTP error \(code) from Shop Server."
        case .cancelled: return "Sign-in was cancelled."
        }
    }
}
