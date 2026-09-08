import SwiftUI

/// PROTOTYPE: five visual shopping jobs inside the existing feed renderer.
/// All data/selection lives above the lazy cell. No model-authored UI or live generation.
struct QuietShoppingCardPrototype: View {
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
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var detail: ResolvedStoryProduct?
    @State private var showsJourney = false
    private var state: GenerativeFeedPrototypeSession.CardState { session.state(for: spec) }
    private var products: [ResolvedStoryProduct] { session.products(for: spec, merchants: merchants).filter { !state.removedIDs.contains($0.id) } }
    private var selected: ResolvedStoryProduct? { session.selected(in: products, for: spec) }
    private var anchor: ResolvedStoryProduct? { spec.anchor.flatMap { NextGenerationFeedCardSpec.resolve($0, in: merchants) } }
    private var group: PrototypeContentGroup? { session.activeGroup(for: spec) }
    private var ink: Color { .black }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                Text(spec.title)
                    .font(GravityFont.expressiveSemiBold.fixedFont(size: 25))
                    .tracking(-0.4)
                    .accessibilityIdentifier("quiet.heading")
                    .onLongPressGesture(perform: onInspect)
                    .accessibilityAction(named: "Inspect prototype", onInspect)
                Spacer(minLength: 0)
                if session.designMode {
                    Button(action: onInspect) { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
                        .accessibilityLabel("Inspect this shopping experience")
                }
            }
            GeometryReader { geometry in
                composition(size: geometry.size)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            footer.frame(minHeight: 48)
        }
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(width: width, height: height)
        .foregroundStyle(ink)
        .environment(\.colorScheme, .light)
        .sheet(item: $detail) { GenerativeProductReview(item: $0) }
        .sheet(isPresented: $showsJourney) {
            QuietShoppingJourneyPrototype(spec: spec, merchants: merchants, session: session)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("quiet.card.\(spec.signal.id)")
    }

    @ViewBuilder
    private func composition(size: CGSize) -> some View {
        switch spec.interaction {
        case .swap: outfit(size: size)
        case .shortlist: comparison(size: size)
        case .browse: merchant(size: size)
        case .selectForWorld: room(size: size)
        case .steer: directions(size: size)
        case .selectMerchant: EmptyView()
        }
    }

