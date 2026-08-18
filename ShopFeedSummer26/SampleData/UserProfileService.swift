import SwiftUI

/// Prototype-only cohort fixture. These profiles exercise the hypothesis
/// pipeline without impersonating a Shop account or claiming private history.
struct BuyerPreviewProfile: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let accentHex: String
    let storyOrder: [String]
    let titleOverrides: [String: String]
}

@Observable
@MainActor
final class BuyerPreviewStore {
    static let shared = BuyerPreviewStore()

    static let profiles: [BuyerPreviewProfile] = [
        BuyerPreviewProfile(
            id: "luke",
            name: "Luke Dupont",
            symbol: "🛍️",
            accentHex: "#6657E8",
            storyOrder: [],
            titleOverrides: [:]
        ),
        BuyerPreviewProfile(
            id: "tobi",
            name: "Tobi",
            symbol: "T",
            accentHex: "#5C54DF",
            storyOrder: [
                "edit-studio-in-a-bag", "edit-coffee-worth-waking-for",
                "edit-zero-beige-energy", "edit-salomons-to-know",
                "edit-wash-day-reset", "edit-design-shelf",
                "edit-gloriously-lost", "edit-table-as-a-scene",
                "edit-stay-a-while", "edit-mirrors-with-presence",
                "edit-grow-with-them"
            ],
            titleOverrides: [
                "edit-studio-in-a-bag": "The setup around the machine",
                "edit-coffee-worth-waking-for": "Coffee and creatine, on cadence",
                "edit-zero-beige-energy": "Tools for the project builder",
                "edit-salomons-to-know": "Technical gear with everyday range",
                "edit-wash-day-reset": "A better daily ritual"
            ]
        ),
        BuyerPreviewProfile(
            id: "katarina",
            name: "Katarina",
            symbol: "K",
            accentHex: "#29262D",
            storyOrder: [
                "edit-zero-beige-energy", "edit-studio-in-a-bag",
                "edit-wash-day-reset", "edit-design-shelf",
                "edit-coffee-worth-waking-for", "edit-table-as-a-scene",
                "edit-salomons-to-know", "edit-mirrors-with-presence",
                "edit-stay-a-while", "edit-gloriously-lost",
                "edit-grow-with-them"
            ],
            titleOverrides: [
                "edit-zero-beige-energy": "Black, silver, and anything but basic",
                "edit-studio-in-a-bag": "A sharper everyday carry",
                "edit-wash-day-reset": "Skincare that earns its space",
                "edit-design-shelf": "Monographs for the permanent stack",
                "edit-coffee-worth-waking-for": "Coffee tools with design credibility"
            ]
        ),
        BuyerPreviewProfile(
            id: "kenny",
            name: "Kenny",
            symbol: "K",
            accentHex: "#C47732",
            storyOrder: [
                "edit-gloriously-lost", "edit-table-as-a-scene",
                "edit-stay-a-while", "edit-coffee-worth-waking-for",
                "edit-salomons-to-know", "edit-mirrors-with-presence",
                "edit-design-shelf", "edit-zero-beige-energy",
                "edit-studio-in-a-bag", "edit-wash-day-reset",
                "edit-grow-with-them"
            ],
            titleOverrides: [
                "edit-gloriously-lost": "The field kit that keeps getting better",
                "edit-table-as-a-scene": "Good objects for slow weekends",
                "edit-stay-a-while": "A room you actually want to stay in",
                "edit-coffee-worth-waking-for": "The morning ritual, upgraded",
                "edit-salomons-to-know": "Trail gear that still works in the city"
            ]
        )
    ]

    private(set) var selectedID: String

    var selected: BuyerPreviewProfile {
        Self.profiles.first(where: { $0.id == selectedID }) ?? Self.profiles[0]
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "buyerPreviewProfileID")
        selectedID = Self.profiles.contains(where: { $0.id == saved }) ? saved! : "luke"
    }

    func select(_ profile: BuyerPreviewProfile) {
        selectedID = profile.id
        UserDefaults.standard.set(profile.id, forKey: "buyerPreviewProfileID")
    }

    func orderedStories(_ stories: [FeedStory]) -> [FeedStory] {
        guard !selected.storyOrder.isEmpty else { return stories }
        let rank = Dictionary(uniqueKeysWithValues: selected.storyOrder.enumerated().map { ($1, $0) })
        return stories.enumerated().sorted { lhs, rhs in
            let left = rank[lhs.element.id] ?? selected.storyOrder.count + lhs.offset
            let right = rank[rhs.element.id] ?? selected.storyOrder.count + rhs.offset
            return left < right
        }.map(\.element)
    }

    func title(for story: FeedStory) -> String? {
        selected.titleOverrides[story.id]
    }
}

struct BuyerPreviewAvatar: View {
    let profile: BuyerPreviewProfile
    let size: CGFloat

    var body: some View {
        if profile.id == "luke" {
            Image("luke-avatar")
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(hex: profile.accentHex))
                .overlay {
                    Text(profile.symbol)
                        .font(.system(size: size * 0.46, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: size, height: size)
        }
    }
}

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
