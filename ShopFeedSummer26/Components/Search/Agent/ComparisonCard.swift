import SwiftUI

/// A comparison product card matching the Figma "ProductColumn" spec.
///
/// Standard ProductCard on top + comparison attribute rows below.
/// 160px wide, white fill, 20pt corners, 0.5px border, small shadow.
struct ComparisonCard: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let product: AgentProduct
    var fillWidth: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product card (image + metadata)
            comparisonProductCard

            // Comparison attributes
            if !product.descriptors.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(product.descriptors) { attr in
                        attributeRow(attr.value)
                    }
                }
                .padding(.horizontal, PurlTune.value("Components/Search/Agent/ComparisonCard.swift:padding:_:23:39", default: 10))
            }
        }
        .padding(.bottom, PurlTune.value("Components/Search/Agent/ComparisonCard.swift:padding:_:26:27", default: 10))
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r20)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.small)
        .frame(maxWidth: fillWidth ? .infinity : 176.5)
        .if(!fillWidth) { $0.frame(width: PurlTune.value("Components/Search/Agent/ComparisonCard.swift:frame:width:35:43", default: 160)) }
    }

    // MARK: - Custom Product Card (no image border, flat bottom corners)

    private var comparisonProductCard: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            // Image — no border, only top corners rounded
            Color.white
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let urlString = product.imageURL?.absoluteString,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Rectangle().fill(PurlTune.token("Components/Search/Agent/ComparisonCard.swift:fill:_:53:50", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                            }
                        }
                    }
                }
                .overlay { Color.black.opacity(PurlTune.value("Components/Search/Agent/ComparisonCard.swift:opacity:_:58:48", default: 0.04)) }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: GravityRadius.r20, topTrailingRadius: GravityRadius.r20))

            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                if let merchantName = product.shopName {
                    Text(merchantName)
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(PurlTune.token("Components/Search/Agent/ComparisonCard.swift:foregroundStyle:_:66:42", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                        .lineLimit(1)
                }
                Text(product.title)
                    .gravityTextStyle(GravityTypography.captionBold)
                    .foregroundStyle(PurlTune.token("Components/Search/Agent/ComparisonCard.swift:foregroundStyle:_:71:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .lineLimit(1)
                if let rating = product.rating, let count = product.ratingCount {
                    HStack(spacing: 2) {
                        HStack(spacing: 0) {
                            ForEach(0..<5) { i in
                                GravityIcon.starFilled.image
                                    .resizable().scaledToFit()
                                    .frame(width: PurlTune.value("Components/Search/Agent/ComparisonCard.swift:frame:width:79:51", default: 12), height: PurlTune.value("Components/Search/Agent/ComparisonCard.swift:frame:height:79:154", default: 12))
                                    .foregroundStyle(Double(i) < rating ? Color(hex: 0xFFB800) : GravityColors.bgFillSecondary)
                            }
                        }
                        Text("(\(count))")
                            .gravityTextStyle(GravityTypography.caption)
                            .foregroundStyle(PurlTune.token("Components/Search/Agent/ComparisonCard.swift:foregroundStyle:_:85:46", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                    }
                }
                Text(product.price)
                    .gravityTextStyle(GravityTypography.captionMedium)
                    .foregroundStyle(PurlTune.token("Components/Search/Agent/ComparisonCard.swift:foregroundStyle:_:90:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
            }
            .padding(.horizontal, PurlTune.token("Components/Search/Agent/ComparisonCard.swift:padding:_:92:35", default: GravitySpacing.space10, options: GravitySpacing.purlTuneOptions))
        }
    }

    // MARK: - Attribute Row

    private func attributeRow(_ text: String) -> some View {
        HStack(spacing: 4) {
            GravityIcon.checkmarkCircle.image
                .resizable()
                .scaledToFit()
                .frame(width: PurlTune.value("Components/Search/Agent/ComparisonCard.swift:frame:width:103:31", default: 12), height: PurlTune.value("Components/Search/Agent/ComparisonCard.swift:frame:height:103:135", default: 12))
                .foregroundStyle(PurlTune.token("Components/Search/Agent/ComparisonCard.swift:foregroundStyle:_:104:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))

            Text(text)
                .gravityTextStyle(GravityTypography.caption)
                .foregroundStyle(PurlTune.token("Components/Search/Agent/ComparisonCard.swift:foregroundStyle:_:108:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                .lineLimit(1)
        }
        .padding(.vertical, PurlTune.value("Components/Search/Agent/ComparisonCard.swift:padding:_:111:29", default: 2))
    }
}

#Preview {
    let product = AgentProduct.comparisonPreviews.first!
    return ComparisonCard(product: product, fillWidth: true)
        .padding()
        .background(PurlTune.token("Components/Search/Agent/ComparisonCard.swift:background:_:119:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
