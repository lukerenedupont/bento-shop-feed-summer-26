import Observation
import SwiftUI

@Observable
final class TopicHeaderScrollState {
    var showsTitle = false
}

/// Owns the only scroll-responsive topic chrome. Keeping this in a separate
/// observation boundary prevents a title visibility change from rebuilding
/// the video hero and every merchandising rail on the page.
struct TopicCompactHeaderBackdrop: View {
    let state: TopicHeaderScrollState
    let title: String
    let surfaceColor: Color
    let width: CGFloat
    let topInset: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            if state.showsTitle {
                // Resolve scrolling content into the authored topic color
                // instead of smearing it through a system material. This
                // keeps product photography crisp beneath a cleaner fade.
                LinearGradient(
                    stops: [
                        .init(color: surfaceColor.opacity(0.98), location: 0),
                        .init(color: surfaceColor.opacity(0.94), location: 0.56),
                        .init(color: surfaceColor.opacity(0.72), location: 0.78),
                        .init(color: surfaceColor.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Text(title)
                    .font(GravityFont.semiBold.fixedFont(size: 15))
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: max(120, width - 140))
                    .padding(.top, topInset + 14)
                    .transition(.opacity)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .frame(width: width, height: topInset + 72, alignment: .top)
        .animation(.easeOut(duration: 0.14), value: state.showsTitle)
    }
}
