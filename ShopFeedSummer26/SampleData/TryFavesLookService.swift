import CryptoKit
import Foundation
import SwiftUI
import UIKit

/// Generates, caches, and persists "Try your faves" looks.
///
/// Rendering runs through fal's queue API. Every look is composed from the
/// seed photograph in a single `openai/gpt-image-2/edit` pass — garments,
/// pose, and the selected environment in one generation. Each look is one
/// flat photograph, like a frame from an editorial photo shoot: posture and
/// shot variations cycle per look so consecutive generations share the
/// location but never feel identical.
/// The fal API key never ships in the app: every HTTP call is authorized with
/// a short-lived JWT minted by the same server-side token endpoint the live
/// Decart studio uses (`FAL_TOKEN_ENDPOINT` / Shopify proxy fallback). fal's
/// queue supports webhooks, but a client-only prototype has no callback URL,
/// so completion is observed by polling the queue's status endpoint instead.
@MainActor
@Observable
final class TryFavesLookService {
    static let shared = TryFavesLookService()

    static let modelVersion = "openai/gpt-image-2/edit"
    /// Generation settings, frozen into the cache key. `shoot-v4` is the
    /// flat-photograph pipeline: environment baked into the render (anchored
    /// by the environment's seed photograph when it has one, as a location
    /// reference that never drives framing), per-look shot variation, and
    /// per-buyer seed photographs.
    static let generationSettings = "quality=high|samples=1|png|9x16|shoot-v4"

    /// Seed-photograph settings, part of the seed cache key and — through
    /// the seed identity — of every look cache key derived from it.
    /// `seed-v2`: neutral expression, direct gaze, natural head proportions.
    static let seedSettings = "seed-v2"

    /// Ten subtle stances, cycled per generation so consecutive looks don't
    /// share an identical pose. The index is stored on the look (stable
    /// through retries) and folded into the render cache key.
    ///
    /// `shotVariations` cycles independently — the array lengths are coprime
    /// (10 and 7), so posture/shot pairings don't repeat for 70 looks.
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

    /// Seven subtle shot-to-shot variations — framing, camera angle, light —
    /// so each look reads as a different frame from the same photo shoot
    /// rather than a re-render of the previous one.
    static let shotVariations = [
        "framed slightly wider, with a little more of the space visible around him",
        "framed slightly tighter on the figure, still full body head to toe",
        "the camera shifted a touch to the left of centre",
        "the camera shifted a touch to the right of centre",
        "the light a little softer and more diffuse",
        "the light slightly warmer, like late afternoon",
        "the figure standing just off-centre in the frame",
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
        /// Rewritten on retry: the key derives from model, settings, posture,
        /// shot, environment, and the appearance note, any of which may
        /// change between attempts.
        var cacheKey: String
        let createdAt: Date
        var state: LookState
        var attemptCount: Int
        /// Index into `posturePrompts`; 0 for looks predating posture cycling.
        var postureIndex: Int = 0
        /// Index into `shotVariations` — the frame's own camera/light nuance.
        var shotIndex: Int = 0
    }

    enum JobPhase: Equatable {
        case queued
        case composing
        case validating

