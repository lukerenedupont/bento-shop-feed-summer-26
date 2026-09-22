import SwiftUI
import UIKit

public struct ShopOtherShopperAvatar: View {
    public static let paletteColorCount = ShopOtherShopperAvatarPalette.colorCount

    private let pointSize: CGFloat
    private let initial: String?
    private let colors: ShopOtherShopperAvatarColors

    public init(
        displayName: String?,
        seed: String? = nil,
        pointSize: CGFloat,
        showsInitial: Bool = true,
        paletteIndex: Int? = nil
    ) {
        self.pointSize = pointSize
        self.initial = showsInitial
            ? shopOtherShopperAvatarInitial(displayName: displayName)
            : nil
        let resolvedPaletteIndex = paletteIndex.map {
            (($0 % Self.paletteColorCount) + Self.paletteColorCount) % Self.paletteColorCount
        } ?? ShopOtherShopperAvatarHash.index(for: seed ?? displayName ?? "anonymous-user")
        self.colors = ShopOtherShopperAvatarColors.palettes[resolvedPaletteIndex]
    }

    public var body: some View {
        ZStack {
            Circle().fill(colors.baseColor)

            ShopAvatarFallbackGlow(
                color: colors.glowColor,
                opacity: 0.45,
                pointSize: pointSize
            )

            if let initial {
                ShopAvatarInitialsText(
                    initials: initial,
                    pointSize: pointSize,
                    color: ShopColor.textFixedLight
                )
                .accessibilityHidden(true)
            }
        }
        .frame(width: pointSize, height: pointSize)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(ShopOtherShopperAvatarColors.border, lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }
}

func shopOtherShopperAvatarInitial(displayName: String?) -> String? {
    let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmedName.first.map { String($0).localizedUppercase }
}

private struct ShopOtherShopperAvatarColors {
    let baseColor: Color
    let glowColor: Color

    static let border = Color(
        UIColor(red: 24.0 / 255.0, green: 59.0 / 255.0, blue: 78.0 / 255.0, alpha: 0.06)
    )

    static let palettes = [
        ShopOtherShopperAvatarColors(
            baseColor: Color(UIColor(red: 1, green: 150.0 / 255.0, blue: 125.0 / 255.0, alpha: 1)),
            glowColor: Color(UIColor(red: 1, green: 210.0 / 255.0, blue: 194.0 / 255.0, alpha: 1))
        ),
        ShopOtherShopperAvatarColors(
            baseColor: Color(UIColor(red: 146.0 / 255.0, green: 208.0 / 255.0, blue: 141.0 / 255.0, alpha: 1)),
            glowColor: Color(UIColor(red: 186.0 / 255.0, green: 235.0 / 255.0, blue: 203.0 / 255.0, alpha: 1))
        ),
        ShopOtherShopperAvatarColors(
            baseColor: Color(UIColor(red: 248.0 / 255.0, green: 219.0 / 255.0, blue: 103.0 / 255.0, alpha: 1)),
            glowColor: Color(UIColor(red: 1, green: 236.0 / 255.0, blue: 159.0 / 255.0, alpha: 1))
        ),
        ShopOtherShopperAvatarColors(
            baseColor: Color(UIColor(red: 217.0 / 255.0, green: 123.0 / 255.0, blue: 158.0 / 255.0, alpha: 1)),
            glowColor: Color(UIColor(red: 237.0 / 255.0, green: 179.0 / 255.0, blue: 205.0 / 255.0, alpha: 1))
        ),
    ]
}

public enum ShopOtherShopperAvatarPalette {
    public static let colorCount = ShopOtherShopperAvatarColors.palettes.count

    public static func indexAssignments(for identifiers: [String]) -> [String: Int] {
        var assignments: [String: Int] = [:]
        var usedIndices = Set<Int>()

        for identifier in identifiers where assignments[identifier] == nil {
            if usedIndices.count == colorCount {
                usedIndices.removeAll(keepingCapacity: true)
            }

            let preferredIndex = ShopOtherShopperAvatarHash.index(for: identifier)
            var resolvedIndex = preferredIndex
            for offset in 0..<colorCount {
                let candidate = (preferredIndex + offset) % colorCount
                if usedIndices.contains(candidate) == false {
                    resolvedIndex = candidate
                    break
                }
            }

            assignments[identifier] = resolvedIndex
            usedIndices.insert(resolvedIndex)
        }

        return assignments
    }
}

enum ShopOtherShopperAvatarHash {
    static func index(for value: String) -> Int {
        var hash: Int32 = 0
        for codeUnit in value.utf16 {
            hash = hash &* 31 &+ Int32(codeUnit)
        }

        let magnitude = hash == .min ? Int(Int32.max) + 1 : abs(Int(hash))
        return magnitude % ShopOtherShopperAvatarPalette.colorCount
    }
}

#Preview("Other shopper avatars") {
    ShopTheme {
        HStack(spacing: 12) {
            ShopOtherShopperAvatar(displayName: "Jane", seed: "jane", pointSize: 24)
            ShopOtherShopperAvatar(displayName: "Alex", seed: "alex", pointSize: 32)
            ShopOtherShopperAvatar(displayName: "Morgan", seed: "morgan", pointSize: 44)
            ShopOtherShopperAvatar(displayName: nil, seed: nil, pointSize: 56)
        }
        .padding()
    }
}
