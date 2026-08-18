import Foundation

/// A merchant-authored Shop Post returned by the authenticated Shop feed.
/// This intentionally stays separate from product and ambient merchant video:
/// only a server `PostCard` can create one of these models.
struct ShopPost: Identifiable, Hashable {
    enum Media: Hashable {
        case image(url: URL, width: Int?, height: Int?)
        case video(url: URL, posterURL: URL?, width: Int?, height: Int?)

        var previewURL: URL? {
            switch self {
            case let .image(url, _, _): url
            case let .video(_, posterURL, _, _): posterURL
            }
        }

        var isVideo: Bool {
            if case .video = self { return true }
            return false
        }
    }

    struct Merchant: Hashable {
        let id: String
        let name: String
        let logoURL: URL?
        let websiteURL: URL?
    }

    let id: String
    let title: String?
    let caption: String?
    let subtitle: String?
    let media: Media
    let merchant: Merchant
    let actionURL: URL?
}
