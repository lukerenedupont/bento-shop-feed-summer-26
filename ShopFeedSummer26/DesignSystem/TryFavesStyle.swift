import SwiftUI

/// One source of truth for every Try your faves surface: the Home feed card,
/// the world stage, and both sheets.
///
/// Home and the world share tile geometry, type, and colour deliberately —
/// opening the world is a zoom into the same design, not a change of design.
enum TryFavesStyle {

    // MARK: - Stage

    /// Notification dot on the "View new look" chip and the configuration
    /// button. Fixed, because it always sits on a light photograph.
    static let badge = Color(hex: "#4A90D9")

    /// The Home card's backing. In the world the canvas is sampled from the
    /// look on screen instead — see `TryFavesStageColors` — because a fixed
    /// grey cannot sit under a warm interior and a mountaintop at once.
    static let canvas = Color(hex: "#EAEAEA")

    /// How far the photograph rides above the page.
    ///
    /// Centred, the frame puts the subject's feet well down behind the look
    /// panel. Lifting it sets the figure back where the composition wants it,
    /// and the strip the lift leaves at the foot of the page is filled with
    /// the frame's own sampled ground tone, so the lift itself is invisible.
    static let frameLift: CGFloat = 96

    /// The header and panel fades are one treatment, mirrored: the same
    /// dissolve and the same reach, one running down from the top edge and one
    /// up from the bottom. Kept here so they cannot drift apart.
    static let fadeSolidUntil: CGFloat = 0.6
    static let fadeBleed: CGFloat = 12

    /// Swiping between looks crossfades the chrome tones rather than cutting
    /// them, so the stage reads as one surface responding to the photograph.
    static let bandsFade = Animation.easeInOut(duration: 0.3)

    // MARK: - Chrome on the stage

    /// Stage type is fixed white over the photography in both light and dark
    /// mode.
    static let stageText = GravityColors.textFixedLight
    static let stageTextSecondary = GravityColors.textFixedLight.opacity(0.7)
    static let chromeHeight: CGFloat = 36

    // MARK: - Floating glass

    /// Every floating surface in the world is this one treatment: the header
    /// buttons, the status chip, and both sheet plates. A sheet is a chip at a
    /// larger size, not a different material — see `tryFavesGlass(in:)`.
    ///
    /// The tint has to sit *on* the glass rather than behind it; layered
    /// underneath, the bright material washes it out.
    ///
    /// A step above the design's `IconButton/Blurred` value. Liquid Glass
    /// carries most of the separation; the tint only has to keep white type
    /// off bright patches of the stage photography, and 10% did not quite.
    static let glassFill = GravityColors.bgOverlayFixedDark20

    // MARK: - Product tiles

    /// Shared by the Home card grid, the look panel rail, and the composer.
    static let tileRadius = GravityRadius.r20
    /// A white well keeps transparent product PNGs reading as product cards.
    static let tileWell = Color.white
    static let tileBorder = Color(hex: "#05294D").opacity(0.08)
    static let tileShadow = GravityShadows.small
    /// The look panel's tile width, from the design's 118pt ProductCard.
    static let lookTileWidth: CGFloat = 118
    /// The composer's tile width, from the design's 110pt ProductCard.
    static let composerTileWidth: CGFloat = 110
    /// Merchant, product, price — three 16pt lines, pinned so a short title
    /// and a long one occupy the same block.
    static let tileMetaHeight: CGFloat = 48

    // MARK: - Look panel

    /// The panel is a fixed block, not a hug.
    ///
    /// Its content legitimately varies — the seed look has no overflow menu,
    /// a shoes-only look has one tile instead of three — and a hugging panel
    /// would resize under the pager on every swipe and every delete. Composed
    /// from its parts so the total can't drift away from them.
    static let panelTopInset = GravitySpacing.space24
    static let panelTitleHeight: CGFloat = 32
    static let panelTitleGap = GravitySpacing.space12
    static let panelRailHeight = lookTileWidth + GravitySpacing.space8 + tileMetaHeight
    /// Clears the pagination dots and the home indicator below the panel.
    static let panelBottomInset: CGFloat = 76

    static var panelHeight: CGFloat {
        panelTopInset + panelTitleHeight + panelTitleGap + panelRailHeight + panelBottomInset
    }

    // MARK: - Sheets

    /// A sheet fades in over a softened, barely-darkened stage. The blur lives
    /// on the stage itself rather than in a material behind the sheet, so the
    /// sheet never samples its own plate and the stage stays put — nothing
    /// slides. Light enough that the look stays readable underneath.
    static let stageBlur: CGFloat = 8
    /// Gravity's lightest fixed dark overlay — the token nearest the design's
    /// 5% black. Barely there: the blur does the separating, not the darkening.
    static let sheetScrim = GravityColors.bgOverlayFixedDark04

    /// How far a sheet rises as it appears. Enough to read as arriving from
    /// the bottom edge, well short of a system sheet's full travel.
    static let sheetRise: CGFloat = 48
    static let sheetMotion = Animation.spring(response: 0.34, dampingFraction: 0.92)

    /// The plate fades and rises; the scrim behind it only fades, because a
    /// backdrop that slides reads as a second moving object.
    static let sheetTransition: AnyTransition = .opacity.combined(with: .offset(y: sheetRise))

    /// Swipe-to-dismiss: far enough that a scroll or a mis-grab won't trigger
    /// it, or a flick fast enough to mean it regardless of distance.
    static let sheetDismissDistance: CGFloat = 120
    static let sheetDismissFlick: CGFloat = 240

    /// Both sheets are the same glass plate as the chrome, at sheet radius.
    static let sheetRadius = GravityRadius.r40
    static let sheetInset = GravitySpacing.space12
    static let sheetText = GravityColors.textFixedLight
    static let sheetTextSecondary = GravityColors.textFixedLight.opacity(0.7)
}

extension View {
    /// The world's floating glass surface, from the design's
    /// `IconButton/Blurred` and `Sheet`: a fixed dark tint over Liquid Glass.
    /// Shared by the header controls and both sheets, so a sheet reads as the
    /// same material as the button that opened it.
    func tryFavesGlass(in shape: some Shape) -> some View {
        background { shape.fill(TryFavesStyle.glassFill) }
            .glassEffect(.regular, in: shape)
    }
}
