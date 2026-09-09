import SwiftUI

/// PROTOTYPE — direct review for product-specific feed interactions.
/// Cards are added one at a time so each merchant treatment can be reviewed
/// before the sequence expands.
struct ProductSpecificFeedGallery: View {
    @State private var coordinator = NavigationCoordinator()
    @State private var selectedIndex: Int
    @Namespace private var namespace

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let flag = arguments.firstIndex(of: "-productSpecificCard")
        let requested = flag.flatMap { arguments.indices.contains($0 + 1) ? Int(arguments[$0 + 1]) : nil } ?? 0
        _selectedIndex = State(initialValue: min(max(requested, 0), 6))
    }

    var body: some View {
        NavigationStack(path: $coordinator.homePath) {
            GeometryReader { proxy in
                let topInset = proxy.safeAreaInsets.top
                let bottomInset = proxy.safeAreaInsets.bottom
                let totalHeight = proxy.size.height + topInset + bottomInset

                VStack(spacing: 0) {
                    Group {
                        switch selectedIndex {
                        case 0:
                            OliveAndJuneNailPreviewCard(
                                width: proxy.size.width,
                                height: totalHeight - bottomInset - 64,
                                topPadding: topInset + GravitySpacing.space16
                            )
                        case 1:
                            GrazaOilPickerCard(
                                width: proxy.size.width,
                                height: totalHeight - bottomInset - 64,
                                topPadding: topInset + GravitySpacing.space16
                            )
                        case 2:
                            CotopaxiTrozoPackingCard(
                                width: proxy.size.width,
                                height: totalHeight - bottomInset - 64,
                                topPadding: topInset + GravitySpacing.space16
                            )
                        case 3:
                            TaylorStitchQuincyCard(
                                width: proxy.size.width,
                                height: totalHeight - bottomInset - 64,
                                topPadding: topInset + GravitySpacing.space16
                            )
                        case 4:
                            DSDurgaScentCard(
                                width: proxy.size.width,
                                height: totalHeight - bottomInset - 64,
                                topPadding: topInset + GravitySpacing.space16
                            )
                        case 5:
                            FellowCoffeeRitualCard(
                                width: proxy.size.width,
                                height: totalHeight - bottomInset - 64,
                                topPadding: topInset + GravitySpacing.space16
                            )
                        default:
                            UgmonkAnalogFocusCard(
                                width: proxy.size.width,
                                height: totalHeight - bottomInset - 64,
                                topPadding: topInset + GravitySpacing.space16
                            )
                        }
                    }
                    .id(selectedIndex)

                    HStack {
                        Button { selectedIndex = max(0, selectedIndex - 1) } label: {
                            Image(systemName: "chevron.left").frame(width: 48, height: 48)
                        }
                        .disabled(selectedIndex == 0)
                        .opacity(selectedIndex == 0 ? 0.2 : 1)
                        Spacer()
                        Text("\(selectedIndex + 1) of 8 · \(["Nail preview", "Pick the right oil", "Pack the Trozo", "Style the Quincy", "Explore the scent", "Build a coffee ritual", "Make the list analog"][selectedIndex])")
                            .font(GravityFont.semiBold.fixedFont(size: 14))
                        Spacer()
                        Button { selectedIndex = min(6, selectedIndex + 1) } label: {
                            Image(systemName: "chevron.right").frame(width: 48, height: 48)
                        }
                        .disabled(selectedIndex == 6)
                        .opacity(selectedIndex == 6 ? 0.2 : 1)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, GravitySpacing.space20)
                    .frame(height: 64)
                    .foregroundStyle(.black)
                }
                .frame(width: proxy.size.width, height: totalHeight)
                .offset(y: -topInset)
                .background(Color.white)
            }
            .navigationDestination(for: HomeRoute.self) { route in
                if case .agentProduct(let product) = route {
                    ProductPage(agentProduct: product, namespace: namespace)
                }
            }
        }
        .environment(coordinator)
    }
}

private struct OliveAndJuneNailPreviewCard: View {
    private struct Shade: Identifiable {
        let id: String
        let name: String
        let color: Color
        let bottleURL: URL
    }

    private enum SkinTone: String, CaseIterable, Identifiable {
        case light, medium, deep
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var color: Color {
            switch self {
            case .light: Color(hex: "#EBC1A5")
            case .medium: Color(hex: "#B9774F")
            case .deep: Color(hex: "#75422E")
            }
        }
    }

    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedShadeID = "actually-dramatic"
    @State private var selectedTone: SkinTone = .medium

    private let shades = [
        Shade(id: "actually-dramatic", name: "Actually Dramatic", color: Color(hex: "#851531"),
              bottleURL: URL(string: "https://cdn.shopify.com/s/files/1/2665/7478/files/Actualltry_Dramatic_LL-tr_9d3395d2-5a1f-42ec-a0f8-8c4378839f94.png")!),
        Shade(id: "lowkey-perfect", name: "Lowkey Perfect", color: Color(hex: "#C9AEB1"),
              bottleURL: URL(string: "https://cdn.shopify.com/s/files/1/2665/7478/files/Lowkey_Perfect_LL-tr_97328a0c-ba36-4a1f-a48c-e0e28f2572bf.png")!),
        Shade(id: "unbothered-energy", name: "Unbothered Energy", color: Color(hex: "#8FA448"),
              bottleURL: URL(string: "https://cdn.shopify.com/s/files/1/2665/7478/files/Unbothered_Energy_LL-tr_53c06ad4-a3cd-4090-8c02-68b7137b494f.png")!),
        Shade(id: "not-quiet-luxury", name: "Not Quiet Luxury", color: Color(hex: "#00667A"),
              bottleURL: URL(string: "https://cdn.shopify.com/s/files/1/2665/7478/files/Not_Quiet_Luxury_LL-tr_7b336931-d049-425f-8d7b-d412714837dc.png")!)
    ]

    private var selectedShade: Shade { shades.first { $0.id == selectedShadeID } ?? shades[0] }
    private var imageURL: URL? {
        let images: [String: [SkinTone: String]] = [
            "actually-dramatic": [
                .light: "https://cdn.shopify.com/s/files/1/2665/7478/files/2_3cf157cd-3202-413a-a8e0-cbcc1945de2f.png",
                .medium: "https://cdn.shopify.com/s/files/1/2665/7478/files/ActuallyDramaticNP2.png",
                .deep: "https://cdn.shopify.com/s/files/1/2665/7478/files/1_bfc68455-452b-4948-bbc1-ea90d62ae0b6.png"
            ],
            "lowkey-perfect": [
                .light: "https://cdn.shopify.com/s/files/1/2665/7478/files/LowkeyPerfectNP3.png",
                .medium: "https://cdn.shopify.com/s/files/1/2665/7478/files/LowkeyPerfectNP2.png",
                .deep: "https://cdn.shopify.com/s/files/1/2665/7478/files/2_5b4a475f-fcf9-48ae-a75b-8d1eee64c8f6.png"
            ],
            "unbothered-energy": [
                .light: "https://cdn.shopify.com/s/files/1/2665/7478/files/Artboard1-4.png",
                .medium: "https://cdn.shopify.com/s/files/1/2665/7478/files/UnbotheredEnergyNP2.png",
                .deep: "https://cdn.shopify.com/s/files/1/2665/7478/files/Artboard1-3.png"
            ],
            "not-quiet-luxury": [
                .light: "https://cdn.shopify.com/s/files/1/2665/7478/files/NotQuietLuxuryNP1.png",
                .medium: "https://cdn.shopify.com/s/files/1/2665/7478/files/NotQuietLuxuryNP2.png",
                .deep: "https://cdn.shopify.com/s/files/1/2665/7478/files/Artboard1-4_f876526b-2d12-4f2a-a46d-32323352bf13.png"
            ]
        ]
        guard let source = images[selectedShade.id]?[selectedTone] else { return nil }
        return URL(string: source + "?width=1000")
    }
    private var selectedProduct: AgentProduct {
        AgentProduct(
            id: "olive-and-june-\(selectedShade.id)",
            title: selectedShade.name,
            price: "$10",
            originalPrice: nil,
            imageURL: selectedShade.bottleURL,
            allImageURLs: [selectedShade.bottleURL, imageURL].compactMap { $0 },
            rating: nil,
            ratingCount: nil,
            shopName: "Olive & June",
            shopLogoURL: URL(string: "https://oliveandjune.com/cdn/shop/files/main-logo_2x_32c6d76d-f837-4a47-8fae-8b2868b06da5.png?v=1651863832"),
            descriptors: [],
            labels: []
        )
    }
    var body: some View {
        ZStack {
            Color(hex: "#F8EDEC")

            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                merchantIdentity
                Text("Find your next shade.")
                    .font(GravityFont.bold.fixedFont(size: 28))
                    .tracking(-0.7)
                    .lineLimit(1)
                Text("Real polish, shown on different hands.")
                    .font(GravityFont.medium.fixedFont(size: 14))
                    .foregroundStyle(Color(hex: "#443035").opacity(0.66))

                hero
                    .padding(.top, GravitySpacing.space4)
                selectionControls
                Spacer(minLength: 0)
                viewComboButton
            }
            .frame(width: width - GravitySpacing.space20 * 2, alignment: .leading)
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, topPadding)
            .padding(.bottom, GravitySpacing.space12)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Olive and June nail polish preview")
    }

    private var merchantIdentity: some View {
        HStack(spacing: GravitySpacing.space8) {
            BundleImage(name: "olive-and-june-mark", extension: "png")
                .frame(width: 25, height: 25)
            Text("Olive & June")
                .font(GravityFont.semiBold.fixedFont(size: 15))
            Spacer()
        }
        .frame(height: 32)
    }

    private var hero: some View {
        ZStack {
            if let imageURL {
                CachedAsyncImage(url: imageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        selectedShade.color.opacity(0.14)
                    }
                }
                .id(imageURL)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: min(405, height * 0.47))
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: imageURL)
        .accessibilityHidden(true)
    }

    private var selectionControls: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Skin tone reference")
                        .font(GravityFont.medium.fixedFont(size: 12))
                    Text(selectedTone.label)
                        .font(GravityFont.regular.fixedFont(size: 10))
                        .opacity(0.56)
                }
                Spacer()
                HStack(spacing: GravitySpacing.space12) {
                    ForEach(SkinTone.allCases) { tone in
                        Button { selectTone(tone) } label: {
                            Circle()
                                .fill(tone.color)
                                .frame(width: 26, height: 26)
                                .padding(3)
                                .overlay {
                                    Circle().stroke(selectedTone == tone ? Color(hex: "#443035") : .clear, lineWidth: 1.5)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(tone.label) skin tone")
                        .accessibilityAddTraits(selectedTone == tone ? .isSelected : [])
                    }
                }
            }
            .frame(height: 48)

            Divider().overlay(Color(hex: "#443035").opacity(0.12))

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Polish")
                        .font(GravityFont.medium.fixedFont(size: 12))
                    Text(selectedShade.name)
                        .font(GravityFont.regular.fixedFont(size: 10))
                        .opacity(0.56)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: GravitySpacing.space10) {
                    ForEach(shades) { shade in
                        Button { selectShade(shade) } label: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(shade.color)
                                .frame(width: 27, height: 27)
                                .padding(3)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(selectedShade.id == shade.id ? Color(hex: "#443035") : .clear, lineWidth: 1.5)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(shade.name) polish")
                        .accessibilityAddTraits(selectedShade.id == shade.id ? .isSelected : [])
                    }
                }
            }
            .frame(height: 48)
        }
        .padding(.horizontal, GravitySpacing.space12)
        .background(.white.opacity(0.34), in: RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous))
    }

    private var viewComboButton: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.agentProduct(selectedProduct))
        } label: {
            HStack(spacing: GravitySpacing.space12) {
                CachedAsyncImage(url: selectedShade.bottleURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        selectedShade.color.opacity(0.18)
                    }
                }
                .frame(width: 44, height: 44)
                .id(selectedShade.id)

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedShade.name)
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                        .lineLimit(1)
                    Text("$10")
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .opacity(0.62)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, GravitySpacing.space12)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .foregroundStyle(Color(hex: "#443035"))
            .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(selectedShade.name), $10")
    }

    private func selectTone(_ tone: SkinTone) {
        guard tone != selectedTone else { return }
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { selectedTone = tone }
    }

    private func selectShade(_ shade: Shade) {
        guard shade.id != selectedShadeID else { return }
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { selectedShadeID = shade.id }
    }

}

