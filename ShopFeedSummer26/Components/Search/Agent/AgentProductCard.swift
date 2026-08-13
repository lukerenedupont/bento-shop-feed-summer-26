import SwiftUI

/// Product card variant for agent conversation and quick search results.
/// Differences from standard ProductCard:
/// - Image has a 0.5pt borderImage border
/// - Star color is configurable (black in quick search, yellow in conversation)
struct AgentProductCard: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    // MARK: - Properties

    var imageURL: String? = nil
    var merchantName: String? = nil
    var productName: String? = nil
    var rating: Double? = nil
    var ratingCount: Int? = nil
    var price: String? = nil
    var originalPrice: String? = nil
    var showFavoriteButton: Bool = false
    var starColor: Color = Color(hex: 0xFFB800)

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            imageSection
            metadataSection
        }
    }

    // MARK: - Image

    private var imageSection: some View {
        Color.white
            .aspectRatio(1, contentMode: .fit)
            .overlay { imageContent }
            .overlay { Color.black.opacity(PurlTune.value("Components/Search/Agent/AgentProductCard.swift:opacity:_:35:44", default: 0.04)) }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20))
            .overlay(
                RoundedRectangle(cornerRadius: GravityRadius.r20)
                    .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
            )
            .gravityShadow(GravityShadows.small)
    }

    @ViewBuilder
    private var imageContent: some View {
        if let imageURL, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let loaded):
                    loaded.resizable().scaledToFill()
                case .failure:
                    Rectangle().fill(PurlTune.token("Components/Search/Agent/AgentProductCard.swift:fill:_:52:38", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                default:
                    Rectangle().fill(PurlTune.token("Components/Search/Agent/AgentProductCard.swift:fill:_:54:38", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                }
            }
        } else {
            Rectangle().fill(PurlTune.token("Components/Search/Agent/AgentProductCard.swift:fill:_:58:30", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let merchantName {
                Text(merchantName)
                    .gravityTextStyle(GravityTypography.caption)
                    .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentProductCard.swift:foregroundStyle:_:69:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                    .lineLimit(1)
            }

            if let productName {
                Text(productName)
                    .gravityTextStyle(GravityTypography.captionBold)
                    .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentProductCard.swift:foregroundStyle:_:76:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .lineLimit(1)
            }

            if let rating, let ratingCount {
                HStack(spacing: 2) {
                    HStack(spacing: 0) {
                        ForEach(0..<5) { index in
                            GravityIcon.starFilled.image
                                .resizable()
                                .scaledToFit()
                                .frame(width: PurlTune.value("Components/Search/Agent/AgentProductCard.swift:frame:width:87:47", default: 12), height: PurlTune.value("Components/Search/Agent/AgentProductCard.swift:frame:height:87:152", default: 12))
                                .foregroundStyle(
                                    Double(index) < rating
                                        ? starColor
                                        : GravityColors.bgFillSecondary
                                )
                        }
                    }
                    Text("(\(ratingCount))")
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentProductCard.swift:foregroundStyle:_:97:42", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                }
            }

            if let price {
                HStack(spacing: GravitySpacing.space4) {
                    Text(price)
                        .gravityTextStyle(GravityTypography.captionMedium)
                        .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentProductCard.swift:foregroundStyle:_:105:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    if let originalPrice {
                        Text(originalPrice)
                            .gravityTextStyle(GravityTypography.caption)
                            .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentProductCard.swift:foregroundStyle:_:109:46", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                            .strikethrough()
                    }
                }
            }
        }
        .padding(.horizontal, PurlTune.token("Components/Search/Agent/AgentProductCard.swift:padding:_:115:31", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
    }
}

#Preview {
    let merchant = SampleMerchant.preview
    let product = merchant.products.first!
    return ScrollView {
        VStack(spacing: GravitySpacing.space12) {
            AgentProductCard(
                imageURL: product.imageURL,
                merchantName: merchant.name,
                productName: product.title,
                rating: merchant.rating,
                ratingCount: merchant.totalRatings,
                price: "$\(product.price)",
                originalPrice: "$99.00",
                showFavoriteButton: true
            )
            .frame(width: PurlTune.value("Components/Search/Agent/AgentProductCard.swift:frame:width:134:27", default: 180))

            AgentProductCard(
                imageURL: nil,
                productName: "No image fallback"
            )
            .frame(width: PurlTune.value("Components/Search/Agent/AgentProductCard.swift:frame:width:140:27", default: 180))
        }
        .padding()
    }
    .background(PurlTune.token("Components/Search/Agent/AgentProductCard.swift:background:_:144:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
