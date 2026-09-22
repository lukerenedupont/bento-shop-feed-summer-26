import UIKit

public struct ShopCollectionListCustomLayout {
    public let id: String
    let makeLayout: @MainActor () -> UICollectionViewLayout

    public init(
        id: String,
        makeLayout: @escaping @MainActor () -> UICollectionViewLayout
    ) {
        self.id = id
        self.makeLayout = makeLayout
    }
}
