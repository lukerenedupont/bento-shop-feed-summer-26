import SwiftUI

/// In-memory image cache shared across the app.
/// Pre-warms product images at launch so agent cards appear instantly.
@MainActor
final class ImageCache {
    static let shared = ImageCache()

    private var cache: [String: Image] = [:]
    private var inflight: [String: Task<Image?, Never>] = [:]

    private init() {}

    /// Returns a cached image immediately, or nil if not yet available.
    func image(for urlString: String) -> Image? {
        cache[urlString]
    }

    /// Returns a cached image or downloads it, caching the result.
    func image(for urlString: String) async -> Image? {
        if let cached = cache[urlString] { return cached }

        // Join an existing download if one is in-flight
        if let existing = inflight[urlString] {
            return await existing.value
        }

        let task = Task<Image?, Never> {
            guard let url = URL(string: urlString),
                  let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            // Decode off the main thread to avoid blocking UI
            let uiImage = await Task.detached {
                UIImage(data: data)
            }.value
            guard let uiImage else { return nil }
            let img = Image(uiImage: uiImage)
            cache[urlString] = img
            return img
        }
        inflight[urlString] = task
        let result = await task.value
        inflight.removeValue(forKey: urlString)
        return result
    }

    /// Pre-downloads all product images that could appear in agent responses.
    func prewarm() {
        let allProducts = SampleMerchant.all.flatMap(\.products)
        let urls = allProducts.compactMap(\.imageURL)

        Task {
            await withTaskGroup(of: Void.self) { group in
                for urlString in urls {
                    guard cache[urlString] == nil else { continue }
                    group.addTask { @MainActor in
                        _ = await self.image(for: urlString)
                    }
                }
            }
        }
    }
}
