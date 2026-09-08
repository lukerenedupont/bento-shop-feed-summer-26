import SwiftUI

/// PROTOTYPE — renders the finite card grammar used to evaluate a future
/// AI-authored feed. Every variant uses the same trusted commerce inputs but
/// owns a materially different hierarchy and interaction model.
struct NextGenerationFeedCardView: View {
    let spec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let width: CGFloat
    let height: CGFloat
    let foregroundTopPadding: CGFloat
    let isActive: Bool

    @State private var selectedIndex = 0
    @State private var secondaryIndex = 1
    @State private var selectedProductIDs = Set<String>()
    @State private var dragTranslation: CGFloat = 0
    @State private var revealAmount: CGFloat = 0.5
    @State private var isExpanded = false
    @State private var answeredPoll: Bool?
    @State private var stageRotation: Double = 0

    private var products: [ResolvedStoryProduct] {
        spec.resolvedProducts(from: merchants)
    }

    private var accent: Color { Color(hex: spec.accentHex) }

    private var usesDarkText: Bool {
        [.colorWash, .comparisonScrub, .priceLadder].contains(spec.layout)
    }

    private var foreground: Color { usesDarkText ? .black : .white }

    var body: some View {
        let contentHeight = max(
            height - foregroundTopPadding - FeedCardStyle.foregroundBottomPadding,
            320
        )

        ZStack {
            background
            layout
                .frame(width: width, height: contentHeight, alignment: .top)
                .clipped()
                .padding(.top, foregroundTopPadding)
                .padding(.bottom, FeedCardStyle.foregroundBottomPadding)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
        }
        .contentShape(Rectangle())
        .onChange(of: spec.id) { _, _ in resetInteraction() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(spec.title). \(spec.subtitle)")
    }

    @ViewBuilder
    private var background: some View {
        switch spec.layout {
        case .colorWash, .priceLadder:
            LinearGradient(
                colors: [.white, accent.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .catalogTicker, .merchantWindow, .rapidPoll:
            accent
        default:
            LinearGradient(
                colors: [accent.opacity(0.94), accent.opacity(0.62), .black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var layout: some View {
        switch spec.layout {
        case .focusFrame: focusFrame
        case .orbit: orbit
        case .splitDecision: splitDecision
        case .swipeStack: swipeStack
        case .mosaicSpotlight: mosaicSpotlight
        case .merchantWindow: merchantWindow
        case .colorWash: colorWash
        case .productTimeline: productTimeline
        case .comparisonScrub: comparisonScrub
        case .kitBuilder: kitBuilder
        case .constellation: constellation
        case .catalogTicker: catalogTicker
        case .detailLens: detailLens
        case .priceLadder: priceLadder
        case .dropReveal: dropReveal
        case .editorialFold: editorialFold
        case .bundleBuilder: bundleBuilder
        case .textureRail: textureRail
        case .productStage: productStage
        case .rapidPoll: rapidPoll
        }
    }

    // MARK: 01 — Focus frame

    private var focusFrame: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            cardHeader(indexLabel: "01 / 20")
            Button { advanceSelection() } label: {
                productImage(product(at: selectedIndex))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.62)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                    .overlay(alignment: .center) {
                        RoundedRectangle(cornerRadius: 34)
                            .stroke(.white.opacity(0.72), lineWidth: 1)
                            .frame(width: 190, height: 250)
                    }
                    .overlay(alignment: .bottom) {
                        productIdentity(product(at: selectedIndex), centered: true)
                            .padding(GravitySpacing.space20)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            }
            .buttonStyle(.plain)
            dotIndex
        }
        .padding(.horizontal, GravitySpacing.space20)
    }

    // MARK: 02 — Orbit

    private var orbit: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            cardHeader(indexLabel: "02 / 20")
            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                        .frame(width: proxy.size.width * 0.82)
                    ForEach(Array(products.prefix(5).enumerated()), id: \.element.id) { index, item in
                        let angle = Double(index) / Double(max(min(products.count, 5), 1)) * .pi * 2
                            + Double(dragTranslation / 110)
                        productImage(item)
                            .frame(width: index == selectedIndex ? 150 : 88, height: index == selectedIndex ? 190 : 110)
                            .clipShape(RoundedRectangle(cornerRadius: index == selectedIndex ? 28 : 18, style: .continuous))
                            .offset(
                                x: cos(angle) * proxy.size.width * 0.31,
                                y: sin(angle) * proxy.size.width * 0.31
                            )
                            .zIndex(index == selectedIndex ? 2 : 1)
                            .onTapGesture { select(index) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { dragTranslation = $0.translation.width }
                        .onEnded { value in
                            if abs(value.translation.width) > 32 { advanceSelection(direction: value.translation.width < 0 ? 1 : -1) }
                            withAnimation(SpringPreset.responsive) { dragTranslation = 0 }
                        }
                )
            }
            productIdentity(product(at: selectedIndex))
        }
        .padding(.horizontal, GravitySpacing.space20)
    }

    // MARK: 03 — Split decision

    private var splitDecision: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            cardHeader(indexLabel: "Pick one")
            HStack(spacing: GravitySpacing.space8) {
                splitChoice(index: 0)
                splitChoice(index: 1)
            }
            .frame(maxHeight: .infinity)
            Text("Tap either side. The selected direction becomes the next signal.")
                .font(GravityFont.regular.fixedFont(size: 13))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, GravitySpacing.space16)
    }

    private func splitChoice(index: Int) -> some View {
        let item = product(at: index)
        return Button { select(index) } label: {
            productImage(item)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item?.product.title ?? "Product")
                            .font(GravityFont.expressiveSemiBold.fixedFont(size: 19))
                            .lineLimit(2)
                        Text(item.map { formatPrice($0.product.price) } ?? "")
                            .font(GravityFont.medium.fixedFont(size: 14))
                    }
                    .foregroundStyle(.white)
                    .gravityShadow(GravityShadows.feedText)
                    .padding(GravitySpacing.space16)
                }
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: GravityRadius.r24, style: .continuous)
                        .stroke(selectedIndex == index ? .white : .white.opacity(0.18), lineWidth: selectedIndex == index ? 3 : 0.5)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: 04 — Swipe stack

    private var swipeStack: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            cardHeader(indexLabel: "Swipe")
            ZStack {
                ForEach((0..<min(products.count, 4)).reversed(), id: \.self) { depth in
                    let index = wrappedIndex(selectedIndex + depth)
                    productImage(product(at: index))
                        .overlay(alignment: .bottom) { productIdentity(product(at: index), centered: true).padding(18) }
                        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
                        .scaleEffect(1 - CGFloat(depth) * 0.045)
                        .offset(y: CGFloat(depth) * 18)
                        .offset(x: depth == 0 ? dragTranslation : 0)
                        .rotationEffect(.degrees(depth == 0 ? Double(dragTranslation / 18) : 0))
                        .zIndex(Double(10 - depth))
                }
            }
            .frame(maxHeight: .infinity)
            .gesture(
                DragGesture()
                    .onChanged { dragTranslation = $0.translation.width }
                    .onEnded { value in
                        if abs(value.translation.width) > 55 { advanceSelection(direction: value.translation.width < 0 ? 1 : -1) }
                        withAnimation(SpringPreset.responsive) { dragTranslation = 0 }
                    }
            )
            HStack {
                pill("Skip", symbol: "xmark") { advanceSelection() }
                pill("Keep", symbol: "heart") { toggleSelected(product(at: selectedIndex)) }
            }
        }
        .padding(.horizontal, GravitySpacing.space20)
    }

    // MARK: 05 — Mosaic spotlight

    private var mosaicSpotlight: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            cardHeader(indexLabel: "Tap a tile")
            GeometryReader { proxy in
                let gap = GravitySpacing.space8
                let small = (proxy.size.width - gap * 2) / 3
                ZStack(alignment: .topLeading) {
                    mosaicTile(index: selectedIndex, width: small * 2 + gap, height: proxy.size.height * 0.58)
                    mosaicTile(index: wrappedIndex(selectedIndex + 1), width: small, height: proxy.size.height * 0.28)
                        .offset(x: small * 2 + gap * 2)
                    mosaicTile(index: wrappedIndex(selectedIndex + 2), width: small, height: proxy.size.height * 0.28)
                        .offset(x: small * 2 + gap * 2, y: proxy.size.height * 0.30)
                    ForEach(0..<3, id: \.self) { column in
                        mosaicTile(index: wrappedIndex(selectedIndex + 3 + column), width: small, height: proxy.size.height * 0.38)
                            .offset(x: CGFloat(column) * (small + gap), y: proxy.size.height * 0.60)
                    }
                }
            }
        }
        .padding(.horizontal, GravitySpacing.space16)
    }

    private func mosaicTile(index: Int, width: CGFloat, height: CGFloat) -> some View {
        Button { select(index) } label: {
            productImage(product(at: index))
                .frame(width: width, height: height)
                .overlay(alignment: .bottomLeading) {
                    if index == selectedIndex {
                        Text(product(at: index)?.product.title ?? "")
                            .font(GravityFont.semiBold.fixedFont(size: 15))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .padding(12)
                            .gravityShadow(GravityShadows.feedText)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: 06 — Merchant window

    private var merchantWindow: some View {
        let merchant = product(at: 0)?.merchant
        return VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            HStack(spacing: GravitySpacing.space12) {
                if let merchant { MerchantAvatarView(merchant: merchant, size: 52) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.title).font(GravityFont.expressiveSemiBold.fixedFont(size: 28))
                    Text(spec.eyebrow).font(GravityFont.regular.fixedFont(size: 14)).opacity(0.68)
                }
                Spacer()
                Button(isExpanded ? "Following" : "Follow") { withAnimation { isExpanded.toggle() } }
                    .buttonStyle(.borderedProminent)
                    .tint(isExpanded ? .white.opacity(0.18) : .white)
                    .foregroundStyle(isExpanded ? .white : .black)
            }
            .foregroundStyle(.white)
            productImage(product(at: selectedIndex))
                .overlay(alignment: .bottomLeading) { productIdentity(product(at: selectedIndex)).padding(18) }
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
                .frame(maxHeight: .infinity)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(Array(products.prefix(6).enumerated()), id: \.element.id) { index, item in
                        Button { select(index) } label: {
                            productImage(item)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay { RoundedRectangle(cornerRadius: 14).stroke(index == selectedIndex ? .white : .clear, lineWidth: 2) }
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, GravitySpacing.space20)
    }

    // MARK: 07 — Color wash

    private var colorWash: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space20) {
            cardHeader(indexLabel: "Mood", forceDark: true)
            productImage(product(at: selectedIndex))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                .shadow(color: accent.opacity(0.45), radius: 40)
            productIdentity(product(at: selectedIndex), forceDark: true)
            HStack(spacing: GravitySpacing.space12) {
                ForEach(0..<5, id: \.self) { index in
                    Button { select(index) } label: {
                        Circle()
                            .fill(colorSwatch(index))
                            .frame(width: index == selectedIndex ? 42 : 32, height: index == selectedIndex ? 42 : 32)
                            .overlay { Circle().stroke(.black.opacity(0.22), lineWidth: 1) }
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, GravitySpacing.space24)
    }

    // MARK: 08 — Product timeline

    private var productTimeline: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            cardHeader(indexLabel: "Step \(selectedIndex + 1)")
            HStack(spacing: GravitySpacing.space16) {
                VStack(spacing: 0) {
                    ForEach(0..<min(products.count, 5), id: \.self) { index in
                        Button { select(index) } label: {
                            VStack(spacing: 0) {
                                Circle().fill(index == selectedIndex ? .white : .white.opacity(0.25)).frame(width: 18, height: 18)
                                if index < 4 { Rectangle().fill(.white.opacity(0.22)).frame(width: 1, height: 72) }
                            }
                        }.buttonStyle(.plain)
                    }
                }
                productImage(product(at: selectedIndex))
                    .overlay(alignment: .bottomLeading) { productIdentity(product(at: selectedIndex)).padding(20) }
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, GravitySpacing.space24)
    }

    // MARK: 09 — Comparison scrub

    private var comparisonScrub: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            cardHeader(indexLabel: "Drag", forceDark: true)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    productImage(product(at: 0))
                    productImage(product(at: 1))
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: proxy.size.width * revealAmount)
                        }
                    Rectangle()
                        .fill(.white)
                        .frame(width: 3)
                        .offset(x: proxy.size.width * revealAmount - 1.5)
                    Circle()
                        .fill(.white)
                        .frame(width: 42, height: 42)
                        .overlay { Image(systemName: "arrow.left.and.right").foregroundStyle(.black) }
                        .offset(x: proxy.size.width * revealAmount - 21)
                }
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { revealAmount = min(max($0.location.x / proxy.size.width, 0.08), 0.92) })
            }
            HStack {
                productCompactIdentity(product(at: 0), forceDark: true)
                Spacer()
                productCompactIdentity(product(at: 1), forceDark: true, alignment: .trailing)
            }
        }
        .padding(.horizontal, GravitySpacing.space20)
    }

    // MARK: 10 — Kit builder

    private var kitBuilder: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            cardHeader(indexLabel: "\(selectedProductIDs.count) selected")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: GravitySpacing.space8) {
                ForEach(Array(products.prefix(6).enumerated()), id: \.element.id) { _, item in
                    Button { toggleSelected(item) } label: {
                        productImage(item)
                            .frame(height: 170)
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: selectedProductIDs.contains(item.id) ? "checkmark.circle.fill" : "plus.circle.fill")
                                    .font(.system(size: 26))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(selectedProductIDs.contains(item.id) ? accent : .black, .white)
                                    .padding(10)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                    }.buttonStyle(.plain)
                }
            }
            Text(selectedProductIDs.isEmpty ? "Tap products to start a kit" : "Your kit is taking shape")
                .font(GravityFont.semiBold.fixedFont(size: 15))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, GravitySpacing.space16)
    }

    // MARK: 11 — Constellation

    private var constellation: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            cardHeader(indexLabel: "Tap a node")
            GeometryReader { proxy in
                let points: [CGPoint] = [
                    .init(x: 0.50, y: 0.16), .init(x: 0.20, y: 0.38),
                    .init(x: 0.76, y: 0.42), .init(x: 0.36, y: 0.68),
                    .init(x: 0.72, y: 0.78),
                ]
                ZStack {
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: CGPoint(x: first.x * proxy.size.width, y: first.y * proxy.size.height))
                        for point in points.dropFirst() {
                            path.addLine(to: CGPoint(x: point.x * proxy.size.width, y: point.y * proxy.size.height))
                        }
                    }
                    .stroke(.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [5, 7]))
                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        Button { select(index) } label: {
                            productImage(product(at: index))
                                .frame(width: index == selectedIndex ? 124 : 82, height: index == selectedIndex ? 124 : 82)
                                .clipShape(Circle())
                                .overlay { Circle().stroke(.white.opacity(index == selectedIndex ? 0.9 : 0.3), lineWidth: index == selectedIndex ? 3 : 1) }
                        }
                        .buttonStyle(.plain)
                        .position(x: point.x * proxy.size.width, y: point.y * proxy.size.height)
                    }
                }
            }
            productIdentity(product(at: selectedIndex))
        }
        .padding(.horizontal, GravitySpacing.space20)
    }

    // MARK: 12 — Catalog ticker

    private var catalogTicker: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space20) {
            cardHeader(indexLabel: "Live")
            Spacer(minLength: 0)
            ForEach(0..<3, id: \.self) { row in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GravitySpacing.space8) {
                        ForEach(Array(products.enumerated()), id: \.element.id) { index, item in
                            Button { select(index) } label: {
                                productImage(item)
                                    .frame(width: row == 1 ? 180 : 128, height: row == 1 ? 210 : 148)
                                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, GravitySpacing.space20)
                }
                .scrollDisabled(row != 1)
            }
            Spacer(minLength: 0)
            productIdentity(product(at: selectedIndex))
                .padding(.horizontal, GravitySpacing.space20)
        }
    }

    // MARK: 13 — Detail lens

    private var detailLens: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            cardHeader(indexLabel: "Drag the lens")
            GeometryReader { proxy in
                let x = revealAmount * proxy.size.width
                ZStack {
                    productImage(product(at: 0))
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 150, height: 150)
                        .overlay {
                            productImage(product(at: 0))
                                .scaleEffect(1.8)
                                .clipShape(Circle())
                        }
                        .overlay { Circle().stroke(.white, lineWidth: 3) }
                        .position(x: x, y: proxy.size.height * 0.52)
                }
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { revealAmount = min(max($0.location.x / proxy.size.width, 0.12), 0.88) })
            }
            productIdentity(product(at: 0))
        }
        .padding(.horizontal, GravitySpacing.space20)
    }

    // MARK: 14 — Price ladder

    private var priceLadder: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            cardHeader(indexLabel: "Tap a rung", forceDark: true)
            Spacer(minLength: 0)
            ForEach(Array(products.prefix(6).enumerated()), id: \.element.id) { index, item in
                Button { select(index) } label: {
                    HStack(spacing: GravitySpacing.space12) {
                        Text(formatPrice(item.product.price))
                            .font(GravityFont.expressiveSemiBold.fixedFont(size: 20))
                            .frame(width: 88, alignment: .leading)
                        RoundedRectangle(cornerRadius: 18)
                            .fill(index == selectedIndex ? .black : .black.opacity(0.12))
                            .frame(height: index == selectedIndex ? 76 : 48)
                            .overlay(alignment: .leading) {
                                HStack {
                                    productImage(item).frame(width: 64).clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text(item.product.title).font(GravityFont.medium.fixedFont(size: 14)).lineLimit(2)
                                }
                                .foregroundStyle(index == selectedIndex ? .white : .black)
                                .padding(6)
                            }
                    }
                }.buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, GravitySpacing.space20)
    }

    // MARK: 15 — Drop reveal

    private var dropReveal: some View {
        Button {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { isExpanded.toggle() }
        } label: {
            ZStack {
                productImage(product(at: 0))
                    .scaleEffect(isExpanded ? 1 : 0.74)
                    .blur(radius: isExpanded ? 0 : 18)
                if !isExpanded {
                    VStack(spacing: GravitySpacing.space16) {
                        Image(systemName: "hand.tap.fill").font(.system(size: 38))
                        Text("Press to reveal").font(GravityFont.semiBold.fixedFont(size: 17))
                    }
                    .foregroundStyle(.white)
                }
                VStack(alignment: .leading) {
                    cardHeader(indexLabel: isExpanded ? "Revealed" : "One product")
                    Spacer()
                    if isExpanded { productIdentity(product(at: 0)) }
                }
                .padding(GravitySpacing.space20)
            }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .padding(.horizontal, GravitySpacing.space20)
        }
        .buttonStyle(.plain)
    }

    // MARK: 16 — Editorial fold

    private var editorialFold: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(SpringPreset.responsive) { isExpanded.toggle() } } label: {
                ZStack(alignment: .bottomLeading) {
                    productImage(product(at: 0))
                    LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(spec.eyebrow).font(GravityFont.medium.fixedFont(size: 13))
                        Text(spec.title).font(GravityFont.expressiveBold.fixedFont(size: isExpanded ? 32 : 44)).lineLimit(3)
                    }
                    .foregroundStyle(.white)
                    .padding(GravitySpacing.space20)
                }
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            }
            .buttonStyle(.plain)
            if isExpanded {
                HStack {
                    Text(spec.subtitle).lineLimit(2)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(GravityFont.regular.fixedFont(size: 15))
                .foregroundStyle(.white)
                .padding(GravitySpacing.space20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, GravitySpacing.space20)
    }

    // MARK: 17 — Bundle builder

    private var bundleBuilder: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            cardHeader(indexLabel: selectedProductIDs.isEmpty ? "Start a bundle" : "\(selectedProductIDs.count) in bundle")
            ZStack {
                ForEach(Array(products.prefix(5).enumerated()), id: \.element.id) { index, item in
                    Button { toggleSelected(item) } label: {
                        productImage(item)
                            .frame(width: 180, height: 230)
                            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r24, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                if selectedProductIDs.contains(item.id) {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 28)).foregroundStyle(.white, accent).padding(10)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .rotationEffect(.degrees(Double(index - 2) * 8))
                    .offset(x: CGFloat(index - 2) * 48, y: CGFloat(abs(index - 2)) * 28)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("Tap cards to compose a set")
                .font(GravityFont.regular.fixedFont(size: 14))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, GravitySpacing.space20)
    }

    // MARK: 18 — Texture rail

    private var textureRail: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            cardHeader(indexLabel: "Swipe details")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space12) {
                    ForEach(Array(products.prefix(6).enumerated()), id: \.element.id) { index, item in
                        Button { select(index) } label: {
                            productImage(item)
                                .scaleEffect(index == selectedIndex ? 1.22 : 1.55)
                                .frame(width: width * 0.68, height: height * 0.57)
                                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
                                .overlay(alignment: .bottomLeading) { productCompactIdentity(item).padding(16) }
                        }.buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, GravitySpacing.space20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            productIdentity(product(at: selectedIndex))
                .padding(.horizontal, GravitySpacing.space20)
        }
    }

    // MARK: 19 — Product stage

    private var productStage: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            cardHeader(indexLabel: "Drag to turn")
            ZStack {
                Ellipse().fill(.black.opacity(0.32)).frame(width: 260, height: 70).blur(radius: 16).offset(y: 210)
                productImage(product(at: selectedIndex))
                    .frame(width: width * 0.72, height: height * 0.58)
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
                    .rotation3DEffect(.degrees(stageRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                    .gesture(
                        DragGesture()
                            .onChanged { stageRotation = Double($0.translation.width) * 0.35 }
                            .onEnded { value in
                                if abs(value.translation.width) > 60 { advanceSelection(direction: value.translation.width < 0 ? 1 : -1) }
                                withAnimation(SpringPreset.responsive) { stageRotation = 0 }
                            }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            productIdentity(product(at: selectedIndex))
        }
        .padding(.horizontal, GravitySpacing.space20)
    }

    // MARK: 20 — Rapid poll

    private var rapidPoll: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space20) {
            cardHeader(indexLabel: "Signal")
            productImage(product(at: 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            if let answeredPoll {
                HStack(spacing: GravitySpacing.space12) {
                    Image(systemName: answeredPoll ? "heart.fill" : "arrow.right")
                    Text(answeredPoll ? "More like this is queued" : "We’ll change direction")
                    Spacer()
                    Button("Undo") { withAnimation { self.answeredPoll = nil } }
                }
                .font(GravityFont.semiBold.fixedFont(size: 15))
                .foregroundStyle(.white)
                .padding(GravitySpacing.space16)
                .background(.white.opacity(0.12), in: Capsule())
            } else {
                HStack(spacing: GravitySpacing.space12) {
                    pollButton("Not for me", symbol: "xmark", answer: false)
                    pollButton("More like this", symbol: "heart", answer: true)
                }
            }
        }
        .padding(.horizontal, GravitySpacing.space20)
    }

    // MARK: Shared card primitives

    private func cardHeader(indexLabel: String, forceDark: Bool = false) -> some View {
        let color: Color = forceDark ? .black : foreground
        return GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                    Text(spec.eyebrow)
                        .font(GravityFont.medium.fixedFont(size: 13))
                        .foregroundStyle(color.opacity(0.72))
                    Text(spec.title)
                        .font(GravityFont.expressiveSemiBold.fixedFont(size: 28))
                        .tracking(-0.55)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }
                .frame(width: max(proxy.size.width - 76, 140), alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(indexLabel)
                    .font(GravityFont.medium.fixedFont(size: 12))
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(color.opacity(0.10), in: Capsule())
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(color)
            .nextGenerationTextShadow(enabled: !forceDark)
        }
        .frame(height: 68)
    }

    @ViewBuilder
    private func productImage(_ item: ResolvedStoryProduct?) -> some View {
        if let item {
            ProductImageView(product: item.product, merchant: item.merchant)
        } else {
            Rectangle().fill(.white.opacity(0.12))
        }
    }

    private func productIdentity(
        _ item: ResolvedStoryProduct?,
        centered: Bool = false,
        forceDark: Bool = false
    ) -> some View {
        let color: Color = forceDark ? .black : .white
        return VStack(alignment: centered ? .center : .leading, spacing: 4) {
            Text(item?.product.title ?? spec.title)
                .font(GravityFont.expressiveSemiBold.fixedFont(size: 22))
                .tracking(-0.3)
                .lineLimit(2)
            HStack(spacing: GravitySpacing.space8) {
                Text(item?.merchant.displayName ?? spec.eyebrow)
                Text(item.map { formatPrice($0.product.price) } ?? "")
            }
            .font(GravityFont.medium.fixedFont(size: 13))
            .opacity(0.78)
        }
        .multilineTextAlignment(centered ? .center : .leading)
        .frame(maxWidth: centered ? .infinity : nil, alignment: centered ? .center : .leading)
        .foregroundStyle(color)
        .nextGenerationTextShadow(enabled: !forceDark)
    }

    private func productCompactIdentity(
        _ item: ResolvedStoryProduct?,
        forceDark: Bool = false,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        let color: Color = forceDark ? .black : .white
        return VStack(alignment: alignment, spacing: 2) {
            Text(item?.product.title ?? "Product").font(GravityFont.semiBold.fixedFont(size: 14)).lineLimit(1)
            Text(item.map { formatPrice($0.product.price) } ?? "").font(GravityFont.medium.fixedFont(size: 12)).opacity(0.72)
        }
        .foregroundStyle(color)
        .nextGenerationTextShadow(enabled: !forceDark)
    }

    private var dotIndex: some View {
        HStack(spacing: 5) {
            ForEach(0..<min(products.count, 6), id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == selectedIndex ? 1 : 0.28))
                    .frame(width: index == selectedIndex ? 22 : 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func pill(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(GravityFont.semiBold.fixedFont(size: 15))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.white.opacity(0.14), in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func pollButton(_ title: String, symbol: String, answer: Bool) -> some View {
        Button { withAnimation(SpringPreset.responsive) { answeredPoll = answer } } label: {
            Label(title, systemImage: symbol)
                .font(GravityFont.semiBold.fixedFont(size: 14))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(answer ? .white : .white.opacity(0.14), in: Capsule())
                .foregroundStyle(answer ? .black : .white)
        }
        .buttonStyle(.plain)
    }

    private func colorSwatch(_ index: Int) -> Color {
        let colors: [Color] = [accent, .orange, .pink, .mint, .indigo]
        return colors[index % colors.count]
    }

    private func product(at index: Int) -> ResolvedStoryProduct? {
        guard !products.isEmpty else { return nil }
        return products[wrappedIndex(index)]
    }

    private func wrappedIndex(_ index: Int) -> Int {
        guard !products.isEmpty else { return 0 }
        return (index % products.count + products.count) % products.count
    }

    private func select(_ index: Int) {
        HapticFeedback.selection.fire()
        withAnimation(SpringPreset.responsive) { selectedIndex = wrappedIndex(index) }
    }

    private func advanceSelection(direction: Int = 1) {
        select(selectedIndex + direction)
    }

    private func toggleSelected(_ item: ResolvedStoryProduct?) {
        guard let item else { return }
        HapticFeedback.selection.fire()
        withAnimation(SpringPreset.responsive) {
            if selectedProductIDs.contains(item.id) { selectedProductIDs.remove(item.id) }
            else { selectedProductIDs.insert(item.id) }
        }
    }

    private func resetInteraction() {
        selectedIndex = 0
        secondaryIndex = 1
        selectedProductIDs = []
        dragTranslation = 0
        revealAmount = 0.5
        isExpanded = false
        answeredPoll = nil
        stageRotation = 0
    }
}

private extension View {
    @ViewBuilder
    func nextGenerationTextShadow(enabled: Bool) -> some View {
        if enabled {
            gravityShadow(GravityShadows.feedText)
        } else {
            self
        }
    }
}
