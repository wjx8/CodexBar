import Foundation

struct GetAccountRateLimitsResponse: Codable {
    let rateLimits: RateLimitSnapshot
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
    let rateLimitResetCredits: RateLimitResetCreditsResponse?
}

struct RateLimitSnapshot: Codable {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
}

struct RateLimitWindow: Codable {
    let usedPercent: Double
    let windowDurationMins: Double?
    let resetsAt: Double?
}

struct RateLimitResetCreditsResponse: Codable {
    let availableCount: Int
    let credits: [RateLimitResetCreditResponse]?
}

struct RateLimitResetCreditResponse: Codable {
    let status: String?
    let expiresAt: Double?
}

struct LimitMeter: Equatable {
    let title: String
    let shortTitle: String
    let usedPercent: Double
    let remainingPercent: Double
    let resetDate: Date?
    let durationMinutes: Double?

    var remainingText: String {
        "\(Int(remainingPercent.rounded()))%"
    }

    var resetText: String {
        guard let resetDate else {
            return "重置 --"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current

        formatter.dateFormat = "MM月dd日 HH:mm"

        return "\(formatter.string(from: resetDate)) 重置"
    }

    init(title: String, shortTitle: String, window: RateLimitWindow) {
        self.title = title
        self.shortTitle = shortTitle
        self.usedPercent = window.usedPercent
        self.remainingPercent = max(0, min(100, 100 - window.usedPercent))
        self.resetDate = Self.date(fromEpoch: window.resetsAt)
        self.durationMinutes = window.windowDurationMins
    }

    private static func date(fromEpoch value: Double?) -> Date? {
        guard let value else {
            return nil
        }

        let seconds = value > 10_000_000_000 ? value / 1000 : value
        return Date(timeIntervalSince1970: seconds)
    }
}

struct RateLimitDisplayState: Equatable {
    var fiveHour: LimitMeter?
    var weekly: LimitMeter?
    var resetCredits: ResetCreditSummary?
    var tokenUsage: TokenUsageSummary?
    var isRefreshing: Bool
    var lastUpdated: Date?
    var errorMessage: String?

    static let initial = RateLimitDisplayState(
        fiveHour: nil,
        weekly: nil,
        resetCredits: nil,
        tokenUsage: nil,
        isRefreshing: false,
        lastUpdated: nil,
        errorMessage: nil
    )

    var statusText: String {
        if let errorMessage {
            return errorMessage
        }

        if isRefreshing {
            return lastUpdated == nil ? "正在读取本机 Codex app-server..." : "正在刷新，保留上一组数据"
        }

        guard let lastUpdated else {
            return "尚未读取额度"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "上次更新 \(formatter.string(from: lastUpdated))"
    }
}

struct ResetCreditSummary: Equatable {
    let availableCount: Int
    let earliestExpirationDate: Date?

    var compactText: String {
        "重置 \(availableCount)次"
    }

    var availableText: String {
        "可用 \(availableCount) 次"
    }

    var expirationText: String {
        guard let earliestExpirationDate else {
            return "到期 --"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "MM月dd日"
        return "\(formatter.string(from: earliestExpirationDate)) 到期"
    }

    init(response: RateLimitResetCreditsResponse) {
        availableCount = max(0, response.availableCount)
        earliestExpirationDate = response.credits?
            .filter { $0.status == nil || $0.status == "available" }
            .compactMap { credit in
                guard let value = credit.expiresAt else {
                    return nil
                }
                let seconds = value > 10_000_000_000 ? value / 1000 : value
                return Date(timeIntervalSince1970: seconds)
            }
            .min()
    }
}

struct TokenUsageSummary: Equatable {
    let yesterdayTokens: Int
    let cumulativeTokens: Int

    var yesterdayText: String {
        "昨日 \(Self.formatAsWan(yesterdayTokens))"
    }

    var cumulativeText: String {
        "累计 \(Self.formatAsYi(cumulativeTokens))"
    }

    private static func formatAsWan(_ tokens: Int) -> String {
        let value = Double(tokens) / 10_000
        return "\(formatted(value)) 万"
    }

    private static func formatAsYi(_ tokens: Int) -> String {
        let value = Double(tokens) / 100_000_000
        return "\(formatted(value)) 亿"
    }

    private static func formatted(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        }
        if value >= 10 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
}
