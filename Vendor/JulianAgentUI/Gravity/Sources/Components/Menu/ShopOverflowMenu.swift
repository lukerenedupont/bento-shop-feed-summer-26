import SwiftUI
import UIKit

private let shopOverflowMenuWidthRatio: CGFloat = 0.75

private let shopOverflowMenuFallbackWidth: CGFloat = 280

public func shopOverflowMenuUsesPopover(
    dynamicTypeSize: DynamicTypeSize,
    isAccessibilityContentSizeCategory: Bool
) -> Bool {
    dynamicTypeSize.isAccessibilitySize || isAccessibilityContentSizeCategory
}

public func shopOverflowMenuWidth(availableWidth: CGFloat) -> CGFloat {
    guard availableWidth > 0 else { return shopOverflowMenuFallbackWidth }
    return availableWidth * shopOverflowMenuWidthRatio
}

public struct ShopOverflowMenu: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let accessibilityLabel: String
    private let accessibilityIdentifier: String?
    private let accessibilityHint: String?
    private let items: [ShopContextMenuItem]
    private let onOpen: (() -> Void)?
    private let onClose: (() -> Void)?

    @State private var isPopoverPresented = false
    @State private var popoverWidth = shopOverflowMenuFallbackWidth
    @State private var pendingSelection: (() -> Void)?
    @State private var contentSizeCategoryRevision = 0

    public init(
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        accessibilityHint: String? = nil,
        onOpen: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        @ShopContextMenuBuilder items: () -> [ShopContextMenuItem]
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityHint = accessibilityHint
        self.onOpen = onOpen
        self.onClose = onClose
        self.items = items()
    }

    private var usesPopover: Bool {
        shopOverflowMenuUsesPopover(
            dynamicTypeSize: dynamicTypeSize,
            isAccessibilityContentSizeCategory: UIApplication.shared
                .preferredContentSizeCategory
                .isAccessibilityCategory
        )
    }

    public var body: some View {
        menu
            .id(contentSizeCategoryRevision)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIContentSizeCategory.didChangeNotification
                )
            ) { _ in
                contentSizeCategoryRevision += 1
            }
    }

    @ViewBuilder
    private var menu: some View {
        if usesPopover {
            popoverTrigger
        } else {
            ShopMenu(
                accessibilityLabel: accessibilityLabel,
                accessibilityIdentifier: accessibilityIdentifier,
                accessibilityHint: accessibilityHint,
                onOpen: onOpen,
                onClose: onClose,
                items: { items },
                label: { triggerLabel }
            )
            .shopToolbarIconStyle()
        }
    }

    private var triggerLabel: some View {
        Label {
            SwiftUI.Text(accessibilityLabel)
        } icon: {
            ShopIcon(.overflow, size: .medium)
        }
    }

    private var popoverTrigger: some View {
        SwiftUI.Button(action: presentPopover) {
            triggerLabel
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
        .accessibilityHint(accessibilityHint ?? "")
        .shopToolbarIconStyle()
        .popover(isPresented: $isPopoverPresented) {
            ShopOverflowMenuPopoverContent(
                items: items,
                width: popoverWidth,
                onSelect: select
            )
            .presentationCompactAdaptation(.popover)
            .onDisappear(perform: handlePopoverDismissed)
        }
    }

    private func presentPopover() {
        popoverWidth = shopOverflowMenuWidth(availableWidth: Self.hostingWindowWidth())
        pendingSelection = nil
        isPopoverPresented = true
        onOpen?()
    }

    private func select(_ item: ShopContextMenuItem) {
        pendingSelection = item.action
        isPopoverPresented = false
    }

    private func handlePopoverDismissed() {
        let action = pendingSelection
        pendingSelection = nil
        onClose?()
        action?()
    }

    private static func hostingWindowWidth() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .bounds.width ?? 0
    }
}

private struct ShopOverflowMenuPopoverContent: View {
    let items: [ShopContextMenuItem]
    let width: CGFloat
    let onSelect: (ShopContextMenuItem) -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            rows
            ScrollView {
                rows
            }
        }
        .frame(width: width, alignment: .leading)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                SwiftUI.Button {
                    onSelect(item)
                } label: {
                    HStack(alignment: .center, spacing: GravitySpacing.space16) {
                        if let icon = item.icon {
                            ShopIcon(icon, size: .medium, color: color(for: item))
                        }
                        ShopText(item.title, style: .bodyLarge, color: color(for: item))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, GravitySpacing.space16)
                    .padding(.vertical, GravitySpacing.space12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(item.enabled == false)
                .accessibilityIdentifier(item.id)
            }
        }
        .padding(.vertical, GravitySpacing.space8)
    }

    private func color(for item: ShopContextMenuItem) -> Color {
        guard item.enabled else { return GravityColor.textPlaceholder }
        return item.role == .destructive ? GravityColor.textCritical : GravityColor.text
    }
}
