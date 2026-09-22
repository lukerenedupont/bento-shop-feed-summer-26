import ImageIO
import Foundation
import Nuke
import SwiftUI
import UIKit

struct ShopRemoteImageModel: Hashable, Sendable {
    let url: String
    let altText: String?
    let width: Int?
    let height: Int?
    let sensitive: Bool?
    let thumbhash: String?

    init(
        url: String,
        altText: String?,
        width: Int? = nil,
        height: Int? = nil,
        sensitive: Bool? = nil,
        thumbhash: String? = nil
    ) {
        self.url = url
        self.altText = altText
        self.width = width
        self.height = height
        self.sensitive = sensitive
        self.thumbhash = thumbhash
    }

    init(
        url: String,
        altText: String?,
        width: Int?,
        height: Int?,
        thumbhash: String?
    ) {
        self.init(
            url: url,
            altText: altText,
            width: width,
            height: height,
            sensitive: nil,
            thumbhash: thumbhash
        )
    }
}

private struct ShopRemoteImageValidatedURL {
    let source: String
    let url: URL

    init?(_ source: String?) {
        guard let source = source?.nonEmpty,
              let components = URLComponents(string: source),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host?.isEmpty == false,
              let url = components.url else {
            return nil
        }
        self.source = source
        self.url = url
    }
}

extension ShopRemoteImageModel {
    static func isValidRemoteURL(_ urlString: String?) -> Bool {
        ShopRemoteImageValidatedURL(urlString) != nil
    }

    init?(validatingURL urlString: String?, altText: String?) {
        guard let validatedURL = ShopRemoteImageValidatedURL(urlString) else {
            return nil
        }
        self.init(url: validatedURL.source, altText: altText, width: nil, height: nil)
    }
}

extension ShopRemoteImageURLBuilder {
    @MainActor
    static func url(
        for sourceURL: String,
        displayWidth: CGFloat
    ) -> URL? {
        url(
            for: sourceURL,
            displayWidth: displayWidth,
            displayScale: UIScreen.main.scale
        )
    }
}

struct ShopRemoteImagePreparedRequest: Sendable {
    let request: ImageRequest
    let key: String
}

enum ShopRemoteImageRequestBuilder {
    private static let webPAcceptHeader = "image/webp,image/*,*/*;q=0.8"
    private static let webPExcludedExtensions: Set<String> = ["gif", "svg"]

    static func prepare(
        sourceURL: String,
        requestSize: CGSize,
        displayScale: CGFloat,
        contentMode: ImageProcessingOptions.ContentMode
    ) -> ShopRemoteImagePreparedRequest? {
        guard requestSize.width.isFinite,
              requestSize.height.isFinite,
              requestSize.width > 0,
              requestSize.height > 0,
              let optimizedURL = ShopRemoteImageURLBuilder.url(
                  for: sourceURL,
                  displayWidth: requestSize.width,
                  displayScale: displayScale
              ) else {
            return nil
        }

        let urlRequest = urlRequest(for: optimizedURL, sourceURL: sourceURL)
        var request = ImageRequest(urlRequest: urlRequest, priority: .high)
        request.thumbnail = ImageRequest.ThumbnailOptions(
            size: requestSize,
            unit: .points,
            contentMode: contentMode
        )
        let key = "\(optimizedURL.absoluteString)|\(Int(requestSize.width.rounded()))x\(Int(requestSize.height.rounded()))|\(contentMode)"
        return ShopRemoteImagePreparedRequest(request: request, key: key)
    }

    static func urlRequest(for url: URL, sourceURL: String) -> URLRequest {
        var request = URLRequest(url: url)
        if shouldNegotiateWebP(for: sourceURL) {
            request.setValue(webPAcceptHeader, forHTTPHeaderField: "Accept")
        }
        return request
    }

    private static func shouldNegotiateWebP(for sourceURL: String) -> Bool {
        guard let validatedURL = ShopRemoteImageValidatedURL(sourceURL) else {
            return false
        }
        return webPExcludedExtensions.contains(validatedURL.url.pathExtension.lowercased()) == false
    }
}

