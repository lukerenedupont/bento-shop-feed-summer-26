import SwiftUI

/// A shadow definition with all parameters needed for SwiftUI's `.shadow()`.
struct GravityShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// Shadow presets matching Gravity's shadows.ts.
enum GravityShadows {
    /// Cards on white/light backgrounds (L1 — content layer)
    static let small = GravityShadow(
        color: Color.black.opacity(0.06),
        radius: 8,
        x: 0,
        y: 2
    )

    /// Cards on colored backgrounds, floating chrome, glass surfaces
    static let medium = GravityShadow(
        color: Color.black.opacity(0.12),
        radius: 24,
        x: 0,
        y: 4
    )

    /// Compact top-of-feed rail cards from the current utility-card spec.
    static let utilityRail = GravityShadow(
        color: Color.black.opacity(0.18),
        radius: 20,
        x: 0,
        y: 3
    )

    /// Map-backed order utility card; lighter so the pale map remains clean.
    static let orderUtilityRail = GravityShadow(
        color: Color.black.opacity(0.10),
        radius: 14,
        x: 0,
        y: 3
    )

    /// Inset order summary surface from the delivery utility-card spec.
    static let orderSummary = GravityShadow(
        color: Color.black.opacity(0.12),
        radius: 12,
        x: 0,
        y: 4
    )

    /// Selected top-level feed chip. The broad, nearly centered falloff keeps
    /// the white pill legible without reading like a raised card.
    static let selectedTopic = GravityShadow(
        color: Color.black.opacity(0.22),
        radius: 18,
        x: 0,
        y: 4
    )

    /// Optical support for white labels over photographic feed media.
    static let feedText = GravityShadow(
        color: Color.black.opacity(0.16),
        radius: 3,
        x: 0,
        y: 1
    )

    /// Cards on dark/non-white backgrounds, sheets, modals
    static let large = GravityShadow(
        color: Color.black.opacity(0.24),
        radius: 40,
        x: 0,
        y: 8
    )
}

// MARK: - View Extension

extension View {
    /// Applies a Gravity shadow preset.
    /// Uses `.compositingGroup()` to flatten view layers before shadow computation,
    /// preventing GPU overdraw from nested subviews each generating their own shadow pass.
    func gravityShadow(_ shadow: GravityShadow) -> some View {
        self.compositingGroup()
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
}

#Preview("Shadow presets") {
    struct Sample: View {
        let name: String
        let shadow: GravityShadow
        var body: some View {
            VStack(spacing: GravitySpacing.space12) {
                RoundedRectangle(cornerRadius: GravityRadius.r20)
                    .fill(GravityColors.bgFill)
                    .frame(width: 200, height: 100)
                    .gravityShadow(shadow)
                Text(name)
                    .gravityTextStyle(GravityTypography.captionBold)
                    .foregroundStyle(GravityColors.textTertiary)
                    .textCase(.uppercase)
            }
        }
    }
    return VStack(spacing: GravitySpacing.space32) {
        Sample(name: "small", shadow: GravityShadows.small)
        Sample(name: "medium", shadow: GravityShadows.medium)
        Sample(name: "large", shadow: GravityShadows.large)
    }
    .padding(GravitySpacing.space32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(GravityColors.bg)
}
