import Combine
import Foundation

/// Loads Home from the cloned `dossier-feed-bundle` snapshot, or from the
/// dossier-lab HTTP API when `baseURL` is overridden with an http(s) origin.
///
/// Both sources emit the two shapes this app already decodes —
/// `PersonalizedFeedCatalog` and the merchant snapshot read by
/// `LocalMerchantService` — so switching sources does not change view models.
///
/// Anything that fails (server down, phone on another network, malformed
/// payload) leaves the bundled assets in place: the prototype always opens.
@MainActor
final class RemoteFeedService: ObservableObject {
    static let shared = RemoteFeedService()

    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var isLive = false
    /// Merchants from the feed API. Empty until a successful load.
    @Published private(set) var merchants: [SampleMerchant] = []
    /// Bumped on every successful load. `SampleMerchant` is not `Equatable`, so
    /// views observe this instead to react to a refreshed assortment.
    @Published private(set) var revision = 0

    /// The checked-out frozen feed is the simulator default. Override the same
    /// UserDefaults key with an http(s) origin to use dossier-lab again.
    static let defaultBaseURL = "bundle://dossier-feed"
    private static let baseURLKey = "dossierLabFeedBaseURL"

    var baseURL: String {
        get {
            let saved = UserDefaults.standard.string(forKey: Self.baseURLKey)
            // Migrate installs that inherited the prototype's former default.
            if saved == "http://localhost:4100" { return Self.defaultBaseURL }
            return saved ?? Self.defaultBaseURL
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.baseURLKey) }
    }

    private init() {}

    func load(force: Bool = false) async {
        guard !isLoading else { return }
        guard force || !isLive else { return }

        isLoading = true
        error = nil

        do {
            let origin = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let sourceURL = URL(string: origin) else {
                throw FeedServiceError.badBaseURL(baseURL)
            }

            let feedData: Data
            let merchantData: Data
            if sourceURL.scheme == "bundle" {
                guard let directory = Bundle.main.url(forResource: "bundle", withExtension: nil) else {
                    throw FeedServiceError.missingSnapshot
                }
                let rawFeed = try Data(contentsOf: directory.appendingPathComponent("feed.json"))
                let rawMerchants = try Data(contentsOf: directory.appendingPathComponent("merchants.json"))
                feedData = Self.localised(rawFeed, in: directory)
                merchantData = Self.localised(rawMerchants, in: directory)
            } else if sourceURL.isFileURL {
                let rawFeed = try Data(contentsOf: sourceURL.appendingPathComponent("feed.json"))
                let rawMerchants = try Data(contentsOf: sourceURL.appendingPathComponent("merchants.json"))
                feedData = Self.localised(rawFeed, in: sourceURL)
                merchantData = Self.localised(rawMerchants, in: sourceURL)
            } else {
                guard let feedURL = URL(string: "\(origin)/api/shop/feed"),
                      let merchantsURL = URL(string: "\(origin)/api/shop/merchants") else {
                    throw FeedServiceError.badBaseURL(baseURL)
                }
                async let fetchedFeed = Self.fetch(feedURL)
                async let fetchedMerchants = Self.fetch(merchantsURL)
                feedData = try await fetchedFeed
                merchantData = try await fetchedMerchants
            }

            let catalog = try JSONDecoder().decode(PersonalizedFeedCatalog.self, from: feedData)
            let loaded = LocalMerchantService.decodeMerchants(from: merchantData)

            // A catalog with no topics would crash HomePage, which force-indexes
            // topics[0]; an empty merchant list would render every story blank.
            guard !catalog.topics.isEmpty, !loaded.isEmpty else {
                throw FeedServiceError.emptyResult
            }

            PersonalizedFeedCatalog.remote = catalog
            merchants = loaded
            isLive = true
            revision += 1
        } catch {
            self.error = error.localizedDescription
            isLive = false
        }

        isLoading = false
    }

    /// Drop back to the bundled assets.
    func useBundledFeed() {
        PersonalizedFeedCatalog.remote = nil
        merchants = []
        isLive = false
        error = nil
    }

    /// Absolutise the snapshot's `media/...` values once, at its decoding
    /// boundary. Existing image and AVPlayer call sites then receive file URLs.
    private static func localised(_ data: Data, in directory: URL) -> Data {
        let base = directory.absoluteString.hasSuffix("/")
            ? directory.absoluteString
            : directory.absoluteString + "/"
        return Data(
            String(decoding: data, as: UTF8.self)
                .replacingOccurrences(of: "\"media/", with: "\"\(base)media/")
                .utf8
        )
    }

    private static func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FeedServiceError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }
}

private enum FeedServiceError: LocalizedError {
    case badBaseURL(String)
    case badStatus(Int)
    case emptyResult
    case missingSnapshot

    var errorDescription: String? {
        switch self {
        case .badBaseURL(let value):
            return "“\(value)” is not a valid feed URL."
        case .badStatus(let code):
            return "The feed server answered \(code). Is dossier-lab running?"
        case .emptyResult:
            return "The feed source returned no stories."
        case .missingSnapshot:
            return "The dossier feed snapshot is missing from the app bundle."
        }
    }
}
