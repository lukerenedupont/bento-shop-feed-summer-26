import SwiftUI

/// Merchant storefront page matching the Figma "Store" design.
///
/// Full-bleed hero (video/image/solid color) with centered branding,
/// floating glass header buttons, filter chip row, and 2-column product grid.
struct StorePage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let merchantId: String
    let namespace: Namespace.ID

    @Environment(NavigationCoordinator.self) private var coordinator

    private let contentPadding: CGFloat = GravitySpacing.space20

    private var merchant: SampleMerchant? {
        SampleMerchant.all.first { $0.id == merchantId }
    }

    /// Whether the merchant's brand color is dark enough to need light text.
    private var isDarkBackground: Bool {
        guard let merchant else { return false }
        let resolved = UIColor(merchant.brandColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: nil)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.55
    }

    var body: some View {
        Group {
        if let merchant {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero(merchant: merchant)
                    storeContent(merchant: merchant)
                }
            }
            .ignoresSafeArea(edges: .top)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, offset in
                coordinator.updateScrollOffset(offset)
            }
            .background(merchant.brandColor)
            .overlay(alignment: .top) {
                floatingHeader(merchant: merchant)
                    .padding(.top, PurlTune.token("Pages/StorePage.swift:padding:_:47:36", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
            }
            .environment(\.colorScheme, isDarkBackground ? .dark : .light)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTransition(.zoom(sourceID: merchantId, in: namespace))
        } else {
            Text("Store not found")
                .foregroundStyle(PurlTune.token("Pages/StorePage.swift:foregroundStyle:_:55:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                .navigationBarHidden(true)
        }
        }
        .purlInjectable()
    }

    // MARK: - Floating Header (over hero)

    @ViewBuilder
    private func floatingHeader(merchant: SampleMerchant) -> some View {
        HStack {
            // Hamburger menu button
            glassCircleButton(icon: .hamburgerMenu, merchant: merchant)

            Spacer()

            // Follow pill + share button
            HStack(spacing: GravitySpacing.space8) {
                Text("Follow")
                    .gravityTextStyle(GravityTypography.buttonMedium)
                    .foregroundStyle(PurlTune.token("Pages/StorePage.swift:foregroundStyle:_:76:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .padding(.horizontal, PurlTune.token("Pages/StorePage.swift:padding:_:77:43", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
                    .padding(.vertical, PurlTune.token("Pages/StorePage.swift:padding:_:78:41", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                    .glassEffect(.regular.tint(merchant.primaryColor.opacity(PurlTune.value("Pages/StorePage.swift:opacity:_:79:78", default: 0.15))), in: .capsule)
                    .onTapGesture {
                        HapticFeedback.light.fire()
                    }

                glassCircleButton(icon: .share, merchant: merchant)
            }
        }
        .padding(.horizontal, contentPadding)
    }

    @ViewBuilder
    private func glassCircleButton(icon: GravityIcon, merchant: SampleMerchant) -> some View {
        icon.image
            .resizable()
            .scaledToFit()
            .frame(width: PurlTune.value("Pages/StorePage.swift:frame:width:95:27", default: 20), height: PurlTune.value("Pages/StorePage.swift:frame:height:95:107", default: 20))
            .foregroundStyle(PurlTune.token("Pages/StorePage.swift:foregroundStyle:_:96:30", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
            .frame(width: PurlTune.value("Pages/StorePage.swift:frame:width:97:27", default: 44), height: PurlTune.value("Pages/StorePage.swift:frame:height:97:107", default: 44))
            .contentShape(Circle())
            .glassEffect(.regular.interactive().tint(merchant.primaryColor.opacity(PurlTune.value("Pages/StorePage.swift:opacity:_:99:84", default: 0.15))), in: .circle)
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(merchant: SampleMerchant) -> some View {
        GeometryReader { geo in
            ZStack {
                // Background media — constrained to device width
                Color.clear
                    .background {
                        if merchant.hasVideos, let url = merchant.bestVideoURL {
                            LoopingVideoPlayer(url: url)
                        } else {
                            MerchantCoverImage(merchant: merchant)
                        }
                    }
                    .clipped()

                // Bottom gradient: transparent → brand color → bg
                VStack {
                    Spacer()
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: merchant.brandColor.opacity(PurlTune.value("Pages/StorePage.swift:opacity:_:125:70", default: 0.6)), location: 0.55),
                            .init(color: merchant.brandColor, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: PurlTune.value("Pages/StorePage.swift:frame:height:131:36", default: 260))
                }

                // Centered branding
                VStack(spacing: GravitySpacing.space4) {
                    Spacer()

                    // Wordmark or merchant name
                    if merchant.bestWordmarkURL != nil {
                        MerchantWordmarkImage(merchant: merchant, maxHeight: 80, maxWidth: 220)
                    } else {
                        Text(merchant.name)
                            .gravityTextStyle(GravityTypography.heroBold)
                            .foregroundStyle(.white)
                    }

                    // Rating info
                    HStack(spacing: GravitySpacing.space4) {
                        GravityIcon.starFilled.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: PurlTune.value("Pages/StorePage.swift:frame:width:152:43", default: 20), height: PurlTune.value("Pages/StorePage.swift:frame:height:152:124", default: 20))
                            .foregroundStyle(.white)

                        Text(String(format: "%.1f", merchant.rating))
                            .gravityTextStyle(GravityTypography.bodyTitleSmall)
                            .foregroundStyle(.white)

                        Text("\(merchant.totalReviews) Reviews")
                            .gravityTextStyle(GravityTypography.bodySmall)
                            .foregroundStyle(.white.opacity(PurlTune.value("Pages/StorePage.swift:opacity:_:161:61", default: 0.8)))
                    }

                    Spacer()
                        .frame(height: PurlTune.value("Pages/StorePage.swift:frame:height:165:40", default: 140))
                }
            }
            .frame(width: geo.size.width, height: PurlTune.value("Pages/StorePage.swift:frame:height:168:51", default: 460))
        }
        .frame(height: PurlTune.value("Pages/StorePage.swift:frame:height:170:24", default: 460))
    }

    // MARK: - Store Content (chips + grid)

    @ViewBuilder
    private func storeContent(merchant: SampleMerchant) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            // Filter chips
            filterChips(merchant: merchant)

            // Product grid
            productGrid(merchant: merchant)
        }
        .padding(.top, PurlTune.token("Pages/StorePage.swift:padding:_:184:24", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        .padding(.bottom, PurlTune.value("Pages/StorePage.swift:padding:_:185:27", default: 100))
    }

    // MARK: - Filter Chips

    @ViewBuilder
    private func filterChips(merchant: SampleMerchant) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space4) {
                // Filter icon chip
                GravityIcon.filterFilled.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: PurlTune.value("Pages/StorePage.swift:frame:width:198:35", default: 16), height: PurlTune.value("Pages/StorePage.swift:frame:height:198:116", default: 16))
                    .foregroundStyle(PurlTune.token("Pages/StorePage.swift:foregroundStyle:_:199:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .frame(width: PurlTune.value("Pages/StorePage.swift:frame:width:200:35", default: 40), height: PurlTune.value("Pages/StorePage.swift:frame:height:200:116", default: 40))
                    .glassEffect(.regular.tint(merchant.primaryColor.opacity(PurlTune.value("Pages/StorePage.swift:opacity:_:201:78", default: 0.1))), in: .capsule)

                // Text chips
                ForEach(["Sort by", "On sale", "In stock", "Price"], id: \.self) { label in
                    Text(label)
                        .gravityTextStyle(GravityTypography.buttonMedium)
                        .foregroundStyle(PurlTune.token("Pages/StorePage.swift:foregroundStyle:_:207:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        .padding(.horizontal, PurlTune.token("Pages/StorePage.swift:padding:_:208:47", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
                        .padding(.vertical, PurlTune.token("Pages/StorePage.swift:padding:_:209:45", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                        .glassEffect(.regular.tint(merchant.primaryColor.opacity(PurlTune.value("Pages/StorePage.swift:opacity:_:210:82", default: 0.1))), in: .capsule)
                }
            }
            .padding(.horizontal, contentPadding)
            .padding(.vertical, PurlTune.token("Pages/StorePage.swift:padding:_:214:33", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
        }
        .scrollClipDisabled()
    }

    // MARK: - Product Grid

    @ViewBuilder
    private func productGrid(merchant: SampleMerchant) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: GravitySpacing.space8),
            GridItem(.flexible(), spacing: GravitySpacing.space8),
        ]

        LazyVGrid(columns: columns, spacing: GravitySpacing.space16) {
            ForEach(merchant.products) { product in
                NavigationLink(value: HomeRoute.product(merchantId: merchant.id, productId: product.id)) {
                    ProductCard(
                        image: nil,
                        imageURL: product.imageURL,
                        merchantName: merchant.name,
                        productName: product.title,
                        rating: merchant.rating,
                        ratingCount: merchant.totalRatings,
                        price: formatPrice(product.price)
                    )
                    .matchedTransitionSource(id: product.id, in: namespace)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, contentPadding)
    }

}

// MARK: - Preview

private struct StorePagePreview: View {
    @Namespace private var ns
    var body: some View {
        let merchant = SampleMerchant.all[0]
        NavigationStack {
            StorePage(merchantId: merchant.id, namespace: ns)
        }
        .environment(NavigationCoordinator())
    }
}

#Preview {
    StorePagePreview()
}
