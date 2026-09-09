import SwiftUI

/// PROTOTYPE direct review. Same data, state and rendering as Home.
struct NextGenerationFeedGallery: View {
    @State private var selectedCardID: String
    @State private var session = GenerativeFeedPrototypeSession(persistence: GenerativeFeedPrototypeSession.demoPersistence)
    private let merchants = NextGenerationFeedCardCatalog.prototypeMerchants

    init() {
        let args = ProcessInfo.processInfo.arguments
        let flag = args.firstIndex(of: "-nextGenerationGallery")
        let requested = flag.flatMap { args.indices.contains($0 + 1) ? Int(args[$0 + 1]) : nil } ?? 0
        let signals = GenerativeFeedPrototypeFixtures.signals
        guard !signals.isEmpty else {
            _selectedCardID = State(initialValue: "empty-feed")
            return
        }
        let requestedSignal = signals[min(max(requested, 0), signals.count - 1)]
        _selectedCardID = State(initialValue: "next-gen-\(requestedSignal.id)")
        if QuietFeedReviewCatalog.enabled, DossierReviewLibrary.enabled {
            let demo = GenerativeFeedPrototypeSession(persistence: GenerativeFeedPrototypeSession.demoPersistence)
            demo.setSignalEnabled(true, id: requestedSignal.id)
            _session = State(initialValue: demo)
        }
        if args.contains("-fisheyeCanvas"),
           let card = NextGenerationFeedCardCatalog.cards(signals: signals, merchants: NextGenerationFeedCardCatalog.prototypeMerchants)
            .first(where: { $0.alternatives.contains(.fisheye) }) {
            let demo = GenerativeFeedPrototypeSession()
            demo.setComposition(.fisheye, for: card)
            _session = State(initialValue: demo)
            _selectedCardID = State(initialValue: card.id)
        }
    }
    private var cards: [NextGenerationFeedCardSpec] {
        let sources = NextGenerationFeedCardCatalog.cards(signals: GenerativeFeedPrototypeFixtures.signals, merchants: merchants)
        return session.arrange(sources.map(FeedEntry.nextGeneration)).compactMap {
            if case let .nextGeneration(spec) = $0 { return spec }; return nil
        }
    }
    private var selectedIndex: Int { cards.firstIndex { $0.id == selectedCardID } ?? 0 }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom
            let totalHeight = proxy.size.height + topInset + bottomInset
            ZStack(alignment: .bottom) {
                Color.white
                if !cards.isEmpty {
                    let card = cards[selectedIndex]
                    VStack(spacing: 0) {
                        NextGenerationFeedCardView(
                            sourceSpec: card, merchants: merchants,
                            width: proxy.size.width, height: totalHeight - bottomInset - 64,
                            foregroundTopPadding: topInset + 20, isActive: true, session: session
                        )
                        HStack {
                            Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 48, height: 48) }
                                .accessibilityLabel("Previous experience")
                            Spacer()
                            Text(session.designMode
                                ? "\(selectedIndex + 1) / \(cards.count) · \(session.composition(for: session.resolve(card, merchants: merchants)).rawValue)"
                                : "\(selectedIndex + 1) of \(cards.count)")
                                .font(GravityFont.semiBold.fixedFont(size: 14))
                            Spacer()
                            Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 48, height: 48) }
                                .accessibilityLabel("Next experience")
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .frame(height: 64)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(width: proxy.size.width, height: totalHeight)
            .offset(y: -topInset)
        }
        .onChange(of: session.requestedJourneySignalID) { _, signalID in
            guard let signalID, let card = cards.first(where: { $0.signal.id == signalID }) else { return }
            selectedCardID = card.id
            session.requestedJourneySignalID = nil
        }
        .modifier(GenerativePrototypeTools(session: session, merchants: merchants))
    }
    private func move(_ direction: Int) {
        guard !cards.isEmpty else { return }
        selectedCardID = cards[(selectedIndex + direction + cards.count) % cards.count].id
    }
}
