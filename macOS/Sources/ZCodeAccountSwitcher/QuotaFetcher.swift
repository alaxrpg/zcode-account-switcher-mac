import Foundation

public struct QuotaFetcher {
    private static let quotaURLs = [
        URL(string: "https://open.bigmodel.cn/api/monitor/usage/quota/limit")!,
        URL(string: "https://api.z.ai/api/monitor/usage/quota/limit")!
    ]

    public static func fetchQuota(credentials: [String: String]?, configData: Data?) async -> QuotaSnapshot {
        var candidateAuths: [(header: String, url: URL)] = []

        if let creds = credentials {
            if let bigmodelToken = creds["oauth:bigmodel:access_token"], !bigmodelToken.isEmpty {
                candidateAuths.append(("Bearer \(bigmodelToken)", quotaURLs[0]))
            }
            if let zaiToken = creds["oauth:zai:access_token"], !zaiToken.isEmpty {
                candidateAuths.append(("Bearer \(zaiToken)", quotaURLs[1]))
            }
            if let jwtToken = creds["zcodejwttoken"], !jwtToken.isEmpty {
                candidateAuths.append(("Bearer \(jwtToken)", quotaURLs[0]))
            }
        }

        if let data = configData,
           let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let providers = dict["provider"] as? [String: [String: Any]] {
            for (id, provider) in providers {
                if let options = provider["options"] as? [String: Any],
                   let apiKey = options["apiKey"] as? String,
                   !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    let url = id.contains("zai") ? quotaURLs[1] : quotaURLs[0]
                    let header = key.hasPrefix("eyJ") ? "Bearer \(key)" : key
                    candidateAuths.append((header, url))
                }
            }
        }

        for candidate in candidateAuths {
            if let snapshot = await performRequest(header: candidate.header, url: candidate.url) {
                return snapshot
            }
        }

        return QuotaSnapshot(available: false, level: nil, items: [])
    }

    private static func performRequest(header: String, url: URL) async -> QuotaSnapshot? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(header, forHTTPHeaderField: "authorization")
        request.setValue(header, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 7.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }
            return parseResponseData(data)
        } catch {
            return nil
        }
    }

    private static func parseResponseData(_ data: Data) -> QuotaSnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = root["code"] as? Int, code == 200,
              let dataDict = root["data"] as? [String: Any],
              let limits = dataDict["limits"] as? [[String: Any]] else {
            return nil
        }

        let level = (dataDict["level"] as? String)?.lowercased() ?? "pro"

        var tokensLimits: [[String: Any]] = []
        var timeLimits: [[String: Any]] = []

        for limit in limits {
            if let type = limit["type"] as? String {
                if type == "TOKENS_LIMIT" {
                    tokensLimits.append(limit)
                } else if type == "TIME_LIMIT" || type == "TOOL_LIMIT" {
                    timeLimits.append(limit)
                }
            }
        }

        // 1. 5 小时 Prompt 池
        let fiveHourDict = tokensLimits.first { dict in
            let unit = dict["unit"] as? Int ?? 0
            let number = dict["number"] as? Int ?? 0
            return unit == 3 || number == 5
        } ?? tokensLimits.first

        // 2. 每周额度
        let weeklyDict = tokensLimits.first { dict in
            let unit = dict["unit"] as? Int ?? 0
            let number = dict["number"] as? Int ?? 0
            return (unit == 6 || number == 1 || number == 7) && dict["nextResetTime"] as? Int64 != fiveHourDict?["nextResetTime"] as? Int64
        } ?? (tokensLimits.count > 1 ? tokensLimits[1] : nil)

        // 3. 工具调用
        let toolDict = timeLimits.first

        var items: [QuotaLimitItem] = []

        if let dict = fiveHourDict {
            let pct = dict["percentage"] as? Int ?? 0
            let resetMs = (dict["nextResetTime"] as? NSNumber)?.int64Value
            items.append(QuotaLimitItem(
                key: "fiveHour",
                label: "5 小时",
                percentage: pct,
                resetTime: formatResetTime(resetMs),
                colorName: "blue"
            ))
        }

        if let dict = weeklyDict {
            let pct = dict["percentage"] as? Int ?? 0
            let resetMs = (dict["nextResetTime"] as? NSNumber)?.int64Value
            items.append(QuotaLimitItem(
                key: "weekly",
                label: "每周",
                percentage: pct,
                resetTime: formatResetTime(resetMs),
                colorName: "green"
            ))
        }

        if let dict = toolDict {
            let pct = dict["percentage"] as? Int ?? 0
            let resetMs = (dict["nextResetTime"] as? NSNumber)?.int64Value
            items.append(QuotaLimitItem(
                key: "monthlyTool",
                label: "工具调用",
                percentage: pct,
                resetTime: formatResetTime(resetMs),
                colorName: "purple"
            ))
        }

        return QuotaSnapshot(available: !items.isEmpty, level: level, items: items)
    }

    private static func formatResetTime(_ timestampMs: Int64?) -> String? {
        guard let ms = timestampMs, ms > 0 else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            return formatter.string(from: date)
        }
    }
}
