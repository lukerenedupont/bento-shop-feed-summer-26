import SwiftUI

/// Text with a shimmer/glint animation across it.
struct ShimmerText: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let text: String
    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        Text(text)
            .gravityTextStyle(GravityTypography.bodySmall)
            .foregroundStyle(GravityColors.text.opacity(PurlTune.value("Components/Search/Agent/ShimmerText.swift:opacity:_:11:57", default: 0.35)))
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(PurlTune.value("Components/Search/Agent/ShimmerText.swift:opacity:_:15:57", default: 0.5)), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.4)
                    .offset(x: shimmerOffset * geo.size.width)
                    .blendMode(.sourceAtop)
                }
            }
            .compositingGroup()
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1.5
                }
            }
    }
}

#Preview {
    ShimmerText(text: "Thinking through your request…")
        .gravityTextStyle(GravityTypography.bodyLarge)
        .padding()
        .background(PurlTune.token("Components/Search/Agent/ShimmerText.swift:background:_:37:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
