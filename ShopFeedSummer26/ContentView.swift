import SwiftUI

/// Entry point for the buyer-profile feed prototype.
///
/// The personalized assortment is bundled so the prototype opens directly
/// into the flick-and-stick feed without requiring Shop Server authentication.
/// When the dossier-lab feed API is reachable it takes over, replacing the
/// curated stories with ones generated from every saved dossier; if it is not,
/// the bundled assets stand and nothing about the prototype changes.
struct ContentView: View {
    @ObservedObject private var merchantService = RemoteMerchantService.shared
    @ObservedObject private var feedService = RemoteFeedService.shared
    @State private var userProfile = UserProfileService.shared
    @State private var historyClient = ConversationHistoryClient.shared
    @State private var postService = ShopPostService.shared

    var body: some View {
        RootView()
            .task {
                await feedService.load()
                // A bundled editorial feed and the signed-in relationship
                // graph are complementary. Always hydrate Luke's followed
                // shops when a Shop session exists instead of letting the
                // dossier snapshot shadow them.
                if AuthService.shared.hasSession {
                    PrototypeConfig.shared.merchantSource = .followed
                    await merchantService.loadMerchants(force: true)
                }
                if merchantService.merchants.isEmpty {
                    if feedService.isLive {
                        merchantService.publishLookupMerchants(feedService.merchants)
                    } else {
                        merchantService.loadFallbackData()
                    }
                    userProfile.applyFallbackProfile()
                }
            }
            // Secondary account content is independent of the first feed
            // frame. Load it concurrently so a slow history or posts request
            // never delays merchant hydration or topic interaction.
            .task {
                await historyClient.fetch()
            }
            .task {
                await postService.loadLukePosts()
            }
    }
}

#Preview {
    ContentView()
}
