import SwiftUI

/// Shared navigation state: selected page index + independent nav paths per page.
@Observable
final class NavigationCoordinator {
    /// 0 = Home, 1 = Orders/Deliveries, 2 = Explore, 3 = Search
    var selectedPage: Int = 0

    var homePath = NavigationPath()
    var accountPath = NavigationPath()
    var explorePath = NavigationPath()
    var searchPath = NavigationPath()

    /// Whether the bottom nav bar shows its blur background.
    var showNavBarBlur: Bool = true

    /// Surface color washed into the progressive blur behind bottom navigation.
    /// Topic feeds set this to their lead-story color; other tabs use white.
    var navBarBlurTint: Color = .white

    /// Whether the bottom nav bar is visible at all.
    var showNavBar: Bool = true

    /// Back action for the home tab's inline topic feed. Topic selection is
    /// HomePage state rather than a pushed route, so the bottom nav's back
    /// button uses this hook to leave a topic and return to For You.
    var topicBackAction: (() -> Void)? = nil

    /// Inline handler for story drill-ins at the home tab's root. HomePage
    /// registers this so subcategories swap in place — keeping the avatar and
    /// topic pills — instead of pushing a separate destination. Returns true
    /// when the story was handled inline.
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

    /// Whether the currently visible page has a pushed sub-page.
    var isNavigatedDeep: Bool {
        switch selectedPage {
        case 0: return !homePath.isEmpty || topicBackAction != nil
        case 1: return !accountPath.isEmpty
        case 2: return !explorePath.isEmpty
        case 3: return !searchPath.isEmpty
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
        default: return 0
        }
    }

    /// Push a route onto the current page's navigation stack.
    func pushRoute(_ route: HomeRoute) {
        // Story drill-ins from the home root stay inline so the top bar
        // (avatar + topic pills) persists across subcategory pages.
        if case .story(let storyId) = route,
           selectedPage == 0, homePath.isEmpty,
           let inlineStoryHandler, inlineStoryHandler(storyId) {
            return
        }
        switch selectedPage {
        case 0: homePath.append(route)
        case 1: accountPath.append(route)
        case 2: explorePath.append(route)
        case 3: searchPath.append(route)
        default: break
        }
    }

    func navigateToPage(_ page: Int) {
        switch selectedPage {
        case 0: homePath = NavigationPath()
        case 1: accountPath = NavigationPath()
        case 2: explorePath = NavigationPath()
        case 3: searchPath = NavigationPath()
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
        default: break
        }
    }
}
