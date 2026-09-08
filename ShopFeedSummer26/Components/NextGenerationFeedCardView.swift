import SwiftUI

/// PROTOTYPE — four jobs in the real Shop feed. Long-press the heading to
/// compare two compositions with identical products and retained local state.
struct NextGenerationFeedCardView: View {
    let spec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let width: CGFloat
    let height: CGFloat
    let foregroundTopPadding: CGFloat
    let isActive: Bool
    let session: GenerativeFeedPrototypeSession
    var bottomContentPadding: CGFloat = GravitySpacing.space24

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsInspector = false
    @State private var showsRoomPlan = false

    private var products: [ResolvedStoryProduct] { spec.resolvedProducts(from: merchants) }
    private var anchor: ResolvedStoryProduct? {
        spec.anchor.flatMap { NextGenerationFeedCardSpec.resolve($0, in: merchants) }
    }
    private var selected: ResolvedStoryProduct? { session.selected(in: products, for: spec) }
    private var current: GenerativeFeedPrototypeSession.CardState { session.state(for: spec) }
    private var ink: Color { spec.prefersDarkNavigationText ? .black : .white }
    private var visibleProducts: [ResolvedStoryProduct] { products.filter { !current.removedIDs.contains($0.id) } }

    var body: some View {
        // Background is the sizing root. Intrinsic image sizes must never
        // participate in the feed's width/height proposal.
        GenerativeFeedStyle.surface(for: spec)
            .frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: GravitySpacing.space20) {
                    heading
                    GeometryReader { proxy in
                        composition(size: proxy.size)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    controls
                }
                .padding(.horizontal, GravitySpacing.space20)
                .padding(.top, foregroundTopPadding)
                .padding(.bottom, bottomContentPadding)
                .frame(width: width, height: height)
                .foregroundStyle(ink)
            }
            .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
            .environment(\.colorScheme, spec.prefersDarkNavigationText ? .light : .dark)
            .sheet(isPresented: $showsInspector) {
                GenerativeFeedInspector(spec: spec, merchants: merchants, session: session)
            }
            .sheet(isPresented: $showsRoomPlan) {
                roomPlan
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(spec.accessibilityDescription)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            HStack {
                Text(spec.signal.worldID == nil ? "Demo context" : "Living room · Demo context")
                    .font(GravityFont.medium.fixedFont(size: 12))
                    .foregroundStyle(ink.opacity(0.65))
                Spacer()
                if session.designMode {
                    Button { showsInspector = true } label: {
                        Image(systemName: "slider.horizontal.3").frame(width: 44, height: 28)
                    }
                    .accessibilityLabel("Inspect this shopping experience")
                    .accessibilityIdentifier("generative.inspector")
                }
            }
            Text(spec.title)
                .font(GravityFont.expressiveSemiBold.fixedFont(size: 28))
                .tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("generative.heading")
            Text(spec.subtitle)
                .font(GravityFont.regular.fixedFont(size: 15))
                .foregroundStyle(ink.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onLongPressGesture { showsInspector = true }
        .accessibilityAction(named: "Inspect demo context") { showsInspector = true }
    }

    @ViewBuilder
    private func composition(size: CGSize) -> some View {
        switch session.composition(for: spec) {
        case .relationship:
            relationship(size: size)
        case .comparison:
            comparison(size: size)
        case .merchant:
            merchant(size: size)
        case .continuation:
            continuation(size: size)
        case .hero:
            VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                if let anchor { compactProduct(anchor, caption: "Your anchor") }
                GenerativeProductMedia(item: selected)
                identity(selected)
            }
        }
    }

