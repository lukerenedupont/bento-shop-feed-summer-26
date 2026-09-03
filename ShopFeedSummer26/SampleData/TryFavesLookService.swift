import CryptoKit
import Foundation
import SwiftUI
import UIKit

/// Generates, caches, and persists "Try your faves" looks.
///
/// Rendering runs through fal's queue API against `fal-ai/fashn/tryon/v1.6`.
/// The fal API key never ships in the app: every HTTP call is authorized with
/// a short-lived JWT minted by the same server-side token endpoint the live
/// Decart studio uses (`FAL_TOKEN_ENDPOINT` / Shopify proxy fallback). fal's
/// queue supports webhooks, but a client-only prototype has no callback URL,
/// so completion is observed by polling the queue's status endpoint instead.
@MainActor
@Observable
final class TryFavesLookService {
    static let shared = TryFavesLookService()

    static let modelVersion = "fal-ai/fashn/tryon/v1.6"
    /// Posture and footwear edits run through Nano Banana Pro — markedly
    /// better photographic realism and product fidelity than the base model,
    /// which was drifting renders toward a synthetic look.
    static let editModel = "fal-ai/nano-banana-pro/edit"
    /// Generation settings, frozen into the cache key: FASHN quality mode,
    /// one sample, PNG output, the editorial seed framing, the posture pass,
    /// and the pro edit passes.
    static let generationSettings = "quality|samples=1|png|frame-v3|pose-v1|edits-nbp1"

    /// Ten subtle stances, cycled per generation so consecutive looks don't
    /// share an identical pose. The index is stored on the look (stable
    /// through retries) and folded into the render cache key.
    static let posturePrompts = [
        "weight shifted onto his left leg, right knee relaxed",
        "arms relaxed at his sides, shoulders loose",
        "left hand in his pocket, right arm hanging naturally",
        "arms loosely crossed over his chest",
        "a slight three-quarter turn to his left, face toward the camera",
        "one small step forward with his right foot",
        "hands clasped loosely in front of him",
        "gaze turned slightly off camera to his right",
        "weight on his right leg, left foot pointed slightly outward",
        "hands held behind his back, chest open",
    ]

    enum LookState: Codable, Hashable {
        case generating
        case ready
        case failed(String)

        var isFailed: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    struct Look: Identifiable, Codable, Hashable {
        let id: UUID
        var title: String
        /// Ordered variant IDs, generation order (bottoms before top).
        let variantIDs: [String]
        let cacheKey: String
        let createdAt: Date
        var state: LookState
        var attemptCount: Int
        /// Index into `posturePrompts`; 0 for looks predating posture cycling.
        var postureIndex: Int = 0
    }

    enum JobPhase: Equatable {
        case queued
        case posing
        case applyingBottoms
        case applyingTop
        case applyingShoes
        case validating

        var label: String {
            switch self {
            case .queued: "Queued"
            case .posing: "Setting the pose"
            case .applyingBottoms: "Styling bottoms"
            case .applyingTop: "Styling the top"
            case .applyingShoes: "Styling shoes"
            case .validating: "Checking the result"
            }
        }
    }

    struct Job: Equatable {
        let lookID: UUID
        var phase: JobPhase
        var attempt: Int
    }

    /// The outfit the seed avatar is photographed in, presented as the first,
    /// pre-generated look. It is not persisted, cannot be deleted or retried,
    /// and its render is the bundled seed photograph.
    static let seedLookID = UUID(uuidString: "00000000-0000-0000-0000-00000000FA7E")!

    let seedLook = Look(
        id: TryFavesLookService.seedLookID,
        title: "Look 1",
        variantIDs: TryFavesCatalog.seedLookVariantIDs,
        cacheKey: "seed-look",
        createdAt: .distantPast,
        state: .ready,
        attemptCount: 0
    )

    private(set) var looks: [Look] = []
    private(set) var activeJob: Job?
    /// A finished look the shopper hasn't opened yet — drives the
    /// "View new look" chip and its badge.
    private(set) var unseenLookID: UUID?

