import SwiftUI

/// An illustrative perspective room, not a measured room or generated installation.
/// Both invitation and editor use exactly the selected products' reviewed cutouts.
struct ReadingCornerRoomScene: View {
    let pieces: [ReadingCornerPiece]
    var roomImage: UIImage? = nil
    var interactive = false

    private var layeredPieces: [ReadingCornerPiece] {
        pieces.sorted { layer($0) < layer($1) }
    }
    private func layer(_ piece: ReadingCornerPiece) -> Int {
        if piece.role == .light { return piece.handle == "floor-lamp-1" ? 0 : 3 }
        return piece.role == .chair ? 1 : 2
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let roomImage {
                    Image(uiImage: roomImage).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                    room
                }
                ForEach(layeredPieces) { piece in
                    RoomCutout(piece: piece, bounds: geometry.size, interactive: interactive)
                }
            }
        }
    }
    private var room: some View {
        Canvas { context, size in
            func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
                var path = Path()
                path.addLines(points.map { CGPoint(x: $0.0 * size.width, y: $0.1 * size.height) })
                path.closeSubpath(); return path
            }
            let left = polygon([(0,0), (0.64,0), (0.64,0.52), (0,0.71)])
            let right = polygon([(0.64,0), (1,0), (1,0.66), (0.64,0.52)])
            let floor = polygon([(0,0.71), (0.64,0.52), (1,0.66), (1,1), (0,1)])
            context.fill(left, with: .linearGradient(Gradient(colors: [Color(hex: "#E5DECE"), Color(hex: "#CDC2AE")]),
                                                     startPoint: .zero, endPoint: CGPoint(x: size.width * 0.64, y: size.height * 0.55)))
            context.fill(right, with: .linearGradient(Gradient(colors: [Color(hex: "#B7AB95"), Color(hex: "#D4CAB7")]),
                                                      startPoint: CGPoint(x: size.width * 0.64, y: 0), endPoint: CGPoint(x: size.width, y: 0)))
            context.fill(floor, with: .linearGradient(Gradient(colors: [Color(hex: "#AD9980"), Color(hex: "#C8B59B")]),
                                                      startPoint: CGPoint(x: 0, y: size.height * 0.5), endPoint: CGPoint(x: 0, y: size.height)))
            let light = polygon([(0.05,0.08), (0.33,0.03), (0.33,0.4), (0.05,0.49)])
            context.fill(light, with: .color(.white.opacity(0.13)))
            var trim = Path()
            trim.move(to: CGPoint(x: 0, y: size.height * 0.70))
            trim.addLine(to: CGPoint(x: size.width * 0.64, y: size.height * 0.51))
            trim.addLine(to: CGPoint(x: size.width, y: size.height * 0.65))
            context.stroke(trim, with: .color(.white.opacity(0.35)), lineWidth: 3)
            context.clip(to: floor)
            for line in 0..<9 {
                var plank = Path()
                plank.move(to: CGPoint(x: size.width * 0.64, y: size.height * 0.30))
                plank.addLine(to: CGPoint(x: CGFloat(line - 3) * size.width / 3, y: size.height))
                context.stroke(plank, with: .color(.black.opacity(0.035)), lineWidth: 1)
            }
            let rug = polygon([(0.08,0.86), (0.54,0.66), (0.94,0.89), (0.53,1.08)])
            context.fill(rug, with: .color(Color(hex: "#C5BAA5").opacity(0.75)))
        }.accessibilityHidden(true)
    }
}

private struct RoomCutout: View {
    let piece: ReadingCornerPiece
    let bounds: CGSize
    let interactive: Bool
    @State private var offset = CGSize.zero
    @State private var drag = CGSize.zero
    @State private var isMoving = false

    private var pose: (x: CGFloat, base: CGFloat, width: CGFloat, height: CGFloat) {
        switch piece.role {
        case .chair: return (0.31, 0.91, 0.43, 0.48)
        case .table: return (0.72, 0.92, 0.29, 0.29)
        case .light:
            return piece.handle == "floor-lamp-1" ? (0.57, 0.83, 0.35, 0.68) : (0.72, 0.64, 0.19, 0.23)
        }
    }
    private var tileSize: CGSize { CGSize(width: bounds.width * pose.width, height: bounds.height * pose.height) }
    private func center(_ displacement: CGSize) -> CGPoint {
        CGPoint(x: min(max(bounds.width * pose.x + displacement.width, tileSize.width / 2), bounds.width - tileSize.width / 2),
                y: min(max(bounds.height * pose.base - tileSize.height / 2 + displacement.height, tileSize.height / 2), bounds.height - tileSize.height / 2))
    }
    var body: some View {
        ZStack(alignment: .bottom) { ReadingCornerCutout(piece: piece) }
            .frame(width: tileSize.width, height: tileSize.height, alignment: .bottom)
            .overlay {
                if interactive {
                    ReadingCornerGrabSurface(onTap: {}, onMove: { isMoving = true; drag = $0 },
                                             onEnd: { translation, _ in
                                                 shift(x: translation.width, y: translation.height)
                                                 drag = .zero; isMoving = false
                                             }, onCancel: { drag = .zero; isMoving = false }, freeDragImmediately: true)
                        .accessibilityHidden(true)
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 4, x: 5, y: 5)
            .contentShape(Rectangle())
            .position(center(CGSize(width: offset.width + drag.width, height: offset.height + drag.height)))
            .allowsHitTesting(interactive)
            .preference(key: WorldDragOwnership.self, value: isMoving)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(piece.product.title)
            .accessibilityIdentifier("corner.room-piece.\(piece.role.rawValue)")
            .accessibilityHidden(!interactive)
            .accessibilityAction(named: "Move left") { shift(x: -20, y: 0) }
            .accessibilityAction(named: "Move right") { shift(x: 20, y: 0) }
            .accessibilityAction(named: "Move up") { shift(x: 0, y: -20) }
            .accessibilityAction(named: "Move down") { shift(x: 0, y: 20) }
    }
    private func shift(x: CGFloat, y: CGFloat) {
        let next = center(CGSize(width: offset.width + x, height: offset.height + y))
        offset = CGSize(width: next.x - bounds.width * pose.x,
                        height: next.y - (bounds.height * pose.base - tileSize.height / 2))
    }
}
