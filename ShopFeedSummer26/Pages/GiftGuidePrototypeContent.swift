import Observation
import SwiftUI

/// PROTOTYPE — Session-only state shared by the gift content and its pinned
/// steering dock so every control visibly transforms one coherent page.
@Observable
final class GiftGuidePrototypeState {
    var showsTuning = false
    var showsVoiceMode = false
    var age = 10.0
    var ageIsConfirmed = false
    var setting = GiftSetting.both
    var settingIsConfirmed = false
    var budget = 150.0
    var budgetIsConfirmed = false
    var intent = GiftIntent.surprise
    var intentIsConfirmed = false
    var note = ""
    var appliedNote = ""
    var updateToken = 0
    var deckIndex = 0
    var remainingConfirmations: Int {
        [ageIsConfirmed, settingIsConfirmed, budgetIsConfirmed, intentIsConfirmed]
            .filter { !$0 }.count
    }

    func registerUpdate(_: String) {
        HapticFeedback.light.fire()
        updateToken += 1
    }
}

/// PROTOTYPE — A steerable topic that tests whether recipient controls can
/// make a gift guide feel alive. State is intentionally session-only.
struct GiftGuidePrototypeContent: View {
    let products: [ResolvedStoryProduct]
    @Bindable var state: GiftGuidePrototypeState

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var deckDragOffset: CGFloat = 0

    private var showsTuning: Bool {
        get { state.showsTuning }
        nonmutating set { state.showsTuning = newValue }
    }
    private var age: Double {
        get { state.age }
        nonmutating set { state.age = newValue }
    }
    private var ageIsConfirmed: Bool {
        get { state.ageIsConfirmed }
        nonmutating set { state.ageIsConfirmed = newValue }
    }
    private var setting: GiftSetting {
        get { state.setting }
        nonmutating set { state.setting = newValue }
    }
    private var settingIsConfirmed: Bool {
        get { state.settingIsConfirmed }
        nonmutating set { state.settingIsConfirmed = newValue }
    }
    private var budget: Double {
        get { state.budget }
        nonmutating set { state.budget = newValue }
    }
    private var intent: GiftIntent {
        get { state.intent }
        nonmutating set { state.intent = newValue }
    }
    private var intentIsConfirmed: Bool {
        get { state.intentIsConfirmed }
        nonmutating set { state.intentIsConfirmed = newValue }
    }
    private var note: String {
        get { state.note }
        nonmutating set { state.note = newValue }
    }
    private var appliedNote: String {
        get { state.appliedNote }
        nonmutating set { state.appliedNote = newValue }
    }
    private var updateToken: Int { state.updateToken }

    private var rankedProducts: [ResolvedStoryProduct] {
        products.sorted { score($0) > score($1) }
    }

    private var leadProducts: [ResolvedStoryProduct] {
        let anchorMerchantIDs = ["tin-can-kids", "pollen-robotics"]
        let anchors = anchorMerchantIDs.compactMap { merchantID in
            products.first { $0.merchant.id == merchantID }
        }
        let anchorIDs = Set(anchors.map(\.id))
        return Array((anchors + rankedProducts.filter { !anchorIDs.contains($0.id) }).prefix(3))
    }

    private var withinBudget: [ResolvedStoryProduct] {
        let matches = rankedProducts.filter { price(of: $0) <= budget }
        return matches.count >= 2 ? matches : rankedProducts
    }

