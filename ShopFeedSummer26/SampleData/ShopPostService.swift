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
        case "luke": lukePosts
        default: []
        }
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

            var seen = Set<String>()
            lukePosts = candidates
                .filter { Self.lukeMerchantNames.contains(Self.normalized($0.merchant.name)) }
                .filter { seen.insert($0.id).inserted }
                .sorted { lhs, rhs in
                    if lhs.media.isVideo != rhs.media.isVideo { return lhs.media.isVideo }
                    return lhs.merchant.name.localizedCaseInsensitiveCompare(rhs.merchant.name) == .orderedAscending
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