        var label: String {
            switch self {
            case .queued: "Queued"
            case .composing: "Composing the look"
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

    /// The preview buyer whose seed photograph and look library are loaded.
    private(set) var buyerID: String = BuyerPreviewStore.shared.selected.id

    /// Generated per-buyer seed photographs. Observed, so pages swap from
    /// the bundled fallback the moment a buyer's seed lands.
    private var seedImages: [String: UIImage] = [:]
    @ObservationIgnored private var seedTasks: [String: Task<UIImage, Error>] = [:]
    @ObservationIgnored private var isPrefetchingSeeds = false


    /// The location the shoot happens in. It is baked into every generation's
    /// prompt — and therefore into the render cache key — so changing it
    /// affects new looks only; existing photographs keep their location.
    var environment: TryFavesEnvironment = TryFavesLookService.loadEnvironment() {
        didSet {
            UserDefaults.standard.set(environment.rawValue, forKey: Self.environmentDefaultsKey)
        }
    }

    private static let environmentDefaultsKey = "TryFavesEnvironment"

    private static func loadEnvironment() -> TryFavesEnvironment {
        let stored = TryFavesEnvironment(
            rawValue: UserDefaults.standard.string(forKey: environmentDefaultsKey) ?? ""
        )
        guard let stored, stored.isAvailable else { return .seed }
        return stored
    }

    /// A free-text appearance or pose note from Try on configuration. It rides
    /// along with the posture pass, so it changes what is generated — and is
    /// therefore part of the render cache key.
    var appearanceNote: String = TryFavesLookService.loadAppearanceNote() {
        didSet {
            UserDefaults.standard.set(appearanceNote, forKey: Self.appearanceNoteDefaultsKey)
        }
    }

    private static let appearanceNoteDefaultsKey = "TryFavesAppearanceNote"

    private static func loadAppearanceNote() -> String {
        UserDefaults.standard.string(forKey: appearanceNoteDefaultsKey) ?? ""
    }

    /// Whether Try on configuration has ever been opened. Drives the one-time
    /// discovery dot on the settings button — not a notification.
    var hasOpenedConfiguration: Bool = UserDefaults.standard.bool(
        forKey: "TryFavesHasOpenedConfiguration"
    ) {
        didSet {
            UserDefaults.standard.set(hasOpenedConfiguration, forKey: "TryFavesHasOpenedConfiguration")
        }
    }
    /// A finished look the shopper hasn't opened yet — drives the
    /// "View new look" chip and its badge.
    private(set) var unseenLookID: UUID?

    /// Render restore is observation-ignored: pages re-render off `looks`
    /// state changes, and the lazy disk restore inside `renderImage(for:)`
    /// must never re-enter SwiftUI's update transaction.
    @ObservationIgnored private var renderImages: [String: UIImage] = [:]
    @ObservationIgnored private var generationTask: Task<Void, Never>?

    private init() {
        looks = Self.loadLooks(buyerID: buyerID)
        // A relaunch mid-generation leaves orphaned `.generating` looks with
        // no task attached. Surface them as retryable instead of spinning.
        for index in looks.indices where looks[index].state == .generating {
            looks[index].state = .failed("Generation was interrupted.")
        }
    }

    // MARK: - Buyer scoping

    /// Looks and seed photographs are scoped per preview buyer. Called from
    /// the world page, the Home card, and every generation entry point, so
    /// switching buyers swaps the seed image and the look library together.
    func syncBuyerIfNeeded() {
        let selected = BuyerPreviewStore.shared.selected.id
        guard selected != buyerID else { return }

        // A generation in flight belongs to the outgoing buyer: cancel it
        // and leave the look retryable in that buyer's library.
        if let job = activeJob {
            generationTask?.cancel()
            generationTask = nil
            update(lookID: job.lookID) { $0.state = .failed("Generation was interrupted.") }
            activeJob = nil
        }
        persistLooks()

        buyerID = selected
        looks = Self.loadLooks(buyerID: selected)
        for index in looks.indices where looks[index].state == .generating {
            looks[index].state = .failed("Generation was interrupted.")
        }
        unseenLookID = nil
        ensureSeed()
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
        syncBuyerIfNeeded()
        guard activeJob == nil else { return nil }

        // Cycle stances and shot variations independently so consecutive
        // generations read as different frames from the same shoot.
        let postureIndex = looks.count % Self.posturePrompts.count
        let shotIndex = looks.count % Self.shotVariations.count
        let cacheKey = cacheKey(
            for: outfit,
            postureIndex: postureIndex,
            shotIndex: shotIndex,
            environment: environment,
            note: appearanceNote
        )
        let look = Look(
            id: UUID(),
            // The seed photograph is Look 1, so generated looks start at 2.
            title: "Look \(looks.count + 2)",
            variantIDs: outfit.orderedVariantIDs,
            cacheKey: cacheKey,
            createdAt: Date(),
            state: .generating,
            attemptCount: 0,
            postureIndex: postureIndex,
            shotIndex: shotIndex
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

        startGeneration(lookID: look.id, outfit: outfit, postureIndex: postureIndex, shotIndex: shotIndex)
        return look.id
    }

    func retry(_ lookID: UUID) {
        guard let look = looks.first(where: { $0.id == lookID }), look.state.isFailed else {
            return
        }
        regenerate(lookID)
    }

    /// Re-shoot a look under the current environment and appearance note.
    ///
    /// Both are prompt-only — they describe the photograph rather than edit
    /// it — so changing them in Try on configuration has no effect until the
    /// look is generated again. Returns the look that will carry the result.
    ///
    /// The seed look is a bundled photograph with no pipeline behind it, so it
    /// cannot be re-shot in place; its outfit is generated as a new look
    /// instead, which is also what makes the change visible without destroying
    /// the one photograph every shopper starts from.
    @discardableResult
    func regenerate(_ lookID: UUID) -> UUID? {
        syncBuyerIfNeeded()
        guard activeJob == nil else { return nil }

        guard lookID != Self.seedLookID else {
            guard let outfit = Self.outfit(from: TryFavesCatalog.seedLookGarments) else {
                return nil
            }
            return generate(outfit: outfit)
        }

        guard let look = looks.first(where: { $0.id == lookID }) else { return nil }
        let garments = look.variantIDs.compactMap(TryFavesCatalog.garment(for:))
        guard let outfit = Self.outfit(from: garments) else { return nil }

        // Re-key the look before rendering: the model, settings, environment,
        // or appearance note may have changed since it was created, and the
        // render lands under the freshly computed key.
        let cacheKey = cacheKey(
            for: outfit,
            postureIndex: look.postureIndex,
            shotIndex: look.shotIndex,
            environment: environment,
            note: appearanceNote
        )
        update(lookID: lookID) {
            $0.state = .generating
            $0.cacheKey = cacheKey
        }
        startGeneration(
            lookID: lookID,
            outfit: outfit,
            postureIndex: look.postureIndex,
            shotIndex: look.shotIndex
        )
        return lookID
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
            return seedRenderImage()
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
    // MARK: - Generation pipeline

    private func startGeneration(
        lookID: UUID,
        outfit: TryFavesOutfit,
        postureIndex: Int,
        shotIndex: Int
    ) {
        let attempt = (looks.first { $0.id == lookID }?.attemptCount ?? 0) + 1
        update(lookID: lookID) { $0.attemptCount = attempt }
        activeJob = Job(lookID: lookID, phase: .queued, attempt: attempt)

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.render(
                    outfit: outfit,
                    postureIndex: postureIndex,
                    shotIndex: shotIndex
                )
                let cacheKey = self.cacheKey(
                    for: outfit,
                    postureIndex: postureIndex,
                    shotIndex: shotIndex,
                    environment: self.environment,
                    note: self.appearanceNote
                )
                self.storeCachedRender(result.image, for: cacheKey)
                self.renderImages[cacheKey] = result.image
                self.finish(lookID: lookID, state: .ready)
            } catch is CancellationError {
                self.finish(lookID: lookID, state: .failed("Generation was cancelled."))
            } catch let error as TryFavesRenderError {
                self.finish(lookID: lookID, state: .failed(error.shopperMessage))
            } catch {
                self.finish(lookID: lookID, state: .failed("The look couldn't be generated."))
            }
        }
    }

    /// One GPT Image 2 edit composes garments, pose, and the selected
    /// environment directly from the seed photograph. One automatic retry
    /// covers transient queue failures and bad frames; anything after that
    /// is a user-visible retry.
    private func render(
        outfit: TryFavesOutfit,
        postureIndex: Int,
        shotIndex: Int
    ) async throws -> (image: UIImage, hostedURL: String) {
        let client = FalQueueClient()
        let avatar = try await seedDataURI()
        let posture = Self.posturePrompts[postureIndex % Self.posturePrompts.count]
        let shot = Self.shotVariations[shotIndex % Self.shotVariations.count]

        let garments: [TryOnGarment] = switch outfit {
        case let .shoesOnly(shoes):
            [shoes]
        case let .separates(top, bottom, shoes):
            [top, bottom] + (shoes.map { [$0] } ?? [])
        }

        activeJob?.phase = .composing
        let note = appearanceNote
        let location = environment
        // The environment's own seed photograph rides along as the last
        // reference image, anchoring the location across the whole shoot.
        let locationReference = location.plateAssetName
            .flatMap { UIImage(named: $0) }
            .flatMap { $0.jpegData(compressionQuality: 0.85) }
            .map { "data:image/jpeg;base64,\($0.base64EncodedString())" }
        var lastError: Error = TryFavesRenderError.generationFailed
        for _ in 0..<2 {
            do {
                let output = try await client.composeLook(
                    prompt: Self.lookPrompt(
                        garments: garments,
                        posture: posture,
                        shot: shot,
                        environment: location,
                        hasLocationReference: locationReference != nil,
                        note: note
                    ),
                    imageURLs: [avatar] + garments.map(\.imageURL)
                        + (locationReference.map { [$0] } ?? [])
                )
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

    /// One instruction covering garments, environment, pose, and the frame's
    /// own shot variation — each garment referenced by its position in
    /// `image_urls` (the seed avatar is always first; the environment's seed
    /// photograph, when present, is always last).
    private static func lookPrompt(
        garments: [TryOnGarment],
        posture: String,
        shot: String,
        environment: TryFavesEnvironment,
        hasLocationReference: Bool,
        note: String
    ) -> String {
        let ordinals = ["second", "third", "fourth", "fifth"]
        let references = zip(garments, ordinals)
            .map { garment, ordinal in "the \(garment.category.promptNoun) from the \(ordinal) image" }
            .joined(separator: ", then ")
        let wardrobe = garments.contains { $0.category != .footwear }
            ? "Replace the corresponding clothing they are wearing."
            : "Keep the rest of their clothing exactly as photographed."
        let location = hasLocationReference
            ? "Photograph them standing in the location shown in the last "
                + "image — \(environment.promptDescription) — matching its light "
                + "and atmosphere. The last image is a location reference only: "
                + "never take framing, crop, zoom, or camera distance from it."
            : "Photograph them standing in \(environment.promptDescription)."
        return "The first image is a photograph of a person. Dress them in "
            + "\(references) — reproduce each garment's precise design, shape, "
            + "colors, materials, sole, stitching, and details faithfully, "
            + "adjusted to the person's body and viewing angle. \(wardrobe) "
            + "\(location) "
            + "Pose: \(posture).\(Self.noteClause(note)) "
            + "This is one frame from an editorial photo shoot in that location, "
            + "so vary it naturally from other frames: \(shot). "
            + "Keep the exact same person, face, and hair. "
            + "\(Self.framingRules) "
            + "Match the first image's camera distance and figure size exactly. "
            + "The shot variation stays subtle and never overrides these "
            + "framing rules. "
            + "Vertical photorealistic editorial photograph, natural skin and "
            + "fabric texture, no retouching."
    }

    /// Zoom/crop guardrails shared by seed and look generations, keeping the
    /// figure the same size in every frame of every shoot.
    private static let framingRules = "Framing rules for every frame of the shoot: full-length lookbook "
        + "framing from a camera at chest height, the person standing "
        + "centred, full body head to toe with feet grounded and a natural "
        + "floor shadow. The figure spans roughly two thirds of the frame's "
        + "height — head in the top quarter, feet in the bottom quarter — "
        + "with clear space above the head and below the feet. Never crop "
        + "the figure, never zoom closer than mid-shin, never pull back so "
        + "far the figure drops below half the frame's height."

    /// The shopper's free-text appearance note, folded into a prompt as its own
    /// sentence. Empty notes contribute nothing rather than an empty clause.
    static func noteClause(_ note: String) -> String {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return " Also apply this change to the person: \(trimmed)."
    }

    private func finish(lookID: UUID, state: LookState) {
        // A cancelled generation (buyer switch) may resolve after its look
        // left the loaded library; it must not clobber the next buyer's job.
        guard activeJob?.lookID == lookID else { return }
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
        // The edit output is pinned to a tall frame, but accept anything from
        // a slim full-body strip to a squarish studio frame. Only degenerate
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

    // MARK: - Seed photographs

    /// The bundled seed photograph: Luke-era reference imagery. It is every
    /// buyer seed's style/framing reference, and the display and generation
    /// fallback for buyers whose own seed hasn't landed yet.
    static let seedAvatarAssetName = "try-faves-avatar"

    /// SHA-256 of the bundled photograph. Part of every seed identity so new
    /// reference photography invalidates derived seeds and renders.
    private static let bundledSeedHash: String = {
        guard let image = UIImage(named: seedAvatarAssetName),
              let data = image.pngData() else { return "no-avatar" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }()

    private static func bundledSeedDataURI() throws -> String {
        guard let seed = UIImage(named: seedAvatarAssetName),
              let jpeg = seed.jpegData(compressionQuality: 0.85) else {
            throw TryFavesRenderError.missingAvatar
        }
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }

    private static func buyerAvatarAssetName(for buyerID: String) -> String? {
        BuyerPreviewStore.profiles.first { $0.id == buyerID }?.avatarAssetName
    }

    /// Identity of a buyer's seed photograph — buyer, avatar pixels, seed
    /// settings, and the bundled reference — folded into every look cache
    /// key so one buyer never reuses another's renders, and a changed avatar
    /// regenerates everything derived from it.
    private static var seedIdentities: [String: String] = [:]

    private static func seedIdentity(for buyerID: String) -> String {
        if let cached = seedIdentities[buyerID] { return cached }
        let avatarHash: String
        if let asset = buyerAvatarAssetName(for: buyerID),
           let data = UIImage(named: asset)?.pngData() {
            avatarHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        } else {
            avatarHash = "no-buyer-avatar"
        }
        let identity = "buyer-\(buyerID)|\(avatarHash)|\(bundledSeedHash)|\(seedSettings)"
        seedIdentities[buyerID] = identity
        return identity
    }

    /// The current buyer's seed photograph for display: their generated seed
    /// once it lands, the bundled photograph until then.
    func seedRenderImage() -> UIImage? {
        seedImages[buyerID] ?? UIImage(named: Self.seedAvatarAssetName)
    }

    /// Kick off (or restore from disk) the current buyer's seed photograph.
    /// Must be called from an async context such as `.task` — never during a
    /// view body — because it publishes observable state. No-op for buyers
    /// without an avatar; they keep the bundled seed.
    func ensureSeed() {
        let buyerID = buyerID
        guard seedImages[buyerID] == nil else { return }
        if let disk = loadCachedSeed(for: buyerID) {
            seedImages[buyerID] = disk
            return
        }
        guard seedTasks[buyerID] == nil,
              Self.buyerAvatarAssetName(for: buyerID) != nil else { return }
        seedTasks[buyerID] = makeSeedTask(for: buyerID)
    }

    /// Generate every preview buyer's seed ahead of need, one at a time to
    /// stay clear of gateway rate limits. Disk-cached buyers are skipped;
    /// the active buyer's own `ensureSeed` task is awaited rather than
    /// duplicated. Called when the Home card appears, so every buyer's
    /// photograph is usually ready before they are ever selected.
    func ensureAllSeeds() {
        guard !isPrefetchingSeeds else { return }
        isPrefetchingSeeds = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.isPrefetchingSeeds = false }
            for profile in BuyerPreviewStore.profiles {
                let id = profile.id
                guard self.seedImages[id] == nil else { continue }
                if let disk = self.loadCachedSeed(for: id) {
                    self.seedImages[id] = disk
                    continue
                }
                guard profile.avatarAssetName != nil else { continue }
                let task = self.seedTasks[id] ?? self.makeSeedTask(for: id)
                self.seedTasks[id] = task
                _ = try? await task.value
            }
        }
    }

    /// One GPT Image 2 pass recreates the bundled seed photograph with the
    /// buyer's avatar as the person. One automatic retry covers transient
    /// queue failures; a failed task clears itself so a later `ensureSeed`,
    /// prefetch, or look generation can try again.
    private func makeSeedTask(for buyerID: String) -> Task<UIImage, Error> {
        Task {
            defer { seedTasks[buyerID] = nil }
            guard let asset = Self.buyerAvatarAssetName(for: buyerID),
                  let avatar = UIImage(named: asset),
                  let avatarJPEG = avatar.jpegData(compressionQuality: 0.85) else {
                throw TryFavesRenderError.missingAvatar
            }
            let avatarURI = "data:image/jpeg;base64,\(avatarJPEG.base64EncodedString())"
            let reference = try Self.bundledSeedDataURI()
            var lastError: Error = TryFavesRenderError.generationFailed
            for _ in 0..<2 {
                do {
                    let output = try await FalQueueClient().composeLook(
                        prompt: Self.seedPrompt,
                        imageURLs: [avatarURI, reference]
                    )
                    let image = try Self.validated(output.imageData)
                    seedImages[buyerID] = image
                    storeCachedSeed(image, for: buyerID)
                    return image
                } catch {
                    lastError = error
                    try Task.checkCancellation()
                }
            }
            throw lastError
        }
    }

    private static let seedPrompt = "The first image shows a person. The second image is a "
        + "full-length studio photograph of a different person. Recreate the "
        + "second photograph exactly — the same warm plaster studio, the same "
        + "soft natural light and floor shadow, the same plain white t-shirt, "
        + "dark jeans, and dark loafers, the same pose — but the person is "
        + "the person from the first image: reproduce their face, hair, and "
        + "skin tone faithfully. The first image is only an identity "
        + "reference: do not copy its expression, head angle, framing, or "
        + "proportions. Give the person a neutral, relaxed expression, "
        + "looking directly ahead at the camera, with realistic natural "
        + "head-to-body proportions for a full-length photograph — the head "
        + "must not be enlarged. \(framingRules) Match the second image's "
        + "camera distance and figure size exactly. Vertical photorealistic "
        + "editorial photograph, natural skin and fabric texture, no "
        + "retouching."

    /// The current buyer's seed as a data URI for a look generation — always
    /// the first reference image in the edit. Awaits an in-flight seed
    /// generation (spawning one if needed) and falls back to the bundled
    /// photograph rather than sinking the look when the seed can't be made.
    private func seedDataURI() async throws -> String {
        let buyerID = buyerID
        ensureSeed()
        if let task = seedTasks[buyerID] {
            _ = try? await task.value
        }
        if let image = seedImages[buyerID],
           let jpeg = image.jpegData(compressionQuality: 0.85) {
            return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        }
        return try Self.bundledSeedDataURI()
    }

    private func seedCacheFileName(for buyerID: String) -> String {
        let material = "\(Self.seedIdentity(for: buyerID))|\(Self.modelVersion)"
        let hash = SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "seed-\(hash).png"
    }

    private func loadCachedSeed(for buyerID: String) -> UIImage? {
        let url = Self.cacheDirectory.appendingPathComponent(seedCacheFileName(for: buyerID))
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func storeCachedSeed(_ image: UIImage, for buyerID: String) {
        guard let data = image.pngData() else { return }
        try? FileManager.default.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.cacheDirectory.appendingPathComponent(seedCacheFileName(for: buyerID)))
    }

    // MARK: - Render cache

    /// Renders are keyed on the buyer's seed identity + ordered variant IDs +
    /// posture + shot variation + environment + appearance note + model +
    /// settings, so buyers never share renders.
    func cacheKey(
        for outfit: TryFavesOutfit,
        postureIndex: Int = 0,
        shotIndex: Int = 0,
        environment: TryFavesEnvironment = .seed,
        note: String = ""
    ) -> String {
        let material = [
            Self.seedIdentity(for: buyerID),
            outfit.orderedVariantIDs.joined(separator: "+"),
            "pose-\(postureIndex)",
            "shot-\(shotIndex)",
            "env-\(environment.rawValue)",
            "note-\(note.trimmingCharacters(in: .whitespacesAndNewlines))",
            Self.modelVersion,
            Self.generationSettings,
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

    // MARK: - Look persistence

    /// Versioned, per-buyer filename: `shoot-v1` retired the lifted-figure
    /// looks, and each preview buyer keeps their own look library so
    /// switching buyers switches the whole shoot.
    private static func looksFileURL(buyerID: String) -> URL {
        cacheDirectory.appendingPathComponent("looks-shoot-v1-\(buyerID).json")
    }

    private func persistLooks() {
        try? FileManager.default.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(looks) else { return }
        try? data.write(to: Self.looksFileURL(buyerID: buyerID))
    }

    private static func loadLooks(buyerID: String) -> [Look] {
        guard let data = try? Data(contentsOf: looksFileURL(buyerID: buyerID)),
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

/// Minimal client for fal's queue API. Submits a generation job, polls its
/// status, and downloads the finished PNG.
///
/// Preferred route is the Shopify LLM gateway: set `SHOPIFY_PROXY_KEY` in
/// `.env.local` with a token from https://proxy.shopify.io and every queue
/// call goes through `proxy.shopify.ai/vendors/fal-queue-run` with a static
/// Bearer key — no fal credential ever touches the app. Without a gateway
/// key it falls back to fal's queue directly, minting a short-lived JWT per
/// call from `FAL_TOKEN_ENDPOINT`.
private struct FalQueueClient {
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

    /// The look pass: one GPT Image 2 edit that poses the seed and applies
    /// every garment at once. References ride in `image_urls` — seed first,
    /// then garments in prompt order.
    func composeLook(prompt: String, imageURLs: [String]) async throws -> Output {
        try await run(
            modelPath: TryFavesLookService.modelVersion,
            payload: [
                "prompt": prompt,
                "image_urls": imageURLs,
                // Pin the tall frame — on auto the edit infers size from its
                // inputs, and square garment flats skew the output.
                "image_size": "portrait_16_9",
                "quality": "high",
                "num_images": 1,
                "output_format": "png",
            ]
        )
    }

    private func run(modelPath: String, payload: [String: Any]) async throws -> Output {
        // fal JWTs are scoped per app; derive it from the model path so the
        // direct-fal fallback mints a token scoped to the model's app.
        let app = modelPath.split(separator: "/").prefix(2).joined(separator: "/")
        let job = try await submit(modelPath: modelPath, payload: payload, app: app)
        let resultURL = try await waitForCompletion(job: job, app: app)
        return try await fetchResult(from: resultURL, app: app)
    }

    private func submit(modelPath: String, payload: [String: Any], app: String) async throws -> SubmittedJob {
        guard let submitURL = URL(string: "\(queueBase)/\(modelPath)") else {
            throw TryFavesRenderError.requestFailed
        }
        var request = try await authorizedRequest(url: submitURL, app: app)
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

    private func waitForCompletion(job: SubmittedJob, app: String) async throws -> URL {
        let deadline = Date().addingTimeInterval(Self.pollBudget)

        while Date() < deadline {
            try Task.checkCancellation()
            let request = try await authorizedRequest(url: job.statusURL, app: app)
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

    private func fetchResult(from url: URL, app: String) async throws -> Output {
        let request = try await authorizedRequest(url: url, app: app)
        let object = try await Self.json(for: request)
        // GPT Image 2 answers with an `images` array.
        let hosted = (object["images"] as? [[String: Any]])?.first?["url"] as? String
        guard let hostedURL = hosted, let imageURL = URL(string: hostedURL) else {
            throw TryFavesRenderError.generationFailed
        }
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        return Output(imageData: data, hostedURL: hostedURL)
    }

    private func authorizedRequest(url: URL, app: String) async throws -> URLRequest {
        let token: String
        switch route {
        case let .shopifyGateway(key):
            token = key
        case .falDirect:
            do {
                token = try await FalTokenProvider().token(for: app)
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

private extension TryOnGarmentCategory {
    /// How the single-pass prompt names each garment reference.
    var promptNoun: String {
        switch self {
        case .tops: "top"
        case .bottoms: "bottoms"
        case .footwear: "shoes"
        }
    }
}