    private var sharedActivityProducts: [ResolvedStoryProduct] {
        rankedProducts.sorted {
            activityScore($0) > activityScore($1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            recipientBrief
                .padding(.horizontal, GravitySpacing.space12)

            leadSection

            giftRoutes

            productDeck

            productRail(
                title: setting.sectionTitle,
                subtitle: setting.sectionSubtitle,
                products: rankedProducts
            )

            productRail(
                title: budgetTitle,
                subtitle: "Easy yeses that stay inside the brief",
                products: withinBudget
            )

            productRail(
                title: intent == .together ? "Things you can do together" : "A gift with a story",
                subtitle: intent == .together
                    ? "Projects and adventures that become shared time"
                    : "Distinctive finds from independent shops",
                products: sharedActivityProducts
            )

            conversationalRefinement
                .padding(.horizontal, GravitySpacing.space12)
        }
        .padding(.top, GravitySpacing.space8)
        .padding(.bottom, 140)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: updateToken)
        .sheet(isPresented: Binding(
            get: { showsTuning },
            set: { showsTuning = $0 }
        )) {
            GiftGuideTuningSheet(
                age: Binding(get: { age }, set: { age = $0 }),
                setting: Binding(get: { setting }, set: { setting = $0 }),
                budget: Binding(get: { budget }, set: { budget = $0 }),
                intent: Binding(get: { intent }, set: { intent = $0 }),
                note: Binding(get: { note }, set: { note = $0 }),
                apply: {
                    ageIsConfirmed = true
                    settingIsConfirmed = true
                    state.budgetIsConfirmed = true
                    intentIsConfirmed = true
                    applyTuning()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .environment(\.colorScheme, .light)
        }
    }

    private var recipientBrief: some View {
        HStack(spacing: GravitySpacing.space12) {
            VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                Text("For Leon")
                    .font(GravityFont.expressiveBold.fixedFont(size: 21))
                    .tracking(-0.5)
                Text(state.remainingConfirmations == 0
                     ? "Gift preferences confirmed"
                     : "\(state.remainingConfirmations) preferences to tune")
                    .font(GravityFont.medium.fixedFont(size: 12))
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer()
            Button {
                HapticFeedback.light.fire()
                showsTuning = true
            } label: {
                Text("Edit")
                    .font(GravityFont.semiBold.fixedFont(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, GravitySpacing.space12)
                    .frame(height: 34)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
    }

    private var leadSection: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            sectionHeading("Shop’s take", subtitle: "Start with connection, then leave room for wonder")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space10) {
                    ForEach(Array(leadProducts.enumerated()), id: \.element.id) { index, item in
                        leadCard(item, label: leadLabel(for: item, index: index))
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private func leadCard(_ item: ResolvedStoryProduct, label: String) -> some View {
        Button { open(item) } label: {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let rawVideoURL = item.product.videoUrl,
                       let videoURL = URL(string: rawVideoURL) {
                        LoopingVideoPlayer(
                            url: videoURL,
                            playbackGroupID: "gift-lead-\(item.id)"
                        )
                    } else {
                        ProductImageView(product: item.product, merchant: item.merchant)
                    }
                }
                .frame(width: 286, height: 342)
                .clipped()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.12), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                    Text(label)
                        .font(GravityFont.semiBold.fixedFont(size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(item.product.title)
                        .font(GravityFont.bold.fixedFont(size: 19))
                        .tracking(-0.35)
                        .lineLimit(2)
                    HStack {
                        Text(item.merchant.displayName)
                        Spacer()
                        Text(formatPrice(item.product.price))
                    }
                    .font(GravityFont.medium.fixedFont(size: 12))
                    .foregroundStyle(.white.opacity(0.76))
                }
                .foregroundStyle(.white)
                .padding(GravitySpacing.space16)
            }
            .frame(width: 286, height: 342)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var giftRoutes: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            sectionHeading("Ways into the gift", subtitle: "Start with the kind of moment you want to create")
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: GravitySpacing.space8), count: 2),
                spacing: GravitySpacing.space8
            ) {
                ForEach(routeProducts) { item in
                    routeCard(item)
                }
            }
            .padding(.horizontal, GravitySpacing.space12)
        }
    }

    private var routeProducts: [ResolvedStoryProduct] {
        let preferredMerchantIDs = ["tin-can-kids", "pollen-robotics", "nocs", "moma"]
        return preferredMerchantIDs.compactMap { merchantID in
            rankedProducts.first { $0.merchant.id == merchantID }
        }
    }

    private func routeCard(_ item: ResolvedStoryProduct) -> some View {
        Button { open(item) } label: {
            Color.clear
                .aspectRatio(0.92, contentMode: .fit)
                .overlay {
                    ProductImageView(product: item.product, merchant: item.merchant)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.68)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                        Text(routeTitle(for: item))
                            .font(GravityFont.bold.fixedFont(size: 16))
                            .lineLimit(2)
                        Text(item.merchant.displayName)
                            .font(GravityFont.medium.fixedFont(size: 11))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .foregroundStyle(.white)
                    .padding(GravitySpacing.space12)
                }
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func routeTitle(for item: ResolvedStoryProduct) -> String {
        switch item.merchant.id {
        case "tin-can-kids": "Keep Leon connected"
        case "pollen-robotics": "Build and code"
        case "nocs": "Explore outside"
        default: "Make something"
        }
    }

    private var productDeck: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionHeading(
                "Swipe through ideas",
                subtitle: "A quick stack of gifts picked for Leon"
            )

            ZStack {
                ForEach(Array((0..<min(3, rankedProducts.count)).reversed()), id: \.self) { depth in
                    let itemIndex = (state.deckIndex + depth) % rankedProducts.count
                    deckCard(rankedProducts[itemIndex], depth: depth)
                }
            }
            .frame(height: 394)
            .padding(.horizontal, GravitySpacing.space20)
        }
    }

