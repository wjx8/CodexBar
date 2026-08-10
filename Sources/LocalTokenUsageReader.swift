import Foundation

enum LocalTokenUsageReader {
    private static let sessionDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/sessions", isDirectory: true)

    static func read() -> TokenUsageSummary? {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let calendar = Calendar.current
        guard
            let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())),
            let yesterdayEnd = calendar.date(byAdding: .day, value: 1, to: yesterdayStart)
        else {
            return nil
        }

        var yesterdayTokens = 0
        var cumulativeTokens = 0

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else {
                continue
            }

            let fileUsage = readUsage(
                from: fileURL,
                yesterdayStart: yesterdayStart,
                yesterdayEnd: yesterdayEnd
            )
            yesterdayTokens += fileUsage.yesterdayTokens
            cumulativeTokens += fileUsage.finalTotalTokens
        }

        return TokenUsageSummary(
            yesterdayTokens: yesterdayTokens,
            cumulativeTokens: cumulativeTokens
        )
    }

    private static func readUsage(
        from fileURL: URL,
        yesterdayStart: Date,
        yesterdayEnd: Date
    ) -> (yesterdayTokens: Int, finalTotalTokens: Int) {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return (0, 0)
        }

        var yesterdayTokens = 0
        var finalTotalTokens = 0

        for line in contents.split(separator: "\n", omittingEmptySubsequences: true) {
            guard line.range(of: "\"token_count\"") != nil else {
                continue
            }

            let data = Data(line.utf8)
            guard
                let object = try? JSONSerialization.jsonObject(with: data),
                let event = object as? [String: Any],
                let payload = event["payload"] as? [String: Any],
                payload["type"] as? String == "token_count",
                let info = payload["info"] as? [String: Any]
            else {
                continue
            }

            if let totalUsage = info["total_token_usage"] as? [String: Any],
               let totalTokens = intValue(totalUsage["total_tokens"]) {
                finalTotalTokens = totalTokens
            }

            guard
                let timestampString = event["timestamp"] as? String,
                let timestamp = parseDate(timestampString),
                timestamp >= yesterdayStart,
                timestamp < yesterdayEnd,
                let lastUsage = info["last_token_usage"] as? [String: Any],
                let lastTokens = intValue(lastUsage["total_tokens"])
            else {
                continue
            }

            yesterdayTokens += lastTokens
        }

        return (yesterdayTokens, finalTotalTokens)
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let double = value as? Double {
            return Int(double)
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }
}
