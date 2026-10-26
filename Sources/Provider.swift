import Darwin
import Foundation

// Each read uses the installed official CLI. No tokens are copied or logged,
// no inference turns are created, and no server is kept resident by this app.
final class QuotaProvider {
  private let lock = NSLock()
  private var active: Process?

  static func cliURL(override: String?) -> URL? {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let candidates = [
      override ?? "", "\(home)/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex",
      "\(home)/.codex/packages/standalone/current/bin/codex",
      "/Applications/Codex.app/Contents/Resources/codex",
    ]
    return candidates.first { !$0.isEmpty && FileManager.default.isExecutableFile(atPath: $0) }.map
    { URL(fileURLWithPath: $0) }
  }

  func cancel() {
    lock.lock()
    let process = active
    lock.unlock()
    if let process = process, process.isRunning { process.terminate() }
  }

  func read(cli: URL) throws -> QuotaSnapshot {
    let process = Process()
    let input = Pipe()
    let output = Pipe()
    process.executableURL = cli
    process.arguments = ["app-server", "--listen", "stdio://", "-c", "analytics.enabled=false"]
    process.standardInput = input
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
    var environment = ProcessInfo.processInfo.environment
    environment["RUST_LOG"] = "off"
    process.environment = environment
    try process.run()
    lock.lock()
    active = process
    lock.unlock()
    // Close the parent's copies of the child-only pipe ends.
    try? input.fileHandleForReading.close()
    try? output.fileHandleForWriting.close()
    defer {
      try? input.fileHandleForWriting.close()
      let grace = Date().addingTimeInterval(0.7)
      while process.isRunning && Date() < grace { Thread.sleep(forTimeInterval: 0.02) }
      if process.isRunning { process.terminate() }
      let deadline = Date().addingTimeInterval(0.5)
      while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
      if process.isRunning { kill(process.processIdentifier, SIGKILL) }
      process.waitUntilExit()
      try? output.fileHandleForReading.close()
      lock.lock()
      active = nil
      lock.unlock()
    }
    func send(_ object: [String: Any]) throws {
      var bytes = try JSONSerialization.data(withJSONObject: object)
      bytes.append(10)
      try input.fileHandleForWriting.write(contentsOf: bytes)
    }
    try send([
      "id": 1, "method": "initialize",
      "params": [
        "clientInfo": ["name": "codexvolt", "title": "CodexVolt", "version": "1.0.0"]
      ],
    ])
    let deadline = Date().addingTimeInterval(18)
    var buffer = Data()
    var bytes = [UInt8](repeating: 0, count: 16384)
    var initialized = false
    while Date() < deadline {
      var fd = pollfd(
        fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
      let ready = poll(&fd, 1, 250)
      if ready < 0 {
        if errno == EINTR { continue }
        throw MeterError.unavailable
      }
      if ready == 0 {
        if !process.isRunning { throw MeterError.unavailable }
        continue
      }
      let n = Darwin.read(fd.fd, &bytes, bytes.count)
      guard n > 0 else { throw MeterError.unavailable }
      buffer.append(contentsOf: bytes.prefix(n))
      guard buffer.count < 524288 else { throw MeterError.protocolError }
      while let newline = buffer.firstIndex(of: 10) {
        let line = buffer.prefix(upTo: newline)
        buffer.removeSubrange(...newline)
        guard let message = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else {
          continue
        }
        if let method = message["method"] as? String, let requestID = message["id"] {
          // Do not authorize any server-requested action.
          try send([
            "id": requestID,
            "error": [
              "code": -32601, "message": "Read-only quota client does not handle \(method)",
            ],
          ])
          continue
        }
        guard let id = message["id"] as? Int else { continue }
        if message["error"] != nil { throw MeterError.unavailable }
        if id == 1 && !initialized {
          initialized = true
          try send(["method": "initialized"])
          try send(["id": 2, "method": "account/rateLimits/read"])
        } else if id == 2, let result = message["result"] as? [String: Any] {
          return try QuotaSnapshot.parse(result)
        }
      }
    }
    throw MeterError.timeout
  }
}
