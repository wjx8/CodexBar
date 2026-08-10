import AppKit

final class TouchBarRateLimitsView: NSView {
    private let codexIconView = NSImageView()
    private let fiveHourRow = TouchBarLimitRow(title: "5 小时")
    private let weeklyRow = TouchBarLimitRow(title: "周限额")
    private let rows = NSStackView()
    private let transcriptLabel = NSTextField(labelWithString: "点麦克风开始语音输入")
    private let microphoneButton = NSButton()

    init(
        voiceTarget: AnyObject,
        toggleVoiceAction: Selector
    ) {
        super.init(frame: .zero)
        microphoneButton.target = voiceTarget
        microphoneButton.action = toggleVoiceAction
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with state: RateLimitDisplayState) {
        if let fiveHour = state.fiveHour {
            fiveHourRow.isHidden = false
            fiveHourRow.updateLimit(
                title: "5 小时",
                meter: fiveHour,
                usageText: state.tokenUsage?.yesterdayText ?? "昨日 --"
            )
        } else if let resetCredits = state.resetCredits, resetCredits.availableCount > 0 {
            fiveHourRow.isHidden = false
            fiveHourRow.updateResetCredits(
                resetCredits,
                usageText: state.tokenUsage?.yesterdayText ?? "昨日 --"
            )
        } else if state.lastUpdated != nil {
            fiveHourRow.isHidden = true
        } else {
            fiveHourRow.isHidden = false
            fiveHourRow.updatePlaceholder(title: "5 小时", usageText: "昨日 --")
        }

        if let weekly = state.weekly {
            weeklyRow.isHidden = false
            weeklyRow.updateLimit(
                title: "周限额",
                meter: weekly,
                usageText: state.tokenUsage?.cumulativeText ?? "累计 --"
            )
        } else if state.lastUpdated != nil {
            weeklyRow.isHidden = true
        } else {
            weeklyRow.isHidden = false
            weeklyRow.updatePlaceholder(title: "周限额", usageText: "累计 --")
        }
    }

    func updateVoice(state: SpeechInputController.State, transcript: String) {
        switch state {
        case .idle:
            rows.isHidden = false
            transcriptLabel.isHidden = true
            transcriptLabel.stringValue = "点麦克风开始语音输入"
            updateMicrophoneButton(
                symbolName: "waveform.circle.fill",
                color: .systemPurple,
                accessibilityLabel: "开始语音输入",
                toolTip: "开始中文语音输入；再次点击会直接输入当前文本框"
            )
        case .requestingPermission:
            rows.isHidden = true
            transcriptLabel.isHidden = false
            transcriptLabel.stringValue = "正在请求语音权限…"
            updateMicrophoneButton(
                symbolName: "xmark.circle.fill",
                color: .systemOrange,
                accessibilityLabel: "取消语音输入",
                toolTip: "取消权限请求"
            )
        case .recording:
            rows.isHidden = true
            transcriptLabel.isHidden = false
            transcriptLabel.stringValue = transcript.isEmpty ? "正在听，请说话…" : transcript
            updateMicrophoneButton(
                symbolName: "stop.circle.fill",
                color: .systemRed,
                accessibilityLabel: "停止并输入",
                toolTip: "停止识别并输入当前文字"
            )
        case .ready:
            rows.isHidden = true
            transcriptLabel.isHidden = false
            transcriptLabel.stringValue = transcript.isEmpty ? "没有识别到文字" : transcript
            updateMicrophoneButton(
                symbolName: transcript.isEmpty ? "waveform.circle.fill" : "arrow.up.circle.fill",
                color: transcript.isEmpty ? .systemPurple : .systemGreen,
                accessibilityLabel: transcript.isEmpty ? "重新录音" : "输入识别文字",
                toolTip: transcript.isEmpty ? "重新开始语音识别" : "输入当前识别文字"
            )
        case .error(let message):
            rows.isHidden = true
            transcriptLabel.isHidden = false
            transcriptLabel.stringValue = transcript.isEmpty ? message : "\(transcript) · \(message)"
            updateMicrophoneButton(
                symbolName: transcript.isEmpty ? "exclamationmark.circle.fill" : "arrow.up.circle.fill",
                color: .systemOrange,
                accessibilityLabel: transcript.isEmpty ? "语音识别失败" : "输入已识别文字",
                toolTip: message
            )
        }
    }