    /// Only `figureImages` is observed — pages re-render when a lifted figure
    /// lands. The bookkeeping caches are observation-ignored so incidental
    /// reads/mutations can never re-enter SwiftUI's update transaction.
    private var figureImages: [String: UIImage] = [:]
    @ObservationIgnored private var renderImages: [String: UIImage] = [:]
    @ObservationIgnored private var figureExtractionsInFlight: Set<String> = []
    @ObservationIgnored private var figureExtractionFailures: Set<String> = []
    @ObservationIgnored private var generationTask: Task<Void, Never>?

    private init() {
        looks = Self.loadLooks()
        // A relaunch mid-generation leaves orphaned `.generating` looks with
        // no task attached. Surface them as retryable instead of spinning.
        for index in looks.indices where looks[index].state == .generating {
            looks[index].state = .failed("Generation was interrupted.")
        }
    }

    // MARK: - Public API

    func resolvedGarments(for look: Look) -> [TryOnGarment] {
        // Present garments top, bottoms, shoes regardless of generation order.
        look.variantIDs
            .compactMap(TryFavesCatalog.garment(for:))
            .sorted { $0.category.displayRank < $1.category.displayRank }
    }

    /// Submit a new look. Returns the look's ID immediately; generation
    /// continues in the background and publishes through `activeJob` / `looks`.
    @discardableResult
    func generate(outfit: TryFavesOutfit) -> UUID? {
        guard activeJob == nil else { return nil }

        // Cycle stances so consecutive generations aren't identical.
        let postureIndex = looks.count % Self.posturePrompts.count
        let cacheKey = Self.cacheKey(for: outfit, postureIndex: postureIndex)
        let look = Look(
            id: UUID(),
            // The seed photograph is Look 1, so generated looks start at 2.
            title: "Look \(looks.count + 2)",
            variantIDs: outfit.orderedVariantIDs,
            cacheKey: cacheKey,
            createdAt: Date(),
            state: .generating,
            attemptCount: 0,
            postureIndex: postureIndex
        )
        looks.append(look)
        persistLooks()

        // Cache hit: the identical avatar + variants + posture + settings was
        // rendered before. Reuse it without touching the network.
        if let cached = loadCachedRender(for: cacheKey) {
            renderImages[cacheKey] = cached
            finish(lookID: look.id, state: .ready)
            return look.id
        }

        startGeneration(lookID: look.id, outfit: outfit, postureIndex: postureIndex)
        return look.id
    }

    func retry(_ lookID: UUID) {
        guard activeJob == nil,
              let look = looks.first(where: { $0.id == lookID }),
              look.state.isFailed else { return }
        let garments = look.variantIDs.compactMap(TryFavesCatalog.garment(for:))
        guard let outfit = Self.outfit(from: garments) else { return }
        update(lookID: lookID) { $0.state = .generating }
        startGeneration(lookID: lookID, outfit: outfit, postureIndex: look.postureIndex)
    }

    func delete(_ lookID: UUID) {
        guard lookID != Self.seedLookID, activeJob?.lookID != lookID else { return }
        looks.removeAll { $0.id == lookID }
        if unseenLookID == lookID { unseenLookID = nil }
        persistLooks()
    }

    func markSeen(_ lookID: UUID) {
        if unseenLookID == lookID { unseenLookID = nil }
    }

    func renderImage(for look: Look) -> UIImage? {
        if look.id == Self.seedLookID {
            return UIImage(named: Self.seedAvatarAssetName)
        }
        // renderImages is observation-ignored, so this lazy disk restore is
        // safe even when first touched during a view pass.
        if let image = renderImages[look.cacheKey] { return image }
        guard let image = loadCachedRender(for: look.cacheKey) else { return nil }
        renderImages[look.cacheKey] = image
        return image
    }

    // MARK: - Figure extraction

    /// The look's figure lifted off its photographed backdrop. Pure read —
    /// safe to call from view bodies. Returns nil until `ensureFigure(for:)`
    /// has produced one; callers fall back to the full render.
    func figureImage(for look: Look) -> UIImage? {
        figureImages[look.cacheKey]
    }

