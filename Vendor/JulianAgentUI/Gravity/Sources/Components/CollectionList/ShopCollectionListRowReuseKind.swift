public struct ShopCollectionListRowReuseKind: Hashable, Sendable {
    public enum HostingMode: Hashable, Sendable {
        case configuration
        case persistentHostingController
    }

    public static let `default` = ShopCollectionListRowReuseKind("default")

    let rawValue: String
    let hostingMode: HostingMode

    public init(
        _ rawValue: StaticString,
        hostingMode: HostingMode = .configuration
    ) {
        self.rawValue = String(describing: rawValue)
        self.hostingMode = hostingMode
    }
}

public protocol ShopCollectionListReusableItem {
    var collectionListReuseKind: ShopCollectionListRowReuseKind { get }
}
