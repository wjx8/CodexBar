import AppKit

final class CompactHUDPanel: NSPanel {
    private let defaultSize = NSSize(width: 238, height: 34)
    private var hasPositionedInitialFrame = false

    init(contentViewController: NSViewController) {
        super.init(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.contentViewController = contentViewController
        self.backgroundColor = .clear
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.hasShadow = true
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = true
        self.isOpaque = false
        self.isReleasedWhenClosed = false
        self.level = .statusBar
        self.titleVisibility = .hidden
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    func orderFrontPinned() {
        positionInitialFrameIfNeeded()
        orderFrontRegardless()
    }

    private func positionInitialFrameIfNeeded() {
        guard !hasPositionedInitialFrame else {
            return
        }

        let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: screenFrame.midX - defaultSize.width / 2,
            y: screenFrame.maxY - defaultSize.height - 68
        )
        setFrame(NSRect(origin: origin, size: defaultSize), display: false)
        hasPositionedInitialFrame = true
    }
}
