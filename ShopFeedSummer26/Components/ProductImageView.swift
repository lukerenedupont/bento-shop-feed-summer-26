import SwiftUI

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