    private func deckCard(_ item: ResolvedStoryProduct, depth: Int) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 370)
            .overlay {
                ProductImageView(product: item.product, merchant: item.merchant)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.08), .black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: GravitySpacing.space6) {
                    Text(item.product.title)
                        .font(GravityFont.bold.fixedFont(size: 20))
                        .tracking(-0.25)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: GravitySpacing.space6) {
                        Text(item.merchant.displayName)
                        Text("·")
                            .foregroundStyle(.white.opacity(0.42))
                        Text(formatPrice(item.product.price))
                    }
                    .font(GravityFont.medium.fixedFont(size: 12))
                    .foregroundStyle(.white.opacity(0.72))
                }
                .foregroundStyle(.white)
                .padding(GravitySpacing.space16)
            }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .scaleEffect(1 - CGFloat(depth) * 0.025, anchor: .bottom)
            .offset(
                x: depth == 0 ? deckDragOffset : (depth == 1 ? -10 : 10),
                y: CGFloat(depth) * -14
            )
            .rotationEffect(.degrees(
                depth == 0 ? Double(deckDragOffset / 28) : (depth == 1 ? -2 : 2)
            ))
            .shadow(color: .black.opacity(depth == 0 ? 0.22 : 0.10), radius: 18, y: 10)
            .zIndex(Double(3 - depth))
            .allowsHitTesting(depth == 0)
            .contentShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .onTapGesture { open(item) }
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        deckDragOffset = value.translation.width
                    }
                    .onEnded { value in
                        finishDeckSwipe(value.translation.width)
                    }
            )
    }

    private func finishDeckSwipe(_ translation: CGFloat) {
        guard abs(translation) > 56 else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                deckDragOffset = 0
            }
            return
        }

        let direction = translation < 0 ? 1 : -1
        withAnimation(.easeOut(duration: 0.18)) {
            deckDragOffset = translation < 0 ? -480 : 480
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                state.deckIndex = (state.deckIndex + direction + rankedProducts.count) % rankedProducts.count
                deckDragOffset = 0
            }
            HapticFeedback.light.fire()
        }
    }

    private func productRail(
        title: String,
        subtitle: String,
        products: [ResolvedStoryProduct]
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            sectionHeading(title, subtitle: subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: GravitySpacing.space8) {
                    ForEach(products) { item in
                        Button { open(item) } label: {
                            ProductCard(
                                image: nil,
                                imageURL: item.product.imageURL,
                                merchantName: item.merchant.displayName,
                                productName: item.product.title,
                                price: formatPrice(item.product.price),
                                showFavoriteButton: true,
                                favoriteIconHasContrastShadow: true
                            )
                            .frame(width: 132)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
            }
        }
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space2) {
            Text(title)
                .font(GravityFont.expressiveBold.fixedFont(size: 21))
                .tracking(-0.5)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(GravityFont.regular.fixedFont(size: 13))
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(.horizontal, GravitySpacing.space12)
    }

    private var conversationalRefinement: some View {
        Button {
            HapticFeedback.light.fire()
            showsTuning = true
        } label: {
            HStack(spacing: GravitySpacing.space12) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                    Text("Tell Shop more about Leon")
                        .font(GravityFont.bold.fixedFont(size: 16))
                    Text(appliedNote.isEmpty ? "What is Leon into lately?" : "“\(appliedNote)”")
                        .font(GravityFont.regular.fixedFont(size: 13))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(GravitySpacing.space16)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: GravityRadius.r24, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func leadLabel(for item: ResolvedStoryProduct, index: Int) -> String {
        switch item.merchant.id {
        case "tin-can-kids": "Our starting point"
        case "pollen-robotics": "The delight pick"
        default: index == 2 ? "One to do together" : "A strong match"
        }
    }

    private var leadSubtitle: String {
        "For an \(Int(age))-year-old who is \(setting.description.lowercased())"
    }

    private var budgetTitle: String {
        "Great gifts under $\(Int(budget))"
    }

    private func score(_ item: ResolvedStoryProduct) -> Int {
        let text = "\(item.product.title) \(item.merchant.displayName) \(item.product.tags.joined(separator: " "))".lowercased()
        var value = price(of: item) <= budget ? 24 : -12
        if setting == .outdoors && ["nocs", "outdoor", "binocular", "field"].contains(where: text.contains) { value += 70 }
        if setting == .indoors && ["design", "comic", "craft", "watch", "puzzle"].contains(where: text.contains) { value += 70 }
        if setting == .both && ["nocs", "craft", "comic", "watch", "robot", "screen-free"].contains(where: text.contains) { value += 34 }
        if age <= 8 && ["puzzle", "craft"].contains(where: text.contains) { value += 45 }
        if age >= 12 && ["watch", "comic", "design"].contains(where: text.contains) { value += 42 }
        switch intent {
        case .fun where ["puzzle", "neon", "comic", "robot"].contains(where: text.contains): value += 34
        case .useful where ["watch", "binocular", "clock", "communication", "screen-free"].contains(where: text.contains): value += 34
        case .together where ["field", "craft", "puzzle", "coding", "robot"].contains(where: text.contains): value += 34
        case .surprise where ["ring", "neon", "comic", "robot"].contains(where: text.contains): value += 34
        default: break
        }
        return value
    }

    private func activityScore(_ item: ResolvedStoryProduct) -> Int {
        let text = item.product.title.lowercased()
        return ["field", "binocular", "craft", "puzzle", "comic"]
            .reduce(0) { $0 + (text.contains($1) ? 20 : 0) }
    }

    private func price(of item: ResolvedStoryProduct) -> Double {
        Double(item.product.price.filter { $0.isNumber || $0 == "." }) ?? .greatestFiniteMagnitude
    }

    private func open(_ item: ResolvedStoryProduct) {
        HapticFeedback.light.fire()
        coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
    }

    private func registerUpdate(_ message: String) {
        state.registerUpdate(message)
    }

    private func applyTuning() {
        appliedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        showsTuning = false
        registerUpdate("Rebuilt Leon’s guide from your brief")
    }
}

struct GiftGuideSteeringDock: View {
    @Bindable var state: GiftGuidePrototypeState
    let surfaceColor: Color

    var body: some View {
        ZStack {
            filterBar
            HStack {
                Spacer()
                assistantMenu
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, minHeight: FeedNavigationStyle.controlSize, maxHeight: FeedNavigationStyle.controlSize)
        .sheet(isPresented: $state.showsVoiceMode) {
            GiftGuideVoiceMode()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 0) {
            Menu {
                ForEach([7, 10, 13, 16], id: \.self) { age in
                    Button("Age \(age)") {
                        state.age = Double(age)
                        state.ageIsConfirmed = true
                        state.registerUpdate("Updated for Leon at age \(age)")
                    }
                }
            } label: {
                dockPill(
                    "Age \(Int(state.age))",
                    width: 54,
                    confirmed: state.ageIsConfirmed
                )
            }
            .accessibilityLabel("Leon’s age")

            Menu {
                ForEach(GiftSetting.allCases) { setting in
                    Button(setting.label) {
                        state.setting = setting
                        state.settingIsConfirmed = true
                        state.registerUpdate("Shifted the guide toward \(setting.label.lowercased())")
                    }
                }
            } label: {
                dockPill(
                    settingDockLabel,
                    width: 64,
                    confirmed: state.settingIsConfirmed
                )
            }
            .accessibilityLabel("Leon’s setting preference")

            Menu {
                ForEach([50, 100, 150, 400], id: \.self) { budget in
                    Button("Under $\(budget)") {
                        state.budget = Double(budget)
                        state.budgetIsConfirmed = true
                        state.registerUpdate("Rebuilt the shortlist under $\(budget)")
                    }
                }
            } label: {
                dockPill(
                    "$\(Int(state.budget))",
                    width: 58,
                    confirmed: state.budgetIsConfirmed
                )
            }
            .accessibilityLabel("Gift budget")

            Menu {
                ForEach(GiftIntent.allCases) { intent in
                    Button(intent.label) {
                        state.intent = intent
                        state.intentIsConfirmed = true
                        state.registerUpdate("Prioritizing \(intent.label.lowercased()) gifts")
                    }
                }
            } label: {
                dockPill(
                    intentDockLabel,
                    width: 74,
                    confirmed: state.intentIsConfirmed
                )
            }
            .accessibilityLabel("Gift intent")
        }
        .padding(3)
        .frame(width: 262, height: FeedNavigationStyle.controlSize)
        .background {
            Capsule()
                .fill(surfaceColor)
                .overlay { Capsule().fill(.black.opacity(0.26)) }
        }
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
        }
    }

    private var assistantMenu: some View {
        Menu {
            Button {
                HapticFeedback.light.fire()
                state.showsVoiceMode = true
            } label: {
                Label("Voice mode", systemImage: "waveform")
            }
            Button {
                HapticFeedback.light.fire()
                state.showsTuning = true
            } label: {
                Label("Chat with Shop", systemImage: "message")
            }
        } label: {
            Image(systemName: "waveform")
                .font(FeedNavigationStyle.iconFont)
                .foregroundStyle(.white)
                .frame(
                    width: FeedNavigationStyle.controlSize,
                    height: FeedNavigationStyle.controlSize
                )
                .background {
                    Circle()
                        .fill(surfaceColor)
                        .overlay { Circle().fill(.black.opacity(0.26)) }
                }
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                }
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
        .accessibilityLabel("Voice or chat with Shop")
    }

    private var settingDockLabel: String {
        switch state.setting {
        case .indoors: "Inside"
        case .both: "Both"
        case .outdoors: "Outside"
        }
    }

    private var intentDockLabel: String {
        switch state.intent {
        case .surprise: "Surprise"
        case .fun: "Fun"
        case .useful: "Useful"
        case .together: "Together"
        }
    }

    private func dockPill(_ title: String, width: CGFloat, confirmed: Bool) -> some View {
        Text(title)
            .font(GravityFont.semiBold.fixedFont(size: 12))
            .foregroundStyle(.white.opacity(confirmed ? 1 : 0.72))
            .frame(width: width, height: 34)
            .background(confirmed ? .white.opacity(0.12) : .clear, in: Capsule())
    }
}

private struct GiftGuideVoiceMode: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: GravitySpacing.space16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#7455A2").opacity(0.14))
                    .frame(width: 76, height: 76)
                Image(systemName: "waveform")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(hex: "#62458E"))
            }

            VStack(spacing: GravitySpacing.space4) {
                Text("Tell Shop about Leon")
                    .font(GravityFont.expressiveBold.fixedFont(size: 22))
                Text("Try “more things he can build himself”")
                    .font(GravityFont.regular.fixedFont(size: 14))
                    .foregroundStyle(.secondary)
            }

            Button("Done") { dismiss() }
                .font(GravityFont.semiBold.fixedFont(size: 15))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(hex: "#62458E"), in: Capsule())
        }
        .padding(GravitySpacing.space20)
        .environment(\.colorScheme, .light)
    }
}

