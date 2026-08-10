import AppKit

final class CodexLifecycleMonitor {
    var onCodexStarted: (() -> Void)?
    var onCodexStopped: (() -> Void)?

    private var timer: Timer?
    private var isCodexRunning = false

    func start() {
        isCodexRunning = Self.detectCodexRunning()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func codexIsRunningNow() -> Bool {
        Self.detectCodexRunning()
    }

    @objc private func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        if Self.isCodex(app) {
            transition(to: true)
        }
    }

    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        if Self.isCodex(app) {
            transition(to: Self.detectCodexRunning())
        }
    }

    private func poll() {
        transition(to: Self.detectCodexRunning())
    }

    private func transition(to running: Bool) {
        guard running != isCodexRunning else {
            return
        }

        isCodexRunning = running
        if running {
            onCodexStarted?()
        } else {
            onCodexStopped?()
        }
    }

    private static func detectCodexRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            isCodex(app)
        }
    }

    private static func isCodex(_ app: NSRunningApplication) -> Bool {
        if app.bundleIdentifier == "com.openai.codex" {
            return true
        }

        let supportedPaths = [
            "/Applications/Codex.app",
            "/Applications/ChatGPT.app",
            "/Applications/GPT.app"
        ]
        if let path = app.bundleURL?.path, supportedPaths.contains(path) {
            return true
        }

        let supportedNames = ["Codex", "ChatGPT", "GPT"]
        return app.localizedName.map(supportedNames.contains) ?? false
    }
}
