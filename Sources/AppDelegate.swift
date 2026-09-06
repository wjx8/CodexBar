import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, RateLimitStoreDelegate, NSMenuDelegate {
    /// 菜单栏各分段的自定义显示开关，持久化在 UserDefaults；未设置时默认全部显示。
    private enum MenuBarSection {
        static let codex = "menubar.showCodex"
        static let deepSeek = "menubar.showDeepSeek"
        static let glm = "menubar.showGLM"
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store = RateLimitStore()
    private let remoteBalances = RemoteBalanceStore()
    private var lastQuotaState = RateLimitDisplayState.initial
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
        remoteBalances.onUpdate = { [weak self] _ in
            self?.renderStatusItem()
        }
        SettingsWindowController.shared.onSaved = { [weak self] in
            guard let self else { return }
            store.applySettings()
            remoteBalances.applySettings()
        }
        remoteBalances.start()
        configureStatusItem()
        configureLifecycleMonitor()
        lifecycleMonitor.start()

        if lifecycleMonitor.codexIsRunningNow() {
            codexDidStart()
        } else {
            renderStatusItem()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchBarController.hideSystemTouchBar()
        lifecycleMonitor.stop()
        store.stop()
        remoteBalances.stop()
    }

    func rateLimitStore(_ store: RateLimitStore, didUpdate state: RateLimitDisplayState) {
        lastQuotaState = state
        touchBarController.update(with: state)
        renderStatusItem()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.toolTip = "余额"
        // 系统原生展示：外观、贴齐菜单栏、滚动行为全部由系统保证。
        statusItem.menu = makeStatusMenu()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // 把菜单最小宽度撑到与状态项等宽：系统将菜单左对齐到状态项，
        // 等宽时即视觉居中，与显示哪几段余额无关。
        if let width = statusItem.button?.window?.frame.width, width > 0 {
            menu.minimumWidth = width
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

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
        menu.addItem(.separator())

        // 菜单栏分段显示开关：勾选即显示（HIG 标准的 checkmark 菜单项）。
        let sectionItems: [(key: String, title: String)] = [
            (MenuBarSection.codex, "菜单栏显示 Codex 用量"),
            (MenuBarSection.deepSeek, "菜单栏显示 DS 余额"),
            (MenuBarSection.glm, "菜单栏显示 GLM 余额"),
        ]
        for section in sectionItems {
            let item = NSMenuItem(
                title: section.title,
                action: #selector(toggleMenuBarSection(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = section.key
            item.state = isSectionVisible(section.key) ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let refreshItem = NSMenuItem(
            title: "刷新额度",
            action: #selector(refreshQuotaFromMenu(_:)),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(
            title: "设置…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
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

    private func isSectionVisible(_ key: String) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }

    @objc private func toggleMenuBarSection(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }

        let newValue = !isSectionVisible(key)
        UserDefaults.standard.set(newValue, forKey: key)
        sender.state = newValue ? .on : .off
        renderStatusItem()
    }

    private func renderStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        let state = lastQuotaState
        var titleParts: [String] = []
        var tooltipParts: [String] = []

        if isSectionVisible(MenuBarSection.codex) {
            if let fiveHour = state.fiveHour {
                titleParts.append("\(fiveHour.shortTitle) \(fiveHour.remainingText)")
                tooltipParts.append("Codex 5 小时剩余 \(fiveHour.remainingText)")
            } else if let resetCredits = state.resetCredits, resetCredits.availableCount > 0 {
                titleParts.append("重置\(resetCredits.availableCount)")
                tooltipParts.append("Codex 可重置 \(resetCredits.availableCount) 次，\(resetCredits.expirationText)")
            }

            if let weekly = state.weekly {
                titleParts.append("\(weekly.shortTitle) \(weekly.remainingText)")
                tooltipParts.append("Codex 周限额剩余 \(weekly.remainingText)")
            }

            if state.isRefreshing && state.fiveHour == nil && state.weekly == nil {
                titleParts.insert("...", at: 0)
            }
        }

        if isSectionVisible(MenuBarSection.deepSeek) {
            titleParts.append(remoteBalances.display.deepSeekText)
            tooltipParts.append("DeepSeek \(remoteBalances.display.deepSeekText)")
        }

        if isSectionVisible(MenuBarSection.glm) {
            titleParts.append(remoteBalances.display.glmText)
            tooltipParts.append("GLM \(remoteBalances.display.glmText)")
        }

        if titleParts.isEmpty {
            button.title = "--"
            button.toolTip = "CodexBar"
        } else {
            button.title = titleParts.joined(separator: " ")
            button.toolTip = tooltipParts.joined(separator: "，")
                + (isSectionVisible(MenuBarSection.codex) ? (state.errorMessage.map { "，Codex：\($0)" } ?? "") : "")
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
        remoteBalances.refresh()
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

    @objc private func openSettings(_ sender: AnyObject?) {
        SettingsWindowController.shared.showSettings()
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
        remoteBalances.stop()
        NSApp.terminate(nil)
    }
}