    /// Kick off (or restore) figure extraction for a look. Must be called
    /// from an async context such as `.task` — never during a view body —
    /// because it publishes observable state.
    ///
    /// On-device Vision segmentation is unavailable in the simulator ("could
    /// not create inference context"), so lifting runs through BiRefNet on
    /// fal via the same gateway, then persists beside the render cache. The
    /// seed figure ships in the bundle and costs nothing.
    func ensureFigure(for look: Look) {
        let cacheKey = look.cacheKey
        guard figureImages[cacheKey] == nil,
              !figureExtractionsInFlight.contains(cacheKey),
              !figureExtractionFailures.contains(cacheKey) else {
            return
        }
        if look.id == Self.seedLookID {
            if let bundled = UIImage(named: "try-faves-figure") {
                figureImages[cacheKey] = bundled
            }
            return
        }
        if let disk = loadCachedFigure(for: cacheKey) {
            figureImages[cacheKey] = disk
            return
        }
        guard look.state == .ready,
              let render = renderImage(for: look),
              let jpeg = render.jpegData(compressionQuality: 0.85) else {
            return
        }
        startFigureExtraction(
            cacheKey: cacheKey,
            imageReference: "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        )
    }

    /// Background removal through the gateway. `imageReference` is either the
    /// render's hosted URL (fresh generations) or a data URI (restored looks).
    /// Failure is memoized — the look keeps showing its full render.
    private func startFigureExtraction(cacheKey: String, imageReference: String) {
        guard figureImages[cacheKey] == nil,
              !figureExtractionsInFlight.contains(cacheKey),
              !figureExtractionFailures.contains(cacheKey) else {
            return
        }
        figureExtractionsInFlight.insert(cacheKey)
        Task.detached(priority: .userInitiated) {
            let data = try? await FashnQueueClient().removeBackground(imageURL: imageReference)
            await MainActor.run {
                let service = TryFavesLookService.shared
                service.figureExtractionsInFlight.remove(cacheKey)
                if let data, let figure = UIImage(data: data) {
                    service.figureImages[cacheKey] = figure
                    service.storeCachedFigure(figure, for: cacheKey)
                } else {
                    service.figureExtractionFailures.insert(cacheKey)
                }
            }
        }
    }

    // MARK: - Generation pipeline

    private func startGeneration(lookID: UUID, outfit: TryFavesOutfit, postureIndex: Int) {
        let attempt = (looks.first { $0.id == lookID }?.attemptCount ?? 0) + 1
        update(lookID: lookID) { $0.attemptCount = attempt }
        activeJob = Job(lookID: lookID, phase: .queued, attempt: attempt)

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.render(outfit: outfit, lookID: lookID, postureIndex: postureIndex)
                let cacheKey = Self.cacheKey(for: outfit, postureIndex: postureIndex)
                self.storeCachedRender(result.image, for: cacheKey)
                self.renderImages[cacheKey] = result.image
                self.finish(lookID: lookID, state: .ready)
                // Lift the figure eagerly from the hosted render so the page
                // composites over the fixed plate as soon as possible.
                self.startFigureExtraction(cacheKey: cacheKey, imageReference: result.hostedURL)
            } catch is CancellationError {
                self.finish(lookID: lookID, state: .failed("Generation was cancelled."))
            } catch let error as TryFavesRenderError {
                self.finish(lookID: lookID, state: .failed(error.shopperMessage))
            } catch {
                self.finish(lookID: lookID, state: .failed("The look couldn't be generated."))
            }
        }
    }