    private func relationship(size: CGSize) -> some View {
        let columnWidth = (size.width - GravitySpacing.space12) / 2
        return VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            HStack(alignment: .top, spacing: GravitySpacing.space12) {
                relationshipColumn(anchor, caption: "You bought", width: columnWidth, height: size.height - 42)
                relationshipColumn(selected, caption: "Wear it with", width: columnWidth, height: size.height - 42)
            }
            Text("Nike × Stüssy, from Feature")
                .font(GravityFont.medium.fixedFont(size: 13))
                .foregroundStyle(ink.opacity(0.65))
        }
    }

    private func relationshipColumn(_ item: ResolvedStoryProduct?, caption: String, width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            Text(caption).font(GravityFont.semiBold.fixedFont(size: 13))
            GenerativeProductMedia(item: item)
                .frame(height: max(height - 150, 100))
            identity(item, showsMerchant: false)
        }
        .frame(width: width, alignment: .topLeading)
    }

    private func comparison(size: CGSize) -> some View {
        let items = visibleProducts
        let columnWidth = (size.width - CGFloat(max(items.count - 1, 0)) * 8) / CGFloat(max(items.count, 1))
        return VStack(alignment: .leading, spacing: GravitySpacing.space20) {
            Text("House of Leon").font(GravityFont.semiBold.fixedFont(size: 16))
            if items.isEmpty {
                ContentUnavailableView("Shortlist cleared", systemImage: "checkmark", description: Text("Use Reset shortlist to bring the chairs back."))
            } else {
                HStack(alignment: .top, spacing: GravitySpacing.space8) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                            GenerativeProductMedia(item: item)
                                .frame(height: max(size.height * 0.52, 120))
                            identity(item, showsMerchant: false, compact: true)
                            Button {
                                perform { session.remove(item, for: spec) }
                            } label: {
                                Text("Remove").font(GravityFont.medium.fixedFont(size: 12))
                                    .frame(minHeight: 44)
                            }
                            .disabled(!current.interactionsEnabled)
                            .accessibilityLabel("Remove \(item.product.title) from shortlist")
                        }
                        .frame(width: columnWidth, alignment: .topLeading)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func merchant(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            HStack(spacing: GravitySpacing.space12) {
                if let merchant = products.first?.merchant {
                    MerchantAvatarView(merchant: merchant, size: 40)
                }
                Text("Independent publishing.\nGraphic design, documented.")
                    .font(GravityFont.medium.fixedFont(size: 14))
            }
            GenerativeProductMedia(item: selected)
                .frame(height: max(size.height - 178, 100))
            identity(selected, showsMerchant: false)
            thumbnailChoices
        }
    }

    private func continuation(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            if let anchor { compactProduct(anchor, caption: "Saved in your living room") }
            GenerativeProductMedia(item: selected)
                .frame(height: max(size.height - 240, 100))
            identity(selected)
            thumbnailChoices
        }
    }

    private var thumbnailChoices: some View {
        HStack(spacing: GravitySpacing.space8) {
            ForEach(products) { item in
                Button { perform { session.select(item, for: spec) } } label: {
                    GenerativeProductMedia(item: item)
                        .frame(width: 52, height: 58)
                        .overlay {
                            RoundedRectangle(cornerRadius: GravityRadius.r16)
                                .strokeBorder(selected?.id == item.id ? ink : .clear, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!current.interactionsEnabled)
                .accessibilityLabel("Select \(item.product.title)")
                .accessibilityAddTraits(selected?.id == item.id ? .isSelected : [])
            }
        }
    }

    private func compactProduct(_ item: ResolvedStoryProduct, caption: String) -> some View {
        HStack(spacing: GravitySpacing.space12) {
            GenerativeProductMedia(item: item).frame(width: 64, height: 72)
            VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                Text(caption).font(GravityFont.medium.fixedFont(size: 12)).foregroundStyle(.secondary)
                Text(item.product.title).font(GravityFont.semiBold.fixedFont(size: 14)).lineLimit(2)
            }
        }
    }

    private func identity(_ item: ResolvedStoryProduct?, showsMerchant: Bool = true, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space4) {
            if let item {
                Text(item.product.title)
                    .font(GravityFont.semiBold.fixedFont(size: compact ? 13 : 15))
                    .lineLimit(compact ? 4 : 3)
                    .fixedSize(horizontal: false, vertical: true)
                if showsMerchant {
                    Text(item.merchant.displayName)
                        .font(GravityFont.regular.fixedFont(size: 12))
                        .foregroundStyle(ink.opacity(0.65))
                }
                Text(GenerativeFeedStyle.price(item.product))
                    .font(GravityFont.medium.fixedFont(size: 14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        HStack(spacing: GravitySpacing.space12) {
            Text(progressLabel)
                .font(GravityFont.medium.fixedFont(size: 13))
                .foregroundStyle(ink.opacity(0.65))
            Spacer(minLength: 0)
            Button {
                perform {
                    switch spec.interaction {
                    case .swap, .browse: advance()
                    case .shortlist: session.restoreShortlist(spec)
                    case .selectForWorld: showsRoomPlan = true
                    }
                }
            } label: {
                Text(actionLabel)
                    .font(GravityFont.semiBold.fixedFont(size: 14))
                    .padding(.horizontal, GravitySpacing.space20)
                    .frame(minHeight: 48)
                    .foregroundStyle(spec.prefersDarkNavigationText ? Color.white : .black)
                    .background(ink, in: Capsule())
            }
            .disabled(!current.interactionsEnabled)
            .opacity(current.interactionsEnabled ? 1 : 0.45)
            .accessibilityIdentifier("generative.primaryAction")
        }
    }

    private var progressLabel: String {
        if spec.interaction == .shortlist { return "\(visibleProducts.count) on your shortlist" }
        let index = products.firstIndex { $0.id == selected?.id } ?? 0
        return "\(index + 1) of \(products.count)"
    }
    private var actionLabel: String {
        switch spec.interaction {
        case .swap: "Swap pants"
        case .shortlist: "Reset shortlist"
        case .browse: "Next book"
        case .selectForWorld: "Review room plan"
        }
    }
    private func advance() {
        guard !products.isEmpty else { return }
        let index = products.firstIndex { $0.id == selected?.id } ?? 0
        session.select(products[(index + 1) % products.count], for: spec)
    }
    private func perform(_ action: () -> Void) {
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion || !isActive ? nil : SpringPreset.responsive, action)
    }

    private var roomPlan: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GravitySpacing.space24) {
                    Text("Your living room").font(GravityFont.expressiveSemiBold.fixedFont(size: 28))
                    Text("Demo room plan · Your selection carries over from the feed.")
                        .font(GravityFont.regular.fixedFont(size: 15)).foregroundStyle(.secondary)
                    if let anchor { compactProduct(anchor, caption: "Previously saved") }
                    GenerativeProductMedia(item: selected).frame(height: 260)
                    identity(selected)
                    Text("Choose a different chair")
                        .font(GravityFont.semiBold.fixedFont(size: 16))
                    thumbnailChoices
                    Text("This is a local state-continuity prototype, not a room rendering or the full World destination.")
                        .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.secondary)
                }
                .padding(GravitySpacing.space20)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsRoomPlan = false } } }
        }
        .presentationDetents([.large])
    }
}