#if false
private struct LegacyGrazaOilPickerCard: View {
    private enum CookingChoice: String, CaseIterable, Identifiable {
        case saute = "Sauté"
        case bread = "Bread"
        case roast = "Roast"
        case salad = "Salad"

        var id: String { rawValue }
        var sentence: String {
            switch self {
            case .saute: "sautéing"
            case .roast: "roasting"
            case .bread: "bread"
            case .salad: "salad"
            }
        }
        var usesSizzle: Bool { self == .saute || self == .roast }
    }

    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var choice: CookingChoice = .saute

    private var oilName: String { choice.usesSizzle ? "Sizzle" : "Drizzle" }
    private var price: String { choice.usesSizzle ? "$16" : "$21" }
    private var product: AgentProduct {
        let imageString = choice.usesSizzle
            ? "https://cdn.shopify.com/s/files/1/0550/0003/9638/files/30_product_sizzle750ml_0002_fe965569-a5c7-45ca-8809-47da9aba1e32.jpg"
            : "https://cdn.shopify.com/s/files/1/0550/0003/9638/files/driz.jpg"
        let image = URL(string: imageString)
        return AgentProduct(
            id: choice.usesSizzle ? "7429933924566" : "7429934252246",
            title: oilName,
            price: price,
            originalPrice: nil,
            imageURL: image,
            allImageURLs: [image].compactMap { $0 },
            rating: nil,
            ratingCount: nil,
            shopName: "Graza",
            shopLogoURL: URL(string: "https://www.graza.co/cdn/shop/files/graza-logo.png?v=1638847956"),
            descriptors: [],
            labels: []
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "#F1E5C9")
            RadialGradient(
                colors: [Color(hex: "#E8B23A").opacity(0.22), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: width
            )

            VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                BundleImage(name: "graza-wordmark", extension: "png")
                    .frame(width: 112, height: 32)
                Text("What are you making?")
                    .feedCardTitleStyle()

                bento
                Spacer(minLength: GravitySpacing.space8)

                VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                    Text("For \(choice.sentence)")
                        .font(GravityFont.regular.fixedFont(size: 13))
                        .foregroundStyle(.black.opacity(0.62))
                    Text(choice.usesSizzle ? "Cook with Sizzle" : "Finish with Drizzle")
                        .font(GravityFont.expressiveSemiBold.fixedFont(size: 24))
                }

                Button {
                    HapticFeedback.light.fire()
                    coordinator.pushRoute(.agentProduct(product))
                } label: {
                    HStack {
                        Text("View \(oilName)")
                            .font(GravityFont.semiBold.fixedFont(size: 15))
                        Spacer()
                        Text(price)
                            .font(GravityFont.medium.fixedFont(size: 14))
                            .opacity(0.72)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, GravitySpacing.space20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(Color(hex: "#1F3D2B"), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(width: width - GravitySpacing.space20 * 2, alignment: .leading)
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, topPadding)
            .padding(.bottom, GravitySpacing.space16)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Graza oil picker")
    }

    private var bento: some View {
        GeometryReader { proxy in
            BundleImage(name: "graza-trio-bento", extension: "jpg", fills: true)
                .frame(width: proxy.size.width, height: proxy.size.height)

            let tileWidth = proxy.size.width / 2
            let tileHeight = proxy.size.height / 2
            ForEach(Array(CookingChoice.allCases.enumerated()), id: \.element.id) { index, item in
                Button { select(item) } label: {
                    ZStack(alignment: .bottomLeading) {
                        Color.clear
                        Text(item.rawValue)
                            .font(GravityFont.semiBold.fixedFont(size: 13))
                            .foregroundStyle(choice == item ? Color.black : .white)
                            .padding(.horizontal, GravitySpacing.space12)
                            .frame(height: 34)
                            .background(choice == item ? Color(hex: "#E8B23A") : .black.opacity(0.72), in: Capsule())
                            .padding(GravitySpacing.space8)
                    }
                    .frame(width: tileWidth, height: tileHeight)
                    .contentShape(Rectangle())
                    .overlay {
                        Rectangle()
                            .strokeBorder(choice == item ? Color.white : .clear, lineWidth: 4)
                    }
                }
                .buttonStyle(.plain)
                .position(
                    x: tileWidth * (index.isMultiple(of: 2) ? 0.5 : 1.5),
                    y: tileHeight * (index < 2 ? 0.5 : 1.5)
                )
                .accessibilityLabel("Choose \(item.rawValue.lowercased())")
                .accessibilityAddTraits(choice == item ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: min(370, height * 0.44))
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
    }

    private func select(_ item: CookingChoice) {
        guard choice != item else { return }
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { choice = item }
    }
}

#endif

#if false
private struct LegacyInteractiveGrazaOilPickerCard: View {
    private enum OilMoment: Int, CaseIterable {
        case cooking, finishing

        var oil: String { self == .cooking ? "Sizzle" : "Drizzle" }
        var price: String { self == .cooking ? "$16" : "$21" }
        var sceneAsset: String { self == .cooking ? "graza-pencil-pan" : "graza-pencil-pasta" }
        var bottleAsset: String { self == .cooking ? "graza-pencil-sizzle" : "graza-pencil-bottle" }
        var title: String { self == .cooking ? "Sizzle does the cooking." : "Drizzle is the finishing touch." }
        var copy: String {
            self == .cooking
                ? "Start here: sauté, roast, or fry. Your everyday oil for the heat."
                : "Off the heat, onto the plate. A peppery squeeze just before you eat."
        }
        var label: String { self == .cooking ? "In the pan" : "On the plate" }
    }

    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moment: OilMoment = .cooking
    @State private var isPouring = false

    private var product: AgentProduct {
        let imageString = moment == .cooking
            ? "https://cdn.shopify.com/s/files/1/0550/0003/9638/files/30_product_sizzle750ml_0002_fe965569-a5c7-45ca-8809-47da9aba1e32.jpg"
            : "https://cdn.shopify.com/s/files/1/0550/0003/9638/files/driz.jpg"
        let image = URL(string: imageString)
        return AgentProduct(
            id: moment == .cooking ? "7429933924566" : "7429934252246",
            title: moment.oil,
            price: moment.price,
            originalPrice: nil,
            imageURL: image,
            allImageURLs: [image].compactMap { $0 },
            rating: nil,
            ratingCount: nil,
            shopName: "Graza",
            shopLogoURL: URL(string: "https://www.graza.co/cdn/shop/files/graza-logo.png?v=1638847956"),
            descriptors: [],
            labels: []
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "#F6F5E8")

            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                BundleImage(name: "graza-wordmark", extension: "png")
                    .frame(width: 108, height: 28, alignment: .leading)
                Text("Two oils. Two good jobs.")
                    .font(GravityFont.bold.fixedFont(size: 28))
                    .tracking(-0.7)
                    .lineLimit(1)
                Text("Sizzle for cooking. Drizzle for finishing.")
                    .font(GravityFont.medium.fixedFont(size: 14))
                    .foregroundStyle(Color(hex: "#3C422E").opacity(0.66))

                oilStage
                    .padding(.top, GravitySpacing.space4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(moment.title)
                        .font(GravityFont.semiBold.fixedFont(size: 18))
                    Text(moment.copy)
                        .font(GravityFont.regular.fixedFont(size: 13))
                        .foregroundStyle(Color(hex: "#3C422E").opacity(0.72))
                        .lineLimit(2)
                }
                .frame(height: 58, alignment: .topLeading)

                momentControl
                Spacer(minLength: 0)
                productFooter
            }
            .frame(width: width - GravitySpacing.space20 * 2, alignment: .leading)
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, topPadding)
            .padding(.bottom, GravitySpacing.space12)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
        .foregroundStyle(Color(hex: "#3C422E"))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Graza cooking and finishing oils")
    }

    private var oilStage: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: "#E7E4C8")

                Image(moment.sceneAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width * 0.92, height: proxy.size.height * 0.78)
                    .position(x: proxy.size.width * 0.44, y: proxy.size.height * 0.55)
                    .id(moment)
                    .transition(.opacity)

                Capsule()
                    .fill(Color(hex: "#829B43"))
                    .frame(width: 3, height: isPouring ? 118 : 0)
                    .position(x: proxy.size.width * 0.72, y: proxy.size.height * 0.59)
                    .opacity(isPouring ? 0.9 : 0)

                Button { pour() } label: {
                    Image(moment.bottleAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 86, height: 218)
                        .rotationEffect(.degrees(isPouring ? -28 : -13), anchor: .bottom)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: proxy.size.width * 0.77, y: proxy.size.height * 0.34)
                .accessibilityLabel("Squeeze \(moment.oil)")

                VStack(alignment: .leading, spacing: 2) {
                    Text(isPouring ? "A little goes a long way" : "Give me a squeeze")
                        .font(GravityFont.semiBold.fixedFont(size: 12))
                    Text("Tap the bottle ↗")
                        .font(GravityFont.regular.fixedFont(size: 10))
                        .opacity(0.58)
                }
                .position(x: proxy.size.width * 0.24, y: proxy.size.height * 0.17)

                Text("← Pan to plate →")
                    .font(GravityFont.medium.fixedFont(size: 11))
                    .opacity(0.62)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, GravitySpacing.space12)
            }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        select(value.translation.width < 0 ? .finishing : .cooking)
                    }
            )
        }
        .frame(height: min(390, height * 0.45))
    }

    private var momentControl: some View {
        HStack(spacing: 0) {
            ForEach(OilMoment.allCases, id: \.rawValue) { option in
                Button { select(option) } label: {
                    HStack {
                        Text(option == .cooking ? "←" : "")
                        VStack(spacing: 1) {
                            Text(option.label)
                                .font(GravityFont.semiBold.fixedFont(size: 12))
                            Text(option.oil)
                                .font(GravityFont.regular.fixedFont(size: 10))
                                .opacity(0.62)
                        }
                        Text(option == .finishing ? "→" : "")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 43)
                    .foregroundStyle(moment == option ? Color(hex: "#F6F5E8") : Color(hex: "#3C422E"))
                    .background(moment == option ? Color(hex: "#3C422E") : .clear)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(option.label.lowercased())")
                .accessibilityAddTraits(moment == option ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color(hex: "#3C422E").opacity(0.08), in: Capsule())
    }

    private var productFooter: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.agentProduct(product))
        } label: {
            HStack(spacing: GravitySpacing.space12) {
                Image(moment.bottleAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(moment.oil)
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                    Text(moment.price)
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .opacity(0.62)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, GravitySpacing.space12)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(.white.opacity(0.50), in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(moment.oil), \(moment.price)")
    }

    private func select(_ selection: OilMoment) {
        guard selection != moment else { return }
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            moment = selection
            isPouring = false
        }
    }

    private func pour() {
        HapticFeedback.light.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.20)) { isPouring = true }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.20)) { isPouring = false }
            }
        }
    }
}

