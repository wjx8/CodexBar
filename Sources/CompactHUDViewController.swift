import AppKit

final class CompactHUDViewController: NSViewController, NSTouchBarDelegate, SpeechInputControllerDelegate {
    private enum TouchBarIdentifiers {
        static let touchBar = NSTouchBar.CustomizationIdentifier("com.wangjiaxuan666.CodexBar.touchBar")
        static let limits = NSTouchBarItem.Identifier("com.wangjiaxuan666.CodexBar.limits")
    }

    private let hudView: CompactQuotaHUDView
    private let speechInputController = SpeechInputController()
    private lazy var touchBarView = TouchBarRateLimitsView(
        voiceTarget: self,
        toggleVoiceAction: #selector(toggleVoiceInput)
    )
    private var currentState = RateLimitDisplayState.initial
    private var presentedTouchBar: NSTouchBar?
    private let onRefresh: () -> Void
    private let onQuit: () -> Void

    init(
        initialAppearance: HUDAppearance,
        onRefresh: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        contextMenuProvider: @escaping () -> NSMenu
    ) {
        self.onRefresh = onRefresh
        self.onQuit = onQuit
        self.hudView = CompactQuotaHUDView(
            initialAppearance: initialAppearance,
            onRefresh: onRefresh,
            onQuit: onQuit,
            contextMenuProvider: contextMenuProvider
        )
        super.init(nibName: nil, bundle: nil)
        self.hudView.touchBarProvider = self
        self.speechInputController.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = hudView
        view.frame = NSRect(x: 0, y: 0, width: 238, height: 34)
        update(with: currentState)
    }

    override func makeTouchBar() -> NSTouchBar? {
        makeQuotaTouchBar()
    }

    func makeQuotaTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.customizationIdentifier = TouchBarIdentifiers.touchBar
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [TouchBarIdentifiers.limits]
        return touchBar
    }

    var isTouchBarVisible: Bool {
        presentedTouchBar != nil
    }

    @discardableResult
    func showSystemTouchBar() -> Bool {
        if presentedTouchBar != nil {
            return true
        }

        let touchBar = makeQuotaTouchBar()
        touchBarView.update(with: currentState)
        guard SystemModalTouchBar.present(touchBar) else {
            return false
        }

        presentedTouchBar = touchBar
        return true
    }

    func hideSystemTouchBar() {
        guard let touchBar = presentedTouchBar else {
            return
        }

        SystemModalTouchBar.dismiss(touchBar)
        presentedTouchBar = nil
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case TouchBarIdentifiers.limits:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = touchBarView
            return item
        default:
            return nil
        }
    }

    func update(with state: RateLimitDisplayState) {
        currentState = state
        touchBarView.update(with: state)

        guard isViewLoaded else {
            return
        }

        hudView.update(with: state)
    }

    func updateAppearance(_ appearance: HUDAppearance) {
        hudView.updateAppearance(appearance)
    }

    func speechInputController(_ controller: SpeechInputController, didChange state: SpeechInputController.State) {
        touchBarView.updateVoice(state: state, transcript: controller.transcript)
    }

    func speechInputController(_ controller: SpeechInputController, didUpdateTranscript transcript: String) {
        touchBarView.updateVoice(state: controller.state, transcript: transcript)
    }

    @objc private func toggleVoiceInput() {
        speechInputController.toggleRecording()
    }

}

final class CompactQuotaHUDView: NSView {
    weak var touchBarProvider: CompactHUDViewController?

    private let firstItem = CompactQuotaItemView()
    private let secondItem = CompactQuotaItemView()
    private let refreshButton = CompactIconButton(
        symbolName: "arrow.clockwise",
        accessibilityLabel: "刷新额度"
    )
    private let quitButton = CompactIconButton(
        symbolName: "xmark",
        accessibilityLabel: "退出额度条"
    )
    private let onRefresh: () -> Void
    private let onQuit: () -> Void
    private let contextMenuProvider: () -> NSMenu
    private var hudAppearance: HUDAppearance
    private var widthConstraint: NSLayoutConstraint?
    private var contentStack: NSStackView?

    init(
        initialAppearance: HUDAppearance,
        onRefresh: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        contextMenuProvider: @escaping () -> NSMenu
    ) {
        self.onRefresh = onRefresh
        self.onQuit = onQuit
        self.contextMenuProvider = contextMenuProvider
        self.hudAppearance = initialAppearance
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        activateTouchBar()
        super.mouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        contextMenuProvider()
    }

    override func makeTouchBar() -> NSTouchBar? {
        touchBarProvider?.makeQuotaTouchBar()
    }

    func activateTouchBar() {
        window?.makeFirstResponder(self)
        touchBar = nil
        touchBar = makeTouchBar()
    }