/// Shop owns the mapping from semantic job to surface; the spec cannot supply
/// arbitrary colors, fonts, spacing, or animation curves.
enum GenerativeFeedStyle {
    static func surface(for spec: NextGenerationFeedCardSpec) -> Color {
        switch spec.job {
        case .complete: Color(hex: "#F2F1ED")
        case .compare: Color.white
        case .merchantDiscovery: Color(hex: "#20201E")
        case .continueWorld: Color(hex: "#EFECE6")
        }
    }
    static func price(_ product: SampleMerchant.Product) -> String {
        guard let value = Double(product.price) else { return product.price }
        return value.formatted(.currency(code: product.currencyCode))
    }
}

/// Bounded, fitted catalog image. Never replaces a failed product image with
/// unrelated merchant media. Bundled copies are keyed to exact canonical IDs.
struct GenerativeProductMedia: View {
    let item: ResolvedStoryProduct?
    private var url: URL? {
        guard let item else { return nil }
        let local = Bundle.main.url(forResource: "prototype-product-\(item.merchant.id)-\(item.product.id)", withExtension: "jpg")
        return local ?? item.product.imageURL.flatMap(URL.init(string:))
    }
    var body: some View {
        GeometryReader { proxy in
            Color.white.overlay {
                if let url {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        case .failure:
                            Image(systemName: "photo").foregroundStyle(.gray)
                                .accessibilityLabel("Product image unavailable")
                        default: ProgressView().tint(.gray)
                        }
                    }
                    .id(url)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16))
        }
        .accessibilityHidden(true)
    }
}
