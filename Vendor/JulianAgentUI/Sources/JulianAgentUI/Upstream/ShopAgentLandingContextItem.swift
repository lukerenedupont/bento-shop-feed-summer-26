import SwiftUI
import Gravity
import UIKit

enum ShopAgentLandingContextItemType: String, Hashable, Sendable {
    case shop
    case product
    case order
    case image
    case page
    case currentConversation = "current_conversation"
}

struct ShopAgentLandingContextItem: Identifiable, Hashable, Sendable {
    let id: String
    let type: ShopAgentLandingContextItemType
    var productID: String?
    var title: String?
    var content: String?

    init(
        id: String,
        type: ShopAgentLandingContextItemType,
        productID: String? = nil,
        title: String? = nil,
        content: String? = nil
    ) {
        self.id = id
        self.type = type
        self.productID = productID
        self.title = title
        self.content = content
    }

    static func product(productID: String) -> ShopAgentLandingContextItem? {
        guard let normalizedProductID = productID.shopAgentTrimmedNilIfEmpty else {
            return nil
        }

        return ShopAgentLandingContextItem(
            id: normalizedProductID,
            type: .product,
            productID: normalizedProductID
        )
    }
}

