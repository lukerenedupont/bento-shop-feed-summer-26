import SwiftUI

/// Reveals text with a natural typing rhythm — variable speed, word chunking,
/// and pauses at punctuation to mimic real human/AI output.
struct TypewriterText: View {
    let fullText: String
    var baseSpeed: Double = 0.018
    var style: GravityTextStyle = GravityTypography.bodyLarge
    var onComplete: (() -> Void)? = nil

    @State private var visibleCount: Int = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var didComplete: Bool = false

    private var displayedText: String {
        String(fullText.prefix(visibleCount))
    }

    var body: some View {
        Text(LocalizedStringKey(displayedText))
            .gravityTextStyle(style)
            .foregroundStyle(PurlTune.token("Components/Search/Agent/TypewriterText.swift:foregroundStyle:_:22:30", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                startTyping()
            }
            .onDisappear {
                animationTask?.cancel()
            }
            .onChange(of: fullText) { _, _ in
                startTyping()
            }
    }

    private func startTyping() {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            let chars = Array(fullText)
            while visibleCount < chars.count {
                guard !Task.isCancelled else { break }

                let char = chars[visibleCount]
                visibleCount += 1

                // Burst forward 2-4 chars at a time for word interiors
                if char.isLetter && visibleCount < chars.count && chars[visibleCount].isLetter {
                    let burst = Int.random(in: 1...3)
                    let end = min(visibleCount + burst, chars.count)
                    visibleCount = end
                }

                // Natural delays based on character type
                let delay = delayFor(char)
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            }

            if !didComplete {
                didComplete = true
                onComplete?()
            }
        }
    }

    private func delayFor(_ char: Character) -> Double {
        switch char {
        case ".", "!", "?":
            // Sentence-ending pause
            return baseSpeed * Double.random(in: 12...18)
        case ",", ";", ":":
            // Clause pause
            return baseSpeed * Double.random(in: 5...8)
        case " ":
            // Word boundary — slight variation
            return baseSpeed * Double.random(in: 0.8...2.0)
        case "\n":
            // Line break pause
            return baseSpeed * Double.random(in: 8...12)
        default:
            // Regular character with slight jitter
            return baseSpeed * Double.random(in: 0.4...1.2)
        }
    }
}

#Preview {
    TypewriterText(
        fullText: "Here are some great options I found across a few of your favorite stores — all under $120, in stock, and ship within two days.",
        style: GravityTypography.bodyLarge
    )
    .padding()
    .background(PurlTune.token("Components/Search/Agent/TypewriterText.swift:background:_:91:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
