import SwiftUI

/// PROTOTYPE — A steerable topic that tests whether recipient controls can
/// make a gift guide feel alive. State is intentionally session-only.
struct GiftGuidePrototypeContent: View {
    let products: [ResolvedStoryProduct]

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var showsTuning = false
    @State private var age = 10.0
    @State private var ageIsConfirmed = false
    @State private var setting = GiftSetting.both
    @State private var settingIsConfirmed = false
    @State private var budget = 150.0
    @State private var intent = GiftIntent.surprise
    @State private var intentIsConfirmed = false
    @State private var note = ""
    @State private var appliedNote = ""
    @State private var updateToken = 0

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

            progressivePrompt
                .padding(.horizontal, GravitySpacing.space12)

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
        .sheet(isPresented: $showsTuning) {
            GiftGuideTuningSheet(
                age: $age,
                setting: $setting,
                budget: $budget,
                intent: $intent,
                note: $note,
                apply: {
                    ageIsConfirmed = true
                    settingIsConfirmed = true
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
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            HStack {
                VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                    Text("Gift brief")
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .foregroundStyle(.white.opacity(0.58))
                    Text("For Leon")
                        .font(GravityFont.expressiveBold.fixedFont(size: 21))
                        .tracking(-0.5)
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    HapticFeedback.light.fire()
                    showsTuning = true
                } label: {
                    Label("Tune", systemImage: "slider.horizontal.3")
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                        .foregroundStyle(Color(hex: "#392657"))
                        .padding(.horizontal, GravitySpacing.space12)
                        .frame(height: 34)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
            }

            HStack(spacing: GravitySpacing.space6) {
                briefChip("Age \(Int(age))\(ageIsConfirmed ? "" : "?")", confirmed: ageIsConfirmed)
                briefChip(setting.label, confirmed: settingIsConfirmed)
                briefChip("Under $\(Int(budget))", confirmed: true)
            }

            if !appliedNote.isEmpty {
                HStack(spacing: GravitySpacing.space4) {
                    Image(systemName: "sparkles")
                    Text(appliedNote)
                        .lineLimit(1)
                }
                .font(GravityFont.medium.fixedFont(size: 12))
                .foregroundStyle(.white.opacity(0.76))
            }
        }
        .padding(14)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: GravityRadius.r24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GravityRadius.r24, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        }
    }

    private func briefChip(_ title: String, confirmed: Bool) -> some View {
        HStack(spacing: GravitySpacing.space4) {
            Text(title)
            Image(systemName: confirmed ? "checkmark" : "sparkles")
                .font(.system(size: 9, weight: .bold))
        }
        .font(GravityFont.medium.fixedFont(size: 12))
        .foregroundStyle(.white)
        .padding(.horizontal, GravitySpacing.space10)
        .frame(height: 30)
        .background(.white.opacity(confirmed ? 0.13 : 0.20), in: Capsule())
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

    private var progressivePrompt: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            HStack {
                VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                    Text(promptEyebrow)
                        .font(GravityFont.semiBold.fixedFont(size: 10))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.52))
                    Text(promptTitle)
                        .font(GravityFont.bold.fixedFont(size: 18))
                        .tracking(-0.35)
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(promptProgress)
                    .font(GravityFont.medium.fixedFont(size: 11))
                    .foregroundStyle(.white.opacity(0.48))
            }

            if !ageIsConfirmed {
                HStack(spacing: GravitySpacing.space6) {
                    ForEach([7, 10, 13, 16], id: \.self) { option in
                        steerButton("\(option)", selected: Int(age) == option && ageIsConfirmed) {
                            age = Double(option)
                            ageIsConfirmed = true
                            registerUpdate()
                        }
                    }
                }
            } else if !settingIsConfirmed {
                HStack(spacing: GravitySpacing.space6) {
                    ForEach(GiftSetting.allCases) { option in
                        steerButton(option.label, selected: setting == option && settingIsConfirmed) {
                            setting = option
                            settingIsConfirmed = true
                            registerUpdate()
                        }
                    }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                    ForEach(GiftIntent.allCases) { option in
                        steerButton(option.label, selected: intent == option && intentIsConfirmed) {
                            intent = option
                            intentIsConfirmed = true
                            registerUpdate()
                        }
                    }
                }
            }
        }
        .padding(GravitySpacing.space16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: GravityRadius.r24, style: .continuous))
    }

    private var promptEyebrow: String {
        if !ageIsConfirmed { return "One quick check" }
        if !settingIsConfirmed { return "Getting closer" }
        return "Shape the surprise"
    }

    private var promptTitle: String {
        if !ageIsConfirmed { return "How old is Leon?" }
        if !settingIsConfirmed { return "Which sounds more like Leon?" }
        return "What should the gift feel like?"
    }

    private var promptProgress: String {
        if !ageIsConfirmed { return "1 of 3" }
        if !settingIsConfirmed { return "2 of 3" }
        return "3 of 3"
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
                Image(systemName: "sparkles")
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

    private func registerUpdate() {
        HapticFeedback.light.fire()
        updateToken += 1
    }

    private func applyTuning() {
        appliedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        showsTuning = false
        registerUpdate()
    }
}

private enum GiftSetting: String, CaseIterable, Identifiable {
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

private enum GiftIntent: String, CaseIterable, Identifiable {
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
