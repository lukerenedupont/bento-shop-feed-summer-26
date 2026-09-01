import Observation
import Foundation

enum WorldExperienceForm: String, CaseIterable, Hashable {
    case merchandised
    case canvas
    case tryOn
    case spatial
    case gifting
    case mission

    var label: String {
        switch self {
        case .merchandised: "Merchandised"
        case .canvas: "Canvas"
        case .tryOn: "Try-on"
        case .spatial: "Spatial"
        case .gifting: "Gifting"
        case .mission: "Mission"
        }
    }
}

enum WorldPurpose: String, Hashable {
    case interest
    case intent
    case person
    case moment
    case mission
}

enum WorldLifetime: Hashable {
    case persistent
    case session
    case ephemeral(days: Int)
}

enum WorldOrigin: Hashable {
    case feed
    case relatedWorld(String)
    case child(parentSessionID: UUID)
}

enum WorldFactSource: String, Hashable {
    case stated
    case observed
    case inferred
    case inherited
}

enum WorldFactScope: String, Hashable {
    case buyer
    case subject
    case local
}

struct WorldFact: Identifiable, Hashable {
    let key: String
    var value: String
    let source: WorldFactSource
    let scope: WorldFactScope
    var id: String { key }
}

struct WorldContext: Hashable {
    private(set) var buyerFacts: [String: WorldFact] = [:]
    private(set) var subjectFacts: [String: WorldFact] = [:]
    private(set) var localFacts: [String: WorldFact] = [:]

    mutating func set(_ fact: WorldFact) {
        switch fact.scope {
        case .buyer: buyerFacts[fact.key] = fact
        case .subject: subjectFacts[fact.key] = fact
        case .local: localFacts[fact.key] = fact
        }
    }

    func value(for key: String) -> String? {
        localFacts[key]?.value ?? subjectFacts[key]?.value ?? buyerFacts[key]?.value
    }

    var resolvedFacts: [WorldFact] {
        let keys = Set(buyerFacts.keys).union(subjectFacts.keys).union(localFacts.keys)
        return keys.compactMap { key in
            localFacts[key] ?? subjectFacts[key] ?? buyerFacts[key]
        }
        .sorted { $0.key < $1.key }
    }
}

struct WorldPath: Identifiable, Hashable {
    let id: String
    let title: String
    let destinationWorldID: String
    let inheritedFactKeys: Set<String>
}

struct WorldDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let purpose: WorldPurpose
    let subject: String
    let primaryExperience: WorldExperienceForm
    let availableExperiences: Set<WorldExperienceForm>
    let lifetime: WorldLifetime
    let paths: [WorldPath]
}

struct WorldState: Hashable {
    var activeExperience: WorldExperienceForm
    var savedProductIDs: Set<String> = []
    var rejectedProductIDs: Set<String> = []
    var viewedProductIDs: Set<String> = []
    var completedMissionSteps: Set<String> = []
    var instructions: [String] = []
    var selectedProductID: String?
}

enum WorldAction: Hashable {
    case switchExperience(WorldExperienceForm)
    case setFact(WorldFact)
    case viewProduct(String)
    case saveProduct(String)
    case rejectProduct(String)
    case selectProduct(String)
    case toggleMissionStep(String)
    case steer(String)
}

struct WorldEvent: Identifiable, Hashable {
    let id = UUID()
    let action: WorldAction
    let date: Date
}

@Observable
final class WorldSession {
    let id: UUID
    let definition: WorldDefinition
    let origin: WorldOrigin
    private(set) var context: WorldContext
    private(set) var state: WorldState
    private(set) var events: [WorldEvent] = []

    init(
        id: UUID = UUID(),
        definition: WorldDefinition,
        origin: WorldOrigin = .feed,
        context: WorldContext = WorldContext()
    ) {
        self.id = id
        self.definition = definition
        self.origin = origin
        self.context = context
        state = WorldState(activeExperience: definition.primaryExperience)
    }

