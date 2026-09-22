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
            EmptyView()
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
                                Text("\(selected.merchant.displayName) · \(formatPrice(selected.product))")
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

private struct MissionStepDefinition: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let guidance: String
    let symbol: String
    let keywords: Set<String>
}

private struct MissionWorldView: View {
    @Bindable var session: WorldSession
    let products: [ResolvedStoryProduct]

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var expandedStepID = "equipment"

    private let steps: [MissionStepDefinition] = [
        .init(
            id: "equipment",
            title: "Hard gear",
            subtitle: "Skis, boots, bindings, and poles",
            guidance: "Decide what travels with you and what is easier to rent on arrival.",
            symbol: "figure.skiing.downhill",
            keywords: ["ski", "skis", "boot", "boots", "binding", "bindings", "pole", "poles"]
        ),
        .init(
            id: "layers",
            title: "Mountain layers",
            subtitle: "Weather-ready warmth",
            guidance: "Build one adaptable system rather than packing for every forecast.",
            symbol: "cloud.snow",
            keywords: ["jacket", "shell", "fleece", "hoodie", "parka", "glove", "goggle", "helmet", "sweater"]
        ),
        .init(
            id: "travel",
            title: "Travel setup",
            subtitle: "What gets there with you",
            guidance: "Keep essentials together and leave room for bulky mountain gear.",
            symbol: "airplane",
            keywords: ["backpack", "duffel", "luggage", "carry", "bag"]
        ),
        .init(
            id: "recovery",
            title: "After the mountain",
            subtitle: "Comfort for the end of the day",
            guidance: "Choose one easy recovery option instead of another full outfit.",
            symbol: "sparkles",
            keywords: ["recovery", "clog", "sandal", "slipper", "sock", "mule"]
        ),
    ]

    private var completedCount: Int {
        steps.filter { session.state.missionDecisions[$0.id] != nil }.count
    }

