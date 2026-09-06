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

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 206),
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

        let rows = NSStackView(views: [
            row(title: "DeepSeek Key", field: deepSeekField, hint: deepSeekHint),
            row(title: "GLM Key", field: glmField, hint: glmHint),
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

    private func row(title: String, field: NSTextField, hint: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false

        let fieldRow = NSStackView(views: [label, field])
        fieldRow.orientation = .horizontal
        fieldRow.alignment = .centerY
        fieldRow.spacing = 8

        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let wrapper = NSStackView(views: [fieldRow, hint])
        wrapper.orientation = .vertical
        wrapper.alignment = .leading
        wrapper.spacing = 3

        // 固定标签宽度，让两个输入框左缘对齐。
        label.widthAnchor.constraint(equalToConstant: 96).isActive = true
        return wrapper
    }

    // MARK: - 数据

    private func reloadFields() {
        deepSeekField.stringValue = APIKeyStore.deepSeek
        glmField.stringValue = APIKeyStore.glm
        refreshHints()
    }

    private func refreshHints() {
        deepSeekHint.stringValue = APIKeyStore.maskHint(APIKeyStore.deepSeek)
        glmHint.stringValue = APIKeyStore.maskHint(APIKeyStore.glm)
    }

    @objc private func saveClicked(_ sender: NSButton) {
        let deepSeek = deepSeekField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let glm = glmField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        APIKeyStore.save(deepSeek: deepSeek, glm: glm)
        onSaved?()
        window?.performClose(nil)
    }
}