#endif

private struct GrazaOilPickerCard: View {
    private enum GrazaOil: String, CaseIterable, Identifiable {
        case sizzle = "Sizzle"
        case frizzle = "Frizzle"
        case drizzle = "Drizzle"

        var id: String { rawValue }
        var price: String {
            switch self {
            case .sizzle: "$16"
            case .frizzle: "$14"
            case .drizzle: "$21"
            }
        }
        var color: Color {
            switch self {
            case .sizzle: Color(hex: "#E5DF61")
            case .frizzle: Color(hex: "#F19247")
            case .drizzle: Color(hex: "#B5CE76")
            }
        }
        var imageURL: URL {
            let source = switch self {
            case .sizzle: "https://cdn.shopify.com/s/files/1/0550/0003/9638/files/30_product_sizzle750ml_0002_fe965569-a5c7-45ca-8809-47da9aba1e32.jpg"
            case .frizzle: "https://cdn.shopify.com/s/files/1/0550/0003/9638/files/squeeze_2731d97c-2e92-429b-9b04-6e1b55d74a97.jpg?v=1762306788"
            case .drizzle: "https://cdn.shopify.com/s/files/1/0550/0003/9638/files/driz.jpg"
            }
            return URL(string: source)!
        }
        var productID: String {
            switch self {
            case .sizzle: "7429933924566"
            case .frizzle: "8843130863830"
            case .drizzle: "7429934252246"
            }
        }
        var product: AgentProduct {
            AgentProduct(
                id: productID,
                title: rawValue,
                price: price,
                originalPrice: nil,
                imageURL: imageURL,
                allImageURLs: [imageURL],
                rating: nil,
                ratingCount: nil,
                shopName: "Graza",
                shopLogoURL: URL(string: "https://www.graza.co/cdn/shop/files/graza-logo.png?v=1638847956"),
                descriptors: [],
                labels: []
            )
        }
    }

    private struct GameRound {
        let prompt: String
        let symbol: String
        let answer: GrazaOil
        let reason: String
    }

    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var roundIndex = 0
    @State private var selectedOil: GrazaOil?
    @State private var score = 0
    @State private var isFinished = false

    private let rounds = [
        GameRound(prompt: "Juicy roasted chicken with vegetables.", symbol: "flame", answer: .sizzle, reason: "Sizzle loves roasting and everyday heat."),
        GameRound(prompt: "A piping-hot stir fry with crispy tofu.", symbol: "takeoutbag.and.cup.and.straw", answer: .frizzle, reason: "Frizzle stays neutral at serious high heat."),
        GameRound(prompt: "A slice of pizza needs a little something.", symbol: "circle.grid.cross", answer: .drizzle, reason: "Drizzle is the peppery finish after cooking."),
        GameRound(prompt: "Scrambled eggs and a crispy fried egg.", symbol: "frying.pan", answer: .sizzle, reason: "Sizzle is made for the pan."),
        GameRound(prompt: "A big salad, ready to be dressed.", symbol: "leaf", answer: .drizzle, reason: "Drizzle brings the fresh, grassy finish.")
    ]

    private var round: GameRound { rounds[roundIndex] }
    private var featuredOil: GrazaOil { selectedOil == nil ? .sizzle : round.answer }

    var body: some View {
        ZStack {
            Color(hex: "#F6F5E8")

            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                BundleImage(name: "graza-wordmark", extension: "png")
                    .frame(width: 108, height: 28, alignment: .leading)
                Text("Sizzle, Drizzle, or Frizzle?")
                    .font(GravityFont.bold.fixedFont(size: 25))
                    .tracking(-0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                Text("Pick the right oil for the job.")
                    .font(GravityFont.medium.fixedFont(size: 14))
                    .foregroundStyle(Color(hex: "#3C422E").opacity(0.66))

                gameBoard
                    .padding(.top, GravitySpacing.space4)

                Text("Inspired by Graza’s favorite oil-filled game.")
                    .font(GravityFont.regular.fixedFont(size: 10))
                    .foregroundStyle(Color(hex: "#3C422E").opacity(0.56))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
                productFooter
            }
            .frame(width: width - GravitySpacing.space20 * 2, alignment: .leading)
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, topPadding)
            .padding(.bottom, GravitySpacing.space12)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
        .foregroundStyle(Color(hex: "#3C422E"))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sizzle, Drizzle, or Frizzle game")
    }

