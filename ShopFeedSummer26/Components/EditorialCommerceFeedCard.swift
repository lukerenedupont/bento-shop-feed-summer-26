import SwiftUI

/// Native renderer for bounded, data-authored scenes. There is no generated
/// SwiftUI, webview, arbitrary script or merchant-specific UI class here.
struct EditorialCommerceFeedCard: View {
    let plan: EditorialFeedPlan
    let spec: NextGenerationFeedCardSpec
    let products: [ResolvedStoryProduct]
    let session: GenerativeFeedPrototypeSession
    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let onInspect: () -> Void
    let onOpen: (ResolvedStoryProduct) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsInside = false

    private var selected: ResolvedStoryProduct? { session.selected(in: products, for: spec) }
    private var enabled: Bool { session.state(for: spec).interactionsEnabled }
    private var ink: Color { plan.darkText ? .black : .white }

    var body: some View {
        ZStack {
            (plan.palette == "paper" ? Color(hex: "#E9E6DD") : plan.darkText ? Color.white : .black)
            if plan.backdrop, let first = products.first {
                EditorialCatalogPhoto(item: first, index: plan.photoIndex, fills: true)
                    .frame(width: width, height: height)
                    .clipped()
                    .allowsHitTesting(false)
                // The same top/bottom contrast strategy as main's story cards.
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.60), location: 0),
                    .init(color: .black.opacity(0.52), location: 0.28),
                    .init(color: .black.opacity(0.08), location: 0.46),
                    .init(color: .black.opacity(0.55), location: 0.68),
                    .init(color: .black.opacity(0.80), location: 1)
                ], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            }
            VStack(alignment: .leading, spacing: GravitySpacing.space16) {
                if plan.headlineAnchor == "top" { heading }
                else { byline }
                GeometryReader { geometry in
                    if plan.interaction == "swipe" {
                        productPager(size: geometry.size)
                    } else {
                        scene(size: geometry.size)
                    }
                }
                if plan.headlineAnchor == "bottom" { heading }
                if plan.showChoices { choices }
                productHandoff
            }
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .foregroundStyle(ink)
        }
        .frame(width: width, height: height)
        .environment(\.colorScheme, plan.darkText ? .light : .dark)
    }

    private var byline: some View {
        HStack {
            merchantIdentity
            Spacer()
            if plan.interaction == "reveal" {
                Button(showsInside ? "See the cover" : "See inside") { showsInside.toggle() }
                    .font(GravityFont.semiBold.fixedFont(size: 13))
                    .frame(minHeight: 44)
                    .disabled(!enabled)
            }
            if session.designMode {
                Button(action: onInspect) {
                    Image(systemName: "slider.horizontal.3").frame(width: 44, height: 32)
                }
                .accessibilityIdentifier("generative.inspector")
                .accessibilityLabel("Inspect this shopping experience")
            }
        }
        .frame(minHeight: 32)
    }

    @ViewBuilder private var merchantIdentity: some View {
        // Use the audited storefront marks already bundled for native merchant
        // cards. Retailer identity stays separate from the product brand.
        let aliases = ["extra-butter-salomon": "extra-butter", "feature-salomon": "feature",
                       "nocs": "nocs-provisions", "moma": "moma-design-store"]
        let asset = "merchant-wordmark-\(aliases[plan.merchant] ?? plan.merchant)"
        if let merchant = products.first?.merchant, UIImage(named: asset) != nil {
            HStack(spacing: GravitySpacing.space8) {
                MerchantWordmarkImage(merchant: merchant, maxHeight: 26, maxWidth: 144,
                    tint: ink, bundledAssetName: asset, rendersAsTemplate: true)
                if plan.merchant.hasSuffix("-salomon") {
                    Text("· Salomon").font(GravityFont.medium.fixedFont(size: 13))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(plan.kicker)
            .accessibilityIdentifier("editorial.wordmark")
        } else {
            // Plain attribution, not a typographic imitation of an absent logo.
            Text(plan.kicker).font(GravityFont.semiBold.fixedFont(size: 13))
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            if plan.headlineAnchor == "top" { byline }
            Text(plan.title)
                .feedCardTitleStyle()
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("generative.heading")
                .contentShape(Rectangle())
                .onLongPressGesture(perform: onInspect)
                .accessibilityAction(named: "Inspect demo context", onInspect)
        }
    }

    private func scene(size: CGSize) -> some View {
        ZStack {
            ForEach(Array(plan.scene.enumerated()), id: \.offset) { index, placement in
                if let item = item(for: placement.product) {
                    Button {
                        select(item)
                        onOpen(item)
                    } label: {
                        VStack(spacing: GravitySpacing.space4) {
                            EditorialCatalogPhoto(item: item, index: imageIndex(placement, item: item))
                                .frame(height: photoHeight(placement, item: item, size: size))
                                .clipShape(RoundedRectangle(cornerRadius: placement.shape == "circle" ? 1000 : 0))
                            if placement.product >= 0, plan.scene.count > 1 {
                                Text(plan.labels[placement.product])
                                    .font(GravityFont.medium.fixedFont(size: 12))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: size.width * placement.width, height: size.height * placement.height)
                    .position(x: size.width * placement.x, y: size.height * placement.y)
                    .accessibilityLabel("View \(item.product.title)")
                    .accessibilityAddTraits(selected?.id == item.id ? .isSelected : [])
                    .accessibilityIdentifier("editorial.photo.\(index)")
                    .disabled(!enabled)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editorial.scene")
    }

    private func productPager(size: CGSize) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space12) {
                ForEach(products) { item in
                    Button { onOpen(item) } label: {
                        EditorialCatalogPhoto(item: item)
                            .frame(width: size.width * 0.88, height: size.height)
                    }
                    .buttonStyle(.plain)
                    .id(item.id)
                    .accessibilityLabel("View \(item.product.title)")
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.trailing, size.width * 0.12, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: Binding<String?>(get: { selected?.id }, set: { id in
            if let item = products.first(where: { $0.id == id }) { select(item) }
        }), anchor: .leading)
        .scrollDisabled(!enabled)
    }

    private var choices: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space20) {
                ForEach(Array(products.enumerated()).filter { !plan.backdrop || $0.offset > 0 }, id: \.element.id) { index, item in
                    Button {
                        // Photographic stories retain their pictured anchor;
                        // related objects open details instead of being cropped
                        // into a backdrop intended for a different photograph.
                        if plan.backdrop { onOpen(item) } else { select(item) }
                    } label: {
                        Text(plan.labels[index] + (plan.backdrop ? " ↗" : ""))
                            .font(GravityFont.semiBold.fixedFont(size: 14))
                            .foregroundStyle(ink.opacity(plan.backdrop || selected?.id == item.id ? 1 : 0.6))
                            .frame(minHeight: 44)
                            .overlay(alignment: .bottom) {
                                if !plan.backdrop && selected?.id == item.id { ink.frame(height: 2) }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(plan.backdrop ? "View" : "Select") \(item.product.title)")
                    .accessibilityAddTraits(!plan.backdrop && selected?.id == item.id ? .isSelected : [])
                    .disabled(!enabled)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var productHandoff: some View {
        if let selected {
            Button { onOpen(selected) } label: {
                HStack(spacing: GravitySpacing.space12) {
                    if plan.backdrop {
                        EditorialCatalogPhoto(item: selected)
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r8))
                    }
                    VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                        Text(selected.product.title)
                            .font(GravityFont.semiBold.fixedFont(size: 15)).lineLimit(2)
                        Text(GenerativeFeedStyle.price(selected.product))
                            .font(GravityFont.medium.fixedFont(size: 14)).opacity(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(ink.opacity(0.12), in: Circle())
                }
                .multilineTextAlignment(.leading)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .accessibilityLabel("View \(selected.product.title)")
            .accessibilityIdentifier("generative.primaryAction")
        }
    }

    private func photoHeight(_ placement: EditorialFeedPlan.Placement,
                             item: ResolvedStoryProduct, size: CGSize) -> CGFloat? {
        guard placement.product >= 0, plan.scene.count > 1 else { return nil }
        let index = imageIndex(placement, item: item)
        let url = Bundle.main.url(forResource: "editorial-\(item.merchant.id)-\(item.product.id)-\(index)", withExtension: "jpg")
        guard let url, let image = UIImage(contentsOfFile: url.path), image.size.width > 0 else { return nil }
        // Fit the complete photograph, then keep its caption against the image
        // rather than at the bottom of an oversized GeometryReader.
        return max(1, min(size.height * placement.height - 20,
                          size.width * placement.width * image.size.height / image.size.width))
    }

    private func item(for index: Int) -> ResolvedStoryProduct? {
        index < 0 ? selected : products.indices.contains(index) ? products[index] : nil
    }
    private func imageIndex(_ placement: EditorialFeedPlan.Placement, item: ResolvedStoryProduct) -> Int {
        if plan.interaction == "reveal", placement.product == 0 { return showsInside ? 1 : 0 }
        if placement.product < 0, item.id == products.first?.id { return plan.photoIndex }
        return placement.image
    }
    private func select(_ item: ResolvedStoryProduct) {
        guard enabled, item.id != selected?.id else { return }
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { session.select(item, for: spec) }
    }
}

private struct EditorialCatalogPhoto: View {
    let item: ResolvedStoryProduct
    var index = 0
    var fills = false
    private var url: URL? {
        Bundle.main.url(forResource: "editorial-\(item.merchant.id)-\(item.product.id)-\(index)", withExtension: "jpg")
    }
    var body: some View {
        GeometryReader { geometry in
            if let url {
                CachedAsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: fills ? .fill : .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else { Color.clear }
                }
                .id(url)
            } else {
                GenerativeProductMedia(item: item)
            }
        }
        .accessibilityHidden(true)
    }
}
