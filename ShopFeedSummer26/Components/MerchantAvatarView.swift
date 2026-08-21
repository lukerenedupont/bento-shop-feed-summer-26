import SwiftUI

/// Reusable merchant avatar: displays logo image in a circle, or a colored circle with the
/// merchant's initial as a fallback. Configurable size, shape, and border style.
struct MerchantAvatarView: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    private let logoURL: URL?
    private let fallbackName: String
    private let fallbackColor: Color
    var size: CGFloat = 32
    var shape: AvatarShape = .circle
    var borderColor: Color = GravityColors.borderImage
    var borderWidth: CGFloat = 0.5

    enum AvatarShape {
        case circle
        case roundedRect(cornerRadius: CGFloat)
    }

    /// Initialize with a SampleMerchant (existing usage).
    init(merchant: SampleMerchant, size: CGFloat = 32, shape: AvatarShape = .circle, borderColor: Color = GravityColors.borderImage, borderWidth: CGFloat = 0.5) {
        self.logoURL = merchant.bestLogoURL.flatMap { URL(string: $0) }
        self.fallbackName = merchant.name
        self.fallbackColor = merchant.primaryColor
        self.size = size
        self.shape = shape
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }

    /// Initialize with a logo URL and name directly (for typeahead, etc.).
    init(logoURL: URL?, name: String, size: CGFloat = 32, shape: AvatarShape = .circle, fallbackColor: Color = GravityColors.bgFillSecondary) {
        self.logoURL = logoURL
        self.fallbackName = name
        self.fallbackColor = fallbackColor
        self.size = size
        self.shape = shape
        self.borderColor = GravityColors.borderImage
        self.borderWidth = 0.5
    }

    var body: some View {
        Group {
            if let url = logoURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        initialFallback
                    default:
                        Circle().fill(fallbackColor.opacity(PurlTune.value("Components/MerchantAvatarView.swift:opacity:_:51:61", default: 0.3)))
                    }
                }
            } else {
                initialFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(avatarClipShape)
        .overlay(avatarClipShape.strokeBorder(borderColor, lineWidth: borderWidth))
    }

    private var initialFallback: some View {
        Circle()
            .fill(fallbackColor)
            .overlay(
                Text(String(fallbackName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(PurlTune.token("Components/MerchantAvatarView.swift:foregroundStyle:_:69:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
            )
    }

    private var avatarClipShape: some InsettableShape {
        switch shape {
        case .circle:
            AnyInsettableShape(Circle())
        case .roundedRect(let cr):
            AnyInsettableShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        }
    }
}

/// Type-erased InsettableShape so we can switch between Circle and RoundedRectangle.
private struct AnyInsettableShape: InsettableShape {
    private let _path: @Sendable (CGRect) -> Path
    private let _inset: @Sendable (CGFloat) -> AnyInsettableShape

    init<S: InsettableShape & Sendable>(_ shape: S) {
        _path = { shape.path(in: $0) }
        _inset = { AnyInsettableShape(shape.inset(by: $0)) }
    }

    func path(in rect: CGRect) -> Path { _path(rect) }
    func inset(by amount: CGFloat) -> AnyInsettableShape { _inset(amount) }
}

// MARK: - Previews

#Preview("Merchant Avatars") {
    let merchants = Array(SampleMerchant.all.prefix(6))
    VStack(spacing: 20) {
        // Circle avatars at various sizes
        HStack(spacing: 16) {
            ForEach(merchants.prefix(4)) { merchant in
                VStack(spacing: 4) {
                    MerchantAvatarView(merchant: merchant, size: 48)
                    Text(merchant.name)
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(PurlTune.token("Components/MerchantAvatarView.swift:foregroundStyle:_:109:42", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                        .lineLimit(1)
                }
            }
        }

        // Rounded rect variant
        HStack(spacing: 16) {
            ForEach(merchants.prefix(4)) { merchant in
                MerchantAvatarView(
                    merchant: merchant,
                    size: 56,
                    shape: .roundedRect(cornerRadius: GravityRadius.r12)
                )
            }
        }

        // Size comparison
        HStack(spacing: 12) {
            MerchantAvatarView(merchant: merchants[0], size: 24)
            MerchantAvatarView(merchant: merchants[0], size: 32)
            MerchantAvatarView(merchant: merchants[0], size: 48)
            MerchantAvatarView(merchant: merchants[0], size: 64)
        }
    }
    .padding()
    .background(PurlTune.token("Components/MerchantAvatarView.swift:background:_:135:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
