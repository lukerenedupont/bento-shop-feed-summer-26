import SwiftUI
import ShopFisheyeCanvas

/// Twelve native primitives, recursively composed. No switch on card/merchant ID.
struct CompositionNodeView: View {
    let node: CompositionNode
    let context: CompositionContext
    let size: CGSize
    let active: Bool
    let onDetail: (ResolvedStoryProduct) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let gap: CGFloat = 10
    private var state: GenerativeFeedPrototypeSession.CardState { context.state }

    var body: some View {
        content.frame(width: max(0, size.width), height: max(0, size.height)).clipped()
            .foregroundStyle(context.ink)
    }
    @ViewBuilder private var content: some View {
        switch node.kind {
        case .spacer: Color.clear
        case .row: weightedStack(horizontal: true)
        case .column: weightedStack(horizontal: false)
        case .media:
            let entity = node.role.flatMap(context.entity)
            if let asset = NextGeneration20Catalog.asset(node.asset ?? entity?.scene ?? entity?.art) {
                CompositionMedia(asset: asset,
                    active: active && node.mode == "video",
                    fills: !(node.fit ?? false))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityLabel("Styling image")
            }
        case .product: product
        case .grid: productGrid
        case .choice: choice
        case .compare: comparison
        case .steps: stepSelector
        case .pager: pager
        case .merchant: merchant
        case .canvas: canvas
        }
    }

    private func child(_ child: CompositionNode, width: CGFloat, height: CGFloat, active: Bool? = nil) -> CompositionNodeView {
        CompositionNodeView(node: child, context: context, size: .init(width: max(0, width), height: max(0, height)),
            active: active ?? self.active, onDetail: onDetail)
    }
    private func dimension(index: Int, horizontal: Bool) -> CGFloat {
        let children = node.children ?? []
        let weights = node.weights?.count == children.count ? node.weights! : Array(repeating: 1, count: children.count)
        let extent = max(0, (horizontal ? size.width : size.height) - gap * CGFloat(max(0, children.count - 1)))
        return extent * CGFloat(weights[index]) / CGFloat(max(1, weights.reduce(0, +)))
    }
    @ViewBuilder private func weightedStack(horizontal: Bool) -> some View {
        if horizontal {
            HStack(spacing: gap) {
                ForEach(Array((node.children ?? []).enumerated()), id: \.element.id) { index, childNode in
                    child(childNode, width: dimension(index: index, horizontal: true), height: size.height)
                }
            }
        } else {
            VStack(spacing: gap) {
                ForEach(Array((node.children ?? []).enumerated()), id: \.element.id) { index, childNode in
                    child(childNode, width: size.width, height: dimension(index: index, horizontal: false))
                }
            }
        }
    }

