import SwiftUI

// MARK: - Data Model

struct DeliveryItem: Identifiable {
    let id: String
    let merchantId: String
    let products: [SampleMerchant.Product]
    let status: DeliveryStatus
    let isStale: Bool
}

enum DeliveryStatus {
    case labelCreated(headline: String)
    case inTransit(headline: String)
    case outForDelivery(headline: String)
    case delivered(date: String)
}

// MARK: - Top-of-feed utility cards

enum UtilityRailMetrics {
    static let cardHeight: CGFloat = 148
    static let expandedCardHeight: CGFloat = cardHeight * 1.76
    static let compactCardWidth: CGFloat = 228
    static let cornerRadius: CGFloat = 24
    static let carouselVerticalPadding: CGFloat = 8

    static func expansionProgress(for height: CGFloat) -> CGFloat {
        let travel = expandedCardHeight - cardHeight
        return min(max((height - cardHeight) / travel, 0), 1)
    }
}

/// Shared title treatment for every utility-belt card.
struct UtilityRailCardHeader: View {
    let title: String

    var body: some View {
        HStack(alignment: .bottom, spacing: GravitySpacing.space6) {
            Text(title)
                .gravityTextStyle(GravityTypography.utilityCardTitle)
                .foregroundStyle(GravityColors.text)
                .lineLimit(1)

            Spacer(minLength: 0)

            GravityIcon.boldRightChevron.image
                .resizable()
                .scaledToFit()
                // The Gravity asset already contains the optical inset shown
                // in Figma, so it fills the 24pt control without being scaled twice.
                .frame(width: GravitySpacing.space24, height: GravitySpacing.space24)
                .foregroundStyle(GravityColors.text)
                .background(GravityColors.bgFill, in: Circle())
        }
    }
}

/// Product-based utility card shared by Buy again, Your saves, and Keep
/// shopping. Product count may change width, but never typography or height.
struct UtilityProductRailCard: View {
    let title: String
    let products: [ResolvedStoryProduct]
    let maximumWidth: CGFloat
    let height: CGFloat
    let fill: Color
    let border: Color
    var onSelectProduct: (ResolvedStoryProduct) -> Void

    var body: some View {
        let visibleProducts = Array(products.prefix(6))
        let firstRow = Array(visibleProducts.prefix(3))
        let secondRow = Array(visibleProducts.dropFirst(3).prefix(3))
        let productCount = max(firstRow.count, 1)
        let width = cardWidth(productCount: productCount)
        let availableWidth = width - (GravitySpacing.space12 * 2)
        let rowSpacing = GravitySpacing.space8 * CGFloat(productCount - 1)
        let tileSize = (availableWidth - rowSpacing) / CGFloat(productCount)
        let expansionProgress = UtilityRailMetrics.expansionProgress(for: height)
        let secondRowReveal = min(max((expansionProgress - 0.28) / 0.72, 0), 1)

        VStack(alignment: .leading, spacing: 0) {
            UtilityRailCardHeader(title: title)
                .padding(.horizontal, GravitySpacing.space2)

            Spacer(minLength: 0)

            VStack(spacing: GravitySpacing.space8 * secondRowReveal) {
                productRow(
                    firstRow,
                    tileSize: tileSize
                )

                if !secondRow.isEmpty {
                    productRow(
                        secondRow,
                        tileSize: tileSize
                    )
                    .frame(
                        height: tileSize * secondRowReveal,
                        alignment: .bottom
                    )
                    .clipped()
                }
            }
        }
        .padding(GravitySpacing.space12)
        .frame(width: width, height: height, alignment: .top)
        .utilityRailSurface(fill: fill, border: border)
    }

    private func cardWidth(productCount: Int) -> CGFloat {
        switch productCount {
        case 1, 2:
            // This compact width fits every fixed utility title and lets a
            // single product expand rather than leaving dead space.
            min(maximumWidth, UtilityRailMetrics.compactCardWidth)
        default:
            maximumWidth
        }
    }

