import Foundation

/// Reviewed marks supplied for this internal preview. Asset identity is kept
/// distinct from product seller identity, particularly for multi-retailer edits.
enum LibraryWordmarkCatalog {
    struct Variant: Decodable { let path: String }
    struct Asset: Decodable {
        let tier: String
        let review: String
        let white: Variant?
        let original: Variant?
    }
    struct Manifest: Decodable {
        let merchantKeys: [String: String]
        let groupKeys: [String: String]
        let assets: [String: Asset]
        let reusePermission: String
    }

    static let manifest: Manifest = {
        do {
            return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf:
                ShopCanvasLibrary.rootURL.appendingPathComponent("wordmarks.json")))
        } catch {
            assertionFailure("Missing reviewed wordmark manifest: \(error)")
            return Manifest(merchantKeys: [:], groupKeys: [:], assets: [:], reusePermission: "unknown")
        }
    }()

    static func key(for story: FeedStory) -> String? {
        guard let group = LibraryArtDirection.group(for: story),
              let key = manifest.groupKeys[group], !story.products.isEmpty,
              story.products.allSatisfy({
                  ShopCanvasLibrary.productsByNativeID[$0.productID]?.brand == group
              }) else { return nil }
        return key
    }

    static func sources(for key: String?, onDark: Bool) -> [URL] {
        guard let key, let asset = manifest.assets[key] else { return [] }
        let variants = onDark ? [asset.white, asset.original] : [asset.original, asset.white]
        var seen = Set<URL>()
        return variants.compactMap { ShopCanvasLibrary.resolve($0?.path) }
            .filter { seen.insert($0).inserted }
    }

    static func sources(forMerchantID id: String, onDark: Bool) -> [URL] {
        sources(for: manifest.merchantKeys[id], onDark: onDark)
    }
}
