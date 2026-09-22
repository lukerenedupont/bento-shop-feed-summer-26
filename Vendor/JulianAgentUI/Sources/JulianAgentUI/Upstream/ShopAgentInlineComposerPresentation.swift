import Gravity
import UIKit

/// Coordinates the PDP scroll and the accessory rows. Composer sizing remains
/// owned by ShopAgentUIKitComposer, with the same bottom anchor throughout growth.
@MainActor
final class ShopAgentInlineComposerPresentation {
    weak var source: UIView?
    weak var accessoryContainer: ShopAgentInlineAccessoryContainer?
    weak var backdrop: ShopComposerFocusBackdropView?
    private weak var scrollView: UIScrollView?
    private weak var host: UIView?
    private var accessoryConstraints: [NSLayoutConstraint] = []
    private var accessoryLeading: NSLayoutConstraint?
    private var accessoryTrailing: NSLayoutConstraint?
    private var accessoryBottom: NSLayoutConstraint?
    private var originalScrollEnabled: Bool?

    func begin(in host: UIView, composer: UIView) {
        guard let source, source.window === host.window, self.host == nil else { return }
        self.host = host
        var ancestor = source.superview
        while let current = ancestor {
            if let scroll = current as? UIScrollView {
                scrollView = scroll
                originalScrollEnabled = scroll.isScrollEnabled
                scroll.isScrollEnabled = false
                break
            }
            ancestor = current.superview
        }
        if let container = accessoryContainer,
           let content = container.contentView, container.window === host.window {
            let frame = content.convert(content.bounds, to: host)
            _ = container.releaseContent()
            host.insertSubview(content, belowSubview: composer)
            let leading = content.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: frame.minX)
            let trailing = content.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: frame.maxX - host.bounds.width)
            let bottom = content.bottomAnchor.constraint(equalTo: composer.topAnchor, constant: -GravitySpacing.space12)
            accessoryLeading = leading
            accessoryTrailing = trailing
            accessoryBottom = bottom
            accessoryConstraints = [leading, trailing, bottom, content.heightAnchor.constraint(equalToConstant: frame.height)]
            NSLayoutConstraint.activate(accessoryConstraints)
        }
        let upperView: UIView
        if let content = accessoryContainer?.contentView, content.superview === host {
            upperView = content
        } else {
            upperView = composer
        }
        if let backdrop {
            // This full-screen layer also belongs to the conversation presentation.
            // Reparent it without resetting its current blur or opacity.
            backdrop.frame = host.bounds
            backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            host.insertSubview(backdrop, belowSubview: upperView)
        }
        host.layoutIfNeeded()
    }

    /// Returns the inline slot's achievable bottom after scrolling. The common
    /// case lands exactly above the final keyboard; clamp only at real bounds.
    func alignedBottom(to targetBottom: CGFloat) -> CGFloat? {
        guard let source, let host, let scrollView else { return nil }
        let sourceBottom = source.convert(source.bounds, to: host).maxY
        let targetOffset = Self.scrollOffset(
            sourceBottom: sourceBottom, targetBottom: targetBottom,
            currentOffset: scrollView.contentOffset.y,
            minimumOffset: -scrollView.adjustedContentInset.top,
            maximumOffset: max(-scrollView.adjustedContentInset.top,
                scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        )
        return sourceBottom - (targetOffset - scrollView.contentOffset.y)
    }

    func scroll(to bottom: CGFloat) {
        guard let source, let host, let scrollView else { return }
        let delta = source.convert(source.bounds, to: host).maxY - bottom
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: scrollView.contentOffset.y + delta), animated: false)
        scrollView.layoutIfNeeded()
    }

    func expand() {
        accessoryLeading?.constant = GravitySpacing.space12
        accessoryTrailing?.constant = -GravitySpacing.space12
        if backdrop?.superview === host { backdrop?.setVisible(true) }
    }

    func prepareReturn() {
        guard let container = accessoryContainer, let host, let source else { return }
        let frame = container.convert(container.bounds, to: host)
        let composerFrame = source.convert(source.bounds, to: host)
        accessoryLeading?.constant = frame.minX
        accessoryTrailing?.constant = frame.maxX - host.bounds.width
        accessoryBottom?.constant = frame.maxY - composerFrame.minY
    }

    func fadeOut() {
        guard host != nil, backdrop?.superview === host else { return }
        backdrop?.setVisible(false)
    }

    func finish(keepingBackdropVisible: Bool = false) {
        NSLayoutConstraint.deactivate(accessoryConstraints)
        accessoryConstraints = []
        accessoryContainer?.returnContentInline()
        // Chat may already have adopted this view. A keyboard dismissal must not
        // remove its backdrop or expose the detail screen during that handoff.
        if !keepingBackdropVisible, host != nil, backdrop?.superview === host {
            backdrop?.setVisible(false)
            backdrop?.removeFromSuperview()
        }
        if let originalScrollEnabled { scrollView?.isScrollEnabled = originalScrollEnabled }
        originalScrollEnabled = nil
        scrollView = nil
        host = nil
    }

    static func scrollOffset(sourceBottom: CGFloat, targetBottom: CGFloat, currentOffset: CGFloat, minimumOffset: CGFloat, maximumOffset: CGFloat) -> CGFloat {
        min(maximumOffset, max(minimumOffset, currentOffset + sourceBottom - targetBottom))
    }
}
