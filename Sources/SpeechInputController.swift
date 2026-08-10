import AppKit
import ApplicationServices
import AVFoundation
import Speech

protocol SpeechInputControllerDelegate: AnyObject {
    func speechInputController(_ controller: SpeechInputController, didChange state: SpeechInputController.State)
    func speechInputController(_ controller: SpeechInputController, didUpdateTranscript transcript: String)
}

final class SpeechInputController {
    enum State: Equatable {
        case idle
        case requestingPermission
        case recording
        case ready
        case error(String)
    }

    weak var delegate: SpeechInputControllerDelegate?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInstalledAudioTap = false
    private var errorResetWorkItem: DispatchWorkItem?

    private(set) var state: State = .idle {
        didSet {
            guard state != oldValue else { return }
            delegate?.speechInputController(self, didChange: state)
        }
    }

    private(set) var transcript = "" {
        didSet {
            guard transcript != oldValue else { return }
            delegate?.speechInputController(self, didUpdateTranscript: transcript)
        }
    }

    var isRecording: Bool {
        state == .recording || state == .requestingPermission
    }

    func toggleRecording() {
        if state == .requestingPermission {
            clear()
        } else if state == .recording {
            stopAndInsertTranscript()
        } else if !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            insertTranscript()
        } else {
            requestPermissionsAndStart()
        }
    }

    func stopRecording() {
        finishAudioCapture(cancelTask: false)
        if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state = .idle
        } else {
            state = .ready
        }
    }

    func clear() {
        errorResetWorkItem?.cancel()
        errorResetWorkItem = nil
        finishAudioCapture(cancelTask: true)
        transcript = ""
        state = .idle
    }

    private func stopAndInsertTranscript() {
        stopRecording()
        insertTranscript()
    }

    private func insertTranscript() {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            showTemporaryError("没有识别到文字")
            return
        }

        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            showTemporaryError("允许辅助功能后再点“输入”")
            return
        }

        let targetApplication = NSWorkspace.shared.runningApplications.first { application in
            let bundleIdentifier = application.bundleIdentifier?.lowercased() ?? ""
            let name = application.localizedName?.lowercased() ?? ""
            return bundleIdentifier == "com.openai.chat"
                || bundleIdentifier == "com.openai.codex"
                || name == "chatgpt"
                || name == "codex"
        }

        guard let targetApplication else {
            showTemporaryError("没有找到正在运行的 Codex")
            return
        }

        targetApplication.activate(options: [.activateAllWindows])
        state = .ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.postUnicodeText(text)
        }
    }

    private func postUnicodeText(_ text: String) {
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            showTemporaryError("无法把文字输入到 Codex")
            return
        }

        let utf16 = Array(text.utf16)
        for start in stride(from: 0, to: utf16.count, by: 64) {
            let end = min(start + 64, utf16.count)
            var chunk = Array(utf16[start..<end])
            guard let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false) else {
                showTemporaryError("无法把文字输入到 Codex")
                return
            }
            keyDown.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            keyUp.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        transcript = ""
        state = .idle
    }

    private func requestPermissionsAndStart() {
        state = .requestingPermission

        requestSpeechPermission { [weak self] speechAllowed in
            guard let self else { return }
            guard speechAllowed else {
                self.showTemporaryError("请允许语音识别权限")
                return
            }

            self.requestMicrophonePermission { [weak self] microphoneAllowed in
                guard let self else { return }
                guard microphoneAllowed else {
                    self.showTemporaryError("请允许麦克风权限")
                    return
                }
                self.startRecording()
            }
        }
    }

    private func requestSpeechPermission(completion: @escaping (Bool) -> Void) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            completion(true)
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(status == .authorized)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                DispatchQueue.main.async {
                    completion(allowed)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func startRecording() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            showTemporaryError("语音识别服务暂不可用")
            return
        }

        finishAudioCapture(cancelTask: true)
        transcript = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            recognitionRequest = nil
            showTemporaryError("没有可用的麦克风输入")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasInstalledAudioTap = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.stopRecording()
                    }
                }

                if let error, !self.isCancellationError(error) {
                    self.finishAudioCapture(cancelTask: true)
                    if self.transcript.isEmpty {
                        self.showTemporaryError("识别失败，请重试")
                    } else {
                        self.state = .ready
                    }
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            state = .recording
        } catch {
            finishAudioCapture(cancelTask: true)
            showTemporaryError("无法启动麦克风")
        }
    }

    private func showTemporaryError(_ message: String) {
        errorResetWorkItem?.cancel()
        state = .error(message)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, case .error = self.state else {
                return
            }
            self.clear()
        }
        errorResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }

    private func finishAudioCapture(cancelTask: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if hasInstalledAudioTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledAudioTap = false
        }

        recognitionRequest?.endAudio()
        if cancelTask {
            recognitionTask?.cancel()
        }
        recognitionRequest = nil
        recognitionTask = nil
    }

    private func isCancellationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216
    }
}
