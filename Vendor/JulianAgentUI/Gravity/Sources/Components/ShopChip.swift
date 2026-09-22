import SwiftUI

public enum ShopChipVariant: Sendable, CaseIterable {
    /// Solid Gravity fill with a token border. Use on ordinary app backgrounds.
    case flat
    /// Native glass/elevated pill for image, gradient, or floating-chrome contexts.
    case glass
}

/// Controls how an unselected glass chip resolves a `nil` `glassTint`.
public enum ShopChipGlassTintFallback: Sendable {
    /// Uses the standard Gravity fill, preserving existing ShopChip behavior.
    case gravityFill
    /// Leaves the glass material untinted.
    case none
}

public enum ShopChipSize: Sendable, CaseIterable {
    case small
    case medium
    case large

    var minHeight: CGFloat {
        switch self {
        case .small: 32
        case .medium: GravitySpacing.space36
        case .large: 40
        }
    }

    var textStyle: GravityTextStyle {
        switch self {
        case .small, .medium: .buttonSmall
        case .large: .buttonMedium
        }
    }

    var mediaSize: CGFloat {
        switch self {
        case .small, .medium: GravitySpacing.space24
        case .large: GravitySpacing.space32
        }
    }

    var mediaOnlySize: CGFloat {
        switch self {
        case .small: 28
        case .medium: GravitySpacing.space32
        case .large: GravitySpacing.space36
        }
    }

    var accessibilityLabeledMediaMaximumSize: CGFloat {
        switch self {
        case .small, .medium: GravitySpacing.space40
        case .large: GravitySpacing.space48
        }
    }

    /// Only `small` tightens gaps and horizontal padding; `medium` shares `large`'s spacing.
    var usesCompactMetrics: Bool {
        switch self {
        case .small: true
        case .medium, .large: false
        }
    }
}

func shopChipUsesAccessibilityReflow(
    hasTitle: Bool,
    isAccessibilitySize: Bool,
    maximumWidth: CGFloat?
) -> Bool {
    guard hasTitle, isAccessibilitySize, let maximumWidth else {
        return false
    }

    return maximumWidth.isFinite && maximumWidth > 0
}

func shopChipTitleLineLimit(
    usesAccessibilityReflow: Bool,
    accessibilityReflowLineLimit: Int? = nil
) -> Int? {
    usesAccessibilityReflow ? accessibilityReflowLineLimit : 1
}

func shopChipTitleAlignment(usesAccessibilityReflow: Bool) -> TextAlignment {
    usesAccessibilityReflow ? .leading : .center
}

func shopChipAccessibilityTrailingClearance(usesAccessibilityReflow: Bool) -> CGFloat {
    usesAccessibilityReflow ? GravitySpacing.space4 : GravitySpacing.space0
}

func shopChipAccessibilityAvailableWidth(
    maximumWidth: CGFloat,
    proposalWidth: CGFloat?
) -> CGFloat {
    guard let proposalWidth, proposalWidth.isFinite else {
        return maximumWidth
    }

    return min(maximumWidth, max(proposalWidth, 0))
}

func shopChipMediaDimension(
    size: ShopChipSize,
    isMediaOnly: Bool,
    usesAccessibilityReflow: Bool,
    scaledLabeledMediaSize: CGFloat
) -> CGFloat {
    guard !isMediaOnly else {
        return size.mediaOnlySize
    }

    guard usesAccessibilityReflow else {
        return size.mediaSize
    }

    return min(
        max(size.mediaSize, scaledLabeledMediaSize),
        size.accessibilityLabeledMediaMaximumSize
    )
}

func shopChipUsesCustomGlassForeground(
    variant: ShopChipVariant,
    isSelected: Bool
) -> Bool {
    guard !isSelected else {
        return false
    }

    switch variant {
    case .flat:
        return false
    case .glass:
        return true
    }
}

func shopChipResolvedGlassTint<T>(
    explicitTint: T?,
    fallback: ShopChipGlassTintFallback,
    gravityFill: @autoclosure () -> T
) -> T? {
    if let explicitTint {
        return explicitTint
    }

    switch fallback {
    case .gravityFill:
        return gravityFill()
    case .none:
        return nil
    }
}

private func preconditionValidShopChipAccessibilityReflowMaximumWidth(_ maximumWidth: CGFloat?) {
    guard let maximumWidth else {
        return
    }

    precondition(
        maximumWidth.isFinite && maximumWidth > 0,
        "ShopChip accessibilityReflowMaximumWidth must be positive and finite"
    )
}

