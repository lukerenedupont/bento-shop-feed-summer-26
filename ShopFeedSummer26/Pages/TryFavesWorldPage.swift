import SwiftUI

/// The "Try your faves" world: a fixed seed avatar the shopper dresses with
/// saved tops, bottoms, and one-pieces. Looks generate asynchronously through
/// FASHN while the shopper keeps browsing; a chip in the top bar carries the
/// progress and the ready notification.
///
/// This is a style visualization — deliberately not a sizing or fit tool, and
/// the interface says so wherever a render appears.
struct TryFavesWorldPage: View {
    var namespace: Namespace.ID

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var service = TryFavesLookService.shared
    @State private var selectedPageID: String?
    @State private var showsComposer = false

    private var looks: [TryFavesLookService.Look] { service.looks }

    /// Page 0 is the plain seed avatar; each look adds a page.
    /// The seed outfit is a pre-generated look and leads the pager.
    private var pagedLooks: [TryFavesLookService.Look] {
        [service.seedLook] + looks
    }

    private var pageIDs: [String] {
        pagedLooks.map(\.id.uuidString)
    }

    var body: some View {
        ZStack {
            TryFavesStyle.canvas.ignoresSafeArea()

            // The empty studio plate stays fixed while figures and product
            // panels swipe across it. Overlay + clip keeps the oversized fill
            // from inflating the layout; the lift matches the figures' so the
            // floor stays under their feet.
            TryFavesStyle.canvas
                .overlay {
                    Image("try-faves-backdrop")
                        .resizable()
                        .scaledToFill()
                        .offset(y: -TryFavesStyle.stageLift)
                }
                .clipped()
                .ignoresSafeArea()

            // Pages run edge to edge; the header and footer fades conceal the
            // imagery's crop lines.
            lookPager
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, GravitySpacing.space12)
                    .padding(.vertical, GravitySpacing.space8)
                    .background { TryFavesEdgeFade(edge: .top) }

                Spacer()

                paginationDots
                    .padding(.bottom, GravitySpacing.space8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .navigationTransition(.zoom(sourceID: TryFavesExperience.cardID, in: namespace))
        .onAppear {
            coordinator.showNavBar = false
            if selectedPageID == nil { selectedPageID = pageIDs.first }
#if DEBUG
            // Dev/demo shortcut: `-openTryFavesComposer` lands directly in
            // the New look composer.
            if ProcessInfo.processInfo.arguments.contains("-openTryFavesComposer") {
                showsComposer = true
            }
            // Dev shortcut: `-deleteLastTryFavesLook` replays the overflow
            // menu's delete action after a beat, for layout verification.
            if ProcessInfo.processInfo.arguments.contains("-deleteLastTryFavesLook") {
                Task {
                    try? await Task.sleep(for: .seconds(6))
                    guard let last = service.looks.last else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        if selectedPageID == last.id.uuidString {
                            selectedPageID = pageIDs.first
                        }
                        service.delete(last.id)
                    }
                }
            }
            // Dev shortcut: `-generateTryFavesLook` submits the first valid
            // outfit immediately, exercising the full generation pipeline
            // including the footwear pass.
            if ProcessInfo.processInfo.arguments.contains("-generateTryFavesLook"),
               let top = TryFavesCatalog.garments(in: .tops).first,
               let bottom = TryFavesCatalog.garments(in: .bottoms).first,
               let lookID = service.generate(outfit: .separates(
                   top: top,
                   bottom: bottom,
                   shoes: TryFavesCatalog.garments(in: .footwear).first
               )) {
                selectedPageID = lookID.uuidString
            }
#endif
        }
        .onDisappear {
            coordinator.showNavBar = true
        }
        .fullScreenCover(isPresented: $showsComposer) {
            TryFavesComposerView { outfit in
                // Land on the new look's page so queued → generating → ready
                // (or the retryable failure) is visible in place. The hop is
                // deferred one tick so the pager has inserted the new page.
                if let lookID = service.generate(outfit: outfit) {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(80))
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            selectedPageID = lookID.uuidString
                        }
                    }
                }
            }
        }
        .purlInjectable()
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: GravitySpacing.space12) {
            Button {
                HapticFeedback.light.fire()
                coordinator.popCurrentPage()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background { Circle().fill(.white.opacity(0.55)) }
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Close try-on")

            Text("Try it on")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)

            Spacer(minLength: GravitySpacing.space8)

            statusChip
        }
    }

    /// Create a look → Generating look (spinner) → View new look (badge).
    @ViewBuilder
    private var statusChip: some View {
        if service.activeJob != nil {
            chip {
                HStack(spacing: GravitySpacing.space8) {
                    Text("Generating look")
                    ProgressView()
                        .controlSize(.small)
                        .tint(.black.opacity(0.6))
                }
            }
            .transition(.opacity)
        } else if let unseenID = service.unseenLookID {
            Button {
                HapticFeedback.light.fire()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    selectedPageID = unseenID.uuidString
                }
                service.markSeen(unseenID)
            } label: {
                chip {
                    HStack(spacing: GravitySpacing.space6) {
                        Text("View new look")
                        Circle()
                            .fill(TryFavesStyle.badge)
                            .frame(width: 8, height: 8)
                            .offset(y: -6)
                    }
                }
            }
            .buttonStyle(PressScaleButtonStyle())
        } else {
            Button {
                HapticFeedback.light.fire()
                showsComposer = true
            } label: {
                chip { Text("Create a look") }
            }
            .buttonStyle(PressScaleButtonStyle())
        }
    }

    private func chip(@ViewBuilder content: () -> some View) -> some View {
        content()
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, GravitySpacing.space16)
            .frame(height: 36)
            .background { Capsule().fill(.white.opacity(0.55)) }
            .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Pager

    private var lookPager: some View {
        TabView(selection: $selectedPageID) {
            ForEach(pagedLooks) { look in
                avatarPage(for: look)
                    .tag(Optional(look.id.uuidString))
                    // Extraction is requested from an async context — never
                    // during body — and re-requested when the render lands.
                    .task(id: "\(look.cacheKey)-\(look.state)") {
                        service.ensureFigure(for: look)
                    }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // Rebuild the pager when the page set changes. Page-style TabView
        // re-applies safe-area insets to surviving children after a deletion,
        // which shoved figures and footers ~90pt up; a fresh identity lays
        // out exactly like a fresh launch.
        .id(pageIDs.count)
        .animation(.easeInOut(duration: 0.24), value: pageIDs)
    }

    private func avatarPage(for look: TryFavesLookService.Look) -> some View {
        GeometryReader { geo in
            // Only the lifted figure swipes — the studio plate stays fixed
            // behind the pager. Falls back to the full render for the beat
            // before the cutout lands. Figure and shadow share one transform
            // group so registration holds at any scale or lift.
            let cutout = service.figureImage(for: look)
            let figure = cutout ?? service.renderImage(for: look)

            ZStack {
                if let figure {
                    ZStack {
                        // Grounding + direction, for true cutouts only — a
                        // full-frame render would shadow as a rectangle.
                        if cutout != nil {
                            figureContactShadow(size: geo.size)
                        }
                        Image(uiImage: figure)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    // Shrink the person around the floor line so the feet
                    // keep their contact point on the fixed plate.
                    .scaleEffect(TryFavesStyle.figureScale, anchor: TryFavesStyle.figureAnchor)
                    .offset(y: -TryFavesStyle.figureLift)
                } else {
                    placeholderStage(for: look)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(TryFavesStyle.figureScale, anchor: TryFavesStyle.figureAnchor)
                        .offset(y: -TryFavesStyle.figureLift)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .bottom) {
                bottomPanel(for: look)
                    // Tighter reach so the fade dissolves lower, closer to
                    // the product panel itself.
                    .background { TryFavesEdgeFade(edge: .bottom, solidUntil: 0.4, bleed: 8) }
            }
        }
    }

    /// A directional floor shadow matching the seed photograph: anchored at
    /// the feet and stretching to the figure's right along the floor — never
    /// pooled underneath, which reads as floating.
    private func figureContactShadow(size: CGSize) -> some View {
        let floorY = size.height * TryFavesStyle.figureAnchor.y
        let length = size.width * 0.34
        return ZStack {
            // Long soft throw to the right.
            Ellipse()
                .fill(.black.opacity(0.16))
                .frame(width: length, height: 26)
                .blur(radius: 12)
                .position(x: size.width / 2 + length * 0.52, y: floorY - 2)
            // Tighter, darker core at the contact point so the feet ground.
            Ellipse()
                .fill(.black.opacity(0.2))
                .frame(width: size.width * 0.16, height: 16)
                .blur(radius: 7)
                .position(x: size.width / 2 + 14, y: floorY - 4)
        }
    }

    /// Stand-in stage while a look renders or after it fails: a ghost of the
    /// seed figure over the fixed plate, sized like the real pages so nothing
    /// jumps when the render lands.
    private func placeholderStage(for look: TryFavesLookService.Look) -> some View {
        ZStack {
            if let seedFigure = service.figureImage(for: service.seedLook) {
                Image(uiImage: seedFigure)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 18)
                    .opacity(0.3)
            }
            switch look.state {
            case .generating:
                VStack(spacing: GravitySpacing.space12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.black.opacity(0.5))
                    Text(service.activeJob?.phase.label ?? "Generating")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black.opacity(0.55))
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: service.activeJob?.phase)
                }
            case let .failed(message):
                failedStage(look: look, message: message)
            case .ready:
                // Ready but the cached file is gone — offer regeneration.
                failedStage(look: look, message: "This render is no longer cached.")
            }
        }
    }

    /// The user-visible retry state for missing, blank, or unusable renders.
    private func failedStage(look: TryFavesLookService.Look, message: String) -> some View {
        VStack(spacing: GravitySpacing.space12) {
            Image(systemName: "sparkles.slash")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.black.opacity(0.35))
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, GravitySpacing.space24)
            Button {
                HapticFeedback.light.fire()
                service.retry(look.id)
            } label: {
                Text("Retry")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, GravitySpacing.space20)
                    .frame(height: 36)
                    .background(.black, in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(service.activeJob != nil)
        }
    }

    // MARK: - Bottom panel

    @ViewBuilder
    private func bottomPanel(for look: TryFavesLookService.Look) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            HStack {
                Text(look.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                Spacer()
                // The seed outfit is fixed — no retry or delete.
                if look.id != TryFavesLookService.seedLookID {
                    Menu {
                        if look.state.isFailed {
                            Button("Retry") { service.retry(look.id) }
                        }
                        Button("Delete look", role: .destructive) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                if selectedPageID == look.id.uuidString {
                                    selectedPageID = pageIDs.first
                                }
                                service.delete(look.id)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(service.resolvedGarments(for: look)) { garment in
                        garmentTile(
                            garment,
                            isOnScreen: selectedPageID == look.id.uuidString
                        )
                    }
                }
            }
            .scrollClipDisabled()
        }
        .padding(.horizontal, GravitySpacing.space16)
        .padding(.top, GravitySpacing.space24)
        // Clear the pagination dots and home indicator that overlay the
        // bottom of the full-bleed page.
        .padding(.bottom, 76)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A garment in the look, opening its product page with the app's shared
    /// zoom. Only the page on screen registers a transition source: the pager
    /// keeps every look alive, and a garment worn in two looks would
    /// otherwise claim the same source ID twice.
    @ViewBuilder
    private func garmentTile(_ garment: TryOnGarment, isOnScreen: Bool) -> some View {
        let tile = Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.tryFavesProduct(variantID: garment.variantID))
        } label: {
            TryFavesGarmentTile(garment: garment, width: 118, showsMeta: true)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(garment.title), \(garment.shop), \(garment.displayPrice)")

        if isOnScreen {
            tile.matchedTransitionSource(id: garment.productID, in: namespace)
        } else {
            tile
        }
    }

    // MARK: - Pagination

    private var paginationDots: some View {
        HStack(spacing: GravitySpacing.space8) {
            ForEach(pageIDs, id: \.self) { pageID in
                Capsule()
                    .fill(.black.opacity(selectedPageID == pageID ? 0.85 : 0.22))
                    .frame(width: selectedPageID == pageID ? 24 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedPageID)
        .padding(.top, GravitySpacing.space8)
    }
}

// MARK: - Composer

/// "New look": pick a top and bottoms with optional shoes, or shoes alone on
/// the already-dressed seed avatar. The selection always maps to a valid
/// generation plan: FASHN passes for separates, an edit pass for footwear.
private struct TryFavesComposerView: View {
    let onGenerate: (TryFavesOutfit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTop: TryOnGarment?
    @State private var selectedBottom: TryOnGarment?
    @State private var selectedShoes: TryOnGarment?

    private var outfit: TryFavesOutfit? {
        if let selectedTop, let selectedBottom {
            return .separates(top: selectedTop, bottom: selectedBottom, shoes: selectedShoes)
        }
        if let selectedShoes, selectedTop == nil, selectedBottom == nil {
            return .shoesOnly(selectedShoes)
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            composerBackdrop

            // Bottom-aligned sheet content over the full-height fade.
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: GravitySpacing.space24) {
                    Text("New look")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.black)

                    garmentRail(category: .tops, selection: $selectedTop)
                    garmentRail(category: .bottoms, selection: $selectedBottom)
                    garmentRail(category: .footwear, selection: $selectedShoes)
                }
                .padding(.horizontal, GravitySpacing.space16)
                .padding(.bottom, GravitySpacing.space24)

                generateButton
            }

            // Close sits where the Create a look chip lives underneath, so
            // the header reads as morphing between the two states.
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background { Circle().fill(.white.opacity(0.55)) }
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Close new look")
            }
            .padding(.horizontal, GravitySpacing.space12)
            .padding(.vertical, GravitySpacing.space8)
        }
        .presentationBackground(.clear)
    }

    /// Full-height opacified gradient blur: heaviest behind the bottom-aligned
    /// content, thinning toward the top so the world page ghosts through.
    private var composerBackdrop: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                stops: [
                    .init(color: TryFavesStyle.canvas.opacity(0.35), location: 0),
                    .init(color: TryFavesStyle.canvas.opacity(0.72), location: 0.45),
                    .init(color: TryFavesStyle.canvas.opacity(0.95), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private func garmentRail(
        category: TryOnGarmentCategory,
        selection: Binding<TryOnGarment?>
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            Text(category.railTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black.opacity(0.6))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(TryFavesCatalog.garments(in: category)) { garment in
                        selectableTile(
                            garment: garment,
                            isSelected: selection.wrappedValue == garment
                        ) {
                            selection.wrappedValue =
                                selection.wrappedValue == garment ? nil : garment
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func selectableTile(
        garment: TryOnGarment,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button {
            HapticFeedback.selection.fire()
            onTap()
        } label: {
            TryFavesGarmentTile(garment: garment, width: 110, showsMeta: false)
                .overlay(alignment: .bottomTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(.black.opacity(0.72), in: Circle())
                            .padding(GravitySpacing.space8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isSelected ? .black : .black.opacity(0.08),
                            lineWidth: isSelected ? 2 : 0.5
                        )
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(garment.title) from \(garment.shop)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var generateButton: some View {
        Button {
            guard let outfit else { return }
            HapticFeedback.light.fire()
            onGenerate(outfit)
            dismiss()
        } label: {
            Text("Generate a look")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    Capsule().fill(outfit == nil ? Color.black.opacity(0.3) : .black.opacity(0.85))
                }
                .glassEffect(.regular, in: .capsule)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(outfit == nil)
        .padding(.horizontal, GravitySpacing.space16)
        .padding(.bottom, GravitySpacing.space8)
    }
}

// MARK: - Shared pieces

/// A small garment card: square image above optional two-line title + price,
/// matching the design's 118×174 (viewer) and 110×110 (composer) tiles.
struct TryFavesGarmentTile: View {
    let garment: TryOnGarment
    let width: CGFloat
    let showsMeta: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            // Product imagery fills its container edge to edge; the white
            // well behind keeps transparent PNGs reading as product cards.
            ZStack {
                Color.white
                if let url = URL(string: garment.imageURL) {
                    CachedAsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.white
                        }
                    }
                }
            }
            .frame(width: width, height: width)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
            }

            if showsMeta {
                VStack(alignment: .leading, spacing: 2) {
                    Text(garment.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.8))
                        .lineLimit(2)
                    Text(garment.displayPrice)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
        }
        .frame(width: width)
    }
}

enum TryFavesStyle {
    static let canvas = Color(hex: "#F5F1EB")
    static let stagePlaceholder = Color(hex: "#ECE7DF")
    static let badge = Color(hex: "#4A90D9")
    /// Upward shift of the fixed studio plate.
    static let stageLift: CGFloat = 120
    /// Figures ride higher than the plate so they clear the product footer.
    static let figureLift: CGFloat = stageLift + 40
    /// Figures render at 93% of the photographed size, scaled around the
    /// floor line so their feet stay planted on the fixed plate.
    static let figureScale: CGFloat = 0.93
    static let figureAnchor = UnitPoint(x: 0.5, y: 0.85)
}

/// A gradient-masked blur that dissolves the top or bottom edge of the
/// full-bleed stage imagery behind the header and footer chrome.
struct TryFavesEdgeFade: View {
    enum Edge { case top, bottom }
    let edge: Edge
    /// Fraction of the fade that stays fully opaque before dissolving.
    var solidUntil: CGFloat = 0.55
    /// How far the fade reaches past the chrome it backs.
    var bleed: CGFloat = 44

    var body: some View {
        let mask = LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: solidUntil),
                .init(color: .clear, location: 1),
            ],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(mask)
            LinearGradient(
                stops: [
                    .init(color: TryFavesStyle.canvas.opacity(0.94), location: 0),
                    .init(color: TryFavesStyle.canvas.opacity(0.55), location: solidUntil),
                    .init(color: TryFavesStyle.canvas.opacity(0), location: 1),
                ],
                startPoint: edge == .top ? .top : .bottom,
                endPoint: edge == .top ? .bottom : .top
            )
        }
        .padding(edge == .top ? .bottom : .top, -bleed)
        .ignoresSafeArea(edges: edge == .top ? .top : .bottom)
        .allowsHitTesting(false)
    }
}

#Preview("Try faves world") {
    @Previewable @Namespace var namespace
    TryFavesWorldPage(namespace: namespace)
        .environment(NavigationCoordinator())
}

#Preview("Garment tile") {
    HStack(spacing: 12) {
        ForEach(TryFavesCatalog.garments.prefix(3)) { garment in
            TryFavesGarmentTile(garment: garment, width: 118, showsMeta: true)
        }
    }
    .padding()
    .background(TryFavesStyle.canvas)
}
