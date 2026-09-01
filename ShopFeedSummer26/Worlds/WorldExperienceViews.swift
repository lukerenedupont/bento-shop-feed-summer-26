import SwiftUI

struct WorldExperienceContent: View {
    let definition: WorldDefinition
    @Bindable var session: WorldSession
    let products: [ResolvedStoryProduct]

    var body: some View {
        switch session.state.activeExperience {
        case .canvas:
            EmptyView()
        case .tryOn:
            TryOnWorldView(session: session, products: products)
        case .spatial:
            SpatialWorldView(session: session, products: products)
        case .mission:
            MissionWorldView(session: session, products: products)
        case .merchandised, .gifting:
            EmptyView()
        }
    }
}

struct WorldSteeringDock: View {
    @Bindable var session: WorldSession
    @State private var showsSteering = false
    @State private var instruction = ""

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            showsSteering = true
        } label: {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black.opacity(0.82))
                .frame(width: 56, height: 56)
                .background { Circle().fill(.white.opacity(0.52)) }
                .clipShape(Circle())
                .glassEffect(.regular, in: .circle)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.36), lineWidth: 0.5)
                }
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
        .accessibilityLabel("Steer this World")
        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
        .sheet(isPresented: $showsSteering) {
            VStack(alignment: .leading, spacing: GravitySpacing.space16) {
                HStack {
                    VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                        Text("Steer this World")
                            .font(GravityFont.expressiveBold.fixedFont(size: 24))
                        Text("Tell Shop what direction to take next")
                            .font(GravityFont.regular.fixedFont(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "waveform")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 48, height: 48)
                        .background(Color.black.opacity(0.06), in: Circle())
                }

                TextField("More colorful, less technical, under $200…", text: $instruction, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(GravitySpacing.space12)
                    .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))

                Button("Update World") {
                    session.send(.steer(instruction))
                    instruction = ""
                    showsSteering = false
                }
                .font(GravityFont.semiBold.fixedFont(size: 15))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.black, in: Capsule())
                .disabled(instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            }
            .padding(GravitySpacing.space20)
            .presentationDetents([.height(310)])
            .presentationDragIndicator(.visible)
            .environment(\.colorScheme, .light)
        }
    }
}

struct CanvasAgentWorldDestination: View {
    @Bindable var session: WorldSession
    let products: [ResolvedStoryProduct]
    let topInset: CGFloat
    let bottomInset: CGFloat
    let onClose: () -> Void

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var canvasProducts: [CatalogProduct]
    @State private var resetToken = 0
    @State private var hasInteracted = false
    @State private var canvasMotion = CanvasOrbMotion.zero
    @State private var canvasCommand: CanvasVoiceCommand?
    @State private var showsComposer = false
    @State private var instruction = ""

    init(
        session: WorldSession,
        products: [ResolvedStoryProduct],
        topInset: CGFloat,
        bottomInset: CGFloat,
        onClose: @escaping () -> Void
    ) {
        self.session = session
        self.products = products
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.onClose = onClose
        _canvasProducts = State(initialValue: CanvasAgentProductAdapter.products(from: products))
    }

    var body: some View {
        ZStack {
            InfiniteProductCanvas(
                products: canvasProducts,
                resultColumnCount: nil,
                resetToken: resetToken,
                voiceCommand: canvasCommand,
                hasInteracted: $hasInteracted,
                onSelect: openProduct,
                onRequestSimilar: showMoreLike,
                onRemove: removeProduct,
                onMotion: { canvasMotion = $0 }
            )
            .ignoresSafeArea()

            canvasHeader
            voiceControl
        }
        .background(Color.white.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .sheet(isPresented: $showsComposer) {
            canvasComposer
        }
        .task {
            guard !canvasProducts.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(220))
            canvasCommand = CanvasVoiceCommand(action: .voiceEntrance)
        }
    }