private func preconditionValidShopChipAccessibilityReflowLineLimit(_ lineLimit: Int?) {
    guard let lineLimit else {
        return
    }

    precondition(
        lineLimit > 0,
        "ShopChip accessibilityReflowLineLimit must be positive"
    )
}

private enum ShopChipLayout {
    case label
    case leadingIconLabel
    case labelTrailingIcon
    case mediaLabel
    case mediaTrailingIcon
    case mediaOnly
    case iconOnly

    var gap: CGFloat {
        switch self {
        case .label, .mediaOnly, .iconOnly:
            GravitySpacing.space0
        case .leadingIconLabel, .mediaTrailingIcon:
            GravitySpacing.space4
        case .labelTrailingIcon:
            GravitySpacing.space2
        case .mediaLabel:
            GravitySpacing.space8
        }
    }

    func resolvedGap(for size: ShopChipSize) -> CGFloat {
        if self == .mediaLabel, size.usesCompactMetrics {
            return GravitySpacing.space6
        }
        return gap
    }

    func contentPadding(for size: ShopChipSize) -> EdgeInsets {
        switch (size.usesCompactMetrics, self) {
        case (_, .iconOnly):
            EdgeInsets()
        case (_, .mediaOnly):
            EdgeInsets(horizontal: GravitySpacing.space2)
        case (true, .label):
            EdgeInsets(horizontal: GravitySpacing.space12)
        case (false, .label):
            EdgeInsets(horizontal: GravitySpacing.space16)
        case (true, .leadingIconLabel):
            EdgeInsets(leading: GravitySpacing.space8, trailing: GravitySpacing.space12)
        case (false, .leadingIconLabel):
            EdgeInsets(leading: GravitySpacing.space12, trailing: GravitySpacing.space16)
        case (true, .labelTrailingIcon):
            EdgeInsets(leading: GravitySpacing.space12, trailing: GravitySpacing.space8)
        case (false, .labelTrailingIcon):
            EdgeInsets(leading: GravitySpacing.space16, trailing: GravitySpacing.space12)
        case (true, .mediaLabel):
            EdgeInsets(leading: GravitySpacing.space4, trailing: GravitySpacing.space8)
        case (false, .mediaLabel):
            EdgeInsets(leading: GravitySpacing.space4, trailing: GravitySpacing.space12)
        case (true, .mediaTrailingIcon):
            EdgeInsets(leading: GravitySpacing.space4, trailing: GravitySpacing.space6)
        case (false, .mediaTrailingIcon):
            EdgeInsets(leading: GravitySpacing.space4, trailing: GravitySpacing.space8)
        }
    }
}

