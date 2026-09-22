import SwiftUI
import Testing
@testable import Gravity

struct ShopAvatarTests {
    @Test
    func defaultPlaceholderStylePreservesEstablishedNativeAppearance() {
        let style = ShopAvatarVisualStyle.resolve(
            hasImage: false,
            showsTint: true,
            fallbackBackgroundColor: GravityColor.bgFillFixedDusk,
            showsFallbackTint: false
        )

        #expect(style.backgroundColor == GravityColor.bgFillFixedDusk)
        #expect(style.showsTint == false)
    }

    @Test
    func placeholderCanOptIntoReactNativeAppearance() {
        let style = ShopAvatarVisualStyle.resolve(
            hasImage: false,
            showsTint: true,
            fallbackBackgroundColor: GravityColor.bgFillTertiary,
            showsFallbackTint: true
        )

        #expect(style.backgroundColor == GravityColor.bgFillTertiary)
        #expect(style.showsTint)
    }

    @Test
    func optedInPlaceholderTintStillRespectsShowsTint() {
        let style = ShopAvatarVisualStyle.resolve(
            hasImage: false,
            showsTint: false,
            fallbackBackgroundColor: GravityColor.bgFillTertiary,
            showsFallbackTint: true
        )

        #expect(style.backgroundColor == GravityColor.bgFillTertiary)
        #expect(style.showsTint == false)
    }

    @Test
    func imageStyleKeepsFixedLightBackgroundAndTint() {
        let style = ShopAvatarVisualStyle.resolve(
            hasImage: true,
            showsTint: true,
            fallbackBackgroundColor: GravityColor.bgFillTertiary,
            showsFallbackTint: false
        )

        #expect(style.backgroundColor == GravityColor.bgFillFixedLight)
        #expect(style.showsTint)
    }

    @Test
    func imageStyleStillRespectsDisabledTint() {
        let style = ShopAvatarVisualStyle.resolve(
            hasImage: true,
            showsTint: false,
            fallbackBackgroundColor: GravityColor.bgFillTertiary,
            showsFallbackTint: true
        )

        #expect(style.backgroundColor == GravityColor.bgFillFixedLight)
        #expect(style.showsTint == false)
    }

    @Test
    func initialsRenderAtStandardDynamicTypeSizes() {
        let standardSizes: [DynamicTypeSize] = [
            .xSmall,
            .small,
            .medium,
            .large,
            .xLarge,
            .xxLarge,
            .xxxLarge,
        ]

        for size in standardSizes {
            #expect(shopAvatarShowsInitials(dynamicTypeSize: size), "\(size)")
        }
    }

    @Test
    func initialsFallBackToPlaceholderAtAccessibilityDynamicTypeSizes() {
        let accessibilitySizes: [DynamicTypeSize] = [
            .accessibility1,
            .accessibility2,
            .accessibility3,
            .accessibility4,
            .accessibility5,
        ]

        for size in accessibilitySizes {
            #expect(shopAvatarShowsInitials(dynamicTypeSize: size) == false, "\(size)")
        }
    }

    @Test
    func derivedInitialsResolveBelowAccessibilitySizes() {
        #expect(
            shopAvatarResolvedInitials(
                initialsOverride: nil,
                name: "Snow Peak",
                showsInitials: true
            ) == "SP"
        )
    }

    @Test
    func explicitInitialsResolveBelowAccessibilitySizes() {
        #expect(
            shopAvatarResolvedInitials(
                initialsOverride: "CM",
                name: "Claw on Mac",
                showsInitials: true
            ) == "CM"
        )
    }

    @Test
    func bothDerivedAndExplicitInitialsDropAtAccessibilitySizes() {
        #expect(
            shopAvatarResolvedInitials(
                initialsOverride: nil,
                name: "Snow Peak",
                showsInitials: false
            ) == nil
        )
        #expect(
            shopAvatarResolvedInitials(
                initialsOverride: "SP",
                name: "Snow Peak",
                showsInitials: false
            ) == nil
        )
    }

    @Test
    func emptyExplicitInitialsResolveToNil() {
        #expect(
            shopAvatarResolvedInitials(
                initialsOverride: "",
                name: "Snow Peak",
                showsInitials: true
            ) == nil
        )
    }
}
