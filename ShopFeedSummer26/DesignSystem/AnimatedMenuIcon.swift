import SwiftUI

// MARK: - Animated Menu ↔ Close Icon

/// A two-line hamburger that morphs into an X with a single tap.
/// Uses native SwiftUI transforms so the crossover animation
/// interpolates smoothly frame-by-frame.
///
/// Usage:
/// ```
/// @State private var menuOpen = false
/// AnimatedMenuIcon(isOpen: $menuOpen, size: 20)
/// ```
struct AnimatedMenuIcon: View {

    @Binding var isOpen: Bool

    /// Point size of the icon (matches Gravity 20 or 24).
    var size: CGFloat = 24

    /// Stroke weight for the lines.
    var lineWeight: CGFloat = 1.8

    /// Color — defaults to Gravity text token.
    var color: Color = GravityColors.text

    // MARK: Derived metrics

    /// Vertical distance from center to each line in hamburger state.
    private var halfGap: CGFloat { size * 0.2 }

    /// Width of each line (slightly inset for optical balance).
    private var lineLength: CGFloat { size * 0.6 }

    // MARK: Body

    var body: some View {
        ZStack {
            // Top line → slides down to center, rotates +45°
            Capsule()
                .fill(color)
                .frame(width: lineLength, height: lineWeight)
                .rotationEffect(.degrees(isOpen ? 45 : 0))
                .offset(y: isOpen ? 0 : -halfGap)

            // Bottom line → slides up to center, rotates −45°
            Capsule()
                .fill(color)
                .frame(width: lineLength, height: lineWeight)
                .rotationEffect(.degrees(isOpen ? -45 : 0))
                .offset(y: isOpen ? 0 : halfGap)
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isOpen)
    }

    private func toggle() {
        isOpen.toggle()
    }
}

// MARK: - Convenience wrapper with built-in glass circle

/// Drop-in replacement for the 44×44 glass circle buttons in StorePage / DynamicNavBar.
struct AnimatedMenuButton: View {

    @Binding var isOpen: Bool
    var iconSize: CGFloat = 20
    var buttonSize: CGFloat = 44
    var tint: Color = .clear

    var body: some View {
        AnimatedMenuIcon(isOpen: $isOpen, size: iconSize)
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
            .glassEffect(
                .regular.interactive().tint(tint.opacity(0.15)),
                in: .circle
            )
    }
}

// MARK: - Preview

#Preview("Menu ↔ Close") {
    @Previewable @State var open = false

    VStack(spacing: 40) {
        Text(open ? "Close" : "Menu")
            .gravityTextStyle(GravityTypography.bodySmall)

        // Raw icon at 20pt
        AnimatedMenuIcon(isOpen: $open, size: 20)

        // Raw icon at 24pt
        AnimatedMenuIcon(isOpen: $open, size: 24)

        // Glass circle button variant
        AnimatedMenuButton(isOpen: $open)

        // Dark variant
        AnimatedMenuButton(isOpen: $open)
            .environment(\.colorScheme, .dark)
    }
    .padding(60)
}