    func send(_ action: WorldAction) {
        switch action {
        case .switchExperience(let experience):
            guard definition.availableExperiences.contains(experience) else { return }
            state.activeExperience = experience
        case .setFact(let fact):
            context.set(fact)
        case .viewProduct(let id):
            state.viewedProductIDs.insert(id)
        case .saveProduct(let id):
            if state.savedProductIDs.contains(id) {
                state.savedProductIDs.remove(id)
            } else {
                state.savedProductIDs.insert(id)
                state.rejectedProductIDs.remove(id)
            }
        case .rejectProduct(let id):
            state.rejectedProductIDs.insert(id)
            state.savedProductIDs.remove(id)
        case .selectProduct(let id):
            state.selectedProductID = id
            state.viewedProductIDs.insert(id)
        case .toggleMissionStep(let id):
            if state.completedMissionSteps.contains(id) {
                state.completedMissionSteps.remove(id)
            } else {
                state.completedMissionSteps.insert(id)
            }
        case .steer(let instruction):
            let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            state.instructions.append(trimmed)
        }
        events.append(WorldEvent(action: action, date: Date()))
    }
}

@Observable
@MainActor
final class WorldPrototypePreferences {
    static let shared = WorldPrototypePreferences()

    private static let defaultsKey = "enabledWorldPrototypes"
    private(set) var enabledWorldIDs: Set<String>

    private init() {
        enabledWorldIDs = Set(
            UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
        )
    }

    func isEnabled(_ worldID: String) -> Bool {
        enabledWorldIDs.contains(worldID)
    }

    func setEnabled(_ enabled: Bool, for worldID: String) {
        if enabled {
            enabledWorldIDs.insert(worldID)
        } else {
            enabledWorldIDs.remove(worldID)
        }
        UserDefaults.standard.set(enabledWorldIDs.sorted(), forKey: Self.defaultsKey)
    }
}

@MainActor
final class WorldSessionStore {
    static let shared = WorldSessionStore()
    private var sessions: [String: WorldSession] = [:]

    func session(for definition: WorldDefinition) -> WorldSession {
        if let existing = sessions[definition.id] { return existing }
        let session = WorldSession(
            definition: definition,
            context: WorldPrototypeCatalog.initialContext(for: definition)
        )
        sessions[definition.id] = session
        return session
    }
}

enum WorldPrototypeCatalog {
    static let runningID = HypothesisShelfCatalog.performanceSneakerStoryID
    static let canvasID = "shelf-luke-6-analog-watches-desk-clocks"
    static let tryOnID = TryOnExperience.cardID
    static let spatialID = "shelf-luke-2-sculptural-living-room-pieces"
    static let giftingID = HypothesisShelfCatalog.giftGuideStoryID
    static let missionID = "shelf-mikhail-8-high-performance-ski-setup"

    static let topLevelWorldIDs = [
        runningID,
        canvasID,
        tryOnID,
        spatialID,
        giftingID,
        missionID,
    ]

    static var topLevelDefinitions: [WorldDefinition] {
        topLevelWorldIDs.compactMap { definitions[$0] }
    }

    static func definition(for storyID: String) -> WorldDefinition? {
        definitions[storyID]
    }

    static func feedStories(
        from authored: [FeedStory],
        available: [FeedStory],
        enabledIDs: Set<String>
    ) -> [FeedStory] {
        guard !enabledIDs.isEmpty else { return authored }
        let storiesByID = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
        let worlds: [FeedStory] = topLevelWorldIDs.compactMap { worldID in
            guard enabledIDs.contains(worldID), let source = storiesByID[worldID] else {
                return nil
            }
            return feedStory(from: source)
        }
        return worlds + authored.filter { !enabledIDs.contains($0.id) }
    }

    static func feedStory(from source: FeedStory) -> FeedStory {
        guard let definition = definitions[source.id] else { return source }
        return FeedStory(
            id: source.id,
            eyebrow: source.eyebrow,
            title: definition.title,
            subtitle: subtitle(for: source.id),
            format: .world,
            topicKeys: source.topicKeys,
            accentHex: source.accentHex,
            coverImageName: source.coverImageName,
            destinationLabel: source.destinationLabel,
            products: source.products
        )
    }

