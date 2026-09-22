import SwiftUI
import Gravity
import UIKit

struct ShopAgentMessageContextItem: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let type: ShopAgentMessageContextItemType
    var shopID: String?
    var productID: String?
    var orderID: String?
    var orderUUID: String?
    var orderNumber: String?
    var shopName: String?
    var imageID: String?
    var title: String?
    var subtitle: String?
    var name: String?
    var logoImageURL: String?
    var averageRating: Double?
    var totalRatings: Int?
    var imageURL: String?
    var screen: String?

    init(
        id: String,
        type: ShopAgentMessageContextItemType,
        shopID: String? = nil,
        productID: String? = nil,
        orderID: String? = nil,
        orderUUID: String? = nil,
        orderNumber: String? = nil,
        shopName: String? = nil,
        imageID: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        name: String? = nil,
        logoImageURL: String? = nil,
        averageRating: Double? = nil,
        totalRatings: Int? = nil,
        imageURL: String? = nil,
        screen: String? = nil
    ) {
        self.id = id
        self.type = type
        self.shopID = shopID
        self.productID = productID
        self.orderID = orderID
        self.orderUUID = orderUUID
        self.orderNumber = orderNumber
        self.shopName = shopName
        self.imageID = imageID
        self.title = title
        self.subtitle = subtitle
        self.name = name
        self.logoImageURL = logoImageURL
        self.averageRating = averageRating
        self.totalRatings = totalRatings
        self.imageURL = imageURL
        self.screen = screen
    }

    init(landingItem: ShopAgentLandingContextItem) {
        switch landingItem.type {
        case .shop:
            self.init(
                id: landingItem.id,
                type: .shop,
                shopID: landingItem.id,
                name: landingItem.title ?? landingItem.content
            )
        case .product:
            let productID = landingItem.productID ?? landingItem.id
            self.init(
                id: landingItem.id,
                type: .product,
                productID: productID,
                title: landingItem.title,
                imageURL: landingItem.content
            )
        case .order:
            self.init(id: landingItem.id, type: .order, orderID: landingItem.id)
        case .image:
            self.init(id: landingItem.id, type: .image, imageID: landingItem.id)
        case .page, .currentConversation:
            self.init(id: landingItem.id, type: .page, screen: landingItem.content ?? landingItem.title ?? landingItem.id)
        }
    }
}

