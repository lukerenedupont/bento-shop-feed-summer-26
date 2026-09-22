import SwiftUI
import Gravity
import UIKit

enum ShopRootTab: String, CaseIterable, Hashable, Sendable {
    case home
    case aiSearch
    case search
    case orders

    var title: String {
        switch self {
        case .home:
            localizedString("MainNavigationTabs.Home")
        case .aiSearch:
            localizedString("MainNavigationTabs.Agent")
        case .search:
            localizedString("MainNavigationTabs.Explore")
        case .orders:
            localizedString("MainNavigationTabs.Orders")
        }
    }

    var icon: GravityIconName {
        switch self {
        case .home:
            .navigationHomeFilled
        case .aiSearch:
            .navigationSearch
        case .search:
            .navigationCategoriesFilled
        case .orders:
            .orderFilled
        }
    }
}

extension ShopRootTab {
    /// Tabs visible in the floating tab bar. Agent is visible only when RN's
    /// `useNativeAgent()` equivalent is true (`FLAG_SHOP_AGENT_NATIVE_4_TABS` on and
    /// killswitch off). When Agent is disabled, Explore takes over the lens / old-search
    /// role — mirroring the RN agent-off layout (`MainNavigator` drops `Agent` and
    /// re-skins `Search`).
    static func visibleTabs(isNativeAgentEnabled: Bool) -> [ShopRootTab] {
        isNativeAgentEnabled ? allCases : [.home, .search, .orders]
    }

    /// The tab to actually render for `selectedTab`. When Agent is disabled, a selection of
    /// `aiSearch` — e.g. a deep link or programmatic `openRoot` that lands there while the tab
    /// is hidden — resolves to the old Search/Explore entry instead of the hidden tab.
    static func visibleSelection(for selectedTab: ShopRootTab, isNativeAgentEnabled: Bool) -> ShopRootTab {
        visibleTabs(isNativeAgentEnabled: isNativeAgentEnabled).contains(selectedTab) ? selectedTab : .search
    }

    /// Tab bar icon accounting for the Agent gate: when Agent is disabled, Explore shows the
    /// lens icon instead of the categories icon.
    func icon(
        isNativeAgentEnabled: Bool,
        usesSearchIconForExplore: Bool = false
    ) -> GravityIconName {
        if self == .search, isNativeAgentEnabled == false || usesSearchIconForExplore {
            return .navigationSearch
        }
        return icon
    }
}

