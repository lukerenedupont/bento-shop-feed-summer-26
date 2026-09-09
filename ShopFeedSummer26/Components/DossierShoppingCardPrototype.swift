import SwiftUI

/// Asset-led revision of the existing semantic card renderer. Photography is
/// inspiration; after a swap the stage becomes an honest, independently composed plan.
struct DossierShoppingCardPrototype: View {
    let record: DossierReviewRecord
    let spec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let session: GenerativeFeedPrototypeSession
    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let isActive: Bool
    let onInspect: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var detail: ResolvedStoryProduct?
    @State private var showsReview = false
    @State private var swapSlot: PrototypeContentGroup?

    private var state: GenerativeFeedPrototypeSession.CardState { session.state(for: spec) }
    private var panelHeight: CGFloat { (record.isAssembly ? 226 : 178) + bottomPadding }
    private var sceneHeight: CGFloat { max(240, height - panelHeight) }
    private var focused: ResolvedStoryProduct? {
        let items = spec.resolvedProducts(from: merchants)
        return items.first { $0.id == state.selectedID }
    }
    private var selectedSlot: PrototypeContentGroup? {
        spec.groups.first { slot in
            slot.products.contains { reference in focused?.merchant.id == reference.merchantID && focused?.product.id == reference.productID }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if state.dossierObjectsVisible, record.isAssembly {
                    objectComposition
                        .padding(.top, topPadding + 48)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                } else {
                    scenePager
                    // Native contrast protection, not a model-generated decorative gradient.
                    LinearGradient(colors: [.white.opacity(0.86), .white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: topPadding + 85).allowsHitTesting(false)
                }
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(record.title).font(GravityFont.expressiveSemiBold.fixedFont(size: 26))
                            .tracking(-0.5).lineLimit(2)
                            .accessibilityIdentifier("dossier.heading")
                        if state.dossierObjectsVisible {
                            Button("View original study") { session.setDossierObjectsVisible(false, for: spec) }
                                .font(GravityFont.medium.fixedFont(size: 12)).frame(minHeight: 32)
                                .accessibilityIdentifier("dossier.originalStudy")
                        } else if !state.roomSelections.isEmpty {
                            Text("Original styling study").font(GravityFont.medium.fixedFont(size: 12)).foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onLongPressGesture(perform: onInspect)
                    Spacer(minLength: 0)
                    if session.designMode {
                        Button(action: onInspect) { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 36) }
                            .accessibilityLabel("Inspect this shopping experience")
                    }
                }
                .padding(.horizontal, 20).padding(.top, topPadding)
            }
            .frame(width: width, height: sceneHeight)
            .clipped()

            VStack(alignment: .leading, spacing: 12) {
                if record.isAssembly {
                    objectStrip
                    focusRow.frame(height: 48)
                } else {
                    singleProductRow.frame(height: 82)
                }
                primaryAction
            }
            .padding(.horizontal, 20).padding(.top, 16)
            .padding(.bottom, bottomPadding)
            .frame(width: width, height: panelHeight, alignment: .top)
            .background(Color(hex: record.surface))
        }
        .frame(width: width, height: height)
        .background(Color(hex: record.surface))
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
        .sheet(item: $detail) { GenerativeProductReview(item: $0) }
        .sheet(isPresented: $showsReview) {
            DossierSelectionReview(record: record, spec: spec, merchants: merchants, session: session)
        }
        .sheet(item: $swapSlot) { slot in
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 20) {
                        ForEach(slot.products, id: \.self) { reference in
                            if let item = NextGenerationFeedCardSpec.resolve(reference, in: merchants) {
                                Button {
                                    session.selectRoomProduct(item, slot: slot, for: spec)
                                    session.setDossierObjectsVisible(true, for: spec)
                                    swapSlot = nil
                                } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        GenerativeProductMedia(item: item).frame(height: 170)
                                        Text(item.product.title).font(GravityFont.semiBold.fixedFont(size: 14)).lineLimit(3)
                                    }.frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Use \(item.product.title)")
                            }
                        }
                    }.padding(20)
                }
                .navigationTitle(slot.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { swapSlot = nil } } }
            }.presentationDetents([.large])
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dossier.card.\(record.key)")
    }

    private var scenePager: some View {
        TabView(selection: Binding(get: { state.dossierSceneIndex }, set: { session.setDossierScene($0, for: spec) })) {
            ForEach(Array(record.sceneVariants.enumerated()), id: \.offset) { index, variant in
                ZStack(alignment: .bottom) {
                    DossierSceneMedia(record: record, variant: variant, active: isActive && state.dossierSceneIndex == index)
                    HStack(spacing: 6) {
                        ForEach(record.sceneVariants.indices, id: \.self) { page in
                            Capsule().fill(page == index ? .white : .white.opacity(0.45))
                                .frame(width: page == index ? 18 : 5, height: 5)
                        }
                    }.padding(12)
                }.tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .accessibilityLabel("Styling studies. Swipe for another view.")
        .accessibilityHint("Generated inspiration, not a photograph of your changed selections.")
    }

    private var objectStrip: some View {
        HStack(spacing: 12) {
            ForEach(record.objects) { object in
                if let item = resolved(object) {
                    Button {
                        session.select(item, for: spec)
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            session.setDossierObjectsVisible(true, for: spec)
                        }
                    } label: {
                        DossierObjectMedia(object: object, item: item)
                            .frame(height: 86)
                            .overlay(alignment: .bottom) {
                                if focused?.id == item.id { Capsule().fill(.black).frame(width: 22, height: 3) }
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityLabel("Focus \(item.product.title)")
                    .accessibilityIdentifier("dossier.object.\(object.reference.productID)")
                }
            }
        }
    }

    private var objectComposition: some View {
        GeometryReader { proxy in
            let items = record.objects
            if record.family == "room" || record.family == "setup" {
                HStack(alignment: .center, spacing: 16) {
                    if let anchor = resolved(record.anchor) {
                        compositionObject(record.anchor, anchor).frame(width: proxy.size.width * 0.40)
                    }
                    VStack(spacing: 8) {
                        ForEach(items.dropFirst()) { object in
                            if let item = resolved(object) {
                                compositionObject(object, item)
                                    .frame(height: max(55, (proxy.size.height - 16) / 3))
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 16) {
                    VStack(spacing: 12) {
                        ForEach([0, 3], id: \.self) { index in
                            if items.indices.contains(index), let item = resolved(items[index]) {
                                compositionObject(items[index], item)
                                    .frame(height: (proxy.size.height - 12) * (index == 0 ? 0.62 : 0.38))
                            }
                        }
                    }.frame(width: proxy.size.width * 0.53)
                    VStack(spacing: 12) {
                        ForEach([1, 2], id: \.self) { index in
                            if items.indices.contains(index), let item = resolved(items[index]) {
                                compositionObject(items[index], item)
                                    .frame(height: (proxy.size.height - 12) * (index == 1 ? 0.72 : 0.28))
                            }
                        }
                    }
                }
            }
        }
    }

    private func compositionObject(_ object: DossierReviewObject, _ item: ResolvedStoryProduct) -> some View {
        Button { session.select(item, for: spec) } label: {
            DossierObjectMedia(object: object, item: item).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Focus \(item.product.title)")
        .accessibilityIdentifier("dossier.composed.\(object.reference.productID)")
    }

    @ViewBuilder private var focusRow: some View {
        if let focused {
            HStack(spacing: 8) {
                Button { detail = focused } label: {
                    Text(focused.product.title).font(GravityFont.semiBold.fixedFont(size: 14))
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                }.buttonStyle(.plain)
                if let slot = selectedSlot, slot.products.count > 1 {
                    Button("Swap") { swapSlot = slot }.font(GravityFont.semiBold.fixedFont(size: 14)).frame(minWidth: 52, minHeight: 44)
                        .accessibilityIdentifier("dossier.swap")
                } else {
                    Button { session.toggleSaved(focused, for: spec) } label: {
                        Image(systemName: state.savedSelectionIDs.contains(focused.id) ? "heart.fill" : "heart").frame(width: 44, height: 44)
                    }.accessibilityLabel("Save product")
                }
            }
        } else {
            Text(record.family == "room" ? "Tap a piece to work with it" : "Tap a piece to make it yours")
                .font(GravityFont.medium.fixedFont(size: 13)).foregroundStyle(.secondary)
        }
    }

    private var singleProductRow: some View {
        HStack(spacing: 16) {
            if let item = resolved(record.anchor) {
                Button { detail = item } label: {
                    DossierObjectMedia(object: record.anchor, item: item).frame(width: 88, height: 82)
                }.buttonStyle(.plain).accessibilityLabel("View \(item.product.title)")
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.merchant).font(GravityFont.medium.fixedFont(size: 12)).foregroundStyle(.secondary)
                    Text(record.family == "watch" ? "1975 Rolex Oyster Perpetual Date" : item.product.title)
                        .font(GravityFont.semiBold.fixedFont(size: 16)).lineLimit(2)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button { session.toggleSaved(item, for: spec) } label: {
                    Image(systemName: state.savedSelectionIDs.contains(item.id) ? "heart.fill" : "heart").font(.system(size: 21)).frame(width: 44, height: 44)
                }.accessibilityLabel(state.savedSelectionIDs.contains(item.id) ? "Remove saved idea" : "Save idea")
                    .accessibilityIdentifier("dossier.save")
            }
        }
    }

    private var primaryAction: some View {
        Button {
            if record.family == "gift", let anchor = resolved(record.anchor) {
                if !state.savedSelectionIDs.contains(anchor.id) { session.toggleSaved(anchor, for: spec) }
                showsReview = true
            } else if record.isAssembly { showsReview = true }
            else { detail = resolved(record.anchor) }
        } label: {
            HStack {
                Text(record.family == "room" ? "Review room" : record.family == "outfit" || record.family == "kids" ? "View look" : record.family == "setup" ? "Review setup" : record.family == "gift" ? "Keep for Leon" : record.family == "watch" ? "View watch" : "View hat")
                Spacer(); Image(systemName: "arrow.up.right")
            }
            .font(GravityFont.semiBold.fixedFont(size: 15))
            .padding(.horizontal, 18).frame(height: 48)
            .foregroundStyle(.white).background(.black, in: Capsule())
        }
        .disabled(!state.interactionsEnabled)
        .accessibilityIdentifier("dossier.primary")
    }
    private func resolved(_ object: DossierReviewObject) -> ResolvedStoryProduct? {
        if let slot = spec.groups.first(where: { $0.id == object.id }) {
            return session.roomProduct(slot: slot, for: spec, merchants: merchants)
        }
        return NextGenerationFeedCardSpec.resolve(object.reference, in: merchants)
    }
}

struct DossierSceneMedia: View {
    let record: DossierReviewRecord
    let variant: String
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            DossierFileImage(url: record.imageURL(variant), fills: true)
            if active, !reduceMotion, scenePhase == .active,
               let filename = record.videos[variant], let url = DossierReviewLibrary.url(filename) {
                LoopingVideoPlayer(url: url, playbackEnabled: true,
                    playbackGroupID: "dossier-review-\(record.key)-\(variant)")
                    .id(url)
            }
        }.clipped().accessibilityHidden(true)
    }
}
struct DossierFileImage: View {
    let url: URL?
    var fills = false
    var body: some View {
        GeometryReader { proxy in
            if let url {
                CachedAsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: fills ? .fill : .fit)
                            .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                    } else {
                        Color.clear.frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }.id(url)
            }
        }.accessibilityHidden(true)
    }
}
struct DossierObjectMedia: View {
    let object: DossierReviewObject
    let item: ResolvedStoryProduct
    var body: some View {
        if object.id == item.id {
            DossierFileImage(url: DossierReviewLibrary.url(object.image + ".png") ?? DossierReviewLibrary.url(object.image + ".jpg"))
        } else {
            QuietProductImage(item: item)
        }
    }
}