/// Pressable pill-shaped control for filters, tags, and compact selection actions.
///
/// `ShopChip` intentionally keeps a smaller native API than the React Native component:
/// structured label/icon/media inputs, native selection state, token-backed sizes, and
/// flat/glass variants. Feature-specific custom compositions should wrap this primitive
/// instead of passing arbitrary view trees through the design-system API.
public struct ShopChip<Media: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var scaledSmallLabeledMediaSize = GravitySpacing.space24
    @ScaledMetric(relativeTo: .body) private var scaledLargeLabeledMediaSize = GravitySpacing.space32

    private let title: String?
    private let leadingIcon: GravityIconName?
    private let trailingIcon: GravityIconName?
    private let media: Media?
    private let variant: ShopChipVariant
    private let glassTint: Color?
    private let glassTintFallback: ShopChipGlassTintFallback
    private let glassForegroundTint: Color?
    private let glassOutline: Color?
    private let glassMaterial: ShopGlassMaterial
    private let size: ShopChipSize
    private let isSelected: Bool
    private let accessibilityLabel: String?
    private let accessibilityReflowMaximumWidth: CGFloat?
    private let accessibilityReflowLineLimit: Int?
    private let action: () -> Void

    /// Creates a chip with optional structured media.
    ///
    /// - Parameters:
    ///   - glassTint: Optional tint for an unselected glass chip.
    ///   - glassTintFallback: How a `nil` `glassTint` is resolved. The default preserves the
    ///     existing Gravity fill; pass `.none` to leave the glass material untinted.
    ///   - glassForegroundTint: Foreground tint for an unselected glass chip. Flat and selected
    ///     chips keep their existing foreground colors.
    ///   - accessibilityReflowMaximumWidth: A positive, finite maximum width for the complete chip;
    ///     passing zero, a negative value, infinity, or NaN fails a precondition. It has no effect
    ///     without a title or at standard Dynamic Type sizes. At accessibility
    ///     sizes, oversized content wraps within this cap while short content remains intrinsic.
    ///     Raster or remote media should be sourced at 40×40 points for a small chip and 48×48
    ///     points for a large chip, with the image loader accounting for display scale.
    ///   - accessibilityReflowLineLimit: Optional positive line limit applied only while accessibility
    ///     reflow is active. The default `nil` allows the complete label to wrap.
    public init(
        _ title: String? = nil,
        leadingIcon: GravityIconName? = nil,
        trailingIcon: GravityIconName? = nil,
        variant: ShopChipVariant = .flat,
        glassTint: Color? = nil,
        glassTintFallback: ShopChipGlassTintFallback = .gravityFill,
        glassForegroundTint: Color? = nil,
        glassOutline: Color? = nil,
        glassMaterial: ShopGlassMaterial = .regular,
        size: ShopChipSize = .large,
        isSelected: Bool = false,
        accessibilityLabel: String? = nil,
        accessibilityReflowMaximumWidth: CGFloat? = nil,
        accessibilityReflowLineLimit: Int? = nil,
        @ViewBuilder media: () -> Media,
        action: @escaping () -> Void
    ) {
        preconditionValidShopChipAccessibilityReflowMaximumWidth(accessibilityReflowMaximumWidth)
        preconditionValidShopChipAccessibilityReflowLineLimit(accessibilityReflowLineLimit)

        self.title = title
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.media = media()
        self.variant = variant
        self.glassTint = glassTint
        self.glassTintFallback = glassTintFallback
        self.glassForegroundTint = glassForegroundTint
        self.glassOutline = glassOutline
        self.glassMaterial = glassMaterial
        self.size = size
        self.isSelected = isSelected
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityReflowMaximumWidth = accessibilityReflowMaximumWidth
        self.accessibilityReflowLineLimit = accessibilityReflowLineLimit
        self.action = action
    }

    public var body: some View {
        SwiftUI.Button(action: action) {
            styledContent
                .clipShape(containerShape)
                .gravityShadow(variant == .glass ? .s : .none)
                .contentShape(containerShape)
        }
        .buttonStyle(ShopChipScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SwiftUI.Text(resolvedAccessibilityLabel))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var styledContent: some View {
        switch variant {
        case .flat:
            sizedContent.background { selectedFlatOrUnselectedBackground }
        case .glass:
            sizedContent.shopGlassCapsule(
                tint: isSelected ? GravityColor.bgFillInverse : resolvedGlassTint,
                isInteractive: true,
                material: glassMaterial,
                outline: glassOutline
            )
        }
    }

    private var hasMedia: Bool {
        media != nil
    }

    private var usesAccessibilityReflow: Bool {
        shopChipUsesAccessibilityReflow(
            hasTitle: title != nil,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
            maximumWidth: accessibilityReflowMaximumWidth
        )
    }

    @ViewBuilder
    private var sizedContent: some View {
        if usesAccessibilityReflow, let accessibilityReflowMaximumWidth {
            ShopChipAccessibilityWidthCapLayout(maximumWidth: accessibilityReflowMaximumWidth) {
                content
                    // Preserve a small trailing optical clearance for multiline fragments.
                    .padding(
                        .trailing,
                        shopChipAccessibilityTrailingClearance(usesAccessibilityReflow: true)
                    )
                    .padding(.vertical, GravitySpacing.space4)
                    .frame(width: fixedWidth)
                    .frame(minHeight: size.minHeight)
            }
        } else {
            content
                .frame(width: fixedWidth)
                .frame(minHeight: size.minHeight)
        }
    }

    private var layout: ShopChipLayout {
        if hasMedia, title != nil {
            return .mediaLabel
        }

        if hasMedia, trailingIcon != nil {
            return .mediaTrailingIcon
        }

        if hasMedia {
            return .mediaOnly
        }

        if title == nil, leadingIcon != nil, trailingIcon == nil {
            return .iconOnly
        }

        if leadingIcon != nil {
            return .leadingIconLabel
        }

        if trailingIcon != nil {
            return .labelTrailingIcon
        }

        return .label
    }

    private var fixedWidth: CGFloat? {
        switch layout {
        case .iconOnly, .mediaOnly:
            size.minHeight
        default:
            nil
        }
    }

    private var containerShape: Capsule {
        Capsule()
    }

    private var foregroundColor: Color {
        if let glassForegroundTint,
           shopChipUsesCustomGlassForeground(variant: variant, isSelected: isSelected) {
            return glassForegroundTint
        }

        return switch (variant, isSelected) {
        case (.glass, true):
            if #available(iOS 26.0, *) {
                GravityColor.textInverse
            } else {
                // legacy glass has a light background when selected, see ShopLegacyGlassLayers
                GravityColor.textFixedDark
            }
        case (_, true):
            GravityColor.textInverse
        case (_, false):
            GravityColor.text
        }
    }

    private var resolvedAccessibilityLabel: String {
        accessibilityLabel ?? title ?? ""
    }

    private var resolvedGlassTint: Color? {
        return shopChipResolvedGlassTint(
            explicitTint: glassTint,
            fallback: glassTintFallback,
            gravityFill: GravityColor.bgFill
        )
    }

    private var content: some View {
        HStack(spacing: layout.resolvedGap(for: size)) {
            if let media {
                mediaSlot(media, solo: layout == .mediaOnly)
                    .accessibilityHidden(true)
            }

            if let leadingIcon, !hasMedia {
                ShopIcon(leadingIcon, size: .small, color: foregroundColor)
                    .accessibilityHidden(true)
            }

            if let title {
                titleView(title)
            }

            if let trailingIcon {
                ShopIcon(trailingIcon, size: .small, color: foregroundColor)
                    .accessibilityHidden(true)
            }
        }
        .padding(layout.contentPadding(for: size))
    }

    @ViewBuilder
    private func titleView(_ title: String) -> some View {
        let label = ShopText(
            title,
            style: size.textStyle,
            color: foregroundColor,
            alignment: shopChipTitleAlignment(usesAccessibilityReflow: usesAccessibilityReflow)
        )
        .lineLimit(shopChipTitleLineLimit(
            usesAccessibilityReflow: usesAccessibilityReflow,
            accessibilityReflowLineLimit: accessibilityReflowLineLimit
        ))
        .truncationMode(.tail)

        if usesAccessibilityReflow {
            label.fixedSize(horizontal: false, vertical: true)
        } else {
            label
        }
    }

    private var scaledLabeledMediaSize: CGFloat {
        switch size {
        case .small, .medium: scaledSmallLabeledMediaSize
        case .large: scaledLargeLabeledMediaSize
        }
    }

    private func mediaSlot(_ media: Media, solo: Bool) -> some View {
        let mediaSize = shopChipMediaDimension(
            size: size,
            isMediaOnly: solo,
            usesAccessibilityReflow: usesAccessibilityReflow,
            scaledLabeledMediaSize: scaledLabeledMediaSize
        )

        return media
            .frame(width: mediaSize, height: mediaSize)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(GravityColor.bgOverlayFixedLight20, lineWidth: 1)
            }
    }

    @ViewBuilder
    private var selectedFlatOrUnselectedBackground: some View {
        if isSelected {
            selectedFlatBackground
        } else {
            flatBackground(borderColor: GravityColor.border)
        }
    }

    private var selectedFlatBackground: some View {
        containerShape
            .fill(GravityColor.bgFillInverse)
            .overlay {
                containerShape.stroke(GravityColor.bgFillInverse, lineWidth: 1)
            }
    }

    private func flatBackground(borderColor: Color) -> some View {
        containerShape
            .fill(GravityColor.bgFill)
            .overlay {
                containerShape.stroke(borderColor, lineWidth: 1)
            }
    }

}

