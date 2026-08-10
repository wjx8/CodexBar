import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, RateLimitStoreDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: 118)
    private let store = RateLimitStore()
    private let lifecycleMonitor = CodexLifecycleMonitor()
    private var touchBarVisibilityMenuItem: NSMenuItem?
    private lazy var touchBarController = CompactHUDViewController(
        initialAppearance: HUDAppearance.load(),
        onRefresh: { [weak self] in
            self?.refreshQuotaNow()
        },
        onQuit: { [weak self] in
            self?.quitManually()
        },
        contextMenuProvider: { NSMenu() }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        CodexAutoLauncher.installOrUpdate()
        CodexAutoLauncher.clearManualQuitLock()

        store.delegate = self
        configureStatusItem()
        configureLifecycleMonitor()
        lifecycleMonitor.start()

        if lifecycleMonitor.codexIsRunningNow() {
            codexDidStart()
        } else {
            updateStatusTitle(with: .initial)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchBarController.hideSystemTouchBar()
        lifecycleMonitor.stop()
        store.stop()
    }

    func rateLimitStore(_ store: RateLimitStore, didUpdate state: RateLimitDisplayState) {
        updateStatusTitle(with: state)
        touchBarController.update(with: state)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(
            systemSymbolName: "bolt.horizontal.circle.fill",
            accessibilityDescription: "Codex"
        )
        button.imagePosition = .imageLeft
        button.title = " --"
        button.toolTip = "Codex 额度"
        statusItem.menu = makeStatusMenu()
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let visibilityItem = NSMenuItem(
            title: "隐藏 Touch Bar",
            action: #selector(toggleTouchBar(_:)),
            keyEquivalent: ""
        )
        visibilityItem.target = self
        menu.addItem(visibilityItem)
        touchBarVisibilityMenuItem = visibilityItem

        let reloadTouchBarItem = NSMenuItem(
            title: "重新加载 Touch Bar",
            action: #selector(reloadTouchBarFromMenu(_:)),
            keyEquivalent: ""
        )
        reloadTouchBarItem.target = self
        menu.addItem(reloadTouchBarItem)

        let refreshItem = NSMenuItem(
            title: "刷新额度",
            action: #selector(refreshQuotaFromMenu(_:)),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quitFromMenu(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    private func configureLifecycleMonitor() {
        lifecycleMonitor.onCodexStarted = { [weak self] in
            self?.codexDidStart()
        }
        lifecycleMonitor.onCodexStopped = { [weak self] in
            self?.codexDidStop()
        }
    }

    private func updateStatusTitle(with state: RateLimitDisplayState) {
        guard let button = statusItem.button else {
            return
        }

        var titleParts: [String] = []
        var tooltipParts: [String] = []

        if let fiveHour = state.fiveHour {
            titleParts.append("\(fiveHour.shortTitle) \(fiveHour.remainingText)")
            tooltipParts.append("5 小时剩余 \(fiveHour.remainingText)")
        } else if let resetCredits = state.resetCredits, resetCredits.availableCount > 0 {
            titleParts.append("重置\(resetCredits.availableCount)")
            tooltipParts.append("可重置 \(resetCredits.availableCount) 次，\(resetCredits.expirationText)")
        }

        if let weekly = state.weekly {
            titleParts.append("\(weekly.shortTitle) \(weekly.remainingText)")
            tooltipParts.append("周限额剩余 \(weekly.remainingText)")
        }

        if !titleParts.isEmpty {
            button.title = " \(titleParts.joined(separator: "  "))"
            button.toolTip = "Codex 额度：\(tooltipParts.joined(separator: "，"))"
        } else if state.isRefreshing {
            button.title = " ..."
            button.toolTip = "Codex 额度：正在刷新"
        } else {
            button.title = " --"
            button.toolTip = state.errorMessage ?? "Codex 额度"
        }
    }

    private func codexDidStart() {
        store.start()
        _ = touchBarController.showSystemTouchBar()
        updateTouchBarMenuTitle()
    }

    private func codexDidStop() {
        touchBarController.hideSystemTouchBar()
        store.stop()
        NSApp.terminate(nil)
    }

    private func refreshQuotaNow() {
        store.start()
    }

    @objc private func toggleTouchBar(_ sender: AnyObject?) {
        if touchBarController.isTouchBarVisible {
            touchBarController.hideSystemTouchBar()
        } else {
            _ = touchBarController.showSystemTouchBar()
        }
        updateTouchBarMenuTitle()
    }

    private func updateTouchBarMenuTitle() {
        touchBarVisibilityMenuItem?.title = touchBarController.isTouchBarVisible
            ? "隐藏 Touch Bar"
            : "显示 Touch Bar"
    }

    @objc private func refreshQuotaFromMenu(_ sender: AnyObject?) {
        refreshQuotaNow()
    }

    @objc private func reloadTouchBarFromMenu(_ sender: AnyObject?) {
        touchBarController.hideSystemTouchBar()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else {
                return
            }
            _ = self.touchBarController.showSystemTouchBar()
            self.updateTouchBarMenuTitle()
        }
    }

    @objc private func quitFromMenu(_ sender: AnyObject?) {
        quitManually()
    }

    private func quitManually() {
        CodexAutoLauncher.markManualQuit()
        quitApp()
    }

    private func quitApp() {
        touchBarController.hideSystemTouchBar()
        lifecycleMonitor.stop()
        store.stop()
        NSApp.terminate(nil)
    }
}