    private static func subtitle(for worldID: String) -> String {
        switch worldID {
        case runningID: "Shoes, recovery, and smaller running brands for finding a rhythm again."
        case canvasID: "A steerable canvas of distinctive vintage and contemporary watches from Very Special."
        case tryOnID: "Use the live camera to see products from your feed on you."
        case spatialID: "Place and swap warm sculptural pieces against the room you are building."
        case giftingID: "A living gift guide shaped around Leon, not a generic age bracket."
        case missionID: "A working plan for equipment, mountain layers, travel, and recovery."
        default: ""
        }
    }

    static func initialContext(for definition: WorldDefinition) -> WorldContext {
        var context = WorldContext()
        context.set(WorldFact(
            key: "shopping-style",
            value: "distinctive products from trusted and independent shops",
            source: .observed,
            scope: .buyer
        ))
        switch definition.id {
        case giftingID:
            context.set(WorldFact(key: "recipient", value: "Leon", source: .stated, scope: .subject))
            context.set(WorldFact(key: "age", value: "10", source: .stated, scope: .subject))
            context.set(WorldFact(key: "setting", value: "outdoors", source: .stated, scope: .local))
            context.set(WorldFact(key: "budget", value: "150", source: .stated, scope: .local))
        case canvasID:
            context.set(WorldFact(key: "style", value: "distinctive vintage and contemporary", source: .inferred, scope: .local))
            context.set(WorldFact(key: "merchant", value: "Very Special", source: .stated, scope: .local))
        case tryOnID:
            context.set(WorldFact(key: "subject", value: "Luke", source: .stated, scope: .subject))
            context.set(WorldFact(key: "input", value: "live camera", source: .stated, scope: .local))
        case spatialID:
            context.set(WorldFact(key: "room", value: "living room", source: .stated, scope: .subject))
            context.set(WorldFact(key: "mood", value: "warm and sculptural", source: .observed, scope: .local))
        case missionID:
            context.set(WorldFact(key: "trip", value: "ski weekend", source: .stated, scope: .local))
        default:
            context.set(WorldFact(key: "goal", value: "getting back into running", source: .stated, scope: .local))
        }
        return context
    }

    private static let definitions: [String: WorldDefinition] = {
        let values = [
            WorldDefinition(
                id: runningID,
                title: "Getting back into running",
                purpose: .intent,
                subject: "Luke",
                primaryExperience: .merchandised,
                availableExperiences: [.merchandised],
                lifetime: .ephemeral(days: 60),
                paths: []
            ),
            WorldDefinition(
                id: canvasID,
                title: "Find my next watch",
                purpose: .intent,
                subject: "Luke",
                primaryExperience: .canvas,
                availableExperiences: [.canvas],
                lifetime: .ephemeral(days: 30),
                paths: []
            ),
            WorldDefinition(
                id: tryOnID,
                title: "Try it live",
                purpose: .intent,
                subject: "Luke",
                primaryExperience: .tryOn,
                availableExperiences: [.tryOn],
                lifetime: .ephemeral(days: 21),
                paths: []
            ),
            WorldDefinition(
                id: spatialID,
                title: "Finish the living room",
                purpose: .intent,
                subject: "Luke’s living room",
                primaryExperience: .spatial,
                availableExperiences: [.spatial, .merchandised],
                lifetime: .ephemeral(days: 90),
                paths: []
            ),
            WorldDefinition(
                id: giftingID,
                title: "Gifts for Leon",
                purpose: .person,
                subject: "Leon",
                primaryExperience: .gifting,
                availableExperiences: [.gifting, .canvas],
                lifetime: .ephemeral(days: 30),
                paths: [
                    WorldPath(
                        id: "buildable-robots-for-leon",
                        title: "A robot Leon can build",
                        destinationWorldID: "leon-buildable-robots",
                        inheritedFactKeys: ["recipient", "age", "budget", "shopping-style"]
                    )
                ]
            ),
            WorldDefinition(
                id: missionID,
                title: "Ski weekend",
                purpose: .mission,
                subject: "Luke’s trip",
                primaryExperience: .mission,
                availableExperiences: [.mission],
                lifetime: .ephemeral(days: 14),
                paths: []
            ),
        ]
        return Dictionary(uniqueKeysWithValues: values.map { ($0.id, $0) })
    }()
}
