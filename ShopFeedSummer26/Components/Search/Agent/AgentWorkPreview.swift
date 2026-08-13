import SwiftUI

/// Shows agent thinking state: spinner + shimmer text.
struct AgentWorkPreview: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let steps: [String]
    let thinkingText: String

    var body: some View {
        HStack(alignment: .center, spacing: GravitySpacing.space8) {
            SpinnerView()
                .frame(width: PurlTune.value("Components/Search/Agent/AgentWorkPreview.swift:frame:width:11:31", default: 16), height: PurlTune.value("Components/Search/Agent/AgentWorkPreview.swift:frame:height:11:136", default: 16))
            ShimmerThinkingText(text: thinkingText)
        }
    }
}

// MARK: - Spinner (16×16, 3px stroke)

private struct SpinnerView: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(PurlTune.value("Components/Search/Agent/AgentWorkPreview.swift:opacity:_:25:45", default: 0.1)), lineWidth: 3)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    Color(red: 0.33, green: 0.20, blue: 0.92),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Shimmer Thinking Text

private struct ShimmerThinkingText: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let text: String
    @State private var shimmerPhase: CGFloat = -1.0
    private let textColor = Color(red: 0.33, green: 0.31, blue: 0.44)

    var body: some View {
        Text(text)
            .gravityTextStyle(GravityTypography.bodyLarge)
            .tracking(-0.5)
            .foregroundStyle(textColor)
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(PurlTune.value("Components/Search/Agent/AgentWorkPreview.swift:opacity:_:58:57", default: 0.5)), location: 0),
                            .init(color: .white.opacity(PurlTune.value("Components/Search/Agent/AgentWorkPreview.swift:opacity:_:59:57", default: 0)), location: 0.5),
                            .init(color: .white.opacity(PurlTune.value("Components/Search/Agent/AgentWorkPreview.swift:opacity:_:60:57", default: 0.5)), location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width)
                    .offset(x: shimmerPhase * geo.size.width)
                }
                .blendMode(.sourceAtop)
            }
            .compositingGroup()
            .id(text)
            .transition(
                .asymmetric(
                    insertion: .offset(y: PurlTune.value("Components/Search/Agent/AgentWorkPreview.swift:offset:y:74:43", default: 8)).combined(with: .opacity),
                    removal: .offset(y: PurlTune.value("Components/Search/Agent/AgentWorkPreview.swift:offset:y:75:41", default: -8)).combined(with: .opacity)
                )
            )
            .animation(.spring(response: PurlTune.value("Components/Search/Agent/AgentWorkPreview.swift:spring:response:78:42", default: 0.4), dampingFraction: PurlTune.value("Components/Search/Agent/AgentWorkPreview.swift:spring:dampingFraction:78:161", default: 0.8)), value: text)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.0
                }
            }
    }
}

#Preview {
    AgentWorkPreview(
        steps: [
            "Browsing 24 stores",
            "Comparing prices and reviews",
            "Picking the best matches for you",
        ],
        thinkingText: "Finding products you'll love…"
    )
    .padding()
    .background(PurlTune.token("Components/Search/Agent/AgentWorkPreview.swift:background:_:97:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
