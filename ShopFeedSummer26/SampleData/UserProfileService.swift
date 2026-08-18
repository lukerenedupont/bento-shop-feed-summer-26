import SwiftUI

enum BuyerShelfEvidence: String, Hashable {
    /// Directly supported by supplied profile, search, view, or purchase data.
    case observed
    /// A restrained adjacency derived from an observed taste or owned item.
    case adjacent
    /// Broad exploration used when the profile has little trustworthy data.
    case discovery
}

struct BuyerFeedShelf: Hashable {
    let categoryID: String
    let storyIDs: [String]
    let evidence: BuyerShelfEvidence
}

struct BuyerUtilityConfiguration: Hashable {
    let buyAgainStoryID: String?
    let recentlyViewedStoryID: String?
    let ownedAdjacencyStoryID: String?
    let showsCart: Bool
    let showsOrders: Bool

    var isVisible: Bool {
        buyAgainStoryID != nil
            || recentlyViewedStoryID != nil
            || ownedAdjacencyStoryID != nil
            || showsCart
            || showsOrders
    }

    static let fullPrototype = BuyerUtilityConfiguration(
        buyAgainStoryID: "",
        recentlyViewedStoryID: "",
        ownedAdjacencyStoryID: nil,
        showsCart: true,
        showsOrders: true
    )

    static let none = BuyerUtilityConfiguration(
        buyAgainStoryID: nil,
        recentlyViewedStoryID: nil,
        ownedAdjacencyStoryID: nil,
        showsCart: false,
        showsOrders: false
    )
}

