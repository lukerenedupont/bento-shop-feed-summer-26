import Observation
import SwiftUI

struct GiftGuidePersonalizationContext {
    let age: Double?
    let personaID: String?
    let personaTitle: String?
    let interests: [String]
    let priorities: [String]
    let discoveryStyleID: String?
}

/// PROTOTYPE — Session-only state shared by the gift content and its pinned
/// steering dock so every control visibly transforms one coherent page.
@Observable
final class GiftGuidePrototypeState {
    var recipientName = "Leon"
    var occasion = "Just because"
    var interests: [GiftGuideInterest] = [.outdoors, .games, .making]
    var showsTuning = false
    var showsVoiceMode = false
    var age = 10.0
    var ageIsConfirmed = false
    var setting = GiftSetting.outdoors
    var settingIsConfirmed = true
    var budget = 150.0
    var budgetIsConfirmed = false
    var intent = GiftIntent.surprise
    var intentIsConfirmed = false
    var note = ""
    var appliedNote = ""
    var profilePersonaID: String?
    var profilePersonaTitle: String?
    var profileKeywords: [String] = []
    var profilePriorities: [String] = []
    var profileDiscoveryStyleID: String?
    var updateToken = 0
    var deckIndex = 0

    init(
        brief: GiftGuideBrief? = nil,
        personalization: GiftGuidePersonalizationContext? = nil,
        adultRecipient: Bool = false
    ) {
        if let brief {
            recipientName = brief.recipientName
            occasion = brief.occasion
            interests = brief.interests
            setting = brief.interests.contains(.outdoors) ? .outdoors : .both
            intent = brief.interests.contains(.surprises) ? .surprise : .fun
            settingIsConfirmed = true
            intentIsConfirmed = true
            appliedNote = "\(brief.occasion) · \(brief.interests.prefix(3).map(\.title).joined(separator: ", "))"
        }

        if adultRecipient {
            recipientName = "Nari"
            interests = []
            setting = .indoors
            settingIsConfirmed = false
        }
        guard let personalization else { return }

        if let age = personalization.age {
            self.age = age
            ageIsConfirmed = true
        }
        profilePersonaID = personalization.personaID
        profilePersonaTitle = personalization.personaTitle
        profileKeywords = personalization.interests
        profilePriorities = personalization.priorities
        profileDiscoveryStyleID = personalization.discoveryStyleID

        if personalization.personaID == "individualist" {
            setting = .both
        } else if personalization.personaID != nil {
            setting = .indoors
        }
        if personalization.priorities.contains("Price") {
            budget = 100
            budgetIsConfirmed = true
        }
        if personalization.discoveryStyleID == "familiar" {
            intent = .useful
        } else if personalization.discoveryStyleID == "surprising" {
            intent = .surprise
        }
    }

    func registerUpdate(_: String) {
        HapticFeedback.light.fire()
        updateToken += 1
    }
}

/// Copy and controls shared by every recipient-specific version of the same
/// gift-guide destination. Leon keeps the child age control; adult recipients
/// use the rest of the tuning model without pretending age is useful context.
struct GiftGuideRecipient {
    let name: String

    static let leon = GiftGuideRecipient(name: "Leon")

    var isNari: Bool { name.caseInsensitiveCompare("Nari") == .orderedSame }
    var usesAge: Bool { !isNari }
    var notePlaceholder: String {
        usesAge
            ? "Dinosaurs, making things, camping…"
            : "Archive fashion, jewelry, interiors…"
    }
    var voiceExample: String {
        usesAge
            ? "more things he can build himself"
            : "more archive fashion and design objects"
    }
    var noteQuestion: String {
        usesAge ? "What is \(name) into lately?" : "Anything specific for this gift?"
    }
    var occasionPlaceholder: String {
        usesAge
            ? notePlaceholder
            : "An anniversary, an exact piece, a favorite color…"
    }
}

