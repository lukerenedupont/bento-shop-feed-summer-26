import SwiftUI

/// A physical pile: the front card follows the hand in two dimensions, then
/// springs home or leaves the pile. A completed throw changes exactly one role.
struct ReadingCornerDeck: View {
    let selection: ReadingCornerSelection
    let role: ReadingCornerPiece.Role
    let onOpen: (ReadingCornerPiece) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag = CGSize.zero
    @State private var isLifted = false
    @State private var isSettling = false
    @State private var tossTask: Task<Void, Never>?
    private var choices: [ReadingCornerPiece] { selection.choices(for: role) }
    private var index: Int {
        choices.firstIndex { $0.id == selection.selected.first(where: { $0.role == role })?.id } ?? 0
    }
    private func step(for offset: CGSize) -> Int {
        let dominant = abs(offset.width) >= abs(offset.height) ? offset.width : offset.height
        return dominant > 0 ? -1 : 1
    }

    var body: some View {
        if !choices.isEmpty {
            ZStack {
                ForEach((1..<min(3, choices.count)).reversed(), id: \.self) { depth in
                    let next = (index + step(for: drag) * depth + choices.count) % choices.count
                    artwork(choices[next], position: nil)
                        .scaleEffect(1 - CGFloat(depth) * 0.035, anchor: .bottom)
                        .rotationEffect(.degrees(Double(depth) * (depth == 1 ? -2 : 2)), anchor: .bottom)
                        .offset(y: CGFloat(depth) * 9)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                ZStack {
                    artwork(choices[index], position: index)
                    ReadingCornerGrabSurface(onTap: { onOpen(choices[index]) }, onMove: move,
                                             onEnd: release, onCancel: cancel)
                        .accessibilityHidden(true)
                }
                    .shadow(color: .black.opacity(isLifted ? 0.3 : 0.1), radius: isLifted ? 24 : 5, y: isLifted ? 18 : 4)
                    .scaleEffect(isLifted && !reduceMotion ? 1.025 : 1)
                    .rotationEffect(.degrees(reduceMotion ? 0 : min(max(drag.width / 22, -16), 16)))
                    .offset(drag)
                    .allowsHitTesting(!isSettling)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(choices[index].product.title), \(ReadingCornerCatalog.money(choices[index].amountCents)), selected \(role.rawValue)")
                    .accessibilityValue("\(index + 1) of \(choices.count)")
                    .accessibilityIdentifier("corner.product.\(role.rawValue)")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onOpen(choices[index]) }
                    .accessibilityAdjustableAction { action in selection.advance(role, by: action == .increment ? 1 : -1) }
            }
            .padding(.horizontal, 8).padding(.bottom, 18)
            .preference(key: WorldDragOwnership.self, value: isLifted || isSettling)
            .onDisappear { tossTask?.cancel(); tossTask = nil; reset() }
        }
    }
    private func move(_ translation: CGSize) {
        guard !isSettling else { return }
        if !isLifted { HapticFeedback.light.fire() }
        isLifted = true
        drag = translation
    }
    private func cancel() {
        guard !isSettling else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { drag = .zero; isLifted = false }
    }
    private func release(_ translation: CGSize, _ velocity: CGSize) {
        guard !isSettling else { return }
        let projected = CGSize(width: translation.width + velocity.width * 0.12,
                               height: translation.height + velocity.height * 0.12)
        let distance = hypot(projected.width, projected.height)
        guard distance > 85 else { cancel(); return }
        let direction = step(for: projected)
        isSettling = true
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.18)) {
            drag = CGSize(width: projected.width / distance * 1000, height: projected.height / distance * 1000)
        }
        tossTask = Task { @MainActor in
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(180)) }
            guard !Task.isCancelled else { return }
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { selection.advance(role, by: direction); reset() }
        }
    }
    private func reset() { drag = .zero; isLifted = false; isSettling = false }

    private func artwork(_ piece: ReadingCornerPiece, position: Int?) -> some View {
        CornerArtwork(url: ShopCanvasLibrary.resolve(piece.product.image), ratio: 0.75)
            .overlay {
                if let position {
                    LinearGradient(stops: [.init(color: .clear, location: 0.52),
                                           .init(color: .black.opacity(0.68), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(position + 1) / \(choices.count)")
                            .font(GravityFont.medium.fixedFont(size: 12))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.black.opacity(0.22), in: Capsule())
                        Spacer()
                        Text(piece.product.title).font(GravityFont.expressiveBold.fixedFont(size: 26))
                            .tracking(-0.4).multilineTextAlignment(.leading)
                        Text(ReadingCornerCatalog.money(piece.amountCents))
                            .font(GravityFont.medium.fixedFont(size: 18))
                    }
                    .foregroundStyle(.white).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24))
    }
}
