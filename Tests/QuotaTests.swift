import Foundation

@main struct QuotaTests {
  static func main() throws {
    var checks = 0
    func expect(_ condition: Bool, _ label: String) {
      precondition(condition, label)
      checks += 1
    }
    func parse(_ json: String) throws -> QuotaSnapshot {
      try QuotaSnapshot.parse(
        JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any],
        now: Date(timeIntervalSince1970: 1000))
    }
    let dual = try parse(
      """
      {"rateLimits":{"primary":{"usedPercent":99}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":23,"windowDurationMins":300,"resetsAt":2000},"secondary":{"usedPercent":61,"windowDurationMins":10080,"resetsAt":3000}},"other":{"primary":{"usedPercent":5}}}}
      """)
    expect(
      dual.selection(bucket: "codex", window: "auto")?.percentage == 39,
      "Automatic selection must use the smaller remainder")
    expect(
      dual.selection(bucket: "codex", window: "primary")?.percentage == 77,
      "Map must take precedence over legacy")
    expect(dual.selection(bucket: "codex", window: "primary")?.label == "5 小时额度", "Duration label")
    expect(dual.selection(bucket: "codex", window: "secondary")?.label == "周额度", "Weekly label")
    expect(dual.selection(bucket: "missing", window: "auto")?.percentage == 39, "Bucket fallback")
    let weekly = try parse(
      """
      {"rateLimits":{"limitId":"codex","primary":{"usedPercent":1,"windowDurationMins":10080},"secondary":null}}
      """)
    expect(
      weekly.selection(bucket: "codex", window: "auto")?.percentage == 99, "Single weekly quota")
    let unknown = try parse(
      """
      {"rateLimits":{"primary":{"usedPercent":null},"secondary":{"usedPercent":true}}}
      """)
    expect(
      unknown.selection(bucket: "codex", window: "auto") == nil,
      "Null and boolean usage must be unknown, never full")
    let clamp = try parse(
      """
      {"rateLimits":{"primary":{"usedPercent":120},"secondary":{"usedPercent":-3}}}
      """)
    expect(clamp.selection(bucket: "codex", window: "primary")?.percentage == 0, "Clamp exhausted")
    expect(
      clamp.selection(bucket: "codex", window: "secondary")?.percentage == 100, "Clamp upper bound")
    let partial = try parse(
      """
      {"rateLimits":{"primary":{"usedPercent":33.8}}}
      """)
    expect(
      partial.selection(bucket: "codex", window: "auto")?.percentage == 66,
      "Do not overstate fractional remaining")
    expect(
      dual.isStale(
        at: Date(timeIntervalSince1970: 1100), interval: 30,
        selection: dual.selection(bucket: "codex", window: "primary")), "Old cache must be stale")
    expect(
      !dual.isStale(
        at: Date(timeIntervalSince1970: 1020), interval: 30,
        selection: dual.selection(bucket: "codex", window: "primary")), "Fresh response")
    expect(
      dual.isStale(
        at: Date(timeIntervalSince1970: 2001), interval: 1000,
        selection: dual.selection(bucket: "codex", window: "primary")),
      "Reset timestamp must not imply fabricated 100%")
    do {
      _ = try parse("{}")
      fatalError("Missing rates must fail")
    } catch MeterError.noQuota { checks += 1 }
    print("Passed \(checks) quota parsing and freshness checks")
  }
}