/// PROTOTYPE — A steerable topic that tests whether recipient controls can
/// make a gift guide feel alive. State is intentionally session-only.
struct GiftGuidePrototypeContent: View {
    let products: [ResolvedStoryProduct]
    @Bindable var state: GiftGuidePrototypeState
    let recipient: GiftGuideRecipient
    private let initialProducts: [ResolvedStoryProduct]

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var deckDragOffset: CGFloat = 0
    @State private var deckIsTransitioning = false
    @State private var rankedProductCache: [ResolvedStoryProduct] = []

    init(
        products: [ResolvedStoryProduct],
        state: GiftGuidePrototypeState,
        recipient: GiftGuideRecipient
    ) {
        self.products = products
        self.state = state
        self.recipient = recipient

        var seenImageURLs = Set<String>()
        initialProducts = products.filter { item in
            let imageURL = item.product.imageURL ?? ""
            let imageKey = imageURL
                .split(separator: "?", maxSplits: 1)
                .first
                .map(String.init) ?? imageURL
            return imageKey.isEmpty || seenImageURLs.insert(imageKey).inserted
        }
    }

    private enum NariProductFamily: CaseIterable {
        case tops
        case bottoms
        case jewelry
        case footwear
        case objects
        case other
    }

    private struct DeckEntry: Identifiable {
        let depth: Int
        let product: ResolvedStoryProduct

