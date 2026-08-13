import SwiftUI

/// Full-screen deliveries page with a dark video background and a native
/// `FloatingPanel`-backed bottom sheet.
struct DeliveriesPage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @Environment(NavigationCoordinator.self) private var coordinator
    var namespace: Namespace.ID

    private var activeDeliveries: [DeliveryItem] { DeliveryItem.active }
    private var pastDeliveries: [DeliveryItem] { DeliveryItem.past }

    var body: some View {
        FloatingPanelSheet(
            anchors: [
                .tip(fraction: 0.50),
                .full(topInset: 54),
            ],
            initialAnchor: .tip,
            contentTopInset: 16,
            background: { backgroundLayer },
            content: { sheetContent }
        )
        .ignoresSafeArea(.container, edges: .all)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTransition(.zoom(sourceID: "deliveries", in: namespace))
        .purlInjectable()
    }

    // MARK: - Background layer (map video + scrim)

    private static let mapVideoURL: URL? = {
        guard let asset = NSDataAsset(name: "map") else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("map.mp4")
        if !FileManager.default.fileExists(atPath: tempURL.path) {
            try? asset.data.write(to: tempURL)
        }
        return tempURL
    }()

    private var backgroundLayer: some View {
        ZStack {
            Color(hex: 0x021626)
                .ignoresSafeArea()

            if let videoURL = Self.mapVideoURL {
                LoopingVideoPlayer(url: videoURL, loops: false)
                    .ignoresSafeArea()
            }

            // Soft top→bottom scrim so the map fades into the panel surface.
            LinearGradient(
                colors: [Color(hex: 0x021626).opacity(PurlTune.value("Pages/DeliveriesPage.swift:opacity:_:53:55", default: 0.15)), Color(hex: 0x021626).opacity(PurlTune.value("Pages/DeliveriesPage.swift:opacity:_:53:91", default: 0.9))],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Sheet content

    private var sheetContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GravitySpacing.space16) {
                // Header — matches Explore page styling (header 28pt Bold, 44pt min height).
                // The grabber lives in FloatingPanel's surfaceView above this.
                HStack(spacing: GravitySpacing.space8) {
                    Text("Orders")
                        .gravityTextStyle(GravityTypography.header)
                        .foregroundStyle(PurlTune.token("Pages/DeliveriesPage.swift:foregroundStyle:_:72:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    Spacer()
                    GravityIcon.overflow.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: PurlTune.value("Pages/DeliveriesPage.swift:frame:width:77:39", default: 20), height: PurlTune.value("Pages/DeliveriesPage.swift:frame:height:77:124", default: 20))
                        .foregroundStyle(PurlTune.token("Pages/DeliveriesPage.swift:foregroundStyle:_:78:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        .frame(width: PurlTune.value("Pages/DeliveriesPage.swift:frame:width:79:39", default: 44), height: PurlTune.value("Pages/DeliveriesPage.swift:frame:height:79:124", default: 44))
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .frame(minHeight: PurlTune.value("Pages/DeliveriesPage.swift:frame:minHeight:82:35", default: 44))
                .padding(.bottom, -GravitySpacing.space4)

                ForEach(activeDeliveries) { item in
                    DeliveryCard(item: item) {
                        navigateToDeliveryDetail(deliveryId: item.id)
                    }
                    .matchedTransitionSource(id: item.id, in: namespace)
                }

                if !pastDeliveries.isEmpty {
                    pastDeliveriesSection
                }
            }
            .padding(.horizontal, PurlTune.token("Pages/DeliveriesPage.swift:padding:_:96:35", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .padding(.bottom, PurlTune.value("Pages/DeliveriesPage.swift:padding:_:97:31", default: 120))
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, offset in
            coordinator.updateScrollOffset(offset)
        }
    }

    // MARK: - Past Deliveries Section

    private var pastDeliveriesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gravity: sectionTitle (20pt semibold) — heads the past deliveries list.
            Text("Past deliveries")
                .gravityTextStyle(GravityTypography.sectionTitle)
                .foregroundStyle(PurlTune.token("Pages/DeliveriesPage.swift:foregroundStyle:_:114:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                .padding(.bottom, PurlTune.token("Pages/DeliveriesPage.swift:padding:_:115:35", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))

            ForEach(Array(pastDeliveries.enumerated()), id: \.element.id) { index, item in
                PastDeliveryRow(item: item)

                if index < pastDeliveries.count - 1 {
                    Rectangle()
                        .fill(PurlTune.token("Pages/DeliveriesPage.swift:fill:_:122:31", default: GravityColors.borderSecondary, options: GravityColors.purlTuneColorOptions))
                        .frame(height: PurlTune.value("Pages/DeliveriesPage.swift:frame:height:123:40", default: 0.5))
                }
            }
        }
    }

    // MARK: - Navigation

    private func navigateToDeliveryDetail(deliveryId: String) {
        coordinator.pushRoute(.deliveryDetail(deliveryId: deliveryId))
    }
}

#Preview {
    @Previewable @Namespace var ns
    NavigationStack {
        DeliveriesPage(namespace: ns)
    }
    .environment(NavigationCoordinator())
}
