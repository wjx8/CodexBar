import AppKit

/// 应用内设置窗口：填写 DeepSeek / 智谱 GLM 的 API Key。
/// Key 由 APIKeyStore 持久化在 UserDefaults，保存即时生效，无需重新构建。
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    var onSaved: (() -> Void)?

    private let deepSeekField = NSSecureTextField(frame: .zero)
    private let glmField = NSSecureTextField(frame: .zero)
    private let deepSeekHint = NSTextField(labelWithString: "")
    private let glmHint = NSTextField(labelWithString: "")
    private let quotaIntervalPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let balanceIntervalPopup = NSPopUpButton(frame: .zero, pullsDown: false)

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 262),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "CodexBar 设置"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildLayout()
        reloadFields()
    }

    func showSettings() {
        reloadFields()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - 布局

    private func buildLayout() {
        guard let content = window?.contentView else {
            return
        }

        deepSeekField.placeholderString = "sk-..."
        glmField.placeholderString = "粘贴 API Key"

        // 长密钥在框内滚动显示，禁止圆点换行。
        for field in [deepSeekField, glmField] {
            if let cell = field.cell as? NSTextFieldCell {
                cell.wraps = false
                cell.isScrollable = true
                cell.lineBreakMode = .byTruncatingTail
            }
        }

        setupIntervalPopup(quotaIntervalPopup, choices: AppSettings.quotaChoices, current: AppSettings.quotaInterval)
        setupIntervalPopup(balanceIntervalPopup, choices: AppSettings.balanceChoices, current: AppSettings.balanceInterval)

        let rows = NSStackView(views: [
            row(title: "DeepSeek Key", control: deepSeekField, hint: deepSeekHint),
            row(title: "GLM Key", control: glmField, hint: glmHint),
            row(title: "额度刷新", control: quotaIntervalPopup, hint: nil),
            row(title: "余额刷新", control: balanceIntervalPopup, hint: nil),
        ])
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 12
        rows.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(rows)

        let footnote = NSTextField(labelWithString: "Key 保存在本机 UserDefaults，保存后立即生效。")
        footnote.font = .systemFont(ofSize: 11)
        footnote.textColor = .secondaryLabelColor
        footnote.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(footnote)

        let save = NSButton(title: "保存", target: self, action: #selector(saveClicked(_:)))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(save)

        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            rows.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            rows.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),

            footnote.leadingAnchor.constraint(equalTo: rows.leadingAnchor),
            footnote.topAnchor.constraint(equalTo: rows.bottomAnchor, constant: 12),

            save.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            save.topAnchor.constraint(equalTo: footnote.bottomAnchor, constant: 14),
            save.widthAnchor.constraint(equalToConstant: 84),
            content.bottomAnchor.constraint(equalTo: save.bottomAnchor, constant: 18),

            deepSeekField.widthAnchor.constraint(equalToConstant: 280),
            glmField.widthAnchor.constraint(equalToConstant: 280),
        ])
    }

    private func setupIntervalPopup(_ popup: NSPopUpButton, choices: [Int], current: Int) {
        popup.removeAllItems()
        var entries = choices.map { (title: AppSettings.intervalTitle($0), seconds: $0) }
        if !choices.contains(current) {
            // 用户曾用 defaults write 写过非预设值：追加回显，不吞掉手动配置。
            entries.append((AppSettings.intervalTitle(current), current))
        }
        for entry in entries.sorted(by: { $0.seconds < $1.seconds }) {
            popup.addItem(withTitle: entry.title)
            popup.lastItem?.representedObject = entry.seconds
        }
        if let index = popup.itemArray.firstIndex(where: { ($0.representedObject as? Int) == current }) {
            popup.selectItem(at: index)
        }
    }

    private func row(title: String, control: NSView, hint: NSTextField?) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false

        let fieldRow = NSStackView(views: [label, control])
        fieldRow.orientation = .horizontal
        fieldRow.alignment = .centerY
        fieldRow.spacing = 8

        var views: [NSView] = [fieldRow]
        if let hint {
            hint.font = .systemFont(ofSize: 11)
            hint.textColor = .secondaryLabelColor
            views.append(hint)
        }

        let wrapper = NSStackView(views: views)
        wrapper.orientation = .vertical
        wrapper.alignment = .leading
        wrapper.spacing = 3

        // 固定标签宽度，让各行的控件左缘对齐。
        label.widthAnchor.constraint(equalToConstant: 96).isActive = true
        return wrapper
    }

    // MARK: - 数据

    private func reloadFields() {
        deepSeekField.stringValue = APIKeyStore.deepSeek
        glmField.stringValue = APIKeyStore.glm
        refreshHints()
        reloadIntervalPopups()
    }

    private func reloadIntervalPopups() {
        let quota = AppSettings.quotaInterval
        let balance = AppSettings.balanceInterval
        if let index = quotaIntervalPopup.itemArray.firstIndex(where: { ($0.representedObject as? Int) == quota }) {
            quotaIntervalPopup.selectItem(at: index)
        }
        if let index = balanceIntervalPopup.itemArray.firstIndex(where: { ($0.representedObject as? Int) == balance }) {
            balanceIntervalPopup.selectItem(at: index)
        }
    }

    private func refreshHints() {
        deepSeekHint.stringValue = APIKeyStore.maskHint(APIKeyStore.deepSeek)
        glmHint.stringValue = APIKeyStore.maskHint(APIKeyStore.glm)
    }

    @objc private func saveClicked(_ sender: NSButton) {
        let deepSeek = deepSeekField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let glm = glmField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        APIKeyStore.save(deepSeek: deepSeek, glm: glm)
        if let quota = quotaIntervalPopup.selectedItem?.representedObject as? Int {
            AppSettings.saveQuotaInterval(quota)
        }
        if let balance = balanceIntervalPopup.selectedItem?.representedObject as? Int {
            AppSettings.saveBalanceInterval(balance)
        }
        onSaved?()
        window?.performClose(nil)
    }
}
