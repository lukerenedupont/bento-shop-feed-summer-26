import ARKit
import SwiftUI

/// PROTOTYPE: an authentic camera-first shell for validating the Spatial World
/// before product-quality 3D assets and placement services are available.
struct SpatialARWorldDestination: View {
    @Bindable var session: WorldSession
    let products: [ResolvedStoryProduct]
    let onClose: () -> Void

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var selectedProductID: String?
    @State private var isPlaced = false
    @State private var placementScale: CGFloat = 1
    @State private var showsDetails = false

    private var selected: ResolvedStoryProduct? {
        products.first(where: { $0.id == selectedProductID })
            ?? products.first(where: { $0.id == session.state.selectedProductID })
            ?? products.first
    }

    private var windowSafeAreaInsets: UIEdgeInsets {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: \.isKeyWindow) else { return .zero }
        return window.safeAreaInsets
    }

    var body: some View {
        ZStack {
            cameraSurface
            cameraWash
            placementPreview
            focusReticle
            topChrome
            bottomControls
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showsDetails) {
            VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                Text("Spatial preview")
                    .font(GravityFont.expressiveBold.fixedFont(size: 24))
                Text("Camera and surface tracking are live on supported iPhones. Product placement is a visual prototype until these products have production 3D assets.")
                    .font(GravityFont.regular.fixedFont(size: 15))
                    .foregroundStyle(.secondary)
            }
            .padding(GravitySpacing.space20)
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
            .environment(\.colorScheme, .light)
        }
        .task {
            guard selectedProductID == nil else { return }
            selectedProductID = session.state.selectedProductID ?? products.first?.id
        }
    }

    @ViewBuilder
    private var cameraSurface: some View {
        if ARWorldTrackingConfiguration.isSupported {
            SpatialARCameraSurface()
        } else if let roomVideo = Bundle.main.url(
            forResource: "sculptural-living-room",
            withExtension: "mp4"
        ) {
            LoopingVideoPlayer(
                url: roomVideo,
                playbackGroupID: "spatial-ar-simulator"
            )
            .overlay { Color.black.opacity(0.08) }
        } else {
            Image("topic-warm-lighting-hero")
                .resizable()
                .scaledToFill()
        }
    }

    private var cameraWash: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.34), location: 0),
                .init(color: .clear, location: 0.25),
                .init(color: .clear, location: 0.58),
                .init(color: .black.opacity(0.68), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var placementPreview: some View {
        if isPlaced, let selected {
            ProductImageView(product: selected.product, merchant: selected.merchant)
                .frame(width: 210, height: 210)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.26), radius: 22, y: 14)
                .scaleEffect(placementScale)
                .offset(y: 64)
                .gesture(
                    MagnifyGesture()
                        .onChanged { placementScale = min(max($0.magnification, 0.65), 1.55) }
                )
                .transition(.scale(scale: 0.82).combined(with: .opacity))
                .onTapGesture { open(selected) }
        }
    }

    private var focusReticle: some View {
        Group {
            if !isPlaced {
                ZStack {
                    Circle().stroke(.white.opacity(0.9), lineWidth: 1.5)
                    Circle().fill(.white).frame(width: 4, height: 4)
                    Rectangle().fill(.white).frame(width: 12, height: 1)
                    Rectangle().fill(.white).frame(width: 1, height: 12)
                }
                .frame(width: 54, height: 54)
                .shadow(color: .black.opacity(0.3), radius: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: 36)
        .allowsHitTesting(false)
    }

    private var topChrome: some View {
        HStack(spacing: GravitySpacing.space8) {
            circleButton(symbol: "xmark", label: "Close", action: onClose)
            Spacer()
            Text("View in your space")
                .font(GravityFont.semiBold.fixedFont(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, GravitySpacing.space12)
                .frame(height: 40)
                .background(.black.opacity(0.18), in: Capsule())
                .glassEffect(.regular.tint(.black.opacity(0.12)), in: .capsule)
            Spacer()
            circleButton(symbol: "ellipsis", label: "About this preview") {
                showsDetails = true
            }
        }
        .padding(.horizontal, GravitySpacing.space16)
        .padding(.top, windowSafeAreaInsets.top + GravitySpacing.space4)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var bottomControls: some View {
        VStack(spacing: GravitySpacing.space12) {
            Text(isPlaced ? "Pinch to resize · Tap the item to shop" : "Move your iPhone to find a floor")
                .font(GravityFont.medium.fixedFont(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, GravitySpacing.space12)
                .frame(height: 34)
                .background(.black.opacity(0.24), in: Capsule())
                .glassEffect(.regular.tint(.black.opacity(0.12)), in: .capsule)

            productPicker

            Button {
                guard let selected else { return }
                HapticFeedback.medium.fire()
                session.send(.selectProduct(selected.id))
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    isPlaced.toggle()
                    placementScale = 1
                }
            } label: {
                Label(isPlaced ? "Remove from room" : "Place in room", systemImage: isPlaced ? "xmark" : "arkit")
                    .font(GravityFont.semiBold.fixedFont(size: 16))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(.horizontal, GravitySpacing.space16)
        .padding(.bottom, windowSafeAreaInsets.bottom + GravitySpacing.space12)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var productPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: GravitySpacing.space8) {
                ForEach(products) { item in
                    Button {
                        HapticFeedback.light.fire()
                        selectedProductID = item.id
                        session.send(.selectProduct(item.id))
                        withAnimation(.easeOut(duration: 0.18)) { isPlaced = false }
                    } label: {
                        ProductImageView(product: item.product, merchant: item.merchant)
                            .frame(width: 72, height: 72)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                            .overlay {
                                if selected?.id == item.id {
                                    RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                                        .strokeBorder(.white, lineWidth: 3)
                                }
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .frame(height: 72)
    }

    private func circleButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticFeedback.light.fire()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.18), in: Circle())
                .glassEffect(.regular.tint(.black.opacity(0.12)), in: .circle)
                .overlay { Circle().strokeBorder(.white.opacity(0.36), lineWidth: 0.5) }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
    }

    private func open(_ item: ResolvedStoryProduct) {
        session.send(.selectProduct(item.id))
        coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
    }
}

private struct SpatialARCameraSurface: UIViewRepresentable {
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.automaticallyUpdatesLighting = true
        view.antialiasingMode = .multisampling4X
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {}

    static func dismantleUIView(_ view: ARSCNView, coordinator: ()) {
        view.session.pause()
    }
}
