import Foundation

enum CodexAppServerError: LocalizedError {
    case processUnavailable
    case requestTimedOut
    case malformedResponse
    case serverError(String)
    case missingResult

    var errorDescription: String? {
        switch self {
        case .processUnavailable:
            return "未找到或无法启动 Codex app-server，请检查 ChatGPT / Codex 安装。"
        case .requestTimedOut:
            return "Codex app-server 读取超时，将在下次刷新时重试。"
        case .malformedResponse:
            return "Codex app-server returned an unexpected response."
        case .serverError(let message):
            return message
        case .missingResult:
            return "Codex app-server response did not include a result."
        }
    }
}

final class CodexAppServerClient {
    typealias JSONDictionary = [String: Any]

    private let codexCandidates = ["ChatGPT", "Codex", "GPT"].flatMap { host in
        [
            "/Applications/\(host).app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/\(host).app/Contents/Resources/codex"
        ].map(URL.init(fileURLWithPath:))
    }
    private let queue = DispatchQueue(label: "CodexBar.CodexAppServerClient")

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var outputBuffer = Data()
    private var nextRequestId = 1
    private var pendingResponses: [Int: (Result<Any, Error>) -> Void] = [:]

    var onRateLimitsUpdated: (() -> Void)?

    func start(completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            if self.process?.isRunning == true {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                return
            }

            do {
                try self.launchProcess()
                self.initialize(completion: completion)
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func stop() {
        queue.async {
            self.outputPipe?.fileHandleForReading.readabilityHandler = nil
            self.errorPipe?.fileHandleForReading.readabilityHandler = nil
            self.inputPipe?.fileHandleForWriting.closeFile()
            if self.process?.isRunning == true {
                self.process?.terminationHandler = nil
                self.process?.terminate()
            }
            self.process = nil
            self.outputBuffer.removeAll()
            self.failPendingResponses(CodexAppServerError.processUnavailable)
        }
    }

    func readRateLimits(completion: @escaping (Result<GetAccountRateLimitsResponse, Error>) -> Void) {
        request(method: "account/rateLimits/read", params: nil) { result in
            switch result {
            case .success(let value):
                do {
                    guard JSONSerialization.isValidJSONObject(value) else {
                        throw CodexAppServerError.malformedResponse
                    }
                    let data = try JSONSerialization.data(withJSONObject: value)
                    let response = try JSONDecoder().decode(GetAccountRateLimitsResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func launchProcess() throws {
        guard let codexURL = codexCandidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }) else {
            throw CodexAppServerError.processUnavailable
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = codexURL
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            self?.queue.async {
                self?.consumeOutput(data)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }

        process.terminationHandler = { [weak self] terminatedProcess in
            self?.queue.async {
                guard let self, self.process === terminatedProcess else { return }
                self.failPendingResponses(CodexAppServerError.processUnavailable)
            }
        }

        outputBuffer.removeAll()
        try process.run()

        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
    }

    private func initialize(completion: @escaping (Result<Void, Error>) -> Void) {
        let capabilities: JSONDictionary = [
            "experimentalApi": true,
            "requestAttestation": false,
            "optOutNotificationMethods": [String]()
        ]

        let params: JSONDictionary = [
            "clientInfo": [
                "name": "touchbar-codex-token",
                "title": "Touch Bar Codex Token",
                "version": "0.1.0"
            ],
            "capabilities": capabilities
        ]

        request(method: "initialize", params: params) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.queue.async {
                        do {
                            let notification = try JSONSerialization.data(withJSONObject: [
                                "method": "initialized",
                                "params": [:]
                            ] as JSONDictionary)
                            guard let writer = self.inputPipe?.fileHandleForWriting,
                                  self.process?.isRunning == true else {
                                throw CodexAppServerError.processUnavailable
                            }
                            var framed = notification
                            framed.append(0x0A)
                            writer.write(framed)
                            DispatchQueue.main.async { completion(.success(())) }
                        } catch {
                            DispatchQueue.main.async { completion(.failure(error)) }
                        }
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    private func request(method: String, params: Any?, completion: @escaping (Result<Any, Error>) -> Void) {
        queue.async {
            guard let writer = self.inputPipe?.fileHandleForWriting, self.process?.isRunning == true else {
                DispatchQueue.main.async {
                    completion(.failure(CodexAppServerError.processUnavailable))
                }
                return
            }

            let requestId = self.nextRequestId
            self.nextRequestId += 1
            self.pendingResponses[requestId] = { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }

            self.queue.asyncAfter(deadline: .now() + 30) {
                guard let completion = self.pendingResponses.removeValue(forKey: requestId) else { return }
                completion(.failure(CodexAppServerError.requestTimedOut))
                // An unresponsive server must be relaunched on the next refresh.
                self.process?.terminate()
            }

            var payload: JSONDictionary = [
                "id": requestId,
                "method": method
            ]
            if let params {
                payload["params"] = params
            }

            do {
                let data = try JSONSerialization.data(withJSONObject: payload)
                var framed = data
                framed.append(0x0A)
                writer.write(framed)
            } catch {
                self.pendingResponses.removeValue(forKey: requestId)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func consumeOutput(_ data: Data) {
        outputBuffer.append(data)

        while let newlineRange = outputBuffer.firstRange(of: Data([0x0A])) {
            let line = outputBuffer.subdata(in: outputBuffer.startIndex..<newlineRange.lowerBound)
            outputBuffer.removeSubrange(outputBuffer.startIndex..<newlineRange.upperBound)

            guard !line.isEmpty else {
                continue
            }
            consumeLine(line)
        }
    }

    private func consumeLine(_ data: Data) {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let message = object as? JSONDictionary
        else {
            return
        }

        if let method = message["method"] as? String {
            if method == "account/rateLimits/updated" {
                DispatchQueue.main.async {
                    self.onRateLimitsUpdated?()
                }
            }
            return
        }

        guard let id = intRequestId(from: message["id"]) else {
            return
        }

        guard let completion = pendingResponses.removeValue(forKey: id) else {
            return
        }

        if let error = message["error"] as? JSONDictionary {
            let message = error["message"] as? String ?? "Codex app-server returned an error."
            completion(.failure(CodexAppServerError.serverError(message)))
            return
        }

        guard let result = message["result"] else {
            completion(.failure(CodexAppServerError.missingResult))
            return
        }

        completion(.success(result))
    }

    private func intRequestId(from value: Any?) -> Int? {
        if let id = value as? Int {
            return id
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    private func failPendingResponses(_ error: Error) {
        let completions = pendingResponses.values
        pendingResponses.removeAll()

        completions.forEach { completion in
            completion(.failure(error))
        }
    }
}
