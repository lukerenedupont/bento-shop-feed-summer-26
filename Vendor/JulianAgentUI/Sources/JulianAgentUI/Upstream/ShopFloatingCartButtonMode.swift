import SwiftUI
import Gravity
import UIKit

enum ShopFloatingCartButtonMode: Equatable {
    case activeCart
    case savedForLaterOnly

    /// RN parity: `FloatingBottomTabBar` marks the cart button as saved-for-later-only only when
    /// there are no active carts, no optimistic add-to-cart reveal, and at least one SFL item.
    static func resolve(
        hasActiveCarts: Bool,
        hasSavedForLaterItems: Bool,
        isShowingOptimistically: Bool
    ) -> ShopFloatingCartButtonMode {
        if hasActiveCarts == false,
           hasSavedForLaterItems,
           isShowingOptimistically == false {
            return .savedForLaterOnly
        }

        return .activeCart
    }
}