    private var gameBoard: some View {
        VStack(spacing: GravitySpacing.space12) {
            HStack {
                Text(isFinished ? "Game complete" : "Round \(roundIndex + 1) of \(rounds.count)")
                Spacer()
                Text("\(score) right")
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .opacity(0.64)

            if isFinished {
                finishedBoard
            } else {
                Image(systemName: round.symbol)
                    .font(.system(size: 40, weight: .light))
                    .frame(width: 82, height: 82)
                    .background(round.answer.color.opacity(0.28), in: Circle())

                Text(round.prompt)
                    .font(GravityFont.semiBold.fixedFont(size: 20))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 310)
                    .frame(height: 52, alignment: .top)
                    .id(roundIndex)
                    .transition(.opacity)

                HStack(spacing: GravitySpacing.space8) {
                    ForEach(GrazaOil.allCases) { oil in
                        Button { answer(oil) } label: {
                            VStack(spacing: 3) {
                                bottleGlyph(oil)
                                Text(oil.rawValue)
                                    .font(GravityFont.semiBold.fixedFont(size: 12))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 91)
                            .background(oil.color.opacity(selectedOil == oil ? 1 : 0.48), in: RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: GravityRadius.r12)
                                    .stroke(answerStroke(oil), lineWidth: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedOil != nil)
                        .accessibilityLabel("Choose \(oil.rawValue)")
                    }
                }

                Group {
                    if let selectedOil {
                        HStack(alignment: .top, spacing: GravitySpacing.space8) {
                            Image(systemName: selectedOil == round.answer ? "checkmark.circle.fill" : "arrow.turn.down.right")
                                .foregroundStyle(selectedOil == round.answer ? Color(hex: "#3D6B43") : Color(hex: "#A65031"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedOil == round.answer ? "You got it." : "\(round.answer.rawValue) is the move.")
                                    .font(GravityFont.semiBold.fixedFont(size: 13))
                                Text(round.reason)
                                    .font(GravityFont.regular.fixedFont(size: 11))
                                    .opacity(0.68)
                            }
                            Spacer()
                            Button { nextRound() } label: {
                                Text(roundIndex == rounds.count - 1 ? "Finish →" : "Next →")
                                    .font(GravityFont.semiBold.fixedFont(size: 12))
                                    .padding(.horizontal, GravitySpacing.space12)
                                    .frame(height: 38)
                                    .background(Color(hex: "#3C422E"), in: Capsule())
                                    .foregroundStyle(Color(hex: "#F6F5E8"))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(roundIndex == rounds.count - 1 ? "Finish game" : "Next question")
                        }
                    } else {
                        Text("Which bottle would you reach for?")
                            .font(GravityFont.medium.fixedFont(size: 12))
                            .opacity(0.58)
                    }
                }
                .frame(height: 55, alignment: .top)
            }

            Spacer(minLength: 0)
            HStack(spacing: GravitySpacing.space8) {
                ForEach(rounds.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= roundIndex ? Color(hex: "#3C422E") : Color(hex: "#3C422E").opacity(0.16))
                        .frame(width: index == roundIndex && !isFinished ? 22 : 7, height: 7)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(GravitySpacing.space16)
        .frame(maxWidth: .infinity)
        .frame(height: min(505, height * 0.59), alignment: .top)
        .background(Color(hex: "#E9E6CD"), in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
    }

    private var finishedBoard: some View {
        VStack(spacing: GravitySpacing.space12) {
            ZStack {
                ForEach(Array(GrazaOil.allCases.enumerated()), id: \.element.id) { index, oil in
                    bottleGlyph(oil)
                        .frame(width: 52, height: 100)
                        .offset(x: CGFloat(index - 1) * 54)
                }
            }
            .frame(height: 122)
            Text("Certified Graz-enius.")
                .font(GravityFont.semiBold.fixedFont(size: 24))
            Text("\(score) of \(rounds.count) right")
                .font(GravityFont.medium.fixedFont(size: 14))
                .opacity(0.66)
            Button { restart() } label: {
                Text("Play again ↻")
                    .font(GravityFont.semiBold.fixedFont(size: 13))
                    .padding(.horizontal, GravitySpacing.space16)
                    .frame(height: 42)
                    .background(Color(hex: "#3C422E"), in: Capsule())
                    .foregroundStyle(Color(hex: "#F6F5E8"))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play again")
        }
        .padding(.top, GravitySpacing.space12)
    }

    private func bottleGlyph(_ oil: GrazaOil) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(hex: "#3C422E"))
                .frame(width: 10, height: 14)
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(hex: "#3C422E"))
                .frame(width: 31, height: 53)
                .overlay {
                    Text(String(oil.rawValue.prefix(1)))
                        .font(GravityFont.bold.fixedFont(size: 14))
                        .foregroundStyle(oil.color)
                }
        }
    }

    private func answerStroke(_ oil: GrazaOil) -> Color {
        guard let selectedOil else { return .clear }
        if oil == round.answer { return Color(hex: "#3D6B43") }
        if oil == selectedOil { return Color(hex: "#A65031") }
        return .clear
    }

    private var productFooter: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.agentProduct(featuredOil.product))
        } label: {
            HStack(spacing: GravitySpacing.space12) {
                CachedAsyncImage(url: featuredOil.imageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        featuredOil.color.opacity(0.4)
                    }
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedOil == nil ? "Meet Sizzle" : "Shop \(featuredOil.rawValue)")
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                    Text(featuredOil.price)
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .opacity(0.62)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, GravitySpacing.space12)
            .frame(height: 62)
            .background(.white.opacity(0.50), in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(featuredOil.rawValue), \(featuredOil.price)")
    }

    private func answer(_ oil: GrazaOil) {
        guard selectedOil == nil else { return }
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            selectedOil = oil
            if oil == round.answer { score += 1 }
        }
    }

    private func nextRound() {
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            if roundIndex == rounds.count - 1 {
                isFinished = true
            } else {
                roundIndex += 1
                selectedOil = nil
            }
        }
    }

    private func restart() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            roundIndex = 0
            selectedOil = nil
            score = 0
            isFinished = false
        }
    }
}

#if false
private struct LegacyCotopaxiTrozoPackingCard: View {
    private enum EverydayItem: String, CaseIterable, Identifiable {
        case phone = "Phone"
        case keys = "Keys"
        case sunglasses = "Sunglasses"
        case notebook = "Notebook"
        case bottle = "Bottle"

        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .phone: "iphone"
            case .keys: "key.fill"
            case .sunglasses: "sunglasses"
            case .notebook: "book.closed.fill"
            case .bottle: "waterbottle.fill"
            }
        }
        var color: Color {
            switch self {
            case .phone: Color(hex: "#3B6FB6")
            case .keys: Color(hex: "#F2C14E")
            case .sunglasses: Color(hex: "#2B2B2B")
            case .notebook: Color(hex: "#E4552B")
            case .bottle: Color(hex: "#2E5E4E")
            }
        }
    }

    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var packed: Set<EverydayItem> = [.phone, .keys]

    private var product: AgentProduct {
        let image = URL(string: "https://cdn.shopify.com/s/files/1/0281/7544/files/1200x1200png-S26UTrozo8LShoulderBag-CadaDiaCream_F.png")
        return AgentProduct(
            id: "gid://shopify/p/5fxWUGSkA9f00CXZZ1Oh1v",
            title: "Trozo 8L Shoulder Bag - Cada Día",
            price: "$38.50",
            originalPrice: nil,
            imageURL: image,
            allImageURLs: [image].compactMap { $0 },
            rating: nil,
            ratingCount: nil,
            shopName: "Cotopaxi",
            shopLogoURL: nil,
            descriptors: [],
            labels: []
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "#F0EBE5")
            Circle()
                .fill(Color(hex: "#F2C14E").opacity(0.26))
                .frame(width: width * 1.1)
                .offset(x: width * 0.42, y: -height * 0.32)
            Circle()
                .fill(Color(hex: "#3B6FB6").opacity(0.14))
                .frame(width: width * 0.9)
                .offset(x: -width * 0.48, y: height * 0.4)

            VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                HStack(spacing: GravitySpacing.space8) {
                    Image(systemName: "mountain.2.fill")
                        .foregroundStyle(Color(hex: "#E4552B"))
                    Text("Cotopaxi")
                        .font(GravityFont.semiBold.fixedFont(size: 15))
                }
                .frame(height: 32)

                Text("Pack your everyday")
                    .feedCardTitleStyle()

                packingPreview
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                    Text("Add an item")
                        .font(GravityFont.medium.fixedFont(size: 13))
                        .foregroundStyle(.black.opacity(0.62))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: GravitySpacing.space8) {
                            ForEach(EverydayItem.allCases) { item in
                                Button { toggle(item) } label: {
                                    HStack(spacing: GravitySpacing.space8) {
                                        Image(systemName: item.symbol)
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(item.rawValue)
                                            .font(GravityFont.medium.fixedFont(size: 13))
                                    }
                                    .foregroundStyle(packed.contains(item) ? .white : .black)
                                    .padding(.horizontal, GravitySpacing.space12)
                                    .frame(height: 40)
                                    .background(packed.contains(item) ? item.color : .white.opacity(0.62), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(packed.contains(item) ? "Remove" : "Add") \(item.rawValue.lowercased())")
                                .accessibilityAddTraits(packed.contains(item) ? .isSelected : [])
                            }
                        }
                    }
                }

                Button {
                    HapticFeedback.light.fire()
                    coordinator.pushRoute(.agentProduct(product))
                } label: {
                    HStack {
                        Text("View the Trozo")
                            .font(GravityFont.semiBold.fixedFont(size: 15))
                        Spacer()
                        Text("$38.50")
                            .font(GravityFont.medium.fixedFont(size: 14))
                            .opacity(0.72)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, GravitySpacing.space20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(Color(hex: "#2E5E4E"), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(width: width - GravitySpacing.space20 * 2, alignment: .leading)
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, topPadding)
            .padding(.bottom, GravitySpacing.space16)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pack the Cotopaxi Trozo bag")
    }

    private var packingPreview: some View {
        ZStack(alignment: .bottom) {
            BundleImage(name: "cotopaxi-trozo-interior", extension: "jpg", fills: true)
            HStack(spacing: GravitySpacing.space8) {
                if packed.isEmpty {
                    Text("Your Trozo is empty")
                        .font(GravityFont.medium.fixedFont(size: 13))
                        .foregroundStyle(.white)
                } else {
                    ForEach(EverydayItem.allCases.filter(packed.contains)) { item in
                        VStack(spacing: GravitySpacing.space4) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .foregroundStyle(.white)
                                .background(item.color, in: Circle())
                            Text(item.rawValue)
                                .font(GravityFont.medium.fixedFont(size: 10))
                                .foregroundStyle(.white)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, GravitySpacing.space12)
            .frame(minHeight: 62)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.54))
        }
        .frame(maxWidth: .infinity)
        .frame(height: min(390, height * 0.43))
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        .accessibilityLabel("\(packed.count) items packed")
    }

    private func toggle(_ item: EverydayItem) {
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            if packed.contains(item) { packed.remove(item) }
            else { packed.insert(item) }
        }
    }
}

#endif

private enum TrozoFind: Int, CaseIterable, Identifiable {
    case cable, sunscreen, notebook

    var id: Int { rawValue }
    var asset: (String, String) {
        switch self {
        case .cable: ("cotopaxi-pop-cable", "webp")
        case .sunscreen: ("cotopaxi-daily-spf", "png")
        case .notebook: ("cotopaxi-layflat-notebook", "png")
        }
    }
    var merchant: String {
        switch self {
        case .cable: "Native Union"
        case .sunscreen: "Beauty of Joseon"
        case .notebook: "Ugmonk"
        }
    }
    var shortTitle: String {
        switch self {
        case .cable: "Pop Cable"
        case .sunscreen: "Daily SPF"
        case .notebook: "Layflat notebook"
        }
    }
    var product: AgentProduct {
        let details: (String, String, String, String) = switch self {
        case .cable:
            ("8029318709387", "POP Cable", "$19.99", "https://cdn.shopify.com/s/files/1/0066/9050/4822/files/PopCable-AlarmRed.png?v=1766482350")
        case .sunscreen:
            ("14990688223604", "Dayscreen Moisturizer SPF 30", "$18.00", "https://cdn.shopify.com/s/files/1/0558/4135/7989/files/03_0626__-_US.jpg?v=1782713443")
        case .notebook:
            ("8549075419286", "Layflat Notebook (Yellow)", "$18.00", "https://cdn.shopify.com/s/files/1/0167/4484/files/layflat-yellow-1.jpg?v=1763657250")
        }
        let image = URL(string: details.3)
        return AgentProduct(
            id: details.0,
            title: details.1,
            price: details.2,
            originalPrice: nil,
            imageURL: image,
            allImageURLs: [image].compactMap { $0 },
            rating: nil,
            ratingCount: nil,
            shopName: merchant,
            shopLogoURL: nil,
            descriptors: [],
            labels: []
        )
    }
}