    private func productRow(
        _ items: [ResolvedStoryProduct],
        tileSize: CGFloat
    ) -> some View {
        return HStack(spacing: GravitySpacing.space8) {
            ForEach(items) { item in
                Button {
                    HapticFeedback.light.fire()
                    onSelectProduct(item)
                } label: {
                    productTile(item, width: tileSize, height: tileSize)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func productTile(
        _ item: ResolvedStoryProduct,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        ProductImageView(product: item.product, merchant: item.merchant)
            .frame(width: width, height: height)
            .background(Color.black.opacity(0.025))
            .overlay { Color.black.opacity(0.025) }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.035), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.small)
    }
}

/// Lightweight destination marker used only while the order map is expanded.
/// It is code-native so it stays crisp as the utility card scales.
private struct UtilityDestinationPin: View {
    private let fill = LinearGradient(
        colors: [Color(hex: 0x7A4DFF), Color(hex: 0x4F1FE8)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        UtilityDestinationPinShape()
            .fill(fill)
            .frame(width: 32, height: 40)
            .overlay(alignment: .top) {
            Circle()
                .fill(.white)
                    .frame(width: 10, height: 10)
                    .padding(.top, 9)
            }
            .shadow(color: Color.black.opacity(0.14), radius: 3, y: 2)
            .frame(width: 36, height: 44)
    }
}

private struct UtilityDestinationPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        var path = Path()

        path.move(to: CGPoint(x: centerX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.height * 0.42),
            control1: CGPoint(x: rect.width * 0.34, y: rect.height * 0.82),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.64)
        )
        path.addCurve(
            to: CGPoint(x: centerX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.height * 0.16),
            control2: CGPoint(x: rect.width * 0.14, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.42),
            control1: CGPoint(x: rect.width * 0.86, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.16)
        )
        path.addCurve(
            to: CGPoint(x: centerX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.64),
            control2: CGPoint(x: rect.width * 0.66, y: rect.height * 0.82)
        )
        path.closeSubpath()
        return path
    }
}

/// Compact order status used in the top-of-feed utility rail.
///
/// The parent rail owns horizontal paging. This card stays deliberately
/// static so it does not introduce a competing gesture inside that rail.
struct OrderTrackingUtilityCard: View {
    let width: CGFloat
    let height: CGFloat
    var onTap: () -> Void

