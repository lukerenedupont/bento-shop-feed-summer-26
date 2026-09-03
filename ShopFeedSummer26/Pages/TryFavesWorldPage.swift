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
    private var pageIDs: [String] {
        ["seed-avatar"] + looks.map(\.id.uuidString)
    }

    var body: some View {
        ZStack {
            TryFavesStyle.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, GravitySpacing.space12)
                    .padding(.vertical, GravitySpacing.space8)

                lookPager

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
            // Dev shortcut: `-generateTryFavesLook` submits the first valid
            // outfit immediately, exercising the full generation pipeline.
            if ProcessInfo.processInfo.arguments.contains("-generateTryFavesLook"),
               let top = TryFavesCatalog.garments(in: .tops).first,
               let bottom = TryFavesCatalog.garments(in: .bottoms).first,
               let lookID = service.generate(outfit: .separates(top: top, bottom: bottom)) {
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
                    .background(.ultraThinMaterial, in: Circle())
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
            .background(.white, in: Capsule())
            .overlay { Capsule().strokeBorder(.black.opacity(0.08), lineWidth: 0.5) }
    }

    // MARK: - Pager

    private var lookPager: some View {
        TabView(selection: $selectedPageID) {
            avatarPage(image: Image(TryFavesLookService.seedAvatarAssetName), look: nil)
                .tag(Optional("seed-avatar"))

            ForEach(looks) { look in
                avatarPage(
                    image: service.renderImage(for: look).map(Image.init(uiImage:)),
                    look: look
                )
                .tag(Optional(look.id.uuidString))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.24), value: pageIDs)
    }

    private func avatarPage(image: Image?, look: TryFavesLookService.Look?) -> some View {
        GeometryReader { geo in
            let stageWidth = min(geo.size.width - 60, 344)
            let stageHeight = stageWidth * (518.0 / 344.0)

            let panelEstimate: CGFloat = look == nil ? 150 : 284
            let boundedStageHeight = min(stageHeight, geo.size.height - panelEstimate)

            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    Ellipse()
                        .fill(.black.opacity(0.1))
                        .frame(width: stageWidth * 0.44, height: 19)
                        .blur(radius: 6)
                        .offset(y: 4)

                    if let look {
                        lookStage(image: image, look: look)
                            .frame(width: stageWidth, height: boundedStageHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    } else if let image {
                        // The seed avatar is a background-removed cutout that
                        // stands directly on the canvas.
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: boundedStageHeight)
                            .padding(.bottom, GravitySpacing.space4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, GravitySpacing.space6)

                Spacer(minLength: GravitySpacing.space12)

                bottomPanel(for: look)
            }
        }
    }

    /// Rendered looks arrive from FASHN as studio photographs, so they sit in
    /// a white rounded card like the design's look pages.
    @ViewBuilder
    private func lookStage(image: Image?, look: TryFavesLookService.Look) -> some View {
        if let image {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .background(.white)
        } else {
            ZStack {
                Color.white
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
    private func bottomPanel(for look: TryFavesLookService.Look?) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            if let look {
                HStack {
                    Text(look.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                    Spacer()
                    Menu {
                        if look.state.isFailed {
                            Button("Retry") { service.retry(look.id) }
                        }
                        Button("Delete look", role: .destructive) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                if selectedPageID == look.id.uuidString {
                                    selectedPageID = "seed-avatar"
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

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GravitySpacing.space8) {
                        ForEach(service.resolvedGarments(for: look)) { garment in
                            TryFavesGarmentTile(garment: garment, width: 118, showsMeta: true)
                        }
                    }
                }
                .scrollClipDisabled()
            } else {
                Text("Try on your favorites")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                Text("Pick saved pieces and see them styled on your avatar.")
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.55))
            }

            Text("Style visualization only — not a guide to sizing or fit.")
                .font(.system(size: 11))
                .foregroundStyle(.black.opacity(0.38))
        }
        .padding(.horizontal, GravitySpacing.space16)
        .padding(.top, GravitySpacing.space12)
        .padding(.bottom, GravitySpacing.space8)
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// "New look": pick a top and bottoms, or a single one-piece. Selecting a
/// one-piece clears separates and vice versa, so the selection always maps to
/// a valid FASHN request plan.
private struct TryFavesComposerView: View {
    let onGenerate: (TryFavesOutfit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTop: TryOnGarment?
    @State private var selectedBottom: TryOnGarment?
    @State private var selectedOnePiece: TryOnGarment?

    private var outfit: TryFavesOutfit? {
        if let selectedOnePiece { return .onePiece(selectedOnePiece) }
        if let selectedTop, let selectedBottom {
            return .separates(top: selectedTop, bottom: selectedBottom)
        }
        return nil
    }

    var body: some View {
        ZStack {
            composerBackdrop

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel("Close new look")
                    Spacer()
                }
                .padding(.horizontal, GravitySpacing.space12)
                .padding(.vertical, GravitySpacing.space8)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: GravitySpacing.space24) {
                        Text("New look")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.top, GravitySpacing.space32)

                        garmentRail(
                            category: .tops,
                            selection: $selectedTop,
                            conflicting: $selectedOnePiece
                        )
                        garmentRail(
                            category: .bottoms,
                            selection: $selectedBottom,
                            conflicting: $selectedOnePiece
                        )
                        onePieceRail
                    }
                    .padding(.horizontal, GravitySpacing.space16)
                    .padding(.bottom, 120)
                }
            }

            generateButton
        }
    }

    private var composerBackdrop: some View {
        ZStack {
            TryFavesStyle.canvas
            Image(TryFavesLookService.seedAvatarAssetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: 360, maxHeight: 500)
                .blur(radius: 40)
                .opacity(0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }

    private func garmentRail(
        category: TryOnGarmentCategory,
        selection: Binding<TryOnGarment?>,
        conflicting: Binding<TryOnGarment?>
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
                            conflicting.wrappedValue = nil
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var onePieceRail: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            Text(TryOnGarmentCategory.onePieces.railTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black.opacity(0.6))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(TryFavesCatalog.garments(in: .onePieces)) { garment in
                        selectableTile(
                            garment: garment,
                            isSelected: selectedOnePiece == garment
                        ) {
                            selectedOnePiece = selectedOnePiece == garment ? nil : garment
                            selectedTop = nil
                            selectedBottom = nil
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
        VStack(spacing: GravitySpacing.space8) {
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
                    .background(
                        outfit == nil ? Color.black.opacity(0.25) : .black,
                        in: Capsule()
                    )
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(outfit == nil)

            Text("Style visualization only — not a guide to sizing or fit.")
                .font(.system(size: 11))
                .foregroundStyle(.black.opacity(0.38))
        }
        .padding(.horizontal, GravitySpacing.space16)
        .padding(.bottom, GravitySpacing.space8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
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
            Group {
                if let url = URL(string: garment.imageURL) {
                    CachedAsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            TryFavesStyle.stagePlaceholder
                        }
                    }
                } else {
                    TryFavesStyle.stagePlaceholder
                }
            }
            .frame(width: width, height: width)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if showsMeta {
                VStack(alignment: .leading, spacing: 2) {
                    Text(garment.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.8))
                        .lineLimit(2)
                    Text(formatPrice(garment.price))
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