private struct CotopaxiTrozoPackingCard: View {
    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var packed: Set<TrozoFind> = []
    @State private var isPeeking = false

    private var trozo: AgentProduct {
        let image = URL(string: "https://cdn.shopify.com/s/files/1/0281/7544/files/1200x1200png-S26UTrozo8LShoulderBag-CadaDiaCream_F.png")
        return AgentProduct(
            id: "gid://shopify/p/5fxWUGSkA9f00CXZZ1Oh1v",
            title: "Trozo 8L Shoulder Bag - Cada Día",
            price: "$38.50",
            originalPrice: nil,
            imageURL: image,
            allImageURLs: [image].compactMap { $0 },
            rating: nil,
            ratingCount: nil,
            shopName: "Cotopaxi",
            shopLogoURL: nil,
            descriptors: [],
            labels: []
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "#F5C458")
            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                BundleImage(name: "cotopaxi-wordmark", extension: "png")
                    .frame(width: 104, height: 30, alignment: .leading)

                Text("A little room for your day.")
                    .font(GravityFont.bold.fixedFont(size: 28))
                    .tracking(-0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Text("Trozo 8L + finds from three other makers")
                    .font(GravityFont.medium.fixedFont(size: 14))
                    .foregroundStyle(Color(hex: "#173F45").opacity(0.78))

                bagStage
                    .padding(.top, GravitySpacing.space4)

                HStack(alignment: .firstTextBaseline) {
                    Text("Make room for these.")
                        .font(GravityFont.semiBold.fixedFont(size: 16))
                    Spacer()
                    Text("Tap to pack ↓")
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .opacity(0.65)
                }
                .foregroundStyle(Color(hex: "#173F45"))

                HStack(alignment: .top, spacing: GravitySpacing.space8) {
                    ForEach(TrozoFind.allCases) { find in
                        findColumn(find)
                    }
                }

                Text("Illustrative fit · product sizes and usable bag space vary.")
                    .font(GravityFont.regular.fixedFont(size: 10))
                    .foregroundStyle(Color(hex: "#173F45").opacity(0.6))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
                productFooter
            }
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, topPadding)
            .padding(.bottom, GravitySpacing.space12)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
        .foregroundStyle(Color(hex: "#173F45"))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pack the Cotopaxi Trozo bag")
    }

    private var bagStage: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: "#F7DB8F")

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trozo / 8L")
                    Text("15 × 10 × 3 in")
                }
                .font(GravityFont.medium.fixedFont(size: 10))
                .tracking(0.6)
                .position(x: 57, y: 33)
                .zIndex(5)

                Ellipse()
                    .fill(Color(hex: "#313747").opacity(isPeeking ? 0.28 : 0))
                    .frame(width: proxy.size.width * 0.57, height: proxy.size.height * 0.18)
                    .position(x: proxy.size.width * 0.53, y: proxy.size.height * 0.60)
                    .zIndex(1)

                BundleImage(name: "cotopaxi-trozo-product", extension: "webp")
                    .padding(.horizontal, 34)
                    .padding(.top, -46)
                    .opacity(isPeeking ? 0.50 : 1)
                    .zIndex(2)

                ForEach(TrozoFind.allCases) { find in
                    if packed.contains(find) {
                        BundleImage(name: find.asset.0, extension: find.asset.1)
                            .frame(width: find == .sunscreen ? 35 : 58, height: find == .notebook ? 66 : 58)
                            .rotationEffect(.degrees(find == .notebook ? 8 : find == .cable ? -8 : 0))
                            .position(packedPosition(find, in: proxy.size))
                            .transition(.offset(y: -90).combined(with: .opacity))
                            .zIndex(3)
                    }
                }

                BundleImage(name: "cotopaxi-trozo-product", extension: "webp")
                    .padding(.horizontal, 34)
                    .padding(.top, -46)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: proxy.size.height * 0.42)
                    }
                    .opacity(isPeeking ? 0.42 : 1)
                    .zIndex(4)

                HStack {
                    Text(packed.isEmpty ? "Your day bag, unpacked" : "\(packed.count) of 3 finds packed")
                        .font(GravityFont.medium.fixedFont(size: 12))
                    Spacer()
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            isPeeking.toggle()
                        }
                    } label: {
                        Text(isPeeking ? "Close cutaway" : "Peek inside ↗")
                            .font(GravityFont.semiBold.fixedFont(size: 13))
                            .padding(.horizontal, GravitySpacing.space12)
                            .frame(height: 42)
                            .background(.white.opacity(0.66), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, GravitySpacing.space12)
                .padding(.bottom, GravitySpacing.space8)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .zIndex(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        }
        .frame(height: min(285, height * 0.34))
        .accessibilityLabel(packed.isEmpty ? "Trozo bag is unpacked" : "\(packed.count) of 3 finds packed")
    }

    private func findColumn(_ find: TrozoFind) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space4) {
            Button { toggle(find) } label: {
                VStack(spacing: 2) {
                    BundleImage(name: find.asset.0, extension: find.asset.1)
                        .frame(height: 67)
                        .padding(.top, 5)
                    Text(packed.contains(find) ? "Packed ✓" : "+ Pack")
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .frame(height: 22)
                }
                .frame(maxWidth: .infinity)
                .background(.white.opacity(packed.contains(find) ? 0.32 : 0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: GravityRadius.r12)
                        .stroke(Color(hex: "#173F45").opacity(0.13), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(packed.contains(find) ? "Unpack" : "Pack") \(find.shortTitle)")
            .accessibilityAddTraits(packed.contains(find) ? .isSelected : [])

            Button {
                coordinator.pushRoute(.agentProduct(find.product))
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(find.merchant)
                        .font(GravityFont.regular.fixedFont(size: 10))
                        .opacity(0.68)
                    Text("\(find.shortTitle) ↗")
                        .font(GravityFont.medium.fixedFont(size: 11))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View \(find.shortTitle) from \(find.merchant)")
        }
        .frame(maxWidth: .infinity)
    }

    private var productFooter: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.agentProduct(trozo))
        } label: {
            HStack(spacing: GravitySpacing.space12) {
                BundleImage(name: "cotopaxi-trozo-product", extension: "webp")
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Trozo 8L Shoulder Bag - Cada Día")
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                        .lineLimit(1)
                    Text("$38.50")
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .opacity(0.65)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, GravitySpacing.space12)
            .frame(height: 62)
            .background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View the Trozo, $38.50")
    }

    private func packedPosition(_ find: TrozoFind, in size: CGSize) -> CGPoint {
        switch find {
        case .cable: CGPoint(x: size.width * 0.38, y: size.height * 0.57)
        case .sunscreen: CGPoint(x: size.width * 0.53, y: size.height * 0.55)
        case .notebook: CGPoint(x: size.width * 0.67, y: size.height * 0.53)
        }
    }

    private func toggle(_ find: TrozoFind) {
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.78)) {
            if packed.contains(find) {
                packed.remove(find)
            } else {
                packed.insert(find)
                isPeeking = true
            }
        }
    }
}

private struct TaylorStitchQuincyCard: View {
    private struct LookProduct: Identifiable {
        let id: String
        let title: String
        let shortTitle: String
        let merchant: String
        let price: String
        let imageURL: URL

        var agentProduct: AgentProduct {
            AgentProduct(
                id: id,
                title: title,
                price: price,
                originalPrice: nil,
                imageURL: imageURL,
                allImageURLs: [imageURL],
                rating: nil,
                ratingCount: nil,
                shopName: merchant,
                shopLogoURL: nil,
                descriptors: [],
                labels: []
            )
        }
    }

    private struct Look {
        let title: String
        let note: String
        let products: [LookProduct]
    }

    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lookIndex = 0

    private let quincyModelURL = URL(string: "https://cdn.shopify.com/s/files/1/0070/1922/files/instock_m_q326_quincy-shirt-vintage-white-slub_portrait_002.jpg?v=1785181122")!
    private let quincyImageURL = URL(string: "https://cdn.shopify.com/s/files/1/0070/1922/files/instock_m_q326_quincy-shirt-vintage-white-slub_portrait_001.jpg?v=1785181122")!

    private var trozo: LookProduct {
        LookProduct(
            id: "7956765048893",
            title: "Trozo 8L Shoulder Bag - Cada Día",
            shortTitle: "Carry it all",
            merchant: "Cotopaxi",
            price: "$38.50",
            imageURL: URL(string: "https://cdn.shopify.com/s/files/1/0281/7544/files/1200x1200png-S26UTrozo8LShoulderBag-CadaDiaMoonbeam_F.png?v=1769436427")!
        )
    }
    private var sneaker: LookProduct {
        LookProduct(
            id: "8286750048384",
            title: "Salomon XT-EVO - Black / Black / Asphalt",
            shortTitle: "Finish the look",
            merchant: "Kith",
            price: "$200",
            imageURL: URL(string: "https://cdn.shopify.com/s/files/1/0094/2252/files/L45404200_0_GHO_XT-EVO_Black_Black_Asphalt.jpg?v=1788543100")!
        )
    }
    private var jacket: LookProduct {
        LookProduct(
            id: "7645558800461",
            title: "The Ryder Jacket in Rinsed Black Organic Selvedge",
            shortTitle: "The other layer",
            merchant: "Taylor Stitch",
            price: "$238",
            imageURL: URL(string: "https://cdn.shopify.com/s/files/1/0070/1922/files/Q326_the-ryder-jacket-rinsed-black-organic-selvedge_pdp_compressed_01.jpg?v=1787843851")!
        )
    }
    private var jeans: LookProduct {
        LookProduct(
            id: "7645560012877",
            title: "The Straight Jean in Rinsed Black Organic Selvedge",
            shortTitle: "Dark denim",
            merchant: "Taylor Stitch",
            price: "$188",
            imageURL: URL(string: "https://cdn.shopify.com/s/files/1/0070/1922/files/Q326_the-straight-jean-rinsed-black-organic-selvedge_pdp_compressed_01.jpg?v=1787844615")!
        )
    }

