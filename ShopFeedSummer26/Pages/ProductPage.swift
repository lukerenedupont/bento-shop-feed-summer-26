import SwiftUI

/// Full-screen product detail page matching the Figma PDP design.
struct ProductPage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @Environment(NavigationCoordinator.self) private var coordinator
    let merchantId: String
    let productId: Int
    let namespace: Namespace.ID

    /// Optional agent product — when set, overrides merchant/product lookup.
    private var agentProduct: AgentProduct?
    private var agentReason: String?

    @State private var productImageFrame: CGRect = .zero
    @State private var loadedProductImage: UIImage?

    /// Consistent content gutter on both sides.
    private let contentPadding: CGFloat = GravitySpacing.space20

    // MARK: - Standard init (merchant data)

    init(merchantId: String, productId: Int, namespace: Namespace.ID) {
        self.merchantId = merchantId
        self.productId = productId
        self.namespace = namespace
        self.agentProduct = nil
        self.agentReason = nil
    }

    // MARK: - Agent init (real product data)

    init(agentProduct: AgentProduct, reason: String? = nil, namespace: Namespace.ID) {
        self.agentProduct = agentProduct
        self.agentReason = reason
        self.namespace = namespace
        // Create a synthetic merchant/product ID for compatibility
        self.merchantId = agentProduct.shopName ?? "agent"
        self.productId = agentProduct.id.hashValue
    }

    private var merchant: SampleMerchant? {
        if agentProduct != nil { return agentMerchant }
        return SampleMerchant.byId[merchantId]
    }

    private var product: SampleMerchant.Product? {
        if let ap = agentProduct { return agentToProduct(ap) }
        return merchant?.products.first { $0.id == productId }
    }

    /// Synthesize a SampleMerchant from AgentProduct data.
    private var agentMerchant: SampleMerchant? {
        guard let ap = agentProduct else { return nil }
        return SampleMerchant(
            id: ap.shopName ?? "agent",
            name: ap.shopName ?? "Shop",
            description: "",
            rating: ap.rating ?? 0,
            totalRatings: ap.ratingCount ?? 0,
            totalReviews: ap.ratingCount ?? 0,
            primaryColor: .gray,
            secondaryColor: .gray,
            collections: [],
            products: [],
            featuredImageURLs: [],
            logoImageURL: ap.shopLogoURL?.absoluteString,
            wordmarkImageURL: nil,
            coverImageURL: nil,
            videoURL: nil,
            coverDominantColor: nil,
            productCategory: nil
        )
    }

    /// Convert AgentProduct to SampleMerchant.Product for view compatibility.
    private func agentToProduct(_ ap: AgentProduct) -> SampleMerchant.Product {
        SampleMerchant.Product(
            id: ap.id.hashValue,
            title: ap.title,
            price: ap.price.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: ""),
            handle: "",
            productType: nil,
            vendor: ap.shopName ?? "",
            imageURL: ap.imageURL?.absoluteString,
            shopURL: nil,
            tags: [],
            allImageURLs: ap.allImageURLs.map { $0.absoluteString },
            currencyCode: "USD",
            productDescription: agentReason
        )
    }

    var body: some View {
        Group {
        if let merchant, let product {
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .top) {
                    // Background layer: merchant brand color extends behind status bar
                    VStack(spacing: 0) {
                        merchant.brandColor
                            .overlay(Color.black.opacity(PurlTune.value("Pages/ProductPage.swift:opacity:_:101:58", default: 0.2)))
                            .frame(height: PurlTune.value("Pages/ProductPage.swift:frame:height:102:44", default: 260))
                        Spacer(minLength: 0)
                    }

                    // Foreground content
                    VStack(spacing: 0) {
                        // A. Branded Top Bar (in the colored area)
                        brandedTopBar(merchant: merchant, product: product)

                        // B–I. Rounded white container with image + all content
                        productContainer(merchant: merchant, product: product)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            // The floating back chip's top bar triggers a scroll-edge blur
            // that smears the merchant identity row; the branded header
            // provides its own contrast, so hide the effect entirely.
            .scrollEdgeEffectHidden(for: .top)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, offset in
                coordinator.updateScrollOffset(offset)
            }
            .onAppear {
                preloadProductImage()
            }
            .background(PurlTune.token("Pages/ProductPage.swift:background:_:125:25", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        } else {
            Text("Product not found")
                .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:131:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                .navigationBarHidden(true)
        }
        }
        .purlInjectable()
    }

    // MARK: - A. Branded Top Bar

    /// Compact count formatter: 1234 → "1.2K", 124200 → "124.2K", 999 → "999"
    private func formattedCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    @ViewBuilder
    private func brandedTopBar(merchant: SampleMerchant, product: SampleMerchant.Product) -> some View {
        // Push content below the status bar
        VStack(spacing: 0) {
            Color.clear.frame(height: PurlTune.value("Pages/ProductPage.swift:frame:height:154:39", default: 63)) // status bar + dynamic island clearance

            Group {
                // Merchant info centered — the floating back chip owns the
                // leading corner, overflow stays trailing.
                ZStack {
                    merchantInfoButton(merchant: merchant, product: product)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Button {
                            HapticFeedback.light.fire()
                            coordinator.popCurrentPage()
                        } label: {
                            GravityIcon.arrowLeft.image
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundStyle(GravityColors.text)
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")

                        Spacer()

                        GravityIcon.overflow.image
                            .resizable()
                            .frame(width: PurlTune.value("Pages/ProductPage.swift:frame:width:165:39", default: 20), height: PurlTune.value("Pages/ProductPage.swift:frame:height:165:122", default: 20))
                            .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:166:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                            .frame(width: PurlTune.value("Pages/ProductPage.swift:frame:width:167:39", default: 44), height: PurlTune.value("Pages/ProductPage.swift:frame:height:167:122", default: 44))
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                }
            }
            .padding(.horizontal, contentPadding)
            .padding(.bottom, PurlTune.token("Pages/ProductPage.swift:padding:_:172:31", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        }
    }

    @ViewBuilder
    private func merchantInfoButton(merchant: SampleMerchant, product: SampleMerchant.Product) -> some View {
        Button {
            coordinator.pushRoute(.store(merchantId: merchantId))
        } label: {
            HStack(spacing: 0) {
                MerchantAvatarView(merchant: merchant, size: 32, borderColor: .white.opacity(PurlTune.value("Pages/ProductPage.swift:opacity:_:182:94", default: 0.4)), borderWidth: 1)

                VStack(alignment: .leading, spacing: 0) {
                    Text(merchant.name)
                        .gravityTextStyle(GravityTypography.bodyTitleSmall)
                        .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:187:42", default: GravityColors.textFixedLight, options: GravityColors.purlTuneColorOptions))
                        .lineLimit(1)

                    if !isCanonicalCatalogProduct(product) {
                        HStack(spacing: GravitySpacing.space2) {
                            Text(String(format: "%.1f", merchant.rating))
                                .gravityTextStyle(GravityTypography.caption)
                                .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:193:46", default: GravityColors.textFixedLight, options: GravityColors.purlTuneColorOptions))

                            GravityIcon.starFilled.image
                                .resizable()
                                .frame(width: PurlTune.value("Pages/ProductPage.swift:frame:width:197:43", default: 12), height: PurlTune.value("Pages/ProductPage.swift:frame:height:197:126", default: 12))
                                .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:198:46", default: GravityColors.textFixedLight, options: GravityColors.purlTuneColorOptions))

                            Text("(\(formattedCount(merchant.totalRatings)))")
                                .gravityTextStyle(GravityTypography.caption)
                                .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:202:46", default: GravityColors.textFixedLight, options: GravityColors.purlTuneColorOptions))
                        }
                    }
                }
                .padding(.leading, PurlTune.token("Pages/ProductPage.swift:padding:_:205:36", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
            }
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: merchantId, in: namespace)
    }

    // MARK: - B–I. Product Container (rounded top, white background)

    @ViewBuilder
    private func productContainer(merchant: SampleMerchant, product: SampleMerchant.Product) -> some View {
        VStack(spacing: 0) {
            // B. Product Image (fills rounded top, edge-to-edge within container)
            productImage(merchant: merchant, product: product)

            // All content below image with consistent 20px gutters
            VStack(alignment: .leading, spacing: GravitySpacing.space24) {
                // D. Product Info
                productInfoSection(merchant: merchant, product: product)

                // E. Price
                priceSection(product: product)

                // I. Buy Buttons (above cards)
                buyButtons

                // F. Delivery & Returns
                if !isCanonicalCatalogProduct(product) {
                    deliveryCard
                }

                // G. Description
                descriptionCard(merchant: merchant, product: product)

                // H. Reviews
                if !isCanonicalCatalogProduct(product) {
                    reviewsCard(merchant: merchant)
                }
            }
            .padding(.top, PurlTune.token("Pages/ProductPage.swift:padding:_:240:28", default: GravitySpacing.space20, options: GravitySpacing.purlTuneOptions))
            .padding(.horizontal, contentPadding)
            .padding(.bottom, PurlTune.value("Pages/ProductPage.swift:padding:_:242:31", default: 80)) // clear the DynamicNavBar
        }
        .background(PurlTune.token("Pages/ProductPage.swift:background:_:244:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: GravityRadius.r28,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: GravityRadius.r28
            )
        )
    }

    // MARK: - B. Product Image Gallery

    @State private var selectedImageIndex = 0

    @ViewBuilder
    private func productImage(merchant: SampleMerchant, product: SampleMerchant.Product) -> some View {
        let imageURLs = product.allImageURLs.count > 1
            ? Array(product.allImageURLs.prefix(6))
            : [product.imageURL].compactMap { $0 }

        ZStack(alignment: .bottom) {
            if imageURLs.count > 1 {
                // Swipeable gallery
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, urlString in
                            if let url = URL(string: urlString) {
                                CachedAsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    case .failure:
                                        Rectangle().fill(merchant.brandColor.opacity(PurlTune.value("Pages/ProductPage.swift:opacity:_:277:86", default: 0.1)))
                                    default:
                                        Rectangle().fill(PurlTune.token("Pages/ProductPage.swift:fill:_:279:58", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                                    }
                                }
                                .frame(width: UIScreen.main.bounds.width, height: PurlTune.value("Pages/ProductPage.swift:frame:height:282:83", default: 423))
                                .clipped()
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .frame(height: PurlTune.value("Pages/ProductPage.swift:frame:height:290:32", default: 423))
                .overlay(Color.black.opacity(PurlTune.value("Pages/ProductPage.swift:opacity:_:291:46", default: 0.04)))
                .navigationTransition(.zoom(sourceID: productId, in: namespace))
                .background(
                    GeometryReader { imageGeo in
                        Color.clear
                            .onAppear { productImageFrame = imageGeo.frame(in: .global) }
                            .onChange(of: imageGeo.frame(in: .global)) { _, newFrame in productImageFrame = newFrame }
                    }
                )
            } else {
                // Single image
                GeometryReader { geo in
                    ProductImageView(product: product, merchant: merchant)
                        .frame(width: geo.size.width, height: PurlTune.value("Pages/ProductPage.swift:frame:height:304:63", default: 423))
                        .clipped()
                        .overlay(Color.black.opacity(PurlTune.value("Pages/ProductPage.swift:opacity:_:306:54", default: 0.04)))
                        .background(
                            GeometryReader { imageGeo in
                                Color.clear
                                    .onAppear { productImageFrame = imageGeo.frame(in: .global) }
                                    .onChange(of: imageGeo.frame(in: .global)) { _, newFrame in productImageFrame = newFrame }
                            }
                        )
                }
                .frame(height: PurlTune.value("Pages/ProductPage.swift:frame:height:315:32", default: 423))
                .navigationTransition(.zoom(sourceID: productId, in: namespace))
            }

            // Pagination dots
            if imageURLs.count > 1 {
                HStack(spacing: GravitySpacing.space6) {
                    ForEach(0..<imageURLs.count, id: \.self) { index in
                        Circle()
                            .fill(index == selectedImageIndex ? Color.white : Color.white.opacity(PurlTune.value("Pages/ProductPage.swift:opacity:_:324:99", default: 0.4)))
                            .frame(width: index == selectedImageIndex ? 8 : 6, height: index == selectedImageIndex ? 8 : 6)
                            .animation(.spring(response: PurlTune.value("Pages/ProductPage.swift:spring:response:326:58", default: 0.25)), value: selectedImageIndex)
                    }
                }
                .padding(.bottom, PurlTune.token("Pages/ProductPage.swift:padding:_:329:35", default: GravitySpacing.space24, options: GravitySpacing.purlTuneOptions))
            }
        }
    }

    // MARK: - D. Product Info

    @ViewBuilder
    private func productInfoSection(merchant: SampleMerchant, product: SampleMerchant.Product) -> some View {
        // Text content flows naturally; buttons overlay top-trailing
        VStack(alignment: .leading, spacing: GravitySpacing.space2) {
            Text(product.title)
                .gravityTextStyle(GravityTypography.subtitle)
                .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:342:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                .lineLimit(3)
                // Reserve space so text doesn't run under the buttons
                .padding(.trailing, PurlTune.value("Pages/ProductPage.swift:padding:_:345:37", default: 104)) // 44 + 8 + 44 + 8

            // Rating row tucks right under the title
            if !isCanonicalCatalogProduct(product) {
                HStack(spacing: GravitySpacing.space4) {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            GravityIcon.starFilled.image
                                .resizable()
                                .frame(width: PurlTune.value("Pages/ProductPage.swift:frame:width:353:43", default: 12), height: PurlTune.value("Pages/ProductPage.swift:frame:height:353:126", default: 12))
                                .foregroundStyle(index < Int(merchant.rating.rounded()) ? GravityColors.iconStars : GravityColors.bgFillSecondary)
                        }
                    }
                    Text(String(format: "%.1f", merchant.rating))
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:359:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                    Text("(\(formattedCount(merchant.totalRatings)))")
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:362:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                }
            }

            // Badges
            productBadges(product: product)
                .padding(.top, PurlTune.token("Pages/ProductPage.swift:padding:_:367:32", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            // Floating action buttons pinned to the actual trailing edge
            HStack(spacing: GravitySpacing.space8) {
                glassIconButton(icon: .share)
                glassIconButton(icon: .favorites)
            }
        }
    }

    /// Circular glass-style icon button (44×44, white 85% opacity) matching Figma PDP.
    @ViewBuilder
    private func glassIconButton(icon: GravityIcon) -> some View {
        Button {
            HapticFeedback.light.fire()
        } label: {
            icon.image
                .resizable()
                .frame(width: PurlTune.value("Pages/ProductPage.swift:frame:width:387:31", default: 20), height: PurlTune.value("Pages/ProductPage.swift:frame:height:387:114", default: 20))
                .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:388:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                .frame(width: PurlTune.value("Pages/ProductPage.swift:frame:width:389:31", default: 44), height: PurlTune.value("Pages/ProductPage.swift:frame:height:389:114", default: 44))
                .background(Color.white.opacity(PurlTune.value("Pages/ProductPage.swift:opacity:_:390:49", default: 0.85)))
                .clipShape(Circle())
                .gravityShadow(GravityShadows.small)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func productBadges(product: SampleMerchant.Product) -> some View {
        let badges = generateBadges(for: product)
        if !badges.isEmpty {
            HStack(spacing: GravitySpacing.space4) {
                ForEach(Array(badges.enumerated()), id: \.offset) { index, badge in
                    Text(badge.text)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(badge.isUrgent ? GravityColors.textCritical : GravityColors.text)
                        .padding(.horizontal, PurlTune.token("Pages/ProductPage.swift:padding:_:406:47", default: GravitySpacing.space6, options: GravitySpacing.purlTuneOptions))
                        .padding(.vertical, PurlTune.token("Pages/ProductPage.swift:padding:_:407:45", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
                        .background(badge.isUrgent ? GravityColors.bgFillCriticalSecondary : GravityColors.bgFillSecondary)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private struct ProductBadge: Hashable {
        let text: String
        let isUrgent: Bool
    }

    /// Products added from buyer evidence carry verified catalog fields only.
    /// Prototype-only commerce claims must not bleed into those PDPs.
    private func isCanonicalCatalogProduct(_ product: SampleMerchant.Product) -> Bool {
        product.tags.contains("canonical-catalog")
    }

    /// Deterministic but varied badge generation — not every product gets every badge.
    private func generateBadges(for product: SampleMerchant.Product) -> [ProductBadge] {
        guard !isCanonicalCatalogProduct(product) else { return [] }
        let seed = abs(product.id)
        var badges: [ProductBadge] = []

        // ~30% of products get an urgency badge
        if seed % 10 < 3 {
            let remaining = 1 + (seed % 4) // 1–4 left
            badges.append(ProductBadge(text: "Only \(remaining) left", isUrgent: true))
        }

        // ~50% get a social proof badge
        if seed % 6 < 3 {
            let bought = (seed % 9 + 1) * 100
            badges.append(ProductBadge(text: "\(bought)+ bought in past month", isUrgent: false))
        }

        // ~40% get a status badge
        if seed % 5 < 2 {
            let extras = ["Bestseller", "Popular", "New arrival", "Trending"]
            badges.append(ProductBadge(text: extras[seed % extras.count], isUrgent: false))
        }

        // If nothing was picked, give one neutral badge from product type or fallback
        if badges.isEmpty {
            if let type = product.productType, !type.isEmpty {
                badges.append(ProductBadge(text: type, isUrgent: false))
            } else {
                badges.append(ProductBadge(text: "Popular", isUrgent: false))
            }
        }

        return Array(badges.prefix(3))
    }

    // MARK: - E. Price Section

    /// Whether this product shows a sale price (~40% of products).
    private func hasDiscount(for product: SampleMerchant.Product) -> Bool {
        !isCanonicalCatalogProduct(product) && abs(product.id) % 5 < 2
    }

    private func discountPercent(for product: SampleMerchant.Product) -> Int {
        10 + (abs(product.id) % 16)
    }

    /// Whether this product qualifies for free shipping (price > $100).
    private func hasFreeShipping(for product: SampleMerchant.Product) -> Bool {
        !isCanonicalCatalogProduct(product) && (Double(product.price) ?? 0) >= 100
    }

    /// Format a price with the product's currency symbol.
    private func formattedPrice(_ value: String, currencyCode: String) -> String {
        let symbol: String
        switch currencyCode {
        case "USD": symbol = "$"
        case "CAD": symbol = "CA$"
        case "GBP": symbol = "£"
        case "EUR": symbol = "€"
        case "AUD": symbol = "A$"
        default: symbol = "$"
        }
        if let dbl = Double(value) {
            return String(format: "\(symbol)%.2f", dbl)
        }
        return "\(symbol)\(value)"
    }

    @ViewBuilder
    private func priceSection(product: SampleMerchant.Product) -> some View {
        let showDiscount = hasDiscount(for: product)
        let discount = discountPercent(for: product)
        let priceValue = Double(product.price) ?? 0
        let originalPrice = priceValue / (1.0 - Double(discount) / 100.0)
        let currency = product.currencyCode

        VStack(alignment: .leading, spacing: GravitySpacing.space4) {
            HStack(alignment: .firstTextBaseline, spacing: GravitySpacing.space8) {
                Text(formattedPrice(product.price, currencyCode: currency))
                    .gravityTextStyle(GravityTypography.subtitle)
                    .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:500:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))

                if showDiscount {
                    Text(formattedPrice(String(format: "%.2f", originalPrice), currencyCode: currency))
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:505:42", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
                        .strikethrough()

                    Text("\(discount)% off")
                        .gravityTextStyle(GravityTypography.captionMedium)
                        .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:510:42", default: GravityColors.textCritical, options: GravityColors.purlTuneColorOptions))
                }
            }

            if hasFreeShipping(for: product) {
                Text("FREE shipping on $100+")
                    .gravityTextStyle(GravityTypography.caption)
                    .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:517:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
            }
        }
    }

    // MARK: - F. Delivery & Returns Card

    private var deliveryCard: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            Text("Delivery & returns")
                .gravityTextStyle(GravityTypography.subtitle)
                .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:528:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))

            VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                deliveryRow(icon: .mapPinFilled, text: "Ship to 06443")
                deliveryRow(icon: .truckFilled, text: "FREE shipping on orders $100+")
                deliveryRow(icon: .calendarFilled, text: "Arrives as soon as \(arrivalDateString)")
                deliveryRow(icon: .returnPackage, text: "Returns accepted within 14 days")
            }
        }
        .padding(PurlTune.token("Pages/ProductPage.swift:padding:_:537:18", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PurlTune.token("Pages/ProductPage.swift:background:_:539:21", default: GravityColors.bgFill, options: GravityColors.purlTuneColorOptions))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r28)
                .stroke(GravityColors.borderSecondary, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28))
        .gravityShadow(GravityShadows.small)
    }

    @ViewBuilder
    private func deliveryRow(icon: GravityIcon, text: String) -> some View {
        HStack(spacing: GravitySpacing.space12) {
            icon.image
                .resizable()
                .frame(width: PurlTune.value("Pages/ProductPage.swift:frame:width:553:31", default: 20), height: PurlTune.value("Pages/ProductPage.swift:frame:height:553:114", default: 20))
                .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:554:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))

            Text(text)
                .gravityTextStyle(GravityTypography.bodySmall)
                .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:558:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
        }
    }

    private static let arrivalDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var arrivalDateString: String {
        let dayOffset = 5 + (abs(productId) % 4) // deterministic 5-8 days
        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: .now) ?? .now
        return Self.arrivalDateFormatter.string(from: date)
    }

    // MARK: - G. Description Card

    @ViewBuilder
    private func descriptionCard(merchant: SampleMerchant, product: SampleMerchant.Product) -> some View {
        let descriptionText = product.productDescription ?? merchant.description

        if !descriptionText.isEmpty {
            VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                Text("Description")
                    .gravityTextStyle(GravityTypography.subtitle)
                    .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:584:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))

                Text(descriptionText)
                    .gravityTextStyle(GravityTypography.bodySmall)
                    .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:588:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                    .lineLimit(3)

                Text("Read more")
                    .gravityTextStyle(GravityTypography.bodySmallBold)
                    .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:593:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
            }
            .padding(PurlTune.token("Pages/ProductPage.swift:padding:_:595:22", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PurlTune.token("Pages/ProductPage.swift:background:_:597:25", default: GravityColors.bgFill, options: GravityColors.purlTuneColorOptions))
            .overlay(
                RoundedRectangle(cornerRadius: GravityRadius.r28)
                    .stroke(GravityColors.borderSecondary, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28))
            .gravityShadow(GravityShadows.small)
        }
    }

    // MARK: - H. Reviews Card

    @ViewBuilder
    private func reviewsCard(merchant: SampleMerchant) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            Text("Reviews")
                .gravityTextStyle(GravityTypography.subtitle)
                .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:614:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))

            // Rating summary + histogram
            HStack(alignment: .top, spacing: GravitySpacing.space20) {
                // Left: big rating
                VStack(spacing: GravitySpacing.space4) {
                    Text(String(format: "%.1f", merchant.rating))
                        .gravityTextStyle(GravityTypography.heroBold)
                        .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:622:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))

                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            GravityIcon.starFilled.image
                                .resizable()
                                .frame(width: PurlTune.value("Pages/ProductPage.swift:frame:width:628:47", default: 16), height: PurlTune.value("Pages/ProductPage.swift:frame:height:628:130", default: 16))
                                .foregroundStyle(index < Int(merchant.rating.rounded()) ? GravityColors.iconStars : GravityColors.bgFillSecondary)
                        }
                    }

                    Text("\(merchant.totalRatings) ratings")
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:635:42", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                }

                // Right: histogram
                VStack(spacing: GravitySpacing.space4) {
                    ForEach((1...5).reversed(), id: \.self) { star in
                        reviewHistogramBar(star: star, rating: merchant.rating)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Text("Review detail is not available from the current live product payload.")
                .gravityTextStyle(GravityTypography.caption)
                .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:649:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                .padding(.top, PurlTune.token("Pages/ProductPage.swift:padding:_:650:32", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        }
        .padding(PurlTune.token("Pages/ProductPage.swift:padding:_:652:18", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PurlTune.token("Pages/ProductPage.swift:background:_:654:21", default: GravityColors.bgFill, options: GravityColors.purlTuneColorOptions))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r28)
                .stroke(GravityColors.borderSecondary, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28))
        .gravityShadow(GravityShadows.small)
    }

    @ViewBuilder
    private func reviewHistogramBar(star: Int, rating: Double) -> some View {
        let fraction = approximateDistribution(star: star, rating: rating)
        HStack(spacing: GravitySpacing.space8) {
            Text("\(star)")
                .gravityTextStyle(GravityTypography.caption)
                .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:669:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                .frame(width: PurlTune.value("Pages/ProductPage.swift:frame:width:670:31", default: 12), alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PurlTune.token("Pages/ProductPage.swift:fill:_:675:31", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))

                    Capsule()
                        .fill(PurlTune.token("Pages/ProductPage.swift:fill:_:678:31", default: GravityColors.bgFillInverse, options: GravityColors.purlTuneColorOptions))
                        .frame(width: max(geo.size.width * fraction, 0))
                }
            }
            .frame(height: PurlTune.value("Pages/ProductPage.swift:frame:height:682:28", default: 8))
        }
    }

    private func approximateDistribution(star: Int, rating: Double) -> Double {
        let center = rating
        let diff = abs(Double(star) - center)
        if diff < 0.5 { return 0.85 }
        if diff < 1.0 { return 0.55 }
        if diff < 1.5 { return 0.30 }
        if diff < 2.5 { return 0.12 }
        return 0.05
    }

    // MARK: - I. Buy Buttons (inline in scroll content)

    private var buyButtons: some View {
        VStack(spacing: GravitySpacing.space8) {
            Button {
                HapticFeedback.medium.fire()
                if let product, let snapshot = loadedProductImage {
                } else if let product {
                }
            } label: {
                Text("Add to cart")
                    .gravityTextStyle(GravityTypography.buttonLarge)
                    .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:708:38", default: GravityColors.textFixedLight, options: GravityColors.purlTuneColorOptions))
                    .frame(maxWidth: .infinity)
                    .frame(height: PurlTune.value("Pages/ProductPage.swift:frame:height:710:36", default: 52))
                    .background(PurlTune.token("Pages/ProductPage.swift:background:_:711:33", default: GravityColors.bgFillBrand, options: GravityColors.purlTuneColorOptions))
                    .clipShape(Capsule())
                    .gravityShadow(GravityShadows.small)
            }

            Button {
                HapticFeedback.medium.fire()
            } label: {
                Text("Buy now")
                    .gravityTextStyle(GravityTypography.buttonLarge)
                    .foregroundStyle(PurlTune.token("Pages/ProductPage.swift:foregroundStyle:_:721:38", default: GravityColors.textFixedLight, options: GravityColors.purlTuneColorOptions))
                    .frame(maxWidth: .infinity)
                    .frame(height: PurlTune.value("Pages/ProductPage.swift:frame:height:723:36", default: 52))
                    .background(PurlTune.token("Pages/ProductPage.swift:background:_:724:33", default: GravityColors.bgFillInverse, options: GravityColors.purlTuneColorOptions))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Image Preload

    private func preloadProductImage() {
        guard let urlString = product?.imageURL, let url = URL(string: urlString) else { return }
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                loadedProductImage = image
            }
        }
    }
}

// MARK: - Preview

private struct ProductPagePreview: View {
    @Namespace private var ns
    var body: some View {
        let merchant = SampleMerchant.all[0]
        let product = merchant.products[0]
        NavigationStack {
            ProductPage(merchantId: merchant.id, productId: product.id, namespace: ns)
        }
        .environment(NavigationCoordinator())
    }
}

#Preview {
    ProductPagePreview()
}