/// GIF-specific URL handling for `ShopRemoteImage`'s opt-in animated playback.
enum ShopRemoteImageGIF {
    /// Original GIF rendition: strips only `format` query items (the CDN's GIF-to-PNG rewrite)
    /// while preserving every other parameter's percent-encoding.
    static func animatedURL(for sourceURL: String) -> URL? {
        guard var components = URLComponents(string: sourceURL), isGIF(components) else {
            return nil
        }

        components.percentEncodedQueryItems?.removeAll { $0.name.caseInsensitiveCompare("format") == .orderedSame }
        if components.percentEncodedQueryItems?.isEmpty == true {
            components.percentEncodedQueryItems = nil
        }
        return components.url
    }

    private static func isGIF(_ components: URLComponents) -> Bool {
        guard let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host?.isEmpty == false
        else {
            return false
        }
        return components.path.lowercased().hasSuffix(".gif")
    }
}

struct ShopRemoteImage: View {
    static let imageViewIdentifier = "shop-remote-image"

    /// Test hook so layout tests can mount live hierarchies without starting image loads.
    /// A static read instead of an environment key: no per-instance SwiftUI input to diff.
    @MainActor static var remoteImagesEnabled = true

    let image: ShopRemoteImageModel
    let displaySize: CGSize
    var imageRequestSize: CGSize? = nil
    var contentMode: ContentMode = .fill
    var alignment: Alignment = .center
    var animatesImageLoad = true
    /// Opt-in: when the URL is an http(s) `.gif`, additionally fetch the original GIF bytes and
    /// play them in place. Static rendering, sizing, and layout are unchanged; reduce-motion and
    /// non-GIF URLs keep the existing static path.
    var animatesGIFs = false
    var sizing: ShopRemoteImageSizing = .fixed
    var contentPlacement: ShopRemoteImageContentPlacement = .frame
    var onFailure: (() -> Void)? = nil
    var onLoadEnd: (() -> Void)? = nil
    var onImageLoaded: ((CGSize) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animatedGIFURL: URL? {
        guard animatesGIFs, Self.remoteImagesEnabled, reduceMotion == false else {
            return nil
        }
        return ShopRemoteImageGIF.cachedAnimatedURL(for: image.url)
    }

    private var preparedRequest: ShopRemoteImagePreparedRequest? {
        ShopRemoteImageRequestBuilder.preparedRequest(
            sourceURL: image.url,
            requestSize: resolvedImageRequestSize,
            displayScale: UIScreen.main.scale,
            contentMode: nukeContentMode
        )
    }

    private var previewIdentity: ShopRemoteImagePreviewIdentity? {
        ShopRemoteImagePreviewIdentity.cachedIdentity(for: image.url)
    }

    private var resolvedImageRequestSize: CGSize {
        imageRequestSize ?? displaySize
    }

    private var nukeContentMode: ImageProcessingOptions.ContentMode {
        switch contentMode {
        case .fit:
            .aspectFit
        case .fill:
            .aspectFill
        }
    }

    private var imageViewContentMode: UIView.ContentMode {
        switch contentMode {
        case .fit:
            .scaleAspectFit
        case .fill:
            .scaleAspectFill
        }
    }

    var body: some View {
        let preparedRequest = Self.remoteImagesEnabled ? self.preparedRequest : nil

        ShopRemoteUIImageView(
            request: preparedRequest?.request,
            requestKey: preparedRequest?.key,
            previewIdentity: Self.remoteImagesEnabled ? previewIdentity : nil,
            // A box-shaped thumbhash misrepresents natural-width content: stay empty until
            // the image arrives (previous wordmark behavior).
            thumbhash: Self.remoteImagesEnabled && contentPlacement == .frame ? image.thumbhash : nil,
            gifURL: animatedGIFURL,
            displaySize: displaySize,
            contentMode: imageViewContentMode,
            contentPlacement: contentPlacement,
            animatesImageLoad: animatesImageLoad,
            onFailure: onFailure,
            onLoadEnd: onLoadEnd,
            onImageLoaded: onImageLoaded
        )
        .modifier(ShopRemoteImageFrameModifier(
            displaySize: displaySize,
            sizing: sizing,
            alignment: alignment
        ))
        .clipped()
        .accessibilityLabel(image.altText ?? "")
        .accessibilityHidden(image.altText == nil)
    }
}

/// How `displaySize` is turned into a frame.
enum ShopRemoteImageSizing {
    /// `displaySize` is the frame.
    case fixed
    /// `displaySize` is a maximum, so the image can shrink (down-only) into the space its parent
    /// offers while keeping the same request resolution.
    case shrinksToFit
    /// The image adopts the parent's proposal on both axes and `displaySize` is the request hint
    /// only. Use where the parent's size is finite and established elsewhere — this is the
    /// proposal-adopting replacement for a bare `GeometryReader`, and it inherits the reader's
    /// requirement that something above it bound both axes.
    case fillsProposal
}

private struct ShopRemoteImageFrameModifier: ViewModifier {
    let displaySize: CGSize
    let sizing: ShopRemoteImageSizing
    let alignment: Alignment

