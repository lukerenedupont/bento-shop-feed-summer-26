import SwiftUI

/// One-card design correction, not a new feed template system.
/// Uses BentoGrid's full-width anchor + tall/stacked trio grammar and 8pt gutters.
/// Its navigation-only compartment chrome is deliberately not reused: metadata
/// is earned by focus, and the pants compartment edits in place.
struct VomeroBentoPrototype: View {
    let record: DossierReviewRecord
    let spec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let session: GenerativeFeedPrototypeSession
    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let onInspect: () -> Void

    @State private var detail: ResolvedStoryProduct?
    @State private var showsLook = false

    private let gap = GravitySpacing.space8
    private let radius: CGFloat = 22
    private var state: GenerativeFeedPrototypeSession.CardState { session.state(for: spec) }
    private var objects: [DossierReviewObject] { record.objects }
    private var pantsObject: DossierReviewObject? { objects.dropFirst().first }
    private var pantsSlot: PrototypeContentGroup? {
        spec.groups.first { $0.id == pantsObject?.id }
    }
    private var pantsExpanded: Bool { pantsSlot != nil && state.roomSlotID == pantsSlot?.id }
    private var focused: ResolvedStoryProduct? {
        spec.resolvedProducts(from: merchants).first { $0.id == state.selectedID }
    }
    private var contentWidth: CGFloat { width - 40 }
    private var gridHeight: CGFloat { max(220, height - topPadding - bottomPadding - 112) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("With these Vomeros")
                    .font(GravityFont.semiBold.fixedFont(size: 20))
                    .accessibilityIdentifier("vomero.heading")
                    .onLongPressGesture(perform: onInspect)
                    .accessibilityAction(named: "Inspect prototype", onInspect)
                Spacer(minLength: 0)
                if session.designMode {
                    Button(action: onInspect) {
                        Image(systemName: "slider.horizontal.3").frame(width: 44, height: 28)
                    }.accessibilityLabel("Inspect this shopping experience")
                }
            }
            .frame(height: 28)

            bento
                .frame(width: contentWidth, height: gridHeight)

