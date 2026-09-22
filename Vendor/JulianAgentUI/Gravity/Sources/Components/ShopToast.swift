import SwiftUI

public struct ShopToast: View {
    private let message: ShopToastMessage
    private let onCTA: (() -> Void)?
    private let onContentAction: (() -> Void)?
    private let onDismiss: (() -> Void)?

    public init(
        message: ShopToastMessage,
        onCTA: (() -> Void)? = nil,
        onContentAction: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.message = message
        self.onCTA = onCTA
        self.onContentAction = onContentAction
        self.onDismiss = onDismiss
    }

    public var body: some View {
        if message.layout == .process {
            processToast
        } else if isRichSnackbar {
            richSnackbar
        } else {
            compactToast
        }
    }

    private var processToast: some View {
        HStack(alignment: .center, spacing: GravitySpacing.space16) {
            if message.isLoading {
                ShopSpinner(size: .medium, accessibilityLabel: nil)
                    .accessibilityHidden(true)
            } else if let leadingImageURL = message.leadingImageURL {
                ProcessToastLeadingImage(url: leadingImageURL)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: GravitySpacing.space0) {
                ShopText(message.title ?? message.text, style: .bodyTitleSmall, color: GravityColor.text)

                if let body = message.body, body.isEmpty == false {
                    ShopText(body, style: .caption, color: GravityColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let ctaTitle = message.ctaTitle, let onCTA {
                ShopButton(
                    ctaTitle,
                    variant: .secondary,
                    size: .medium,
                    isFullWidth: false,
                    action: onCTA
                )
                .accessibilityLabel(SwiftUI.Text(message.ctaAccessibilityLabel ?? ctaTitle))
            }
        }
        .padding(GravitySpacing.space16)
        .background(GravityColor.bgFill)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.radius16, style: .continuous))
        .gravityShadow(.l)
        .accessibilityElement(children: message.ctaTitle == nil ? .combine : .contain)
        .accessibilityLabel(SwiftUI.Text(accessibilityLabel))
    }

    private var compactToast: some View {
        let toast = HStack(alignment: .center, spacing: GravitySpacing.space8) {
            if let leadingImageURL = message.leadingImageURL {
                HStack(alignment: .center, spacing: GravitySpacing.space4) {
                    ToastLeadingImage(url: leadingImageURL, size: GravitySpacing.space40)
                        .accessibilityHidden(true)

                    compactText
                }
            } else if let leadingIcon = message.leadingIcon {
                HStack(alignment: .center, spacing: GravitySpacing.space4) {
                    ShopIcon(leadingIcon, size: .medium, color: foregroundColor)
                        .accessibilityHidden(true)

                    compactText
                }
            } else {
                compactText
                    .padding(.leading, GravitySpacing.space4)
            }

            if let ctaTitle = message.ctaTitle, let onCTA {
                Spacer(minLength: 0)

                SwiftUI.Button(action: onCTA) {
                    ShopText(ctaTitle, style: .buttonMedium, color: foregroundColor)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(SwiftUI.Text(message.ctaAccessibilityLabel ?? ctaTitle))
            }
        }
        .padding(.horizontal, GravitySpacing.space16)
        .padding(.vertical, GravitySpacing.space12)
        .background(backgroundColor)
        .clipShape(Capsule())
        .gravityShadow(.m)
        .contentShape(Rectangle())
        // For CTA toasts keep children individually accessible (`.contain`) so the "View" button
        // stays focusable/activatable by VoiceOver. Only the non-action info/error toasts collapse
        // into a single static-text element.
        .accessibilityElement(children: message.ctaTitle == nil ? .combine : .contain)
        .accessibilityLabel(SwiftUI.Text(accessibilityLabel))
        .accessibilityAddTraits(message.ctaTitle == nil ? .isStaticText : [])

        // Tap-to-dismiss for non-CTA (info/error) toasts. CTA toasts intentionally have no
        // tap-to-dismiss so the body tap can't pre-empt the "View" action.
        if message.ctaTitle == nil, let onDismiss {
            return AnyView(toast.onTapGesture(perform: onDismiss))
        } else {
            return AnyView(toast)
        }
    }

    private var compactText: some View {
        ShopText(message.text, style: .caption, color: foregroundColor)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var richSnackbar: some View {
        HStack(alignment: .center, spacing: GravitySpacing.space8) {
            richSnackbarContent

            if let ctaTitle = message.ctaTitle, let onCTA {
                ShopButton(
                    ctaTitle,
                    variant: .secondary,
                    size: .small,
                    isFullWidth: false,
                    action: onCTA
                )
                .accessibilityLabel(SwiftUI.Text(message.ctaAccessibilityLabel ?? ctaTitle))
            }
        }
        .padding(GravitySpacing.space12)
        .background(GravityColor.bgFill)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.radius16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.radius16, style: .continuous)
                .stroke(GravityColor.borderImage, lineWidth: 0.5)
        )
        .shadow(color: GravityColor.shadow300, radius: 30, x: 0, y: 12)
        .accessibilityElement(children: message.ctaTitle == nil ? .combine : .contain)
        .accessibilityLabel(SwiftUI.Text(accessibilityLabel))
    }

    @ViewBuilder
    private var richSnackbarContent: some View {
        let content = HStack(alignment: .center, spacing: GravitySpacing.space8) {
            if let leadingImageURL = message.leadingImageURL {
                ToastLeadingImage(url: leadingImageURL, size: GravitySpacing.space32)
                    .accessibilityHidden(true)
            } else if let leadingIcon = message.leadingIcon {
                ShopIcon(leadingIcon, size: .medium, color: GravityColor.text)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                ShopText(message.title ?? message.text, style: .bodyTitleSmall, color: GravityColor.text)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let body = message.body, body.isEmpty == false {
                    ShopText(body, style: .caption, color: GravityColor.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        if message.isContentActionable, let onContentAction {
            SwiftUI.Button(action: onContentAction) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var isRichSnackbar: Bool {
        message.title != nil || message.body != nil
    }

    private var accessibilityLabel: String {
        if isRichSnackbar {
            return [
                message.title ?? message.text,
                message.body,
                message.leadingImageAltText,
                message.ctaAccessibilityLabel ?? message.ctaTitle,
            ]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: ", ")
        }

        if let ctaTitle = message.ctaTitle {
            return "\(message.text), \(ctaTitle)"
        }

        return message.text
    }

    private var backgroundColor: Color {
        switch message.style {
        case .info:
            GravityColor.bgFillFixedDark
        case .error:
            GravityColor.bgFillCritical
        }
    }

    private var foregroundColor: Color {
        switch message.style {
        case .info:
            GravityColor.textFixedLight
        case .error:
            GravityColor.textFixedLight
        }
    }
}

private struct ToastLeadingImage: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                GravityColor.bgFillPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.radius8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GravityRadius.radius8, style: .continuous)
                .stroke(GravityColor.borderImage, lineWidth: 1)
        }
    }
}

private struct ProcessToastLeadingImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFit()
            default:
                GravityColor.bgFillPlaceholder
            }
        }
        .frame(width: GravitySpacing.space36, height: GravitySpacing.space36)
    }
}

#Preview("ShopToast") {
    VStack(spacing: GravitySpacing.space16) {
        ShopToast(message: ShopToastMessage(text: "Changes saved", leadingIcon: .checkmarkCircle))
        ShopToast(
            message: ShopToastMessage(
                text: "Package is already being tracked\nBlue sneakers",
                ctaTitle: "View",
                ctaAccessibilityLabel: "View package",
                leadingImageURL: URL(string: "https://cdn.shopify.com/example.png")
            ),
            onCTA: {}
        )
        ShopToast(message: ShopToastMessage(text: "Something went wrong", style: .error))
    }
    .padding()
    .background(GravityColor.bg)
}