    func update(with state: RateLimitDisplayState) {
        let hasError = state.errorMessage != nil && state.fiveHour == nil && state.weekly == nil

        if let fiveHour = state.fiveHour {
            firstItem.update(with: fiveHour, title: "5h")
            if let weekly = state.weekly {
                secondItem.update(with: weekly, title: "7d")
                setMetricCount(2)
            } else {
                setMetricCount(1)
            }
        } else if let resetCredits = state.resetCredits, resetCredits.availableCount > 0 {
            firstItem.update(with: resetCredits)
            if let weekly = state.weekly {
                secondItem.update(with: weekly, title: "7d")
                setMetricCount(2)
            } else {
                setMetricCount(1)
            }
        } else if let weekly = state.weekly {
            firstItem.update(with: weekly, title: "7d")
            setMetricCount(1)
        } else {
            firstItem.updatePlaceholder(title: "5h", hasError: hasError)
            secondItem.updatePlaceholder(title: "7d", hasError: hasError)
            setMetricCount(2)
        }

        toolTip = state.statusText
    }

    func updateAppearance(_ appearance: HUDAppearance) {
        self.hudAppearance = appearance
        layer?.backgroundColor = appearance.backgroundColor.cgColor
        contentStack?.alphaValue = appearance.contentOpacity
    }

    private func configure() {
        wantsLayer = true
        layer?.backgroundColor = hudAppearance.backgroundColor.cgColor
        layer?.cornerRadius = 17
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = false

        refreshButton.target = self
        refreshButton.action = #selector(refreshClicked)
        quitButton.target = self
        quitButton.action = #selector(quitClicked)

        let stack = NSStackView(views: [firstItem, secondItem, refreshButton, quitButton])
        contentStack = stack
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = 8
        stack.alphaValue = hudAppearance.contentOpacity

        addSubview(stack)

        let widthConstraint = widthAnchor.constraint(equalToConstant: 238)
        self.widthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            widthConstraint,
            heightAnchor.constraint(equalToConstant: 34),
            firstItem.widthAnchor.constraint(equalToConstant: 70),
            secondItem.widthAnchor.constraint(equalToConstant: 70),
            refreshButton.widthAnchor.constraint(equalToConstant: 20),
            refreshButton.heightAnchor.constraint(equalToConstant: 20),
            quitButton.widthAnchor.constraint(equalToConstant: 20),
            quitButton.heightAnchor.constraint(equalToConstant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func setMetricCount(_ count: Int) {
        let showsSecondItem = count > 1
        secondItem.isHidden = !showsSecondItem

        let targetWidth: CGFloat = showsSecondItem ? 238 : 160
        guard widthConstraint?.constant != targetWidth else {
            return
        }

        widthConstraint?.constant = targetWidth

        guard let window else {
            frame.size.width = targetWidth
            return
        }

        let previousMidX = window.frame.midX
        window.setContentSize(NSSize(width: targetWidth, height: 34))
        var origin = window.frame.origin
        origin.x = previousMidX - window.frame.width / 2
        window.setFrameOrigin(origin)
    }

    @objc private func refreshClicked() {
        onRefresh()
    }

    @objc private func quitClicked() {
        onQuit()
    }
}

private final class CompactQuotaItemView: NSView {
    private let dotView = CompactStatusDotView()
    private let label = NSTextField(labelWithString: "-- --")

    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with meter: LimitMeter, title: String) {
        let remaining = Int(meter.remainingPercent.rounded())
        label.stringValue = "\(title) \(remaining)%"
        label.textColor = .white
        dotView.color = color(for: remaining)
    }

    func update(with resetCredits: ResetCreditSummary) {
        label.stringValue = resetCredits.compactText
        label.textColor = .white
        dotView.color = .systemTeal
    }

    func updatePlaceholder(title: String, hasError: Bool) {
        label.stringValue = "\(title) --"
        label.textColor = NSColor.white.withAlphaComponent(0.62)
        dotView.color = hasError ? NSColor.systemRed : NSColor.white.withAlphaComponent(0.28)
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        label.textColor = .white
        label.lineBreakMode = .byClipping
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = NSStackView(views: [dotView, label])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6

        addSubview(stack)

        NSLayoutConstraint.activate([
            dotView.widthAnchor.constraint(equalToConstant: 8),
            dotView.heightAnchor.constraint(equalToConstant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func color(for remaining: Int) -> NSColor {
        if remaining <= 20 {
            return NSColor.systemRed
        }
        if remaining <= 45 {
            return NSColor.systemYellow
        }
        return NSColor.systemGreen
    }
}

private final class CompactIconButton: NSButton {
    init(symbolName: String, accessibilityLabel: String) {
        super.init(frame: .zero)

        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel)
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        contentTintColor = NSColor.white.withAlphaComponent(0.88)
        toolTip = accessibilityLabel
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class CompactStatusDotView: NSView {
    var color = NSColor.systemGreen {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        color.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()
    }
}
