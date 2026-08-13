import SwiftUI

/// A horizontal scroll of ComparisonCards with section header.
/// Used when `AgentProductSection.isComparison` is true.
struct ComparisonShelf: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let section: AgentProductSection

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            // Section header
            if let title = section.title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .gravityTextStyle(GravityTypography.sectionTitle)
                        .foregroundStyle(PurlTune.token("Components/Search/Agent/ComparisonShelf.swift:foregroundStyle:_:15:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))

                    if let subtitle = section.subtitle {
                        Text(subtitle)
                            .gravityTextStyle(GravityTypography.caption)
                            .foregroundStyle(PurlTune.token("Components/Search/Agent/ComparisonShelf.swift:foregroundStyle:_:20:46", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                    }
                }
                .padding(.horizontal, GravitySpacing.screenMargin)
            }

            // Comparison cards
            if section.products.count <= 2 {
                // 2 or fewer: fill container 50/50
                HStack(alignment: .top, spacing: GravitySpacing.space8) {
                    ForEach(section.products) { product in
                        ComparisonCard(product: product, fillWidth: true)
                    }
                }
                .padding(.horizontal, GravitySpacing.screenMargin)
                .padding(.vertical, PurlTune.value("Components/Search/Agent/ComparisonShelf.swift:padding:_:35:37", default: 6))
            } else {
                // 3+: snapping scroll, max 176.5px per card
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: GravitySpacing.space8) {
                        ForEach(section.products) { product in
                            ComparisonCard(product: product)
                                .scrollTransition { content, phase in
                                    content.opacity(phase.isIdentity ? 1 : 0.85)
                                }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, GravitySpacing.screenMargin)
                    .padding(.vertical, PurlTune.value("Components/Search/Agent/ComparisonShelf.swift:padding:_:49:41", default: 4))
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
}

#Preview {
    ComparisonShelf(section: .comparisonPreview)
        .padding(.vertical)
        .background(PurlTune.token("Components/Search/Agent/ComparisonShelf.swift:background:_:60:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
