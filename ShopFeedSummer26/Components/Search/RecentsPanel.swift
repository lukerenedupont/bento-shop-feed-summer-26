import SwiftUI

/// Slide-over panel showing recent agent conversations.
struct RecentsPanel: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let conversations: [RecentConversation]
    let isLoading: Bool
    var isVisible: Bool = false
    var onSelect: (RecentConversation) -> Void = { _ in }
    var onClose: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading && conversations.isEmpty {
                skeletonView
            } else if conversations.isEmpty {
                emptyView
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(conversations) { conversation in
                            Button {
                                HapticFeedback.light.fire()
                                onSelect(conversation)
                            } label: {
                                conversationRow(conversation)
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, GravitySpacing.screenMargin)
                    .padding(.top, PurlTune.value("Components/Search/RecentsPanel.swift:padding:_:31:36", default: 100))
                    .padding(.bottom, PurlTune.value("Components/Search/RecentsPanel.swift:padding:_:32:39", default: 100))
                }
                .ignoresSafeArea()
            }

            Spacer(minLength: 0)
        }
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: PurlTune.value("Components/Search/RecentsPanel.swift:spring:response:41:38", default: 0.4), dampingFraction: PurlTune.value("Components/Search/RecentsPanel.swift:spring:dampingFraction:41:147", default: 0.85)).delay(0.05), value: isVisible)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PurlTune.token("Components/Search/RecentsPanel.swift:background:_:43:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
        .overlay(alignment: .top) {
            VStack() {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: GravityColors.bg, location: 0),
                                .init(color: GravityColors.bg, location: 0.5),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: PurlTune.value("Components/Search/RecentsPanel.swift:frame:height:59:36", default: 140))
                    .allowsHitTesting(false)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            Text("Recents")
                .gravityTextStyle(GravityTypography.header)
                .foregroundStyle(PurlTune.token("Components/Search/RecentsPanel.swift:foregroundStyle:_:68:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                .padding(.horizontal, GravitySpacing.screenMargin)
                .padding(.top, PurlTune.token("Components/Search/RecentsPanel.swift:padding:_:70:32", default: GravitySpacing.space48, options: GravitySpacing.purlTuneOptions))
                .padding(.top, PurlTune.token("Components/Search/RecentsPanel.swift:padding:_:71:32", default: GravitySpacing.space10, options: GravitySpacing.purlTuneOptions))
                .opacity(isVisible ? 1 : 0)
                .animation(.spring(response: PurlTune.value("Components/Search/RecentsPanel.swift:spring:response:73:46", default: 0.4), dampingFraction: PurlTune.value("Components/Search/RecentsPanel.swift:spring:dampingFraction:73:155", default: 0.85)).delay(0.05), value: isVisible)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(isVisible ? 1.0 : 0.9)
        }
        .ignoresSafeArea()
    }

    // MARK: - Row

    private func conversationRow(_ conversation: RecentConversation) -> some View {
        HStack(spacing: GravitySpacing.space12) {
            thumbnailStack(urls: conversation.thumbnailURLs)

            VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                Text(conversation.title ?? "Untitled")
                    .gravityTextStyle(GravityTypography.bodySmall)
                    .foregroundStyle(PurlTune.token("Components/Search/RecentsPanel.swift:foregroundStyle:_:89:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .lineLimit(1)

                Text(conversation.relativeDate)
                    .gravityTextStyle(GravityTypography.captionBold)
                    .foregroundStyle(PurlTune.token("Components/Search/RecentsPanel.swift:foregroundStyle:_:94:38", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
            }
        }
        .frame(maxWidth: PurlTune.value("Components/Search/RecentsPanel.swift:frame:maxWidth:97:26", default: 275), alignment: .leading)
        .padding(.vertical, PurlTune.token("Components/Search/RecentsPanel.swift:padding:_:98:29", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
        .contentShape(Rectangle())
    }

    // MARK: - Thumbnail Stack

    private func thumbnailStack(urls: [URL]) -> some View {
        HStack(spacing: -34) {
            if let first = urls.first {
                thumbnailCard(url: first)
                    .rotationEffect(.degrees(-3))
                    .zIndex(1)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(PurlTune.token("Components/Search/RecentsPanel.swift:fill:_:112:27", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                    .frame(width: PurlTune.value("Components/Search/RecentsPanel.swift:frame:width:113:35", default: 40), height: PurlTune.value("Components/Search/RecentsPanel.swift:frame:height:113:131", default: 40))
                    .overlay(
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(PurlTune.token("Components/Search/RecentsPanel.swift:foregroundStyle:_:117:46", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
                    )
            }

            if urls.count >= 2 {
                thumbnailCard(url: urls[1])
                    .rotationEffect(.degrees(4))
                    .zIndex(0)
            }
        }
    }

    private func thumbnailCard(url: URL) -> some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            RoundedRectangle(cornerRadius: 12)
                .fill(PurlTune.token("Components/Search/RecentsPanel.swift:fill:_:136:23", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
        }
        .frame(width: PurlTune.value("Components/Search/RecentsPanel.swift:frame:width:138:23", default: 40), height: PurlTune.value("Components/Search/RecentsPanel.swift:frame:height:138:119", default: 40))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(PurlTune.value("Components/Search/RecentsPanel.swift:opacity:_:146:43", default: 0.04)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(GravityColors.borderImage, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.small)
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: GravitySpacing.space12) {
            Image(systemName: "clock")
                .font(.system(size: 32))
                .foregroundStyle(PurlTune.token("Components/Search/RecentsPanel.swift:foregroundStyle:_:161:34", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
            Text("No recent conversations")
                .gravityTextStyle(GravityTypography.bodySmall)
                .foregroundStyle(PurlTune.token("Components/Search/RecentsPanel.swift:foregroundStyle:_:164:34", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, PurlTune.value("Components/Search/RecentsPanel.swift:padding:_:167:27", default: 100))
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<10, id: \.self) { i in
                HStack(spacing: GravitySpacing.space12) {
                    HStack(spacing: -34) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(PurlTune.value("Components/Search/RecentsPanel.swift:opacity:_:178:55", default: 0.06)))
                            .frame(width: PurlTune.value("Components/Search/RecentsPanel.swift:frame:width:179:43", default: 40), height: PurlTune.value("Components/Search/RecentsPanel.swift:frame:height:179:139", default: 40))
                            .rotationEffect(.degrees(-3))
                            .zIndex(1)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(PurlTune.value("Components/Search/RecentsPanel.swift:opacity:_:183:55", default: 0.04)))
                            .frame(width: PurlTune.value("Components/Search/RecentsPanel.swift:frame:width:184:43", default: 40), height: PurlTune.value("Components/Search/RecentsPanel.swift:frame:height:184:139", default: 40))
                            .rotationEffect(.degrees(4))
                            .zIndex(0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(PurlTune.token("Components/Search/RecentsPanel.swift:fill:_:191:35", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                            .frame(width: CGFloat([170, 130, 190, 150, 180, 140, 160, 120, 175, 145][i % 10]), height: PurlTune.value("Components/Search/RecentsPanel.swift:frame:height:192:120", default: 14))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(PurlTune.token("Components/Search/RecentsPanel.swift:fill:_:194:35", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                            .frame(width: PurlTune.value("Components/Search/RecentsPanel.swift:frame:width:195:43", default: 50), height: PurlTune.value("Components/Search/RecentsPanel.swift:frame:height:195:139", default: 10))
                    }
                }
                .frame(maxWidth: PurlTune.value("Components/Search/RecentsPanel.swift:frame:maxWidth:198:34", default: 275), alignment: .leading)
                .padding(.vertical, PurlTune.token("Components/Search/RecentsPanel.swift:padding:_:199:37", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
            }
        }
        .padding(.horizontal, GravitySpacing.screenMargin)
        .padding(.top, PurlTune.value("Components/Search/RecentsPanel.swift:padding:_:203:24", default: 100))
        .pulse()
    }
}

#Preview("With history") {
    RecentsPanel(
        conversations: RecentConversation.previews,
        isLoading: false,
        isVisible: true
    )
    .background(PurlTune.token("Components/Search/RecentsPanel.swift:background:_:214:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}

#Preview("Empty / loading") {
    RecentsPanel(
        conversations: [],
        isLoading: true,
        isVisible: true
    )
    .background(PurlTune.token("Components/Search/RecentsPanel.swift:background:_:223:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
