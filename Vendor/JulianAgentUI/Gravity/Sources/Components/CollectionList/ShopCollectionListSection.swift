/// A section model for `ShopCollectionList`.
///
/// Equality and hashing are intentionally identity-only (`id`). The collection view
/// uses sections as diffable-data-source identifiers, while item/header content
/// changes are detected separately by `ShopCollectionListView` and reconfigured in place.
public struct ShopCollectionListSection<SectionID: Hashable & Sendable, Item: Identifiable & Hashable & Sendable>: Identifiable, Hashable, Sendable where Item.ID: Hashable & Sendable {
    public let id: SectionID
    public var items: [Item]
    public var showsHeader: Bool

    public init(
        id: SectionID,
        items: [Item],
        showsHeader: Bool = false
    ) {
        self.id = id
        self.items = items
        self.showsHeader = showsHeader
    }

    public static func == (
        lhs: ShopCollectionListSection<SectionID, Item>,
        rhs: ShopCollectionListSection<SectionID, Item>
    ) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
