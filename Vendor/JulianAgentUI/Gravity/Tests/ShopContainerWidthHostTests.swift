import Gravity
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct ShopContainerWidthHostTests {
    @Test
    func localWidthUpdatesWithoutReplacingHostedState() async throws {
        let capture = ContainerWidthCapture()
        let host = MountedContainerWidthHost(capture: capture)
        defer { host.close() }

        let widths: [CGFloat] = [370, 442, 872, 300, 370]
        for width in widths {
            try await host.resize(to: CGSize(width: width, height: 600)) {
                capture.width == width
            }
            #expect(capture.width == width)
            #expect(capture.lifetimes.count == 1)
            #expect(capture.containerSize.width == width)
            #expect(capture.containerSize.height == 120)
        }
    }

    @Test
    func heightOnlyChangesAndRepeatedLayoutDoNotPublishWidth() async throws {
        let capture = ContainerWidthCapture()
        let host = MountedContainerWidthHost(capture: capture)
        defer { host.close() }

        try await host.resize(to: CGSize(width: 370, height: 600)) { capture.width == 370 }
        let publications = capture.widths
        for height in [320.0, 240.0, 600.0, 600.0] {
            try await host.resize(to: CGSize(width: 370, height: height)) { capture.width == 370 }
        }

        #expect(capture.widths == publications)
        #expect(capture.lifetimes.count == 1)
    }

    @Test
    func zeroWidthDoesNotReplaceTheLastUsableWidth() async throws {
        let capture = ContainerWidthCapture()
        let host = MountedContainerWidthHost(capture: capture)
        defer { host.close() }

        try await host.resize(to: CGSize(width: 370, height: 600)) { capture.width == 370 }
        let publications = capture.widths
        try await host.resize(to: CGSize(width: 0, height: 600)) { capture.containerSize.width == 0 }

        #expect(capture.width == 370)
        #expect(capture.widths == publications)
        try await host.resize(to: CGSize(width: 442, height: 600)) { capture.width == 442 }
        #expect(capture.width == 442)
        #expect(capture.lifetimes.count == 1)
    }
}

@MainActor
private final class ContainerWidthCapture {
    var width: CGFloat?
    var widths: [CGFloat] = []
    var containerSize = CGSize.zero
    var lifetimes = Set<UUID>()
}

private struct ContainerWidthProbe: View {
    let width: CGFloat?
    let capture: ContainerWidthCapture
    @State private var lifetime = UUID()

    var body: some View {
        Color.blue
            // Simulate a shelf child that still wants its last measured width on a shrinking pass.
            .frame(width: width, height: 120)
            .onChange(of: width, initial: true) { _, width in
                capture.width = width
                if let width { capture.widths.append(width) }
                capture.lifetimes.insert(lifetime)
            }
    }
}

@MainActor
private final class MountedContainerWidthHost {
    private let window: UIWindow
    private let controller: UIViewController

    init(capture: ContainerWidthCapture) {
        let host = UIHostingController(rootView:
            ShopContainerWidthHost { width in
                ContainerWidthProbe(width: width, capture: capture)
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { capture.containerSize = $0 }
        )
        host.safeAreaRegions = []
        controller = host
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1_200, height: 1_000))
        let parent = UIViewController()
        window.rootViewController = parent
        parent.addChild(host)
        parent.view.addSubview(host.view)
        host.didMove(toParent: parent)
        window.makeKeyAndVisible()
    }

    func resize(to size: CGSize, until isSettled: () -> Bool) async throws {
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.setNeedsLayout()
        // Give SwiftUI a layout turn even when the expected width is unchanged.
        try await Task.sleep(for: .milliseconds(20))
        for _ in 0..<100 {
            controller.view.layoutIfNeeded()
            if isSettled() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Container width did not settle for \(size)")
    }

    func close() {
        window.isHidden = true
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        window.rootViewController = nil
    }
}
