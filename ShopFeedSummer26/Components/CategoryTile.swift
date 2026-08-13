import SwiftUI

/// A colored category tile with a label and product thumbnail previews.
///
/// Matches the Figma "CategoryTile" component: 177×133, r20,
/// colored background, white label (bodySmallBold), 2 product thumbnails (73×73, r12),
/// plus a 10% black scrim overlay.
struct CategoryTile: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let label: String
    let backgroundColor: Color
    var thumbnailImages: [Image] = []
    /// CDN URLs for thumbnails (used when thumbnailImages is empty).
    var thumbnailURLs: [String] = []

    /// Optional tap handler; if nil, the tile is non-interactive.
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            onTap?()
        } label: {
            ZStack {
                // Background fill
                RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                    .fill(backgroundColor)

                // Product thumbnail grid
                VStack(alignment: .leading, spacing: GravitySpacing.space16) {
                    // Category label
                    Text(label)
                        .gravityTextStyle(GravityTypography.bodySmallBold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    // Thumbnail row: up to 2 product images
                    HStack(spacing: 10) {
                        if !thumbnailImages.isEmpty {
                            // Local bundle images
                            ForEach(0..<min(2, thumbnailImages.count), id: \.self) { index in
                                thumbnailImages[index]
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: PurlTune.value("Components/CategoryTile.swift:frame:width:44:51", default: 73), height: PurlTune.value("Components/CategoryTile.swift:frame:height:44:139", default: 73))
                                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous))
                            }
                        } else if !thumbnailURLs.isEmpty {
                            // Remote CDN images
                            ForEach(Array(thumbnailURLs.prefix(2).enumerated()), id: \.offset) { _, urlString in
                                if let url = URL(string: urlString) {
                                    CachedAsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        default:
                                            RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
                                                .fill(Color.white.opacity(PurlTune.value("Components/CategoryTile.swift:opacity:_:57:75", default: 0.15)))
                                        }
                                    }
                                    .frame(width: PurlTune.value("Components/CategoryTile.swift:frame:width:60:51", default: 73), height: PurlTune.value("Components/CategoryTile.swift:frame:height:60:139", default: 73))
                                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous))
                                }
                            }
                        }

                        // Placeholders for remaining slots
                        let filledCount = max(thumbnailImages.count, thumbnailURLs.prefix(2).count)
                        if filledCount < 2 {
                            ForEach(0..<(2 - filledCount), id: \.self) { _ in
                                RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
                                    .fill(Color.white.opacity(PurlTune.value("Components/CategoryTile.swift:opacity:_:71:63", default: 0.15)))
                                    .frame(width: PurlTune.value("Components/CategoryTile.swift:frame:width:72:51", default: 73), height: PurlTune.value("Components/CategoryTile.swift:frame:height:72:139", default: 73))
                            }
                        }
                    }
                }
                .padding(PurlTune.token("Components/CategoryTile.swift:padding:_:77:26", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // 10% black scrim
                RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                    .fill(.black.opacity(PurlTune.value("Components/CategoryTile.swift:opacity:_:82:42", default: 0.10)))
            }
            .frame(height: PurlTune.value("Components/CategoryTile.swift:frame:height:84:28", default: 133))
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let merchant = SampleMerchant.all.first!
    let imageURLs = Array(merchant.featuredImageURLs.prefix(2))

    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            CategoryTile(
                label: "Beauty",
                backgroundColor: Color(hex: 0xFF446D),
                thumbnailURLs: imageURLs
            )
            CategoryTile(
                label: "Womenswear",
                backgroundColor: Color(hex: 0x9EA6AC),
                thumbnailURLs: imageURLs
            )
            CategoryTile(
                label: "Menswear",
                backgroundColor: Color(hex: 0x003988),
                thumbnailURLs: imageURLs
            )
            CategoryTile(
                label: "Home",
                backgroundColor: Color(hex: 0xCE5F01),
                thumbnailURLs: imageURLs
            )
        }
        .padding(.horizontal, GravitySpacing.screenMargin)
    }
    .background(PurlTune.token("Components/CategoryTile.swift:background:_:122:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
