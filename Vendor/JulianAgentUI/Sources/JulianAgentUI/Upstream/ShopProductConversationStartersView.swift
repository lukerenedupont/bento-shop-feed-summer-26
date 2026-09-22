import Gravity
import SwiftUI

enum ShopProductConversationStartersLayout: Equatable, Sendable {
    case singleRow
    case twoRows
    case stacked
}

extension EnvironmentValues {
    @Entry var shopProductConversationStartersLayout: ShopProductConversationStartersLayout = .twoRows
}

/// Shared inline section for PDP and order starters. Only the buttons transfer
/// to the keyboard presentation; the section heading stays in the page.
struct ShopInlineConversationStartersSection: View {
    let starters: [ShopProductConversationStarter]
    let navigation: ShopBottomNavigationConversation
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            ShopText(localizedString("Agent.ConversationStarters.SectionTitle"), style: .subtitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            ShopProductConversationStartersPlacement(
                starters: starters,
                navigation: navigation,
                onSelect: onSelect
            )
            .padding(.horizontal, -GravitySpacing.space8)
        }
    }
}

/// Natural-width conversation starters sharing one horizontal scroller.
struct ShopProductConversationStartersView: View {
    let starters: [ShopProductConversationStarter]
    let onSelect: (String) -> Void
    var layout: ShopProductConversationStartersLayout = .twoRows
    var horizontalInset: CGFloat = ShopSpacing.screenMargin
    var maximumDraftCount: Int? = nil

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: GravitySpacing.space8) {
                content
            }
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if layout == .stacked {
            ShopConversationStarterStack(items: starters, maximumDraftCount: maximumDraftCount) { starter in
                ShopProductConversationStarterRow(
                    starters: [starter], onSelect: onSelect,
                    minimumHeight: 56, textStyle: .buttonLarge, iconSpacing: GravitySpacing.space6
                )
            }
        } else {
            ScrollView(.horizontal) {
                rows
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
            .accessibilityIdentifier("product-conversation-starters")
        }
    }

    @ViewBuilder
    private var rows: some View {
        switch layout {
        case .singleRow, .stacked:
            ShopProductConversationStarterRow(starters: starters, onSelect: onSelect)
        case .twoRows:
            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                ShopProductConversationStarterRow(starters: Array(starters.prefix(2)), onSelect: onSelect)
                ShopProductConversationStarterRow(starters: Array(starters.dropFirst(2)), onSelect: onSelect)
            }
        }
    }
}

private struct ShopProductConversationStarterRow: View {
    let starters: [ShopProductConversationStarter]
    let onSelect: (String) -> Void
    var minimumHeight: CGFloat = 40
    var textStyle: GravityTextStyle = .buttonMedium
    var iconSpacing: CGFloat = GravitySpacing.space4

    var body: some View {
        HStack(spacing: GravitySpacing.space8) {
            ForEach(starters) { starter in
                Button { onSelect(starter.text) } label: {
                    HStack(spacing: iconSpacing) {
                        ShopIcon(.shopChatFilled, size: .small, color: GravityColor.textBrand)
                            .opacity(0.35)
                        ShopText(starter.text, style: textStyle, color: GravityColor.textBrand)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, GravitySpacing.space16 - GravitySpacing.space2)
                    .padding(.trailing, GravitySpacing.space16)
                    .padding(.vertical, GravitySpacing.space12)
                    .frame(minHeight: minimumHeight)
                    .modifier(ShopConversationStarterGlass(tint: GravityColor.bgBrand.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("product-conversation-starter-\(starter.id)")
            }
        }
    }
}
