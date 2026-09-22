import SwiftUI
import Gravity
import UIKit

// Standalone data/service boundaries. Visual components remain in Upstream/.
func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
    let value = Bundle.module.localizedString(forKey: key, value: key, table: nil)
    return arguments.isEmpty ? value : String(format: value, arguments: arguments)
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
    var shopAgentTrimmedNilIfEmpty: String? { trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
}
extension Optional where Wrapped == String {
    var nonEmpty: String? { self?.nonEmpty }
}

@MainActor @Observable final class ShopCheckoutBlockingPresenter { var isActive = false }

/// The library has no live cart. Empty is a real state, not a fabricated badge or target.
@MainActor @Observable final class ShopCartShellStore {
    struct Snapshot {
        var carts: [String] = []
        var hasSavedForLaterItems = false
        var isCartButtonTargetVisible: Bool { !carts.isEmpty || hasSavedForLaterItems }
    }
    var snapshot = Snapshot()
    var visibleBadgeCount = 0
}
enum ShopCartBadgeCount { static let maxDisplayed = 99 }

struct ShopAgentEmbeddedConversation {
    struct ContextInfo: Equatable {
        let title: String
        var subtitle: String? = nil
        var imageURL: String? = nil
        var icon: GravityIconName? = nil
    }
}