            focusActions.frame(height: 52)
        }
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(width: width, height: height, alignment: .top)
        .background(.white)
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
        .sheet(item: $detail) { GenerativeProductReview(item: $0) }
        .sheet(isPresented: $showsLook) {
            DossierSelectionReview(record: record, spec: spec, merchants: merchants, session: session)
        }
    }

    private var bento: some View {
        let heroHeight = (gridHeight - gap) * 0.46
        let lowerHeight = gridHeight - heroHeight - gap
        let columnWidth = (contentWidth - gap) / 2
        return VStack(spacing: gap) {
            if let anchor = resolved(record.anchor) {
                objectButton(record.anchor, item: anchor, padding: 24)
                    .frame(width: contentWidth, height: heroHeight)
                    .accessibilityIdentifier("vomero.anchor")
            }
            HStack(spacing: gap) {
                pantsCompartment(width: columnWidth, height: lowerHeight)
                    .frame(width: columnWidth, height: lowerHeight)
                VStack(spacing: gap) {
                    if objects.indices.contains(3), let jacket = resolved(objects[3]) {
                        objectButton(objects[3], item: jacket, padding: 16)
                            .frame(height: (lowerHeight - gap) * 0.72)
                            .accessibilityIdentifier("vomero.jacket")
                    }
                    if objects.indices.contains(2), let socks = resolved(objects[2]) {
                        // A single sock illustrates the styling role. The original
                        // six-pack product and quantity remain in product details.
                        objectButton(objects[2], item: socks, padding: 8)
                            .frame(height: (lowerHeight - gap) * 0.28)
                            .accessibilityIdentifier("vomero.socks")
                    }
                }
                .frame(width: columnWidth)
            }
        }
    }

    private func objectButton(_ object: DossierReviewObject, item: ResolvedStoryProduct, padding: CGFloat) -> some View {
        Button {
            session.select(item, for: spec)
            session.focusRoomSlot(nil, for: spec)
        } label: {
            tileSurface.overlay {
                DossierObjectMedia(object: object, item: item).padding(padding)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!state.interactionsEnabled)
        .accessibilityLabel("Focus \(item.product.title)")
    }

    @ViewBuilder
    private func pantsCompartment(width: CGFloat, height: CGFloat) -> some View {
        if let object = pantsObject, let slot = pantsSlot, let current = resolved(object) {
            let candidates = slot.products.compactMap { NextGenerationFeedCardSpec.resolve($0, in: merchants) }
            ZStack {
                tileSurface
                if pantsExpanded {
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: gap) {
                                ForEach(candidates) { item in
                                    Button {
                                        selectPants(item, slot: slot)
                                        session.focusRoomSlot(nil, for: spec)
                                    } label: {
                                        DossierObjectMedia(object: object, item: item)
                                            .padding(12)
                                            .frame(width: width - 20, height: height - 44)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .id(item.id)
                                    .accessibilityLabel("Wear \(item.product.title)")
                                }
                            }.scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                        .scrollPosition(id: Binding<String?>(get: { current.id }, set: { id in
                            if let item = candidates.first(where: { $0.id == id }), item.id != current.id {
                                selectPants(item, slot: slot)
                            }
                        }), anchor: .leading)
                        .frame(height: height - 44)
                        .accessibilityIdentifier("vomero.pantsAlternatives")
                        HStack {
                            Text("\((candidates.firstIndex { $0.id == current.id } ?? 0) + 1) / \(candidates.count)")
                                .font(GravityFont.medium.fixedFont(size: 12)).foregroundStyle(.secondary)
                            Spacer()
                            Button("Done") { session.focusRoomSlot(nil, for: spec) }
                                .font(GravityFont.semiBold.fixedFont(size: 12)).frame(minWidth: 44, minHeight: 44)
                                .accessibilityIdentifier("vomero.finishSwap")
                        }.padding(.horizontal, 12)
                    }
                } else {
                    Button {
                        session.select(current, for: spec)
                        session.focusRoomSlot(slot.id, for: spec)
                    } label: {
                        VStack(spacing: 0) {
                            DossierObjectMedia(object: object, item: current)
                                .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 8)
                                .frame(height: height - 40)
                            HStack(spacing: 6) {
                                Text("Swap pants")
                                Image(systemName: "arrow.left.arrow.right").font(.system(size: 10, weight: .medium))
                            }
                            .font(GravityFont.medium.fixedFont(size: 12))
                            .frame(height: 40)
                        }
                        .frame(width: width, height: height)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Swap pants")
                    .accessibilityValue(current.product.title)
                    .accessibilityIdentifier("vomero.pants")
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .disabled(!state.interactionsEnabled)
        }
    }

    @ViewBuilder private var focusActions: some View {
        if let focused {
            HStack(spacing: 16) {
                Button { detail = focused } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(focused.product.title).font(GravityFont.medium.fixedFont(size: 13)).lineLimit(2)
                        Text("Product details").font(GravityFont.regular.fixedFont(size: 11)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                }.buttonStyle(.plain).accessibilityIdentifier("vomero.details")
                Button { showsLook = true } label: {
                    Text("View look").font(GravityFont.semiBold.fixedFont(size: 13)).frame(minHeight: 44)
                }.buttonStyle(.plain).accessibilityIdentifier("vomero.viewLook")
            }
        } else {
            Color.clear
        }
    }

    private var tileSurface: some View { Color.black.opacity(0.035) }
    private func resolved(_ object: DossierReviewObject) -> ResolvedStoryProduct? {
        if let slot = spec.groups.first(where: { $0.id == object.id }) {
            return session.roomProduct(slot: slot, for: spec, merchants: merchants)
        }
        return NextGenerationFeedCardSpec.resolve(object.reference, in: merchants)
    }
    private func selectPants(_ item: ResolvedStoryProduct, slot: PrototypeContentGroup) {
        HapticFeedback.selection.fire()
        // Deliberately do not animate the grid geometry; only this slot's
        // native pager moves. Other products never resize or shift.
        session.selectRoomProduct(item, slot: slot, for: spec)
    }
}
