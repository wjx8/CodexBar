import Foundation

/// 用户可调的应用设置（UserDefaults 持久化），与 APIKeyStore 同一模式。
/// 读取时做下限钳制，设置界面与 defaults write 两条修改路径都被覆盖。
enum AppSettings {
    static let quotaIntervalKey = "interval.quotaSeconds"
    static let balanceIntervalKey = "interval.balanceSeconds"

    static let defaultQuotaInterval = 60
    static let defaultBalanceInterval = 600

    /// 额度刷新预设档位（秒）：30秒 / 1 / 2 / 5 分钟
    static let quotaChoices = [30, 60, 120, 300]

    /// 余额刷新预设档位（秒）：1 / 2 / 3 / 4 / 5 / 10 / 15 / 20 / 25 / 30 / 60 分钟
    static let balanceChoices = [60, 120, 180, 240, 300, 600, 900, 1200, 1500, 1800, 3600]

    static var quotaInterval: Int {
        max(saved(quotaIntervalKey, fallback: defaultQuotaInterval), 30)
    }

    static var balanceInterval: Int {
        max(saved(balanceIntervalKey, fallback: defaultBalanceInterval), 60)
    }

    static func saveQuotaInterval(_ seconds: Int) {
        UserDefaults.standard.set(max(seconds, 30), forKey: quotaIntervalKey)
    }

    static func saveBalanceInterval(_ seconds: Int) {
        UserDefaults.standard.set(max(seconds, 60), forKey: balanceIntervalKey)
    }

    static func intervalTitle(_ seconds: Int) -> String {
        seconds >= 60 && seconds % 60 == 0 ? "\(seconds / 60)分钟" : "\(seconds)秒"
    }

    private static func saved(_ key: String, fallback: Int) -> Int {
        let value = UserDefaults.standard.integer(forKey: key)
        return value == 0 ? fallback : value
    }
}