        var id: String { product.id }
    }

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
        rankedProductCache.isEmpty ? initialProducts : rankedProductCache
    }

    private func makeRankedProducts() -> [ResolvedStoryProduct] {
        let ranked = initialProducts.sorted { score($0) > score($1) }
        return recipient.isNari ? diversifiedNariProducts(ranked) : ranked
    }

    private var leadProducts: [ResolvedStoryProduct] {
        if recipient.isNari {
            let candidates = Array(nariFashionProducts.prefix(2))
                + Array(nariJewelryProducts.prefix(1))
            var seen = Set<String>()
            return Array(candidates.filter { seen.insert($0.id).inserted }.prefix(3))
        }
        if !recipient.usesAge {
            return Array(rankedProducts.prefix(3))
        }
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

    private var settingSectionTitle: String {
        switch setting {
        case .indoors: "For \(state.recipientName)’s world indoors"
        case .both: "For wherever the day goes"
        case .outdoors: "For \(state.recipientName)’s next adventure"
        }
    }

    private var sharedActivityProducts: [ResolvedStoryProduct] {
        rankedProducts.sorted {
            activityScore($0) > activityScore($1)
        }
    }

    private var nariBKRProducts: [ResolvedStoryProduct] {
        rankedProducts.filter { $0.merchant.id == "bkr" }
    }

    private var nariArchiveProducts: [ResolvedStoryProduct] {
        rankedProducts.filter { $0.merchant.id != "bkr" }
    }

    private var nariJewelryProducts: [ResolvedStoryProduct] {
        let jewelryTerms = ["jewel", "ring", "necklace", "bracelet", "earring", "brooch", "silver", "gold"]
        let matches = nariArchiveProducts.filter { item in
            let text = searchableText(for: item)
            return jewelryTerms.contains(where: text.contains)
                || item.merchant.id == "shelf-shop-mano-vintage-jewellery-2b7e972"
        }
        return matches.isEmpty ? nariArchiveProducts : matches
    }

    private var nariFashionProducts: [ResolvedStoryProduct] {
        let jewelryIDs = Set(nariJewelryProducts.map(\.id))
        let fashion = nariArchiveProducts.filter { !jewelryIDs.contains($0.id) }
        return fashion.isEmpty ? nariArchiveProducts : fashion
    }

    private var deckProducts: [ResolvedStoryProduct] {
        guard recipient.isNari else { return rankedProducts }
        let featuredIDs = Set((leadProducts + routeProducts).map(\.id))
        return rankedProducts.filter { !featuredIDs.contains($0.id) }
            + rankedProducts.filter { featuredIDs.contains($0.id) }
    }

    private var deckEntries: [DeckEntry] {
        guard !deckProducts.isEmpty else { return [] }
        return (0..<min(3, deckProducts.count)).map { depth in
            let itemIndex = (state.deckIndex + depth) % deckProducts.count
            return DeckEntry(depth: depth, product: deckProducts[itemIndex])
        }
    }

    private var nariFashionRailProducts: [ResolvedStoryProduct] {
        let featuredIDs = Set((leadProducts + routeProducts).map(\.id))
        return nariFashionProducts.filter { !featuredIDs.contains($0.id) }
            + nariFashionProducts.filter { featuredIDs.contains($0.id) }
    }

    private var nariDiscoveryProducts: [ResolvedStoryProduct] {
        Array(rankedProducts.prefix(60))
    }

    private func diversifiedNariProducts(
        _ ranked: [ResolvedStoryProduct]
    ) -> [ResolvedStoryProduct] {
        var buckets = Dictionary(
            grouping: ranked,
            by: nariProductFamily(for:)
        )
        var diversified: [ResolvedStoryProduct] = []
        var lastMerchantID: String?

        while diversified.count < ranked.count {
            var addedProduct = false
            for family in NariProductFamily.allCases {
                guard var bucket = buckets[family], !bucket.isEmpty else { continue }
                let nextIndex = bucket.firstIndex {
                    $0.merchant.id != lastMerchantID
                } ?? bucket.startIndex
                let next = bucket.remove(at: nextIndex)
                buckets[family] = bucket
                diversified.append(next)
                lastMerchantID = next.merchant.id
                addedProduct = true
            }
            if !addedProduct { break }
        }
        return diversified
    }

    private func nariProductFamily(
        for item: ResolvedStoryProduct
    ) -> NariProductFamily {
        if item.merchant.id == "bkr" { return .objects }
        let text = searchableText(for: item)
        if ["jewel", "ring", "necklace", "bracelet", "earring", "brooch", "silver", "gold"]
            .contains(where: text.contains) {
            return .jewelry
        }
        if ["pants", "trouser", "bottom", "skirt", "shorts"]
            .contains(where: text.contains) {
            return .bottoms
        }
        if ["sneaker", "shoe", "boot", "loafer", "sandal"]
            .contains(where: text.contains) {
            return .footwear
        }
        if ["shirt", "t-shirt", "tee", "tank", "top", "blouse", "sweater", "jacket", "coat"]
            .contains(where: text.contains) {
            return .tops
        }
        return .other
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 30) {
            leadSection

            giftRoutes

            if recipient.isNari {
                productRail(
                    title: "Archive pieces",
                    subtitle: "Westwood and independent designers, picked for Nari",
                    products: nariFashionRailProducts,
                    usesImageShadow: false
                )

                productDeck

                productRail(
                    title: "Vintage jewelry",
                    subtitle: "Sculptural pieces with character",
                    products: nariJewelryProducts,
                    usesImageShadow: false
                )

                productRail(
                    title: "Everyday design",
                    subtitle: "BKR bottles in colors she might love",
                    products: nariBKRProducts,
                    usesImageShadow: false
                )

                nariDiscoveryGrid
            } else {
                productDeck

                productRail(
                    title: settingSectionTitle,
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
            }

            conversationalRefinement
                .padding(.horizontal, GravitySpacing.space12)
        }
        .padding(.top, GravitySpacing.space8)
        .padding(.bottom, 140)
        .onAppear {
            if rankedProductCache.isEmpty {
                Task { @MainActor in
                    // Let the hero and shared-view transition commit first.
                    // Ranking is below the fold and only needs one pass.
                    await Task.yield()
                    guard rankedProductCache.isEmpty else { return }
                    rankedProductCache = makeRankedProducts()
                }
            }
        }
        .onChange(of: updateToken) {
            rankedProductCache = makeRankedProducts()
        }
        .sheet(isPresented: Binding(
            get: { showsTuning },
            set: { showsTuning = $0 }
        )) {
            GiftGuideTuningSheet(
                recipientName: state.recipientName,
                age: Binding(get: { age }, set: { age = $0 }),
                setting: Binding(get: { setting }, set: { setting = $0 }),
                budget: Binding(get: { budget }, set: { budget = $0 }),
                intent: Binding(get: { intent }, set: { intent = $0 }),
                note: Binding(get: { note }, set: { note = $0 }),
                recipient: recipient,
                apply: {
                    if recipient.usesAge { ageIsConfirmed = true }
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

    private var leadSection: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            sectionHeading(recipient.isNari ? "Top picks for Nari" : "Shop’s take", subtitle: shopTakeSubtitle)
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
            sectionHeading(
                recipient.isNari ? "Shop by instinct" : "Ways into the gift",
                subtitle: recipient.isNari
                    ? "Start with a direction"
                    : "Start with the kind of moment you want to create"
            )
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
        if recipient.isNari {
            let leadIDs = Set(leadProducts.map(\.id))
            let remainingFashion = nariFashionProducts.filter { !leadIDs.contains($0.id) }
            let remainingJewelry = nariJewelryProducts.filter { !leadIDs.contains($0.id) }
            let candidates = [
                remainingFashion.first,
                remainingFashion.dropFirst().first,
                remainingJewelry.first,
                nariBKRProducts.first,
            ].compactMap { $0 }
            var seen = Set<String>()
            return Array(candidates.filter { seen.insert($0.id).inserted }.prefix(4))
        }
        if !recipient.usesAge {
            return Array(rankedProducts.prefix(4))
        }
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
        if recipient.isNari {
            let text = searchableText(for: item)
            if item.merchant.id == "bkr" { return "Color for every day" }
            if item.merchant.id == "shelf-shop-mano-vintage-jewellery-2b7e972"
                || ["jewel", "ring", "necklace", "bracelet", "earring", "brooch"]
                    .contains(where: text.contains) {
                return "Sculptural jewelry"
            }
            if item.merchant.id == "shelf-shop-good-s-vintage-0aae91a"
                || item.merchant.id == "shelf-shop-the-list-af09863" {
                return "One-of-a-kind finds"
            }
            return "Archive fashion"
        }
        return switch item.merchant.id {
        case "tin-can-kids": "Keep \(state.recipientName) connected"
        case "pollen-robotics": "Build and code"
        case "nocs": "Explore outside"
        default: "Make something"
        }
    }

    private var productDeck: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionHeading(
                recipient.isNari ? "Tune these picks" : "Swipe through ideas",
                subtitle: recipient.isNari
                    ? "Swipe left to pass · right to see more like it"
                    : "A quick stack of gifts picked for \(state.recipientName)"
            )

            ZStack {
                ForEach(Array(deckEntries.reversed())) { entry in
                    deckCard(entry.product, depth: entry.depth)
                }
            }
            .frame(height: 394)
            .padding(.horizontal, GravitySpacing.space20)

            HStack(spacing: GravitySpacing.space8) {
                deckFeedbackButton(
                    title: "Not for her",
                    systemImage: "xmark",
                    isPositive: false
                )
                deckFeedbackButton(
                    title: "More like this",
                    systemImage: "checkmark",
                    isPositive: true
                )
            }
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
            .overlay(alignment: .topLeading) {
                if depth == 0 {
                    Label("MORE LIKE THIS", systemImage: "checkmark")
                    .font(GravityFont.semiBold.fixedFont(size: 12))
                    .tracking(0.3)
                    .foregroundStyle(.white)
                    .padding(.horizontal, GravitySpacing.space12)
                    .frame(height: 36)
                    .background(.black.opacity(0.72), in: Capsule())
                    .padding(GravitySpacing.space16)
                    .opacity(deckFeedbackProgress(isPositive: true))
                }
            }
            .overlay(alignment: .topTrailing) {
                if depth == 0 {
                    Label("NOT FOR HER", systemImage: "xmark")
                        .font(GravityFont.semiBold.fixedFont(size: 12))
                        .tracking(0.3)
                        .foregroundStyle(.white)
                        .padding(.horizontal, GravitySpacing.space12)
                        .frame(height: 36)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(GravitySpacing.space16)
                        .opacity(deckFeedbackProgress(isPositive: false))
                }
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
                x: depth == 0 ? deckDragOffset : 0,
                y: CGFloat(depth) * -14
            )
            .rotationEffect(.degrees(
                depth == 0 ? Double(deckDragOffset / 28) : 0
            ))
            .shadow(color: .black.opacity(depth == 0 ? 0.22 : 0.10), radius: 18, y: 10)
            .zIndex(Double(3 - depth))
            .allowsHitTesting(depth == 0 && !deckIsTransitioning)
            .contentShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .onTapGesture { open(item) }
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard !deckIsTransitioning else { return }
                        guard abs(value.translation.width) > abs(value.translation.height) else {
                            return
                        }
                        deckDragOffset = value.translation.width
                    }
                    .onEnded { value in
                        guard !deckIsTransitioning else { return }
                        guard abs(value.translation.width) > abs(value.translation.height) else {
                            deckDragOffset = 0
                            return
                        }
                        finishDeckSwipe(
                            value.translation.width,
                            projectedTranslation: value.predictedEndTranslation.width
                        )
                    }
            )
    }

    private func finishDeckSwipe(
        _ translation: CGFloat,
        projectedTranslation: CGFloat
    ) {
        guard !deckIsTransitioning else { return }
        let completesSwipe = abs(translation) > 56 || abs(projectedTranslation) > 96
        guard completesSwipe else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                deckDragOffset = 0
            }
            return
        }

        let resolvedTranslation = abs(projectedTranslation) > abs(translation)
            ? projectedTranslation
            : translation
        sendDeckFeedback(isPositive: resolvedTranslation > 0)
    }

    private func sendDeckFeedback(isPositive: Bool) {
        guard !deckIsTransitioning, !deckProducts.isEmpty else { return }
        deckIsTransitioning = true
        withAnimation(.easeOut(duration: 0.18)) {
            deckDragOffset = isPositive ? 480 : -480
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.16)) {
                state.deckIndex = (state.deckIndex + 1) % deckProducts.count
                deckDragOffset = 0
            }
            HapticFeedback.selection.fire()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                deckIsTransitioning = false
            }
        }
    }

    private func deckFeedbackButton(
        title: String,
        systemImage: String,
        isPositive: Bool
    ) -> some View {
        let directionProgress = deckFeedbackProgress(isPositive: isPositive)

        return Button {
            sendDeckFeedback(isPositive: isPositive)
        } label: {
            Label(title, systemImage: systemImage)
                .font(GravityFont.semiBold.fixedFont(size: 13))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    .white.opacity(0.10 + (0.20 * directionProgress)),
                    in: Capsule()
                )
                .overlay {
                    Capsule().strokeBorder(
                        .white.opacity(0.18 + (0.38 * directionProgress)),
                        lineWidth: 0.5 + (0.5 * directionProgress)
                    )
                }
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.97))
        .disabled(deckIsTransitioning)
    }

    private func deckFeedbackProgress(isPositive: Bool) -> CGFloat {
        let directionalOffset = isPositive ? deckDragOffset : -deckDragOffset
        let deadZone: CGFloat = 12
        guard directionalOffset > deadZone else { return 0 }
        return min((directionalOffset - deadZone) / 60, 1)
    }

    private func productRail(
        title: String,
        subtitle: String,
        products: [ResolvedStoryProduct],
        usesImageShadow: Bool = true
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
                                favoriteIconHasContrastShadow: true,
                                usesImageShadow: usesImageShadow
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

    private var nariDiscoveryGrid: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionHeading(
                "More for Nari",
                subtitle: "Archive fashion, accessories, and useful objects"
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: GravitySpacing.space8, alignment: .top),
                    GridItem(.flexible(), spacing: GravitySpacing.space8, alignment: .top),
                ],
                alignment: .leading,
                spacing: GravitySpacing.space24
            ) {
                ForEach(nariDiscoveryProducts) { item in
                    Button { open(item) } label: {
                        ProductCard(
                            image: nil,
                            imageURL: item.product.imageURL,
                            merchantName: item.merchant.displayName,
                            productName: item.product.title,
                            price: formatPrice(item.product.price),
                            showFavoriteButton: true,
                            favoriteIconHasContrastShadow: true,
                            usesImageShadow: false
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, GravitySpacing.space12)
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
                    Text(recipient.usesAge ? "Tell Shop more about \(state.recipientName)" : "Fine-tune these picks")
                        .font(GravityFont.bold.fixedFont(size: 16))
                    Text(recipient.usesAge
                        ? (appliedNote.isEmpty ? "What is \(state.recipientName) into lately?" : "“\(appliedNote)”")
                        : refinementSubtitle
                    )
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
        if recipient.isNari {
            switch index {
            case 0: return "Archive standout"
            case 1: return "Independent designer"
            default: return "Vintage jewelry"
            }
        }
        return switch item.merchant.id {
        case "tin-can-kids": "Our starting point"
        case "pollen-robotics": "The delight pick"
        default: index == 2 ? "One to do together" : "A strong match"
        }
    }

    private var leadSubtitle: String {
        if recipient.usesAge {
            return "For an \(Int(age))-year-old who is \(setting.description.lowercased())"
        }
        if let profilePersonaTitle = state.profilePersonaTitle {
            return "For \(recipient.name) · \(profilePersonaTitle)"
        }
        return "For \(recipient.name), who is \(setting.description.lowercased())"
    }

    private var shopTakeSubtitle: String {
        if recipient.isNari, state.profilePersonaTitle == nil {
            return "Archive pieces and sculptural details, picked for her"
        }
        guard !recipient.usesAge,
              let persona = state.profilePersonaTitle else {
            return "Start with connection, then leave room for wonder"
        }
        if let interest = state.profileKeywords.first {
            let personaLabel = persona.replacingOccurrences(of: "The ", with: "")
            return "Guided by her \(personaLabel.lowercased()) style and \(interest)"
        }
        return "Shaped by what you’ve told us about \(recipient.name)"
    }

    private var refinementSubtitle: String {
        if recipient.usesAge {
            return appliedNote.isEmpty ? "What is \(recipient.name) into lately?" : "“\(appliedNote)”"
        }
        return "Adjust the budget and direction"
    }

    private var budgetTitle: String {
        "Great gifts under $\(Int(budget))"
    }

    private func score(_ item: ResolvedStoryProduct) -> Int {
        let text = "\(item.product.title) \(item.merchant.displayName) \(item.product.tags.joined(separator: " "))".lowercased()
        var value = price(of: item) <= budget ? 24 : -12
        if recipient.isNari {
            if item.merchant.id == "bkr" {
                value -= 56
            } else {
                value += 42
            }
            if ["rick owens", "issey miyake", "comme des garçons", "comme des garcons", "ann demeulemeester", "diesel"]
                .contains(where: text.contains) {
                value += 64
            }
            if ["jewel", "ring", "sterling", "sculptural"]
                .contains(where: text.contains) {
                value += 34
            }
        }
        if setting == .outdoors && ["nocs", "outdoor", "binocular", "field"].contains(where: text.contains) { value += 70 }
        if setting == .indoors && ["design", "comic", "craft", "watch", "puzzle"].contains(where: text.contains) { value += 70 }
        if setting == .both && ["nocs", "craft", "comic", "watch", "robot", "screen-free"].contains(where: text.contains) { value += 34 }
        if recipient.usesAge,
           age <= 8,
           ["puzzle", "craft"].contains(where: text.contains) { value += 45 }
        if recipient.usesAge,
           age >= 12,
           ["watch", "comic", "design"].contains(where: text.contains) { value += 42 }
        if !recipient.usesAge, ageIsConfirmed {
            if ["kids", "child", "toy", "dinosaur"].contains(where: text.contains) {
                value -= 60
            }
            if ["watch", "jewelry", "design", "interior", "leather", "accessory"]
                .contains(where: text.contains) {
                value += 36
            }
        }
        if recipient.usesAge {
            for interest in state.interests where interestKeywords(interest).contains(where: text.contains) {
                value += 28
            }
        }
        switch intent {
        case .fun where ["puzzle", "neon", "comic", "robot"].contains(where: text.contains): value += 34
        case .useful where ["watch", "binocular", "clock", "communication", "screen-free"].contains(where: text.contains): value += 34
        case .together where ["field", "craft", "puzzle", "coding", "robot"].contains(where: text.contains): value += 34
        case .surprise where ["ring", "neon", "comic", "robot"].contains(where: text.contains): value += 34
        default: break
        }
        value += profileScore(for: text)
        return value
    }

    private func profileScore(for text: String) -> Int {
        var value = 0
        let ignoredTerms: Set<String> = ["and", "for", "from", "into", "the", "with"]
        let terms = state.profileKeywords
            .flatMap { $0.lowercased().split { !$0.isLetter && !$0.isNumber } }
            .map(String.init)
            .filter { $0.count > 3 && !ignoredTerms.contains($0) }
        value += min(terms.reduce(0) { $0 + (text.contains($1) ? 28 : 0) }, 112)

        let preferredTerms: [String]
        switch state.profilePersonaID {
        case "archivist":
            preferredTerms = ["archive", "vintage", "watch", "jewelry", "leather", "design"]
        case "collector":
            preferredTerms = ["ring", "jewelry", "watch", "object", "edition", "design"]
        case "individualist":
            preferredTerms = ["neon", "comic", "robot", "sculptural", "color", "statement"]
        case "minimalist":
            preferredTerms = ["minimal", "classic", "stainless", "black", "design", "useful"]
        default:
            preferredTerms = []
        }
        value += preferredTerms.reduce(0) { $0 + (text.contains($1) ? 24 : 0) }

        if state.profilePriorities.contains("Independent sellers"),
           !["moma", "pollen-robotics", "tin-can-kids"].contains(itemMerchantID(in: text)) {
            value += 12
        }
        if state.profileDiscoveryStyleID == "surprising",
           ["neon", "robot", "ring", "comic", "sculptural"].contains(where: text.contains) {
            value += 18
        }
        return value
    }

    /// The score already receives flattened searchable text; this keeps the
    /// independent-seller nudge conservative when a known large prototype
    /// merchant is present without introducing another catalog dependency.
    private func itemMerchantID(in text: String) -> String {
        if text.contains("moma") { return "moma" }
        if text.contains("pollen") { return "pollen-robotics" }
        if text.contains("tin can") { return "tin-can-kids" }
        return "independent"
    }

    private func interestKeywords(_ interest: GiftGuideInterest) -> [String] {
        switch interest {
        case .outdoors: ["outdoor", "field", "binocular", "adventure"]
        case .games: ["game", "puzzle", "play", "robot"]
        case .making: ["build", "craft", "coding", "robot"]
        case .sports: ["sport", "ball", "run", "skate"]
        case .music: ["music", "audio", "speaker", "headphone"]
        case .style: ["shirt", "shoe", "watch", "style"]
        case .food: ["food", "cook", "chocolate", "kitchen"]
        case .books: ["book", "comic", "story", "manual"]
        case .animals: ["animal", "pet", "dog", "cat"]
        case .travel: ["travel", "bag", "trip", "portable"]
        case .home: ["home", "design", "lamp", "clock"]
        case .surprises: ["neon", "ring", "robot", "unexpected"]
        }
    }

    private func activityScore(_ item: ResolvedStoryProduct) -> Int {
        let text = item.product.title.lowercased()
        return ["field", "binocular", "craft", "puzzle", "comic"]
            .reduce(0) { $0 + (text.contains($1) ? 20 : 0) }
    }

    private func searchableText(for item: ResolvedStoryProduct) -> String {
        ([
            item.product.title,
            item.product.productType ?? "",
            item.product.productDescription ?? "",
            item.merchant.displayName,
        ] + item.product.tags)
            .joined(separator: " ")
            .lowercased()
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
        registerUpdate("Rebuilt \(state.recipientName)’s guide from your brief")
    }
}

struct GiftGuideTopicFilterBar: View {
    @Bindable var state: GiftGuidePrototypeState
    let recipient: GiftGuideRecipient

    var body: some View {
        HStack(spacing: GravitySpacing.space4) {
            if recipient.usesAge {
                Menu {
                    ForEach([7, 10, 13, 16], id: \.self) { age in
                        Button("Age \(age)") {
                            state.age = Double(age)
                            state.ageIsConfirmed = true
                            state.registerUpdate("Updated for \(state.recipientName) at age \(age)")
                        }
                    }
                } label: {
                    filterPill("Age \(Int(state.age))", width: 58)
                }
                .accessibilityLabel("\(state.recipientName)’s age")
            }

            Menu {
                ForEach([50, 100, 150, 400], id: \.self) { budget in
                    Button("Under $\(budget)") {
                        state.budget = Double(budget)
                        state.budgetIsConfirmed = true
                        state.registerUpdate("Rebuilt the shortlist under $\(budget)")
                    }
                }
            } label: {
                filterPill("Budget $\(Int(state.budget))", width: 82)
            }
            .accessibilityLabel("Gift budget")

            if !recipient.isNari {
                Menu {
                    ForEach(GiftSetting.allCases) { setting in
                        Button(setting.label) {
                            state.setting = setting
                            state.settingIsConfirmed = true
                            state.registerUpdate("Shifted the guide toward \(setting.label.lowercased())")
                        }
                    }
                } label: {
                    filterPill(state.setting.label, width: 82)
                }
                .accessibilityLabel("Gift setting")
            }

            Menu {
                ForEach(GiftIntent.allCases) { intent in
                    Button(intent.label) {
                        state.intent = intent
                        state.intentIsConfirmed = true
                        state.registerUpdate("Prioritizing \(intent.label.lowercased()) gifts")
                    }
                }
            } label: {
                filterPill(state.intent.label, width: 92)
            }
            .accessibilityLabel("Gift intent")
        }
        .frame(height: FeedNavigationStyle.controlSize)
    }

    private func filterPill(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(GravityFont.semiBold.fixedFont(size: 11))
            .foregroundStyle(.black.opacity(0.82))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(width: width, height: FeedNavigationStyle.controlSize)
            .background { Capsule().fill(.white.opacity(0.48)) }
            .clipShape(Capsule())
            .glassEffect(.regular, in: .capsule)
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.36), lineWidth: 0.5)
            }
    }
}