    private func updateMicrophoneButton(
        symbolName: String,
        color: NSColor,
        accessibilityLabel: String,
        toolTip: String
    ) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        microphoneButton.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityLabel
        )?.withSymbolConfiguration(configuration)
        microphoneButton.contentTintColor = color
        microphoneButton.setAccessibilityLabel(accessibilityLabel)
        microphoneButton.toolTip = toolTip
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        codexIconView.image = Self.codexIcon()
        codexIconView.imageAlignment = .alignCenter
        codexIconView.imageScaling = .scaleProportionallyUpOrDown
        codexIconView.translatesAutoresizingMaskIntoConstraints = false
        codexIconView.toolTip = "Codex"

        rows.setViews([fiveHourRow, weeklyRow], in: .leading)
        rows.translatesAutoresizingMaskIntoConstraints = false
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 0

        transcriptLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        transcriptLabel.textColor = .labelColor
        transcriptLabel.lineBreakMode = .byTruncatingTail
        transcriptLabel.maximumNumberOfLines = 1
        transcriptLabel.isHidden = true
        transcriptLabel.translatesAutoresizingMaskIntoConstraints = false

        let voiceContent = NSView()
        voiceContent.translatesAutoresizingMaskIntoConstraints = false
        voiceContent.addSubview(rows)
        voiceContent.addSubview(transcriptLabel)

        microphoneButton.title = ""
        microphoneButton.imagePosition = .imageOnly
        microphoneButton.bezelStyle = .circular
        microphoneButton.isBordered = false
        microphoneButton.translatesAutoresizingMaskIntoConstraints = false
        updateMicrophoneButton(
            symbolName: "waveform.circle.fill",
            color: .systemPurple,
            accessibilityLabel: "开始语音输入",
            toolTip: "开始中文语音输入；再次点击会直接输入当前文本框"
        )

        let content = NSStackView(views: [codexIconView, voiceContent, microphoneButton])
        content.translatesAutoresizingMaskIntoConstraints = false
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 6
        content.setCustomSpacing(2, after: codexIconView)

        addSubview(content)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 650),
            heightAnchor.constraint(equalToConstant: 30),
            codexIconView.widthAnchor.constraint(equalToConstant: 34),
            codexIconView.heightAnchor.constraint(equalToConstant: 30),
            voiceContent.widthAnchor.constraint(equalToConstant: 530),
            voiceContent.heightAnchor.constraint(equalToConstant: 30),
            rows.leadingAnchor.constraint(equalTo: voiceContent.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: voiceContent.trailingAnchor),
            rows.centerYAnchor.constraint(equalTo: voiceContent.centerYAnchor),
            transcriptLabel.leadingAnchor.constraint(equalTo: voiceContent.leadingAnchor, constant: 6),
            transcriptLabel.trailingAnchor.constraint(equalTo: voiceContent.trailingAnchor, constant: -6),
            transcriptLabel.centerYAnchor.constraint(equalTo: voiceContent.centerYAnchor),
            fiveHourRow.widthAnchor.constraint(equalToConstant: 530),
            weeklyRow.widthAnchor.constraint(equalToConstant: 530),
            microphoneButton.widthAnchor.constraint(equalToConstant: 48),
            microphoneButton.heightAnchor.constraint(equalToConstant: 30),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private static func codexIcon() -> NSImage {
        let iconPaths = [
            "/Applications/ChatGPT.app/Contents/Resources/icon-codex-light.png",
            "/Applications/ChatGPT.app/Contents/Resources/icon-codex-dark-color.png",
            "/Applications/Codex.app/Contents/Resources/icon.icns"
        ]

        for path in iconPaths {
            if let image = NSImage(contentsOfFile: path) {
                image.size = NSSize(width: 30, height: 30)
                return image
            }
        }

        let appPaths = ["/Applications/ChatGPT.app", "/Applications/Codex.app"]
        for path in appPaths where FileManager.default.fileExists(atPath: path) {
            let image = NSWorkspace.shared.icon(forFile: path)
            image.size = NSSize(width: 30, height: 30)
            return image
        }

        let bundledIconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns")
        let image = bundledIconPath.flatMap(NSImage.init(contentsOfFile:))
            ?? NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Codex")
            ?? NSImage(size: NSSize(width: 30, height: 30))
        image.size = NSSize(width: 30, height: 30)
        return image
    }
}