public extension ShopChip where Media == EmptyView {
    /// Creates a chip without media.
    ///
    /// - Parameters:
    ///   - glassTint: Optional tint for an unselected glass chip.
    ///   - glassTintFallback: How a `nil` `glassTint` is resolved. The default preserves the
    ///     existing Gravity fill; pass `.none` to leave the glass material untinted.
    ///   - glassForegroundTint: Foreground tint for an unselected glass chip. Flat and selected
    ///     chips keep their existing foreground colors.
    ///   - accessibilityReflowMaximumWidth: A positive, finite maximum width for the complete chip;
    ///     passing zero, a negative value, infinity, or NaN fails a precondition. It has no effect
    ///     without a title or at standard Dynamic Type sizes. At accessibility
    ///     sizes, oversized content wraps within this cap while short content remains intrinsic.
    ///     If a labeled chip later adds raster or remote media, source it at the accessibility cap:
    ///     40×40 points for a small chip or 48×48 points for a large chip, with the loader accounting
    ///     for display scale.
    ///   - accessibilityReflowLineLimit: Optional positive line limit applied only while accessibility
    ///     reflow is active. The default `nil` allows the complete label to wrap.
    init(
        _ title: String? = nil,
        leadingIcon: GravityIconName? = nil,
        trailingIcon: GravityIconName? = nil,
        variant: ShopChipVariant = .flat,
        glassTint: Color? = nil,
        glassTintFallback: ShopChipGlassTintFallback = .gravityFill,
        glassForegroundTint: Color? = nil,
        glassOutline: Color? = nil,
        glassMaterial: ShopGlassMaterial = .regular,
        size: ShopChipSize = .large,
        isSelected: Bool = false,
        accessibilityLabel: String? = nil,
        accessibilityReflowMaximumWidth: CGFloat? = nil,
        accessibilityReflowLineLimit: Int? = nil,
        action: @escaping () -> Void
    ) {
        preconditionValidShopChipAccessibilityReflowMaximumWidth(accessibilityReflowMaximumWidth)
        preconditionValidShopChipAccessibilityReflowLineLimit(accessibilityReflowLineLimit)

        self.title = title
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.media = nil
        self.variant = variant
        self.glassTint = glassTint
        self.glassTintFallback = glassTintFallback
        self.glassForegroundTint = glassForegroundTint
        self.glassOutline = glassOutline
        self.glassMaterial = glassMaterial
        self.size = size
        self.isSelected = isSelected
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityReflowMaximumWidth = accessibilityReflowMaximumWidth
        self.accessibilityReflowLineLimit = accessibilityReflowLineLimit
        self.action = action
    }
}

