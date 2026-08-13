import SwiftUI

/// Skeleton placeholder for a product shelf while loading.
struct AgentProductShelfSkeleton: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            // Title + subtitle placeholders
            VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(PurlTune.token("Components/Search/Agent/AgentProductShelfSkeleton.swift:fill:_:10:27", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                    .frame(width: PurlTune.value("Components/Search/Agent/AgentProductShelfSkeleton.swift:frame:width:11:35", default: 160), height: PurlTune.value("Components/Search/Agent/AgentProductShelfSkeleton.swift:frame:height:11:150", default: 16))
                RoundedRectangle(cornerRadius: 4)
                    .fill(PurlTune.token("Components/Search/Agent/AgentProductShelfSkeleton.swift:fill:_:13:27", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                    .frame(width: PurlTune.value("Components/Search/Agent/AgentProductShelfSkeleton.swift:frame:width:14:35", default: 100), height: PurlTune.value("Components/Search/Agent/AgentProductShelfSkeleton.swift:frame:height:14:150", default: 12))
            }
            .padding(.horizontal, GravitySpacing.screenMargin)

            // Product card placeholders
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(PurlTune.token("Components/Search/Agent/AgentProductShelfSkeleton.swift:fill:_:24:39", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                                .aspectRatio(1, contentMode: .fit)
                                .gravityShadow(GravityShadows.small)

                            VStack(alignment: .leading, spacing: 2) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(PurlTune.token("Components/Search/Agent/AgentProductShelfSkeleton.swift:fill:_:30:43", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                                    .frame(width: PurlTune.value("Components/Search/Agent/AgentProductShelfSkeleton.swift:frame:width:31:51", default: 70), height: PurlTune.value("Components/Search/Agent/AgentProductShelfSkeleton.swift:frame:height:31:165", default: 10))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(PurlTune.token("Components/Search/Agent/AgentProductShelfSkeleton.swift:fill:_:33:43", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                                    .frame(width: PurlTune.value("Components/Search/Agent/AgentProductShelfSkeleton.swift:frame:width:34:51", default: 100), height: PurlTune.value("Components/Search/Agent/AgentProductShelfSkeleton.swift:frame:height:34:166", default: 12))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(PurlTune.token("Components/Search/Agent/AgentProductShelfSkeleton.swift:fill:_:36:43", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                                    .frame(width: PurlTune.value("Components/Search/Agent/AgentProductShelfSkeleton.swift:frame:width:37:51", default: 45), height: PurlTune.value("Components/Search/Agent/AgentProductShelfSkeleton.swift:frame:height:37:165", default: 10))
                            }
                            .padding(.horizontal, PurlTune.token("Components/Search/Agent/AgentProductShelfSkeleton.swift:padding:_:39:51", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
                        }
                        .frame(width: PurlTune.value("Components/Search/Agent/AgentProductShelfSkeleton.swift:frame:width:41:39", default: 140))
                    }
                }
                .padding(.horizontal, GravitySpacing.screenMargin)
            }
        }
        .pulse()
    }
}

#Preview {
    AgentProductShelfSkeleton()
        .padding(.vertical)
        .background(PurlTune.token("Components/Search/Agent/AgentProductShelfSkeleton.swift:background:_:54:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
