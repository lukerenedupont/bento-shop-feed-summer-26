import SwiftUI

/// Persistent bottom navigation bar matching the Figma nav spec.
///
/// Layout: Back (conditional) | Tabs (Home, Search, Cart, Orders, Favorites)
/// Uses glass-style pills with progressive blur background.
/// Sits at the bottom of every screen, ignoring safe area.
struct BottomNavBar: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @Environment(NavigationCoordinator.self) private var coordinator

    /// Whether the cart has items (controls cart button visibility).
    var showCart: Bool = false

    private let iconSize: CGFloat = 24
    private let tabPillHeight: CGFloat = 56
    private let buttonSize: CGFloat = 56

    /// Track previous depth to detect changes

    var body: some View {
        ZStack(alignment: .bottom) {
            // Progressive blur background — extends to bottom edge
            if coordinator.showNavBarBlur {
                VariableBlurView(
                    maxBlurRadius: 8,
                    direction: .bottomBlurToTopTransparent,
                    tintColor: coordinator.navBarBlurTint,
                    tintOpacity: 1
                )
                .frame(height: PurlTune.value("Navigation/BottomNavBar.swift:frame:height:33:32", default: 80))
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // Nav bar content — layered so back/cart animate from behind tabs
            ZStack {
                HStack(spacing: 20) {
                    // No back affordance here: pushed pages carry their own
                    // back chip, and on root pages there is nowhere to go.
                    Spacer()

                    // Cart button — scales out from behind the tab pill
                    if showCart {
                        glassCircleButton(icon: .cart, style: .brand) {
                            // TODO: open cart
                        }
                        .transition(
                            .scale(scale: 0.01, anchor: .leading)
                            .combined(with: .opacity)
                            .combined(with: .modifier(
                                active: BlurModifier(active: true),
                                identity: BlurModifier(active: false)
                            ))
                        )
                    }
                }
                .padding(.horizontal, PurlTune.value("Navigation/BottomNavBar.swift:padding:_:86:39", default: 20))

                // Tab pill — always centered
                tabPill
            }
            .padding(.bottom, PurlTune.value("Navigation/BottomNavBar.swift:padding:_:97:31", default: 28))
        }
        .contentShape(Rectangle())
        .ignoresSafeArea(edges: .bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: PurlTune.value("Navigation/BottomNavBar.swift:spring:response:102:38", default: 0.35), dampingFraction: PurlTune.value("Navigation/BottomNavBar.swift:spring:dampingFraction:102:142", default: 0.8)), value: coordinator.isNavigatedDeep)
        .animation(.spring(response: PurlTune.value("Navigation/BottomNavBar.swift:spring:response:103:38", default: 0.35), dampingFraction: PurlTune.value("Navigation/BottomNavBar.swift:spring:dampingFraction:103:142", default: 0.8)), value: showCart)
    }

    // MARK: - Tab Pill

    private var tabPill: some View {
        HStack(spacing: 0) {
            tabItem(icon: .homeFilled, page: 0)
            tabItem(icon: .searchFilled, page: 3)
            tabItem(icon: .cartFilled, page: 4)
            tabItem(icon: .orderFilled, page: 1)
            tabItem(icon: .favoritesFilled, page: 5)
        }
        .padding(PurlTune.value("Navigation/BottomNavBar.swift:padding:_:127:18", default: 6))
        .frame(height: tabPillHeight)
        .background(.white.opacity(PurlTune.value("Navigation/BottomNavBar.swift:opacity:_:129:36", default: 0.75)))
        .clipShape(Capsule())
        .glassEffect(.regular, in: .capsule)
    }

    private func tabItem(icon: GravityIcon, page: Int) -> some View {
        let isSelected = coordinator.selectedPage == page

        return Button {
            HapticFeedback.light.fire()
            withAnimation(.spring(response: PurlTune.value("Navigation/BottomNavBar.swift:spring:response:139:45", default: 0.25), dampingFraction: PurlTune.value("Navigation/BottomNavBar.swift:spring:dampingFraction:139:149", default: 0.75))) {
                coordinator.navigateToPage(page)
            }
        } label: {
            ZStack {
                // Selection indicator circle
                if isSelected {
                    Circle()
                        .fill(PurlTune.token("Navigation/BottomNavBar.swift:fill:_:147:31", default: GravityColors.bgOverlayFixedDark04, options: GravityColors.purlTuneColorOptions))
                        .frame(width: PurlTune.value("Navigation/BottomNavBar.swift:frame:width:148:39", default: 44), height: PurlTune.value("Navigation/BottomNavBar.swift:frame:height:148:128", default: 44))
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }

                icon.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(
                        isSelected ? GravityColors.text : GravityColors.textTertiary
                    )
            }
            .frame(width: PurlTune.value("Navigation/BottomNavBar.swift:frame:width:160:27", default: 50), height: PurlTune.value("Navigation/BottomNavBar.swift:frame:height:160:116", default: 44))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.85))
        .animation(.spring(response: PurlTune.value("Navigation/BottomNavBar.swift:spring:response:164:38", default: 0.25), dampingFraction: PurlTune.value("Navigation/BottomNavBar.swift:spring:dampingFraction:164:142", default: 0.75)), value: isSelected)
    }

    // MARK: - Glass Circle Button

    enum CircleButtonStyle {
        case standard
        case brand
    }

    private func glassCircleButton(
        icon: GravityIcon,
        style: CircleButtonStyle = .standard,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticFeedback.light.fire()
            action()
        } label: {
            icon.image
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(style == .brand ? .white : GravityColors.text)
                .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
        .background {
            if style == .brand {
                Circle().fill(PurlTune.token("Navigation/BottomNavBar.swift:fill:_:193:31", default: GravityColors.bgFillBrand, options: GravityColors.purlTuneColorOptions))
            } else {
                Circle().fill(.white.opacity(PurlTune.value("Navigation/BottomNavBar.swift:opacity:_:195:46", default: 0.75)))
            }
        }
        .clipShape(Circle())
        .if(style == .standard) { view in
            view.glassEffect(.regular, in: .circle)
        }
    }
}

// MARK: - Conditional Modifier Helper

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
