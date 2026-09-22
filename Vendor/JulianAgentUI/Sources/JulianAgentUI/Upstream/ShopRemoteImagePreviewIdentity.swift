import Foundation

struct ShopRemoteImagePreviewIdentity: Hashable, Sendable {
    private struct AspectRatio: Hashable, Sendable {
        let width: Int
        let height: Int
    }

    private let canonicalURL: String
    private let aspectRatio: AspectRatio?

    static func make(from sourceURL: String) -> Self? {
        guard let url = URL(string: sourceURL),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        guard ShopRemoteImageURLBuilder.isFromShopifyCDN(url) else {
            return nil
        }

        let queryItems = components.queryItems ?? []
        let sourceWidth = queryItems.first { $0.name == "width" }?.value.flatMap(Int.init)
        let sourceHeight = queryItems.first { $0.name == "height" }?.value.flatMap(Int.init)
        let hasScalableHeight = sourceWidth.map { $0 > 0 } == true && sourceHeight.map { $0 > 0 } == true

        let canonicalQueryItems = queryItems.filter { item in
            if item.name == "width" {
                return false
            }
            if item.name == "height", hasScalableHeight {
                return false
            }
            return true
        }
        components.queryItems = canonicalQueryItems.isEmpty ? nil : canonicalQueryItems

        let aspectRatio: AspectRatio?
        if hasScalableHeight, let sourceWidth, let sourceHeight {
            let divisor = greatestCommonDivisor(sourceWidth, sourceHeight)
            aspectRatio = AspectRatio(width: sourceWidth / divisor, height: sourceHeight / divisor)
        } else {
            aspectRatio = nil
        }

        guard let canonicalURL = components.url?.absoluteString else {
            return nil
        }

        return Self(canonicalURL: canonicalURL, aspectRatio: aspectRatio)
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var first = lhs
        var second = rhs

        while second != 0 {
            let remainder = first % second
            first = second
            second = remainder
        }

        return max(first, 1)
    }
}
