import Foundation

/// Reads a checked-out dossier-feed-bundle folder (feed.json, merchants.json,
/// media/) straight from disk — no server, no network. The documents are
/// byte-for-byte the shapes the bundled assets carry, so the existing
/// decoders take them unchanged.
///
/// Media values in the documents are paths relative to the bundle folder
/// ("media/<name>.png"), not URLs. They are rewritten to absolute file://
/// URLs once, at load, so every existing URL-parsing call site keeps working
/// exactly as written. `URLSession` and `AVPlayerItem` both accept file URLs,
/// so images and looping clips need no view changes.
enum FeedBundleLoader {
    /// The bundle folder, set via `-feedBundlePath /path/to/bundle` launch
    /// argument (or persisted UserDefaults). Accepts a plain path or a
    /// file:// URL. Nil when unset or missing — the app then behaves exactly
    /// as before, loading its bundled assets.
    static var bundleDirectory: URL? {
        guard let raw = UserDefaults.standard.string(forKey: "feedBundlePath"),
              !raw.isEmpty else { return nil }
        let url = raw.hasPrefix("file://") ? URL(string: raw) : URL(fileURLWithPath: raw)
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// feed.json → PersonalizedFeedCatalog, media paths absolutised.
    static func feedData() -> Data? { document("feed.json") }

    /// merchants.json → MerchantSnapshot, media paths absolutised.
    static func merchantsData() -> Data? { document("merchants.json") }

    private static func document(_ name: String) -> Data? {
        guard let dir = bundleDirectory,
              let data = try? Data(contentsOf: dir.appendingPathComponent(name)) else { return nil }
        return localised(data, in: dir)
    }

    /// Rewrite the bundle's relative media paths to absolute file URLs.
    /// Anything already absolute (an https product photo that could not be
    /// downloaded at export time) is deliberately left alone.
    private static func localised(_ data: Data, in dir: URL) -> Data {
        let base = dir.absoluteString.hasSuffix("/") ? dir.absoluteString : dir.absoluteString + "/"
        return Data(String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "\"media/", with: "\"" + base + "media/")
            .utf8)
    }
}
