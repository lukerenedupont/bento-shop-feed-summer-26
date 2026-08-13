import SwiftUI

/// Feedback row: thumbs up, thumbs down, refresh, overflow.
struct AgentMetaRow: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    var body: some View {
        HStack(spacing: GravitySpacing.space12) {
            metaButton(systemName: "hand.thumbsup")
            metaButton(systemName: "hand.thumbsdown")
            metaButton(systemName: "arrow.clockwise")
            metaButton(systemName: "ellipsis")
            Spacer()
        }
        .padding(.leading, PurlTune.token("Components/Search/Agent/AgentMetaRow.swift:padding:_:13:28", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
    }

    private func metaButton(systemName: String) -> some View {
        Button {
            HapticFeedback.light.fire()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentMetaRow.swift:foregroundStyle:_:22:34", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
                .frame(width: PurlTune.value("Components/Search/Agent/AgentMetaRow.swift:frame:width:23:31", default: 28), height: PurlTune.value("Components/Search/Agent/AgentMetaRow.swift:frame:height:23:132", default: 28))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AgentMetaRow()
        .padding()
        .background(PurlTune.token("Components/Search/Agent/AgentMetaRow.swift:background:_:32:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
