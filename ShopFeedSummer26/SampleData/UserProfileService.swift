import Foundation

/// Fetches the authenticated user's profile from Shop Server.
/// Falls back to "Shop prototype" if unauthenticated or on error.
@Observable
@MainActor
final class UserProfileService {
    static let shared = UserProfileService()

    var firstName: String?
    var lastName: String?
    var avatarURL: URL?
    var isLoaded: Bool = false

    /// Display name: authenticated user's full name or fallback.
    var displayName: String {
        switch (firstName, lastName) {
        case let (first?, last?):
            return "\(first) \(last)"
        case let (first?, nil):
            return first
        default:
            return fallbackName
        }
    }

    /// First letter for the avatar circle.
    var initial: String {
        String(displayName.prefix(1)).uppercased()
    }

    /// Name used when no live profile is available.
    private var fallbackName = "Luke Dupont"

    /// Avatar shown when no live profile is available (bundled asset or SF Symbol).
    var fallbackAvatarSystemName: String? {
        avatarURL == nil ? "person.crop.circle.fill" : nil
    }

    /// Call this to apply a sample-data profile when running without a token.
    func applyFallbackProfile(name: String = "Luke Dupont") {
        firstName = nil
        lastName = nil
        avatarURL = nil
        fallbackName = name
        isLoaded = true
    }

    private init() {
        Task { await fetch() }
    }

    func fetch() async {
        guard AuthService.shared.hasSession,
              let authorization = try? await AuthService.shared.getAuthorization() else {
            isLoaded = true
            return
        }

        let query = """
        {"query":"{ currentUser { firstName lastName email avatar { image { url(maxWidth: 128) } } } }"}
        """

        var request = URLRequest(url: URL(string: "https://server.shop.app/graphql")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "User-Agent")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "X-User-Agent")
        request.httpBody = query.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                isLoaded = true
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any],
               let user = dataObj["currentUser"] as? [String: Any] {
                firstName = user["firstName"] as? String
                lastName = user["lastName"] as? String
                if let avatar = user["avatar"] as? [String: Any],
                   let image = avatar["image"] as? [String: Any],
                   let urlStr = image["url"] as? String {
                    avatarURL = URL(string: urlStr)
                }
            }
        } catch {
            // Silent fail — use fallback
        }

        isLoaded = true
    }
}
