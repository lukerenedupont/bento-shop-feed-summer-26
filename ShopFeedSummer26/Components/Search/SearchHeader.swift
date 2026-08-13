import SwiftUI

/// Top header bar for the search page.
/// History button on the left, close button on the right.
struct SearchHeader: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let query: String
    var isInputFocused: Bool = false
    var onHistory: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        HStack {
            if query.isEmpty {
                Button {
                    HapticFeedback.light.fire()
                    onHistory()
                } label: {
                    GravityIcon.history.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: PurlTune.value("Components/Search/SearchHeader.swift:frame:width:21:39", default: 20), height: PurlTune.value("Components/Search/SearchHeader.swift:frame:height:21:134", default: 20))
                        .foregroundStyle(PurlTune.token("Components/Search/SearchHeader.swift:foregroundStyle:_:22:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        .frame(width: PurlTune.value("Components/Search/SearchHeader.swift:frame:width:23:39", default: 44), height: PurlTune.value("Components/Search/SearchHeader.swift:frame:height:23:134", default: 44))
                        .background(.white.opacity(PurlTune.value("Components/Search/SearchHeader.swift:opacity:_:24:52", default: 0.85)), in: Capsule())
                        .glassEffect(.regular)
                        .overlay(
                            Capsule().stroke(GravityColors.borderSecondary, lineWidth: 0.5)
                        )
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.90))
            }

            Spacer()

            if isInputFocused {
                Button {
                    HapticFeedback.light.fire()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PurlTune.token("Components/Search/SearchHeader.swift:foregroundStyle:_:42:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        .frame(width: PurlTune.value("Components/Search/SearchHeader.swift:frame:width:43:39", default: 44), height: PurlTune.value("Components/Search/SearchHeader.swift:frame:height:43:134", default: 44))
                        .background(.white.opacity(PurlTune.value("Components/Search/SearchHeader.swift:opacity:_:44:52", default: 0.85)), in: Capsule())
                        .glassEffect(.regular)
                        .overlay(
                            Capsule().stroke(GravityColors.borderSecondary, lineWidth: 0.5)
                        )
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.90))
                .transition(.opacity)
            }
        }
        .padding(.horizontal, GravitySpacing.screenMargin)
        .padding(.top, PurlTune.token("Components/Search/SearchHeader.swift:padding:_:55:24", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        .animation(.spring(response: PurlTune.value("Components/Search/SearchHeader.swift:spring:response:56:38", default: 0.3), dampingFraction: PurlTune.value("Components/Search/SearchHeader.swift:spring:dampingFraction:56:147", default: 0.8)), value: isInputFocused)
        .ignoresSafeArea(.keyboard)
    }
}

#Preview("Empty") {
    SearchHeader(query: "", isInputFocused: false)
        .padding()
        .background(PurlTune.token("Components/Search/SearchHeader.swift:background:_:64:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}

#Preview("With query") {
    SearchHeader(query: "hiking boots", isInputFocused: true)
        .padding()
        .background(PurlTune.token("Components/Search/SearchHeader.swift:background:_:70:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
