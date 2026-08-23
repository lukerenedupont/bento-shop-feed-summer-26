import SwiftUI
import ImageIO

/// A performant cached async image that:
/// - Downsamples to the rendered size (not full resolution)
/// - Decodes off the main thread
/// - Memory + disk caching
/// - Limits concurrent downloads to avoid flooding the network
struct CachedAsyncImage<Content: View>: View {
    let url: URL
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(url: URL, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                // Fast path: memory cache (no decoding, instant)
                if let cached = ImageURLCache.shared.image(for: url) {
                    phase = .success(Image(uiImage: cached))
                    return
                }
                // Slow path: disk cache or network (off main thread)
                let result = await ImageURLCache.shared.loadImage(for: url)
                if !Task.isCancelled {
                    phase = result
                }
            }
    }
}

// MARK: - Image URL Cache

/// Shared image cache with downsampling, off-main-thread decoding,
/// and a concurrency limiter for network requests.
final class ImageURLCache: @unchecked Sendable {
    static let shared = ImageURLCache()

    let urlCache: URLCache
    let session: URLSession
    private let memoryCache = NSCache<NSURL, UIImage>()
    /// Coalesces duplicate requests from repeated carousel items. Without
    /// this, the same product image can be downloaded and decoded several
    /// times while an endless rail is first entering the viewport.
    private let requestBroker = ImageRequestBroker()

    /// Limits concurrent network image fetches to avoid overwhelming the device.
    private let semaphore = AsyncSemaphore(limit: 4)

    /// The largest phone surface is under 400pt wide. A 960px decode remains
    /// crisp while avoiding 1200px allocations for every compact product tile.
    private let maxPixelSize: CGFloat = 960

    private init() {
        urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 96 * 1024 * 1024,
            directory: FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("PrototypeImageCache")
        )
        let config = URLSessionConfiguration.default
        config.urlCache = urlCache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: config)

        memoryCache.countLimit = 60
        memoryCache.totalCostLimit = 64 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        let cost = (image.cgImage?.width ?? 0) * (image.cgImage?.height ?? 0) * 4
        memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    /// Warms a small set of imminent feed images without publishing view
    /// state. The normal image view then hits memory synchronously when the
    /// next card enters the viewport instead of decoding during the swipe.
    func prefetch(_ urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls where image(for: url) == nil {
                group.addTask { [self] in
                    _ = await loadImage(for: url)
                }
            }
        }
    }

    /// Load an image: memory → disk (downsampled) → network (downsampled).
    /// All decoding happens off the main thread.
    func loadImage(for url: URL) async -> AsyncImagePhase {
        if let cached = image(for: url) {
            return .success(Image(uiImage: cached))
        }

        let loaded = await requestBroker.load(url: url) { [weak self] in
            guard let self else { return nil }
            return await self.fetchAndDecode(for: url)
        }
        guard let loaded else {
            return .failure(URLError(.cannotDecodeContentData))
        }
        setImage(loaded, for: url)
        return .success(Image(uiImage: loaded))
    }

    /// Performs one physical load for a URL. `requestBroker` ensures repeated
    /// carousel cells await this same operation instead of creating their own.
    private func fetchAndDecode(for url: URL) async -> UIImage? {
        // Bundled dossier media is already on disk. Routing file URLs through
        // URLSession read the entire multi-megabyte source into memory and
        // duplicated it in the 500 MB response cache before downsampling.
        // ImageIO can thumbnail directly from the file off the main thread.
        if url.isFileURL {
            return await downsample(fileURL: url)
        }

        // 1. Disk cache — decode + downsample off main thread
        let request = URLRequest(url: url)
        if let cachedResponse = urlCache.cachedResponse(for: request) {
            if let image = await downsample(data: cachedResponse.data) {
                return image
            }
        }

        // 2. Network — throttled
        await semaphore.wait()

        // Re-check memory in case another task loaded it while we waited
        if let cached = image(for: url) {
            await semaphore.signal()
            return cached
        }

        do {
            let (data, response) = try await session.data(for: request)

            // Cache the response on disk
            let cachedResponse = CachedURLResponse(response: response, data: data)
            urlCache.storeCachedResponse(cachedResponse, for: request)

            // Downsample off main thread
            guard let image = await downsample(data: data) else {
                await semaphore.signal()
                return nil
            }
            await semaphore.signal()
            return image
        } catch {
            await semaphore.signal()
            return nil
        }
    }

    /// Downsample image data to maxPixelSize on a background thread.
    /// Uses ImageIO for efficient thumbnail generation without decoding the full image.
    private func downsample(data: Data) async -> UIImage? {
        await Task.detached(priority: .utility) { [maxPixelSize] in
            let options: [CFString: Any] = [
                kCGImageSourceShouldCache: false,
            ]
            guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
                return nil as UIImage?
            }

            let thumbOptions: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
                // Fallback: try full decode if thumbnail fails
                guard let cgFull = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    return nil as UIImage?
                }
                return UIImage(cgImage: cgFull)
            }
            return UIImage(cgImage: cgImage)
        }.value
    }

    private func downsample(fileURL: URL) async -> UIImage? {
        await Task.detached(priority: .utility) { [maxPixelSize] in
            let sourceOptions: [CFString: Any] = [
                kCGImageSourceShouldCache: false,
            ]
            guard let source = CGImageSourceCreateWithURL(
                fileURL as CFURL,
                sourceOptions as CFDictionary
            ) else { return nil as UIImage? }

            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                thumbnailOptions as CFDictionary
            ) else { return nil as UIImage? }
            return UIImage(cgImage: cgImage)
        }.value
    }
}

/// One task per URL prevents looping rails and prefetch from duplicating the
/// same network, file IO, and ImageIO decode work.
private actor ImageRequestBroker {
    private var requests: [URL: Task<UIImage?, Never>] = [:]

    func load(
        url: URL,
        operation: @escaping @Sendable () async -> UIImage?
    ) async -> UIImage? {
        if let request = requests[url] {
            return await request.value
        }

        let request = Task(priority: .utility) {
            await operation()
        }
        requests[url] = request
        let image = await request.value
        requests[url] = nil
        return image
    }
}

// MARK: - Async Semaphore

/// Simple async semaphore to limit concurrent operations.
actor AsyncSemaphore {
    private let limit: Int
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
        self.count = limit
    }

    func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume()
        } else {
            count = min(count + 1, limit)
        }
    }
}

#Preview {
    let url = SampleMerchant.preview.products.compactMap(\.imageURL).first.flatMap(URL.init(string:))

    return Group {
        if let url {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Color.red.opacity(PurlTune.value("Components/CachedAsyncImage.swift:opacity:_:198:39", default: 0.1)).overlay(Image(systemName: "exclamationmark.triangle"))
                @unknown default:
                    Color.clear
                }
            }
            .frame(width: PurlTune.value("Components/CachedAsyncImage.swift:frame:width:203:27", default: 240), height: PurlTune.value("Components/CachedAsyncImage.swift:frame:height:203:121", default: 240))
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20))
        } else {
            Text("No preview image URL available")
                .foregroundStyle(PurlTune.token("Components/CachedAsyncImage.swift:foregroundStyle:_:207:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
        }
    }
    .padding()
    .background(PurlTune.token("Components/CachedAsyncImage.swift:background:_:211:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
