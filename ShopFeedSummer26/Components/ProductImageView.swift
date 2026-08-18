import SwiftUI

enum LifestyleImageFormat {
    case landscape
    case portrait
}

private func stableMediaIndex(seed: String, count: Int) -> Int {
    guard count > 0 else { return 0 }
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in seed.utf8 {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
    }
    return Int(hash % UInt64(count))
}

extension SampleMerchant.Product {
    /// Andreas's bundle places the original catalog image first, followed by
    /// two generated landscape scenes and two generated portrait scenes.
    /// Keeping that authored order lets each surface select the crop that was
    /// generated for its shape instead of aggressively cropping one asset.
    func lifestyleImageURLs(for format: LifestyleImageFormat) -> [String] {
        let generated = allImageURLs.filter { $0 != imageURL }
        guard generated.count >= 4 else { return generated }

        switch format {
        case .landscape:
            return Array(generated.prefix(2))
        case .portrait:
            return Array(generated.suffix(2))
        }
    }

    func lifestyleImageURL(for format: LifestyleImageFormat, seed: String) -> URL? {
        let candidates = lifestyleImageURLs(for: format)
        guard !candidates.isEmpty else { return nil }
        return URL(string: candidates[stableMediaIndex(seed: seed, count: candidates.count)])
    }
}

extension FeedStory {
    /// Selects from every product in the story, so the complete lifestyle
    /// library participates across feed cards, covers, and topic heroes.
    func lifestyleImageURL(
        from merchants: [SampleMerchant],
        format: LifestyleImageFormat,
        role: String
    ) -> URL? {
        guard !usesCatalogOnlyMedia else { return nil }
        let candidates = resolvedProducts(from: merchants).flatMap {
            $0.product.lifestyleImageURLs(for: format)
        }
        guard !candidates.isEmpty else { return nil }
        let seed = "\(id)-\(role)"
        return URL(string: candidates[stableMediaIndex(seed: seed, count: candidates.count)])
    }
}

/// Generated lifestyle media with an honest catalog-image fallback. This is
/// intentionally still-only; motion remains reserved for explicit video cards.
struct LifestyleProductImage: View {
    let product: SampleMerchant.Product
    let merchant: SampleMerchant
    let format: LifestyleImageFormat
    let seed: String

    var body: some View {
        if let url = product.lifestyleImageURL(for: format, seed: seed) {
            CachedAsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                } else if case .failure = phase {
                    ProductImageView(product: product, merchant: merchant)
                } else {
                    merchant.brandColor.opacity(0.22)
                }
            }
        } else {
            ProductImageView(product: product, merchant: merchant)
        }
    }
}

/// Loads a product image from its CDN URL, falling back to a merchant featured image.
struct ProductImageView: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let product: SampleMerchant.Product
    let merchant: SampleMerchant
    /// Optional index used to pick a featured image fallback.
    var fallbackIndex: Int = 0

    var body: some View {
        if let urlString = product.imageURL, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackImage
                default:
                    Rectangle()
                        .fill(merchant.primaryColor.opacity(PurlTune.value("Components/ProductImageView.swift:opacity:_:22:61", default: 0.15)))
                        .overlay {
                            ProgressView()
                        }
                }
            }
        } else {
            fallbackImage
        }
    }

    @ViewBuilder
    private var fallbackImage: some View {
        MerchantImage(merchant: merchant, index: fallbackIndex)
    }
}

#Preview {
    let merchant = SampleMerchant.preview
    HStack(spacing: GravitySpacing.space12) {
        ForEach(Array(merchant.products.prefix(3).enumerated()), id: \.element.id) { idx, product in
            ProductImageView(product: product, merchant: merchant, fallbackIndex: idx)
                .frame(width: PurlTune.value("Components/ProductImageView.swift:frame:width:44:31", default: 110), height: PurlTune.value("Components/ProductImageView.swift:frame:height:44:124", default: 110))
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16))
        }
    }
    .padding()
    .background(PurlTune.token("Components/ProductImageView.swift:background:_:49:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