    private var isReady: Bool { completedCount == steps.count }

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space24) {
            worldIntro(
                title: "Get ready without overpacking",
                subtitle: "A working plan for the mountain, travel, and everything after.",
                session: session
            )

            tripContext
            readinessSummary

            VStack(spacing: GravitySpacing.space8) {
                ForEach(steps) { step in
                    missionStep(step)
                }
            }
            .padding(.horizontal, GravitySpacing.space12)

            missionPlan
        }
        .padding(.bottom, 140)
        .animation(SpringPreset.smooth, value: expandedStepID)
        .animation(SpringPreset.smooth, value: session.state.missionDecisions)
    }

    private var tripContext: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space8) {
                contextMenu(
                    symbol: "mountain.2.fill",
                    factKey: "mountain",
                    fallback: "Whistler",
                    choices: ["Whistler", "Tahoe", "Aspen"]
                )
                contextMenu(
                    symbol: "calendar",
                    factKey: "dates",
                    fallback: "Feb 20–23",
                    choices: ["Feb 20–23", "Mar 6–9", "Mar 13–16"]
                )
                contextMenu(
                    symbol: "figure.skiing.downhill",
                    factKey: "ability",
                    fallback: "Advanced",
                    choices: ["Intermediate", "Advanced", "Expert"]
                )
                contextMenu(
                    symbol: "airplane",
                    factKey: "travel",
                    fallback: "Flying",
                    choices: ["Flying", "Driving"]
                )
            }
            .padding(.horizontal, GravitySpacing.space12)
        }
    }

    private func contextMenu(
        symbol: String,
        factKey: String,
        fallback: String,
        choices: [String]
    ) -> some View {
        Menu {
            ForEach(choices, id: \.self) { choice in
                Button(choice) {
                    session.send(.setFact(WorldFact(
                        key: factKey,
                        value: choice,
                        source: .stated,
                        scope: factKey == "ability" ? .subject : .local
                    )))
                }
            }
        } label: {
            HStack(spacing: GravitySpacing.space6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(session.context.value(for: factKey) ?? fallback)
                    .font(GravityFont.semiBold.fixedFont(size: 13))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.50))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, GravitySpacing.space12)
            .frame(height: GravitySpacing.space36)
            .background(.white.opacity(0.10), in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5) }
        }
    }

    private var readinessSummary: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                    Text(isReady ? "Weekend ready" : "Weekend readiness")
                        .font(GravityFont.expressiveBold.fixedFont(size: 22))
                    Text(isReady
                        ? "Your gear and packing decisions are covered."
                        : "\(steps.count - completedCount) decisions left")
                        .font(GravityFont.regular.fixedFont(size: 13))
                        .foregroundStyle(.white.opacity(0.60))
                }
                Spacer()
                Text("\(completedCount) of \(steps.count)")
                    .font(GravityFont.semiBold.fixedFont(size: 13))
                    .foregroundStyle(.white.opacity(0.62))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(.white)
                        .frame(
                            width: geometry.size.width
                                * CGFloat(completedCount) / CGFloat(steps.count)
                        )
                }
            }
            .frame(height: 7)
        }
        .padding(GravitySpacing.space16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
        .padding(.horizontal, GravitySpacing.space12)
    }

    private func missionStep(_ step: MissionStepDefinition) -> some View {
        let isExpanded = expandedStepID == step.id
        let decision = session.state.missionDecisions[step.id]

        return VStack(spacing: 0) {
            Button {
                HapticFeedback.light.fire()
                expandedStepID = isExpanded ? "" : step.id
            } label: {
                HStack(spacing: GravitySpacing.space12) {
                    Image(systemName: decision == nil ? step.symbol : "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(decision == nil ? .white : .black)
                        .frame(width: GravitySpacing.space36, height: GravitySpacing.space36)
                        .background(
                            decision == nil ? .white.opacity(0.10) : .white,
                            in: Circle()
                        )

                    VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                        Text(step.title)
                            .font(GravityFont.bold.fixedFont(size: 16))
                        Text(decision.map(decisionLabel) ?? step.subtitle)
                            .font(GravityFont.regular.fixedFont(size: 12))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.44))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(.white)
                .padding(GravitySpacing.space12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                stepEditor(step)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.white.opacity(isExpanded ? 0.10 : 0.07), in: RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                .strokeBorder(.white.opacity(isExpanded ? 0.16 : 0.08), lineWidth: 0.5)
        }
    }

    private func stepEditor(_ step: MissionStepDefinition) -> some View {
        let recommendations = recommendations(for: step)
        let selected = selectedProduct(for: step, recommendations: recommendations)

        return VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            Divider().overlay(.white.opacity(0.12))
            Text(step.guidance)
                .font(GravityFont.regular.fixedFont(size: 13))
                .foregroundStyle(.white.opacity(0.66))
                .padding(.horizontal, GravitySpacing.space12)

            if !recommendations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GravitySpacing.space8) {
                        ForEach(recommendations) { item in
                            missionProductTile(
                                item,
                                isSelected: selected?.id == item.id,
                                stepID: step.id
                            )
                        }
                    }
                    .padding(.horizontal, GravitySpacing.space12)
                }

                if let selected {
                    Button {
                        session.send(.viewProduct(selected.id))
                        coordinator.pushRoute(.product(
                            merchantId: selected.merchant.id,
                            productId: selected.product.id
                        ))
                    } label: {
                        HStack {
                            Text(selected.product.title)
                                .font(GravityFont.semiBold.fixedFont(size: 13))
                                .lineLimit(1)
                            Spacer()
                            Text(formatPrice(selected.product))
                                .font(GravityFont.medium.fixedFont(size: 12))
                                .foregroundStyle(.white.opacity(0.62))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, GravitySpacing.space12)
                    }
                    .buttonStyle(.plain)
                }
            }

            dispositionPicker(for: step, selected: selected)
                .padding(.horizontal, GravitySpacing.space12)
                .padding(.bottom, GravitySpacing.space12)
        }
    }

    private func missionProductTile(
        _ item: ResolvedStoryProduct,
        isSelected: Bool,
        stepID: String
    ) -> some View {
        Button {
            HapticFeedback.selection.fire()
            session.send(.selectMissionProduct(stepID: stepID, productID: item.id))
        } label: {
            ProductImageView(product: item.product, merchant: item.merchant)
                .frame(width: 104, height: 104)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(isSelected ? .black : .white, .white)
                        .padding(GravitySpacing.space8)
                        .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                        .strokeBorder(.white.opacity(isSelected ? 0.90 : 0.16), lineWidth: isSelected ? 2 : 0.5)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func dispositionPicker(
        for step: MissionStepDefinition,
        selected: ResolvedStoryProduct?
    ) -> some View {
        HStack(spacing: GravitySpacing.space6) {
            ForEach(MissionDisposition.allCases, id: \.self) { disposition in
                let isSelected = session.state.missionDecisions[step.id]?.disposition == disposition
                Button {
                    HapticFeedback.medium.fire()
                    let productID = disposition == .owned ? nil : selected?.id
                    session.send(.setMissionDecision(MissionDecision(
                        stepID: step.id,
                        disposition: disposition,
                        productID: productID
                    )))
                } label: {
                    Text(disposition.label)
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                        .foregroundStyle(isSelected ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: GravitySpacing.space36)
                        .background(isSelected ? .white : .white.opacity(0.09), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(disposition != .owned && selected == nil)
                .opacity(disposition != .owned && selected == nil ? 0.38 : 1)
            }
        }
    }

    @ViewBuilder
    private var missionPlan: some View {
        if !session.state.missionDecisions.isEmpty {
            VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                Text(isReady ? "Your packing plan" : "Plan so far")
                    .font(GravityFont.expressiveBold.fixedFont(size: 21))

                ForEach(steps.filter { session.state.missionDecisions[$0.id] != nil }) { step in
                    if let decision = session.state.missionDecisions[step.id] {
                        HStack(spacing: GravitySpacing.space10) {
                            Image(systemName: decision.disposition == .owned ? "checkmark" : decision.disposition == .rent ? "arrow.triangle.2.circlepath" : "bag")
                                .font(.system(size: 13, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(.white.opacity(0.10), in: Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text(step.title)
                                    .font(GravityFont.semiBold.fixedFont(size: 14))
                                Text(decisionLabel(decision))
                                    .font(GravityFont.regular.fixedFont(size: 12))
                                    .foregroundStyle(.white.opacity(0.58))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                session.send(.clearMissionDecision(step.id))
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.54))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(GravitySpacing.space16)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .padding(.horizontal, GravitySpacing.space12)
        }
    }

    private func selectedProduct(
        for step: MissionStepDefinition,
        recommendations: [ResolvedStoryProduct]
    ) -> ResolvedStoryProduct? {
        let selectedID = session.state.missionSelectedProductIDs[step.id]
        return recommendations.first { $0.id == selectedID } ?? recommendations.first
    }

    private func decisionLabel(_ decision: MissionDecision) -> String {
        guard let productID = decision.productID,
              let product = allCatalogProducts.first(where: { $0.id == productID }) else {
            return decision.disposition == .owned ? "Already covered" : decision.disposition.label
        }
        return "\(decision.disposition.label) · \(product.product.title)"
    }

    private func recommendations(for step: MissionStepDefinition) -> [ResolvedStoryProduct] {
        var seen = Set<String>()
        let source = step.id == "equipment"
            ? Array(relatedSkiProducts.prefix(3)) + products
            : allCatalogProducts.filter { item in
                !searchableTokens(for: item).isDisjoint(with: step.keywords)
            }
        return source.filter { seen.insert($0.id).inserted }.prefix(8).map { $0 }
    }

    private var relatedSkiProducts: [ResolvedStoryProduct] {
        guard let story = PersonalizedFeedCatalog.current.stories.first(where: {
            $0.id == "shelf-mikhail-6-premium-all-mountain-skis"
        }) else { return [] }
        return story.resolvedProducts(from: SampleMerchant.all)
    }

    private var allCatalogProducts: [ResolvedStoryProduct] {
        SampleMerchant.all.flatMap { merchant in
            merchant.products.map { ResolvedStoryProduct(merchant: merchant, product: $0) }
        }
    }

    private func searchableTokens(for item: ResolvedStoryProduct) -> Set<String> {
        Set(
            ([item.product.title, item.product.productType ?? ""] + item.product.tags)
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
        )
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
                price: formatPrice(item.product),
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
