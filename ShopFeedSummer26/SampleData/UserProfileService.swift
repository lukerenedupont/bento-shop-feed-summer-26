import SwiftUI

enum BuyerShelfEvidence: String, Hashable {
    /// Directly supported by supplied profile, search, view, or purchase data.
    case observed
    /// A restrained adjacency derived from an observed taste or owned item.
    case adjacent
    /// Broad exploration used when the profile has little trustworthy data.
    case discovery
}

/// One buyer-specific top-level tab and the exact shelf it opens. Keeping the
/// label and destination together prevents personalized navigation from
/// drifting back onto the shared global taxonomy.
struct BuyerFeedTopic: Identifiable, Hashable {
    let id: String
    let label: String
    /// Supplies the existing product-layout rhythm for this personalized tab.
    let sourceCategoryID: String
    let storyIDs: [String]
    let evidence: BuyerShelfEvidence

    init(
        id: String,
        label: String,
        sourceCategoryID: String? = nil,
        storyIDs: [String],
        evidence: BuyerShelfEvidence
    ) {
        self.id = id
        self.label = label
        self.sourceCategoryID = sourceCategoryID ?? id
        self.storyIDs = storyIDs
        self.evidence = evidence
    }
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
    let topics: [BuyerFeedTopic]
    let utility: BuyerUtilityConfiguration

    var showsUtilityShelf: Bool { utility.isVisible }
    /// Personalized topics can stay inside Home while preserving their
    /// sibling rail and buyer context. Legacy fallback profiles have no
    /// authored topics and continue through the shared route stack.
    var usesInlineTopicNavigation: Bool { !topics.isEmpty }
}

@Observable
@MainActor
final class BuyerPreviewStore {
    static let shared = BuyerPreviewStore()

