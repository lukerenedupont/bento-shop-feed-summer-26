import SwiftUI

/// Shared Dossier treatment: full-bleed media, square Shop product cards,
/// white editorial type, and one bottom-anchored action. Content determines the job.
struct DossierMediaFeedCard: View {
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
    private var variant: String {
        if record.videos["calm"] != nil { return "calm" }
        return record.videos.keys.sorted().first ?? record.sceneVariants.first ?? "look0"
    }
    private var actionTitle: String {
        switch record.family {
        case "room": "View the room"
        case "gift": "Keep for Leon"
        case "watch": "View watch"
        case "merchant": "View hat"
        case "setup": "View the setup"
        default: "View the look"
        }
    }
    private var productCardWidth: CGFloat { min(144, (width - 52) / 2.4) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            DossierSceneMedia(record: record, variant: variant, active: isActive)
                .frame(width: width, height: height)

            // Contrast only: the source image remains visible behind all chrome.
            LinearGradient(colors: [.black.opacity(0.42), .black.opacity(0.16), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: topPadding + 110).allowsHitTesting(false)
            LinearGradient(colors: [.clear, .black.opacity(0.24)], startPoint: .top, endPoint: .bottom)
                .frame(height: 430 + bottomPadding)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    Text(record.title)
                        .feedCardTitleStyle()
                        .onLongPressGesture(perform: onInspect)
                        .accessibilityIdentifier("dossier.media.heading")
                        .accessibilityAction(named: "Inspect prototype", onInspect)
                    Spacer(minLength: 0)
                    Menu {
                        Button("Inspect card", action: onInspect)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 22, weight: .medium))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("More options")
                    .accessibilityIdentifier("dossier.media.overflow")
                }
                .foregroundStyle(.white)
                .gravityShadow(GravityShadows.feedText)
                .padding(.horizontal, 20)

                if !state.roomSelections.isEmpty {
                    Text("Original styling study")
                        .font(GravityFont.medium.fixedFont(size: 12)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
                }
                productCarousel
                Button {
                    if ["watch", "merchant"].contains(record.family) {
                        detail = resolved(record.anchor)
                    } else {
                        if record.family == "gift", let anchor = resolved(record.anchor),
                           !state.savedSelectionIDs.contains(anchor.id) {
                            session.toggleSaved(anchor, for: spec)
                        }
                        showsLook = true
                    }
                } label: {
                    Text(actionTitle)
                        .font(GravityFont.semiBold.fixedFont(size: 16))
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .foregroundStyle(.white)
                        .background(.black, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!state.interactionsEnabled)
                .padding(.horizontal, 20)
                .accessibilityIdentifier("dossier.media.primary")
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
                ForEach(record.visibleObjects) { object in
                    if let item = resolved(object) {
                        Button {
                            session.select(item, for: spec)
                            detail = item
                        } label: {
                            ProductCard(
                                image: nil,
                                imageURL: productImage(object: object, item: item)?.absoluteString,
                                priceBadge: Double(item.product.price) == nil ? nil : GenerativeFeedStyle.price(item.product),
                                showFavoriteButton: false,
                                style: .grid
                            )
                            .frame(width: productCardWidth)
                        }
                        .buttonStyle(.plain)
                        .id(object.id)
                        .accessibilityLabel("View \(item.product.title)")
                        .accessibilityIdentifier("dossier.media.product.\(object.reference.productID)")
                    }
                }
            }.scrollTargetLayout()
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .frame(width: width, height: productCardWidth)
        .accessibilityIdentifier("dossier.media.carousel")
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