/// Prototype-only cohort fixture. Every curated shelf states its evidence
/// level so weak profiles can remain discovery-led instead of presenting
/// invented purchase history as personalization.
struct BuyerPreviewProfile: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let accentHex: String
    let avatarAssetName: String?
    let shelves: [BuyerFeedShelf]
    let utility: BuyerUtilityConfiguration

    var showsUtilityShelf: Bool { utility.isVisible }
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
            avatarAssetName: "luke-avatar",
            shelves: [],
            utility: .fullPrototype
        ),
        BuyerPreviewProfile(
            id: "tobi",
            name: "Tobi",
            symbol: "T",
            accentHex: "#5C54DF",
            avatarAssetName: "tobi-avatar",
            shelves: [
                .init(categoryID: "for-you", storyIDs: [
                    "tobi-xbloom-system", "tobi-coffee-creatine",
                    "tobi-manmade-basics", "tobi-wet-shave", "tobi-sim-racing",
                    "edit-studio-in-a-bag", "edit-gloriously-lost",
                ], evidence: .observed),
                .init(categoryID: "living", storyIDs: [
                    "tobi-xbloom-system", "edit-stay-a-while", "edit-table-as-a-scene",
                ], evidence: .adjacent),
                .init(categoryID: "design", storyIDs: [
                    "tobi-sim-racing", "tobi-xbloom-system",
                    "edit-studio-in-a-bag", "edit-design-shelf",
                ], evidence: .observed),
                .init(categoryID: "style", storyIDs: [
                    "tobi-manmade-basics", "edit-salomons-to-know",
                ], evidence: .observed),
                .init(categoryID: "wellness", storyIDs: [
                    "tobi-coffee-creatine", "tobi-wet-shave", "edit-wash-day-reset",
                ], evidence: .observed),
                .init(categoryID: "morning", storyIDs: [
                    "tobi-coffee-creatine", "tobi-xbloom-system", "tobi-wet-shave",
                ], evidence: .observed),
                .init(categoryID: "outdoors", storyIDs: [
                    "edit-gloriously-lost", "edit-salomons-to-know",
                ], evidence: .discovery),
            ],
            utility: .init(
                buyAgainStoryID: "tobi-coffee-creatine",
                recentlyViewedStoryID: "tobi-xbloom-system",
                ownedAdjacencyStoryID: nil,
                showsCart: false,
                showsOrders: false
            )
        ),
        BuyerPreviewProfile(
            id: "katarina",
            name: "Katarina",
            symbol: "K",
            accentHex: "#29262D",
            avatarAssetName: "katarina-avatar",
            shelves: [
                .init(categoryID: "for-you", storyIDs: [
                    "katarina-rick-owens", "katarina-silver",
                    "katarina-rhode-routine", "katarina-black-swim",
                    "edit-design-shelf", "edit-coffee-worth-waking-for",
                    "edit-zero-beige-energy",
                ], evidence: .observed),
                .init(categoryID: "living", storyIDs: [
                    "edit-stay-a-while", "edit-mirrors-with-presence",
                    "edit-table-as-a-scene", "edit-zero-beige-energy",
                ], evidence: .adjacent),
                .init(categoryID: "design", storyIDs: [
                    "edit-design-shelf", "edit-zero-beige-energy",
                    "edit-studio-in-a-bag",
                ], evidence: .observed),
                .init(categoryID: "style", storyIDs: [
                    "katarina-rick-owens", "katarina-silver",
                    "katarina-black-swim", "edit-salomons-to-know",
                ], evidence: .observed),
                .init(categoryID: "wellness", storyIDs: [
                    "katarina-rhode-routine", "edit-wash-day-reset",
                ], evidence: .observed),
                .init(categoryID: "morning", storyIDs: [
                    "edit-coffee-worth-waking-for", "katarina-rhode-routine",
                ], evidence: .adjacent),
                .init(categoryID: "outdoors", storyIDs: [
                    "edit-salomons-to-know", "edit-gloriously-lost",
                ], evidence: .discovery),
            ],
            utility: .init(
                buyAgainStoryID: nil,
                recentlyViewedStoryID: "katarina-rick-owens",
                ownedAdjacencyStoryID: nil,
                showsCart: false,
                showsOrders: false
            )
        ),
        BuyerPreviewProfile(
            id: "kenny",
            name: "Kenny",
            symbol: "K",
            accentHex: "#C47732",
            avatarAssetName: "kenny-avatar",
            shelves: [
                .init(categoryID: "for-you", storyIDs: [
                    "edit-gloriously-lost", "edit-table-as-a-scene",
                    "edit-stay-a-while", "edit-coffee-worth-waking-for",
                    "edit-salomons-to-know", "edit-design-shelf",
                    "edit-wash-day-reset",
                ], evidence: .discovery),
            ],
            utility: .none
        ),
        BuyerPreviewProfile(
            id: "andreas",
            name: "Andreas",
            symbol: "A",
            accentHex: "#4E6651",
            avatarAssetName: "andreas-avatar",
            shelves: [
                .init(categoryID: "for-you", storyIDs: [
                    "andreas-glass-hair", "andreas-smooth-blowout",
                    "andreas-minimal-comfort", "andreas-macbook-kit",
                    "edit-design-shelf", "edit-stay-a-while",
                ], evidence: .observed),
                .init(categoryID: "living", storyIDs: [
                    "edit-stay-a-while", "edit-mirrors-with-presence",
                    "edit-table-as-a-scene",
                ], evidence: .adjacent),
                .init(categoryID: "design", storyIDs: [
                    "andreas-macbook-kit", "edit-design-shelf",
                    "edit-zero-beige-energy",
                ], evidence: .adjacent),
                .init(categoryID: "style", storyIDs: [
                    "andreas-minimal-comfort", "edit-salomons-to-know",
                ], evidence: .observed),
                .init(categoryID: "wellness", storyIDs: [
                    "andreas-glass-hair", "andreas-smooth-blowout",
                    "edit-wash-day-reset",
                ], evidence: .observed),
                .init(categoryID: "morning", storyIDs: [
                    "andreas-smooth-blowout", "edit-coffee-worth-waking-for",
                ], evidence: .adjacent),
                .init(categoryID: "outdoors", storyIDs: [
                    "edit-salomons-to-know", "edit-gloriously-lost",
                ], evidence: .discovery),
            ],
            utility: .init(
                buyAgainStoryID: nil,
                recentlyViewedStoryID: "andreas-glass-hair",
                ownedAdjacencyStoryID: "andreas-macbook-kit",
                showsCart: false,
                showsOrders: false
            )
        ),
        BuyerPreviewProfile(
            id: "archie",
            name: "Archie",
            symbol: "A",
            accentHex: "#334D59",
            avatarAssetName: "archie-avatar",
            shelves: [
                .init(categoryID: "for-you", storyIDs: [
                    "edit-design-shelf", "edit-gloriously-lost",
                    "edit-stay-a-while", "edit-table-as-a-scene",
                    "edit-coffee-worth-waking-for", "edit-salomons-to-know",
                    "edit-wash-day-reset",
                ], evidence: .discovery),
            ],
            utility: .none
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

    func stories(
        for category: FeedCategory,
        in catalog: PersonalizedFeedCatalog
    ) -> [FeedStory] {
        if let shelf = selected.shelves.first(where: { $0.categoryID == category.id }) {
            let byID = Dictionary(uniqueKeysWithValues: catalog.stories.map { ($0.id, $0) })
            let resolved = shelf.storyIDs.compactMap { byID[$0] }
            if !resolved.isEmpty { return resolved }
        }
        return FeedInformationArchitecture.stories(for: category, in: catalog)
    }
}

struct BuyerPreviewAvatar: View {
    let profile: BuyerPreviewProfile
    let size: CGFloat

    var body: some View {
        if let avatarAssetName = profile.avatarAssetName {
            Image(avatarAssetName)
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