    private func render(
        outfit: TryFavesOutfit,
        lookID: UUID,
        postureIndex: Int
    ) async throws -> (image: UIImage, hostedURL: String) {
        let client = FashnQueueClient()
        let avatar = try Self.seedAvatarDataURI()

        func pass(
            model: String,
            garment: TryOnGarment,
            phase: JobPhase
        ) async throws -> (image: UIImage, hostedURL: String) {
            activeJob?.phase = phase
            // One automatic retry per pass covers transient queue failures and
            // bad frames; anything after that becomes a user-visible retry.
            var lastError: Error = TryFavesRenderError.generationFailed
            for _ in 0..<2 {
                do {
                    let output = garment.category == .footwear
                        ? try await client.editShoes(modelImage: model, garment: garment)
                        : try await client.generate(modelImage: model, garment: garment)
                    activeJob?.phase = .validating
                    let image = try Self.validated(output.imageData)
                    return (image, output.hostedURL)
                } catch {
                    lastError = error
                    try Task.checkCancellation()
                }
            }
            throw lastError
        }

        // Re-pose the seed first so each look carries its own stance; every
        // garment pass then composites onto the posed base.
        activeJob?.phase = .posing
        let posture = Self.posturePrompts[postureIndex % Self.posturePrompts.count]
        let posedBase: String
        do {
            let posed = try await client.pose(modelImage: avatar, posture: posture)
            _ = try Self.validated(posed.imageData)
            posedBase = posed.hostedURL
        } catch {
            // A failed pose pass shouldn't sink the look — fall back to the
            // seed's photographed stance.
            posedBase = avatar
        }

        switch outfit {
        case let .shoesOnly(shoes):
            // The seed avatar is already dressed, so shoes alone are a single
            // edit pass.
            let result = try await pass(model: posedBase, garment: shoes, phase: .applyingShoes)
            return (result.image, result.hostedURL)

        case let .separates(top, bottom, shoes):
            // Bottoms first, then the top applied to the intermediate result,
            // then shoes edited onto the composed look. Intermediates stay on
            // fal's CDN, so chained passes send URLs instead of pixels.
            let bottomsPass = try await pass(model: posedBase, garment: bottom, phase: .applyingBottoms)
            let topPass = try await pass(model: bottomsPass.hostedURL, garment: top, phase: .applyingTop)
            guard let shoes else { return (topPass.image, topPass.hostedURL) }
            let shoesPass = try await pass(model: topPass.hostedURL, garment: shoes, phase: .applyingShoes)
            return (shoesPass.image, shoesPass.hostedURL)
        }
    }

    private func finish(lookID: UUID, state: LookState) {
        update(lookID: lookID) { $0.state = state }
        if state == .ready { unseenLookID = lookID }
        activeJob = nil
        generationTask = nil
        persistLooks()
    }

    private func update(lookID: UUID, _ transform: (inout Look) -> Void) {
        guard let index = looks.firstIndex(where: { $0.id == lookID }) else { return }
        transform(&looks[index])
    }

    private static func outfit(from garments: [TryOnGarment]) -> TryFavesOutfit? {
        let shoes = garments.first { $0.category == .footwear }
        if let top = garments.first(where: { $0.category == .tops }),
           let bottom = garments.first(where: { $0.category == .bottoms }) {
            return .separates(top: top, bottom: bottom, shoes: shoes)
        }
        if let shoes, garments.count == 1 {
            return .shoesOnly(shoes)
        }
        return nil
    }

    // MARK: - Output validation

    /// Lightweight guard against missing, blank, corrupted, or badly framed
    /// renders before a look is declared ready.
    private static func validated(_ data: Data) throws -> UIImage {
        guard !data.isEmpty, let image = UIImage(data: data) else {
            throw TryFavesRenderError.invalidOutput
        }
        let size = image.size
        guard size.width >= 256, size.height >= 256 else {
            throw TryFavesRenderError.invalidOutput
        }
        // FASHN preserves the model image's aspect ratio, and the seed
        // avatar is a tall trimmed cutout (~0.27), so accept anything from a
        // slim full-body strip to a squarish studio frame. Only degenerate
        // shapes indicate a badly framed subject.
        let aspect = size.width / size.height
        guard aspect > 0.15, aspect < 1.4 else {
            throw TryFavesRenderError.invalidOutput
        }
        guard !isEffectivelyBlank(image) else {
            throw TryFavesRenderError.invalidOutput
        }
        return image
    }