    @ViewBuilder private var product: some View {
        if let role = node.role, let item = context.product(role) {
            let slot = context.spec.groups.first { $0.id == "slot.\(role)" }
            if let slot, state.roomSlotID == slot.id {
                VStack(spacing: 0) {
                    let roles = node.alternatives ?? []
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(roles, id: \.self) { optionRole in
                                if let candidate = context.directProduct(optionRole) {
                                    Button {
                                        context.session.selectRoomProduct(candidate, slot: slot, for: context.spec)
                                        context.session.focusRoomSlot(nil, for: context.spec)
                                    } label: {
                                        CompositionProductImage(role: optionRole, context: context)
                                            .frame(width: max(44, size.width - 20), height: max(44, size.height - 42))
                                    }
                                    .buttonStyle(.plain).id(candidate.id)
                                    .accessibilityLabel("Use \(candidate.product.title)")
                                }
                            }
                        }.scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollPosition(id: Binding<String?>(get: { item.id }, set: { id in
                        if let candidate = roles.compactMap(context.directProduct).first(where: { $0.id == id }), candidate.id != item.id {
                            context.session.selectRoomProduct(candidate, slot: slot, for: context.spec)
                        }
                    }), anchor: .leading)
                    Button("Done") { context.session.focusRoomSlot(nil, for: context.spec) }
                        .font(GravityFont.semiBold.fixedFont(size: 12)).frame(height: 42)
                }
                .background(context.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
            } else {
                Button {
                    if let slot {
                        context.session.select(item, for: context.spec)
                        context.session.focusRoomSlot(slot.id, for: context.spec)
                    } else if state.selectedID == item.id {
                        onDetail(item)
                    } else {
                        context.session.select(item, for: context.spec)
                    }
                } label: {
                    CompositionProductImage(role: role, context: context, mode: node.mode ?? "object")
                        .overlay(alignment: .bottomTrailing) {
                            if slot != nil {
                                Image(systemName: "arrow.left.arrow.right").font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.black).frame(width: 32, height: 32)
                                    .background(.white.opacity(0.85), in: Circle()).padding(8)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(!state.interactionsEnabled)
                .accessibilityLabel(slot == nil ? "Focus \(item.product.title)" : "Swap \(item.product.title)")
                .accessibilityIdentifier("ng20.product.\(node.id)")
            }
        }
    }

    private var productGrid: some View {
        let roles = context.expandedRoles(node.roles ?? [])
        let columns = min(4, max(1, node.columns ?? 2))
        let rows = max(1, Int(ceil(Double(roles.count) / Double(columns))))
        let side = max(1, min((size.width - gap * CGFloat(columns - 1)) / CGFloat(columns),
                             (size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)))
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: gap), count: columns), spacing: gap) {
            ForEach(roles, id: \.self) { role in
                if let item = context.product(role) {
                    Button {
                        if state.selectedID == item.id { onDetail(item) }
                        else { context.session.select(item, for: context.spec) }
                    } label: {
                        CompositionProductImage(role: role, context: context, mode: "tile")
                            .frame(width: side, height: side)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18).strokeBorder(state.selectedID == item.id ? context.ink : .clear, lineWidth: 2)
                            }
                    }.buttonStyle(.plain).accessibilityLabel("Focus \(item.product.title)")
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .center)
    }

    @ViewBuilder private var choice: some View {
        if context.session.activeGroup(for: context.spec) != nil, let response = node.response {
            VStack(spacing: 8) {
                child(response, width: size.width, height: max(0, size.height - 40))
                Button("Change direction") { context.session.clearGroup(context.spec) }
                    .font(GravityFont.medium.fixedFont(size: 13)).frame(height: 32)
                    .accessibilityIdentifier("ng20.changeDirection")
            }
        } else {
            let options = node.options ?? []
            let isColumn = node.axis == "column"
            let w = isColumn ? size.width : (size.width - gap * CGFloat(max(0, options.count - 1))) / CGFloat(max(1, options.count))
            let h = isColumn ? (size.height - gap * CGFloat(max(0, options.count - 1))) / CGFloat(max(1, options.count)) : size.height
            if node.axis == "featured", options.count == 3 {
                // One contextual photograph leads; companions remain usable
                // destinations rather than three equally narrow poster strips.
                let leadWidth = (size.width - gap) * 0.64
                let companionWidth = size.width - gap - leadWidth
                HStack(spacing: gap) {
                    choiceTile(options[0], width: leadWidth, height: size.height)
                    VStack(spacing: gap) {
                        choiceTile(options[1], width: companionWidth, height: (size.height - gap) / 2)
                        choiceTile(options[2], width: companionWidth, height: (size.height - gap) / 2)
                    }
                }
            } else if isColumn {
                VStack(spacing: gap) { ForEach(options) { choiceTile($0, width: w, height: h) } }
            } else {
                HStack(spacing: gap) { ForEach(options) { choiceTile($0, width: w, height: h) } }
            }
        }
    }
    private func choiceTile(_ choice: CompositionChoice, width: CGFloat, height: CGFloat) -> some View {
        Button {
            if let group = context.spec.groups.first(where: { $0.id == choice.id }) {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { context.session.choose(group, for: context.spec) }
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                child(choice.preview, width: width, height: height, active: false).allowsHitTesting(false).accessibilityHidden(true)
                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
                Text(choice.title).font(GravityFont.semiBold.fixedFont(size: 14)).foregroundStyle(.white).padding(12)
            }.frame(width: width, height: height).clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain).accessibilityLabel("Choose \(choice.title)")
        .accessibilityIdentifier("ng20.choice.\(choice.id)")
    }

    @ViewBuilder private var comparison: some View {
        let roles = node.roles ?? []
        if state.comparisonRevealed {
            let selectedRoles = roles.filter { context.product($0).map { state.comparisonIDs.contains($0.id) } ?? false }
            HStack(alignment: .top, spacing: 14) {
                ForEach(selectedRoles, id: \.self) { role in
                    if let item = context.product(role) {
                        VStack(alignment: .leading, spacing: 12) {
                            Button { onDetail(item) } label: {
                                CompositionProductImage(role: role, context: context).frame(height: size.height * 0.55)
                            }.buttonStyle(.plain)
                            Text(item.product.title).font(GravityFont.semiBold.fixedFont(size: 15)).lineLimit(3)
                            Text(GenerativeFeedStyle.price(item.product)).font(GravityFont.medium.fixedFont(size: 18))
                            Text(item.merchant.displayName).font(GravityFont.regular.fixedFont(size: 12)).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        } else {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ForEach(Array(roles.prefix(2)), id: \.self) { comparisonTile($0) }
                }
                .frame(height: roles.count > 2 ? (size.height - 10) * 0.62 : size.height)
                if roles.count > 2 {
                    HStack(spacing: 12) {
                        ForEach(Array(roles.dropFirst(2)), id: \.self) { comparisonTile($0) }
                    }.frame(height: (size.height - 10) * 0.38)
                }
            }
        }
    }

    @ViewBuilder private func comparisonTile(_ role: String) -> some View {
        if let item = context.product(role) {
            Button { context.session.toggleReviewComparison(item, for: context.spec) } label: {
                CompositionProductImage(role: role, context: context)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: state.comparisonIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22)).padding(10)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Compare \(item.product.title)")
            .accessibilityIdentifier("ng20.compare.\(item.product.id)")
        }
    }

    @ViewBuilder private var stepSelector: some View {
        let roles = node.roles ?? []
        if node.axis == "column" {
            VStack(spacing: 8) {
                ForEach(Array(roles.enumerated()), id: \.element) { i, role in step(role, index: i) }
            }
        } else {
            HStack(spacing: 10) {
                ForEach(Array(roles.enumerated()), id: \.element) { i, role in step(role, index: i) }
            }
        }
    }
    private func step(_ role: String, index: Int) -> some View {
        Button {
            if let item = context.product(role) { context.session.select(item, for: context.spec) }
        } label: {
            VStack(spacing: 6) {
                CompositionProductImage(role: role, context: context)
                HStack(spacing: 5) {
                    Text("\(index + 1)").foregroundStyle(context.ink.opacity(0.5))
                    Text((node.labels?.indices.contains(index) ?? false) ? node.labels![index] : role.capitalized)
                }.font(GravityFont.medium.fixedFont(size: 12))
                Capsule().fill(context.product(role)?.id == context.selected?.id ? context.ink : .clear).frame(width: 22, height: 2)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain).accessibilityLabel("Select \((node.labels?.indices.contains(index) ?? false) ? node.labels![index] : role)")
    }

    private var pager: some View {
        let children = node.children ?? []
        let index = state.compositionPages[node.id] ?? 0
        return TabView(selection: Binding(get: { index }, set: { context.session.setCompositionPage($0, nodeID: node.id, for: context.spec) })) {
            ForEach(Array(children.enumerated()), id: \.element.id) { i, childNode in
                child(childNode, width: size.width, height: size.height, active: active && i == index).tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    @ViewBuilder private var merchant: some View {
        if let item = context.product(node.role ?? "$selected") {
            HStack(spacing: 12) {
                if item.merchant.logoImageURL != nil { MerchantAvatarView(merchant: item.merchant, size: 38) }
                let name = DossierReviewLibrary.records.first(where: { $0.anchor.reference.merchantID == item.merchant.id })?.merchant
                    ?? item.merchant.displayName
                Text(name)
                    .font(GravityFont.semiBold.fixedFont(size: 17))
                Spacer()
            }.padding(8)
        }
    }

    private var canvas: some View {
        let products = context.definition.order.compactMap(context.directProduct)
        return FisheyeCanvas(items: products,
            position: Binding(get: { state.canvasPosition }, set: { context.session.setCanvasPosition($0, for: context.spec) }),
            isInteractive: state.canvasIsExploring && state.interactionsEnabled, isActive: active) { item in
                Button {
                    if state.selectedID == item.id { onDetail(item) }
                    else { context.session.select(item, for: context.spec) }
                } label: {
                    if let role = context.role(for: item) {
                        CompositionProductImage(role: role, context: context)
                            .padding(8).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }
                }.buttonStyle(.plain).accessibilityLabel("Focus \(item.product.title)")
            }
            .background(Color(white: 0.93), in: RoundedRectangle(cornerRadius: 22))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .onDisappear { context.session.setCanvasExploring(false, for: context.spec) }
    }
}
