import SwiftUI
import UIKit

/// Loads merchant media from Shop Server image URLs.
struct MerchantImage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let merchant: SampleMerchant
    let index: Int
    var contentMode: ContentMode = .fill

    init(merchant: SampleMerchant, index: Int = 0, contentMode: ContentMode = .fill) {
        self.merchant = merchant
        self.index = index
        self.contentMode = contentMode
    }

    /// Convenience: show a specific URL string.
    init(merchant: SampleMerchant, urlString: String?, contentMode: ContentMode = .fill) {
        self.merchant = merchant
        self.contentMode = contentMode
        self.index = 0
        self._overrideURL = urlString
    }

    private var _overrideURL: String?

    var body: some View {
        if let urlString = resolvedURL, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                case .failure:
                    fallbackView
                default:
                    Rectangle()
                        .fill(merchant.primaryColor.opacity(PurlTune.value("Components/MerchantImage.swift:opacity:_:37:61", default: 0.15)))
                }
            }
        } else {
            fallbackView
        }
    }

    private var resolvedURL: String? {
        if let override = _overrideURL { return override }
        let urls = merchant.featuredImageURLs
        guard !urls.isEmpty else { return nil }
        return urls[index % urls.count]
    }

    private var fallbackView: some View {
        Rectangle()
            .fill(merchant.primaryColor.opacity(PurlTune.value("Components/MerchantImage.swift:opacity:_:54:49", default: 0.2)))
            .overlay {
                Text(String(merchant.name.prefix(1)))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(merchant.primaryColor)
            }
    }
}

// MARK: - Specialized merchant image views

/// Displays the merchant's logo from URL or bundle.
struct MerchantLogoImage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let merchant: SampleMerchant
    var size: CGFloat = 32

    var body: some View {
        if let url = merchant.bestLogoURL, let parsed = URL(string: url) {
            CachedAsyncImage(url: parsed) { phase in
                switch phase {
                case .success(let image):
                    if merchant.logoFitsInCircle {
                        // Wordmark logos sit fitted on a white disc so wide
                        // marks stay legible instead of being edge-cropped.
                        image.resizable().scaledToFit()
                            .padding(size * 0.14)
                            .frame(width: size, height: size)
                            .background(Circle().fill(.white))
                    } else {
                        image.resizable().scaledToFill()
                    }
                case .failure:
                    initialFallback
                default:
                    // Show brand color circle while loading, not the letter
                    Circle().fill(merchant.primaryColor.opacity(PurlTune.value("Components/MerchantImage.swift:opacity:_:80:65", default: 0.3)))
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            initialFallback
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
    }

    private var initialFallback: some View {
        Rectangle()
            .fill(merchant.primaryColor)
            .overlay {
                Text(String(merchant.name.prefix(1)))
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

/// Displays the merchant's wordmark from URL or bundle.
struct MerchantWordmarkImage: View {
    let merchant: SampleMerchant
    var maxHeight: CGFloat = 28
    var maxWidth: CGFloat = 120
    var tint: Color = .white
    var bundledAssetName: String? = nil

    var body: some View {
        Group {
            if let bundledAssetName,
               UIImage(named: bundledAssetName) != nil {
                Image(bundledAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .leading)
            } else if merchant.bestWordmarkURL != nil,
                      let url = merchant.bestWordmarkURL,
                      let parsed = URL(string: url) {
                CachedAsyncImage(url: parsed) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                            .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .leading)
                    default:
                        Text(merchant.name)
                            .gravityTextStyle(GravityTypography.bodyTitleSmall)
                            .foregroundStyle(tint)
                            .lineLimit(1)
                    }
                }
            } else {
                Text(merchant.name)
                    .gravityTextStyle(GravityTypography.bodyTitleSmall)
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
    }
}

/// Displays the merchant's cover/hero image from URL or bundle.
struct MerchantCoverImage: View {
    let merchant: SampleMerchant
    var contentMode: ContentMode = .fill

    /// The best brand color for backgrounds/gradients — prefers coverDominant, falls back to primary.
    var brandColor: Color {
        if let hex = merchant.coverDominantColor, !hex.isEmpty {
            return Color(hex: hex)
        }
        return merchant.primaryColor
    }

    var body: some View {
        if let url = merchant.bestCoverImageURL, let parsed = URL(string: url) {
            CachedAsyncImage(url: parsed) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: contentMode)
                case .failure:
                    brandColorFill
                default:
                    brandColorFill
                }
            }
        } else {
            brandColorFill
        }
    }

    private var brandColorFill: some View {
        Rectangle().fill(brandColor)
    }
}

#Preview("MerchantImage / Logo / Wordmark / Cover") {
    let merchant = SampleMerchant.preview
    ScrollView {
        VStack(alignment: .leading, spacing: GravitySpacing.space20) {
            Text("Featured image").gravityTextStyle(GravityTypography.subtitle)
            MerchantImage(merchant: merchant, index: 0)
                .frame(height: PurlTune.value("Components/MerchantImage.swift:frame:height:177:32", default: 200))
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20))

            Text("Logo").gravityTextStyle(GravityTypography.subtitle)
            MerchantLogoImage(merchant: merchant, size: 64)

            Text("Wordmark").gravityTextStyle(GravityTypography.subtitle)
            MerchantWordmarkImage(merchant: merchant)
                .frame(height: PurlTune.value("Components/MerchantImage.swift:frame:height:185:32", default: 32))

            Text("Cover").gravityTextStyle(GravityTypography.subtitle)
            MerchantCoverImage(merchant: merchant)
                .frame(height: PurlTune.value("Components/MerchantImage.swift:frame:height:189:32", default: 160))
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20))
        }
        .padding()
    }
    .background(PurlTune.token("Components/MerchantImage.swift:background:_:194:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
