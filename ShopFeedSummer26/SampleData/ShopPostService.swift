import Foundation
import Observation

@MainActor
@Observable
final class ShopPostService {
    static let shared = ShopPostService()

    private static let lukeMerchantNames: Set<String> = [
        "forom",
        "standards manual",
        "fellow",
        "ceremonia",
        "moma design store",
        "draw down",
        "extra butter",
    ]

    private(set) var lukePosts: [ShopPost] = []
    private(set) var isLoading = false
    private(set) var error: String?

    private init() {}

    func reset() {
        lukePosts = []
        error = nil
    }

    /// Curated post availability belongs to the data service rather than the
    /// feed view. Future buyer post sets can be added here without branching
    /// HomePage presentation code.
    func posts(for profile: BuyerPreviewProfile) -> [ShopPost] {
        switch profile.id {
        case "luke":
            let prototypes = bundledPrototypePosts
            let prototypeMerchantNames = Set(prototypes.map {
                Self.normalized($0.merchant.name)
            })
            return prototypes + lukePosts.filter {
                !prototypeMerchantNames.contains(Self.normalized($0.merchant.name))
            }
        default:
            return []
        }
    }

    /// User-supplied social media guarantees that both post presentations can
    /// be reviewed even when Shop authentication is absent.
    private var bundledPrototypePosts: [ShopPost] {
        [bundledHouseOfErrorsPost, bundledKithPost].compactMap { $0 }
    }

    private var bundledHouseOfErrorsPost: ShopPost? {
        guard let videoURL = Bundle.main.url(
            forResource: "house-of-errors-post",
            withExtension: "mp4"
        ) else { return nil }

        let posterURL = Bundle.main.url(
            forResource: "house-of-errors-post-poster",
            withExtension: "jpg"
        )
        return ShopPost(
            id: "prototype-house-of-errors-clouds",
            title: "Head in the clouds",
            caption: "A surreal new collection from House of Errors.",
            subtitle: nil,
            media: .video(url: videoURL, posterURL: posterURL, width: 1440, height: 1800),
            merchant: ShopPost.Merchant(
                id: "house-of-errors",
                name: "House of Errors",
                logoURL: nil,
                websiteURL: nil
            ),
            actionURL: nil
        )
    }

    private var bundledKithPost: ShopPost? {
        guard let videoURL = Bundle.main.url(
            forResource: "kith-post",
            withExtension: "mp4"
        ) else { return nil }

        let posterURL = Bundle.main.url(
            forResource: "kith-post-poster",
            withExtension: "jpg"
        )
        return ShopPost(
            id: "prototype-kith-new-layers",
            title: "New season layers",
            caption: "A study in color, texture, and movement from Kith.",
            subtitle: nil,
            media: .video(url: videoURL, posterURL: posterURL, width: 720, height: 1280),
            merchant: ShopPost.Merchant(
                id: "kith",
                name: "Kith",
                logoURL: nil,
                websiteURL: nil
            ),
            productReferences: [
                .init(merchantID: "kith", productID: 8_286_509_564_032),
                .init(merchantID: "kith", productID: 8_286_188_830_848),
                .init(merchantID: "kith", productID: 8_286_188_863_616),
            ],
            actionURL: nil
        )
    }

    func loadLukePosts(force: Bool = false) async {
        guard !isLoading, force || lukePosts.isEmpty else { return }
        guard AuthService.shared.hasSession else { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let authorization = try await AuthService.shared.getAuthorization()
            let client = ShopServerClient(authorization: authorization)

            // Following is the strongest signal for merchant affinity. Home can
            // contain additional personalized PostCards from the same merchants.
            async let following = client.posts(feedID: "following", first: 18)
            async let home = client.posts(feedID: "home", first: 18)
            let (followingPosts, homePosts) = try await (following, home)
            let candidates = followingPosts + homePosts

            var seenPostIDs = Set<String>()
            let uniqueCandidates = candidates
                .filter { seenPostIDs.insert($0.id).inserted }
                .sorted { lhs, rhs in
                    let lhsApproved = Self.lukeMerchantNames.contains(
                        Self.normalized(lhs.merchant.name)
                    )
                    let rhsApproved = Self.lukeMerchantNames.contains(
                        Self.normalized(rhs.merchant.name)
                    )
                    if lhsApproved != rhsApproved { return lhsApproved }
                    if lhs.media.isVideo != rhs.media.isVideo { return lhs.media.isVideo }
                    return lhs.merchant.name.localizedCaseInsensitiveCompare(rhs.merchant.name)
                        == .orderedAscending
                }

            // A live feed should not become a run of posts from one shop. Keep
            // one strong post per merchant, preferring Luke's approved shops
            // while allowing the personalized Home response to fill gaps.
            var seenMerchantNames = Set<String>()
            lukePosts = uniqueCandidates.filter {
                seenMerchantNames.insert(Self.normalized($0.merchant.name)).inserted
            }
#if DEBUG
            print("ShopPostService: \(candidates.count) PostCards, \(lukePosts.count) approved Luke matches")
#endif
        } catch {
            self.error = error.localizedDescription
#if DEBUG
            print("ShopPostService error: \(error.localizedDescription)")
#endif
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
