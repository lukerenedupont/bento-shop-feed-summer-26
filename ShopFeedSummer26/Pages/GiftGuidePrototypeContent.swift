import Observation
import SwiftUI

/// PROTOTYPE — Session-only state shared by the gift content and its pinned
/// steering dock so every control visibly transforms one coherent page.
@Observable
final class GiftGuidePrototypeState {
    var showsTuning = false
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

            nextQuestion
                .padding(.horizontal, GravitySpacing.space12)

            giftRoutes

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

    @ViewBuilder
    private var nextQuestion: some View {
        if !ageIsConfirmed {
            ageQuestion
        } else if !settingIsConfirmed {
            settingQuestion
        } else if !intentIsConfirmed {
            intentQuestion
        } else if !state.budgetIsConfirmed {
            budgetQuestion
        }
    }

    private var ageQuestion: some View {
        questionCard(
            title: "How old is Leon?",
            detail: ageIsConfirmed ? "Confirmed — change it anytime" : "This has the biggest effect on the guide"
        ) {
            HStack(spacing: GravitySpacing.space6) {
                ForEach([7, 10, 13, 16], id: \.self) { option in
                    steerButton("\(option)", selected: Int(age) == option && ageIsConfirmed) {
                        age = Double(option)
                        ageIsConfirmed = true
                        registerUpdate("Updated for Leon at age \(option)")
                    }
                }
            }
        }
    }

    private var settingQuestion: some View {
        questionCard(
            title: "Where does Leon come alive?",
            detail: settingIsConfirmed ? "We’ll keep this preference in the mix" : "Help us choose between projects and adventures"
        ) {
            HStack(spacing: GravitySpacing.space6) {
                ForEach(GiftSetting.allCases) { option in
                    steerButton(option.label, selected: setting == option && settingIsConfirmed) {
                        setting = option
                        settingIsConfirmed = true
                        registerUpdate("Shifted the guide toward \(option.label.lowercased())")
                    }
                }
            }
        }
    }

    private var intentQuestion: some View {
        questionCard(
            title: "What should the gift feel like?",
            detail: intentIsConfirmed ? "That feeling is now shaping every section" : "There isn’t one right kind of gift"
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                ForEach(GiftIntent.allCases) { option in
                    steerButton(option.label, selected: intent == option && intentIsConfirmed) {
                        intent = option
                        intentIsConfirmed = true
                        registerUpdate("Prioritizing \(option.label.lowercased()) gifts")
                    }
                }
            }
        }
    }

    private var budgetQuestion: some View {
        questionCard(
            title: "What feels comfortable?",
            detail: state.budgetIsConfirmed ? "We’ll keep the main picks under $\(Int(budget))" : "Stretch ideas stay visible, but clearly marked"
        ) {
            HStack(spacing: GravitySpacing.space6) {
                ForEach([50, 100, 150, 400], id: \.self) { option in
                    steerButton("$\(option)", selected: Int(budget) == option && state.budgetIsConfirmed) {
                        budget = Double(option)
                        state.budgetIsConfirmed = true
                        registerUpdate("Rebuilt the shortlist under $\(option)")
                    }
                }
            }
        }
    }

    private func questionCard<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                Text(title)
                    .font(GravityFont.bold.fixedFont(size: 18))
                    .tracking(-0.35)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(GravityFont.regular.fixedFont(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }
            content()
        }
        .padding(GravitySpacing.space16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: GravityRadius.r24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GravityRadius.r24, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
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
            ZStack(alignment: .bottomLeading) {
                ProductImageView(product: item.product, merchant: item.merchant)
                    .aspectRatio(0.92, contentMode: .fill)
                    .clipped()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.68)],
                    startPoint: .center,
                    endPoint: .bottom
                )
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
            .aspectRatio(0.92, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
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

    private func steerButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(GravityFont.semiBold.fixedFont(size: 12))
                .foregroundStyle(selected ? Color(hex: "#392657") : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(selected ? Color.white : Color.white.opacity(0.10), in: Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
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

    var body: some View {
        HStack(spacing: GravitySpacing.space6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space6) {
                    Menu {
                        ForEach([7, 10, 13, 16], id: \.self) { age in
                            Button("Age \(age)") {
                                state.age = Double(age)
                                state.ageIsConfirmed = true
                                state.registerUpdate("Updated for Leon at age \(age)")
                            }
                        }
                    } label: {
                        dockPill("Age \(Int(state.age))\(state.ageIsConfirmed ? "" : "?")", confirmed: state.ageIsConfirmed)
                    }

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
                            "\(state.setting.label)\(state.settingIsConfirmed ? "" : "?")",
                            confirmed: state.settingIsConfirmed
                        )
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
                        dockPill(
                            "$\(Int(state.budget))\(state.budgetIsConfirmed ? "" : "?")",
                            confirmed: state.budgetIsConfirmed
                        )
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
                        dockPill(
                            "\(state.intent.label)\(state.intentIsConfirmed ? "" : "?")",
                            confirmed: state.intentIsConfirmed
                        )
                    }
                }
            }

            Button {
                HapticFeedback.light.fire()
                state.showsTuning = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(GravityColors.text)
                    .frame(width: 44, height: 44)
                    .background(GravityColors.bgOverlayFixedDark04, in: Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Tune Leon’s gift guide")
        }
        .padding(6)
        .frame(width: 262, height: 56)
        .background(.white.opacity(0.75))
        .clipShape(Capsule())
        .glassEffect(.regular, in: .capsule)
        .environment(\.colorScheme, .light)
    }

    private func dockPill(_ title: String, confirmed: Bool) -> some View {
        Text(title)
            .font(GravityFont.semiBold.fixedFont(size: 12))
            .foregroundStyle(confirmed ? GravityColors.text : GravityColors.textTertiary)
            .padding(.horizontal, GravitySpacing.space12)
            .frame(height: 44)
            .background(
                confirmed ? GravityColors.bgOverlayFixedDark04 : .clear,
                in: Capsule()
            )
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
