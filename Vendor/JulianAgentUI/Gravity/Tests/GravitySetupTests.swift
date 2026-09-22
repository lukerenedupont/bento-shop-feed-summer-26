import SwiftUI
import Testing
import UIKit
@testable import Gravity

struct GravitySetupTests {
    @Test
    func gravityTextVariantsExposeCanonicalTokenNames() {
        #expect(GravityTextStyle.posterLarge.rawValue == "posterLarge")
        #expect(GravityTextStyle.posterLargeWeightMedium.rawValue == "posterLargeWeightMedium")
        #expect(GravityTextStyle.heroSmall.rawValue == "heroSmall")
        #expect(GravityTextStyle.navigationTitle.rawValue == "navigationTitle")
        #expect(GravityTextStyle.subtitle.uiFont.fontName == "GTStandard-MSemibold")
        #expect(GravityTextStyle.posterXS.uiFont.fontName == "GTStandard-LHeavy")
    }

    @Test
    func gravityButtonVariantsExposeCanonicalTokenNames() {
        #expect(GravityButtonVariant.outlinedDangerous.rawValue == "outlined-dangerous")
        #expect(GravityButtonVariant.blurredOverlayLight.rawValue == "blurredOverlayLight")
        #expect(GravityButtonVariant.fixedLight.rawValue == "fixedLight")
    }

    @Test
    func gravityIconsAreGeneratedFromCatalog() {
        #expect(GravityIconName.search.assetName == "search")
        #expect(GravityIconName.googleLogoColored.defaultRenderingStyle == .original)
        #expect(GravityIconName.yahooLogo.defaultRenderingStyle == .original)
        #expect(GravityIconName.passkeyApplePasswords.defaultRenderingStyle == .original)
        #expect(GravityIconName.passkeyGooglePasswordManager.defaultRenderingStyle == .original)
        #expect(GravityIconName.arrowRight.defaultRenderingStyle == .template)
    }

    @Test
    func gravityColorsExposeCanonicalTokenNames() {
        #expect(GravityColorToken.bgFillBrand.rawValue == "bg-fill-brand")
        #expect(GravityColorToken.borderInputBrandFocus.rawValue == "border-input-brand-focus")
    }

    @Test
    func toolbarForegroundPrefersItsExplicitSchemeOverTheAmbientScreenScheme() {
        #expect(
            ShopToolbarForegroundColor.resolve(
                for: .light,
                toolbarColorScheme: .dark
            ) == GravityColor.textFixedLight
        )
        #expect(
            ShopToolbarForegroundColor.resolve(
                for: .dark,
                toolbarColorScheme: .light
            ) == GravityColor.textFixedDark
        )
        #expect(
            ShopToolbarForegroundColor.resolve(for: .dark) == GravityColor.textFixedLight
        )
    }

    @Test
    func gravityBadgesCapTextScaling() {
        // badges are generally lower-priority than the content they're badging, so they're
        // size-capped by default to avoid taking over the UI. If the user has a very large
        // text size selected, they can long-press the badge to bring up the Large Content
        // Viewer for a magnified version of the text.
        let badgeTextScale = ShopBadgeTextScale.range(upTo: ShopBadgeTextScale.maximumDynamicTypeSize)

        #expect(badgeTextScale.lowerBound == .xSmall)
        #expect(badgeTextScale.upperBound == .xxLarge)
        #expect(badgeTextScale.contains(.xxxLarge) == false)
    }

    @MainActor
    @Test
    func gravityBadgeLargeContentViewerActivatesOnlyBeyondTextScaleCap() {
        #expect(ShopBadgeTextScale.isLargeContentViewerActive(
            dynamicTypeSize: .xxLarge,
            label: "25% discount"
        ) == false)
        #expect(ShopBadgeTextScale.isLargeContentViewerActive(
            dynamicTypeSize: .xxxLarge,
            label: "25% discount"
        ))
        #expect(ShopBadgeTextScale.isLargeContentViewerActive(
            dynamicTypeSize: .accessibility1,
            maximumDynamicTypeSize: nil,
            label: "25% discount"
        ) == false)
        #expect(ShopBadgeTextScale.isLargeContentViewerActive(
            dynamicTypeSize: .accessibility1,
            label: nil
        ) == false)
    }

    @MainActor
    @Test
    func gravityBadgeSurfaceDefaultsLargeContentViewerToAccessibilityLabel() {
        let surface = ShopBadgeSurface(accessibilityLabel: "25% discount") {
            Color.clear
        } content: {
            SwiftUI.Text("25% off")
        }
        let largeContentViewerLabel = Mirror(reflecting: surface).children.first {
            $0.label == "largeContentViewerLabel"
        }?.value as? String

        #expect(largeContentViewerLabel == "25% discount")
    }

    @MainActor
    @Test
    func gravityBadgeLargeContentViewerUsesConfiguredLabel() {
        let view = ShopBadgeLargeContentViewerView()
        view.configure(label: "25% discount")

        #expect(view.isAccessibilityElement == false)
        #expect(view.showsLargeContentViewer)
        #expect(view.largeContentTitle == "25% discount")
    }

    @MainActor
    @Test
    func gravityBadgeLargeContentViewerCarriesItsOwnInteraction() {
        let view = ShopBadgeLargeContentViewerView()
        let interactions = view.interactions.compactMap { $0 as? UILargeContentViewerInteraction }

        #expect(interactions.count == 1)
    }
}
