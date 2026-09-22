import CoreGraphics
import Testing
@testable import Gravity

struct ShopAvatarFallbackTests {
    @Test
    func customPointSizesUseNearestSupportedAvatarSizeForFallbackMetrics() {
        #expect(ShopAvatarSize.nearest(to: 24) == .xs)
        #expect(ShopAvatarSize.nearest(to: 32) == .s)
        #expect(ShopAvatarSize.nearest(to: 44) == .m)
        #expect(ShopAvatarSize.nearest(to: 56) == .l)
        #expect(ShopAvatarSize.nearest(to: 72) == .xl)
        #expect(ShopAvatarSize.nearest(to: 96) == .xxl)
        #expect(ShopAvatarSize.nearest(to: 100) == .xxl)
        #expect(ShopAvatarSize.nearest(to: 0) == .xs)
    }

    @Test
    func avatarInitialsUseGravityTypography() {
        let expectations: [(CGFloat, GravityTextStyle, CGFloat)] = [
            (16, .badgeBold, 7),
            (24, .badgeBold, 13),
            (32, .bodyTitleLarge, 22),
            (44, .subtitle, 20),
            (56, .headerBold, 26),
            (72, .header, 30),
            (96, .heroNormal, 42),
            (120, .posterSmall, 50),
        ]

        for (pointSize, textStyle, lineHeight) in expectations {
            let typography = ShopAvatarInitialsTypography(pointSize: pointSize)
            #expect(typography.textStyle == textStyle)
            #expect(typography.lineHeight == lineHeight)
        }
    }

    @Test
    func otherShopperPaletteUsesEveryColorBeforeReuse() {
        let identifiers = (0..<8).map { "profile-\($0)" }
        let assignments = ShopOtherShopperAvatarPalette.indexAssignments(for: identifiers)
        let expectedIndices = Set(0..<ShopOtherShopperAvatar.paletteColorCount)

        #expect(Set(identifiers.prefix(4).compactMap { assignments[$0] }) == expectedIndices)
        #expect(Set(identifiers.suffix(4).compactMap { assignments[$0] }) == expectedIndices)
    }

    @Test
    func otherShopperPalettePreservesDuplicateAssignments() {
        let assignments = ShopOtherShopperAvatarPalette.indexAssignments(
            for: ["profile-a", "profile-b", "profile-a"]
        )

        #expect(assignments.count == 2)
        #expect(assignments["profile-a"] == ShopOtherShopperAvatarHash.index(for: "profile-a"))
    }

    @Test
    func otherShopperAvatarStyleUsesStableReactNativeCompatibleHash() {
        #expect(ShopOtherShopperAvatarHash.index(for: "d") == 0)
        #expect(ShopOtherShopperAvatarHash.index(for: "jane") == 2)
        #expect(ShopOtherShopperAvatarHash.index(for: "anonymous-user") == 1)

        for seed in ["", "a", "morgan", String(repeating: "x", count: 64)] {
            let index = ShopOtherShopperAvatarHash.index(for: seed)
            #expect((0..<4).contains(index))
            #expect(ShopOtherShopperAvatarHash.index(for: seed) == index)
        }
    }

    @Test
    func otherShopperAvatarCanLeaveMissingNameBlank() {
        #expect(shopOtherShopperAvatarInitial(displayName: " Avery ") == "A")
        #expect(shopOtherShopperAvatarInitial(displayName: nil) == nil)
        #expect(shopOtherShopperAvatarInitial(displayName: "  ") == nil)
    }
}
