import Foundation

public enum ShopToastStyle: Equatable, Sendable {
    case info
    case error
}

public enum ShopToastLayout: Equatable, Sendable {
    case standard
    case process
}

public struct ShopToastDuration: Equatable, Sendable {
    public let seconds: TimeInterval

    public init(seconds: TimeInterval) {
        self.seconds = seconds
    }

    // Kept in sync with Android `ShopToastMessage` durations
    // (DefaultDurationMillis / ErrorDurationMillis / CtaDurationMillis).
    public static let short = ShopToastDuration(seconds: 3)
    public static let long = ShopToastDuration(seconds: 4)
    public static let error = ShopToastDuration(seconds: 4)
    // Matches RN CTA_TOAST_DURATION (4s); kept in sync with Android CtaDurationMillis.
    public static let cta = ShopToastDuration(seconds: 4)
    public static let undo = ShopToastDuration(seconds: 2.25)
    // RN `duration: 'persist'` (e.g. the AppBoot No-internet CTA): never auto-dismisses.
    // Kept in sync with Android's persistent duration.
    public static let persistent = ShopToastDuration(seconds: .infinity)

    /// A persistent toast must not be auto-dismissed.
    public var isPersistent: Bool {
        seconds.isFinite == false
    }
}

public struct ShopToastMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let style: ShopToastStyle
    public let ctaTitle: String?
    public let ctaAccessibilityLabel: String?
    public let title: String?
    public let body: String?
    public let leadingIcon: ShopIconName?
    public let leadingImageURL: URL?
    public let leadingImageAltText: String?
    public let isContentActionable: Bool
    public let layout: ShopToastLayout
    public let isLoading: Bool
    public let duration: ShopToastDuration

    public init(
        id: UUID = UUID(),
        text: String,
        style: ShopToastStyle = .info,
        ctaTitle: String? = nil,
        ctaAccessibilityLabel: String? = nil,
        title: String? = nil,
        body: String? = nil,
        leadingIcon: ShopIconName? = nil,
        leadingImageURL: URL? = nil,
        leadingImageAltText: String? = nil,
        isContentActionable: Bool = false,
        layout: ShopToastLayout = .standard,
        isLoading: Bool = false,
        duration: ShopToastDuration = .short
    ) {
        self.id = id
        self.text = text
        self.style = style
        self.ctaTitle = ctaTitle
        self.ctaAccessibilityLabel = ctaAccessibilityLabel
        self.title = title
        self.body = body
        self.leadingIcon = leadingIcon
        self.leadingImageURL = leadingImageURL
        self.leadingImageAltText = leadingImageAltText
        self.isContentActionable = isContentActionable
        self.layout = layout
        self.isLoading = isLoading
        self.duration = duration
    }
}
