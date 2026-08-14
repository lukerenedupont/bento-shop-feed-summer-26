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
            case 4:
                NavigationStack(path: $coordinator.cartPath) {
                    CartPage()
                        .navigationDestination(for: HomeRoute.self) { route in
                            destinations(for: route)
                        }
                }
            case 5:
                NavigationStack(path: $coordinator.favoritesPath) {
                    FavoritesPage()
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
        .purlInjectable()
#if DEBUG
        // Fast-iteration hook: `simctl launch ... -openTopic birding-gear`
        // (or -openStory / -openProduct) jumps straight to a surface so
        // screenshot loops don't need UI driving.
        .onAppear {
            if let topicID = UserDefaults.standard.string(forKey: "openTopic") {
                coordinator.pushRoute(.topic(topicId: topicID, sourceStoryId: nil))
            } else if let storyID = UserDefaults.standard.string(forKey: "openStory") {
                coordinator.pushRoute(.story(storyId: storyID))
            } else if let productRef = UserDefaults.standard.string(forKey: "openProduct"),
                      let separator = productRef.lastIndex(of: "/"),
                      let productID = Int(productRef[productRef.index(after: separator)...]) {
                // `-openProduct <merchantID>/<productID>`
                coordinator.pushRoute(.product(merchantId: String(productRef[..<separator]), productId: productID))
            }
        }
#endif
    }

    // MARK: - Navigation Destinations

    @ViewBuilder
    private func destinations(for route: HomeRoute) -> some View {
        switch route {
        case .product(let merchantId, let productId):
            ProductPage(merchantId: merchantId, productId: productId, namespace: namespace)
                .floatingBackChip(coordinator)
        case .deepDive(let merchantId, let productId):
            DeepDivePage(merchantId: merchantId, productId: productId)
                .floatingBackChip(coordinator)
        case .store(let merchantId):
            StorePage(merchantId: merchantId, namespace: namespace)
                .floatingBackChip(coordinator)
        case .story(let storyId):
            StoryTopicPage(storyID: storyId)
        case .topic(let topicId, let sourceStoryId):
            // System zoom from the feed card that opened this world; pill-
            // opened topics (no source registered) fall back to a plain push.
            TopicPage(topicId: topicId)
                .navigationTransition(.zoom(sourceID: "topic-hero-\(sourceStoryId ?? topicId)", in: namespace))
        case .deliveries:
            DeliveriesPage(namespace: namespace)
                .floatingBackChip(coordinator)
        case .deliveryDetail(let deliveryId):
            DeliveryDetailPage(deliveryId: deliveryId, namespace: namespace)
                .floatingBackChip(coordinator)
        case .account:
            AccountPage(namespace: namespace)
        case .explore:
            ExplorePage()
        }
    }
}

extension View {
    /// The single back affordance for pushed pages that hide the system nav
    /// bar: a floating chip at the top leading edge. Back never lives in the
    /// bottom bar — topics and stories add their own chip (they also manage
    /// nav-bar visibility and tint on pop).
    func floatingBackChip(_ coordinator: NavigationCoordinator) -> some View {
        safeAreaBar(edge: .top) {
            HStack {
                FloatingBackButton {
                    coordinator.popCurrentPage()
                }
                Spacer()
            }
            .padding(.horizontal, GravitySpacing.space16)
            .padding(.vertical, GravitySpacing.space4)
        }
    }
}
