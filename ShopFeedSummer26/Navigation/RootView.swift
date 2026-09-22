import SwiftUI
import JulianAgentUI

/// Root container: tab-based navigation with persistent bottom nav bar.
struct RootView: View {
    @State private var coordinator = NavigationCoordinator()
    @State private var authService = AuthService.shared
    @AppStorage("utilityBeltExtendoEnabled") private var utilityBeltExtendoEnabled = true
    @Namespace private var namespace

    var body: some View {
        ZStack {
            // Content for the selected tab
            switch coordinator.selectedPage {
            case 0:
                NavigationStack(path: $coordinator.homePath) {
                    HomePage(
                        namespace: namespace,
                        utilityBeltVisible: coordinator.utilityBeltVisible
                    )
                        .onAppear { coordinator.libraryShell.context = .home }
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
                    Group {
                        if ShopCanvasLibrary.isEnabled {
                            LibraryJulianSearchPage(state: coordinator.julianShell) { product in
                                guard let merchantID = product.merchantIDs.first else { return }
                                coordinator.pushRoute(.product(merchantId: merchantID, productId: product.nativeID))
                            }
                        } else {
                            SearchPage()
                        }
                    }
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

            if ShopCanvasLibrary.isEnabled, coordinator.julianShell.isConversationPresented {
                JulianConversationSurface(state: coordinator.julianShell) {
                    if authService.hasSession {
                        AgentConversationView(
                            query: coordinator.agentInitialQuery,
                            externalControl: coordinator.agentConversationControl,
                            usesExternalComposer: true,
                            onStreamingChanged: { coordinator.julianShell.isAgentStreaming = $0 },
                            onDismiss: coordinator.julianShell.closeConversation
                        )
                    } else {
                        LibraryAgentSignInView(authService: authService)
                    }
                }
            }

            // Julian's persistent UIKit owner includes tabs, draft curtain, input and follow-up.
            if ShopCanvasLibrary.isEnabled, coordinator.showNavBar {
                JulianNavigationHost(state: coordinator.julianShell)
                    .environment(
                        \.colorScheme,
                        coordinator.selectedPage == 0
                            && coordinator.julianShell.prefersDarkChrome
                            && !coordinator.julianShell.searchActive
                            && !coordinator.julianShell.isConversationPresented
                            ? .dark
                            : .light
                    )
            }

            if !ShopCanvasLibrary.isEnabled, coordinator.showNavBar {
                VStack {
                    Spacer()
                    BottomNavBar()
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

        }
        .environment(coordinator)
        .ignoresSafeArea(.keyboard)
        .onAppear {
            coordinator.julianShell.avatar = UIImage(named: "luke-avatar")
            coordinator.julianShell.onSelectPage = { page in coordinator.navigateToPage(page) }
            coordinator.julianShell.onOpenCart = { coordinator.navigateToPage(4) }
            coordinator.julianShell.onFavorites = { coordinator.navigateToPage(5) }
            coordinator.julianShell.onInitialAgentSubmit = { query, _ in
                coordinator.agentInitialQuery = query
            }
            coordinator.julianShell.onAgentFollowUp = coordinator.agentConversationControl.submit
            coordinator.julianShell.onStopAgent = coordinator.agentConversationControl.stop
            coordinator.updateJulianContext(coordinator.libraryShell.context)
        }
        .onChange(of: coordinator.libraryShell.context.id) { _, _ in
            coordinator.updateJulianContext(coordinator.libraryShell.context)
        }
        .onChange(of: coordinator.selectedPage) { _, page in
            coordinator.libraryShell.context = .home
            coordinator.julianShell.selectedPage = page
            if page != 0 {
                coordinator.julianShell.onAccount = { coordinator.pushRoute(.account) }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { coordinator.julianShell.showsUtilityBeltControls },
                set: { coordinator.julianShell.showsUtilityBeltControls = $0 }
            )
        ) {
            UtilityBeltControlsSheet(
                preferences: UtilityBeltPreferences.shared,
                isVisible: Binding(
                    get: { coordinator.utilityBeltVisible },
                    set: { coordinator.utilityBeltVisible = $0 }
                ),
                extendoEnabled: $utilityBeltExtendoEnabled,
                feedProductCarouselsVisible: Binding(
                    get: { coordinator.feedProductCarouselsVisible },
                    set: { coordinator.feedProductCarouselsVisible = $0 }
                )
            )
            .environment(\.colorScheme, .light)
        }
#if DEBUG
        // Dev/demo shortcut: `simctl launch … -openTryFavesWorld 1` jumps
        // straight into the Try your faves world without feed scrolling.
        .task {
            if ProcessInfo.processInfo.arguments.contains("-previewJulianAsk") {
                try? await Task.sleep(for: .milliseconds(500))
                coordinator.julianShell.openAsk()
            } else if ProcessInfo.processInfo.arguments.contains("-openTryFavesWorld") {
                try? await Task.sleep(for: .milliseconds(400))
                coordinator.pushRoute(.tryFavesWorld)
            } else if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-previewStory"),
                      ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
                let storyID = ProcessInfo.processInfo.arguments[index + 1]
                guard PersonalizedFeedCatalog.current.stories.contains(where: { $0.id == storyID }) else { return }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                coordinator.pushRoute(.story(storyId: storyID, sourceId: storyID))
            }
        }
#endif
        .purlInjectable()
    }

    // MARK: - Navigation Destinations

    @ViewBuilder
    private func destinations(for route: HomeRoute) -> some View {
        destinationContent(for: route)
            .onAppear { coordinator.libraryShell.context = askContext(for: route) }
    }

    private func askContext(for route: HomeRoute) -> LibraryAskContext {
        switch route {
        case .product(_, let productID): return .product(productID)
        case .store(let merchantID): return .merchant(merchantID)
        case .customStory(let story, _): return .world(story)
        case .story(let storyID, _), .topicExpanded(_, let storyID):
            return ShopCanvasLibrary.stories.first { $0.id == storyID }.map(LibraryAskContext.world) ?? .home
        default: return .home
        }
    }

    @ViewBuilder
    private func destinationContent(for route: HomeRoute) -> some View {
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
        case .customStory(let story, let sourceId):
            StoryTopicPage(
                storyID: story.id,
                namespace: namespace,
                transitionSourceID: sourceId,
                storyOverride: story,
                merchantOverride: SampleMerchant.all
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

private struct LibraryAgentSignInView: View {
    @Bindable var authService: AuthService

    var body: some View {
        ContentUnavailableView {
            Label("Sign in to Shop Agent", systemImage: "person.crop.circle.badge.checkmark")
        } description: {
            Text("Search works with the curated library. Sign in to send this saved Ask draft to the live Shop Agent service.")
        } actions: {
            Button(authService.state == .signingIn ? "Opening Shop sign-in…" : "Sign in to Shop") {
                Task { await authService.signIn() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authService.state == .signingIn)
            .accessibilityIdentifier("agent-sign-in")

            if case .error(let message) = authService.state {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}