enum GiftSetting: String, CaseIterable, Identifiable {
    case indoors
    case both
    case outdoors

    var id: Self { self }
    var label: String {
        switch self {
        case .indoors: "Indoors"
        case .both: "A bit of both"
        case .outdoors: "Outdoors"
        }
    }
    var description: String {
        switch self {
        case .indoors: "mostly indoors"
        case .both: "into a bit of everything"
        case .outdoors: "mostly outdoors"
        }
    }
    var sectionTitle: String {
        switch self {
        case .indoors: "For Leon’s world indoors"
        case .both: "For wherever the day goes"
        case .outdoors: "For Leon’s next adventure"
        }
    }
    var sectionSubtitle: String {
        switch self {
        case .indoors: "Creative, curious, and designed for time at home"
        case .both: "Things that work at home and out in the world"
        case .outdoors: "Gear for looking closer and going farther"
        }
    }
}

enum GiftIntent: String, CaseIterable, Identifiable {
    case fun
    case useful
    case together
    case surprise

    var id: Self { self }
    var label: String {
        switch self {
        case .fun: "Pure fun"
        case .useful: "Something useful"
        case .together: "Do it together"
        case .surprise: "Surprise me"
        }
    }
}

private struct GiftGuideTuningSheet: View {
    @Binding var age: Double
    @Binding var setting: GiftSetting
    @Binding var budget: Double
    @Binding var intent: GiftIntent
    @Binding var note: String
    let apply: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    dial(title: "How old is Leon?", value: "\(Int(age))") {
                        Slider(value: $age, in: 5...17, step: 1)
                            .tint(Color(hex: "#7455A2"))
                    }

