import SwiftUI

/// Shared navigation state: selected page index + independent nav paths per page.
@Observable
final class NavigationCoordinator {
    /// 0 = Home, 1 = Orders/Deliveries, 2 = Explore, 3 = Search,
    /// 4 = Cart, 5 = Favorites
    var selectedPage: Int = 0

    var homePath = NavigationPath()
    var accountPath = NavigationPath()
    var explorePath = NavigationPath()
    var searchPath = NavigationPath()
    var cartPath = NavigationPath()
    var favoritesPath = NavigationPath()

    /// Whether the bottom nav bar shows its blur background.
    var showNavBarBlur: Bool = true

    /// Surface color washed into the progressive blur behind bottom navigation.
    /// Topic feeds set this to their lead-story color; other tabs use white.
    var navBarBlurTint: Color = .white

    /// Whether the bottom nav bar is visible at all.
    var showNavBar: Bool = true

    /// Compatibility hooks used by Home's inline topic/story navigation.
    var topicBackAction: (() -> Void)? = nil
    @ObservationIgnored var inlineStoryHandler: ((String) -> Bool)? = nil

    /// Current scroll offset tracking.
    @ObservationIgnored var scrollOffset: CGFloat = 0

    /// Collapse progress: 0 = fully revealed, 1 = fully collapsed.
    private(set) var navBarCollapse: CGFloat = 0
    @ObservationIgnored private var previousScrollOffset: CGFloat = 0
    @ObservationIgnored private var anchorOffset: CGFloat = 0
    @ObservationIgnored private var scrollingDown: Bool = false
    @ObservationIgnored private var peakScrollOffset: CGFloat = 0

    func resetScrollState() {
        previousScrollOffset = 0
        anchorOffset = 0
        scrollingDown = false
        peakScrollOffset = 0
        scrollOffset = 0
        navBarCollapse = 0
    }

    func updateScrollOffset(_ newOffset: CGFloat) {
        let delta = newOffset - previousScrollOffset
        previousScrollOffset = newOffset
        scrollOffset = newOffset

        guard abs(delta) > 0.5 else { return }

        if delta > 0 {
            peakScrollOffset = max(peakScrollOffset, newOffset)
        }

        if delta < 0 && newOffset > peakScrollOffset - 30 && peakScrollOffset > 50 {
            return
        }

        let nowDown = delta > 0
        if nowDown != scrollingDown {
            scrollingDown = nowDown
            anchorOffset = newOffset
            if !nowDown { peakScrollOffset = 0 }
        }

        let distance = abs(newOffset - anchorOffset)
        let newCollapse: CGFloat
        if scrollingDown {
            newCollapse = distance > 12 ? 1.0 : 0.0
        } else {
            newCollapse = distance > 12 ? 0.0 : 1.0
        }

        if newOffset <= 0 {
            if navBarCollapse != 0 { navBarCollapse = 0 }
        } else if newCollapse != navBarCollapse {
            navBarCollapse = newCollapse
        }
    }

    /// Whether the bottom bar should show its back button.
    var isNavigatedDeep: Bool {
        switch selectedPage {
        case 0: return !homePath.isEmpty || topicBackAction != nil
        case 1: return !accountPath.isEmpty
        case 2: return !explorePath.isEmpty
        case 3: return !searchPath.isEmpty
        case 4: return !cartPath.isEmpty
        case 5: return !favoritesPath.isEmpty
        default: return false
        }
    }

    /// How many views deep the current page's navigation stack is.
    var navigationDepth: Int {
        switch selectedPage {
        case 0: return homePath.count
        case 1: return accountPath.count
        case 2: return explorePath.count
        case 3: return searchPath.count
        case 4: return cartPath.count
        case 5: return favoritesPath.count
        default: return 0
        }
    }

    /// Push a route onto the current page's navigation stack.
    func pushRoute(_ route: HomeRoute) {
        if case .story(let storyID) = route,
           selectedPage == 0,
           homePath.isEmpty,
           let inlineStoryHandler,
           inlineStoryHandler(storyID) {
            return
        }
        switch selectedPage {
        case 0: homePath.append(route)
        case 1: accountPath.append(route)
        case 2: explorePath.append(route)
        case 3: searchPath.append(route)
        case 4: cartPath.append(route)
        case 5: favoritesPath.append(route)
        default: break
        }
    }

    func navigateToPage(_ page: Int) {
        switch selectedPage {
        case 0: homePath = NavigationPath()
        case 1: accountPath = NavigationPath()
        case 2: explorePath = NavigationPath()
        case 3: searchPath = NavigationPath()
        case 4: cartPath = NavigationPath()
        case 5: favoritesPath = NavigationPath()
        default: break
        }
        selectedPage = page
        showNavBarBlur = (page != 3)
        if page != 0 { navBarBlurTint = .white }
    }

    func popCurrentPage() {
        switch selectedPage {
        case 0:
            if !homePath.isEmpty {
                homePath.removeLast()
            } else {
                topicBackAction?()
            }
        case 1: if !accountPath.isEmpty { accountPath.removeLast() }
        case 2: if !explorePath.isEmpty { explorePath.removeLast() }
        case 3: if !searchPath.isEmpty { searchPath.removeLast() }
        case 4: if !cartPath.isEmpty { cartPath.removeLast() }
        case 5: if !favoritesPath.isEmpty { favoritesPath.removeLast() }
        default: break
        }
    }

    /// Switches between sibling destinations without adding another level to
    /// the back stack (for example, adjacent subtopics in the same topic).
    func replaceCurrentRoute(_ route: HomeRoute) {
        switch selectedPage {
        case 0:
            if !homePath.isEmpty { homePath.removeLast() }
            homePath.append(route)
        case 1:
            if !accountPath.isEmpty { accountPath.removeLast() }
            accountPath.append(route)
        case 2:
            if !explorePath.isEmpty { explorePath.removeLast() }
            explorePath.append(route)
        case 3:
            if !searchPath.isEmpty { searchPath.removeLast() }
            searchPath.append(route)
        case 4:
            if !cartPath.isEmpty { cartPath.removeLast() }
            cartPath.append(route)
        case 5:
            if !favoritesPath.isEmpty { favoritesPath.removeLast() }
            favoritesPath.append(route)
        default: break
        }
    }
}
