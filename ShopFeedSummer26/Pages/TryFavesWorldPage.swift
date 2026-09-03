import SwiftUI

/// The "Try your faves" world: a fixed seed avatar the shopper dresses with
/// saved tops, bottoms, and one-pieces. Looks generate asynchronously through
/// a single GPT Image 2 edit while the shopper keeps browsing; a chip in the
/// top bar carries the progress and the ready notification.
///
/// Every page is one flat photograph — a frame from the shoot. The selected
/// environment is baked into each generation, so changing it from Try on
/// configuration affects new looks; existing photographs keep their location.
///
/// This is a style visualization — deliberately not a sizing or fit tool, and
/// the interface says so wherever a render appears.
struct TryFavesWorldPage: View {
    var namespace: Namespace.ID

    /// The world's two sheets are overlays, not presentations. A cover would
    /// slide the whole stage; here the stage stays fixed and only blurs, and
    /// the sheet fades in over it.
    private enum Sheet: String, Identifiable {
        case composer
        case configuration

        var id: String { rawValue }
    }

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var service = TryFavesLookService.shared
    @State private var selectedPageID: String?
    @State private var sheet: Sheet?
    /// The pager's live horizontal content offset, mirrored by the garment
    /// rail strip in the fixed bottom panel.
    @State private var pagerOffsetX: CGFloat = 0

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
        stage
            // An overlay, not a ZStack sibling: the sheet's scrim ignores the
            // safe area, and as a sibling it would grow the stack past the
            // stage, which then re-centres. An overlay is sized by the stage
            // and can never move it. The scrim carries its own backdrop blur.
            // Two overlays, not one container with two children: a child that
            // appears as part of its parent's insertion never runs its own
            // transition, so the plate's rise was being dropped and only the
            // container's fade survived. Inserted separately, each keeps its
            // own — the scrim fades, the plate fades and rises.
            .overlay {
                if sheet != nil {
                    TryFavesSheetScrim { dismissSheet() }
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if let sheet {
                    sheetContent(sheet)
                        .transition(TryFavesStyle.sheetTransition)
                }
            }
            // Sheet transitions are driven by explicit `withAnimation` at the
            // call sites rather than declared here. Blurring the stage
            // collapses its safe area, which nudges the look; an implicit
            // animation doesn't reach that geometry change and it lands as a
            // jump, where an explicit transaction carries it smoothly.
            // Landing on the unseen look — by toast tap, by swipe, or because
            // it finished while already on its page — marks it seen so the
            // toast never advertises the page the shopper is looking at.
            .onChange(of: selectedPageID) {
                if let unseenID = service.unseenLookID,
                   selectedPageID == unseenID.uuidString {
                    service.markSeen(unseenID)
                }
            }
            .onChange(of: service.unseenLookID) {
                if let unseenID = service.unseenLookID,
                   selectedPageID == unseenID.uuidString {
                    service.markSeen(unseenID)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .navigationTransition(.zoom(sourceID: TryFavesExperience.cardID, in: namespace))
            .onAppear {
                coordinator.showNavBar = false
                // Adopt the active preview buyer's seed and look library, and
                // start their seed photograph if it hasn't been made yet.
                service.syncBuyerIfNeeded()
                service.ensureSeed()
                if selectedPageID == nil { selectedPageID = pageIDs.first }
#if DEBUG
                // Dev/demo shortcut: `-openTryFavesComposer` lands directly in
                // the New look composer.
                if ProcessInfo.processInfo.arguments.contains("-openTryFavesComposer") {
                    sheet = .composer
                }
                // Dev/demo shortcut: `-openTryFavesConfiguration` lands directly
                // in the Try on configuration sheet.
                if ProcessInfo.processInfo.arguments.contains("-openTryFavesConfiguration") {
                    sheet = .configuration
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
                // outfit immediately, exercising the full generation pipeline.
                // The hop is deferred a tick, like the composer's, so the
                // pager has laid out the inserted page before it is targeted.
                if ProcessInfo.processInfo.arguments.contains("-generateTryFavesLook"),
                   let top = TryFavesCatalog.garments(in: .tops).first,
                   let bottom = TryFavesCatalog.garments(in: .bottoms).first,
                   let lookID = service.generate(outfit: .separates(
                       top: top,
                       bottom: bottom,
                       shoes: TryFavesCatalog.garments(in: .footwear).first
                   )) {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(80))
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            selectedPageID = lookID.uuidString
                        }
                    }
                }
#endif
            }
            .onDisappear {
                coordinator.showNavBar = true
            }
            .purlInjectable()
    }

