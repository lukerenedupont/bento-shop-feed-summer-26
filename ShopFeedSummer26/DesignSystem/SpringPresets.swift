import SwiftUI

enum SpringPreset {
    static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.75)
    static let responsive = Animation.spring(response: 0.35, dampingFraction: 0.65)
    static let standard = Animation.spring(response: 0.4, dampingFraction: 0.85)
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.88)
    static let entrance = Animation.spring(response: 0.6, dampingFraction: 0.75)
}

extension AnyTransition {
    static var blurScale: AnyTransition {
        .scale
        .combined(with: .opacity)
        .combined(with: .modifier(
            active: BlurModifier(active: true),
            identity: BlurModifier(active: false)
        ))
    }
}

struct BlurModifier: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content.blur(radius: active ? 10 : 0)
    }
}

#Preview("Spring presets") {
    struct SpringRow: View {
        let name: String
        let animation: Animation
        @State private var toggled = false
        var body: some View {
            HStack(spacing: GravitySpacing.space16) {
                Text(name)
                    .gravityTextStyle(GravityTypography.bodyTitleSmall)
                    .foregroundStyle(GravityColors.text)
                    .frame(width: 120, alignment: .leading)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(GravityColors.bgFillSecondary)
                        .frame(height: 56)
                    Circle()
                        .fill(GravityColors.bgFillBrand)
                        .frame(width: 44, height: 44)
                        .padding(.leading, 6)
                        .offset(x: toggled ? 200 : 0)
                }
                .onTapGesture {
                    withAnimation(animation) { toggled.toggle() }
                }
            }
        }
    }
    return VStack(spacing: GravitySpacing.space12) {
        Text("Tap each row to play").gravityTextStyle(GravityTypography.captionBold).foregroundStyle(GravityColors.textTertiary)
        SpringRow(name: "snappy", animation: SpringPreset.snappy)
        SpringRow(name: "responsive", animation: SpringPreset.responsive)
        SpringRow(name: "standard", animation: SpringPreset.standard)
        SpringRow(name: "smooth", animation: SpringPreset.smooth)
        SpringRow(name: "entrance", animation: SpringPreset.entrance)
    }
    .padding(GravitySpacing.space20)
    .background(GravityColors.bg)
}
