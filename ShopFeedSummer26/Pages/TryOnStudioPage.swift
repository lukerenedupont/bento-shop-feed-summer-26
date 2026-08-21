import AVFoundation
import LiveKitWebRTC
import SwiftUI
import UIKit

/// A contained live-product playground. Nothing in the normal product or story
/// flows depends on this page, which keeps the Decart prototype easy to test,
/// remove, or evolve independently.
struct TryOnStudioPage: View {
    var namespace: Namespace.ID

    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var merchantService = RemoteMerchantService.shared
    @StateObject private var session = DecartTryOnSession()
    @State private var selectedProductID: String?
    @State private var carouselProductID: String?
    @State private var productRailVisible = false

    private var products: [ResolvedStoryProduct] {
        TryOnExperience.products(merchants: merchantService.merchants.isEmpty
            ? SampleMerchant.all
            : merchantService.merchants)
    }

    private var selectedProduct: ResolvedStoryProduct? {
        products.first { $0.id == selectedProductID } ?? products.first
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            videoStage
            stageScrims

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: GravitySpacing.space16)
                permissionCard
                Spacer(minLength: GravitySpacing.space16)
                productControls
            }
            .padding(.horizontal, GravitySpacing.space16)
            .padding(.top, GravitySpacing.space8)
            .padding(.bottom, GravitySpacing.space12)
        }
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .navigationTransition(.zoom(sourceID: TryOnExperience.cardID, in: namespace))
        .onAppear {
            coordinator.showNavBar = false
            if selectedProductID == nil {
                selectedProductID = products.first?.id
                carouselProductID = products.first?.id
            }
        }
        .onChange(of: carouselProductID) { _, productID in
            guard let productID,
                  productID != selectedProductID,
                  let product = products.first(where: { $0.id == productID }) else { return }
            selectedProductID = productID
            HapticFeedback.selection.fire()
            session.apply(product: product)
        }
        .onChange(of: session.phase) { _, phase in
            guard phase != .idle, !productRailVisible else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                productRailVisible = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active,
                  session.needsCameraSettings,
                  AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
            Task {
                await session.stop()
                await session.start(product: selectedProduct)
            }
        }
        .task {
            guard session.phase == .idle else { return }
            await session.start(product: selectedProduct)
        }
        .onDisappear {
            coordinator.showNavBar = true
            Task { await session.stop() }
        }
    }

    private var videoStage: some View {
        Group {
            if let track = session.remoteVideoTrack ?? session.localVideoTrack {
                FalRTCVideoView(
                    track: track,
                    mirrored: session.remoteVideoTrack == nil
                )
                    .transition(.opacity)
            } else {
                cameraPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.2), value: session.remoteVideoTrack != nil)
    }

    private var cameraPlaceholder: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.04, blue: 0.05),
                        Color(red: 0.14, green: 0.08, blue: 0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color(red: 0.58, green: 0.39, blue: 0.70).opacity(0.32))
                    .frame(width: proxy.size.width * 1.05)
                    .blur(radius: 60)
                    .offset(x: proxy.size.width * 0.30, y: -proxy.size.height * 0.24)

                Image(systemName: "person.crop.rectangle")
                    .font(.system(size: min(proxy.size.width * 0.55, 220), weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.09))
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    private var stageScrims: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0.58), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)

            Spacer()

            LinearGradient(
                colors: [.clear, .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 330)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack(spacing: GravitySpacing.space12) {
            circleButton(systemName: "xmark", accessibilityLabel: "Close") {
                HapticFeedback.light.fire()
                coordinator.popCurrentPage()
            }

            Spacer()

            circleButton(
                systemName: "arrow.triangle.2.circlepath.camera",
                accessibilityLabel: "Switch camera",
                isDisabled: !session.isConnected
            ) {
                HapticFeedback.light.fire()
                Task { await session.switchCamera() }
            }
        }
    }

    @ViewBuilder
    private var permissionCard: some View {
        switch session.phase {
        case .idle:
            HStack(spacing: GravitySpacing.space8) {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                Text("Starting camera…")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, GravitySpacing.space16)
            .frame(minHeight: 44)
            .background(.black.opacity(0.48), in: Capsule())

        case .simulator:
            cameraActionCard(
                icon: "iphone.gen3",
                title: "Open this on an iPhone",
                message: session.detail,
                buttonTitle: nil,
                action: {}
            )

        case .failed(let message):
            cameraActionCard(
                icon: session.needsCameraSettings ? "camera.fill" : "exclamationmark.triangle.fill",
                title: session.needsCameraSettings ? "Camera access needed" : "Studio paused",
                message: message,
                buttonTitle: session.needsCameraSettings ? "Open Settings" : "Try again"
            ) {
                if session.needsCameraSettings,
                   let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    openURL(settingsURL)
                } else {
                    Task {
                        await session.stop()
                        await session.start(product: selectedProduct)
                    }
                }
            }

        case .starting, .live, .applying:
            if !session.statusText.isEmpty {
                HStack(spacing: GravitySpacing.space8) {
                    if session.isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(session.statusText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(.horizontal, GravitySpacing.space16)
                .frame(minHeight: 44)
                .background(.black.opacity(0.48), in: Capsule())
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    private func cameraActionCard(
        icon: String,
        title: String,
        message: String,
        buttonTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: GravitySpacing.space16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(.white.opacity(0.10), in: Circle())

            VStack(spacing: GravitySpacing.space8) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            if let buttonTitle {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, GravitySpacing.space24)
                        .frame(height: 48)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.96))
            }
        }
        .padding(.horizontal, GravitySpacing.space24)
        .padding(.vertical, GravitySpacing.space24)
        .frame(maxWidth: 320)
        .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
        .transition(.opacity.combined(with: .offset(y: 12)))
    }

    @ViewBuilder
    private var productControls: some View {
        if productRailVisible {
            VStack(alignment: .leading, spacing: GravitySpacing.space16) {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: GravitySpacing.space12) {
                        ForEach(products) { item in
                            productButton(item)
                                .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $carouselProductID, anchor: .center)
                .contentMargins(.horizontal, GravitySpacing.space20, for: .scrollContent)
                .padding(.horizontal, -GravitySpacing.space16)
                .frame(height: 148)

                if let selectedProduct {
                    HStack(alignment: .center, spacing: GravitySpacing.space16) {
                        VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                            Text(selectedProduct.product.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            Text(selectedProduct.product.price)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))
                                .monospacedDigit()
                        }

                        Spacer(minLength: GravitySpacing.space8)

                        Button {
                            HapticFeedback.light.fire()
                            coordinator.pushRoute(
                                .product(
                                    merchantId: selectedProduct.merchant.id,
                                    productId: selectedProduct.product.id
                                )
                            )
                        } label: {
                            Text("View product")
                                .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, GravitySpacing.space16)
                            .frame(height: 44)
                            .background(.white, in: Capsule())
                        }
                        .buttonStyle(PressScaleButtonStyle(scale: 0.96))
                    }
                    .padding(.horizontal, GravitySpacing.space4)
                }
            }
            .transition(.opacity.combined(with: .offset(y: 12)))
        }
    }

    private func productButton(_ item: ResolvedStoryProduct) -> some View {
        let isSelected = item.id == (carouselProductID ?? selectedProduct?.id)

        return Button {
            withAnimation(reduceMotion ? nil : SpringPreset.responsive) {
                carouselProductID = item.id
            }
        } label: {
            Group {
                if let imageURL = item.product.imageURL,
                   let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.white.opacity(0.08)
                                .overlay { ProgressView().tint(.white.opacity(0.6)) }
                        }
                    }
                } else {
                    Color.white.opacity(0.08)
                }
            }
            .frame(width: 148, height: 148)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.white : Color.white.opacity(0.18),
                        lineWidth: isSelected ? 3 : 0.5
                    )
            }
            .shadow(color: .black.opacity(isSelected ? 0.28 : 0.12), radius: 10, y: 5)
            .scaleEffect(isSelected ? 1 : 0.96)
            .animation(reduceMotion ? nil : SpringPreset.responsive, value: isSelected)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.96))
        .accessibilityLabel(
            "\(DecartProductMode(product: item) == .wearable ? "Try on" : "Place") "
                + "\(item.product.title) from \(item.merchant.displayName)"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func circleButton(
        systemName: String,
        accessibilityLabel: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(isDisabled ? 0.34 : 1))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.30), in: Circle())
                .overlay { Circle().strokeBorder(.white.opacity(0.12), lineWidth: 0.5) }
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.96))
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct FalRTCVideoView: UIViewRepresentable {
    let track: LKRTCVideoTrack
    let mirrored: Bool

    final class Coordinator {
        weak var track: LKRTCVideoTrack?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> LKRTCMTLVideoView {
        let view = LKRTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFill
        view.backgroundColor = .black
        context.coordinator.track = track
        track.add(view)
        applyMirror(to: view)
        return view
    }

    func updateUIView(_ view: LKRTCMTLVideoView, context: Context) {
        if context.coordinator.track !== track {
            context.coordinator.track?.remove(view)
            context.coordinator.track = track
            track.add(view)
        }
        view.videoContentMode = .scaleAspectFill
        applyMirror(to: view)
    }

    static func dismantleUIView(_ view: LKRTCMTLVideoView, coordinator: Coordinator) {
        coordinator.track?.remove(view)
        coordinator.track = nil
    }

    private func applyMirror(to view: LKRTCMTLVideoView) {
        view.transform = mirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    }
}

#Preview {
    @Previewable @Namespace var namespace
    NavigationStack {
        TryOnStudioPage(namespace: namespace)
    }
    .environment(NavigationCoordinator())
}