    private var looks: [Look] {
        [
            Look(title: "Coffee, then wherever.", note: "An easy shirt. Hands free. Out the door.", products: [trozo, sneaker]),
            Look(title: "A little more put together.", note: "Add a structured jacket and darker denim.", products: [jacket, jeans]),
            Look(title: "Stay for dinner.", note: "A crisp layer, dark denim, and a relaxed finish.", products: [jeans, sneaker])
        ]
    }

    private var quincy: AgentProduct {
        AgentProduct(
            id: "7645557915725",
            title: "The Quincy Shirt in Vintage White Slub",
            price: "$138",
            originalPrice: nil,
            imageURL: quincyImageURL,
            allImageURLs: [quincyImageURL, quincyModelURL],
            rating: nil,
            ratingCount: nil,
            shopName: "Taylor Stitch",
            shopLogoURL: nil,
            descriptors: [],
            labels: []
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "#ECEAE3")

            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                BundleImage(name: "taylor-stitch-wordmark", extension: "png")
                    .frame(width: 138, height: 27, alignment: .leading)
                Text("One shirt. Your whole day.")
                    .font(GravityFont.bold.fixedFont(size: 28))
                    .tracking(-0.7)
                    .lineLimit(1)
                Text("The Quincy / Vintage White Slub")
                    .font(GravityFont.medium.fixedFont(size: 14))
                    .foregroundStyle(Color(hex: "#30382E").opacity(0.66))

                lookStage
                    .padding(.top, GravitySpacing.space4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(looks[lookIndex].title)
                        .font(GravityFont.semiBold.fixedFont(size: 18))
                    Text(looks[lookIndex].note)
                        .font(GravityFont.regular.fixedFont(size: 13))
                        .foregroundStyle(Color(hex: "#30382E").opacity(0.70))
                }
                .id(lookIndex)
                .transition(.opacity)

                pageTurner
                Text("Styling ideas · individual products sold separately")
                    .font(GravityFont.regular.fixedFont(size: 10))
                    .foregroundStyle(Color(hex: "#30382E").opacity(0.58))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
                productFooter
            }
            .frame(width: width - GravitySpacing.space20 * 2, alignment: .leading)
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, topPadding)
            .padding(.bottom, GravitySpacing.space12)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
        .foregroundStyle(Color(hex: "#30382E"))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Style the Taylor Stitch Quincy shirt")
    }

    private var lookStage: some View {
        HStack(spacing: GravitySpacing.space8) {
            CachedAsyncImage(url: quincyModelURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Color(hex: "#D7D4CB")
                }
            }
            .frame(width: width - GravitySpacing.space20 * 2 - GravitySpacing.space8 - 135)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
            .overlay(alignment: .topLeading) {
                Text("The constant")
                    .font(GravityFont.semiBold.fixedFont(size: 10))
                    .padding(.horizontal, 9)
                    .frame(height: 27)
                    .background(.white.opacity(0.76), in: Capsule())
                    .padding(GravitySpacing.space8)
            }

            VStack(spacing: GravitySpacing.space8) {
                Text("Add to the look")
                    .font(GravityFont.medium.fixedFont(size: 10))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(0.62)

                ForEach(looks[lookIndex].products) { product in
                    Button {
                        coordinator.pushRoute(.agentProduct(product.agentProduct))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            CachedAsyncImage(url: product.imageURL) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFit()
                                } else {
                                    Color.white.opacity(0.35)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            Text(product.merchant)
                                .font(GravityFont.regular.fixedFont(size: 9))
                                .opacity(0.62)
                            Text("\(product.shortTitle) ↗")
                                .font(GravityFont.semiBold.fixedFont(size: 10))
                                .lineLimit(1)
                        }
                        .padding(GravitySpacing.space8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View \(product.title) from \(product.merchant)")
                }
            }
            .frame(width: 135)
            .id(lookIndex)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
        .frame(height: min(360, height * 0.42))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: lookIndex)
    }

    private var pageTurner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("The Quincy lookbook")
                    .font(GravityFont.medium.fixedFont(size: 10))
                    .opacity(0.60)
                Text("0\(lookIndex + 1)  /  03")
                    .font(GravityFont.semiBold.fixedFont(size: 15))
            }
            Spacer()
            Button { previousLook() } label: {
                Image(systemName: "arrow.left").frame(width: 42, height: 42)
            }
            .accessibilityLabel("Previous look")
            Button { nextLook() } label: {
                HStack(spacing: 5) {
                    Text("Next look")
                    Image(systemName: "arrow.right")
                }
                .font(GravityFont.semiBold.fixedFont(size: 12))
                .padding(.horizontal, GravitySpacing.space12)
                .frame(height: 42)
                .background(Color(hex: "#30382E"), in: Capsule())
                .foregroundStyle(Color(hex: "#ECEAE3"))
            }
            .accessibilityLabel("Next look")
        }
        .buttonStyle(.plain)
    }

    private var productFooter: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.agentProduct(quincy))
        } label: {
            HStack(spacing: GravitySpacing.space12) {
                CachedAsyncImage(url: quincyImageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Color.white.opacity(0.35)
                    }
                }
                .frame(width: 48, height: 48)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("The Quincy Shirt in Vintage White Slub")
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                        .lineLimit(1)
                    Text("$138")
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .opacity(0.62)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, GravitySpacing.space12)
            .frame(height: 62)
            .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View the Quincy Shirt, $138")
    }

    private func nextLook() {
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) {
            lookIndex = (lookIndex + 1) % looks.count
        }
    }

    private func previousLook() {
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) {
            lookIndex = (lookIndex + looks.count - 1) % looks.count
        }
    }
}