    private func outfit(size: CGSize) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 4) {
                if let anchor {
                    Button { detail = anchor } label: {
                        QuietLocalImage(name: "quiet-dossier-tee")
                            .frame(width: size.width * 0.49, height: size.height * 0.72)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View \(anchor.product.title)")
                    .accessibilityIdentifier("quiet.anchor")
                    .accessibilityHint("Generated styling illustration. Opens the original product photograph and details.")
                }
                productPager(items: products, cardWidth: size.width * 0.43, mediaHeight: size.height * 0.72)
                    .frame(width: size.width * 0.49)
                    .accessibilityIdentifier("quiet.pantsPager")
            }
            Group {
            if state.hasInteracted {
                focusedIdentity(selected)
                    .transition(.opacity)
            } else {
                Text("Swipe pants")
                    .font(GravityFont.medium.fixedFont(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 32)
            }
            }.frame(height: 64)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func comparison(size: CGSize) -> some View {
        if state.comparisonRevealed {
            let pair = products.filter { state.comparisonIDs.contains($0.id) }
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(pair) { item in
                        VStack(alignment: .leading, spacing: 14) {
                            Button { detail = item } label: {
                                QuietProductImage(item: item).frame(height: size.height * 0.43)
                            }.buttonStyle(.plain)
                            Text(item.product.title).font(GravityFont.semiBold.fixedFont(size: 15)).fixedSize(horizontal: false, vertical: true)
                            Text(GenerativeFeedStyle.price(item.product)).font(GravityFont.medium.fixedFont(size: 17))
                            Text(item.product.id == 8214794371245 ? "Wool mohair · Oak base" : "Belgian linen · Down-topped seat")
                                .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.secondary)
                            Text(item.merchant.displayName).font(GravityFont.regular.fixedFont(size: 12)).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                Button("Change selection") { animate { session.revealReviewComparison(false, for: spec) } }
                    .font(GravityFont.medium.fixedFont(size: 13)).frame(minHeight: 44)
                Spacer(minLength: 0)
            }
            .accessibilityIdentifier("quiet.comparison")
        } else {
            VStack(spacing: 12) {
                ForEach(products) { item in
                    Button {
                        animate { session.toggleReviewComparison(item, for: spec) }
                    } label: {
                        ZStack(alignment: .trailing) {
                            QuietProductImage(item: item)
                                .padding(.horizontal, 18)
                            Image(systemName: state.comparisonIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(state.comparisonIDs.contains(item.id) ? .black : .black.opacity(0.25))
                                .padding(.trailing, 4)
                        }
                        .frame(height: max(80, (size.height - 24) / 3))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select \(item.product.title)")
                    .accessibilityAddTraits(state.comparisonIDs.contains(item.id) ? .isSelected : [])
                    .accessibilityIdentifier("quiet.compare.\(item.product.id)")
                }
            }
        }
    }

    private func merchant(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            QuietLocalImage(name: "quiet-salomon-campaign", fills: true)
                .frame(height: max(150, size.height * 0.55))
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16))
            productPager(items: products, cardWidth: size.width * 0.72, mediaHeight: max(90, size.height * 0.25))
                .accessibilityIdentifier("quiet.collectionPager")
            if state.hasInteracted { focusedIdentity(selected) }
            Spacer(minLength: 0)
        }
    }

    private func room(size: CGSize) -> some View {
        let boardHeight = max(200, size.height - 132)
        return VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if let anchor {
                    Button { detail = anchor } label: {
                        QuietProductImage(item: anchor).frame(width: size.width * 0.94, height: boardHeight * 0.53)
                    }
                    .buttonStyle(.plain)
                    .offset(x: size.width * 0.03, y: 0)
                    .accessibilityLabel("View saved \(anchor.product.title)")
                    .accessibilityIdentifier("quiet.roomAnchor")
                }
                ForEach(Array(spec.groups.enumerated()), id: \.element.id) { index, slot in
                    if let item = session.roomProduct(slot: slot, for: spec, merchants: merchants) {
                        Button { animate { session.focusRoomSlot(slot.id, for: spec) } } label: {
                            QuietProductImage(item: item)
                                .frame(width: size.width * (index == 0 ? 0.49 : 0.43), height: boardHeight * 0.45)
                                .overlay(alignment: .bottom) {
                                    if state.roomSlotID == slot.id {
                                        Capsule().fill(.black).frame(width: 26, height: 3)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .offset(x: size.width * (index == 0 ? 0.48 : 0.02), y: boardHeight * (index == 0 ? 0.5 : 0.43))
                        .accessibilityLabel("Swap \(slot.title)")
                        .accessibilityValue(item.product.title)
                        .accessibilityIdentifier("quiet.roomSlot.\(slot.id)")
                    }
                }
            }
            .frame(width: size.width, height: boardHeight, alignment: .topLeading)
            .clipped()
            if let slot = spec.groups.first(where: { $0.id == state.roomSlotID }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(slot.products, id: \.self) { reference in
                            if let item = NextGenerationFeedCardSpec.resolve(reference, in: merchants) {
                                Button { animate { session.selectRoomProduct(item, slot: slot, for: spec) } } label: {
                                    QuietProductImage(item: item).frame(width: 90, height: 80)
                                        .overlay(alignment: .bottom) {
                                            if session.roomProduct(slot: slot, for: spec, merchants: merchants)?.id == item.id {
                                                Capsule().fill(.black).frame(width: 20, height: 2)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Use \(item.product.title)")
                                .accessibilityIdentifier("quiet.roomAlternative.\(item.product.id)")
                            }
                        }
                    }
                }
                .frame(height: 84)
            } else {
                Text("Tap a piece to swap it")
                    .font(GravityFont.medium.fixedFont(size: 13)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func directions(size: CGSize) -> some View {
        if let group {
            VStack(alignment: .leading, spacing: 20) {
                Text(group.title).font(GravityFont.medium.fixedFont(size: 13)).foregroundStyle(.secondary)
                productPager(items: products, cardWidth: size.width * 0.86, mediaHeight: size.height * 0.56)
                    .accessibilityIdentifier("quiet.refinedPager")
                if state.hasInteracted { focusedIdentity(selected) }
                Button("Change direction") { animate { session.clearGroup(spec) } }
                    .font(GravityFont.medium.fixedFont(size: 13)).frame(minHeight: 44)
                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: 20) {
                ForEach(spec.groups) { direction in
                    Button { animate { session.choose(direction, for: spec) } } label: {
                        VStack(spacing: 10) {
                            ForEach(direction.products.prefix(2), id: \.self) { reference in
                                QuietProductImage(item: NextGenerationFeedCardSpec.resolve(reference, in: merchants))
                                    .frame(height: size.height * 0.31)
                            }
                            Text(direction.title).font(GravityFont.medium.fixedFont(size: 13)).padding(.top, 12)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose \(direction.title)")
                    .accessibilityIdentifier("quiet.direction.\(direction.id)")
                }
            }
        }
    }

    private func productPager(items: [ResolvedStoryProduct], cardWidth: CGFloat, mediaHeight: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    Button {
                        if state.hasInteracted && selected?.id == item.id { detail = item }
                        else { animate { session.select(item, for: spec) } }
                    } label: {
                        QuietProductImage(item: item).frame(width: cardWidth, height: mediaHeight)
                    }
                    .buttonStyle(.plain)
                    .id(item.id)
                    .accessibilityLabel("Focus \(item.product.title)")
                    .accessibilityAddTraits(selected?.id == item.id ? .isSelected : [])
                }
            }.scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: Binding<String?>(get: { selected?.id }, set: { id in
            guard let item = items.first(where: { $0.id == id }), item.id != selected?.id else { return }
            session.select(item, for: spec)
        }), anchor: .leading)
        .scrollDisabled(!state.interactionsEnabled)
        .frame(height: mediaHeight)
    }

    private func focusedIdentity(_ item: ResolvedStoryProduct?) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if let item {
                Button { detail = item } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.product.title).font(GravityFont.semiBold.fixedFont(size: 14)).lineLimit(2)
                        Text("\(item.merchant.displayName) · \(GenerativeFeedStyle.price(item.product))")
                            .font(GravityFont.regular.fixedFont(size: 12)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("quiet.focusedProduct")
                Button { session.toggleSaved(item, for: spec) } label: {
                    Image(systemName: state.savedSelectionIDs.contains(item.id) ? "heart.fill" : "heart")
                        .font(.system(size: 20)).frame(width: 44, height: 44)
                }
                .accessibilityLabel(state.savedSelectionIDs.contains(item.id) ? "Remove saved selection" : "Save selection")
                .accessibilityIdentifier("quiet.save")
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch spec.interaction {
        case .swap:
            if state.hasInteracted { primary("View look") { showsJourney = true } }
            else { Color.clear.frame(height: 48) }
        case .shortlist:
            if state.comparisonRevealed { primary("View shortlist") { showsJourney = true } }
            else if state.comparisonIDs.count == 2 {
                primary("Compare") { animate { session.revealReviewComparison(true, for: spec) } }
            } else {
                Text(state.comparisonIDs.isEmpty ? "Select two to compare" : "Select one more")
                    .font(GravityFont.medium.fixedFont(size: 13)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
            }
        case .browse:
            primary("Visit Extra Butter") { coordinator.pushRoute(.store(merchantId: spec.signal.merchantID)) }
        case .selectForWorld:
            primary("View room") { showsJourney = true }
        case .steer:
            if group != nil { primary("Keep exploring") { showsJourney = true } }
            else { Color.clear.frame(height: 48) }
        case .selectMerchant: EmptyView()
        }
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(title); Spacer(); Image(systemName: "arrow.right") }
                .font(GravityFont.semiBold.fixedFont(size: 15))
                .padding(.horizontal, 20).frame(height: 48)
                .foregroundStyle(.white).background(.black, in: Capsule())
        }
        .disabled(!state.interactionsEnabled)
        .accessibilityIdentifier("quiet.primary")
    }
    private func animate(_ action: () -> Void) {
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion || !isActive ? nil : .easeInOut(duration: 0.25), action)
    }
}

/// Original merchant images, blended onto the renderer-owned neutral surface.
/// Generated Dossier composites are never substituted for exact product images.
struct QuietProductImage: View {
    let item: ResolvedStoryProduct?
    var body: some View {
        GeometryReader { proxy in
            if let item {
                GenerativeProductMedia(item: item)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blendMode(.multiply)
            }
        }
        .accessibilityHidden(true)
    }
}

struct QuietLocalImage: View {
    let name: String
    var fills = false
    var body: some View {
        GeometryReader { proxy in
            if let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: fills ? .fill : .fit)
                    .frame(width: proxy.size.width, height: proxy.size.height).clipped()
            } else { Color.clear }
        }
        .accessibilityHidden(true)
    }
}

extension GenerativeFeedPrototypeSession {
    func roomProduct(slot: PrototypeContentGroup, for spec: NextGenerationFeedCardSpec, merchants: [SampleMerchant]) -> ResolvedStoryProduct? {
        let choices = slot.products.compactMap { NextGenerationFeedCardSpec.resolve($0, in: merchants) }
        return choices.first { $0.id == state(for: spec).roomSelections[slot.id] } ?? choices.first
    }
}
