import Foundation

struct ShopAskStarter: Identifiable, Equatable {
    let id: String
    let title: String
    let query: String
    let contextItems: [ShopAgentMessageContextItem]
    let images: [ShopRemoteImageModel]
    let keyColorHex: String?
}
