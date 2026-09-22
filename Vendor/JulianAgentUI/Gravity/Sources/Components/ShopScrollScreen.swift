import SwiftUI

private struct ShopBottomOverlayInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct ShopTopSafeAreaInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct ShopBottomSafeAreaInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

public extension EnvironmentValues {
    var shopBottomOverlayInset: CGFloat {
        get { self[ShopBottomOverlayInsetKey.self] }
        set { self[ShopBottomOverlayInsetKey.self] = newValue }
    }

    var shopTopSafeAreaInset: CGFloat {
        get { self[ShopTopSafeAreaInsetKey.self] }
        set { self[ShopTopSafeAreaInsetKey.self] = newValue }
    }

    var shopBottomSafeAreaInset: CGFloat {
        get { self[ShopBottomSafeAreaInsetKey.self] }
        set { self[ShopBottomSafeAreaInsetKey.self] = newValue }
    }
}

public extension View {
    func shopBottomOverlayInset(_ inset: CGFloat) -> some View {
        environment(\.shopBottomOverlayInset, inset)
    }

    func shopTopSafeAreaInset(_ inset: CGFloat) -> some View {
        environment(\.shopTopSafeAreaInset, inset)
    }

    func shopBottomSafeAreaInset(_ inset: CGFloat) -> some View {
        environment(\.shopBottomSafeAreaInset, inset)
    }
}

public struct ShopScrollScreen<Content: View>: View {
    @Environment(\.shopBottomOverlayInset) private var bottomOverlayInset
    @Environment(\.shopTopSafeAreaInset) private var topSafeAreaInset

    private let title: String?
    private let titleDisplayMode: ToolbarTitleDisplayMode
    private let showsIndicators: Bool
    private let horizontalPadding: CGFloat
    private let verticalSpacing: CGFloat
    private let contentTopPadding: CGFloat?
    private let contentBottomPadding: CGFloat
    private let content: Content

    public init(
        _ title: String,
        titleDisplayMode: ToolbarTitleDisplayMode = .large,
        showsIndicators: Bool = false,
        horizontalPadding: CGFloat = GravitySpacing.screenMargin,
        verticalSpacing: CGFloat = GravitySpacing.sectionGap,
        contentTopPadding: CGFloat? = nil,
        contentBottomPadding: CGFloat = GravitySpacing.space48,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.titleDisplayMode = titleDisplayMode
        self.showsIndicators = showsIndicators
        self.horizontalPadding = horizontalPadding
        self.verticalSpacing = verticalSpacing
        self.contentTopPadding = contentTopPadding
        self.contentBottomPadding = contentBottomPadding
        self.content = content()
    }

    public init(
        showsIndicators: Bool = false,
        horizontalPadding: CGFloat = GravitySpacing.screenMargin,
        verticalSpacing: CGFloat = GravitySpacing.space24,
        contentTopPadding: CGFloat? = nil,
        contentBottomPadding: CGFloat = GravitySpacing.space48,
        @ViewBuilder content: () -> Content
    ) {
        self.title = nil
        self.titleDisplayMode = .inline
        self.showsIndicators = showsIndicators
        self.horizontalPadding = horizontalPadding
        self.verticalSpacing = verticalSpacing
        self.contentTopPadding = contentTopPadding
        self.contentBottomPadding = contentBottomPadding
        self.content = content()
    }

    public var body: some View {
        ScrollView(showsIndicators: showsIndicators) {
            VStack(alignment: .leading, spacing: verticalSpacing) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, contentTopPadding ?? defaultContentTopPadding)
            .padding(.bottom, contentBottomPadding + bottomOverlayInset)
        }
        // SwiftUI's soft scroll-edge effect only renders where content scrolls
        // under a bar, so this is effective for titled screens (which have a
        // navigation bar) and a no-op for bar-less custom-chrome screens.
        .shopScrollEdgeEffect()
        .background(GravityColor.bg.ignoresSafeArea())
        .overlay(alignment: .top) {
            // Untitled screens are bar-less, so they can't anchor the system
            // scroll-edge effect. Paint an equivalent soft fade at the top by
            // default: cover the status bar and fade content into the background
            // beneath it. Titled screens get the real effect from the nav bar.
            if title == nil {
                ShopTopScrollFade(safeAreaInset: topSafeAreaInset)
            }
        }
        .modifier(OptionalNavigationTitle(title: title, titleDisplayMode: titleDisplayMode))
    }

    private var defaultContentTopPadding: CGFloat {
        if title == nil {
            return topSafeAreaInset
        }

        // Titled screens use SwiftUI's navigation bar, so the system owns the
        // status-bar safe area. Untitled screens are custom chrome surfaces.
        return GravitySpacing.space24
    }
}

private struct OptionalNavigationTitle: ViewModifier {
    let title: String?
    let titleDisplayMode: ToolbarTitleDisplayMode

    func body(content: Content) -> some View {
        if let title {
            content
                .navigationTitle(title)
                .toolbarTitleDisplayMode(titleDisplayMode)
        } else {
            content
        }
    }
}

#Preview("ShopScrollScreen") {
    ShopScrollScreen {
        ShopSectionHeader("Section")
        ShopCard {
            ShopText("Content")
        }
    }
}