    // MARK: - Stage

    /// The tones the chrome borrows from the photograph currently on screen.
    /// Looks carry their own environment, so this is the only way the fades
    /// can dissolve into the image rather than sit on top of it.
    /// The look the pager has settled on. The panel and the chrome tones both
    /// follow it, since both are pinned to the stage rather than to a page.
    private var currentLook: TryFavesLookService.Look {
        pagedLooks.first { $0.id.uuidString == selectedPageID } ?? service.seedLook
    }

    private var bands: TryFavesStageColors.Bands {
        guard let render = service.renderImage(for: currentLook) else { return .neutral }
        return TryFavesStageColors.bands(for: render, key: currentLook.cacheKey)
    }

    private var stage: some View {
        ZStack {
            // Every look is a flat photograph with its own environment, so the
            // canvas takes the frame's own ground tone. It backs the strip the
            // frame lift leaves at the foot of the page, and matching means
            // that strip reads as more floor rather than as a band.
            bands.canvas
                .ignoresSafeArea()
                .animation(TryFavesStyle.bandsFade, value: bands)

            // Pages run edge to edge; the header and footer fades conceal the
            // imagery's crop lines.
            lookPager
                .ignoresSafeArea()

            // The panel and its fade are pinned to the stage rather than
            // riding each page, so rubber-banding the pager never drags them
            // away from the header. They sit *above* the pager: as a sibling
            // underneath it, the photograph simply covered the fade.
            VStack(spacing: 0) {
                Spacer()
                bottomPanel
                    .background {
                        TryFavesEdgeFade(
                            edge: .bottom,
                            tint: bands.groundScrim,
                            solidUntil: TryFavesStyle.fadeSolidUntil,
                            bleed: TryFavesStyle.fadeBleed
                        )
                        .animation(TryFavesStyle.bandsFade, value: bands)
                    }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, GravitySpacing.space12)
                    .padding(.vertical, GravitySpacing.space8)
                    .background {
                        TryFavesEdgeFade(
                            edge: .top,
                            tint: bands.skyScrim,
                            solidUntil: TryFavesStyle.fadeSolidUntil,
                            bleed: TryFavesStyle.fadeBleed
                        )
                        .animation(TryFavesStyle.bandsFade, value: bands)
                    }

                Spacer()

                // The toast rises over the dots, centered on the same bottom
                // line, and only while the new look is somewhere off screen.
                ZStack(alignment: .bottom) {
                    paginationDots
                        .padding(.bottom, GravitySpacing.space8)
                    newLookToast
                }
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.85),
                    value: service.unseenLookID
                )
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.85),
                    value: selectedPageID
                )
            }
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: Sheet) -> some View {
        switch sheet {
        case .composer:
            TryFavesComposerView(dismiss: dismissSheet) { outfit in
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
        case .configuration:
            TryFavesConfigurationSheet(dismiss: dismissSheet) {
                // Environment and appearance describe the photograph, so they
                // only land by shooting the look on screen again.
                guard let current = pagedLooks.first(where: {
                    $0.id.uuidString == selectedPageID
                }) else { return }
                if let lookID = service.regenerate(current.id) {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(80))
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            selectedPageID = lookID.uuidString
                        }
                    }
                }
            }
        }
    }

    private func dismissSheet() {
        withAnimation(TryFavesStyle.sheetMotion) { sheet = nil }
    }

    private func present(_ sheet: Sheet) {
        withAnimation(TryFavesStyle.sheetMotion) { self.sheet = sheet }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: GravitySpacing.space12) {
            Button {
                HapticFeedback.light.fire()
                coordinator.popCurrentPage()
            } label: {
                GravityIcon.cross.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(TryFavesStyle.stageText)
                    .frame(width: TryFavesStyle.chromeHeight, height: TryFavesStyle.chromeHeight)
                    .tryFavesGlass(in: .circle)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Close try-on")

            Text("Try it on")
                .gravityTextStyle(GravityTypography.expressiveH8Heavy)
                .foregroundStyle(TryFavesStyle.stageText)

            Spacer(minLength: GravitySpacing.space8)

            // The chip and the settings button are one control cluster, so
            // they sit tighter to each other than to the title.
            HStack(spacing: GravitySpacing.space4) {
                statusChip
                configurationButton
            }
        }
    }

    /// Create a look → Generating look (spinner). The finished-look
    /// notification is `newLookToast`, not a chip state.
    @ViewBuilder
    private var statusChip: some View {
        if service.activeJob != nil {
            chip {
                HStack(spacing: GravitySpacing.space8) {
                    Text("Generating look")
                    ProgressView()
                        .controlSize(.small)
                        .tint(TryFavesStyle.stageTextSecondary)
                }
            }
            .transition(.opacity)
        } else {
            Button {
                HapticFeedback.light.fire()
                present(.composer)
            } label: {
                chip { Text("Create a look") }
            }
            .buttonStyle(PressScaleButtonStyle())
        }
    }

    /// The finished-look notification: the same glass chip as the header
    /// controls, popping up from the bottom edge over the pagination dots.
    /// It only shows while the new look's page is off screen — arriving on
    /// the page (by tap or by swipe) marks the look seen and retracts it.
    @ViewBuilder
    private var newLookToast: some View {
        if let unseenID = service.unseenLookID,
           selectedPageID != unseenID.uuidString {
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
            .padding(.bottom, GravitySpacing.space4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// Avatar, environment, and appearance settings. The dot is a one-time
    /// discovery hint: it clears the first time the sheet is opened.
    private var configurationButton: some View {
        Button {
            HapticFeedback.light.fire()
            service.hasOpenedConfiguration = true
            present(.configuration)
        } label: {
            GravityIcon.filter.image
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(TryFavesStyle.stageText)
                .frame(width: TryFavesStyle.chromeHeight, height: TryFavesStyle.chromeHeight)
                .tryFavesGlass(in: .circle)
                .overlay(alignment: .topTrailing) {
                    if !service.hasOpenedConfiguration {
                        Circle()
                            .fill(TryFavesStyle.badge)
                            .frame(width: 8, height: 8)
                            .offset(x: -1, y: 1)
                    }
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Try on configuration")
    }

    private func chip(@ViewBuilder content: () -> some View) -> some View {
        content()
            .gravityTextStyle(GravityTypography.buttonMedium)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(TryFavesStyle.stageText)
            .padding(.horizontal, GravitySpacing.space16)
            .frame(height: TryFavesStyle.chromeHeight)
            .tryFavesGlass(in: .capsule)
    }

    // MARK: - Pager

    private var lookPager: some View {
        // Native SwiftUI paging rather than a page-style TabView: the UIKit
        // pager underneath TabView re-applies safe-area insets to surviving
        // pages on every insert and delete, shoving figures and panels ~90pt
        // up. A paging ScrollView lays out identically through mutations, so
        // titles and garment rails hold their position.
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pagedLooks) { look in
                    avatarPage(for: look)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(look.id.uuidString)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $selectedPageID)
        .scrollIndicators(.hidden)
        // The garment rail strip in the fixed panel mirrors this offset so
        // garments ride the swipe exactly like the photographs do.
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.x
        } action: { _, offset in
            pagerOffsetX = offset
        }
        .animation(.easeInOut(duration: 0.24), value: pageIDs)
    }

    private func avatarPage(for look: TryFavesLookService.Look) -> some View {
        GeometryReader { geo in
            // One flat photograph per look — a frame from the shoot, filling
            // the page edge to edge.
            ZStack {
                if let render = service.renderImage(for: look) {
                    Image(uiImage: render)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .offset(y: -TryFavesStyle.frameLift)
                        .clipped()
                } else {
                    placeholderStage(for: look)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// Stand-in while a look renders or after it fails: a ghost of the seed
    /// photograph, sized like the real pages so nothing jumps when the
    /// render lands.
    private func placeholderStage(for look: TryFavesLookService.Look) -> some View {
        ZStack {
            if let seed = service.seedRenderImage() {
                Image(uiImage: seed)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 18)
                    .opacity(0.2)
                    .clipped()
            }
            switch look.state {
            case .generating:
                ComposingLookIndicator()
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
                .foregroundStyle(TryFavesStyle.stageText.opacity(0.35))
            Text(message)
                .gravityTextStyle(GravityTypography.bodySmall)
                .foregroundStyle(TryFavesStyle.stageTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, GravitySpacing.space24)
            Button {
                HapticFeedback.light.fire()
                service.retry(look.id)
            } label: {
                Text("Retry")
                    .gravityTextStyle(GravityTypography.buttonMedium)
                    .foregroundStyle(GravityColors.textFixedLight)
                    .padding(.horizontal, GravitySpacing.space20)
                    .frame(height: TryFavesStyle.chromeHeight)
                    .background(
                        GravityColors.bgFillFixedDark,
                        in: RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
                    )
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(service.activeJob != nil)
        }
    }

    // MARK: - Bottom panel

    /// A fixed block, never a hug.
    ///
    /// The content legitimately varies between pages — the seed look has no
    /// overflow menu, a shoes-only look has one tile instead of three — and a
    /// hugging panel resizes under the pager on every swipe and every delete.
    /// Pinning the title row, the rail, and the panel itself keeps the
    /// headline and garments still.
    @ViewBuilder
    private var bottomPanel: some View {
        garmentRailStrip
            .padding(.top, TryFavesStyle.panelTopInset)
            // Clear the pagination dots and home indicator that overlay the
            // bottom of the full-bleed page.
            .padding(.bottom, TryFavesStyle.panelBottomInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: TryFavesStyle.panelHeight, alignment: .top)
    }

    /// Every look's title and garments laid side by side at page width and
    /// translated by the pager's live offset, so both ride the swipe exactly
    /// like the photographs — while the panel and its fade stay pinned.
    /// Never scrollable itself: at most three garments per look.
    private var garmentRailStrip: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(pagedLooks) { look in
                    VStack(alignment: .leading, spacing: TryFavesStyle.panelTitleGap) {
                        titleRow(for: look)
                        HStack(alignment: .top, spacing: GravitySpacing.space8) {
                            ForEach(service.resolvedGarments(for: look)) { garment in
                                garmentTile(garment)
                            }
                        }
                        .frame(height: TryFavesStyle.panelRailHeight, alignment: .top)
                    }
                    .padding(.horizontal, GravitySpacing.space16)
                    .frame(width: geo.size.width, alignment: .leading)
                }
            }
            .offset(x: -pagerOffsetX)
        }
    }

    private func titleRow(for look: TryFavesLookService.Look) -> some View {
        HStack {
            Text(look.title)
                .gravityTextStyle(GravityTypography.expressiveH8Heavy)
                .foregroundStyle(TryFavesStyle.stageText)
                .lineLimit(1)
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
                    GravityIcon.overflow.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(TryFavesStyle.stageText)
                        .frame(
                            width: TryFavesStyle.overflowHitTarget,
                            height: TryFavesStyle.overflowHitTarget
                        )
                        // A rectangle, not a circle: an inscribed circle threw
                        // away the corners and left a target noticeably
                        // smaller than the frame it sits in.
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, GravitySpacing.space4)
        .frame(height: TryFavesStyle.panelTitleHeight)
    }

    /// A garment in the look, opening its product page with the app's shared
    /// zoom. Only one panel exists now that it is pinned to the stage, so a
    /// garment can no longer claim the same transition source twice.
    private func garmentTile(_ garment: TryOnGarment) -> some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.tryFavesProduct(variantID: garment.variantID))
        } label: {
            TryFavesProductTile(
                garment: garment,
                width: TryFavesStyle.lookTileWidth,
                accessory: .favorite,
                showsMeta: true
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(garment.title), \(garment.shop), \(garment.displayPrice)")
        .matchedTransitionSource(id: garment.productID, in: namespace)
    }

    // MARK: - Pagination

    private var paginationDots: some View {
        HStack(spacing: GravitySpacing.space8) {
            ForEach(pageIDs, id: \.self) { pageID in
                Capsule()
                    .fill(TryFavesStyle.stageText.opacity(selectedPageID == pageID ? 0.85 : 0.22))
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
///
/// It shares its plate, type, and buttons with Try on configuration; the two
/// sheets open from adjacent controls and must read as one family.
private struct TryFavesComposerView: View {
    /// The sheet is an overlay on the world page, not a presentation, so it is
    /// handed its own way out.
    let dismiss: () -> Void
    let onGenerate: (TryFavesOutfit) -> Void

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
        // The world page owns the scrim behind every sheet; this is the plate.
        TryFavesSheetPlate(title: "New look", onDismiss: dismiss) {
            VStack(alignment: .leading, spacing: GravitySpacing.space16) {
                garmentRail(category: .tops, selection: $selectedTop)
                garmentRail(category: .bottoms, selection: $selectedBottom)
                garmentRail(category: .footwear, selection: $selectedShoes)
            }
        } footer: {
            TryFavesSheetButton(title: "Generate a look", isEnabled: outfit != nil) {
                guard let outfit else { return }
                onGenerate(outfit)
                dismiss()
            }
        }
    }

    /// Rails bleed to the sheet's edges so the next tile is always half-visible
    /// — the affordance that there is more to choose from.
    private func garmentRail(
        category: TryOnGarmentCategory,
        selection: Binding<TryOnGarment?>
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            Text(category.railTitle)
                .gravityTextStyle(GravityTypography.captionBold)
                .foregroundStyle(TryFavesStyle.sheetText)
                .padding(.horizontal, GravitySpacing.space20)

            ScrollView(.horizontal) {
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
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, GravitySpacing.space16, for: .scrollContent)
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
            TryFavesProductTile(
                garment: garment,
                width: TryFavesStyle.composerTileWidth,
                accessory: .selection(isSelected: isSelected)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(garment.title) from \(garment.shop)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Shared pieces

/// The generating state: three softly pulsing dots over a cycling set of
/// photo-shoot phrases, so a long generation reads as a shoot in progress
/// rather than a stalled spinner. Phrases hold for a slightly random beat
/// and swap with a blur, keeping the rhythm organic.
private struct ComposingLookIndicator: View {
    private static let phrases = [
        "Setting up the shot",
        "Styling the fit",
        "Adjusting the light",
        "Framing the scene",
        "Getting the details right",
        "One more take",
    ]

    @State private var phraseIndex = 0
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: GravitySpacing.space16) {
            HStack(spacing: GravitySpacing.space8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(TryFavesStyle.stageText)
                        .frame(width: 9, height: 9)
                        .scaleEffect(pulsing ? 1 : 0.5)
                        .opacity(pulsing ? 0.95 : 0.35)
                        .animation(
                            .easeInOut(duration: 0.65)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.21),
                            value: pulsing
                        )
                }
            }

            Text(Self.phrases[phraseIndex])
                .gravityTextStyle(GravityTypography.bodySmallBold)
                .foregroundStyle(TryFavesStyle.stageTextSecondary)
                .id(phraseIndex)
                .transition(.blurReplace)
        }
        .onAppear { pulsing = true }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(.random(in: 2.0...3.2)))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.45)) {
                    phraseIndex = (phraseIndex + 1) % Self.phrases.count
                }
            }
        }
    }
}

/// A gradient-masked blur that dissolves the top or bottom edge of the
/// full-bleed stage imagery behind the header and footer chrome. The tint
/// comes from the stage canvas, so the fade never reads as a band.
struct TryFavesEdgeFade: View {
    enum Edge { case top, bottom }
    let edge: Edge
    let tint: Color
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
                    .init(color: tint.opacity(0.58), location: 0),
                    .init(color: tint.opacity(0.26), location: solidUntil),
                    .init(color: tint.opacity(0), location: 1),
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