                    VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                        Text("Where does Leon come alive?")
                            .font(GravityFont.bold.fixedFont(size: 17))
                        Picker("Setting", selection: $setting) {
                            ForEach(GiftSetting.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    dial(title: "Working budget", value: "Under $\(Int(budget))") {
                        Slider(value: $budget, in: 25...300, step: 25)
                            .tint(Color(hex: "#7455A2"))
                    }

                    VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                        Text("What should it feel like?")
                            .font(GravityFont.bold.fixedFont(size: 17))
                        Picker("Intent", selection: $intent) {
                            ForEach(GiftIntent.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(Color(hex: "#7455A2"))
                    }

                    VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                        Text("What is Leon into lately?")
                            .font(GravityFont.bold.fixedFont(size: 17))
                        TextField("Dinosaurs, making things, camping…", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(GravitySpacing.space12)
                            .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: GravityRadius.r16))
                    }

                    Button(action: apply) {
                        Text("Transform this guide")
                            .font(GravityFont.bold.fixedFont(size: 15))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "#5E3C8B"), in: Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .padding(GravitySpacing.space20)
            }
            .navigationTitle("Tune Leon’s gift guide")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func dial<Content: View>(
        title: String,
        value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space10) {
            HStack {
                Text(title)
                    .font(GravityFont.bold.fixedFont(size: 17))
                Spacer()
                Text(value)
                    .font(GravityFont.semiBold.fixedFont(size: 14))
                    .foregroundStyle(Color(hex: "#5E3C8B"))
            }
            content()
        }
    }
}
