import Gravity
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct ShopCollectionListResizeTests {
    @Test(arguments: [ShopCollectionListRowReuseKind.HostingMode.configuration, .persistentHostingController])
    func widthChangesRemeasureRowsWithoutReplacingTheirStateOrLayout(
        mode: ShopCollectionListRowReuseKind.HostingMode
    ) async throws {
        let capture = CollectionResizeCapture()
        let host = UIHostingController(rootView:
            ShopCollectionList(
                items: [CollectionResizeItem(id: "row", mode: mode)],
                layout: .vertical(estimatedRowHeight: 100),
                contentInsetAdjustmentBehavior: .never,
                row: { _ in CollectionResizeRow(capture: capture) }
            )
        )
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1_200, height: 1_000))
        let parent = UIViewController()
        window.rootViewController = parent
        parent.addChild(host)
        parent.view.addSubview(host.view)
        host.didMove(toParent: parent)
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
            window.rootViewController = nil
        }

        var originalCollection: UICollectionView?
        var originalLayout: UICollectionViewLayout?
        var heights: [CGFloat: CGFloat] = [:]
        let widths: [CGFloat] = [402, 474, 904, 300, 402]
        for width in widths {
            host.view.frame = CGRect(x: 0, y: 0, width: width, height: 696)
            host.view.setNeedsLayout()
            for _ in 0..<20 {
                host.view.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(10))
            }
            let collection = try #require(findCollection(in: host.view))
            let cell = try #require(collection.cellForItem(at: IndexPath(item: 0, section: 0)))
            #expect(abs(cell.bounds.width - width) < 1)
            #expect(collection.numberOfItems(inSection: 0) == 1)
            #expect(capture.lifetimes.count == 1)
            heights[width] = cell.bounds.height
            if let originalCollection, let originalLayout {
                #expect(collection === originalCollection)
                #expect(collection.collectionViewLayout === originalLayout)
                #expect(capture.draft?.wrappedValue == "edited")
            } else {
                originalCollection = collection
                originalLayout = collection.collectionViewLayout
                let draft = try #require(capture.draft)
                draft.wrappedValue = "edited"
            }
        }
        let narrowHeight = try #require(heights[300])
        let wideHeight = try #require(heights[904])
        #expect(narrowHeight > wideHeight)
    }

    private func findCollection(in view: UIView) -> UICollectionView? {
        if let collection = view as? UICollectionView { return collection }
        for child in view.subviews {
            if let collection = findCollection(in: child) { return collection }
        }
        return nil
    }
}

private struct CollectionResizeItem: Identifiable, Hashable, Sendable, ShopCollectionListReusableItem {
    let id: String
    let mode: ShopCollectionListRowReuseKind.HostingMode
    var collectionListReuseKind: ShopCollectionListRowReuseKind {
        ShopCollectionListRowReuseKind("resize-row", hostingMode: mode)
    }
}

@MainActor
private final class CollectionResizeCapture {
    var lifetimes = Set<UUID>()
    var draft: Binding<String>?
}

private struct CollectionResizeRow: View {
    let capture: CollectionResizeCapture
    @State private var lifetime = UUID()
    @State private var draft = "initial"

    var body: some View {
        ShopText(
            draft + " " + String(repeating: "Text that must wrap when its actual row becomes narrower. ", count: 12),
            style: .bodyLarge
        )
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            capture.lifetimes.insert(lifetime)
            capture.draft = $draft
        }
    }
}
