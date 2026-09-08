import SwiftUI

/// Direct review uses the same catalog, specification and renderer as Home.
/// Launch: -nextGenerationGallery 0...3. Not overlaid on a running HomePage.
struct NextGenerationFeedGallery: View {
    @State private var selectedIndex: Int
    @State private var session = GenerativeFeedPrototypeSession()
    private let merchants = LocalMerchantService.loadMerchants()

    init() {
        let args = ProcessInfo.processInfo.arguments
        let flag = args.firstIndex(of: "-nextGenerationGallery")
        let requested = flag.flatMap { args.indices.contains($0 + 1) ? Int(args[$0 + 1]) : nil } ?? 0
        _selectedIndex = State(initialValue: min(max(requested, 0), 3))
    }

    private var cards: [NextGenerationFeedCardSpec] {
        NextGenerationFeedCardCatalog.cards(signals: GenerativeFeedPrototypeFixtures.signals, merchants: merchants)
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom
            let totalHeight = proxy.size.height + topInset + bottomInset
            ZStack(alignment: .bottom) {
                Color.white
                if !cards.isEmpty {
                    let card = cards[min(selectedIndex, cards.count - 1)]
                    VStack(spacing: 0) {
                        NextGenerationFeedCardView(
                            spec: card, merchants: merchants,
                            width: proxy.size.width, height: totalHeight - bottomInset - 64,
                            foregroundTopPadding: topInset + 20, isActive: true, session: session
                        )
                        HStack {
                            Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 48, height: 48) }
                            Spacer()
                            Text("\(selectedIndex + 1) / \(cards.count) · \(session.composition(for: card).rawValue)")
                                .font(GravityFont.semiBold.fixedFont(size: 14))
                            Spacer()
                            Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 48, height: 48) }
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
        .onAppear { session.designMode = true }
    }

    private func move(_ direction: Int) {
        guard !cards.isEmpty else { return }
        selectedIndex = (selectedIndex + direction + cards.count) % cards.count
    }
}
