import Foundation

enum CodexAutoLauncher {
    private static let launchAgentLabel = "com.wangjiaxuan666.CodexBar.Launcher"
    private static let appSupportDirectoryName = "CodexBar"
    private static let manualQuitLockName = "manual-quit.lock"

    static func installOrUpdate() {
        guard let appBundleURL = Bundle.main.bundleURLIfApp else {
            return
        }

        let scriptURL = appBundleURL.appendingPathComponent(
            "Contents/Resources/codex-token-launcher.sh",
            isDirectory: false
        )
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            NSLog("CodexBar auto launcher script is missing at %@", scriptURL.path)
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: launchAgentsDirectory,
                withIntermediateDirectories: true
            )

            let plistURL = launchAgentsDirectory.appendingPathComponent("\(launchAgentLabel).plist")
            let plist = launchAgentPlist(scriptPath: scriptURL.path, appPath: appBundleURL.path)
            try plist.write(to: plistURL, atomically: true, encoding: .utf8)
            bootstrapLaunchAgent(at: plistURL)
        } catch {
            NSLog("CodexBar failed to install auto launcher: %@", String(describing: error))
        }
    }

    static func clearManualQuitLock() {
        try? FileManager.default.removeItem(at: manualQuitLockURL)
    }

    static func markManualQuit() {
        do {
            try FileManager.default.createDirectory(
                at: appSupportDirectory,
                withIntermediateDirectories: true
            )
            try "manual quit\n".write(to: manualQuitLockURL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("CodexBar failed to write manual quit lock: %@", String(describing: error))
        }
    }

    private static var launchAgentsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    private static var appSupportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(appSupportDirectoryName, isDirectory: true)
    }

    private static var manualQuitLockURL: URL {
        appSupportDirectory.appendingPathComponent(manualQuitLockName, isDirectory: false)
    }

    private static func launchAgentPlist(scriptPath: String, appPath: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchAgentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/zsh</string>
                <string>\(scriptPath.xmlEscaped)</string>
                <string>\(appPath.xmlEscaped)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>StartInterval</key>
            <integer>5</integer>
        </dict>
        </plist>
        """
    }

    private static func bootstrapLaunchAgent(at plistURL: URL) {
        let domain = "gui/\(getuid())"

        runLaunchctl(arguments: ["enable", "\(domain)/\(launchAgentLabel)"])
        runLaunchctl(arguments: ["bootout", domain, plistURL.path])
        runLaunchctl(arguments: ["bootstrap", domain, plistURL.path])
        runLaunchctl(arguments: ["kickstart", "-k", "\(domain)/\(launchAgentLabel)"])
    }

    private static func runLaunchctl(arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try? process.run()
        process.waitUntilExit()
    }
}

private extension Bundle {
    var bundleURLIfApp: URL? {
        let url = bundleURL
        return url.pathExtension == "app" ? url : nil
    }
}

private extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