    /// Samples a coarse grid of pixels; a near-zero luminance spread means an
    /// empty or single-color frame.
    private static func isEffectivelyBlank(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return true }
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return true }
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var minLuma = 255.0
        var maxLuma = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let luma = 0.299 * Double(pixels[index])
                + 0.587 * Double(pixels[index + 1])
                + 0.114 * Double(pixels[index + 2])
            minLuma = min(minLuma, luma)
            maxLuma = max(maxLuma, luma)
        }
        return (maxLuma - minLuma) < 8
    }

    // MARK: - Seed avatar

    static let seedAvatarAssetName = "try-faves-avatar"

    /// SHA-256 of the bundled avatar asset. Part of every cache key so a new
    /// seed avatar invalidates old renders.
    private static let seedAvatarHash: String = {
        guard let data = seedAvatarData() else { return "no-avatar" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }()

    private static func seedAvatarData() -> Data? {
        guard let image = UIImage(named: seedAvatarAssetName) else { return nil }
        return image.pngData()
    }

    /// The avatar as a compact JPEG data URI for the first FASHN pass. fal
    /// accepts data URIs directly, which keeps the seed image out of any
    /// third-party storage.
    ///
    /// The seed is a full editorial studio photograph and is sent exactly as
    /// bundled: FASHN mirrors the model image's framing, so every render
    /// inherits the seed's zoom, backdrop, and light — which is what lets the
    /// looks run full-bleed in the interface.
    private static func seedAvatarDataURI() throws -> String {
        guard let seed = UIImage(named: seedAvatarAssetName),
              let jpeg = seed.jpegData(compressionQuality: 0.85) else {
            throw TryFavesRenderError.missingAvatar
        }
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }

    // MARK: - Render cache

    /// Renders are keyed on avatar hash + ordered variant IDs + posture +
    /// model version + generation settings.
    static func cacheKey(for outfit: TryFavesOutfit, postureIndex: Int = 0) -> String {
        let material = [
            seedAvatarHash,
            outfit.orderedVariantIDs.joined(separator: "+"),
            "pose-\(postureIndex)",
            modelVersion,
            generationSettings,
        ].joined(separator: "|")
        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("TryFavesRenders", isDirectory: true)
    }

    private func loadCachedRender(for cacheKey: String) -> UIImage? {
        let url = Self.cacheDirectory.appendingPathComponent("\(cacheKey).png")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func storeCachedRender(_ image: UIImage, for cacheKey: String) {
        guard let data = image.pngData() else { return }
        try? FileManager.default.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.cacheDirectory.appendingPathComponent("\(cacheKey).png"))
    }

    private func loadCachedFigure(for cacheKey: String) -> UIImage? {
        let url = Self.cacheDirectory.appendingPathComponent("\(cacheKey)-figure.png")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func storeCachedFigure(_ image: UIImage, for cacheKey: String) {
        guard let data = image.pngData() else { return }
        try? FileManager.default.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.cacheDirectory.appendingPathComponent("\(cacheKey)-figure.png"))
    }

    // MARK: - Look persistence

    private static var looksFileURL: URL {
        cacheDirectory.appendingPathComponent("looks.json")
    }

    private func persistLooks() {
        try? FileManager.default.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(looks) else { return }
        try? data.write(to: Self.looksFileURL)
    }

    private static func loadLooks() -> [Look] {
        guard let data = try? Data(contentsOf: looksFileURL),
              let looks = try? JSONDecoder().decode([Look].self, from: data) else {
            return []
        }
        return looks
    }
}

enum TryFavesRenderError: Error {
    case missingAvatar
    case missingConfiguration
    case requestFailed
    case generationFailed
    case timedOut
    case invalidOutput

    var shopperMessage: String {
        switch self {
        case .missingAvatar:
            "The avatar image is missing from this build."
        case .missingConfiguration:
            "Add SHOPIFY_PROXY_KEY (from proxy.shopify.io) to .env.local to enable look generation."
        case .requestFailed, .generationFailed:
            "The look couldn't be generated."
        case .timedOut:
            "Generation took too long."
        case .invalidOutput:
            "The render came back unusable."
        }
    }
}

/// Minimal client for fal's queue API. Submits a FASHN try-on job, polls its
/// status, and downloads the finished PNG.
///
/// Preferred route is the Shopify LLM gateway: set `SHOPIFY_PROXY_KEY` in
/// `.env.local` with a token from https://proxy.shopify.io and every queue
/// call goes through `proxy.shopify.ai/vendors/fal-queue-run` with a static
/// Bearer key — no fal credential ever touches the app. Without a gateway
/// key it falls back to fal's queue directly, minting a short-lived JWT per
/// call from `FAL_TOKEN_ENDPOINT`.
private struct FashnQueueClient {
    struct Output {
        let imageData: Data
        /// The render hosted on fal's CDN — reused as the `model_image` for a
        /// chained pass without re-uploading pixels.
        let hostedURL: String
    }