    private let progressControlSize: CGFloat = 24
    private let orderPanelHeight: CGFloat = 92

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            onTap()
        } label: {
            ZStack {
                orderMap

                // Pull the map back so it reads as context rather than
                // competing with the order status surface.
                GravityColors.bgFill.opacity(0.14)

                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.30), location: 0),
                        .init(color: .clear, location: 0.5),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                destinationCallout

                VStack(alignment: .leading, spacing: 0) {
                    UtilityRailCardHeader(title: "Your orders")
                        .padding(.horizontal, GravitySpacing.space2)

                    Spacer(minLength: 0)

                    orderPanel
                }
                .padding(GravitySpacing.space12)
            }
            .frame(
                width: width,
                height: height,
                alignment: .top
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: UtilityRailMetrics.cornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: UtilityRailMetrics.cornerRadius,
                    style: .continuous
                )
                .strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.orderUtilityRail)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your orders, Baggu, arrives today by 6 PM")
    }

    private var orderMap: some View {
        let expansionProgress = UtilityRailMetrics.expansionProgress(for: height)
        let cropOffset = -UtilityRailMetrics.cardHeight
            * 0.2773
            * (1 - expansionProgress)

        return Image("order-card-map")
            .resizable()
            .scaledToFill()
            .frame(
                width: width + 2,
                height: UtilityRailMetrics.cardHeight * 2.5088 + 2
            )
            .offset(y: cropOffset)
            // Give the raster a one-point bleed on every edge so fractional
            // scaling cannot expose the surface behind it as a hairline.
            .frame(width: width, height: height)
            .clipped()
    }

    private var destinationCallout: some View {
        let mapContentTop = GravitySpacing.space12
            + GravitySpacing.space24
            + GravitySpacing.space8
        let orderPanelTop = UtilityRailMetrics.expandedCardHeight
            - GravitySpacing.space12
            - orderPanelHeight
        let destinationCenterY = (mapContentTop + orderPanelTop) / 2

        return HStack(alignment: .center, spacing: -GravitySpacing.space6) {
            UtilityDestinationPin()
                .zIndex(1)

            VStack(alignment: .leading, spacing: 0) {
                Text("Ships to")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(GravityColors.textSecondary)
                Text("Vendome, FR")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GravityColors.text)
            }
            .padding(.horizontal, GravitySpacing.space10)
            .frame(height: 40)
            .background(
                GravityColors.bgFill,
                in: RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
            )
            .gravityShadow(GravityShadows.small)
        }
        .fixedSize()
        // The destination lives at a fixed map coordinate beneath the order
        // panel. As the panel travels down, its top edge reveals this content
        // directly—there is no independent fade or scale animation.
        .position(
            x: width * 0.54,
            y: destinationCenterY
        )
        .allowsHitTesting(false)
        .accessibilityHidden(
            height < (UtilityRailMetrics.cardHeight + UtilityRailMetrics.expandedCardHeight) / 2
        )
    }

    private var orderPanel: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            HStack(spacing: GravitySpacing.space6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Baggu")
                        .gravityTextStyle(GravityTypography.captionMedium)
                        .foregroundStyle(GravityColors.text)
                    Text("Arrives today by 6PM")
                        .gravityTextStyle(GravityTypography.utilityOrderStatus)
                        .foregroundStyle(GravityColors.text)
                }
                .lineLimit(1)

                Spacer(minLength: 0)

                HStack(spacing: GravitySpacing.space4) {
                    orderProductImage("order-card-product-baggu")
                    orderProductImage("order-card-product-glossier")
                }
            }

            trackingProgress
        }
        .padding(.horizontal, GravitySpacing.space10)
        .padding(.vertical, GravitySpacing.space10)
        .frame(maxWidth: .infinity)
        .frame(height: orderPanelHeight)
        .background(
            GravityColors.bgFill,
            in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
        )
        .gravityShadow(GravityShadows.orderSummary)
    }

    private func orderProductImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: 36, height: 36)
            .background(GravityColors.bgFillSecondary)
            .clipShape(
                RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
                    .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
            }
    }

    private var trackingProgress: some View {
        HStack(spacing: GravitySpacing.space4) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xB350F6), Color(hex: 0x7358EC)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: GravitySpacing.space8)

            deliveryBadge

            Capsule()
                .fill(GravityColors.bgFillSecondary)
                .frame(width: 62.5, height: GravitySpacing.space8)
        }
        .frame(height: progressControlSize)
        .overlay(alignment: .leading) { carrierBadge }
    }

    private var carrierBadge: some View {
        Image("order-card-carrier-gls")
            .resizable()
            .scaledToFill()
            .frame(width: 18, height: 18)
            .clipShape(Circle())
            .padding(GravitySpacing.space2)
            .background(GravityColors.bgFill, in: Circle())
            .overlay { Circle().strokeBorder(GravityColors.borderImage, lineWidth: 0.5) }
            .gravityShadow(GravityShadows.small)
    }

    private var deliveryBadge: some View {
        Image("order-card-delivery-van")
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .frame(width: progressControlSize, height: progressControlSize)
            .background(GravityColors.bgFill, in: Circle())
            .overlay { Circle().strokeBorder(GravityColors.borderImage, lineWidth: 0.5) }
            .gravityShadow(GravityShadows.small)
    }
}

extension View {
    func utilityRailSurface(fill: Color, border: Color) -> some View {
        background(
            fill,
            in: RoundedRectangle(
                cornerRadius: UtilityRailMetrics.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: UtilityRailMetrics.cornerRadius,
                style: .continuous
            )
                .strokeBorder(border, lineWidth: 0.5)
        }
        .gravityShadow(GravityShadows.utilityRail)
    }
}

extension DeliveryItem {
    /// Short summary for compact contexts (e.g. account map card).
    var statusSubtitle: String {
        switch status {
        case .labelCreated(let h): return h
        case .inTransit(let h): return h
        case .outForDelivery(let h): return h
        case .delivered(let date): return "Delivered \(date)"
        }
    }
}

// MARK: - DeliveryCard (Active)