private final class TouchBarLimitRow: NSView {
    private let titleLabel: NSTextField
    private let batteryBar = SegmentedBatteryBar()
    private let creditsIndicatorLabel = NSTextField(labelWithString: "")
    private let remainingLabel = NSTextField(labelWithString: "剩余 --")
    private let resetLabel = NSTextField(labelWithString: "-- 重置")
    private let separatorLabel = NSTextField(labelWithString: "|")
    private let usageLabel = NSTextField(labelWithString: "--")

    init(title: String) {
        self.titleLabel = NSTextField(labelWithString: title)
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateLimit(title: String, meter: LimitMeter, usageText: String) {
        titleLabel.stringValue = title
        batteryBar.isHidden = false
        creditsIndicatorLabel.isHidden = true
        batteryBar.remainingPercent = meter.remainingPercent
        batteryBar.isDimmed = false
        remainingLabel.stringValue = "剩余 \(meter.remainingText)"
        resetLabel.stringValue = meter.resetText
        usageLabel.stringValue = usageText
    }

    func updateResetCredits(_ resetCredits: ResetCreditSummary, usageText: String) {
        titleLabel.stringValue = "重置券"
        batteryBar.isHidden = true
        creditsIndicatorLabel.isHidden = false
        creditsIndicatorLabel.stringValue = Self.creditIndicator(count: resetCredits.availableCount)
        remainingLabel.stringValue = resetCredits.availableText
        resetLabel.stringValue = resetCredits.expirationText
        usageLabel.stringValue = usageText
    }

    func updatePlaceholder(title: String, usageText: String) {
        titleLabel.stringValue = title
        batteryBar.isHidden = false
        creditsIndicatorLabel.isHidden = true
        batteryBar.remainingPercent = 0
        batteryBar.isDimmed = true
        remainingLabel.stringValue = "剩余 --"
        resetLabel.stringValue = "-- 重置"
        usageLabel.stringValue = usageText
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .monospacedDigitSystemFont(ofSize: 12.5, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .left

        creditsIndicatorLabel.font = .systemFont(ofSize: 11, weight: .bold)
        creditsIndicatorLabel.textColor = .systemTeal
        creditsIndicatorLabel.alignment = .left
        creditsIndicatorLabel.lineBreakMode = .byClipping
        creditsIndicatorLabel.isHidden = true

        remainingLabel.font = .monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold)
        remainingLabel.textColor = .labelColor
        remainingLabel.lineBreakMode = .byTruncatingTail

        resetLabel.font = .monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold)
        resetLabel.textColor = .labelColor
        resetLabel.lineBreakMode = .byTruncatingTail

        separatorLabel.font = .monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold)
        separatorLabel.textColor = .labelColor
        separatorLabel.alignment = .center

        usageLabel.font = .monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold)
        usageLabel.textColor = .labelColor
        usageLabel.lineBreakMode = .byTruncatingTail

        let statusContainer = NSView()
        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        batteryBar.translatesAutoresizingMaskIntoConstraints = false
        creditsIndicatorLabel.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.addSubview(batteryBar)
        statusContainer.addSubview(creditsIndicatorLabel)

        let row = NSStackView(views: [
            titleLabel,
            statusContainer,
            remainingLabel,
            resetLabel,
            separatorLabel,
            usageLabel
        ])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 8
        row.setCustomSpacing(4, after: titleLabel)
        row.setCustomSpacing(0, after: remainingLabel)
        row.setCustomSpacing(4, after: resetLabel)
        row.setCustomSpacing(4, after: separatorLabel)

        addSubview(row)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 15),
            titleLabel.widthAnchor.constraint(equalToConstant: 44),
            statusContainer.widthAnchor.constraint(equalToConstant: 126),
            statusContainer.heightAnchor.constraint(equalToConstant: 12),
            batteryBar.widthAnchor.constraint(equalToConstant: 126),
            batteryBar.heightAnchor.constraint(equalToConstant: 12),
            batteryBar.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor),
            batteryBar.topAnchor.constraint(equalTo: statusContainer.topAnchor),
            creditsIndicatorLabel.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 5),
            creditsIndicatorLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusContainer.trailingAnchor),
            creditsIndicatorLabel.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            remainingLabel.widthAnchor.constraint(equalToConstant: 66),
            resetLabel.widthAnchor.constraint(equalToConstant: 118),
            separatorLabel.widthAnchor.constraint(equalToConstant: 7),
            usageLabel.widthAnchor.constraint(equalToConstant: 68),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private static func creditIndicator(count: Int) -> String {
        if count <= 5 {
            return Array(repeating: "●", count: max(0, count)).joined(separator: "  ")
        }
        return "●  × \(count)"
    }
}