private struct DSDurgaScentCard: View {
    private enum ScentNote: Int, CaseIterable, Identifiable {
        case rain, eucalyptus, wood

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .rain: "Coastal rain"
            case .eucalyptus: "Eucalyptus"
            case .wood: "Wet wood"
            }
        }
        var chapter: String {
            switch self {
            case .rain: "Top notes"
            case .eucalyptus: "Heart notes"
            case .wood: "Base notes"
            }
        }
        var title: String {
            switch self {
            case .rain: "The air, just after."
            case .eucalyptus: "Through the grove."
            case .wood: "The trail underfoot."
            }
        }
        var notes: String {
            switch self {
            case .rain: "Coastal rain · Young eucalyptus shoots"
            case .eucalyptus: "Magnolia · Pacific spray"
            case .wood: "Eucalyptus leaf · Wet wood"
            }
        }
        var copy: String {
            switch self {
            case .rain: "Cool, green, and open to the Pacific."
            case .eucalyptus: "Soft flowers caught in salt air."
            case .wood: "The scent settles into damp wood and leaves."
            }
        }
    }

    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedNote: ScentNote = .rain

    private let productImageURL = URL(string: "https://cdn.shopify.com/s/files/1/0379/7669/files/BSAR_Lotion_0d911072-f6f3-4c16-9a26-2665eba7ca02.jpg?v=1785789187")!

    private var product: AgentProduct {
        AgentProduct(
            id: "9694949212451",
            title: "Big Sur After Rain",
            price: "$65",
            originalPrice: nil,
            imageURL: productImageURL,
            allImageURLs: [productImageURL],
            rating: nil,
            ratingCount: nil,
            shopName: "D.S. & Durga",
            shopLogoURL: nil,
            descriptors: [],
            labels: []
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "#E8ECE7")

            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                BundleImage(name: "dsdurga-wordmark", extension: "png")
                    .frame(width: 143, height: 28, alignment: .leading)
                Text("Big Sur, after the rain.")
                    .font(GravityFont.bold.fixedFont(size: 28))
                    .tracking(-0.7)
                    .lineLimit(1)
                Text("Explore the scent in the hand lotion.")
                    .font(GravityFont.medium.fixedFont(size: 14))
                    .foregroundStyle(Color(hex: "#253C32").opacity(0.66))

                scentLandscape
                    .padding(.top, GravitySpacing.space4)

                scentReading
                Text("Touch a place in the landscape to explore its notes.")
                    .font(GravityFont.regular.fixedFont(size: 10))
                    .foregroundStyle(Color(hex: "#253C32").opacity(0.60))

                Spacer(minLength: 0)
                productFooter
            }
            .frame(width: width - GravitySpacing.space20 * 2, alignment: .leading)
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, topPadding)
            .padding(.bottom, GravitySpacing.space12)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
        .foregroundStyle(Color(hex: "#253C32"))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Explore Big Sur After Rain by scent note")
    }

    private var scentLandscape: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: selectedNote == .wood
                        ? [Color(hex: "#D8DDD4"), Color(hex: "#87978C")]
                        : [Color(hex: "#E6EDE7"), Color(hex: "#7C9896")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.42))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.35))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                    path.addLine(to: CGPoint(x: 0, y: proxy.size.height))
                    path.closeSubpath()
                }
                .fill(Color(hex: "#88A4A2"))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.48))
                    path.addCurve(
                        to: CGPoint(x: proxy.size.width * 0.78, y: proxy.size.height),
                        control1: CGPoint(x: proxy.size.width * 0.25, y: proxy.size.height * 0.54),
                        control2: CGPoint(x: proxy.size.width * 0.45, y: proxy.size.height * 0.82)
                    )
                    path.addLine(to: CGPoint(x: 0, y: proxy.size.height))
                    path.closeSubpath()
                }
                .fill(Color(hex: "#52695B"))

                ForEach(0..<13, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(selectedNote == .rain ? 0.22 : 0.08))
                        .frame(width: 1, height: 65)
                        .rotationEffect(.degrees(18))
                        .position(
                            x: CGFloat(index) * proxy.size.width / 12,
                            y: 34 + CGFloat((index * 37) % 160)
                        )
                }

                Rectangle()
                    .fill(Color(hex: "#364B3E"))
                    .frame(width: 4, height: proxy.size.height * 0.64)
                    .rotationEffect(.degrees(-25))
                    .position(x: proxy.size.width * 0.90, y: proxy.size.height * 0.76)
                    .opacity(selectedNote == .eucalyptus ? 1 : 0.72)

                ForEach(0..<4, id: \.self) { index in
                    Ellipse()
                        .fill(Color(hex: "#5D765F"))
                        .frame(width: 62, height: 25)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -28 : 62))
                        .position(
                            x: proxy.size.width * (index.isMultiple(of: 2) ? 0.83 : 0.95),
                            y: proxy.size.height * (0.38 + CGFloat(index) * 0.14)
                        )
                        .opacity(selectedNote == .eucalyptus ? 1 : 0.76)
                }

                BundleImage(name: "dsdurga-big-sur-after-rain", extension: "webp")
                    .frame(width: 130, height: proxy.size.height * 0.68)
                    .blendMode(.multiply)
                    .position(x: proxy.size.width * 0.57, y: proxy.size.height * 0.69)
                    .shadow(color: Color(hex: "#172C26").opacity(0.16), radius: 8, y: 7)

                VStack(alignment: .trailing, spacing: 1) {
                    Text("36.2704° N")
                    Text("121.8081° W")
                }
                .font(.system(size: 9, design: .monospaced))
                .tracking(0.5)
                .position(x: proxy.size.width - 53, y: 25)

                noteButton(.rain)
                    .position(x: 83, y: 65)
                noteButton(.eucalyptus)
                    .position(x: proxy.size.width - 69, y: proxy.size.height * 0.48)
                noteButton(.wood)
                    .position(x: 70, y: proxy.size.height - 53)
            }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        }
        .frame(height: min(390, height * 0.45))
    }

    private func noteButton(_ note: ScentNote) -> some View {
        Button { select(note) } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(selectedNote == note ? Color(hex: "#253C32") : .clear)
                    .overlay { Circle().stroke(Color(hex: "#253C32"), lineWidth: 1) }
                    .frame(width: 7, height: 7)
                Text(note.label)
                    .font(GravityFont.medium.fixedFont(size: 11))
            }
            .padding(.horizontal, 11)
            .frame(height: 39)
            .background(.white.opacity(0.82), in: Capsule())
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Explore \(note.label)")
        .accessibilityAddTraits(selectedNote == note ? .isSelected : [])
    }

    private var scentReading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("0\(selectedNote.rawValue + 1) / \(selectedNote.chapter)")
                .font(GravityFont.medium.fixedFont(size: 10))
                .tracking(0.5)
                .opacity(0.60)
            Text(selectedNote.title)
                .font(GravityFont.semiBold.fixedFont(size: 19))
            Text(selectedNote.notes)
                .font(GravityFont.semiBold.fixedFont(size: 12))
            Text(selectedNote.copy)
                .font(GravityFont.regular.fixedFont(size: 12))
                .opacity(0.68)
        }
        .frame(height: 90, alignment: .topLeading)
        .id(selectedNote)
        .transition(.opacity)
    }

    private var productFooter: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.agentProduct(product))
        } label: {
            HStack(spacing: GravitySpacing.space12) {
                BundleImage(name: "dsdurga-big-sur-after-rain", extension: "webp")
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Big Sur After Rain")
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                    Text("$65")
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .opacity(0.62)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, GravitySpacing.space12)
            .frame(height: 62)
            .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View Big Sur After Rain, $65")
    }

    private func select(_ note: ScentNote) {
        guard note != selectedNote else { return }
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
            selectedNote = note
        }
    }
}

private struct FellowCoffeeRitualCard: View {
    private enum Drink: Int, CaseIterable, Identifiable {
        case espresso, longBlack, milkCoffee

        var id: Int { rawValue }
        var name: String {
            switch self {
            case .espresso: "Espresso"
            case .longBlack: "Long black"
            case .milkCoffee: "Milk coffee"
            }
        }
        var edition: String {
            switch self {
            case .espresso: "The short one"
            case .longBlack: "A little longer"
            case .milkCoffee: "Something softer"
            }
        }
        var liquid: Color {
            switch self {
            case .espresso: Color(hex: "#43271B")
            case .longBlack: Color(hex: "#2E201A")
            case .milkCoffee: Color(hex: "#B98C68")
            }
        }
    }

    private enum RitualStep: Int, CaseIterable, Identifiable {
        case grind, brew, serve

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .grind: "Grind"
            case .brew: "Brew"
            case .serve: "Serve"
            }
        }
        var title: String {
            switch self {
            case .grind: "Start with the grind."
            case .brew: "Find your espresso."
            case .serve: "Make it your morning."
            }
        }
        var copy: String {
            switch self {
            case .grind: "Opus 2 makes grind size part of your morning ritual."
            case .brew: "Series 1 brings guided brewing to the center of your coffee bar."
            case .serve: "Pirch glasses bring the finished espresso into focus."
            }
        }
        var asset: String {
            switch self {
            case .grind: "fellow-opus-2"
            case .brew: "fellow-series-1"
            case .serve: "fellow-pirch-glasses"
            }
        }
        var details: (id: String, title: String, price: String, url: String) {
            switch self {
            case .grind:
                ("8426192404580", "Opus 2 Conical Burr Grinder", "$199.95", "https://cdn.shopify.com/s/files/1/0057/6235/1219/files/PDP_Opus2_Black_Black.png?v=1771549610")
            case .brew:
                ("8041603498084", "Espresso Series 1", "$1,399.95", "https://cdn.shopify.com/s/files/1/0057/6235/1219/files/Web_PDP_Series1_Black_1.png?v=1773352064")
            case .serve:
                ("8203553013860", "Pirch Espresso Glasses", "$38.20", "https://cdn.shopify.com/s/files/1/0057/6235/1219/files/Web_PDP_PirchEspressoGlasses_Smoke_1-Espresso.png?v=1773358795")
            }
        }
        var product: AgentProduct {
            let info = details
            let image = URL(string: info.url)
            return AgentProduct(
                id: info.id,
                title: info.title,
                price: info.price,
                originalPrice: nil,
                imageURL: image,
                allImageURLs: [image].compactMap { $0 },
                rating: nil,
                ratingCount: nil,
                shopName: "Fellow",
                shopLogoURL: nil,
                descriptors: [],
                labels: []
            )
        }
    }

    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drink: Drink = .espresso
    @State private var step: RitualStep = .grind

    var body: some View {
        ZStack {
            Color(hex: "#E9E7E2")

            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                BundleImage(name: "fellow-wordmark", extension: "png")
                    .frame(width: 113, height: 27, alignment: .leading)
                Text("How do you take it?")
                    .font(GravityFont.bold.fixedFont(size: 28))
                    .tracking(-0.7)
                    .lineLimit(1)
                Text("Your drink. Your morning ritual.")
                    .font(GravityFont.medium.fixedFont(size: 14))
                    .foregroundStyle(Color(hex: "#262827").opacity(0.66))

                coffeeStage
                    .padding(.top, GravitySpacing.space4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(GravityFont.semiBold.fixedFont(size: 18))
                    Text(stepCopy)
                        .font(GravityFont.regular.fixedFont(size: 13))
                        .foregroundStyle(Color(hex: "#262827").opacity(0.70))
                        .lineLimit(2)
                }
                .frame(height: 59, alignment: .topLeading)
                .id("\(step.rawValue)-\(drink.rawValue)")
                .transition(.opacity)

                ritualProgress
                Text("Equipment sold separately · drink illustration")
                    .font(GravityFont.regular.fixedFont(size: 10))
                    .foregroundStyle(Color(hex: "#262827").opacity(0.56))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
                productFooter
            }
            .frame(width: width - GravitySpacing.space20 * 2, alignment: .leading)
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, topPadding)
            .padding(.bottom, GravitySpacing.space12)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
        .foregroundStyle(Color(hex: "#262827"))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Build a Fellow coffee ritual")
    }

    private var coffeeStage: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#D5D2CB"), Color(hex: "#C4C0B8")],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Text(drink.edition)
                    .font(GravityFont.medium.fixedFont(size: 10))
                    .tracking(0.8)
                    .position(x: 68, y: 25)

                BundleImage(name: step.asset, extension: "webp")
                    .frame(width: proxy.size.width * 0.57, height: proxy.size.height * 0.78)
                    .position(x: proxy.size.width * 0.35, y: proxy.size.height * 0.51)
                    .id(step)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))

                Button { nextDrink() } label: {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "#262827"), lineWidth: 7)
                            .frame(width: 55, height: 55)
                            .offset(x: 33)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "#F3F0E9"))
                            .frame(width: 91, height: 82)
                        Ellipse()
                            .fill(Color(hex: "#D8D3C8"))
                            .frame(width: 74, height: 22)
                            .offset(y: -35)
                        Ellipse()
                            .fill(drink.liquid)
                            .frame(width: 63, height: 14)
                            .offset(y: -34)
                        Text("\(drink.name) ↻")
                            .font(GravityFont.semiBold.fixedFont(size: 11))
                            .offset(y: 59)
                    }
                    .frame(width: 130, height: 145)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: proxy.size.width * 0.77, y: proxy.size.height * 0.62)
                .accessibilityLabel("Change drink, currently \(drink.name)")

                VStack(alignment: .leading, spacing: 1) {
                    Text("0\(step.rawValue + 1)")
                        .font(GravityFont.semiBold.fixedFont(size: 28))
                    Text("Your coffee bar")
                        .font(GravityFont.medium.fixedFont(size: 9))
                        .tracking(0.7)
                }
                .position(x: proxy.size.width - 65, y: 48)
            }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        }
        .frame(height: min(370, height * 0.43))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: step)
    }

    private var ritualProgress: some View {
        HStack(spacing: GravitySpacing.space8) {
            HStack(spacing: 0) {
                ForEach(RitualStep.allCases) { option in
                    Button { select(option) } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(option.rawValue <= step.rawValue ? Color(hex: "#262827") : Color(hex: "#262827").opacity(0.18))
                                .frame(width: 7, height: 7)
                            Text(option.label)
                                .font(GravityFont.medium.fixedFont(size: 10))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go to \(option.label.lowercased())")
                    .accessibilityAddTraits(step == option ? .isSelected : [])
                }
            }

            Button { nextStep() } label: {
                Text(step == .serve ? "Start again ↻" : "Next: \(RitualStep(rawValue: step.rawValue + 1)!.label.lowercased()) →")
                    .font(GravityFont.semiBold.fixedFont(size: 11))
                    .padding(.horizontal, GravitySpacing.space12)
                    .frame(height: 42)
                    .background(Color(hex: "#262827"), in: Capsule())
                    .foregroundStyle(Color(hex: "#E9E7E2"))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(step == .serve ? "Start ritual again" : "Next ritual step")
        }
    }

    private var productFooter: some View {
        let info = step.details
        return Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.agentProduct(step.product))
        } label: {
            HStack(spacing: GravitySpacing.space12) {
                BundleImage(name: step.asset, extension: "webp")
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title)
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                        .lineLimit(1)
                    Text(info.price)
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .opacity(0.62)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, GravitySpacing.space12)
            .frame(height: 62)
            .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(info.title), \(info.price)")
    }

    private var stepCopy: String {
        guard step == .serve else { return step.copy }
        return switch drink {
        case .espresso: "Pirch glasses bring the finished espresso into focus."
        case .longBlack: "Serve espresso with hot water for a longer cup."
        case .milkCoffee: "Add steamed milk for a softer morning coffee."
        }
    }

    private func nextDrink() {
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            drink = Drink(rawValue: (drink.rawValue + 1) % Drink.allCases.count)!
        }
    }

    private func select(_ selection: RitualStep) {
        guard selection != step else { return }
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) { step = selection }
    }

    private func nextStep() {
        select(RitualStep(rawValue: (step.rawValue + 1) % RitualStep.allCases.count)!)
    }
}

