import SwiftUI
import Testing
import UIKit
@testable import Gravity

@MainActor
struct ShopChipAccessibilityLayoutTests {
    private let tolerance: CGFloat = 1
    private let wideFittingWidth: CGFloat = 2_000

    @Test
    func reflowRequiresTitleAccessibilitySizeAndValidMaximum() {
        #expect(!shopChipUsesAccessibilityReflow(
            hasTitle: true,
            isAccessibilitySize: false,
            maximumWidth: 200
        ))
        #expect(!shopChipUsesAccessibilityReflow(
            hasTitle: true,
            isAccessibilitySize: true,
            maximumWidth: nil
        ))
        #expect(!shopChipUsesAccessibilityReflow(
            hasTitle: false,
            isAccessibilitySize: true,
            maximumWidth: 200
        ))
        #expect(!shopChipUsesAccessibilityReflow(
            hasTitle: true,
            isAccessibilitySize: true,
            maximumWidth: 0
        ))
        #expect(!shopChipUsesAccessibilityReflow(
            hasTitle: true,
            isAccessibilitySize: true,
            maximumWidth: .infinity
        ))
        #expect(shopChipUsesAccessibilityReflow(
            hasTitle: true,
            isAccessibilitySize: true,
            maximumWidth: 200
        ))
    }

    @Test
    func activeReflowUsesTheRequestedTitleLineLimit() {
        #expect(shopChipTitleLineLimit(usesAccessibilityReflow: false) == 1)
        #expect(shopChipTitleLineLimit(usesAccessibilityReflow: true) == nil)
        #expect(shopChipTitleLineLimit(
            usesAccessibilityReflow: true,
            accessibilityReflowLineLimit: 2
        ) == 2)
        #expect(shopChipTitleLineLimit(
            usesAccessibilityReflow: false,
            accessibilityReflowLineLimit: 2
        ) == 1)
    }

    @Test
    func onlyActiveReflowUsesLeadingTitleAlignment() {
        #expect(shopChipTitleAlignment(usesAccessibilityReflow: false) == .center)
        #expect(shopChipTitleAlignment(usesAccessibilityReflow: true) == .leading)
    }

    @Test
    func onlyActiveReflowAddsTrailingClearance() {
        #expect(shopChipAccessibilityTrailingClearance(usesAccessibilityReflow: false) == 0)
        #expect(
            shopChipAccessibilityTrailingClearance(usesAccessibilityReflow: true)
                == GravitySpacing.space4
        )
    }

    @Test
    func parentWidthProposalsIncludeZeroWidthCompressionProbes() {
        #expect(shopChipAccessibilityAvailableWidth(maximumWidth: 200, proposalWidth: nil) == 200)
        #expect(shopChipAccessibilityAvailableWidth(maximumWidth: 200, proposalWidth: .infinity) == 200)
        #expect(shopChipAccessibilityAvailableWidth(maximumWidth: 200, proposalWidth: 300) == 200)
        #expect(shopChipAccessibilityAvailableWidth(maximumWidth: 200, proposalWidth: 120) == 120)
        #expect(shopChipAccessibilityAvailableWidth(maximumWidth: 200, proposalWidth: 0) == 0)
        #expect(shopChipAccessibilityAvailableWidth(maximumWidth: 200, proposalWidth: -20) == 0)
    }

    @Test
    func labeledMediaKeepsBaseSizeUntilReflowAndThenClamps() {
        #expect(shopChipMediaDimension(
            size: .small,
            isMediaOnly: false,
            usesAccessibilityReflow: false,
            scaledLabeledMediaSize: 100
        ) == GravitySpacing.space24)
        #expect(shopChipMediaDimension(
            size: .large,
            isMediaOnly: false,
            usesAccessibilityReflow: false,
            scaledLabeledMediaSize: 100
        ) == GravitySpacing.space32)

        let grownSmall = shopChipMediaDimension(
            size: .small,
            isMediaOnly: false,
            usesAccessibilityReflow: true,
            scaledLabeledMediaSize: 34
        )
        let grownLarge = shopChipMediaDimension(
            size: .large,
            isMediaOnly: false,
            usesAccessibilityReflow: true,
            scaledLabeledMediaSize: 42
        )
        #expect(grownSmall > GravitySpacing.space24)
        #expect(grownSmall < GravitySpacing.space40)
        #expect(grownLarge > GravitySpacing.space32)
        #expect(grownLarge < GravitySpacing.space48)

        #expect(shopChipMediaDimension(
            size: .small,
            isMediaOnly: false,
            usesAccessibilityReflow: true,
            scaledLabeledMediaSize: 100
        ) == GravitySpacing.space40)
        #expect(shopChipMediaDimension(
            size: .large,
            isMediaOnly: false,
            usesAccessibilityReflow: true,
            scaledLabeledMediaSize: 100
        ) == GravitySpacing.space48)
    }

    @Test
    func mediaOnlyDimensionsNeverAccessibilityScale() {
        #expect(shopChipMediaDimension(
            size: .small,
            isMediaOnly: true,
            usesAccessibilityReflow: true,
            scaledLabeledMediaSize: 100
        ) == 28)
        #expect(shopChipMediaDimension(
            size: .large,
            isMediaOnly: true,
            usesAccessibilityReflow: true,
            scaledLabeledMediaSize: 100
        ) == GravitySpacing.space36)
    }

    @Test
    func customGlassForegroundAppliesOnlyToUnselectedGlass() {
        #expect(shopChipUsesCustomGlassForeground(variant: .glass, isSelected: false))
        #expect(!shopChipUsesCustomGlassForeground(variant: .glass, isSelected: true))
        #expect(!shopChipUsesCustomGlassForeground(variant: .flat, isSelected: false))
        #expect(!shopChipUsesCustomGlassForeground(variant: .flat, isSelected: true))
    }

    @Test
    func nilGlassTintUsesTheRequestedFallbackWhileExplicitTintWins() {
        #expect(shopChipResolvedGlassTint(
            explicitTint: Optional<String>.none,
            fallback: .gravityFill,
            gravityFill: "gravity"
        ) == "gravity")
        #expect(shopChipResolvedGlassTint(
            explicitTint: Optional<String>.none,
            fallback: .none,
            gravityFill: "gravity"
        ) == nil)
        #expect(shopChipResolvedGlassTint(
            explicitTint: "brand",
            fallback: .gravityFill,
            gravityFill: "gravity"
        ) == "brand")
        #expect(shopChipResolvedGlassTint(
            explicitTint: "brand",
            fallback: .none,
            gravityFill: "gravity"
        ) == "brand")
    }

    @Test
    func shortAccessibilityLabelKeepsIntrinsicWidth() {
        let maximumWidth: CGFloat = 260
        let size = measuredSize(
            ShopChip(
                "Sale",
                accessibilityReflowMaximumWidth: maximumWidth
            ) {},
            dynamicTypeSize: .accessibility5
        )

        #expect(size.width < maximumWidth - tolerance)
        #expect(size.height >= 40 - tolerance)
    }

    @Test
    func oversizedAccessibilityLabelWrapsWithinWholeChipCap() {
        let maximumWidth: CGFloat = 180
        let localizedStyleTitle = "Découvrir toutes les offres exclusives de cette collection aujourd’hui"
        let wrapped = measuredSize(
            ShopChip(
                localizedStyleTitle,
                accessibilityReflowMaximumWidth: maximumWidth
            ) {},
            dynamicTypeSize: .accessibility5
        )
        let unbroken = measuredSize(
            ShopChip(
                String(repeating: "MerchantName", count: 12),
                accessibilityReflowMaximumWidth: maximumWidth
            ) {},
            dynamicTypeSize: .accessibility5
        )

        #expect(wrapped.width <= maximumWidth + tolerance)
        #expect(wrapped.height > 40 + tolerance)
        #expect(unbroken.width <= maximumWidth + tolerance)
        #expect(unbroken.height > 40 + tolerance)
    }

    @Test
    func accessibilityLabelDefaultsToUnlimitedLinesAndSupportsAnExplicitCap() {
        let maximumWidth: CGFloat = 180
        let title = "This category title needs many more than two lines to render its complete text"
        let unlimited = measuredSize(
            ShopChip(
                title,
                accessibilityReflowMaximumWidth: maximumWidth
            ) {},
            dynamicTypeSize: .accessibility5
        )
        let twoLines = measuredSize(
            ShopChip(
                title,
                accessibilityReflowMaximumWidth: maximumWidth,
                accessibilityReflowLineLimit: 2
            ) {},
            dynamicTypeSize: .accessibility5
        )

        #expect(unlimited.width <= maximumWidth + tolerance)
        #expect(unlimited.height > twoLines.height + tolerance)
        #expect(twoLines.height > 40 + tolerance)
    }

    @Test
    func iconShapesRespectTheWholeChipCap() {
        let maximumWidth: CGFloat = 200
        let title = "A long localized filter category title that wraps completely"
        let leading = measuredSize(
            ShopChip(
                title,
                leadingIcon: .filter,
                accessibilityReflowMaximumWidth: maximumWidth
            ) {},
            dynamicTypeSize: .accessibility5
        )
        let trailing = measuredSize(
            ShopChip(
                title,
                trailingIcon: .sort,
                accessibilityReflowMaximumWidth: maximumWidth
            ) {},
            dynamicTypeSize: .accessibility5
        )

        #expect(leading.width <= maximumWidth + tolerance)
        #expect(trailing.width <= maximumWidth + tolerance)
        #expect(leading.height > 40 + tolerance)
        #expect(trailing.height > 40 + tolerance)
    }

    @Test
    func mediaAndLabelGrowAtAccessibilitySizesWithoutFillingTheCapWhenShort() {
        let maximumWidth: CGFloat = 260
        let short = measuredSize(
            ShopChip(
                "New",
                accessibilityReflowMaximumWidth: maximumWidth
            ) {
                Color.purple
            } action: {},
            dynamicTypeSize: .accessibility5
        )
        let standard = measuredSize(
            ShopChip(
                "A long category title with scalable media",
                accessibilityReflowMaximumWidth: maximumWidth
            ) {
                Color.purple
            } action: {},
            dynamicTypeSize: .medium
        )
        let accessible = measuredSize(
            ShopChip(
                "A long category title with scalable media",
                accessibilityReflowMaximumWidth: maximumWidth
            ) {
                Color.purple
            } action: {},
            dynamicTypeSize: .accessibility5
        )

        #expect(short.width < maximumWidth - tolerance)
        #expect(accessible.width <= maximumWidth + tolerance)
        #expect(accessible.height > standard.height + tolerance)
    }

    @Test
    func optedInStandardSizeMatchesDefaultLayout() {
        let title = "A long label remains one line at standard Dynamic Type sizes"
        let defaultSize = measuredSize(
            ShopChip(title) {},
            dynamicTypeSize: .medium
        )
        let optedInSize = measuredSize(
            ShopChip(
                title,
                accessibilityReflowMaximumWidth: 180
            ) {},
            dynamicTypeSize: .medium
        )

        expectApproximatelyEqual(defaultSize, optedInSize)
    }

    @Test(arguments: [DynamicTypeSize.medium, .accessibility5])
    func defaultLabeledShapesRemainSingleLine(dynamicTypeSize: DynamicTypeSize) {
        let longTitle = "A deliberately long chip title that stays on one line by default"

        let shortLabel = measuredSize(ShopChip("Sale") {}, dynamicTypeSize: dynamicTypeSize)
        let longLabel = measuredSize(ShopChip(longTitle) {}, dynamicTypeSize: dynamicTypeSize)
        #expect(longLabel.width > shortLabel.width)
        expectApproximatelyEqual(longLabel.height, shortLabel.height)

        let shortLeading = measuredSize(
            ShopChip("Sale", leadingIcon: .filter) {},
            dynamicTypeSize: dynamicTypeSize
        )
        let longLeading = measuredSize(
            ShopChip(longTitle, leadingIcon: .filter) {},
            dynamicTypeSize: dynamicTypeSize
        )
        #expect(longLeading.width > shortLeading.width)
        expectApproximatelyEqual(longLeading.height, shortLeading.height)

        let shortTrailing = measuredSize(
            ShopChip("Sale", trailingIcon: .sort) {},
            dynamicTypeSize: dynamicTypeSize
        )
        let longTrailing = measuredSize(
            ShopChip(longTitle, trailingIcon: .sort) {},
            dynamicTypeSize: dynamicTypeSize
        )
        #expect(longTrailing.width > shortTrailing.width)
        expectApproximatelyEqual(longTrailing.height, shortTrailing.height)

        let shortMedia = measuredSize(
            ShopChip("Sale") { Color.orange } action: {},
            dynamicTypeSize: dynamicTypeSize
        )
        let longMedia = measuredSize(
            ShopChip(longTitle) { Color.orange } action: {},
            dynamicTypeSize: dynamicTypeSize
        )
        #expect(longMedia.width > shortMedia.width)
        expectApproximatelyEqual(longMedia.height, shortMedia.height)
    }

    @Test
    func defaultNoTitleShapesStayFixedAcrossDynamicTypeSizes() {
        let mediumMediaOnly = measuredSize(
            ShopChip(accessibilityLabel: "Orange") { Color.orange } action: {},
            dynamicTypeSize: .medium
        )
        let accessibleMediaOnly = measuredSize(
            ShopChip(accessibilityLabel: "Orange") { Color.orange } action: {},
            dynamicTypeSize: .accessibility5
        )
        let optedInAccessibleMediaOnly = measuredSize(
            ShopChip(
                accessibilityLabel: "Orange",
                accessibilityReflowMaximumWidth: 200
            ) {
                Color.orange
            } action: {},
            dynamicTypeSize: .accessibility5
        )
        let mediumIconOnly = measuredSize(
            ShopChip(leadingIcon: .search, accessibilityLabel: "Search") {},
            dynamicTypeSize: .medium
        )
        let accessibleIconOnly = measuredSize(
            ShopChip(leadingIcon: .search, accessibilityLabel: "Search") {},
            dynamicTypeSize: .accessibility5
        )
        let optedInAccessibleIconOnly = measuredSize(
            ShopChip(
                leadingIcon: .search,
                accessibilityLabel: "Search",
                accessibilityReflowMaximumWidth: 200
            ) {},
            dynamicTypeSize: .accessibility5
        )
        let mediumMediaTrailing = measuredSize(
            ShopChip(trailingIcon: .sort, accessibilityLabel: "Sort") {
                Color.orange
            } action: {},
            dynamicTypeSize: .medium
        )
        let accessibleMediaTrailing = measuredSize(
            ShopChip(trailingIcon: .sort, accessibilityLabel: "Sort") {
                Color.orange
            } action: {},
            dynamicTypeSize: .accessibility5
        )
        let optedInAccessibleMediaTrailing = measuredSize(
            ShopChip(
                trailingIcon: .sort,
                accessibilityLabel: "Sort",
                accessibilityReflowMaximumWidth: 200
            ) {
                Color.orange
            } action: {},
            dynamicTypeSize: .accessibility5
        )

        expectApproximatelyEqual(mediumMediaOnly, accessibleMediaOnly)
        expectApproximatelyEqual(accessibleMediaOnly, optedInAccessibleMediaOnly)
        expectApproximatelyEqual(mediumIconOnly, accessibleIconOnly)
        expectApproximatelyEqual(accessibleIconOnly, optedInAccessibleIconOnly)
        expectApproximatelyEqual(mediumMediaTrailing, accessibleMediaTrailing)
        expectApproximatelyEqual(accessibleMediaTrailing, optedInAccessibleMediaTrailing)
        expectApproximatelyEqual(mediumMediaOnly.width, 40)
        expectApproximatelyEqual(mediumMediaOnly.height, 40)
        expectApproximatelyEqual(mediumIconOnly.width, 40)
        expectApproximatelyEqual(mediumIconOnly.height, 40)
    }

    @Test
    func minimumHeightsRemainFloorsAndWrappedContentCanExceedThem() {
        let small = measuredSize(
            ShopChip("Sale", size: .small) {},
            dynamicTypeSize: .medium
        )
        let large = measuredSize(
            ShopChip("Sale", size: .large) {},
            dynamicTypeSize: .medium
        )
        let wrappedSmall = measuredSize(
            ShopChip(
                "A long title that wraps across several lines",
                size: .small,
                accessibilityReflowMaximumWidth: 160
            ) {},
            dynamicTypeSize: .accessibility5
        )
        let wrappedLarge = measuredSize(
            ShopChip(
                "A long title that wraps across several lines",
                size: .large,
                accessibilityReflowMaximumWidth: 160
            ) {},
            dynamicTypeSize: .accessibility5
        )

        #expect(small.height >= 32 - tolerance)
        #expect(large.height >= 40 - tolerance)
        #expect(wrappedSmall.height > 32 + tolerance)
        #expect(wrappedLarge.height > 40 + tolerance)
    }

    private func measuredSize<Content: View>(
        _ view: Content,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGSize {
        UIHostingController(
            rootView: AnyView(
                view.environment(\.dynamicTypeSize, dynamicTypeSize)
            )
        )
        .sizeThatFits(in: CGSize(width: wideFittingWidth, height: 10_000))
    }

    private func expectApproximatelyEqual(_ lhs: CGSize, _ rhs: CGSize) {
        expectApproximatelyEqual(lhs.width, rhs.width)
        expectApproximatelyEqual(lhs.height, rhs.height)
    }

    private func expectApproximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat) {
        #expect(abs(lhs - rhs) <= tolerance)
    }
}