    private enum Route {
        case shopifyGateway(key: String)
        case falDirect
    }

    private struct SubmittedJob {
        let statusURL: URL
        let responseURL: URL
    }

    private static let gatewayQueueBase = "https://proxy.shopify.ai/vendors/fal-queue-run"
    private static let falQueueBase = "https://queue.fal.run"
    /// Poll cadence and budget. The product target is P95 under 90 seconds
    /// per look; a single pass gets 100s before it is declared timed out.
    private static let pollInterval: Duration = .seconds(2)
    private static let pollBudget: TimeInterval = 100

    private let route: Route

    init() {
        let values = FalTokenProvider.configurationValues()
        if let key = values["SHOPIFY_PROXY_KEY"], !key.isEmpty {
            route = .shopifyGateway(key: key)
        } else {
            route = .falDirect
        }
    }

    private var queueBase: String {
        switch route {
        case .shopifyGateway: Self.gatewayQueueBase
        case .falDirect: Self.falQueueBase
        }
    }

    /// fal's queue answers with absolute `queue.fal.run` URLs. In gateway
    /// mode they are rewritten onto the proxy so the same key authorizes
    /// every hop; any URL that cannot be routed is rejected rather than
    /// called with credentials attached.
    private func routed(_ raw: String) throws -> URL {
        if case .falDirect = route {
            guard let url = URL(string: raw) else { throw TryFavesRenderError.requestFailed }
            return url
        }
        if raw.hasPrefix(Self.gatewayQueueBase), let url = URL(string: raw) {
            return url
        }
        let falDomains = [
            "https://queue.fal.run/",
            "https://fal.run/",
            "https://gateway.fal.run/",
            "https://rest.fal.run/",
        ]
        for domain in falDomains where raw.hasPrefix(domain) {
            let rewritten = raw.replacingOccurrences(of: domain, with: "\(Self.gatewayQueueBase)/")
            if let url = URL(string: rewritten) { return url }
        }
        throw TryFavesRenderError.requestFailed
    }

    /// A FASHN try-on pass: quality mode, explicit category and photo type,
    /// one sample, PNG output. `webhookUrl` is intentionally absent: no
    /// server to call back — completion is polled instead.
    func generate(modelImage: String, garment: TryOnGarment) async throws -> Output {
        try await run(
            modelPath: TryFavesLookService.modelVersion,
            payload: [
                "model_image": modelImage,
                "garment_image": garment.imageURL,
                "category": garment.category.rawValue,
                "garment_photo_type": garment.photoType.rawValue,
                "mode": "quality",
                "num_samples": 1,
                "output_format": "png",
            ]
        )
    }

    /// A posture pass: re-stance the seed subtly before dressing, so every
    /// generation carries its own pose.
    func pose(modelImage: String, posture: String) async throws -> Output {
        try await run(
            modelPath: TryFavesLookService.editModel,
            payload: [
                "prompt": "Adjust the person's pose subtly: \(posture). Keep the "
                    + "exact same person, face, hair, clothing, camera framing and "
                    + "zoom, and the same warm plaster studio backdrop with its "
                    + "soft natural light and floor shadow. Photorealistic "
                    + "editorial photograph, natural skin texture, no retouching.",
                "image_urls": [modelImage],
                "num_images": 1,
                "output_format": "png",
                "aspect_ratio": "9:16",
            ]
        )
    }

    /// Person cutout via BiRefNet — returns a full-frame PNG with alpha so
    /// the figure keeps its photographed position over the fixed plate.
    func removeBackground(imageURL: String) async throws -> Data {
        let output = try await run(
            modelPath: "fal-ai/birefnet/v2",
            payload: [
                "image_url": imageURL,
                "operating_resolution": "2048x2048",
            ]
        )
        return output.imageData
    }

