import SwiftUI
import Testing
import UIKit
@testable import Gravity

@MainActor
struct ShopMenuAccessibilityTests {
    private func presentingButton(
        accessibilityLabel: String?,
        accessibilityIdentifier: String? = nil,
        userInterfaceStyle: UIUserInterfaceStyle = .unspecified,
        items: [ShopContextMenuItem] = [ShopContextMenuItem("Archive") {}]
    ) -> ShopMenuReportingButton {
        let representable = ShopMenuPresentingButton(
            items: items,
            label: SwiftUI.Text("Label"),
            accessibilityLabel: accessibilityLabel,
            accessibilityIdentifier: accessibilityIdentifier,
            userInterfaceStyle: userInterfaceStyle,
            onOpen: nil,
            onClose: nil
        )
        let button = ShopMenuReportingButton(type: .custom)
        representable.configure(button, isEnabled: true)
        return button
    }

    @Test
    func namedTriggerOwnsAccessibilityIdentity() {
        let button = presentingButton(
            accessibilityLabel: "More options",
            accessibilityIdentifier: "OrdersHeaderOverflowMenuButton"
        )

        #expect(button.isAccessibilityElement)
        #expect(button.accessibilityLabel == "More options")
        #expect(button.accessibilityIdentifier == "OrdersHeaderOverflowMenuButton")
        #expect(button.accessibilityTraits == .button)
    }

    @Test
    func namedTriggerOptsIntoLargeContentViewer() {
        let button = presentingButton(accessibilityLabel: "More options")

        #expect(button.showsLargeContentViewer)
        #expect(button.largeContentTitle == "More options")
    }

    @Test
    func unnamedTriggerLeavesAccessibilityToTheLabelView() {
        let button = presentingButton(accessibilityLabel: nil)

        #expect(button.isAccessibilityElement == false)
        #expect(button.showsLargeContentViewer == false)
        #expect(button.largeContentTitle == nil)
    }

    @Test
    func unnamedTriggerHostedLabelHasButtonTrait() {
        let button = presentingButton(accessibilityLabel: nil)

        #expect(button.hostedLabelAccessibilityTraits.contains(.isButton))
    }

    @Test
    func triggerCarriesItsOwnLargeContentViewerInteraction() {
        let button = presentingButton(accessibilityLabel: "More options")
        let interactions = button.interactions.compactMap { $0 as? UILargeContentViewerInteraction }

        #expect(interactions.count == 1)
    }

    @Test
    func triggerWithoutItemsIsDisabled() {
        let button = presentingButton(accessibilityLabel: "More options", items: [])

        #expect(button.isEnabled == false)
    }

    @Test
    func unchangedPresentationReusesMenuWhileRefreshingActions() throws {
        var selectedAction = ""
        let button = presentingButton(
            accessibilityLabel: "More options",
            items: [ShopContextMenuItem("Archive", id: "archive") { selectedAction = "first" }]
        )
        let originalMenu = try #require(button.menu)

        let updatedRepresentable = ShopMenuPresentingButton(
            items: [ShopContextMenuItem("Archive", id: "archive") { selectedAction = "latest" }],
            label: SwiftUI.Text("Label"),
            accessibilityLabel: "More options",
            onOpen: nil,
            onClose: nil
        )
        updatedRepresentable.configure(button, isEnabled: true)
        button.performMenuAction(at: 0)

        #expect(button.menu === originalMenu)
        #expect(selectedAction == "latest")
    }

    @Test
    func duplicateIDsDispatchEachOccurrenceToItsOwnAction() {
        var selectedActions: [String] = []
        let button = presentingButton(
            accessibilityLabel: "More options",
            items: [
                ShopContextMenuItem("Archive", id: "duplicate") { selectedActions.append("first") },
                ShopContextMenuItem("Archive", id: "duplicate") { selectedActions.append("second") },
            ]
        )

        button.performMenuAction(at: 0)
        button.performMenuAction(at: 1)

        #expect(selectedActions == ["first", "second"])
    }

    @Test
    func changedPresentationRebuildsMenu() throws {
        let button = presentingButton(
            accessibilityLabel: "More options",
            items: [ShopContextMenuItem("Archive", id: "archive") {}]
        )
        let originalMenu = try #require(button.menu)

        let updatedRepresentable = ShopMenuPresentingButton(
            items: [ShopContextMenuItem("Delete", id: "archive", role: .destructive) {}],
            label: SwiftUI.Text("Label"),
            accessibilityLabel: "More options",
            onOpen: nil,
            onClose: nil
        )
        updatedRepresentable.configure(button, isEnabled: true)
        let updatedMenu = try #require(button.menu)

        #expect(updatedMenu !== originalMenu)
        #expect(button.menuItemPresentations == [
            ShopMenuItemPresentation(
                item: ShopContextMenuItem("Delete", id: "archive", role: .destructive) {}
            ),
        ])
    }

    @Test
    func triggerAppliesUIKitInterfaceStyle() {
        let button = presentingButton(
            accessibilityLabel: "More options",
            userInterfaceStyle: .light
        )

        #expect(button.overrideUserInterfaceStyle == .light)
    }
}
