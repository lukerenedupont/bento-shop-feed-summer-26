import CoreGraphics
import Foundation

public enum ShopRemoteImageURLBuilder {
    private static let cdnHosts: Set<String> = [
        "cdn.shopify.com",
        "shopify-assets.shopifycdn.com",
    ]

    /// CDN width buckets, in pixels. Mirrors RN's `ImageSizes` ladder with two additions — 768
    /// and 1536 — which are the widths the RN app has always requested for full-width images on
    /// 2x and 3x phones (`bucket(points) × scale`), so they are hot in the CDN cache. Without
    /// them, any full-width request on a 3x phone (~1206px) fell off the 1080 bucket onto 2048
    /// (~2.9× the bytes actually needed), and ~750px requests on 2x devices landed on 1080.
    private static let resizedWidths = [64, 128, 256, 384, 512, 640, 768, 1080, 1536, 2048]
    private static let widthSelectionOffset = 0.05

    public static func url(
        for sourceURL: String,
        displayWidth: CGFloat,
        displayScale: CGFloat
    ) -> URL? {
        guard displayWidth.isFinite,
              displayScale.isFinite,
              displayWidth > 0,
              displayScale > 0,
              displayWidth.rounded() <= CGFloat(Int.max) else {
            return nil
        }

        let pointWidth = Int(displayWidth.rounded())
        let scaledWidth = displayScale * CGFloat(pointWidth)
        guard scaledWidth.isFinite,
              scaledWidth <= CGFloat(Int.max) else {
            return nil
        }
        let pixelWidth = Int(scaledWidth)
        return url(for: sourceURL, pixelWidth: pixelWidth)
    }

    public static func url(for sourceURL: URL, pixelWidth: Int) -> URL? {
        url(for: sourceURL.absoluteString, pixelWidth: pixelWidth)
    }

    public static func url(for sourceURL: String, pixelWidth: Int) -> URL? {
        guard pixelWidth > 0,
              let url = URL(string: sourceURL),
              url.scheme != nil else {
            return nil
        }

        // Standalone data adapter: the curated snapshot supplies bundled file URLs.
        // Nuke's original-data task already handles local-file decoding.
        if url.isFileURL { return url }
        guard url.host != nil else { return nil }

        guard isFromShopifyCDN(url) else {
            return url
        }

        guard var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            return url
        }

        var queryItems = components.queryItems ?? []
        let sourceWidth = queryItems
            .first { $0.name == "width" }?
            .value
            .flatMap(Int.init)
        let sourceHeight = queryItems
            .first { $0.name == "height" }?
            .value
            .flatMap(Int.init)
        let newWidth = resizedWidth(for: pixelWidth)

        upsertQueryItem(
            in: &queryItems,
            name: "width",
            value: String(newWidth)
        )

        if let sourceWidth,
           sourceWidth > 0,
           let sourceHeight,
           sourceHeight > 0 {
            let scaledHeight = (
                Double(sourceHeight)
                    * Double(newWidth)
                    / Double(sourceWidth)
            ).rounded()
            if scaledHeight.isFinite,
               scaledHeight < Double(Int.max) {
                let newHeight = Int(scaledHeight)
                upsertQueryItem(
                    in: &queryItems,
                    name: "height",
                    value: String(newHeight)
                )
            }
        }

        if shouldConvertToPNG(url) {
            upsertQueryItem(
                in: &queryItems,
                name: "format",
                value: "png"
            )
        }

        components.queryItems = queryItems
        return components.url ?? url
    }

    public static func isFromShopifyCDN(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }
        return cdnHosts.contains(host)
    }

    private static func shouldConvertToPNG(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        return pathExtension == "svg" || pathExtension == "gif"
    }

    private static func resizedWidth(for pixelWidth: Int) -> Int {
        for resizedWidth in resizedWidths {
            let upperBound = Double(resizedWidth) * (1 + widthSelectionOffset)
            if Double(pixelWidth) <= upperBound {
                return resizedWidth
            }
        }
        return resizedWidths.last ?? pixelWidth
    }

    private static func upsertQueryItem(
        in queryItems: inout [URLQueryItem],
        name: String,
        value: String
    ) {
        queryItems.removeAll { $0.name == name }
        queryItems.append(URLQueryItem(name: name, value: value))
    }
}