    /// A footwear pass: FASHN has no shoe category, so shoes are swapped by
    /// an instruction-driven edit over the composed look.
    func editShoes(modelImage: String, garment: TryOnGarment) async throws -> Output {
        try await run(
            modelPath: TryFavesLookService.editModel,
            payload: [
                "prompt": "Replace only the footwear the person is wearing with the "
                    + "exact shoes from the second image — reproduce their precise "
                    + "design, shape, colors, materials, sole, stitching, and laces "
                    + "faithfully, adjusted to the person's viewing angle. Keep the "
                    + "person's pose, body, clothing, the camera framing and zoom, "
                    + "and the warm plaster studio backdrop exactly the same. Show "
                    + "the full body head to toe on the same floor with the same "
                    + "soft shadow. Photorealistic, natural skin and fabric texture.",
                "image_urls": [modelImage, garment.imageURL],
                "num_images": 1,
                "output_format": "png",
                // Pin the output frame to the seed's tall aspect — left on
                // auto, the edit re-crops and the lifted figure lands at a
                // different scale than the fixed studio plate.
                "aspect_ratio": "9:16",
            ]
        )
    }

    private func run(modelPath: String, payload: [String: Any]) async throws -> Output {
        let job = try await submit(modelPath: modelPath, payload: payload)
        let resultURL = try await waitForCompletion(job: job)
        return try await fetchResult(from: resultURL)
    }

    private func submit(modelPath: String, payload: [String: Any]) async throws -> SubmittedJob {
        guard let submitURL = URL(string: "\(queueBase)/\(modelPath)") else {
            throw TryFavesRenderError.requestFailed
        }
        var request = try await authorizedRequest(url: submitURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let object = try await Self.json(for: request)
        guard let requestID = object["request_id"] as? String else {
            throw TryFavesRenderError.requestFailed
        }
        // fal returns canonical queue URLs alongside the ID; prefer them and
        // fall back to the documented layout when absent. Status endpoints
        // live under the app's owner/name, without deeper path segments.
        let appBase = modelPath.split(separator: "/").prefix(2).joined(separator: "/")
        let requestsBase = "\(Self.falQueueBase)/\(appBase)/requests/\(requestID)"
        let statusURL = try routed(object["status_url"] as? String ?? "\(requestsBase)/status")
        let responseURL = try routed(object["response_url"] as? String ?? requestsBase)
        return SubmittedJob(statusURL: statusURL, responseURL: responseURL)
    }

    private func waitForCompletion(job: SubmittedJob) async throws -> URL {
        let deadline = Date().addingTimeInterval(Self.pollBudget)

        while Date() < deadline {
            try Task.checkCancellation()
            let request = try await authorizedRequest(url: job.statusURL)
            let object = try await Self.json(for: request)
            switch object["status"] as? String {
            case "COMPLETED":
                if let raw = object["response_url"] as? String, let url = try? routed(raw) {
                    return url
                }
                return job.responseURL
            case "IN_QUEUE", "IN_PROGRESS":
                try await Task.sleep(for: Self.pollInterval)
            default:
                throw TryFavesRenderError.generationFailed
            }
        }
        throw TryFavesRenderError.timedOut
    }

    private func fetchResult(from url: URL) async throws -> Output {
        let request = try await authorizedRequest(url: url)
        let object = try await Self.json(for: request)
        // FASHN and nano-banana answer with an `images` array; BiRefNet with a
        // single `image` object.
        let hosted = (object["images"] as? [[String: Any]])?.first?["url"] as? String
            ?? (object["image"] as? [String: Any])?["url"] as? String
        guard let hostedURL = hosted, let imageURL = URL(string: hostedURL) else {
            throw TryFavesRenderError.generationFailed
        }
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        return Output(imageData: data, hostedURL: hostedURL)
    }

    private func authorizedRequest(url: URL) async throws -> URLRequest {
        let token: String
        switch route {
        case let .shopifyGateway(key):
            token = key
        case .falDirect:
            do {
                token = try await FalTokenProvider().token(for: "fal-ai/fashn")
            } catch {
                throw TryFavesRenderError.missingConfiguration
            }
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // The gateway caches identical requests; the queue flow must never
        // receive a replayed submit or a stale status snapshot.
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        return request
    }

    private static func json(for request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TryFavesRenderError.requestFailed
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TryFavesRenderError.requestFailed
        }
        return object
    }
}
