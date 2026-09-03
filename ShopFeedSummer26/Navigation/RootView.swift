import SwiftUI

/// Root container: tab-based navigation with persistent bottom nav bar.
struct RootView: View {
    @State private var coordinator = NavigationCoordinator()
    @Namespace private var namespace

    var body: some View {
        ZStack {
            // Content for the selected tab
            switch coordinator.selectedPage {
            case 0:
                NavigationStack(path: $coordinator.homePath) {
                    HomePage(namespace: namespace)
                        .navigationDestination(for: HomeRoute.self) { route in
                            destinations(for: route)
                        }
                }
            case 1:
                NavigationStack(path: $coordinator.accountPath) {
                    DeliveriesPage(namespace: namespace)
                        .navigationDestination(for: HomeRoute.self) { route in
                            destinations(for: route)
                        }
                }
            case 2:
                NavigationStack(path: $coordinator.explorePath) {
                    ExplorePage()
                        .navigationDestination(for: HomeRoute.self) { route in
                            destinations(for: route)
                        }
                }
            case 3:
                NavigationStack(path: $coordinator.searchPath) {
                    SearchPage()
                        .navigationDestination(for: HomeRoute.self) { route in
                            destinations(for: route)
                        }
                }
            default:
                EmptyView()
            }

            // Bottom nav bar — always on top, pinned to bottom edge
            if coordinator.showNavBar {
                VStack {
                    Spacer()
                    BottomNavBar()
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

        }
        .environment(coordinator)
#if DEBUG
        // Dev/demo shortcut: `simctl launch … -openTryFavesWorld 1` jumps
        // straight into the Try your faves world without feed scrolling.
        .task {
            if ProcessInfo.processInfo.arguments.contains("-openTryFavesWorld") {
                try? await Task.sleep(for: .milliseconds(400))
                coordinator.pushRoute(.tryFavesWorld)
            }
        }
#endif
        .purlInjectable()
    }

    // MARK: - Navigation Destinations

    @ViewBuilder
    private func destinations(for route: HomeRoute) -> some View {
        switch route {
        case .product(let merchantId, let productId):
            ProductPage(merchantId: merchantId, productId: productId, namespace: namespace)
        case .store(let merchantId):
            StorePage(merchantId: merchantId, namespace: namespace)
        case .story(let storyId, let sourceId):
            StoryTopicPage(
                storyID: storyId,
                namespace: namespace,
                transitionSourceID: sourceId
            )
        case .topicExpanded(let topicId, let sourceStoryId):
            StoryTopicPage(
                storyID: sourceStoryId,
                namespace: namespace,
                contextTopicID: topicId,
                transitionSourceID: sourceStoryId
            )
        case .tryOnStudio:
            TryOnStudioPage(namespace: namespace)
        case .tryFavesWorld:
            TryFavesWorldPage(namespace: namespace)
        case .tryFavesProduct(let variantID):
            if let garment = TryFavesCatalog.garment(for: variantID) {
                ProductPage(
                    agentProduct: garment.agentProduct,
                    transitionID: garment.productID,
                    namespace: namespace
                )
            }
        case .deliveries:
            DeliveriesPage(namespace: namespace)
        case .deliveryDetail(let deliveryId):
            DeliveryDetailPage(deliveryId: deliveryId, namespace: namespace)
        case .account:
            AccountPage(namespace: namespace)
        case .explore:
            ExplorePage()
        }
    }
}
