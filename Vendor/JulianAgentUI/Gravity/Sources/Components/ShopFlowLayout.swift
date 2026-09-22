import SwiftUI

func shopFlowLayoutNeedsBoundedMeasurement(idealWidth: CGFloat, maxWidth: CGFloat) -> Bool {
    guard maxWidth > 0, maxWidth < .infinity else { return false }
    return idealWidth >= maxWidth
}

public struct ShopFlowLayout: Layout {
    private let horizontalSpacing: CGFloat
    private let verticalSpacing: CGFloat

    public init(spacing: CGFloat) {
        horizontalSpacing = spacing
        verticalSpacing = spacing
    }

    public init(horizontalSpacing: CGFloat, verticalSpacing: CGFloat) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)

        let rowWidths: [CGFloat] = rows.map { row in
            let itemWidth = row.reduce(CGFloat.zero) { $0 + $1.size.width }
            let spacingWidth = horizontalSpacing * CGFloat(max(0, row.count - 1))
            return itemWidth + spacingWidth
        }
        let width = rowWidths.max() ?? 0

        let height = rows.map { row in
            row.map(\.size.height).max() ?? 0
        }.reduce(0, +) + verticalSpacing * CGFloat(max(0, rows.count - 1))

        return CGSize(width: min(width, maxWidth), height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map(\.size.height).max() ?? 0
            for item in row {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + horizontalSpacing
            }
            y += rowHeight + verticalSpacing
        }
    }

    private struct Item {
        let subview: LayoutSubview
        let size: CGSize
    }

    private func measure(_ subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let idealSize = subview.sizeThatFits(.unspecified)
        guard shopFlowLayoutNeedsBoundedMeasurement(idealWidth: idealSize.width, maxWidth: maxWidth) else {
            return idealSize
        }
        return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [[Item]] {
        var rows: [[Item]] = [[]]
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = measure(subview, maxWidth: maxWidth)
            let needsNewRow = currentWidth + size.width > maxWidth && rows[rows.count - 1].isEmpty == false

            if needsNewRow {
                rows.append([])
                currentWidth = 0
            }

            rows[rows.count - 1].append(Item(subview: subview, size: size))
            currentWidth += size.width + horizontalSpacing
        }

        return rows
    }
}