/// Card for an active delivery with merchant info, product thumbnails, status, and progress bar.
/// Supports optional tap-to-navigate to the delivery detail page.
struct DeliveryCard: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let item: DeliveryItem
    var onTap: (() -> Void)? = nil

    private var merchant: SampleMerchant? {
        SampleMerchant.byId[item.merchantId]
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            onTap?()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            // Top row: merchant avatar + name | product thumbnails
            HStack {
                if let merchant {
                    HStack(spacing: GravitySpacing.space8) {
                        MerchantAvatarView(merchant: merchant, size: 24)
                        Text(merchant.name)
                            .gravityTextStyle(GravityTypography.bodyTitleSmall)
                            .foregroundStyle(PurlTune.token("Components/DeliveryCard.swift:foregroundStyle:_:63:46", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: GravitySpacing.space4) {
                    ForEach(item.products.prefix(3)) { product in
                        productThumb(product)
                    }
                }
            }

            // Status headline + subtitle
            VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                Text(headline)
                    .gravityTextStyle(GravityTypography.subtitle)
                    .foregroundStyle(PurlTune.token("Components/DeliveryCard.swift:foregroundStyle:_:80:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                Text(subtitle)
                    .gravityTextStyle(GravityTypography.caption)
                    .foregroundStyle(PurlTune.token("Components/DeliveryCard.swift:foregroundStyle:_:83:38", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
            }

            // Progress bar
            progressBar

            // Mark as delivered button (stale orders)
            if item.isStale {
                Button {
                    HapticFeedback.light.fire()
                } label: {
                    Text("Mark as delivered")
                        .gravityTextStyle(GravityTypography.buttonLarge)
                        .foregroundStyle(PurlTune.token("Components/DeliveryCard.swift:foregroundStyle:_:96:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        .frame(maxWidth: .infinity)
                        .frame(height: PurlTune.value("Components/DeliveryCard.swift:frame:height:98:40", default: 44))
                        .background(GravityColors.bgFillSecondary, in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PurlTune.token("Components/DeliveryCard.swift:padding:_:104:18", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        .background(PurlTune.token("Components/DeliveryCard.swift:background:_:105:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.medium)
    }

    // MARK: - Helpers

    private var headline: String {
        switch item.status {
        case .labelCreated(let h), .inTransit(let h), .outForDelivery(let h):
            return h
        case .delivered(let date):
            return "Delivered \(date)"
        }
    }

    private var subtitle: String {
        switch item.status {
        case .labelCreated: return "Label created"
        case .inTransit: return "In transit"
        case .outForDelivery: return "Out for delivery"
        case .delivered: return "Delivered"
        }
    }

    private var progress: CGFloat {
        switch item.status {
        case .labelCreated: return 0.05
        case .inTransit: return 0.40
        case .outForDelivery: return 0.85
        case .delivered: return 1.0
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            Capsule()
                .fill(PurlTune.token("Components/DeliveryCard.swift:fill:_:146:23", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                .frame(height: PurlTune.value("Components/DeliveryCard.swift:frame:height:147:32", default: 8))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xB350F6), Color(hex: 0x7358EC)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * progress, 8))
                }
        }
        .frame(height: PurlTune.value("Components/DeliveryCard.swift:frame:height:160:24", default: 8))
    }

    private func productThumb(_ product: SampleMerchant.Product) -> some View {
        Group {
            if let imageURL = product.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Rectangle().fill(PurlTune.token("Components/DeliveryCard.swift:fill:_:171:42", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                    }
                }
            } else {
                Rectangle().fill(PurlTune.token("Components/DeliveryCard.swift:fill:_:175:34", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
            }
        }
        .frame(width: PurlTune.value("Components/DeliveryCard.swift:frame:width:178:23", default: 32), height: PurlTune.value("Components/DeliveryCard.swift:frame:height:178:112", default: 32))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r8, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
    }
}

// MARK: - PastDeliveryRow

/// Simpler row for delivered items in the past deliveries section.
struct PastDeliveryRow: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let item: DeliveryItem

    private var merchant: SampleMerchant? {
        SampleMerchant.byId[item.merchantId]
    }

    var body: some View {
        HStack(spacing: GravitySpacing.space12) {
            if let merchant {
                MerchantAvatarView(merchant: merchant, size: 32)
            }

            VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                if let merchant {
                    Text(merchant.name)
                        .gravityTextStyle(GravityTypography.bodyTitleSmall)
                        .foregroundStyle(PurlTune.token("Components/DeliveryCard.swift:foregroundStyle:_:207:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                }
                if case .delivered(let date) = item.status {
                    Text("Delivered \(date)")
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(PurlTune.token("Components/DeliveryCard.swift:foregroundStyle:_:212:42", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: GravitySpacing.space4) {
                ForEach(item.products.prefix(3)) { product in
                    productThumb(product)
                }
            }
        }
        .padding(.vertical, PurlTune.token("Components/DeliveryCard.swift:padding:_:224:29", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
    }

    private func productThumb(_ product: SampleMerchant.Product) -> some View {
        Group {
            if let imageURL = product.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Rectangle().fill(PurlTune.token("Components/DeliveryCard.swift:fill:_:235:42", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                    }
                }
            } else {
                Rectangle().fill(PurlTune.token("Components/DeliveryCard.swift:fill:_:239:34", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
            }
        }
        .frame(width: PurlTune.value("Components/DeliveryCard.swift:frame:width:242:23", default: 32), height: PurlTune.value("Components/DeliveryCard.swift:frame:height:242:112", default: 32))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r8, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
    }
}

// MARK: - Live Catalog-Derived Delivery Data

extension DeliveryItem {
    @MainActor
    static var active: [DeliveryItem] {
        let merchants = SampleMerchant.all.filter { !$0.products.isEmpty }
        guard merchants.count >= 4 else { return [] }
        return [
            DeliveryItem(
                id: "active-1",
                merchantId: merchants[0].id,
                products: Array(merchants[0].products.prefix(3)),
                status: .outForDelivery(headline: "Arrives today, 3-4PM"),
                isStale: false
            ),
            DeliveryItem(
                id: "active-2",
                merchantId: merchants[1].id,
                products: Array(merchants[1].products.prefix(2)),
                status: .inTransit(headline: "Expected by Dec 10"),
                isStale: false
            ),
            DeliveryItem(
                id: "active-3",
                merchantId: merchants[2].id,
                products: Array(merchants[2].products.prefix(1)),
                status: .labelCreated(headline: "Arrives Dec 14-16"),
                isStale: true
            ),
            DeliveryItem(
                id: "active-4",
                merchantId: merchants[3].id,
                products: Array(merchants[3].products.prefix(2)),
                status: .inTransit(headline: "In transit"),
                isStale: false
            ),
        ]
    }

    @MainActor
    static var past: [DeliveryItem] {
        let merchants = SampleMerchant.all.filter { !$0.products.isEmpty }
        guard merchants.count >= 4 else { return [] }
        return [
            DeliveryItem(
                id: "past-1",
                merchantId: merchants[0].id,
                products: Array(merchants[0].products.dropFirst(3).prefix(2)),
                status: .delivered(date: "Dec 12"),
                isStale: false
            ),
            DeliveryItem(
                id: "past-2",
                merchantId: merchants[1].id,
                products: Array(merchants[1].products.dropFirst(2).prefix(2)),
                status: .delivered(date: "Dec 8"),
                isStale: false
            ),
            DeliveryItem(
                id: "past-3",
                merchantId: merchants[2].id,
                products: Array(merchants[2].products.dropFirst(1).prefix(3)),
                status: .delivered(date: "Nov 28"),
                isStale: false
            ),
            DeliveryItem(
                id: "past-4",
                merchantId: merchants[3].id,
                products: Array(merchants[3].products.dropFirst(2).prefix(1)),
                status: .delivered(date: "Nov 20"),
                isStale: false
            ),
        ]
    }
}

// MARK: - Previews

#Preview("Active Deliveries") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(DeliveryItem.active) { item in
                DeliveryCard(item: item)
            }
        }
        .padding()
    }
    .background(PurlTune.token("Components/DeliveryCard.swift:background:_:338:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}

#Preview("Past Deliveries") {
    List {
        ForEach(DeliveryItem.past) { item in
            PastDeliveryRow(item: item)
        }
    }
}

#Preview("Stale Delivery") {
    let merchants = SampleMerchant.all
    DeliveryCard(item: DeliveryItem(
        id: "stale-preview",
        merchantId: merchants[0].id,
        products: Array(merchants[0].products.prefix(2)),
        status: .labelCreated(headline: "Arrives Dec 14-16"),
        isStale: true
    ))
    .padding()
    .background(PurlTune.token("Components/DeliveryCard.swift:background:_:359:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
