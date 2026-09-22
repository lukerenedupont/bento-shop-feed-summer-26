import SwiftUI
import Gravity
import UIKit

func shopAgentMessageContextSummary(for contextItems: [ShopAgentMessageContextItem]) -> String? {
    let titles = contextItems.compactMap { item in
        switch item.type {
        case .product:
            item.title.nonEmpty ?? item.productID.nonEmpty ?? item.id.nonEmpty
        case .shop:
            item.name.nonEmpty ?? item.shopID.nonEmpty ?? item.id.nonEmpty
        case .order:
            item.title.nonEmpty ?? item.orderID.nonEmpty ?? item.id.nonEmpty
        case .image:
            item.title.nonEmpty ?? item.imageID.nonEmpty ?? item.id.nonEmpty
        case .page:
            item.screen.nonEmpty ?? item.title.nonEmpty ?? item.id.nonEmpty
        }
    }

    guard titles.isEmpty == false else { return nil }
    return titles.joined(separator: ", ")
}
