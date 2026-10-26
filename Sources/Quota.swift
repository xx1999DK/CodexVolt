import CoreFoundation
import Foundation

struct QuotaWindow: Equatable {
  let key: String
  let used: Double
  let minutes: Int?
  let reset: Date?
  var remaining: Double { min(100, max(0, 100 - used)) }
  var percentage: Int { Int(remaining.rounded(.down)) }
  var label: String {
    guard let minutes = minutes, minutes > 0 else { return key == "primary" ? "主额度" : "次额度" }
    if minutes == 10080 { return "周额度" }
    if minutes % 1440 == 0 { return "\(minutes / 1440) 天额度" }
    if minutes % 60 == 0 { return "\(minutes / 60) 小时额度" }
    return "\(minutes) 分钟额度"
  }
}

struct QuotaBucket {
  let id: String
  let name: String
  let windows: [QuotaWindow]
}

struct QuotaSnapshot {
  let fetchedAt: Date
  let buckets: [QuotaBucket]
  func bucket(_ preferred: String) -> QuotaBucket? {
    buckets.first { $0.id == preferred } ?? buckets.first { $0.id == "codex" } ?? buckets.first
  }
  func selection(bucket: String, window: String) -> QuotaWindow? {
    guard let windows = self.bucket(bucket)?.windows else { return nil }
    if window != "auto", let explicit = windows.first(where: { $0.key == window }) {
      return explicit
    }
    return windows.min { $0.remaining < $1.remaining }
  }
  func isStale(at now: Date = Date(), interval: Double, selection: QuotaWindow?) -> Bool {
    if now.timeIntervalSince(fetchedAt) > max(90, interval * 3) { return true }
    return selection?.reset.map { $0 <= now } ?? false
  }
  static func parse(_ result: [String: Any], now: Date = Date()) throws -> QuotaSnapshot {
    func number(_ x: Any?) -> Double? {
      guard let value = x as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
        value.doubleValue.isFinite
      else { return nil }
      return value.doubleValue
    }
    var raw: [String: Any] = [:]
    if let map = result["rateLimitsByLimitId"] as? [String: Any], !map.isEmpty {
      raw = map
    } else if let legacy = result["rateLimits"] as? [String: Any] {
      raw[legacy["limitId"] as? String ?? "codex"] = legacy
    }
    var buckets: [QuotaBucket] = []
    for (id, item) in raw {
      guard let object = item as? [String: Any] else { continue }
      var windows: [QuotaWindow] = []
      for key in ["primary", "secondary"] {
        guard let value = object[key] as? [String: Any], let used = number(value["usedPercent"])
        else { continue }
        let duration = number(value["windowDurationMins"]).flatMap {
          $0 > 0 && $0 < 10_000_000 ? Int($0) : nil
        }
        let reset = number(value["resetsAt"]).flatMap {
          $0 > 0 ? Date(timeIntervalSince1970: $0) : nil
        }
        windows.append(QuotaWindow(key: key, used: used, minutes: duration, reset: reset))
      }
      buckets.append(
        QuotaBucket(
          id: id, name: object["limitName"] as? String ?? (id == "codex" ? "Codex" : id),
          windows: windows))
    }
    guard !buckets.isEmpty else { throw MeterError.noQuota }
    return QuotaSnapshot(fetchedAt: now, buckets: buckets.sorted { $0.id < $1.id })
  }
}

enum MeterError: LocalizedError {
  case missingCLI, timeout, noQuota, unavailable, protocolError
  var errorDescription: String? {
    switch self {
    case .missingCLI: return "未找到 Codex CLI，请在设置中选择路径。"
    case .timeout: return "额度查询超时，稍后会自动重试。"
    case .noQuota: return "账户未返回可用额度，请检查 Codex 登录状态。"
    case .unavailable: return "额度暂不可用，请确认 Codex 已登录且网络正常。"
    case .protocolError: return "Codex 返回的数据无法识别，请更新 Codex。"
    }
  }
}
