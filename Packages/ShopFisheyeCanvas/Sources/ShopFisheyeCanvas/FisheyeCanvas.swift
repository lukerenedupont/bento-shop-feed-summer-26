import SwiftUI

/// Fisheye grid extracted from shopify-playground/shop-week-baskets,
/// AddProductsView.swift, commit 16f2078037ee6325bb5dc2a5246919a09c7aee8e.
/// See the package README for provenance and the extraction's changes.
///
/// A finite assortment repeats across an infinite procedural grid. The caller
/// owns item identity, tile rendering/selection and the retained pan position.
public struct FisheyeCanvas<Item: Identifiable, Tile: View>: View {
    private let items: [Item]
    @Binding private var position: CGPoint
    private let isInteractive: Bool
    private let isActive: Bool
    private let tile: (Item) -> Tile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGPoint = .zero
    @State private var dragStart: CGPoint = .zero
    @State private var dragging = false

    // Upstream geometry and projection constants.
    private let tileSize: CGFloat = 140
    private let tileGap: CGFloat = 10
    private let buffer = 2
    private let maxAngle: Double = 16
    private let perspectiveAmount: CGFloat = 0.3
    private let edgeScale: CGFloat = 0.82
    private var stride: CGFloat { tileSize + tileGap }

    public init(
        items: [Item], position: Binding<CGPoint>,
        isInteractive: Bool = true, isActive: Bool = true,
        @ViewBuilder tile: @escaping (Item) -> Tile
    ) {
        self.items = items
        self._position = position
        self.isInteractive = isInteractive
        self.isActive = isActive
        self.tile = tile
    }

    public var body: some View {
        GeometryReader { screen in
            ZStack {
                Color.clear
                if !items.isEmpty, screen.size.width > 0, screen.size.height > 0 {
                    grid(in: screen.size)
                }
            }
            .frame(width: screen.size.width, height: screen.size.height)
            .contentShape(Rectangle())
            .clipped()
            .highPriorityGesture(pan, including: isInteractive && isActive ? .all : .subviews)
        }
        .allowsHitTesting(isActive)
        .onAppear { restore(position) }
        .onChange(of: position) { _, value in
            if !dragging, value != offset { restore(value) }
        }
        .onChange(of: isActive) { _, active in
            if !active { finishInteraction() }
        }
        .onChange(of: isInteractive) { _, interactive in
            if !interactive { finishInteraction() }
        }
        .onDisappear { finishInteraction() }
        .accessibilityElement(children: .contain)
        .accessibilityHidden(!isActive)
        .accessibilityIdentifier("fisheye.canvas")
    }

    private func grid(in size: CGSize) -> some View {
        let minCol = Int(floor((-offset.x - CGFloat(buffer) * stride) / stride))
        let maxCol = Int(ceil((-offset.x + size.width + CGFloat(buffer) * stride) / stride))
        let minRow = Int(floor((-offset.y - CGFloat(buffer) * stride) / stride))
        let maxRow = Int(ceil((-offset.y + size.height + CGFloat(buffer) * stride) / stride))
        return ZStack {
            ForEach(Array(minRow...maxRow), id: \.self) { row in
                ForEach(Array(minCol...maxCol), id: \.self) { col in
                    projectedTile(col: col, row: row, in: size)
                }
            }
        }
    }

    private func projectedTile(col: Int, row: Int, in size: CGSize) -> some View {
        // .magnitude retains upstream's absolute hash without abs(Int.min).
        let hash = (col &* 73856093 ^ row &* 19349669).magnitude
        let item = items[Int(hash % UInt(items.count))]
        let x = CGFloat(col) * stride + stride / 2 + offset.x
        let y = CGFloat(row) * stride + stride / 2 + offset.y
        let nx = (x - size.width / 2) / (size.width / 2)
        let ny = (y - size.height / 2) / (size.height / 2)
        let distance = min(1.5, sqrt(nx * nx + ny * ny))
        let axisX = -ny
        let axisY = nx
        let length = sqrt(axisX * axisX + axisY * axisY)
        let scale = 1 - (1 - edgeScale) * distance * distance
        return tile(item)
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(reduceMotion ? 1 : scale)
            .rotation3DEffect(
                .degrees(!reduceMotion && length > 0.01 ? Double(distance) * maxAngle : 0),
                axis: (x: length > 0.01 ? axisX / length : 0,
                       y: length > 0.01 ? axisY / length : 0, z: 0),
                perspective: perspectiveAmount
            )
            .position(x: x, y: y)
            .accessibilityHidden(x + tileSize / 2 < 0 || x - tileSize / 2 > size.width
                || y + tileSize / 2 < 0 || y - tileSize / 2 > size.height)
            .accessibilityIdentifier("fisheye.tile.\(col).\(row)")
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                if !dragging { dragStart = offset; dragging = true }
                offset = CGPoint(x: dragStart.x + value.translation.width,
                                 y: dragStart.y + value.translation.height)
            }
            .onEnded { value in
                // Preserve upstream's velocity projection + spring release.
                let decay: CGFloat = reduceMotion ? 0 : 0.15
                let target = CGPoint(x: offset.x + value.velocity.width * decay,
                                     y: offset.y + value.velocity.height * decay)
                dragging = false
                position = target
                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.86)) {
                    offset = target
                }
                dragStart = target
            }
    }

    private func restore(_ value: CGPoint) {
        offset = value
        dragStart = value
    }

    private func finishInteraction() {
        // No timer/display-link to keep running after the card leaves. Commit
        // an interrupted drag, too; the host can restore it above lazy cells.
        if dragging { position = offset }
        dragging = false
        dragStart = offset
    }
}
