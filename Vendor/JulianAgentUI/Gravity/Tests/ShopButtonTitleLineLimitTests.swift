import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Gravity

struct ShopButtonTitleLineLimitTests {
    @Test
    func defaultCallersKeepOneLineAtEverySize() {
        #expect(shopButtonTitleLineLimit(
            isAccessibilitySize: false,
            wrapsTitleAtAccessibilitySizes: false
        ) == 1)
        #expect(shopButtonTitleLineLimit(
            isAccessibilitySize: true,
            wrapsTitleAtAccessibilitySizes: false
        ) == 1)
    }

    @Test
    func optedInCallersKeepOneLineAtStandardSizes() {
        #expect(shopButtonTitleLineLimit(
            isAccessibilitySize: false,
            wrapsTitleAtAccessibilitySizes: true
        ) == 1)
    }

    @Test
    func optedInCallersWrapAtAccessibilitySizes() {
        #expect(shopButtonTitleLineLimit(
            isAccessibilitySize: true,
            wrapsTitleAtAccessibilitySizes: true
        ) == nil)
    }

    @MainActor
    @Test
    func stateCardActionsPreserveDefaultAndGrowWhenWrappingIsEnabled() {
        let title = "Try loading all of your past orders again"
        let defaultAction = ShopStateCardAction(title: title, action: {})
        let wrappingAction = ShopStateCardAction(
            title: title,
            wrapsTitleAtAccessibilitySizes: true,
            action: {}
        )

        #expect(defaultAction.wrapsTitleAtAccessibilitySizes == false)
        #expect(wrappingAction.wrapsTitleAtAccessibilitySizes)
        #expect(
            stateCardSize(action: wrappingAction).height > stateCardSize(action: defaultAction).height
        )
    }

    @MainActor
    private func stateCardSize(action: ShopStateCardAction) -> CGSize {
        UIHostingController(
            rootView: ShopStateCard(
                icon: .order,
                title: "Orders",
                actions: [action]
            )
            .environment(\.dynamicTypeSize, .accessibility3)
        )
        .sizeThatFits(in: CGSize(width: 180, height: 1_000))
    }
}