private struct UgmonkAnalogFocusCard: View {
    private struct FocusTask: Identifiable {
        let id: Int
        var title: String
        var isDone: Bool
    }

    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tasks = [
        FocusTask(id: 0, title: "Review the next feed card.", isDone: false),
        FocusTask(id: 1, title: "Send the Shop prototype.", isDone: false),
        FocusTask(id: 2, title: "Take a real break.", isDone: false)
    ]
    @State private var draft = ""
    @State private var isAnalog = false
    @State private var nextID = 3

    private let productImageURL = URL(string: "https://cdn.shopify.com/s/files/1/0167/4484/files/weekly-walnut-dark_edd9132c-231c-4763-ae54-43c39cb43cf9.jpg?v=1747334408")!

    private var completedCount: Int { tasks.filter(\.isDone).count }
    private var product: AgentProduct {
        AgentProduct(
            id: "7802067779734",
            title: "Analog Weekly Planning Kit (Walnut)",
            price: "$79",
            originalPrice: nil,
            imageURL: productImageURL,
            allImageURLs: [productImageURL],
            rating: nil,
            ratingCount: nil,
            shopName: "Ugmonk",
            shopLogoURL: nil,
            descriptors: [],
            labels: []
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "#F0ECE2")

            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                HStack {
                    Text("Ugmonk")
                        .font(GravityFont.semiBold.fixedFont(size: 18))
                    Spacer()
                    Text("Less on your screen. More on your mind.")
                        .font(GravityFont.medium.fixedFont(size: 8))
                        .tracking(1.2)
                        .opacity(0.58)
                }

                VStack(alignment: .leading, spacing: -7) {
                    Text("One thing")
                        .font(GravityFont.regular.fixedFont(size: 43))
                        .tracking(-1.5)
                    Text("at a time.")
                        .font(.system(size: 43, weight: .semibold, design: .serif).italic())
                        .tracking(-1.4)
                }
                .foregroundStyle(Color(hex: "#3D493C"))

                ZStack {
                    if isAnalog {
                        analogStage.transition(.asymmetric(insertion: .scale(scale: 0.94).combined(with: .opacity), removal: .opacity))
                    } else {
                        liveList.transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.96).combined(with: .opacity)))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: min(365, height * 0.43))
                .padding(.top, GravitySpacing.space4)

                Button { toggleAnalog() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isAnalog ? "Keep shaping the list" : "Ready to step away?")
                                .font(GravityFont.regular.fixedFont(size: 11))
                                .opacity(0.60)
                            HStack(spacing: 5) {
                                Text(isAnalog ? "Back to the live list" : "Make it analog")
                                    .font(.system(size: 21, weight: .semibold, design: .serif).italic())
                                Image(systemName: isAnalog ? "arrow.uturn.backward" : "arrow.down.right")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                        Spacer()
                        Text("\(completedCount) / \(tasks.count)")
                            .font(.system(size: 12, design: .monospaced))
                            .opacity(0.60)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isAnalog ? "Back to the live list" : "Make it analog")

                Spacer(minLength: 0)
                productFooter
            }
            .frame(width: width - GravitySpacing.space20 * 2, alignment: .leading)
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, topPadding)
            .padding(.bottom, GravitySpacing.space12)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
        .foregroundStyle(Color(hex: "#3D493C"))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("A personalized Ugmonk focus list")
    }

    private var liveList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Today")
                    .tracking(1.1)
                Spacer()
                Text("\(completedCount) / \(tasks.count)")
            }
            .font(.system(size: 9, design: .monospaced))
            .padding(.bottom, GravitySpacing.space8)

            ForEach($tasks) { $task in
                Button {
                    HapticFeedback.selection.fire()
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        task.isDone.toggle()
                    }
                } label: {
                    HStack(spacing: GravitySpacing.space12) {
                        Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20, weight: .regular))
                        Text(task.title)
                            .font(GravityFont.regular.fixedFont(size: 14))
                            .strikethrough(task.isDone)
                            .opacity(task.isDone ? 0.42 : 1)
                        Spacer()
                    }
                    .frame(height: 47)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(task.isDone ? "Mark incomplete" : "Complete") \(task.title)")
                Divider().overlay(Color(hex: "#3D493C").opacity(0.10))
            }

            if tasks.count < 5 {
                HStack(spacing: GravitySpacing.space8) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    TextField("Add one thing", text: $draft)
                        .font(GravityFont.regular.fixedFont(size: 13))
                        .submitLabel(.done)
                        .onSubmit(addTask)
                    Button(action: addTask) {
                        Image(systemName: "arrow.return.left")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Add task")
                }
                .frame(height: 45)
            }

            Spacer(minLength: GravitySpacing.space4)
            Text("A little space to think.")
                .font(.system(size: 8, design: .monospaced))
                .tracking(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(GravitySpacing.space16)
        .background(Color(hex: "#FBFAF5"))
        .rotationEffect(.degrees(-1.4))
        .shadow(color: .black.opacity(0.07), radius: 12, y: 7)
        .padding(.horizontal, GravitySpacing.space8)
        .accessibilityElement(children: .contain)
    }

    private var analogStage: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "#E8E2D6")
            BundleImage(name: "ugmonk-analog-weekly-kit", extension: "webp", fills: true)
                .blendMode(.multiply)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Today")
                    Spacer()
                    Text("\(completedCount) / \(tasks.count)")
                }
                .font(.system(size: 7, design: .monospaced))
                ForEach(tasks.prefix(4)) { task in
                    HStack(spacing: 6) {
                        Image(systemName: task.isDone ? "checkmark.square" : "square")
                            .font(.system(size: 9))
                        Text(task.title)
                            .font(.system(size: 9, design: .serif))
                            .lineLimit(1)
                    }
                }
            }
            .padding(GravitySpacing.space12)
            .frame(width: 205, height: 122, alignment: .topLeading)
            .background(Color(hex: "#FCFBF6"))
            .rotationEffect(.degrees(3))
            .shadow(color: .black.opacity(0.16), radius: 8, y: 5)
            .offset(y: -21)
        }
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        .accessibilityLabel("Your focus list on an Analog card")
    }

    private var productFooter: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.agentProduct(product))
        } label: {
            HStack(spacing: GravitySpacing.space12) {
                BundleImage(name: "ugmonk-analog-weekly-kit", extension: "webp")
                    .frame(width: 50, height: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Analog Weekly Planning Kit")
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                        .lineLimit(1)
                    Text("$79")
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .opacity(0.62)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, GravitySpacing.space12)
            .frame(height: 62)
            .foregroundStyle(Color(hex: "#F0ECE2"))
            .background(Color(hex: "#3D493C"), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Explore the Analog Weekly Planning Kit, $79")
    }

    private func toggleAnalog() {
        HapticFeedback.light.fire()
        withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.82)) {
            isAnalog.toggle()
        }
    }

    private func addTask() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, tasks.count < 5 else { return }
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.20)) {
            tasks.append(FocusTask(id: nextID, title: title, isDone: false))
            nextID += 1
            draft = ""
        }
    }
}

private struct BundleImage: View {
    let name: String
    let `extension`: String
    var fills = false

    var body: some View {
        GeometryReader { proxy in
            if let url = Bundle.main.url(forResource: name, withExtension: `extension`),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fills ? .fill : .fit)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        }
        .accessibilityHidden(true)
    }
}