    static let legacyProfiles: [BuyerPreviewProfile] = [
        BuyerPreviewProfile(
            id: "luke",
            name: "Luke Dupont",
            symbol: "🛍️",
            accentHex: "#6657E8",
            avatarAssetName: "luke-avatar",
            topics: [],
            utility: .fullPrototype
        ),
        BuyerPreviewProfile(
            id: "tobi",
            name: "Tobi",
            symbol: "T",
            accentHex: "#5C54DF",
            avatarAssetName: "tobi-avatar",
            topics: [
                .init(id: "for-you", label: "For you", storyIDs: [
                    "tobi-xbloom-system", "tobi-coffee-creatine",
                    "tobi-manmade-basics", "edit-studio-in-a-bag",
                    "tobi-wet-shave", "edit-gloriously-lost",
                    "tobi-sim-racing",
                ], evidence: .observed),
                .init(id: "coffee", label: "Coffee", sourceCategoryID: "morning", storyIDs: [
                    "tobi-xbloom-system", "tobi-coffee-creatine",
                    "edit-coffee-worth-waking-for",
                ], evidence: .observed),
                .init(id: "training", label: "Training", sourceCategoryID: "wellness", storyIDs: [
                    "tobi-coffee-creatine", "edit-gloriously-lost",
                    "edit-salomons-to-know",
                ], evidence: .adjacent),
                .init(id: "essentials", label: "Essentials", sourceCategoryID: "style", storyIDs: [
                    "tobi-manmade-basics", "edit-studio-in-a-bag",
                    "edit-salomons-to-know",
                ], evidence: .observed),
                .init(id: "grooming", label: "Grooming", sourceCategoryID: "wellness", storyIDs: [
                    "tobi-wet-shave", "edit-wash-day-reset",
                ], evidence: .observed),
                .init(id: "sim-racing", label: "Sim racing", sourceCategoryID: "design", storyIDs: [
                    "tobi-sim-racing", "edit-studio-in-a-bag", "edit-design-shelf",
                ], evidence: .observed),
                .init(id: "outdoors", label: "Outdoors", storyIDs: [
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
            topics: [
                .init(id: "for-you", label: "For you", storyIDs: [
                    "katarina-rick-owens", "edit-design-shelf",
                    "katarina-silver", "edit-coffee-worth-waking-for",
                    "katarina-rhode-routine", "edit-zero-beige-energy",
                    "katarina-black-swim",
                ], evidence: .observed),
                .init(id: "style", label: "Style", storyIDs: [
                    "katarina-rick-owens", "edit-salomons-to-know",
                    "katarina-silver", "edit-zero-beige-energy",
                    "katarina-black-swim",
                ], evidence: .observed),
                .init(id: "jewelry", label: "Jewelry", sourceCategoryID: "style", storyIDs: [
                    "katarina-silver", "edit-zero-beige-energy",
                    "katarina-rick-owens",
                ], evidence: .observed),
                .init(id: "swim", label: "Swim", sourceCategoryID: "style", storyIDs: [
                    "katarina-black-swim", "edit-salomons-to-know",
                    "katarina-rick-owens",
                ], evidence: .observed),
                .init(id: "skin", label: "Skin", sourceCategoryID: "wellness", storyIDs: [
                    "katarina-rhode-routine", "edit-wash-day-reset",
                ], evidence: .observed),
                .init(id: "design", label: "Design", storyIDs: [
                    "edit-design-shelf", "edit-zero-beige-energy",
                    "edit-studio-in-a-bag",
                ], evidence: .observed),
                .init(id: "living", label: "Living", storyIDs: [
                    "edit-stay-a-while", "edit-mirrors-with-presence",
                    "edit-table-as-a-scene", "edit-zero-beige-energy",
                ], evidence: .adjacent),
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
            topics: [
                .init(id: "for-you", label: "For you", storyIDs: [
                    "edit-gloriously-lost", "discovery-nocs-field-kit",
                    "edit-table-as-a-scene", "discovery-house-of-leon-reading-room",
                    "edit-coffee-worth-waking-for", "discovery-fellow-coffee-workflow",
                    "edit-design-shelf",
                ], evidence: .discovery),
                .init(id: "outdoors", label: "Outdoors", storyIDs: [
                    "edit-gloriously-lost", "discovery-nocs-field-kit",
                    "edit-salomons-to-know",
                ], evidence: .discovery),
                .init(id: "living", label: "Living", storyIDs: [
                    "edit-table-as-a-scene", "discovery-house-of-leon-reading-room",
                    "edit-stay-a-while", "edit-mirrors-with-presence",
                ], evidence: .discovery),
                .init(id: "morning", label: "Morning", storyIDs: [
                    "edit-coffee-worth-waking-for", "discovery-fellow-coffee-workflow",
                    "edit-table-as-a-scene",
                ], evidence: .discovery),
                .init(id: "design", label: "Design", storyIDs: [
                    "edit-design-shelf", "discovery-draw-down-type-books",
                    "edit-studio-in-a-bag",
                ], evidence: .discovery),
                .init(id: "style", label: "Style", storyIDs: [
                    "edit-salomons-to-know", "edit-zero-beige-energy",
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
            topics: [
                .init(id: "for-you", label: "For you", storyIDs: [
                    "andreas-glass-hair", "andreas-minimal-comfort",
                    "andreas-smooth-blowout", "andreas-lange-routine",
                    "andreas-macbook-kit", "edit-stay-a-while",
                ], evidence: .observed),
                .init(id: "hair-care", label: "Hair care", sourceCategoryID: "wellness", storyIDs: [
                    "andreas-glass-hair", "andreas-lange-routine",
                    "andreas-smooth-blowout", "edit-wash-day-reset",
                ], evidence: .observed),
                .init(id: "blowouts", label: "Blowouts", sourceCategoryID: "wellness", storyIDs: [
                    "andreas-smooth-blowout", "andreas-lange-routine",
                    "andreas-glass-hair", "edit-wash-day-reset",
                ], evidence: .observed),
                .init(id: "mac-setup", label: "Mac setup", sourceCategoryID: "design", storyIDs: [
                    "andreas-macbook-kit", "edit-studio-in-a-bag",
                    "edit-design-shelf",
                ], evidence: .adjacent),
                .init(id: "comfort", label: "Comfort", sourceCategoryID: "style", storyIDs: [
                    "andreas-minimal-comfort", "edit-studio-in-a-bag",
                ], evidence: .observed),
                .init(id: "design", label: "Design", storyIDs: [
                    "andreas-macbook-kit", "edit-design-shelf",
                    "edit-zero-beige-energy",
                ], evidence: .adjacent),
                .init(id: "living", label: "Living", storyIDs: [
                    "edit-stay-a-while", "edit-mirrors-with-presence",
                    "edit-table-as-a-scene",
                ], evidence: .adjacent),
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
            id: "kyle",
            name: "Kyle",
            symbol: "K",
            accentHex: "#74594D",
            avatarAssetName: "kyle-avatar",
            topics: [
                .init(id: "for-you", label: "For you", storyIDs: [
                    "kyle-1890-collabs", "edit-zero-beige-energy",
                    "kyle-argizari-lighting", "edit-design-shelf",
                    "kyle-braided-bostons", "edit-salomons-to-know",
                    "kyle-magma-suede",
                ], evidence: .observed),
                .init(id: "collabs", label: "Collabs", sourceCategoryID: "style", storyIDs: [
                    "kyle-1890-collabs", "edit-zero-beige-energy",
                    "kyle-braided-bostons",
                ], evidence: .observed),
                .init(id: "birkenstock", label: "Birkenstock", sourceCategoryID: "style", storyIDs: [
                    "kyle-braided-bostons",
                ], evidence: .observed),
                .init(id: "1890s", label: "1890s", sourceCategoryID: "style", storyIDs: [
                    "kyle-1890-collabs",
                ], evidence: .observed),
                .init(id: "lighting", label: "Lighting", sourceCategoryID: "living", storyIDs: [
                    "kyle-argizari-lighting",
                ], evidence: .observed),
                .init(id: "kith", label: "Kith", sourceCategoryID: "style", storyIDs: [
                    "kyle-magma-suede", "kyle-braided-bostons",
                    "edit-zero-beige-energy", "kyle-1890-collabs",
                ], evidence: .observed),
            ],
            utility: .init(
                buyAgainStoryID: nil,
                recentlyViewedStoryID: "kyle-magma-suede",
                ownedAdjacencyStoryID: nil,
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
            topics: [
                .init(id: "for-you", label: "For you", storyIDs: [
                    "edit-design-shelf", "discovery-draw-down-type-books",
                    "edit-stay-a-while", "discovery-house-of-leon-reading-room",
                    "edit-gloriously-lost", "discovery-nocs-field-kit",
                    "edit-table-as-a-scene",
                ], evidence: .discovery),
                .init(id: "design", label: "Design", storyIDs: [
                    "edit-design-shelf", "discovery-draw-down-type-books",
                    "edit-studio-in-a-bag", "edit-zero-beige-energy",
                ], evidence: .discovery),
                .init(id: "living", label: "Living", storyIDs: [
                    "edit-stay-a-while", "discovery-house-of-leon-reading-room",
                    "edit-table-as-a-scene", "edit-mirrors-with-presence",
                ], evidence: .discovery),
                .init(id: "outdoors", label: "Outdoors", storyIDs: [
                    "edit-gloriously-lost", "discovery-nocs-field-kit",
                    "edit-salomons-to-know",
                ], evidence: .discovery),
                .init(id: "style", label: "Style", storyIDs: [
                    "edit-salomons-to-know", "edit-zero-beige-energy",
                ], evidence: .discovery),
                .init(id: "wellness", label: "Wellness", storyIDs: [
                    "edit-wash-day-reset", "edit-stay-a-while",
                ], evidence: .discovery),
            ],
            utility: .none
        )
    ]

    static let profiles: [BuyerPreviewProfile] = HypothesisShelfCatalog.profiles

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

    var navigationTopics: [BuyerFeedTopic] {
        if !selected.topics.isEmpty { return selected.topics }
        return FeedInformationArchitecture.categories.map { category in
            BuyerFeedTopic(
                id: category.id,
                label: category.label,
                storyIDs: [],
                evidence: .discovery
            )
        }
    }

    func stories(
        for topic: BuyerFeedTopic,
        in catalog: PersonalizedFeedCatalog
    ) -> [FeedStory] {
        let byID = Dictionary(uniqueKeysWithValues: catalog.stories.map { ($0.id, $0) })
        let resolved = topic.storyIDs.compactMap { byID[$0] }
        if !resolved.isEmpty { return resolved }

        let sourceCategory = FeedInformationArchitecture.categories.first {
            $0.id == topic.sourceCategoryID
        } ?? FeedInformationArchitecture.categories[0]
        return FeedInformationArchitecture.stories(for: sourceCategory, in: catalog)
    }

    /// Validates the complete preview cohort, not only the buyer currently on
    /// screen. The prototype intentionally keeps buyer fixtures in Swift, so
    /// this closes the gap left by the JSON feed validator and prevents a
    /// renamed story or removed catalog product from silently emptying a tab.
    static func validationIssues(
        in catalog: PersonalizedFeedCatalog,
        merchants: [SampleMerchant]
    ) -> [String] {
        let storiesByID = Dictionary(uniqueKeysWithValues: catalog.stories.map { ($0.id, $0) })
        let merchantsByID = Dictionary(uniqueKeysWithValues: merchants.map { ($0.id, $0) })
        var issues: [String] = []

        for profile in profiles where !profile.topics.isEmpty {
            let topicIDs = profile.topics.map(\.id)
            if topicIDs.first != "for-you" {
                issues.append("\(profile.id): first topic must be for-you")
            }
            if Set(topicIDs).count != topicIDs.count {
                issues.append("\(profile.id): topic IDs must be unique")
            }

            for topic in profile.topics {
                if topic.storyIDs.isEmpty {
                    issues.append("\(profile.id)/\(topic.id): topic has no stories")
                }
                if Set(topic.storyIDs).count != topic.storyIDs.count {
                    issues.append("\(profile.id)/\(topic.id): story IDs must not repeat")
                }
                for storyID in topic.storyIDs where storiesByID[storyID] == nil {
                    issues.append("\(profile.id)/\(topic.id): unknown story \(storyID)")
                }

            }

            let utilityStoryIDs = [
                profile.utility.buyAgainStoryID,
                profile.utility.recentlyViewedStoryID,
                profile.utility.ownedAdjacencyStoryID,
            ].compactMap { $0 }.filter { !$0.isEmpty }
            for storyID in utilityStoryIDs where storiesByID[storyID] == nil {
                issues.append("\(profile.id): utility references unknown story \(storyID)")
            }
        }

        let buyerStoryIDs = Set(
            profiles.flatMap { profile in
                profile.topics.flatMap(\.storyIDs)
            }
        )
        for storyID in buyerStoryIDs {
            guard let story = storiesByID[storyID] else { continue }
            for reference in story.products {
                guard let merchant = merchantsByID[reference.merchantID] else {
                    issues.append("\(storyID): unknown merchant \(reference.merchantID)")
                    continue
                }
                if !merchant.products.contains(where: { $0.id == reference.productID }) {
                    issues.append(
                        "\(storyID): unknown product \(reference.merchantID)/\(reference.productID)"
                    )
                }
            }
        }

        return issues.sorted()
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
