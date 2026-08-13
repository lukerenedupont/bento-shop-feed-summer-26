import SwiftUI

/// Follow-up suggestion cards matching production AgentActionCard.
/// Wrapping layout — each card's text stays on one line.
struct AgentSuggestionChips: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let suggestions: [SuggestionItem]
    var onTap: ((String) -> Void)? = nil

    var body: some View {
        FlowLayout(spacing: GravitySpacing.space8) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                Button {
                    HapticFeedback.light.fire()
                    onTap?(suggestion.query)
                } label: {
                    Text(suggestion.label)
                        .gravityTextStyle(GravityTypography.buttonMedium)
                        .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentSuggestionChips.swift:foregroundStyle:_:18:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        .lineLimit(1)
                        .padding(PurlTune.token("Components/Search/Agent/AgentSuggestionChips.swift:padding:_:20:34", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                        .background(PurlTune.token("Components/Search/Agent/AgentSuggestionChips.swift:background:_:21:37", default: GravityColors.bgFill, options: GravityColors.purlTuneColorOptions))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(GravityColors.borderSecondary, lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(PurlTune.value("Components/Search/Agent/AgentSuggestionChips.swift:opacity:_:26:55", default: 0.06)), radius: PurlTune.value("Components/Search/Agent/AgentSuggestionChips.swift:shadow:radius:26:165", default: 2), x: PurlTune.value("Components/Search/Agent/AgentSuggestionChips.swift:shadow:x:26:271", default: 0), y: PurlTune.value("Components/Search/Agent/AgentSuggestionChips.swift:shadow:y:26:372", default: 2))
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.97))
            }
        }
    }
}

// MARK: - Flow Layout (wrapping HStack)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            if i < rows.count - 1 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}

#Preview {
    AgentSuggestionChips(suggestions: SuggestionItem.previews)
        .padding()
        .background(PurlTune.token("Components/Search/Agent/AgentSuggestionChips.swift:background:_:86:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