    private var canvasHeader: some View {
        ZStack {
            HStack {
                Button {
                    HapticFeedback.light.fire()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.82))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.52), in: Circle())
                        .glassEffect(.regular, in: .circle)
                        .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5) }
                }
                .buttonStyle(PressScaleButtonStyle())
                Spacer()

                Button {
                    resetToken += 1
                    canvasCommand = CanvasVoiceCommand(action: .showcase(resultCount: canvasProducts.count))
                } label: {
                    Image(systemName: "scope")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.82))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.52), in: Circle())
                        .glassEffect(.regular, in: .circle)
                        .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5) }
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Recenter canvas")
            }
        }
        .padding(.horizontal, GravitySpacing.space16)
        .padding(.top, topInset + GravitySpacing.space4)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var voiceControl: some View {
        Button {
            HapticFeedback.light.fire()
            showsComposer = true
        } label: {
            Image(systemName: "waveform")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.black.opacity(0.82))
                .frame(width: 58, height: 58)
                .background(.white.opacity(0.64), in: Circle())
                .glassEffect(.regular, in: .circle)
                .overlay { Circle().strokeBorder(.white.opacity(0.6), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
        .offset(
            x: -canvasMotion.displacement.width * 42,
            y: -canvasMotion.displacement.height * 30 + max(bottomInset - 28, 0)
        )
        .rotationEffect(.degrees(-Double(canvasMotion.velocity.width) * 3.5))
        .animation(.easeOut(duration: 0.16), value: canvasMotion)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityLabel("Steer this canvas")
    }

    private var canvasComposer: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            Text("Steer the canvas")
                .font(GravityFont.expressiveBold.fixedFont(size: 24))
            Text("The products and arrangement will change together.")
                .font(GravityFont.regular.fixedFont(size: 14))
                .foregroundStyle(.secondary)

            TextField("Less expensive and more unusual…", text: $instruction, axis: .vertical)
                .lineLimit(2...4)
                .padding(GravitySpacing.space12)
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: GravityRadius.r16))

            Button("Rebuild canvas") { applyInstruction() }
                .font(GravityFont.semiBold.fixedFont(size: 15))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.black, in: Capsule())
                .disabled(instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        }
        .padding(GravitySpacing.space20)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
        .environment(\.colorScheme, .light)
    }

    private func openProduct(_ product: CatalogProduct, source: ProductTransitionSource?) {
        source?.revealTile()
        guard let resolved = products.first(where: { $0.id == product.id }) else { return }
        session.send(.selectProduct(resolved.id))
        coordinator.pushRoute(.product(merchantId: resolved.merchant.id, productId: resolved.product.id))
    }

    private func showMoreLike(_ product: CatalogProduct) {
        session.send(.steer("More like \(product.title)"))
        let matching = canvasProducts.filter { $0.merchant == product.merchant || $0.category == product.category }
        let matchingIDs = Set(matching.map(\.id))
        canvasProducts = matching + canvasProducts.filter { !matchingIDs.contains($0.id) }
        resetToken += 1
        canvasCommand = CanvasVoiceCommand(action: .highlight(productIDs: matching.map(\.id)))
    }

    private func removeProduct(_ product: CatalogProduct) {
        session.send(.rejectProduct(product.id))
        canvasProducts.removeAll { $0.id == product.id }
        resetToken += 1
    }

    private func applyInstruction() {
        let prompt = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        session.send(.steer(prompt))
        let normalized = prompt.lowercased()
        if normalized.contains("less expensive") || normalized.contains("cheaper") || normalized.contains("budget") {
            canvasProducts.sort { $0.price < $1.price }
        } else if normalized.contains("premium") || normalized.contains("luxury") {
            canvasProducts.sort { $0.price > $1.price }
        } else {
            canvasProducts = Array(canvasProducts.dropFirst()) + canvasProducts.prefix(1)
        }
        instruction = ""
        showsComposer = false
        resetToken += 1
        canvasCommand = CanvasVoiceCommand(action: .play(CanvasPlayCommand(
            action: .cascade,
            productIDs: canvasProducts.map(\.id),
            sequence: .centerOut
        )))
    }
}

#if false // Superseded by the canvas-agent implementation above.
private struct CanvasWorldView: View {
    @Bindable var session: WorldSession
    let products: [ResolvedStoryProduct]
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var selectedInstruction = "More distinctive"

