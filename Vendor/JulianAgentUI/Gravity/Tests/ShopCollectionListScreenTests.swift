import SwiftUI
import Testing
@testable import Gravity

@MainActor
struct ShopCollectionListScreenTests {
    @Test
    func defaultAutomaticInsetsIgnoreContainerTopAndBottomSafeArea() {
        let screen = ShopCollectionListScreen(
            sections: [
                ShopCollectionListSection(id: "section", items: [ScreenTestItem(id: "item-1")]),
            ],
            row: { _ in EmptyView() }
        )

        #expect(screen.ignoredContainerSafeAreaEdges == [.top, .bottom])
    }
}

private struct ScreenTestItem: Identifiable, Hashable, Sendable {
    let id: String
}
