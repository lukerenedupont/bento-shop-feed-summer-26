import SwiftUI
import Gravity
import UIKit

enum ShopHomeSearchLayout: String, CaseIterable, Sendable {
    static let storageKey = "shop.prototype.home-search-layout"

    case full
    case chip
    case floating
    case tabBar

    var title: String {
        switch self {
        case .full:
            "Full search bar"
        case .chip:
            "Search chip"
        case .floating:
            "Floating search button"
        case .tabBar:
            "Search in tab bar"
        }
    }

    var showsSearchOnHome: Bool { self != .tabBar }
    var usesCompactHomeSearch: Bool { self == .chip || self == .floating }
    var usesSearchIconForExplore: Bool { self == .tabBar }
    var usesSearchToolbarOnOrders: Bool { self != .tabBar }
}