    @ViewBuilder
    func body(content: Content) -> some View {
        switch sizing {
        case .fixed:
            content.frame(width: displaySize.width, height: displaySize.height, alignment: alignment)
        case .shrinksToFit:
            content.frame(maxWidth: displaySize.width, maxHeight: displaySize.height, alignment: alignment)
        case .fillsProposal:
            content.frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: alignment
            )
        }
    }
}

/// How loaded content is placed inside the frame.
enum ShopRemoteImageContentPlacement {
    /// The image view fills the frame; the UIKit content mode governs scaling.
    case frame
    /// Aspect-fitted to the frame height (width-capped, never cropped), natural width, pinned
    /// to the leading edge. Laid out in UIKit, where the image size is known synchronously.
    case leadingAspectFit
}

final class ShopRemoteImageContainerView: UIView {
    private let notifyingImageView = ShopRemoteImageNotifyingImageView()

    var imageView: UIImageView { notifyingImageView }

    var contentPlacement: ShopRemoteImageContentPlacement = .frame {
        didSet {
            if contentPlacement != oldValue {
                setNeedsLayout()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        notifyingImageView.accessibilityIdentifier = ShopRemoteImage.imageViewIdentifier
        notifyingImageView.backgroundColor = .clear
        notifyingImageView.clipsToBounds = true
        notifyingImageView.onImageChanged = { [weak self] in
            self?.setNeedsLayout()
        }
        addSubview(notifyingImageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        switch contentPlacement {
        case .frame:
            imageView.frame = bounds
        case .leadingAspectFit:
            imageView.frame = Self.leadingAspectFitFrame(
                imageSize: imageView.image?.size,
                bounds: bounds,
                isRightToLeft: effectiveUserInterfaceLayoutDirection == .rightToLeft
            )
        }
    }

    static func leadingAspectFitFrame(
        imageSize: CGSize?,
        bounds: CGRect,
        isRightToLeft: Bool
    ) -> CGRect {
        guard let imageSize,
              imageSize.width > 0,
              imageSize.height > 0,
              bounds.width > 0,
              bounds.height > 0 else {
            return bounds
        }

        let scale = min(bounds.height / imageSize.height, bounds.width / imageSize.width)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: isRightToLeft ? bounds.maxX - fitted.width : bounds.minX,
            y: bounds.minY + (bounds.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }
}

private final class ShopRemoteImageNotifyingImageView: UIImageView {
    var onImageChanged: (() -> Void)?

    override var image: UIImage? {
        didSet {
            onImageChanged?()
        }
    }
}

private struct ShopRemoteUIImageView: UIViewRepresentable {
    let request: ImageRequest?
    let requestKey: String?
    let previewIdentity: ShopRemoteImagePreviewIdentity?
    let thumbhash: String?
    let gifURL: URL?
    let displaySize: CGSize
    let contentMode: UIView.ContentMode
    let contentPlacement: ShopRemoteImageContentPlacement
    let animatesImageLoad: Bool
    let onFailure: (() -> Void)?
    let onLoadEnd: (() -> Void)?
    let onImageLoaded: ((CGSize) -> Void)?

    func makeUIView(context: Context) -> ShopRemoteImageContainerView {
        let container = ShopRemoteImageContainerView()
        container.backgroundColor = .clear
        container.contentPlacement = contentPlacement
        container.imageView.contentMode = contentMode
        container.setContentHuggingPriority(.defaultLow, for: .horizontal)
        container.setContentHuggingPriority(.defaultLow, for: .vertical)
        container.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        container.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return container
    }

    func updateUIView(_ container: ShopRemoteImageContainerView, context: Context) {
        container.contentPlacement = contentPlacement
        context.coordinator.update(
            imageView: container.imageView,
            request: request,
            requestKey: requestKey,
            previewIdentity: previewIdentity,
            thumbhash: thumbhash,
            gifURL: gifURL,
            displaySize: displaySize,
            contentMode: contentMode,
            animatesImageLoad: animatesImageLoad,
            onFailure: onFailure,
            onLoadEnd: onLoadEnd,
            onImageLoaded: onImageLoaded
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleUIView(_ container: ShopRemoteImageContainerView, coordinator: Coordinator) {
        coordinator.lowerPriorityAndDetach()
        container.imageView.image = nil
    }

    @MainActor
    final class Coordinator {
        private enum DisplayedImage {
            case none
            case thumbhash
            case cachedPreview
            case progressive
            case final

            var shouldAnimateReplacement: Bool {
                self == .thumbhash || self == .cachedPreview
            }
        }

        private static let thumbhashDisplayDelay = Duration.milliseconds(80)

        private var imageTask: ImageTask?
        private var thumbhashTask: Task<Void, Never>?
        private var currentRequestKey: String?
        private var currentThumbhashKey: String?
        private var failedRequestKey: String?
        private var displayedImage = DisplayedImage.none
        private var loadEndedRequestKey: String?
        private var imageLoadedRequestKey: String?
        private var gifPlayback: ShopRemoteImageGIFPlayback?
        private var currentGIFURL: URL?

        deinit {
            imageTask?.priority = .veryLow
            thumbhashTask?.cancel()
            gifPlayback?.stop()
        }

        func update(
            imageView: UIImageView,
            request: ImageRequest?,
            requestKey: String?,
            previewIdentity: ShopRemoteImagePreviewIdentity?,
            thumbhash: String?,
            gifURL: URL?,
            displaySize: CGSize,
            contentMode: UIView.ContentMode,
            animatesImageLoad: Bool,
            onFailure: (() -> Void)?,
            onLoadEnd: (() -> Void)?,
            onImageLoaded: ((CGSize) -> Void)?
        ) {
            imageView.contentMode = contentMode
            updateGIFPlayback(imageView: imageView, url: gifURL)

            if requestKey != currentRequestKey {
                imageTask?.cancel()
                imageTask = nil
                thumbhashTask?.cancel()
                thumbhashTask = nil
                currentRequestKey = requestKey
                currentThumbhashKey = nil
                failedRequestKey = nil
                displayedImage = .none
                loadEndedRequestKey = nil
                imageLoadedRequestKey = nil
                imageView.image = nil
            }

            guard let request, let requestKey else {
                failedRequestKey = nil
                displayedImage = .none
                loadEndedRequestKey = nil
                updateThumbhashPlaceholder(
                    imageView: imageView,
                    thumbhash: thumbhash,
                    displaySize: displaySize,
                    contentMode: contentMode
                )
                return
            }

            if displayedImage != .final,
               let cachedImage = ImagePipeline.shared.cache[request] {
                if cachedImage.isPreview == false {
                    failedRequestKey = nil
                    setLoadedImage(cachedImage.image, kind: .final, in: imageView, animated: animatesImageLoad)
                    notifyImageLoaded(onImageLoaded, image: cachedImage.image, requestKey: requestKey)
                    if let previewIdentity {
                        ShopRemoteImagePreviewIndex.shared.register(
                            request: request,
                            identity: previewIdentity
                        )
                    }
                    notifyLoadEnd(onLoadEnd, requestKey: requestKey)
                    return
                }

                if displayedImage == .none || displayedImage == .thumbhash {
                    setLoadedImage(
                        cachedImage.image,
                        kind: .progressive,
                        in: imageView,
                        animated: animatesImageLoad
                    )
                    notifyImageLoaded(onImageLoaded, image: cachedImage.image, requestKey: requestKey)
                }
            }

            if displayedImage == .none || displayedImage == .thumbhash,
               let previewIdentity,
               let previewImage = ShopRemoteImagePreviewIndex.shared.cachedPreview(for: previewIdentity) {
                setLoadedImage(
                    previewImage,
                    kind: .cachedPreview,
                    in: imageView,
                    animated: animatesImageLoad
                )
            }

            if displayedImage == .none {
                updateThumbhashPlaceholder(
                    imageView: imageView,
                    thumbhash: thumbhash,
                    displaySize: displaySize,
                    contentMode: contentMode
                )
            }

            guard imageTask == nil,
                  failedRequestKey != requestKey,
                  displayedImage != .final else {
                return
            }

            imageTask = ImagePipeline.shared.loadImage(
                with: request,
                progress: { [weak self, weak imageView] response, _, _ in
                    guard let self,
                          let imageView,
                          self.currentRequestKey == requestKey,
                          let response else {
                        return
                    }

                    self.setLoadedImage(
                        response.image,
                        kind: .progressive,
                        in: imageView,
                        animated: animatesImageLoad
                    )
                },
                completion: { [weak self, weak imageView] result in
                    if case .success = result, let previewIdentity {
                        ShopRemoteImagePreviewIndex.shared.register(
                            request: request,
                            identity: previewIdentity
                        )
                    }

                    guard let self,
                          let imageView,
                          self.currentRequestKey == requestKey else {
                        return
                    }

                    self.imageTask = nil

                    guard case let .success(response) = result else {
                        self.failedRequestKey = requestKey
                        if self.displayedImage == .none {
                            self.updateThumbhashPlaceholder(
                                imageView: imageView,
                                thumbhash: thumbhash,
                                displaySize: displaySize,
                                contentMode: contentMode
                            )
                        }
                        onFailure?()
                        self.notifyLoadEnd(onLoadEnd, requestKey: requestKey)
                        return
                    }

                    self.failedRequestKey = nil
                    self.setLoadedImage(
                        response.image,
                        kind: .final,
                        in: imageView,
                        animated: animatesImageLoad
                    )
                    self.notifyImageLoaded(onImageLoaded, image: response.image, requestKey: requestKey)
                    self.notifyLoadEnd(onLoadEnd, requestKey: requestKey)
                }
            )
            imageTask?.priority = .high
        }

        func lowerPriorityAndDetach() {
            imageTask?.priority = .veryLow
            imageTask = nil
            thumbhashTask?.cancel()
            thumbhashTask = nil
            currentRequestKey = nil
            currentThumbhashKey = nil
            failedRequestKey = nil
            displayedImage = .none
            loadEndedRequestKey = nil
            imageLoadedRequestKey = nil
            gifPlayback?.stop()
            gifPlayback = nil
            currentGIFURL = nil
        }

        private func updateGIFPlayback(imageView: UIImageView, url: URL?) {
            guard url != currentGIFURL else {
                return
            }
            currentGIFURL = url
            let hadPlayback = gifPlayback != nil
            gifPlayback?.stop()
            gifPlayback = nil

            guard let url else {
                if hadPlayback {
                    // Playback ended mid-display (e.g. Reduce Motion turned on): rebuild the
                    // static rendition instead of freezing on the last GIF frame.
                    currentRequestKey = nil
                    displayedImage = .none
                    imageView.image = nil
                }
                return
            }
            let playback = ShopRemoteImageGIFPlayback(imageView: imageView)
            gifPlayback = playback
            playback.start(url: url)
        }

        private func notifyImageLoaded(
            _ onImageLoaded: ((CGSize) -> Void)?,
            image: UIImage,
            requestKey: String
        ) {
            guard imageLoadedRequestKey != requestKey,
                  image.size.width > 0,
                  image.size.height > 0 else {
                return
            }
            imageLoadedRequestKey = requestKey
            let size = image.size
            Task { @MainActor in
                onImageLoaded?(size)
            }
        }

        private func notifyLoadEnd(_ onLoadEnd: (() -> Void)?, requestKey: String) {
            guard loadEndedRequestKey != requestKey else {
                return
            }
            loadEndedRequestKey = requestKey
            Task { @MainActor in
                onLoadEnd?()
            }
        }

        private func updateThumbhashPlaceholder(
            imageView: UIImageView,
            thumbhash: String?,
            displaySize: CGSize,
            contentMode: UIView.ContentMode
        ) {
            guard displayedImage == .none,
                  let thumbhashKey = ShopThumbhashDecoder.renderedImageCacheKey(
                      from: thumbhash,
                      targetSize: displaySize,
                      contentMode: contentMode,
                      scale: UIScreen.main.scale
                  ) else {
                currentThumbhashKey = nil
                thumbhashTask?.cancel()
                thumbhashTask = nil
                return
            }

            guard thumbhashKey != currentThumbhashKey else {
                return
            }

            currentThumbhashKey = thumbhashKey
            thumbhashTask?.cancel()

            let screenScale = UIScreen.main.scale
            thumbhashTask = Task.detached(priority: .userInitiated) { [weak self, weak imageView] in
                do {
                    try await Task.sleep(for: Self.thumbhashDisplayDelay)
                } catch {
                    return
                }

                guard Task.isCancelled == false else {
                    return
                }

                let renderedImage = ShopThumbhashDecoder.cachedRenderedImage(for: thumbhashKey) ??
                    ShopThumbhashDecoder.renderedImage(
                        from: thumbhash,
                        targetSize: displaySize,
                        contentMode: contentMode,
                        scale: screenScale
                    )

                guard Task.isCancelled == false else {
                    return
                }

                await MainActor.run { [weak self, weak imageView] in
                    guard let self,
                          let imageView,
                          self.currentThumbhashKey == thumbhashKey,
                          self.displayedImage == .none else {
                        return
                    }

                    imageView.image = renderedImage
                    if renderedImage != nil {
                        self.displayedImage = .thumbhash
                    }
                }
            }
        }

        private func setLoadedImage(
            _ image: UIImage,
            kind: DisplayedImage,
            in imageView: UIImageView,
            animated: Bool
        ) {
            thumbhashTask?.cancel()
            thumbhashTask = nil
            currentThumbhashKey = nil

            let shouldAnimate = animated && displayedImage.shouldAnimateReplacement && imageView.image != nil
            displayedImage = kind

            guard shouldAnimate else {
                imageView.image = image
                return
            }

            UIView.transition(
                with: imageView,
                duration: 0.16,
                options: [.transitionCrossDissolve, .allowUserInteraction, .beginFromCurrentState]
            ) {
                imageView.image = image
            }
        }
    }
}

/// Plays an animated GIF into an existing `UIImageView` via ImageIO's built-in animator.
/// The static Nuke rendition stays in place until the first frame arrives and remains on failure.
private final class ShopRemoteImageGIFPlayback: @unchecked Sendable {
    private static let maximumByteCount = 10 * 1_024 * 1_024

    private weak var imageView: UIImageView?
    private let lock = NSLock()
    private var isActive = true
    private var fetchTask: Task<Void, Never>?

    init(imageView: UIImageView) {
        self.imageView = imageView
    }

    func stop() {
        lock.withLock {
            isActive = false
        }
        fetchTask?.cancel()
    }

    func start(url: URL) {
        fetchTask = Task { [weak self] in
            guard let data = await Self.data(for: url),
                  let self,
                  Task.isCancelled == false else {
                return
            }
            self.animate(data: data)
        }
    }

    private func animate(data: Data) {
        _ = CGAnimateImageDataWithBlock(data as CFData, nil) { [weak self] _, frame, stop in
            // ImageIO invokes this block on the main queue.
            guard let self, self.display(frame) else {
                stop.pointee = true
                return
            }
        }
    }

    private func display(_ frame: CGImage) -> Bool {
        lock.withLock {
            guard isActive, let imageView else {
                return false
            }
            imageView.image = UIImage(cgImage: frame)
            return true
        }
    }

    /// Streams the GIF body so the 10 MiB cap aborts oversized transfers instead of buffering
    /// them: a declared `Content-Length` above the cap is rejected before reading, and undeclared
    /// bodies stop as soon as the cap is crossed.
    private static func data(for url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        guard let (bytes, response) = try? await URLSession.shared.bytes(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              httpResponse.expectedContentLength <= maximumByteCount else {
            return nil
        }

        var data = Data()
        if httpResponse.expectedContentLength > 0 {
            data.reserveCapacity(Int(httpResponse.expectedContentLength))
        }
        do {
            for try await byte in bytes {
                data.append(byte)
                if data.count > maximumByteCount {
                    return nil
                }
            }
        } catch {
            return nil
        }
        return data
    }
}