struct GiftGuideSteeringDock: View {
    @Bindable var state: GiftGuidePrototypeState
    let recipient: GiftGuideRecipient

    var body: some View {
        Menu {
            Button {
                HapticFeedback.light.fire()
                state.showsVoiceMode = true
            } label: {
                Label("Speak with Shop", systemImage: "waveform")
            }
            Button {
                HapticFeedback.light.fire()
                state.showsTuning = true
            } label: {
                Label("Chat with Shop", systemImage: "message")
            }
        } label: {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black.opacity(0.82))
                .frame(width: 56, height: 56)
                .background { Circle().fill(.white.opacity(0.48)) }
                .clipShape(Circle())
                .glassEffect(.regular, in: .circle)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.36), lineWidth: 0.5)
                }
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
        .accessibilityLabel("Voice or chat with Shop")
        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
        .sheet(isPresented: $state.showsVoiceMode) {
            GiftGuideVoiceMode(recipientName: state.recipientName, recipient: recipient)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct GiftGuideVoiceMode: View {
    let recipientName: String
    let recipient: GiftGuideRecipient
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
                Text("Tell Shop about \(recipientName)")
                    .font(GravityFont.expressiveBold.fixedFont(size: 22))
                Text("Try “\(recipient.voiceExample)”")
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
    func sectionTitle(for recipientName: String) -> String {
        switch self {
        case .indoors: "For \(recipientName)’s world indoors"
        case .both: "For wherever the day goes"
        case .outdoors: "For \(recipientName)’s next adventure"
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
    let recipientName: String
    @Binding var age: Double
    @Binding var setting: GiftSetting
    @Binding var budget: Double
    @Binding var intent: GiftIntent
    @Binding var note: String
    let recipient: GiftGuideRecipient
    let apply: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if recipient.usesAge {
                        dial(title: "How old is \(recipientName)?", value: "\(Int(age))") {
                            Slider(value: $age, in: 5...17, step: 1)
                                .tint(Color(hex: "#7455A2"))
                        }
                    }

                    VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                        Text("Where does \(recipientName) come alive?")
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
                        Text(recipient.noteQuestion)
                            .font(GravityFont.bold.fixedFont(size: 17))
                        TextField(recipient.occasionPlaceholder, text: $note, axis: .vertical)
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
            .navigationTitle("Tune \(recipientName)’s gift guide")
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