    private var visibleProducts: [ResolvedStoryProduct] {
        let available = products.filter { !session.state.rejectedProductIDs.contains($0.id) }
        return available.isEmpty ? products : available
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            worldIntro(
                title: "Shape the shortlist",
                subtitle: "Move through the watches, keep what feels right, and push the rest away.",
                session: session
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(["More distinctive", "Less sporty", "Under $400", "Independent shops"], id: \.self) { instruction in
                        Button {
                            HapticFeedback.light.fire()
                            selectedInstruction = instruction
                            session.send(.steer(instruction))
                        } label: {
                            Text(instruction)
                                .font(GravityFont.semiBold.fixedFont(size: 13))
                                .foregroundStyle(selectedInstruction == instruction ? .black : .white)
                                .padding(.horizontal, GravitySpacing.space12)
                                .frame(height: 40)
                                .background(
                                    selectedInstruction == instruction ? Color.white : Color.white.opacity(0.12),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
            }

            GeometryReader { geometry in
                let cardWidth = min(184, geometry.size.width * 0.46)
                ZStack {
                    ForEach(Array(visibleProducts.prefix(6).enumerated()), id: \.element.id) { index, item in
                        canvasCard(item, width: cardWidth)
                            .rotationEffect(.degrees(canvasRotation(index)))
                            .position(canvasPosition(index, in: geometry.size, cardWidth: cardWidth))
                            .zIndex(session.state.selectedProductID == item.id ? 10 : Double(index))
                    }
                }
            }
            .frame(height: 570)
            .padding(.horizontal, GravitySpacing.space8)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .padding(.horizontal, GravitySpacing.space12)

            if let selected = visibleProducts.first(where: { $0.id == session.state.selectedProductID }) {
                HStack(spacing: GravitySpacing.space12) {
                    VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                        Text(selected.product.title)
                            .font(GravityFont.bold.fixedFont(size: 17))
                            .lineLimit(1)
                        Text("Keep it, remove it, or open the product")
                            .font(GravityFont.regular.fixedFont(size: 12))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    Spacer()
                    Button {
                        session.send(.rejectProduct(selected.id))
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.10), in: Circle())
                    }
                    Button {
                        session.send(.saveProduct(selected.id))
                    } label: {
                        Image(systemName: session.state.savedProductIDs.contains(selected.id) ? "heart.fill" : "heart")
                            .frame(width: 40, height: 40)
                            .background(.white, in: Circle())
                            .foregroundStyle(Color(hex: "#392657"))
                    }
                }
                .foregroundStyle(.white)
                .padding(GravitySpacing.space16)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                .padding(.horizontal, GravitySpacing.space12)
            }
        }
        .padding(.bottom, 140)
    }

    private func canvasCard(_ item: ResolvedStoryProduct, width: CGFloat) -> some View {
        Button {
            HapticFeedback.light.fire()
            session.send(.selectProduct(item.id))
        } label: {
            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                ProductImageView(product: item.product, merchant: item.merchant)
                    .frame(width: width - 16, height: 142)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                Text(item.product.title)
                    .font(GravityFont.bold.fixedFont(size: 14))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                HStack {
                    Text(item.merchant.displayName)
                        .lineLimit(1)
                    Spacer()
                    Text(formatPrice(item.product.price))
                }
                .font(GravityFont.medium.fixedFont(size: 11))
                .foregroundStyle(.black.opacity(0.55))
            }
            .padding(GravitySpacing.space8)
            .frame(width: width, height: 224, alignment: .topLeading)
            .background(.white, in: RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .overlay {
                if session.state.selectedProductID == item.id {
                    RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                        .strokeBorder(Color(hex: "#9A7BD0"), lineWidth: 3)
                }
            }
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        }
        .buttonStyle(PressScaleButtonStyle())
        .contextMenu {
            Button("Open product") {
                coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
            }
            Button("Not for me", role: .destructive) {
                session.send(.rejectProduct(item.id))
            }
        }
    }

    private func canvasRotation(_ index: Int) -> Double {
        [-4, 3, -1.5, 4, -3, 2][index % 6]
    }

    private func canvasPosition(_ index: Int, in size: CGSize, cardWidth: CGFloat) -> CGPoint {
        let columns: [CGFloat] = [0.25, 0.72, 0.28, 0.74, 0.27, 0.72]
        let rows: [CGFloat] = [0.22, 0.26, 0.59, 0.62, 0.94, 0.96]
        return CGPoint(
            x: max(cardWidth / 2, min(size.width - cardWidth / 2, size.width * columns[index % 6])),
            y: min(size.height - 112, max(112, size.height * rows[index % 6]))
        )
    }
}
#endif

private struct TryOnWorldView: View {
    @Bindable var session: WorldSession
    let products: [ResolvedStoryProduct]
    @Environment(NavigationCoordinator.self) private var coordinator

