import SwiftUI

/// A shimmer/glint animation overlay for loading states.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: phase * geo.size.width * 1.5)
                }
            }
            .clipped()
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

/// A pulse opacity animation for skeleton loading states.
struct PulseModifier: ViewModifier {
    @State private var opacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 0.4
                }
            }
    }
}

extension View {
    /// Adds a shimmer glint animation across the view.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    /// Adds a pulse opacity animation (1.0 ↔ 0.4).
    func pulse() -> some View {
        modifier(PulseModifier())
    }
}

#Preview("Shimmer + pulse") {
    VStack(alignment: .leading, spacing: GravitySpacing.space24) {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            Text("Shimmer").gravityTextStyle(GravityTypography.bodyTitleSmall).foregroundStyle(GravityColors.textTertiary)
            RoundedRectangle(cornerRadius: GravityRadius.r12)
                .fill(GravityColors.bgFillSecondary)
                .frame(height: 80)
                .shimmer()
            RoundedRectangle(cornerRadius: GravityRadius.r8)
                .fill(GravityColors.bgFillSecondary)
                .frame(width: 200, height: 14)
                .shimmer()
        }
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            Text("Pulse").gravityTextStyle(GravityTypography.bodyTitleSmall).foregroundStyle(GravityColors.textTertiary)
            HStack(spacing: GravitySpacing.space8) {
                RoundedRectangle(cornerRadius: GravityRadius.r12)
                    .fill(GravityColors.bgFillSecondary)
                    .frame(width: 80, height: 80)
                RoundedRectangle(cornerRadius: GravityRadius.r12)
                    .fill(GravityColors.bgFillSecondary)
                    .frame(width: 80, height: 80)
            }
            .pulse()
        }
    }
    .padding(GravitySpacing.space20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(GravityColors.bg)
}
