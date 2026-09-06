import Foundation

/// API Key 的存取：保存在 UserDefaults（com.wangjiaxuan666.CodexBar），
/// 通过应用内设置窗口填写，改动即时生效，无需重新构建。
enum APIKeyStore {
    static let deepSeekDefaultsKey = "api.deepseekKey"
    static let glmDefaultsKey = "api.glmKey"

    static var deepSeek: String {
        UserDefaults.standard.string(forKey: deepSeekDefaultsKey) ?? ""
    }

    static var glm: String {
        UserDefaults.standard.string(forKey: glmDefaultsKey) ?? ""
    }

    static func save(deepSeek: String, glm: String) {
        UserDefaults.standard.set(deepSeek, forKey: deepSeekDefaultsKey)
        UserDefaults.standard.set(glm, forKey: glmDefaultsKey)
    }

    static func maskHint(_ key: String) -> String {
        guard !key.isEmpty else {
            return "未设置"
        }
        return "已保存：···" + key.suffix(4)
    }
}

struct RemoteBalanceDisplay: Equatable {
    var deepSeekText: String = "DS --¥"
    var glmText: String = "GLM --¥"
}

/// 通过官方 API 轮询 DeepSeek 与智谱 GLM 的账户余额。
/// 刷新失败时保留上一次成功的数值，不打断菜单栏显示。
final class RemoteBalanceStore {
    var onUpdate: ((RemoteBalanceDisplay) -> Void)?

    private(set) var display = RemoteBalanceDisplay()

    private var timer: Timer?
    private var isStarted = false

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    func start() {
        guard !isStarted else {
            refresh()
            return
        }
        isStarted = true
        refresh()
        // 余额变化频率低，10 分钟轮询一次即可；菜单"刷新额度"会立即触发 refresh()。
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        isStarted = false
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        fetchDeepSeek()
        fetchGLM()
    }

    private func publish() {
        onUpdate?(display)
    }

    // MARK: - DeepSeek

    private func fetchDeepSeek() {
        let key = APIKeyStore.deepSeek
        guard !key.isEmpty else {
            return
        }

        var request = URLRequest(url: URL(string: "https://api.deepseek.com/user/balance")!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        session.dataTask(with: request) { [weak self] data, _, _ in
            guard let data else {
                return
            }

            DispatchQueue.main.async {
                guard let self, self.isStarted, let amount = Self.parseDeepSeekBalance(data) else {
                    return
                }
                self.display.deepSeekText = String(format: "DS %.2f¥", amount)
                self.publish()
            }
        }.resume()
    }

    static func parseDeepSeekBalance(_ data: Data) -> Double? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let infos = json["balance_infos"] as? [[String: Any]]
        else {
            return nil
        }

        let preferred = infos.first { ($0["currency"] as? String) == "CNY" } ?? infos.first
        return numberValue(preferred?["total_balance"])
    }

    // MARK: - 智谱 GLM

    private func fetchGLM() {
        let key = APIKeyStore.glm
        guard !key.isEmpty else {
            return
        }

        // 按量付费账户余额在控制台域名 www.bigmodel.cn 上；open.bigmodel.cn 的
        // /v4/users/me/balance 已下线（返回 404），/api/monitor/usage/quota/limit
        // 仅对 Coding Plan 账号开放。
        var request = URLRequest(url: URL(string: "https://www.bigmodel.cn/api/biz/account/query-customer-account-report")!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        session.dataTask(with: request) { [weak self] data, _, _ in
            guard let data else {
                return
            }

            DispatchQueue.main.async {
                guard let self, self.isStarted, let amount = Self.parseGLMBalance(data) else {
                    return
                }
                self.display.glmText = String(format: "GLM %.2f¥", amount)
                self.publish()
            }
        }.resume()
    }

    static func parseGLMBalance(_ data: Data) -> Double? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            (json["success"] as? Bool) == true,
            let payload = json["data"] as? [String: Any]
        else {
            return nil
        }

        return numberValue(payload["availableBalance"]) ?? numberValue(payload["balance"])
    }

    private static func numberValue(_ any: Any?) -> Double? {
        switch any {
        case let text as String:
            return Double(text)
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }
}
