import SwiftUI

/// Full-width product detail card matching the Figma "Req Product" spec.
/// Horizontal image carousel + metadata header + AI reason bubble + "View details" button.
struct ProductDetailCard: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let product: AgentProduct
    var reason: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image carousel
            imageCarousel

            // Content
            VStack(alignment: .leading, spacing: 8) {
                headerRow
                if let reason {
                    reasonBubble(reason)
                }
                viewDetailsButton
            }
            .padding(PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:padding:_:22:22", default: 12))
        }
        .background(PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:background:_:24:21", default: GravityColors.bgFill, options: GravityColors.purlTuneColorOptions))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.small)
    }

    // MARK: - Image Carousel

    private var imageCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                let urls = product.allImageURLs.isEmpty
                    ? (product.imageURL.map { [$0] } ?? [])
                    : product.allImageURLs

                ForEach(Array(urls.enumerated()), id: \.offset) { _, url in
                    Color.white
                        .frame(width: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:frame:width:44:39", default: 240), height: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:frame:height:44:146", default: 240))
                        .overlay {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFit()
                                default:
                                    Rectangle().fill(PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:fill:_:51:54", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                                }
                            }
                        }
                        .overlay { Color.black.opacity(PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:opacity:_:55:56", default: 0.04)) }
                }
            }
        }
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: GravityRadius.r20,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: GravityRadius.r20
        ))
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            // Product info
            VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                Text(product.title)
                    .gravityTextStyle(GravityTypography.bodyTitleSmall)
                    .foregroundStyle(PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:foregroundStyle:_:75:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .lineLimit(1)

                if let rating = product.rating, let count = product.ratingCount, count > 0 {
                    HStack(spacing: 2) {
                        HStack(spacing: 0) {
                            ForEach(0..<5) { i in
                                GravityIcon.starFilled.image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:frame:width:85:51", default: 12), height: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:frame:height:85:157", default: 12))
                                    .foregroundStyle(
                                        Double(i) < rating
                                            ? Color(hex: 0xFFB800)
                                            : GravityColors.bgFillSecondary
                                    )
                            }
                        }
                        Text("(\(count))")
                            .gravityTextStyle(GravityTypography.caption)
                            .foregroundStyle(PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:foregroundStyle:_:95:46", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                    }
                }

                Text(product.price)
                    .gravityTextStyle(GravityTypography.captionMedium)
                    .foregroundStyle(PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:foregroundStyle:_:101:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
            }

            Spacer()

            // Merchant avatar
            if let logoURL = product.shopLogoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle().fill(PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:fill:_:113:39", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                    }
                }
                .frame(width: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:frame:width:116:31", default: 32), height: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:frame:height:116:138", default: 32))
                .clipShape(Circle())
                .overlay(Circle().stroke(GravityColors.borderImage, lineWidth: 0.5))
            }

            // Favorite button
            ProductFavoriteButton()
        }
        .padding(.horizontal, PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:padding:_:136:31", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
        .padding(.bottom, PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:padding:_:137:27", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
    }

    // MARK: - Reason Bubble

    private func reasonBubble(_ text: String) -> some View {
        let bullets = parseBullets(text)

        // Bubble with decorative dots overlaid above top-leading
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\u{2022}")
                        .foregroundStyle(Color(red: 0.33, green: 0.31, blue: 0.44))
                    Text(bullet)
                        .gravityTextStyle(GravityTypography.bodySmall)
                        .foregroundStyle(Color(red: 0.33, green: 0.31, blue: 0.44))
                }
            }
        }
        .padding(.horizontal, PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:padding:_:157:31", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        .padding(.vertical, PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:padding:_:158:29", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GravityColors.bgFillSecondary, in: RoundedRectangle(cornerRadius: GravityRadius.r28))
        .overlay(alignment: .topLeading) {
            // Small dot above-right of large dot
            Circle()
                .fill(PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:fill:_:164:23", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                .frame(width: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:frame:width:165:31", default: 6), height: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:frame:height:165:137", default: 6))
                .offset(x: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:offset:x:166:28", default: 21), y: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:offset:y:166:127", default: -13))
        }
        .overlay(alignment: .topLeading) {
            // Large dot just above bubble edge
            Circle()
                .fill(PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:fill:_:171:23", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                .frame(width: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:frame:width:172:31", default: 14), height: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:frame:height:172:138", default: 14))
                .offset(x: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:offset:x:173:28", default: 10.6), y: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:offset:y:173:129", default: -6))
        }
        .padding(.top, PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:padding:_:175:24", default: 4)) // room for dots above
    }

    /// Parse raw reason text into clean bullet strings.
    private func parseBullets(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { line in
                if line.hasPrefix("- ") { return String(line.dropFirst(2)) }
                if line.hasPrefix("\u{2022} ") { return String(line.dropFirst(2)) }
                return line
            }
            .filter { !$0.isEmpty }
    }

    // MARK: - View Details Button

    private var viewDetailsButton: some View {
        Button(action: {}) {
            Text("View details")
                .gravityTextStyle(GravityTypography.captionMedium)
                .foregroundStyle(PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:foregroundStyle:_:198:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                .frame(maxWidth: .infinity)
                .frame(height: PurlTune.value("Components/Search/Agent/ProductDetailCard.swift:frame:height:200:32", default: 32))
                .background(GravityColors.bgFill, in: Capsule())
                .overlay(Capsule().stroke(GravityColors.borderImage, lineWidth: 0.5))
        }
        .padding(.top, PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:padding:_:204:24", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        .gravityShadow(GravityShadows.small)
        .buttonStyle(PressScaleButtonStyle(scale: 0.97))
    }
}

#Preview {
    let product = AgentProduct.comparisonPreviews.first!
    return ScrollView {
        ProductDetailCard(
            product: product,
            reason: "Matches your stated preference for breathable materials and a relaxed fit."
        )
        .padding()
    }
    .background(PurlTune.token("Components/Search/Agent/ProductDetailCard.swift:background:_:219:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