    private var selected: ResolvedStoryProduct? {
        products.first(where: { $0.id == session.state.selectedProductID }) ?? products.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            worldIntro(
                title: "See the shape on you",
                subtitle: "Start with wide-fit polarized frames, then compare silhouettes without losing the shortlist.",
                session: session
            )

            ZStack(alignment: .bottom) {
                Image("try-on-studio")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 470)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                if let selected {
                    VStack(spacing: GravitySpacing.space12) {
                        ProductImageView(product: selected.product, merchant: selected.merchant)
                            .frame(width: 210, height: 108)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                            .shadow(color: .black.opacity(0.24), radius: 18, y: 8)

                        HStack {
                            VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                                Text(selected.product.title)
                                    .font(GravityFont.bold.fixedFont(size: 17))
                                    .lineLimit(1)
                                Text("\(selected.merchant.displayName) · \(formatPrice(selected.product.price))")
                                    .font(GravityFont.medium.fixedFont(size: 12))
                                    .foregroundStyle(.white.opacity(0.68))
                            }
                            Spacer()
                            Button {
                                session.send(.saveProduct(selected.id))
                            } label: {
                                Image(systemName: session.state.savedProductIDs.contains(selected.id) ? "heart.fill" : "heart")
                                    .frame(width: 44, height: 44)
                                    .background(.white, in: Circle())
                                    .foregroundStyle(.black)
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(GravitySpacing.space16)
                }
            }
            .frame(height: 470)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .padding(.horizontal, GravitySpacing.space12)

            VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                Text("Try another frame")
                    .font(GravityFont.expressiveBold.fixedFont(size: 21))
                    .foregroundStyle(.white)
                    .padding(.horizontal, GravitySpacing.space12)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GravitySpacing.space8) {
                        ForEach(products) { item in
                            Button {
                                HapticFeedback.light.fire()
                                session.send(.selectProduct(item.id))
                            } label: {
                                ProductImageView(product: item.product, merchant: item.merchant)
                                    .frame(width: 112, height: 86)
                                    .clipped()
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                                    .overlay {
                                        if selected?.id == item.id {
                                            RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                                                .strokeBorder(.white, lineWidth: 3)
                                        }
                                    }
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, GravitySpacing.space12)
                }
            }
        }
        .padding(.bottom, 140)
    }
}

private struct SpatialWorldView: View {
    @Bindable var session: WorldSession
    let products: [ResolvedStoryProduct]
    @Environment(NavigationCoordinator.self) private var coordinator

    private var selected: ResolvedStoryProduct? {
        products.first(where: { $0.id == session.state.selectedProductID }) ?? products.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            worldIntro(
                title: "Build the room in place",
                subtitle: "Swap pieces against the same warm, sculptural direction.",
                session: session
            )

            ZStack(alignment: .bottomLeading) {
                Image("topic-warm-lighting-hero")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 490)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.76)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                if let selected {
                    HStack(spacing: GravitySpacing.space12) {
                        ProductImageView(product: selected.product, merchant: selected.merchant)
                            .frame(width: 96, height: 96)
                            .clipped()
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                        VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                            Text("In the room")
                                .font(GravityFont.medium.fixedFont(size: 12))
                                .foregroundStyle(.white.opacity(0.66))
                            Text(selected.product.title)
                                .font(GravityFont.bold.fixedFont(size: 18))
                                .lineLimit(2)
                            Text(formatPrice(selected.product.price))
                                .font(GravityFont.semiBold.fixedFont(size: 13))
                        }
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(GravitySpacing.space16)
                }
            }
            .frame(height: 490)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .padding(.horizontal, GravitySpacing.space12)

            VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                Text("Swap what’s in the room")
                    .font(GravityFont.expressiveBold.fixedFont(size: 21))
                    .foregroundStyle(.white)
                    .padding(.horizontal, GravitySpacing.space12)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GravitySpacing.space8) {
                        ForEach(products) { item in
                            Button {
                                HapticFeedback.light.fire()
                                session.send(.selectProduct(item.id))
                            } label: {
                                VStack(alignment: .leading, spacing: GravitySpacing.space6) {
                                    ProductImageView(product: item.product, merchant: item.merchant)
                                        .frame(width: 132, height: 132)
                                        .clipped()
                                    Text(item.product.title)
                                        .font(GravityFont.bold.fixedFont(size: 13))
                                        .foregroundStyle(.black)
                                        .lineLimit(1)
                                        .padding(.horizontal, GravitySpacing.space8)
                                }
                                .padding(.bottom, GravitySpacing.space8)
                                .background(.white, in: RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, GravitySpacing.space12)
                }
            }
        }
        .padding(.bottom, 140)
    }
}

