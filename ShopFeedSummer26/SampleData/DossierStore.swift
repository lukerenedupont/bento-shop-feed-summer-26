import Foundation

/// A Deep Dive dossier produced by the dossier-lab batch pipeline.
///
/// The JSON schema is still landing, so this model is deliberately tolerant:
/// the manifest supplies the stable identity (key + merchantID + productID)
/// and the raw dossier payload is kept as a dictionary until the schema
/// settles enough to type it. Ambient films are plain mp4 files dropped next
/// to the dossier JSON.
struct ProductDossier: Identifiable {
    let key: String
    let merchantID: String
    let productID: Int
    let title: String?
    /// Local bundle URLs for this product's ambient films, in manifest order.
    let videoURLs: [URL]
    /// The full dossier payload, when `<key>.json` has been dropped in.
    /// Nil for manifest entries whose JSON hasn't arrived yet.
    let payload: [String: Any]?

    var id: String { key }
    var hasAmbientVideo: Bool { !videoURLs.isEmpty }
    var ambientVideoURL: URL? { videoURLs.first }
    /// A second film, reserved for the Deep Dive page.
    var deepDiveVideoURL: URL? { videoURLs.count > 1 ? videoURLs[1] : videoURLs.first }
}

/// Loads dossiers from the bundled `Dossiers/` drop-zone folder.
///
/// Adding content requires no code changes:
/// 1. Drop `<key>.json` (a saved dossier) into `ShopFeedSummer26/Dossiers/`.
/// 2. Drop its mp4 films alongside. Films are matched to a dossier either by
///    filename prefix (`<key>*.mp4`) or by listing them in the manifest
///    entry's `videoFiles`.
/// 3. Rebuild. The folder is a bundle folder reference, so new files ship
///    automatically.
enum DossierStore {

    static let all: [ProductDossier] = load()

    private static var byProduct: [String: ProductDossier] = {
        Dictionary(uniqueKeysWithValues: all.map { ("\($0.merchantID)#\($0.productID)", $0) })
    }()

    static func dossier(merchantID: String, productID: Int) -> ProductDossier? {
        byProduct["\(merchantID)#\(productID)"]
    }

    static func ambientVideoURL(merchantID: String, productID: Int) -> URL? {
        dossier(merchantID: merchantID, productID: productID)?.ambientVideoURL
    }

    // MARK: - Loading

    private struct Manifest: Decodable {
        struct Entry: Decodable {
            let key: String
            let merchantID: String
            let productID: Int
            let title: String?
            let videoFiles: [String]?
        }
        let dossiers: [Entry]
    }

    private static func load() -> [ProductDossier] {
        guard let folderURL = Bundle.main.url(forResource: "Dossiers", withExtension: nil) else {
            return []
        }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folderURL, includingPropertiesForKeys: nil
        )) ?? []
        let mp4s = contents.filter { $0.pathExtension.lowercased() == "mp4" }

        guard let manifestURL = contents.first(where: { $0.lastPathComponent == "dossier-manifest.json" }),
              let manifestData = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: manifestData) else {
            return []
        }

        return manifest.dossiers.map { entry in
            // Explicit manifest listing wins; filename prefix is the fallback
            // so a raw drop works before anyone edits the manifest.
            let explicit = (entry.videoFiles ?? []).compactMap { name in
                mp4s.first { $0.lastPathComponent == name }
            }
            let matched = explicit.isEmpty
                ? mp4s.filter { $0.lastPathComponent.hasPrefix(entry.key) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
                : explicit

            let payloadURL = folderURL.appendingPathComponent("\(entry.key).json")
            let payload = (try? Data(contentsOf: payloadURL))
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }

            return ProductDossier(
                key: entry.key,
                merchantID: entry.merchantID,
                productID: entry.productID,
                title: entry.title,
                videoURLs: matched,
                payload: payload
            )
        }
    }
}