private struct ShopChipAccessibilityWidthCapLayout: Layout {
    let maximumWidth: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else {
            return .zero
        }

        let availableWidth = shopChipAccessibilityAvailableWidth(
            maximumWidth: maximumWidth,
            proposalWidth: proposal.width
        )
        let naturalSize = subview.sizeThatFits(.unspecified)
        guard naturalSize.width > availableWidth else {
            return naturalSize
        }

        let constrainedSize = subview.sizeThatFits(
            ProposedViewSize(width: availableWidth, height: nil)
        )
        return CGSize(
            width: min(constrainedSize.width, availableWidth),
            height: constrainedSize.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else {
            return
        }

        subview.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: nil)
        )
    }
}

private struct ShopChipScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.06 : 1)
            .animation(ShopMotion.press, value: configuration.isPressed)
    }
}

private extension EdgeInsets {
    init(horizontal: CGFloat) {
        self.init(top: 0, leading: horizontal, bottom: 0, trailing: horizontal)
    }

    init(leading: CGFloat, trailing: CGFloat) {
        self.init(top: 0, leading: leading, bottom: 0, trailing: trailing)
    }
}

private struct ShopChipPreview: View {
    @State private var favoritesSelected = true
    @State private var pantsSelected = false
    @State private var socksSelected = false
    @State private var mediumSelected = false
    @State private var mediumSwatchSelected = false
    @State private var filterSelected = false
    @State private var smallFilterSelected = false
    @State private var sortSelected = false
    @State private var searchSelected = false
    @State private var redSelected = false
    @State private var blueSelected = false
    @State private var greenSelected = false
    @State private var glassSelected = false
    @State private var selectedGlassSelected = true
    @State private var glassSearchSelected = false
    @State private var gradientGlassSelected = false
    @State private var gradientSelectedGlassSelected = true
    @State private var gradientGlassSearchSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            ShopText("Tap chips to toggle selected state", style: .bodySmall, color: GravityColor.textSecondary)

            HStack(spacing: GravitySpacing.space8) {
                ShopChip("Favorites", leadingIcon: .navigationFavorites, isSelected: favoritesSelected) {
                    favoritesSelected.toggle()
                }
                ShopChip("Pants", isSelected: pantsSelected) {
                    pantsSelected.toggle()
                }
                ShopChip("Socks", size: .small, isSelected: socksSelected) {
                    socksSelected.toggle()
                }
                ShopChip("Medium", size: .medium, isSelected: mediumSelected) {
                    mediumSelected.toggle()
                }
            }

