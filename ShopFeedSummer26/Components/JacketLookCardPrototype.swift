import SwiftUI

/// Screenshot-directed jacket treatment: full-bleed media, a native product-card
/// carousel over the lower image, and one bottom-anchored CTA. No solid footer panel.
struct JacketLookCardPrototype: View {
    let record: DossierReviewRecord
    let spec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let session: GenerativeFeedPrototypeSession
    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let isActive: Bool
    var visibleContentBottom: CGFloat? = nil
    let onInspect: () -> Void

    @State private var detail: ResolvedStoryProduct?
    @State private var showsLook = false
    private var state: GenerativeFeedPrototypeSession.CardState { session.state(for: spec) }
    private var variant: String { record.videos["calm"] != nil ? "calm" : "look0" }
    private var productCardWidth: CGFloat { min(280, width * 0.72) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            DossierSceneMedia(record: record, variant: variant, active: isActive)
                .frame(width: width, height: height)

            // Contrast only: the source image remains visible behind all chrome.
            LinearGradient(colors: [.black.opacity(0.42), .black.opacity(0.16), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: topPadding + 110).allowsHitTesting(false)
            LinearGradient(colors: [.clear, .black.opacity(0.24)], startPoint: .top, endPoint: .bottom)
                .frame(height: 310 + bottomPadding)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

            HStack(alignment: .center) {
                Text(record.title)
                    .font(GravityFont.expressiveSemiBold.fixedFont(size: 25))
                    .tracking(-0.4)
                    .onLongPressGesture(perform: onInspect)
                    .accessibilityIdentifier("jacket.heading")
                    .accessibilityAction(named: "Inspect prototype", onInspect)
                Spacer(minLength: 0)
                if session.designMode {
                    Button(action: onInspect) { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 36) }
                        .accessibilityLabel("Inspect this shopping experience")
                }
            }
            .foregroundStyle(.white)
            .gravityShadow(GravityShadows.feedText)
            .padding(.horizontal, 20).padding(.top, topPadding)

            VStack(spacing: 16) {
                if !state.roomSelections.isEmpty {
                    Text("Original styling study")
                        .font(GravityFont.medium.fixedFont(size: 12)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
                }
                productCarousel
                Button { showsLook = true } label: {
                    Text("View the look")
                        .font(GravityFont.semiBold.fixedFont(size: 16))
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .foregroundStyle(.white)
                        .background(.black, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!state.interactionsEnabled)
                .padding(.horizontal, 20)
                .accessibilityIdentifier("jacket.viewLook")
            }
            .visualEffect { content, proxy in
                // Keep the rail + CTA together at the card's base. Only lift
                // them when the floating app navigation would actually cover them.
                content.offset(y: visibleContentBottom.map { limit in
                    -max(0, proxy.frame(in: .scrollView(axis: .vertical)).maxY - limit)
                } ?? 0)
            }
            .padding(.bottom, GravitySpacing.space24)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: width, height: height)
        .clipped()
        .environment(\.colorScheme, .light)
        .sheet(item: $detail) { GenerativeProductReview(item: $0) }
        .sheet(isPresented: $showsLook) {
            DossierSelectionReview(record: record, spec: spec, merchants: merchants, session: session)
        }
    }

    private var productCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(record.objects) { object in
                    if let item = resolved(object) {
                        Button {
                            session.select(item, for: spec)
                            detail = item
                        } label: {
                            ProductCard(
                                image: nil,
                                imageURL: productImage(object: object, item: item)?.absoluteString,
                                merchantName: item.merchant.displayName.localizedCapitalized,
                                productName: item.product.title.localizedCapitalized,
                                price: Double(item.product.price) == nil ? nil : GenerativeFeedStyle.price(item.product),
                                showFavoriteButton: false,
                                style: .list
                            )
                            .frame(width: productCardWidth)
                        }
                        .buttonStyle(.plain)
                        .id(object.id)
                        .accessibilityLabel("View \(item.product.title)")
                        .accessibilityIdentifier("jacket.product.\(object.reference.productID)")
                    }
                }
            }.scrollTargetLayout()
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .frame(width: width, height: 132)
        .accessibilityIdentifier("jacket.productCarousel")
    }

    private func resolved(_ object: DossierReviewObject) -> ResolvedStoryProduct? {
        if let slot = spec.groups.first(where: { $0.id == object.id }) {
            return session.roomProduct(slot: slot, for: spec, merchants: merchants)
        }
        return NextGenerationFeedCardSpec.resolve(object.reference, in: merchants)
    }
    private func productImage(object: DossierReviewObject, item: ResolvedStoryProduct) -> URL? {
        // The untrimmed square export fits ProductCard's square image well.
        // The product sheet still uses the original source photography.
        if object.id == item.id { return DossierReviewLibrary.url(object.image + ".jpg") }
        return Bundle.main.url(forResource: "quiet-product-\(item.merchant.id)-\(item.product.id)", withExtension: "jpg")
            ?? item.product.imageURL.flatMap(URL.init(string:))
    }
}
