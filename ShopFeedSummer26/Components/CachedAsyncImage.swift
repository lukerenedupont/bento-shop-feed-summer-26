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

    /// Limits concurrent network image fetches to avoid overwhelming the device.
    private let semaphore = AsyncSemaphore(limit: 6)

    /// Max pixel dimension to downsample to. Matches 3x of the largest card width (~377pt).
    private let maxPixelSize: CGFloat = 1200

    private init() {
        urlCache = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            directory: FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("PrototypeImageCache")
        )
        let config = URLSessionConfiguration.default
        config.urlCache = urlCache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: config)

        memoryCache.countLimit = 150
        memoryCache.totalCostLimit = 150 * 1024 * 1024
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
        // 1. Disk cache — decode + downsample off main thread
        let request = URLRequest(url: url)
        if let cachedResponse = urlCache.cachedResponse(for: request) {
            if let image = await downsample(data: cachedResponse.data) {
                setImage(image, for: url)
                return .success(Image(uiImage: image))
            }
        }

        // 2. Network — throttled
        await semaphore.wait()

        // Re-check memory in case another task loaded it while we waited
        if let cached = image(for: url) {
            await semaphore.signal()
            return .success(Image(uiImage: cached))
        }

        do {
            let (data, response) = try await session.data(for: request)

            // Cache the response on disk
            let cachedResponse = CachedURLResponse(response: response, data: data)
            urlCache.storeCachedResponse(cachedResponse, for: request)

            // Downsample off main thread
            guard let image = await downsample(data: data) else {
                await semaphore.signal()
                return .failure(URLError(.cannotDecodeContentData))
            }
            setImage(image, for: url)
            await semaphore.signal()
            return .success(Image(uiImage: image))
        } catch {
            await semaphore.signal()
            return .failure(error)
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