            HStack(spacing: GravitySpacing.space8) {
                ShopChip("Filter", leadingIcon: .filter, isSelected: filterSelected) {
                    filterSelected.toggle()
                }
                ShopChip("Small", leadingIcon: .filter, size: .small, isSelected: smallFilterSelected) {
                    smallFilterSelected.toggle()
                }
                ShopChip("Sort", trailingIcon: .sort, isSelected: sortSelected) {
                    sortSelected.toggle()
                }
                ShopChip(leadingIcon: .search, isSelected: searchSelected, accessibilityLabel: "Search") {
                    searchSelected.toggle()
                }
            }

            HStack(spacing: GravitySpacing.space8) {
                ShopChip("Red", isSelected: redSelected) {
                    Circle().fill(Color.red)
                } action: {
                    redSelected.toggle()
                }
                ShopChip(size: .large, isSelected: blueSelected, accessibilityLabel: "Blue") {
                    Circle().fill(Color.blue)
                } action: {
                    blueSelected.toggle()
                }
                ShopChip(size: .medium, isSelected: mediumSwatchSelected, accessibilityLabel: "Blue medium") {
                    Circle().fill(Color.blue)
                } action: {
                    mediumSwatchSelected.toggle()
                }
                ShopChip(trailingIcon: .sort, isSelected: greenSelected) {
                    Circle().fill(Color.green)
                } action: {
                    greenSelected.toggle()
                }
            }

            HStack(spacing: GravitySpacing.space8) {
                ShopChip("Glass", variant: .glass, isSelected: glassSelected) {
                    glassSelected.toggle()
                }
                ShopChip("Selected", variant: .glass, isSelected: selectedGlassSelected) {
                    selectedGlassSelected.toggle()
                }
                ShopChip(leadingIcon: .search, variant: .glass, isSelected: glassSearchSelected, accessibilityLabel: "Search") {
                    glassSearchSelected.toggle()
                }
            }

            HStack(spacing: GravitySpacing.space8) {
                ShopChip("Glass", variant: .glass, isSelected: gradientGlassSelected) {
                    gradientGlassSelected.toggle()
                }
                ShopChip("Selected", variant: .glass, isSelected: gradientSelectedGlassSelected) {
                    gradientSelectedGlassSelected.toggle()
                }
                ShopChip(leadingIcon: .search, variant: .glass, isSelected: gradientGlassSearchSelected, accessibilityLabel: "Search") {
                    gradientGlassSearchSelected.toggle()
                }
            }
            .padding(GravitySpacing.space16)
            .background(
                LinearGradient(
                    colors: [GravityColor.bgFillBrand, GravityColor.bgFillCritical],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.radius24, style: .continuous))
        }
        .padding()
        .background(GravityColor.bg)
    }
}

private struct ShopChipAccessibilityReflowPreview: View {
    private let maximumWidth: CGFloat = 260

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GravitySpacing.space16) {
                ShopChip(
                    "Sale",
                    accessibilityReflowMaximumWidth: maximumWidth
                ) {}

                ShopChip(
                    "A long category title that can wrap across every line it needs",
                    accessibilityReflowMaximumWidth: maximumWidth
                ) {}

                ShopChip(
                    "A long category title with decorative icons",
                    leadingIcon: .filter,
                    trailingIcon: .sort,
                    accessibilityReflowMaximumWidth: maximumWidth
                ) {}

                ShopChip(
                    "New",
                    variant: .glass,
                    glassTint: GravityColor.bgFillBrandSecondary,
                    glassForegroundTint: GravityColor.textBrand,
                    accessibilityReflowMaximumWidth: maximumWidth
                ) {
                    Circle().fill(GravityColor.bgFillBrand)
                } action: {}

                ShopChip(
                    "A long glass category title with scalable media",
                    variant: .glass,
                    glassTint: GravityColor.bgFillBrandSecondary,
                    glassForegroundTint: GravityColor.textBrand,
                    accessibilityReflowMaximumWidth: maximumWidth
                ) {
                    Circle().fill(GravityColor.bgFillBrand)
                } action: {}

                HStack(spacing: GravitySpacing.space8) {
                    ShopChip(
                        accessibilityLabel: "Brand"
                    ) {
                        Circle().fill(GravityColor.bgFillBrand)
                    } action: {}

                    ShopChip(
                        leadingIcon: .search,
                        accessibilityLabel: "Search"
                    ) {}
                }
            }
            .padding(GravitySpacing.screenMargin)
        }
        .background(GravityColor.bg)
    }
}

#Preview("ShopChip") {
    ShopChipPreview()
}

#Preview("Accessibility Reflow") {
    ShopChipAccessibilityReflowPreview()
        .environment(\.dynamicTypeSize, .accessibility5)
}
