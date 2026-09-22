import SwiftUI
import UIKit

/// Edge-to-edge media from the separately reviewed native cover edit.
/// Catalog/branding availability alone never selects a full-bleed image.
struct LibraryProductHero: View {
    let story: FeedStory
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Color(hex: story.accentHex)
            .overlay {
                if let cover = LibraryArtDirection.cover(for: story), let url = cover.url {
                    CachedAsyncImage(url: url) { phase in
                        if case let .success(image) = phase {
                            image.resizable().scaledToFill()
                                .offset(x: height > width ? width * CGFloat(cover.portraitOffsetRatio ?? 0) : 0)
                                .accessibilityLabel("Editorial cover: \(story.title)")
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: width, height: height)
                    .clipped()
                }
            }
            .overlay {
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.30), location: 0),
                    .init(color: .clear, location: 0.30),
                    .init(color: .black.opacity(0.12), location: 0.43),
                    .init(color: .black.opacity(0.55), location: 0.64),
                    .init(color: .black.opacity(0.76), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            .frame(width: width, height: height)
            .clipped()
            .allowsHitTesting(false)
    }
}

/// Native equivalent of the library's merchant-wordmark.js behavior. Selection
/// is exact-ID based; opaque white/black backplates are converted to real alpha
/// off the main thread, not blended against an unrelated snapshot background.
struct LibraryMerchantWordmark: View {
    let merchantID: String
    var onDark = true

    var body: some View {
        LibraryWordmarkArtwork(
            sources: ShopCanvasLibrary.wordmarkSources(for: merchantID, onDark: onDark),
            name: LibraryMerchantNames.name(for: merchantID, fallback: ShopCanvasLibrary.merchantsByID[merchantID]?.name ?? "Shop"),
            onDark: onDark
        )
    }
}

struct LibraryCollectionWordmark: View {
    let story: FeedStory
    var onDark = true

    var body: some View {
        LibraryWordmarkArtwork(
            sources: LibraryWordmarkCatalog.sources(for: LibraryWordmarkCatalog.key(for: story), onDark: onDark),
            name: story.title, onDark: onDark
        )
        .accessibilityIdentifier("collection-wordmark.\(story.id)")
    }
}

private struct LibraryWordmarkArtwork: View {
    let sources: [URL]
    let name: String
    let onDark: Bool
    @State private var artwork: UIImage?

    var body: some View {
        Group {
            if let artwork {
                Image(uiImage: artwork).resizable().scaledToFit()
            } else {
                Text(name).font(.headline).lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(onDark ? .white : .black)
            }
        }
        .accessibilityLabel(name)
        .task(id: "\(sources.map(\.absoluteString).joined(separator: "|"))|\(onDark)") {
            artwork = nil
            let image = await LibraryMarkLoader.load(sources, onDark: onDark)
            guard !Task.isCancelled else { return }
            artwork = image
        }
    }
}

@MainActor
private enum LibraryMarkLoader {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 128
        cache.totalCostLimit = 8 * 1024 * 1024
        return cache
    }()

    static func load(_ sources: [URL], onDark: Bool) async -> UIImage? {
        for source in sources {
            guard !Task.isCancelled else { return nil }
            let key = "\(source.absoluteString)|\(onDark)" as NSString
            if let image = cache.object(forKey: key) { return image }
            _ = await ImageURLCache.shared.loadImage(for: source)
            guard let original = ImageURLCache.shared.image(for: source) else { continue }
            let prepared = await Task.detached(priority: .utility) {
                LibraryWordmarkMatte.prepare(original, onDark: onDark)
            }.value
            if let prepared {
                let cost = (prepared.cgImage?.width ?? 0) * (prepared.cgImage?.height ?? 0) * 4
                cache.setObject(prepared, forKey: key, cost: cost)
                return prepared
            }
        }
        return nil
    }
}

enum LibraryWordmarkMatte {
    static func prepare(_ image: UIImage, onDark: Bool) -> UIImage? {
        guard let source = image.cgImage else { return image }
        let scale = min(1, 640.0 / Double(max(source.width, source.height)))
        let width = max(1, Int(Double(source.width) * scale))
        let height = max(1, Int(Double(source.height) * scale))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            let buffer = bytes.bindMemory(to: UInt8.self)
            let transparent = stride(from: 3, to: buffer.count, by: 4).contains { buffer[$0] < 240 }
            let corners = [0, width - 1, width * (height - 1), width * height - 1].map { $0 * 4 }
            let light = corners.allSatisfy { min(buffer[$0], buffer[$0 + 1], buffer[$0 + 2]) > 220 }
            let dark = corners.allSatisfy { max(buffer[$0], buffer[$0 + 1], buffer[$0 + 2]) < 40 }
            guard transparent || light || dark else { return image }
            var coverage = 0
            for index in stride(from: 0, to: buffer.count, by: 4) {
                var alpha = Double(buffer[index + 3])
                if !transparent {
                    let luminance = (0.2126 * Double(buffer[index]) + 0.7152 * Double(buffer[index + 1])
                        + 0.0722 * Double(buffer[index + 2])) / 255
                    let gray = light ? 1 - luminance : luminance
                    alpha *= max(0, min(1, (gray - 0.5) * 3 + 0.5))
                }
                let a = UInt8(alpha.rounded())
                buffer[index] = onDark ? a : 0
                buffer[index + 1] = onDark ? a : 0
                buffer[index + 2] = onDark ? a : 0
                buffer[index + 3] = a
                coverage += Int(a)
            }
            guard coverage > 0, let result = context.makeImage() else { return nil }
            return UIImage(cgImage: result)
        }
    }
}
