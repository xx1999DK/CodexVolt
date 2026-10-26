import AppKit

if CommandLine.arguments.contains("--probe") {
  signal(SIGPIPE, SIG_IGN)
  guard let cli = QuotaProvider.cliURL(override: nil) else {
    print("Codex CLI not found")
    exit(1)
  }
  do {
    let start = Date()
    let snapshot = try QuotaProvider().read(cli: cli)
    let selected = snapshot.selection(bucket: "codex", window: "auto")
    print(
      "remaining=\(selected?.percentage ?? -1) window=\(selected?.label ?? "unknown") duration=\(String(format:"%.2f",Date().timeIntervalSince(start)))s"
    )
    exit(0)
  } catch {
    print(error.localizedDescription)
    exit(1)
  }
}
if let index = CommandLine.arguments.firstIndex(of: "--export-previews"),
  CommandLine.arguments.count > index + 1
{
  _ = NSApplication.shared
  let root = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  for theme in MeterTheme.allCases {
    for value in [0, 8, 20, 73, 100] {
      try IconPainter.exportPNG(
        theme: theme, percent: value,
        to: root.appendingPathComponent("\(theme.rawValue)-\(value).png"))
    }
  }
  print("Exported \(MeterTheme.allCases.count) themes, 5 states each")
  exit(0)
}
let app = NSApplication.shared
let delegate = MeterApp()
app.delegate = delegate
app.run()
