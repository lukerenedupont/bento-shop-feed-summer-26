import Nuke
import UIKit

@MainActor
final class ShopRemoteImagePreviewIndex {
    static let shared = ShopRemoteImagePreviewIndex()

    private let maximumEntryCount: Int
    private var requests: [ShopRemoteImagePreviewIdentity: ImageRequest] = [:]

    var entryCount: Int {
        requests.count
    }

    init(maximumEntryCount: Int = 256) {
        self.maximumEntryCount = max(maximumEntryCount, 1)
    }

    func register(request: ImageRequest, identity: ShopRemoteImagePreviewIdentity) {
        if requests[identity] == nil,
           requests.count >= maximumEntryCount,
           let identityToRemove = requests.keys.first {
            requests.removeValue(forKey: identityToRemove)
        }

        requests[identity] = request
    }

    func cachedPreview(
        for identity: ShopRemoteImagePreviewIdentity,
        pipeline: ImagePipeline = .shared
    ) -> UIImage? {
        guard let request = requests[identity] else {
            return nil
        }

        guard let cachedImage = pipeline.cache[request], cachedImage.isPreview == false else {
            requests.removeValue(forKey: identity)
            return nil
        }

        return cachedImage.image
    }
}
