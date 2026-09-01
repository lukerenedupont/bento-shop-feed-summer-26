import SwiftUI
import UIKit

struct CanvasAgentFeedCover: View {
    let products: [CatalogProduct]
    private let columnCount = 4

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 6
            let tileWidth = (geometry.size.width - spacing * 3) / 4

            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<columnCount, id: \.self) { column in
                    LazyVStack(spacing: spacing) {
                        ForEach(columnProducts(column)) { product in
                            canvasTile(product, width: tileWidth)
                        }
                    }
                    .offset(y: column.isMultiple(of: 2) ? -54 : -112)
                }
            }
            .frame(width: geometry.size.width, alignment: .top)
        }
        .background(Color(hex: "#EEEDE9"))
        .overlay { Color.black.opacity(0.13).allowsHitTesting(false) }
        .clipped()
        .allowsHitTesting(false)
    }

    private func columnProducts(_ column: Int) -> [CatalogProduct] {
        products.prefix(24).enumerated().compactMap { index, product in
            index % columnCount == column ? product : nil
        }
    }

    private func canvasTile(_ product: CatalogProduct, width: CGFloat) -> some View {
        let variant = product.id.utf8.reduce(0) { ($0 + Int($1)) % 3 }
        let height = width * ([1.18, 1.42, 1.06][variant])
        return CachedAsyncImage(url: product.imageURL) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                Color.white.opacity(0.72)
            }
        }
        .frame(width: width, height: height)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct CanvasAgentWorldDestination: View {
    @Bindable var session: WorldSession
    let products: [ResolvedStoryProduct]
    let onClose: () -> Void

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var canvasProducts: [CatalogProduct]
    @State private var resetToken = 0
    @State private var hasInteracted = false
    @State private var canvasMotion = CanvasOrbMotion.zero
    @State private var canvasCommand: CanvasVoiceCommand?
    @State private var showsComposer = false
    @State private var instruction = ""

    private var windowSafeAreaInsets: UIEdgeInsets {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: \.isKeyWindow) else { return .zero }
        return window.safeAreaInsets
    }

    private var topInset: CGFloat { windowSafeAreaInsets.top }
    private var bottomInset: CGFloat { windowSafeAreaInsets.bottom }

    init(
        session: WorldSession,
        products: [ResolvedStoryProduct],
        onClose: @escaping () -> Void
    ) {
        self.session = session
        self.products = products
        self.onClose = onClose
        _canvasProducts = State(initialValue: CanvasAgentProductAdapter.products(from: products))
    }

    var body: some View {
        ZStack {
            InfiniteProductCanvas(
                products: canvasProducts,
                resultColumnCount: nil,
                resetToken: resetToken,
                voiceCommand: canvasCommand,
                hasInteracted: $hasInteracted,
                onSelect: openProduct,
                onRequestSimilar: showMoreLike,
                onRemove: removeProduct,
                onMotion: { canvasMotion = $0 }
            )
            .ignoresSafeArea()

            canvasHeader
            voiceControl
        }
        .background(Color.white.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .sheet(isPresented: $showsComposer) {
            canvasComposer
        }
        .task {
            guard !canvasProducts.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(220))
            canvasCommand = CanvasVoiceCommand(action: .voiceEntrance)
        }
    }

    private var canvasHeader: some View {
        ZStack {
            HStack {
                Button {
                    HapticFeedback.light.fire()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.82))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.52), in: Circle())
                        .glassEffect(.regular, in: .circle)
                        .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5) }
                }
                .buttonStyle(PressScaleButtonStyle())
                Spacer()

                Button {
                    resetToken += 1
                    canvasCommand = CanvasVoiceCommand(action: .showcase(resultCount: canvasProducts.count))
                } label: {
                    Image(systemName: "scope")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.82))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.52), in: Circle())
                        .glassEffect(.regular, in: .circle)
                        .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5) }
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Recenter canvas")
            }
        }
        .padding(.horizontal, GravitySpacing.space16)
        .padding(.top, topInset + GravitySpacing.space4)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var voiceControl: some View {
        Button {
            HapticFeedback.light.fire()
            showsComposer = true
        } label: {
            Image(systemName: "waveform")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.black.opacity(0.82))
                .frame(width: 58, height: 58)
                .background(.white.opacity(0.64), in: Circle())
                .glassEffect(.regular, in: .circle)
                .overlay { Circle().strokeBorder(.white.opacity(0.6), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
        .offset(
            x: -canvasMotion.displacement.width * 42,
            y: -canvasMotion.displacement.height * 30 + max(bottomInset - 28, 0)
        )
        .rotationEffect(.degrees(-Double(canvasMotion.velocity.width) * 3.5))
        .animation(.easeOut(duration: 0.16), value: canvasMotion)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityLabel("Steer this canvas")
    }

    private var canvasComposer: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            Text("Steer the canvas")
                .font(GravityFont.expressiveBold.fixedFont(size: 24))
            Text("The products and arrangement will change together.")
                .font(GravityFont.regular.fixedFont(size: 14))
                .foregroundStyle(.secondary)

            TextField("Less expensive and more unusual…", text: $instruction, axis: .vertical)
                .lineLimit(2...4)
                .padding(GravitySpacing.space12)
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: GravityRadius.r16))

            Button("Rebuild canvas") { applyInstruction() }
                .font(GravityFont.semiBold.fixedFont(size: 15))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.black, in: Capsule())
                .disabled(instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        }
        .padding(GravitySpacing.space20)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
        .environment(\.colorScheme, .light)
    }

    private func openProduct(_ product: CatalogProduct, source: ProductTransitionSource?) {
        source?.revealTile()
        guard let resolved = products.first(where: { $0.id == product.id }) else { return }
        session.send(.selectProduct(resolved.id))
        coordinator.pushRoute(.product(merchantId: resolved.merchant.id, productId: resolved.product.id))
    }

    private func showMoreLike(_ product: CatalogProduct) {
        session.send(.steer("More like \(product.title)"))
        let matching = canvasProducts.filter { $0.merchant == product.merchant || $0.category == product.category }
        let matchingIDs = Set(matching.map(\.id))
        canvasProducts = matching + canvasProducts.filter { !matchingIDs.contains($0.id) }
        resetToken += 1
        canvasCommand = CanvasVoiceCommand(action: .highlight(productIDs: matching.map(\.id)))
    }

    private func removeProduct(_ product: CatalogProduct) {
        session.send(.rejectProduct(product.id))
        canvasProducts.removeAll { $0.id == product.id }
        resetToken += 1
    }

    private func applyInstruction() {
        let prompt = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        session.send(.steer(prompt))
        let normalized = prompt.lowercased()
        if normalized.contains("less expensive") || normalized.contains("cheaper") || normalized.contains("budget") {
            canvasProducts.sort { $0.price < $1.price }
        } else if normalized.contains("premium") || normalized.contains("luxury") {
            canvasProducts.sort { $0.price > $1.price }
        } else {
            canvasProducts = Array(canvasProducts.dropFirst()) + canvasProducts.prefix(1)
        }
        instruction = ""
        showsComposer = false
        resetToken += 1
        canvasCommand = CanvasVoiceCommand(action: .play(CanvasPlayCommand(
            action: .cascade,
            productIDs: canvasProducts.map(\.id),
            sequence: .centerOut
        )))
    }
}
