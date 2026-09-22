import SwiftUI
import Gravity
import UIKit

struct ShopSearchToolbarControls<More: View>: View {
    @Binding var query: String
    @Binding var isActive: Bool
    let placeholder: String
    let width: CGFloat
    let showsAvatar: Bool
    let showsMore: Bool
    let colorScheme: ColorScheme?
    let more: More
    let onSubmit: () -> Void
    let onClose: () -> Void
    let returnContext: ShopSearchToolbarReturnContext?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            if showsAvatar {
                ShopSearchToolbarAccountButton()
                    .frame(width: GravitySpacing.space44, height: GravitySpacing.space44)
                    .modifier(ShopSearchToolbarGlass())
                    .opacity(isActive ? 0 : 1)
                    .allowsHitTesting(!isActive)
                    .accessibilityHidden(isActive)
                    .frame(width: isActive ? 0 : GravitySpacing.space44, alignment: .leading)
                    .padding(.trailing, isActive ? 0 : GravitySpacing.space8)
            }

            ShopSearchToolbarField(
                query: $query,
                isActive: $isActive,
                placeholder: placeholder,
                width: fieldWidth,
                foregroundColor: foregroundColor,
                placeholderColor: foregroundColor.opacity(0.4),
                returnContext: returnContext,
                onSubmit: onSubmit
            )

            if returnContext == nil {
                ShopSearchToolbarTrailingControl(
                    isActive: isActive,
                    foregroundColor: foregroundColor,
                    more: more,
                    onClose: onClose
                )
                .modifier(ShopSearchToolbarGlass())
                .opacity(showsTrailingControl ? 1 : 0)
                .allowsHitTesting(showsTrailingControl)
                .accessibilityHidden(!showsTrailingControl)
                .frame(width: showsTrailingControl ? GravitySpacing.space44 : 0, alignment: .trailing)
                .padding(.leading, showsTrailingControl ? GravitySpacing.space8 : 0)
            }
        }
        .frame(width: width, height: GravitySpacing.space44)
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: isActive)
    }

    private var showsTrailingControl: Bool { showsMore || isActive }

    private var fieldWidth: CGFloat {
        let avatar = showsAvatar && !isActive ? GravitySpacing.space44 + GravitySpacing.space8 : 0
        let trailing = returnContext == nil && showsTrailingControl ? GravitySpacing.space44 + GravitySpacing.space8 : 0
        return max(0, width - avatar - trailing)
    }

    private var foregroundColor: Color {
        guard let colorScheme else { return .primary }
        return ShopToolbarForegroundColor.resolve(for: colorScheme)
    }
}

struct ShopSearchToolbarField: View {
    @Binding var query: String
    @Binding var isActive: Bool
    let placeholder: String
    let width: CGFloat
    let foregroundColor: Color
    let placeholderColor: Color
    let returnContext: ShopSearchToolbarReturnContext?
    let onSubmit: () -> Void

    @State private var contextTextWidth: CGFloat = 0

    private var showsContext: Bool { returnContext?.isPresented == true }

    var body: some View {
        HStack(spacing: GravitySpacing.space8) {
            Button {
                if showsContext { returnContext?.onReturn() } else { isActive = true }
            } label: {
                ShopIcon(.search, size: .medium, color: foregroundColor)
                    .frame(height: GravitySpacing.space44)
            }
            .accessibilityLabel(showsContext ? returnContext?.title ?? placeholder : placeholder)

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ShopSearchToolbarTextField(
                        query: $query,
                        isActive: $isActive,
                        placeholder: placeholder,
                        foregroundColor: foregroundColor,
                        placeholderColor: placeholderColor,
                        onSubmit: onSubmit
                    )
                    if query.isEmpty == false {
                        Button { query = "" } label: {
                            ShopIcon(.crossCircleFilled, size: .medium, color: GravityColor.textPlaceholder)
                                .frame(width: GravitySpacing.space44, height: GravitySpacing.space44)
                                .contentShape(.rect)
                        }
                        .accessibilityLabel(localizedString("DiscoverySearch.ClearSearchAccessibilityLabel"))
                        .accessibilityIdentifier("search-toolbar-clear")
                    }
                }
                .opacity(showsContext ? 0 : 1)
                .allowsHitTesting(!showsContext)
                .accessibilityHidden(showsContext)

                if let returnContext {
                    Button(action: returnContext.onReturn) {
                        ShopText(returnContext.title, style: .bodyTitleLarge, color: foregroundColor)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: GravitySpacing.space44, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .opacity(showsContext ? 1 : 0)
                    .allowsHitTesting(showsContext)
                    .accessibilityHidden(!showsContext)
                    .accessibilityIdentifier("agent-toolbar-context")
                }
            }
        }
        .padding(.leading, GravitySpacing.space12)
        .padding(.trailing, showsContext || query.isEmpty ? GravitySpacing.space16 : GravitySpacing.space4)
        .frame(width: capsuleWidth, height: GravitySpacing.space44)
        .modifier(ShopSearchToolbarGlass())
        .frame(width: width, alignment: .leading)
        .background {
            if let returnContext {
                ShopText(returnContext.title, style: .bodyTitleLarge)
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contextTextWidth = $0 }
                    .hidden()
            }
        }
        .animation(.smooth(duration: 0.3), value: showsContext)
    }

    private var capsuleWidth: CGFloat {
        showsContext
            ? min(width, contextTextWidth + 2 * GravitySpacing.space12 + GravitySpacing.space20 + GravitySpacing.space8 + GravitySpacing.space4)
            : width
    }
}

struct ShopSearchToolbarTrailingControl<More: View>: View {
    let isActive: Bool
    let foregroundColor: Color
    let more: More
    let onClose: () -> Void

    var body: some View {
        ZStack {
            more
                .opacity(isActive ? 0 : 1)
                .allowsHitTesting(!isActive)
                .accessibilityHidden(isActive)
            Button(action: onClose) {
                ShopIcon(.cross, size: .medium, color: foregroundColor)
                    .frame(width: GravitySpacing.space44, height: GravitySpacing.space44)
                    .contentShape(.circle)
            }
            .accessibilityLabel(localizedString("Header.CloseA11yLabel"))
            .accessibilityIdentifier("search-toolbar-close")
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
        }
        .frame(width: GravitySpacing.space44, height: GravitySpacing.space44)
    }
}

struct ShopSearchToolbarGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

