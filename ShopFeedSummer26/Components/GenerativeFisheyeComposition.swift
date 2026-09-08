import SwiftUI
import ShopFisheyeCanvas

/// Shop's adapter. The extracted package knows nothing about this catalog,
/// product media, selection semantics, inspector, or merchant destinations.
struct GenerativeFisheyeComposition: View {
    let spec: NextGenerationFeedCardSpec
    let products: [ResolvedStoryProduct]
    let session: GenerativeFeedPrototypeSession
    let size: CGSize
    let isActive: Bool
    let onOpen: (ResolvedStoryProduct) -> Void

    private var current: GenerativeFeedPrototypeSession.CardState { session.state(for: spec) }
    private var selected: ResolvedStoryProduct? { session.selected(in: products, for: spec) }

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            FisheyeCanvas(
                items: products,
                position: Binding(get: { current.canvasPosition }, set: { session.setCanvasPosition($0, for: spec) }),
                isInteractive: current.canvasIsExploring && current.interactionsEnabled,
                isActive: isActive
            ) { item in
                Button {
                    session.select(item, for: spec)
                    HapticFeedback.selection.fire()
                } label: {
                    GenerativeProductMedia(item: item)
                        .padding(GravitySpacing.space8)
                        .background(.white, in: RoundedRectangle(cornerRadius: GravityRadius.r20))
                        .overlay(alignment: .bottomTrailing) {
                            if selected?.id == item.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(.black, in: Circle())
                                    .padding(GravitySpacing.space8)
                            }
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: GravityRadius.r20)
                                .strokeBorder(selected?.id == item.id ? Color.black : .clear, lineWidth: 2)
                        }
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(!current.interactionsEnabled)
                .accessibilityLabel("Select \(item.product.title)")
                .accessibilityAddTraits(selected?.id == item.id ? .isSelected : [])
            }
            .frame(height: max(160, size.height - 120))
            .background(Color(white: 0.93))
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r24))
            .environment(\.colorScheme, .light)

            Text(current.canvasIsExploring
                ? "Drag to explore. Swipe outside the canvas for the feed."
                : "Tap an item, or explore the library in any direction.")
                .font(GravityFont.regular.fixedFont(size: 12)).foregroundStyle(.secondary)
                .frame(height: 30, alignment: .topLeading)
            if let selected {
                Button {
                    session.setCanvasExploring(false, for: spec)
                    onOpen(selected)
                } label: {
                    HStack(spacing: GravitySpacing.space12) {
                        VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                            Text(selected.product.title)
                                .font(GravityFont.semiBold.fixedFont(size: 15)).lineLimit(2)
                            Text(GenerativeFeedStyle.price(selected.product))
                                .font(GravityFont.regular.fixedFont(size: 14))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        Image(systemName: "arrow.up.right").frame(width: 44, height: 44)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(selected.product.title)")
                .accessibilityIdentifier("generative.canvasProductDetails")
            }
        }
        .onChange(of: isActive) { _, active in
            if !active { session.setCanvasExploring(false, for: spec) }
        }
        .onDisappear { session.setCanvasExploring(false, for: spec) }
    }
}
