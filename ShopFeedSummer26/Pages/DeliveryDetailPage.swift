import SwiftUI
import MapKit

/// Detail view for a single delivery, matching Figma "Delivery Details" (618:60134).
///
/// Layout:
/// - Map placeholder background (top ~50%)
/// - Draggable bottom sheet (same pattern as DeliveriesPage — half-up then swipeable)
///   - Headline: merchant name, "Arrives ..." title, progress bar
///   - Carrier card: carrier name, tracking number, "Manage delivery" button
///   - Order card: merchant branded header, order line items, visit/view buttons
///   - Delivery progress card: timeline + "View all activity" button
///   - Other actions card: mark delivered, edit tracking, report (with icons)
struct DeliveryDetailPage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let deliveryId: String
    var namespace: Namespace.ID

    @Environment(NavigationCoordinator.self) private var coordinator

    private var item: DeliveryItem? {
        (DeliveryItem.active + DeliveryItem.past).first { $0.id == deliveryId }
    }

    private var merchant: SampleMerchant? {
        guard let item else { return nil }
        return SampleMerchant.byId[item.merchantId]
    }

    var body: some View {
        Group {
        if let item, let merchant {
            FloatingPanelSheet(
                anchors: [
                    .tip(fraction: 0.58),
                    .full(topInset: 54),
                ],
                initialAnchor: .tip,
                background: { backgroundLayer },
                content: { sheetContent(item: item, merchant: merchant) }
            )
            .ignoresSafeArea(.container, edges: .all)
            .background(.black)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTransition(.zoom(sourceID: deliveryId, in: namespace))
        } else {
            Text("Delivery not found")
                .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:48:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                .toolbar(.hidden, for: .navigationBar)
        }
        }
        .purlInjectable()
    }

    // MARK: - Background layer (map + scrim)

    private var backgroundLayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            mapBackgroundFullBleed
            LinearGradient(
                colors: [.clear, .black.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:62:49", default: 0.6)), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    private var mapBackgroundFullBleed: some View {
        Map(initialPosition: .region(Self.mapRegion), interactionModes: []) {
            Annotation("Currently", coordinate: Self.originCoord, anchor: .bottom) {
                mapAnnotation(label: "Currently", sublabel: "Grindelwald, CH", isCurrent: true)
            }
            Annotation("Ships to", coordinate: Self.destinationCoord, anchor: .bottom) {
                mapAnnotation(label: "Ships to", sublabel: "Interlaken, CH", isCurrent: false)
            }
        }
        .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll))
        .colorScheme(.dark)
        .ignoresSafeArea()
    }

    // MARK: - Sheet content

    @ViewBuilder
    private func sheetContent(item: DeliveryItem, merchant: SampleMerchant) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GravitySpacing.space16) {
                headlineSection(item: item, merchant: merchant)

                carrierCard(item: item, merchant: merchant)
                orderCard(item: item, merchant: merchant)
                deliveryProgressCard(item: item)
                otherActionsCard
            }
            .padding(.horizontal, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:98:35", default: GravitySpacing.space20, options: GravitySpacing.purlTuneOptions))
            .padding(.bottom, PurlTune.value("Pages/DeliveryDetailPage.swift:padding:_:99:31", default: 120))
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, offset in
            coordinator.updateScrollOffset(offset)
        }
    }

    // MARK: - Map

    /// Sample coordinates for the delivery route (Grindelwald → Interlaken, Switzerland).
    fileprivate static let originCoord = CLLocationCoordinate2D(latitude: 46.6244, longitude: 8.0413)
    fileprivate static let destinationCoord = CLLocationCoordinate2D(latitude: 46.6863, longitude: 7.8632)

    /// Camera region that fits both points with padding.
    fileprivate static let mapRegion: MKCoordinateRegion = {
        let midLat = (originCoord.latitude + destinationCoord.latitude) / 2
        let midLon = (originCoord.longitude + destinationCoord.longitude) / 2
        let spanLat = abs(originCoord.latitude - destinationCoord.latitude) * 1.8
        let spanLon = abs(originCoord.longitude - destinationCoord.longitude) * 1.8
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
            span: MKCoordinateSpan(latitudeDelta: max(spanLat, 0.05), longitudeDelta: max(spanLon, 0.05))
        )
    }()

    @ViewBuilder
    private func mapAnnotation(label: String, sublabel: String, isCurrent: Bool) -> some View {
        VStack(spacing: GravitySpacing.space4) {
            VStack(spacing: 2) {
                Text(label)
                    .gravityTextStyle(GravityTypography.caption)
                    .foregroundStyle(.white.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:133:53", default: 0.7)))
                Text(sublabel)
                    .gravityTextStyle(GravityTypography.captionBold)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:138:35", default: GravitySpacing.space10, options: GravitySpacing.purlTuneOptions))
            .padding(.vertical, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:139:33", default: GravitySpacing.space6, options: GravitySpacing.purlTuneOptions))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous))
            .environment(\.colorScheme, .dark)

            // Pin dot
            Circle()
                .fill(isCurrent ? Palette.Purple.p40 : .white)
                .frame(width: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:width:146:31", default: 12), height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:146:121", default: 12))
                .overlay(
                    Circle()
                        .strokeBorder(isCurrent ? Palette.Purple.l20 : .white.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:149:87", default: 0.4)), lineWidth: 2)
                        .frame(width: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:width:150:39", default: 20), height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:150:129", default: 20))
                )
                .shadow(color: .black.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:152:47", default: 0.3)), radius: PurlTune.value("Pages/DeliveryDetailPage.swift:shadow:radius:152:137", default: 4), y: PurlTune.value("Pages/DeliveryDetailPage.swift:shadow:y:152:224", default: 2))
        }
    }

    // MARK: - Headline Section

    /// Figma "Headline": merchant name (bodySmall), arrival title (sectionTitle), progress bar.
    private func headlineSection(item: DeliveryItem, merchant: SampleMerchant) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            HStack {
                VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                    Text(merchant.name)
                        .gravityTextStyle(GravityTypography.bodySmall)
                        .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:165:42", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))

                    Text(item.statusSubtitle)
                        .gravityTextStyle(GravityTypography.sectionTitle)
                        .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:169:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                }

                Spacer(minLength: 0)

                // Overflow menu button
                GravityIcon.overflow.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:width:178:35", default: 20), height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:178:125", default: 20))
                    .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:179:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                    .frame(width: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:width:180:35", default: 40), height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:180:125", default: 40))
            }

            // Progress bar
            deliveryProgressBar(status: item.status)
        }
        .padding(.horizontal, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:186:31", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
    }

    // MARK: - Carrier Card

    /// Figma "Carrier card": carrier name, tracking number, single "Manage delivery" pill button.
    private func carrierCard(item: DeliveryItem, merchant: SampleMerchant) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            // Carrier name + logo
            HStack(spacing: GravitySpacing.space8) {
                Circle()
                    .fill(PurlTune.token("Pages/DeliveryDetailPage.swift:fill:_:197:27", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                    .frame(width: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:width:198:35", default: 32), height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:198:125", default: 32))
                    .overlay(
                        GravityIcon.truckFilled.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:width:203:43", default: 16), height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:203:133", default: 16))
                            .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:204:46", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    )

                Text("Chronopost")
                    .gravityTextStyle(GravityTypography.bodyTitleLarge)
                    .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:209:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
            }

            // Tracking number
            VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                Text("Tracking no.")
                    .gravityTextStyle(GravityTypography.bodySmall)
                    .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:216:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                Text("LY595209625DE")
                    .gravityTextStyle(GravityTypography.bodySmall)
                    .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:219:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
            }

            // Single "Manage delivery" button (Figma: pill button, r999)
            pillButton(title: "Manage delivery") {
                HapticFeedback.light.fire()
            }
        }
        .padding(PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:227:18", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        .background(PurlTune.token("Pages/DeliveryDetailPage.swift:background:_:228:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.medium)
    }

    // MARK: - Order Card

    /// Whether the merchant's primaryColor is dark enough to need light (white) text.
    /// Same luminance check used in AgentSearchCard and StorePage.
    private func isBrandDark(_ merchant: SampleMerchant) -> Bool {
        let resolved = UIColor(merchant.brandColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: nil)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.55
    }

    /// Figma "Order card": fully branded merchant card with cover image gradient header,
    /// centered wordmark/logo, order number pill, product line items, and action buttons.
    /// Text adapts to light/dark based on the merchant's primaryColor luminance.
    private func orderCard(item: DeliveryItem, merchant: SampleMerchant) -> some View {
        let dark = isBrandDark(merchant)
        let textPrimary: Color = dark ? .white : .black
        let textSecondary: Color = dark ? .white.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:255:58", default: 0.7)) : .black.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:255:80", default: 0.55))
        let overlayColor: Color = dark ? .white : .black
        let borderColor: Color = overlayColor.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:257:55", default: 0.1))

        return VStack(alignment: .leading, spacing: 0) {
            // Branded header: cover image → gradient → solid primaryColor
            orderCardHeader(merchant: merchant, textPrimary: textPrimary, overlayColor: overlayColor)

            // Bottom section: product list + buttons (on solid primaryColor)
            VStack(alignment: .leading, spacing: GravitySpacing.space16) {
                // Product line items — show ALL products in the delivery
                VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                    ForEach(item.products) { product in
                        orderProductRow(
                            product: product,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            overlayColor: overlayColor
                        )
                    }
                }

                // Action buttons
                VStack(spacing: GravitySpacing.space8) {
                    brandedPillButton(title: "Visit store", textColor: textPrimary, overlayColor: overlayColor) {
                        coordinator.navigateToStore(merchantId: merchant.id)
                    }
                    brandedPillButton(title: "View order details", textColor: textPrimary, overlayColor: overlayColor) {
                        HapticFeedback.light.fire()
                    }
                }
            }
            .padding(PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:287:22", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        }
        .background(merchant.brandColor)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.medium)
        .environment(\.colorScheme, dark ? .dark : .light)
    }

    /// Branded header area: cover image with gradient fade into merchant primaryColor,
    /// centered wordmark/logo, and a frosted order number pill.
    private func orderCardHeader(merchant: SampleMerchant, textPrimary: Color, overlayColor: Color) -> some View {
        ZStack {
            // Cover image
            MerchantCoverImage(merchant: merchant)
                .frame(height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:305:32", default: 140))
                .clipped()

            // Color overlay (25% opacity of primaryColor)
            Rectangle().fill(merchant.brandColor.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:309:58", default: 0.25)))

            // Bottom gradient: transparent → solid primaryColor
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: merchant.brandColor, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Centered content: wordmark/logo + order number pill
            VStack(spacing: GravitySpacing.space12) {
                Spacer(minLength: 0)

                // Merchant wordmark or logo — centered
                if merchant.bestWordmarkURL != nil {
                    MerchantWordmarkImage(merchant: merchant, maxHeight: 40, maxWidth: 120)
                } else if merchant.bestLogoURL != nil {
                    HStack(spacing: GravitySpacing.space8) {
                        MerchantLogoImage(merchant: merchant, size: 32)
                            .clipShape(Circle())
                        Text(merchant.name)
                            .gravityTextStyle(GravityTypography.bodyTitleLarge)
                            .foregroundStyle(textPrimary)
                    }
                } else {
                    Text(merchant.name)
                        .gravityTextStyle(GravityTypography.bodyTitleLarge)
                        .foregroundStyle(textPrimary)
                }

                // Order number pill (frosted)
                Text("#200210473 · Oct 12, 2024")
                    .gravityTextStyle(GravityTypography.caption)
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:346:43", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
                    .padding(.vertical, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:347:41", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
                    .background(overlayColor.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:348:54", default: 0.15)), in: Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:351:35", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .padding(.bottom, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:352:31", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .padding(.top, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:353:28", default: GravitySpacing.space48, options: GravitySpacing.purlTuneOptions))
        }
        .frame(height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:355:24", default: 140))
    }

    /// A single product row: 64×64 thumbnail + title + price.
    private func orderProductRow(
        product: SampleMerchant.Product,
        textPrimary: Color,
        textSecondary: Color,
        overlayColor: Color
    ) -> some View {
        HStack(alignment: .top, spacing: GravitySpacing.space12) {
            // Product thumbnail (64×64)
            Group {
                if let imageURL = product.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Rectangle().fill(overlayColor.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:374:67", default: 0.1)))
                        }
                    }
                } else {
                    Rectangle().fill(overlayColor.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:378:59", default: 0.1)))
                }
            }
            .frame(width: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:width:381:27", default: 64), height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:381:117", default: 64))
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                    .strokeBorder(overlayColor.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:385:56", default: 0.1)), lineWidth: 0.5)
            )

            // Product info
            VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                Text(product.title)
                    .gravityTextStyle(GravityTypography.bodySmall)
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)

                Text("$\(product.price) · Qty: 1")
                    .gravityTextStyle(GravityTypography.caption)
                    .foregroundStyle(textSecondary)
            }
            .padding(.top, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:399:28", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))

            Spacer(minLength: 0)
        }
    }

    /// Pill button on a branded (colored) surface — adapts text/overlay to light or dark.
    private func brandedPillButton(title: String, textColor: Color, overlayColor: Color, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.light.fire()
            action()
        } label: {
            Text(title)
                .gravityTextStyle(GravityTypography.bodyTitleLarge)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:415:37", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                .background(overlayColor.opacity(PurlTune.value("Pages/DeliveryDetailPage.swift:opacity:_:416:50", default: 0.1)), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delivery Progress Card

    /// Figma "Delivery progress card": title + vertical timeline + "View all activity" pill button.
    private func deliveryProgressCard(item: DeliveryItem) -> some View {
        let steps = deliverySteps(for: item)

        return VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            Text("Delivery progress")
                .gravityTextStyle(GravityTypography.bodyTitleLarge)
                .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:430:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))

            // Timeline
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: GravitySpacing.space12) {
                        // Timeline dot + connector line
                        VStack(spacing: 0) {
                            Circle()
                                .fill(step.isCompleted ? Palette.Purple.p40 : GravityColors.bgFillSecondary)
                                .frame(width: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:width:440:47", default: 10), height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:440:137", default: 10))

                            if index < steps.count - 1 {
                                Rectangle()
                                    .fill(steps[index + 1].isCompleted
                                          ? Palette.Purple.p40
                                          : GravityColors.bgFillSecondary)
                                    .frame(width: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:width:447:51", default: 2), height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:447:140", default: 40))
                            }
                        }
                        .frame(width: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:width:450:39", default: 10))
                        .padding(.top, PurlTune.value("Pages/DeliveryDetailPage.swift:padding:_:451:40", default: 4))

                        // Step content
                        VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                            Text(step.title)
                                .gravityTextStyle(GravityTypography.bodySmall)
                                .foregroundStyle(step.isCompleted ? GravityColors.text : GravityColors.textTertiary)

                            if let date = step.date {
                                Text(date)
                                    .gravityTextStyle(GravityTypography.caption)
                                    .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:462:54", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
                            }
                        }
                        .padding(.bottom, index < steps.count - 1 ? GravitySpacing.space16 : 0)

                        Spacer()
                    }
                }
            }

            // "View all activity" pill button
            pillButton(title: "View all activity") {
                HapticFeedback.light.fire()
            }
        }
        .padding(PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:477:18", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        .background(PurlTune.token("Pages/DeliveryDetailPage.swift:background:_:478:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.medium)
    }

    // MARK: - Other Actions Card

    /// Figma "Other cards": exactly 3 action rows with leading icons, separated by dividers.
    private var otherActionsCard: some View {
        let actions: [(icon: GravityIcon, title: String)] = [
            (.checkmarkCircle, "Mark as delivered"),
            (.pencil, "Edit tracking details"),
            (.exclamationCircle, "Report incorrect information"),
        ]

        return VStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.element.title) { index, action in
                iconActionRow(icon: action.icon, title: action.title)

                if index < actions.count - 1 {
                    Divider()
                        .padding(.horizontal, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:503:47", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
                }
            }
        }
        .padding(.vertical, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:507:29", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        .background(PurlTune.token("Pages/DeliveryDetailPage.swift:background:_:508:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.medium)
    }

    // MARK: - Shared Components

    /// Reusable progress bar matching the DeliveryCard implementation.
    private func deliveryProgressBar(status: DeliveryStatus) -> some View {
        let progress: CGFloat = switch status {
        case .labelCreated: 0.05
        case .inTransit: 0.40
        case .outForDelivery: 0.85
        case .delivered: 1.0
        }

        return GeometryReader { geo in
            Capsule()
                .fill(PurlTune.token("Pages/DeliveryDetailPage.swift:fill:_:530:23", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                .frame(height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:531:32", default: 8))
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
        .frame(height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:544:24", default: 8))
    }

    /// Pill-shaped secondary button (Figma: r999, bgFillSecondary, bodySmallBold/buttonMedium text).
    private func pillButton(title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(title)
                .gravityTextStyle(GravityTypography.buttonMedium)
                .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:554:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                .frame(maxWidth: .infinity)
                .padding(.vertical, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:556:37", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                .background(GravityColors.bgFillSecondary, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Action row with leading icon for the "Other cards" list.
    private func iconActionRow(icon: GravityIcon, title: String) -> some View {
        Button {
            HapticFeedback.light.fire()
        } label: {
            HStack(spacing: GravitySpacing.space8) {
                icon.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:width:571:35", default: 20), height: PurlTune.value("Pages/DeliveryDetailPage.swift:frame:height:571:125", default: 20))
                    .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:572:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))

                Text(title)
                    .gravityTextStyle(GravityTypography.bodyTitleLarge)
                    .foregroundStyle(PurlTune.token("Pages/DeliveryDetailPage.swift:foregroundStyle:_:576:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))

                Spacer()
            }
            .padding(.horizontal, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:580:35", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .padding(.vertical, PurlTune.token("Pages/DeliveryDetailPage.swift:padding:_:581:33", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data Helpers

    private struct TimelineStep {
        let title: String
        let date: String?
        let isCompleted: Bool
    }

    private func deliverySteps(for item: DeliveryItem) -> [TimelineStep] {
        switch item.status {
        case .outForDelivery:
            return [
                TimelineStep(title: "Delivery to", date: nil, isCompleted: false),
                TimelineStep(title: "Distribution Center, Grindelwald, CH", date: "Nov 9, 9:43", isCompleted: true),
                TimelineStep(title: "Label created", date: "Nov 8, 14:20", isCompleted: true),
            ]
        case .inTransit:
            return [
                TimelineStep(title: "Delivery to", date: nil, isCompleted: false),
                TimelineStep(title: "In transit", date: "Nov 9, 9:43", isCompleted: true),
                TimelineStep(title: "Label created", date: "Nov 8, 14:20", isCompleted: true),
            ]
        case .labelCreated:
            return [
                TimelineStep(title: "Delivery to", date: nil, isCompleted: false),
                TimelineStep(title: "Label created", date: "Nov 8, 14:20", isCompleted: true),
            ]
        case .delivered(let date):
            return [
                TimelineStep(title: "Delivered", date: date, isCompleted: true),
                TimelineStep(title: "Out for delivery", date: "Nov 10, 8:00", isCompleted: true),
                TimelineStep(title: "Distribution Center", date: "Nov 9, 9:43", isCompleted: true),
                TimelineStep(title: "Label created", date: "Nov 8, 14:20", isCompleted: true),
            ]
        }
    }

}

// MARK: - NavigationCoordinator Extension

extension NavigationCoordinator {
    /// Navigate to a store from any tab context.
    func navigateToStore(merchantId: String) {
        HapticFeedback.light.fire()
        pushRoute(.store(merchantId: merchantId))
    }
}

// MARK: - Preview

#Preview {
    @Previewable @Namespace var ns
    NavigationStack {
        DeliveryDetailPage(
            deliveryId: DeliveryItem.active.first!.id,
            namespace: ns
        )
    }
    .environment(NavigationCoordinator())
}