private struct MissionWorldView: View {
    @Bindable var session: WorldSession
    let products: [ResolvedStoryProduct]

    private let steps = [
        ("equipment", "Equipment", "Skis, boots, and bindings"),
        ("layers", "Mountain layers", "Weather-ready warmth"),
        ("travel", "Travel setup", "What gets there with you"),
        ("recovery", "After the mountain", "Comfort for the end of the day"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            worldIntro(
                title: "Get ready without overpacking",
                subtitle: "A working plan for the mountain, travel, and everything after.",
                session: session
            )

            VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Weekend readiness")
                        .font(GravityFont.expressiveBold.fixedFont(size: 22))
                    Spacer()
                    Text("\(session.state.completedMissionSteps.count) of \(steps.count)")
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                        .foregroundStyle(.white.opacity(0.58))
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(.white)
                            .frame(width: geometry.size.width * CGFloat(session.state.completedMissionSteps.count) / CGFloat(steps.count))
                    }
                }
                .frame(height: 7)

                ForEach(steps, id: \.0) { step in
                    Button {
                        HapticFeedback.light.fire()
                        session.send(.toggleMissionStep(step.0))
                    } label: {
                        HStack(spacing: GravitySpacing.space12) {
                            Image(systemName: session.state.completedMissionSteps.contains(step.0) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22, weight: .semibold))
                            VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                                Text(step.1)
                                    .font(GravityFont.bold.fixedFont(size: 16))
                                Text(step.2)
                                    .font(GravityFont.regular.fixedFont(size: 12))
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.44))
                        }
                        .foregroundStyle(.white)
                        .padding(GravitySpacing.space12)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, GravitySpacing.space12)

            VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                Text("Start with the hard gear")
                    .font(GravityFont.expressiveBold.fixedFont(size: 21))
                    .foregroundStyle(.white)
                    .padding(.horizontal, GravitySpacing.space12)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GravitySpacing.space8) {
                        ForEach(products) { item in
                            WorldProductTile(item: item, session: session)
                        }
                    }
                    .padding(.horizontal, GravitySpacing.space12)
                }
            }
        }
        .padding(.bottom, 140)
    }
}

private struct WorldProductTile: View {
    let item: ResolvedStoryProduct
    @Bindable var session: WorldSession
    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            session.send(.viewProduct(item.id))
            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
        } label: {
            ProductCard(
                image: nil,
                imageURL: item.product.imageURL,
                merchantName: item.merchant.displayName,
                productName: item.product.title,
                price: formatPrice(item.product.price),
                showFavoriteButton: true,
                favoriteIconHasContrastShadow: true
            )
            .frame(width: 148)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private func worldIntro(title: String, subtitle: String, session: WorldSession) -> some View {
    HStack(alignment: .top, spacing: GravitySpacing.space12) {
        VStack(alignment: .leading, spacing: GravitySpacing.space4) {
            Text(title)
                .font(GravityFont.expressiveBold.fixedFont(size: 24))
                .tracking(-0.55)
            Text(subtitle)
                .font(GravityFont.regular.fixedFont(size: 14))
                .foregroundStyle(.white.opacity(0.62))
        }
        Spacer()
        WorldExplanationButton(session: session)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, GravitySpacing.space12)
}

private struct WorldExplanationButton: View {
    let session: WorldSession
    @State private var showsExplanation = false

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            showsExplanation = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.10), in: Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Why you’re seeing this")
        .sheet(isPresented: $showsExplanation) {
            VStack(alignment: .leading, spacing: GravitySpacing.space16) {
                Text("Why you’re seeing this")
                    .font(GravityFont.expressiveBold.fixedFont(size: 24))
                Text("This World combines what you’ve told Shop with products and shops related to what you’re trying to accomplish. You can steer it without changing your broader recommendations.")
                    .font(GravityFont.regular.fixedFont(size: 15))
                    .foregroundStyle(.secondary)

                ForEach(session.context.resolvedFacts) { fact in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                            Text(fact.key.replacingOccurrences(of: "-", with: " ").capitalized)
                                .font(GravityFont.semiBold.fixedFont(size: 14))
                            Text(fact.value)
                                .font(GravityFont.regular.fixedFont(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(fact.source.rawValue.capitalized)
                            .font(GravityFont.medium.fixedFont(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
            .padding(GravitySpacing.space20)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .environment(\.colorScheme, .light)
        }
    }
}
