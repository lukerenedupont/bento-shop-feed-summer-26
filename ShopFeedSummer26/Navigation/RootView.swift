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
                    HomePage()
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
            }
        }
        .environment(coordinator)
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
        case .story(let storyId):
            StoryTopicPage(storyID: storyId)
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
