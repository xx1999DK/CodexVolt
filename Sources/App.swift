import AppKit
import ServiceManagement

final class ThemeCard: NSButton {
  let theme: MeterTheme
  var chosen = false {
    didSet {
      if chosen != oldValue { needsDisplay = true }
      setAccessibilityLabel("\(theme.name)，\(theme.subtitle)\(chosen ? "，已选择" : "")")
    }
  }
  var percentage: Int? = 73 { didSet { if percentage != oldValue { needsDisplay = true } } }
  init(theme: MeterTheme, frame: NSRect) {
    self.theme = theme
    super.init(frame: frame)
    title = theme.name
    isBordered = false
    setButtonType(.momentaryChange)
    setAccessibilityLabel("\(theme.name)，\(theme.subtitle)")
    toolTip = theme.subtitle
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override var isFlipped: Bool { false }
  override func draw(_ dirtyRect: NSRect) {
    let rect = bounds.insetBy(dx: 1, dy: 1)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 13, yRadius: 13)
    (chosen ? NSColor.controlAccentColor.withAlphaComponent(0.1) : NSColor.controlBackgroundColor)
      .setFill()
    shape.fill()
    (chosen ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
    shape.lineWidth = chosen ? 2 : 0.7
    shape.stroke()
    let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    IconPainter.image(theme: theme, percent: percentage, dark: dark).draw(
      in: NSRect(x: 14, y: 30, width: 108, height: 44))
    let name = theme.name + (chosen ? " ✓" : "")
    (name as NSString).draw(
      at: NSPoint(x: 133, y: 58),
      withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: NSColor.labelColor,
      ])
    let pieces = theme.subtitle.components(separatedBy: " · ")
    for (i, piece) in pieces.enumerated() {
      (piece as NSString).draw(
        at: NSPoint(x: 133, y: 38 - CGFloat(i) * 15),
        withAttributes: [
          .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor,
        ])
    }
  }
}

final class MeterApp: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
  private var item: NSStatusItem!
  private let provider = QuotaProvider()
  private let defaults = UserDefaults.standard
  private var snapshot: QuotaSnapshot?
  private var lastError: String?
  private var fetching = false
  private var failures = 0
  private var sleeping = false
  private var suspended = false
  private var timer: Timer?
  private var observers: [NSObjectProtocol] = []
  private var appearanceObserver: NSKeyValueObservation?
  private var gallery: NSWindow?
  private var cards: [ThemeCard] = []
  private var galleryLabel: NSTextField?
  private var lastDrawKey = ""
  private var terminated = false

  private var theme: MeterTheme {
    MeterTheme(rawValue: defaults.string(forKey: "theme") ?? "aurora") ?? .aurora
  }
  private var compact: Bool { defaults.bool(forKey: "compact") }
  private var interval: Double {
    let i = defaults.double(forKey: "interval")
    return [15.0, 30, 60, 300].contains(i) ? i : 30
  }
  private var bucketID: String { defaults.string(forKey: "bucket") ?? "codex" }
  private var windowKey: String { defaults.string(forKey: "window") ?? "auto" }
  private var selected: QuotaWindow? { snapshot?.selection(bucket: bucketID, window: windowKey) }
  private var stale: Bool {
    lastError != nil || suspended
      || (snapshot?.isStale(interval: interval, selection: selected) ?? false)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Preserve appearance choices from the original local prototype, once.
    if !defaults.bool(forKey: "migratedPrototypePreferences") {
      if let old = defaults.persistentDomain(forName: "local.codex.meter") {
        for key in ["theme", "compact", "interval", "bucket", "window", "cliPath"] {
          if defaults.object(forKey: key) == nil, let value = old[key] {
            defaults.set(value, forKey: key)
          }
        }
      }
      defaults.set(true, forKey: "migratedPrototypePreferences")
    }
    signal(SIGPIPE, SIG_IGN)
    let others = NSRunningApplication.runningApplications(
      withBundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.xx1999DK.CodexVolt"
    ).filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    if !others.isEmpty {
      NSApp.terminate(nil)
      return
    }
    NSApp.setActivationPolicy(.accessory)
    item = NSStatusBar.system.statusItem(withLength: compact ? 50 : 58)
    item.autosaveName = "CodexVolt"
    item.isVisible = true
    if let button = item.button {
      button.target = self
      button.action = #selector(showMenu(_:))
      button.setAccessibilityLabel("Codex 额度电池")
    }
    appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
      DispatchQueue.main.async { self?.redraw(force: true) }
    }
    let center = NSWorkspace.shared.notificationCenter
    observers.append(
      center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) {
        [weak self] _ in
        self?.sleeping = true
        self?.timer?.invalidate()
        self?.provider.cancel()
      })
    observers.append(
      center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) {
        [weak self] _ in
        self?.sleeping = false
        self?.refresh()
      })
    observers.append(
      NotificationCenter.default.addObserver(
        forName: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil, queue: .main
      ) { [weak self] _ in self?.schedule() })
    redraw(force: true)
    refresh()
    if CommandLine.arguments.contains("--gallery") { showGallery(nil) }
  }

  func applicationWillTerminate(_ notification: Notification) {
    terminated = true
    timer?.invalidate()
    provider.cancel()
    appearanceObserver = nil
    for observer in observers {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
      NotificationCenter.default.removeObserver(observer)
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showGallery(nil)
    return true
  }

  private func schedule() {
    timer?.invalidate()
    guard !sleeping && !suspended && !terminated else { return }
    var delay = interval
    if ProcessInfo.processInfo.isLowPowerModeEnabled { delay = max(delay, 120) }
    if failures > 0 { delay = min(300, max(delay, 30) * pow(2, Double(min(failures - 1, 4)))) }
    let t = Timer(timeInterval: delay, repeats: false) { [weak self] _ in self?.refresh() }
    t.tolerance = min(5, delay * 0.1)
    RunLoop.main.add(t, forMode: .common)
    timer = t
  }

  private func refresh() {
    guard !fetching && !sleeping && !suspended && !terminated else { return }
    timer?.invalidate()
    guard let cli = QuotaProvider.cliURL(override: defaults.string(forKey: "cliPath")) else {
      lastError = MeterError.missingCLI.localizedDescription
      failures += 1
      redraw()
      schedule()
      return
    }
    fetching = true
    DispatchQueue.global(qos: .utility).async { [weak self] in
      guard let self = self else { return }
      let result = Result { try self.provider.read(cli: cli) }
      DispatchQueue.main.async {
        self.fetching = false
        guard !self.terminated else { return }
        switch result {
        case .success(let value):
          self.snapshot = value
          self.lastError = nil
          self.failures = 0
        case .failure(let error):
          if !self.sleeping {
            self.lastError =
              (error as? MeterError)?.localizedDescription
              ?? MeterError.unavailable.localizedDescription
            self.failures += 1
          }
        }
        self.redraw()
        self.schedule()
      }
    }
  }

  private func redraw(force: Bool = false) {
    guard item != nil else { return }
    let dark = item.button?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    let percent = selected?.percentage
    let key = "\(theme.rawValue):\(percent ?? -1):\(stale):\(dark):\(compact)"
    if force || key != lastDrawKey {
      item.length = compact ? 50 : 58
      item.button?.image = IconPainter.image(
        theme: theme, percent: percent, stale: stale, dark: dark, compact: compact)
      lastDrawKey = key
    }
    var detail = "Codex · \(selected?.label ?? "额度") · 剩余 \(percent.map { "\($0)%" } ?? "未知")"
    if let date = selected?.reset { detail += "\n重置：\(formatted(date))" }
    if stale { detail += "\n数据待更新" }
    if let error = lastError { detail += "\n\(error)" }
    item.button?.toolTip = detail
    item.button?.setAccessibilityValue(detail)
    for card in cards {
      card.chosen = card.theme == theme
      card.percentage = percent
    }
    galleryLabel?.stringValue =
      "\(selected?.label ?? "额度")剩余 \(percent.map { "\($0)%" } ?? "—") · 单击切换，自动保存\(stale ? " · 数据待更新" : "")"
  }

  private func formatted(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "M月d日 HH:mm"
    return f.string(from: date)
  }
  private func row(
    _ text: String, action: Selector? = nil, represented: Any? = nil, checked: Bool = false
  ) -> NSMenuItem {
    let row = NSMenuItem(title: text, action: action, keyEquivalent: "")
    row.target = self
    row.representedObject = represented
    row.isEnabled = action != nil
    row.state = checked ? .on : .off
    return row
  }
  private func group(_ title: String, items: [NSMenuItem]) -> NSMenuItem {
    let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    let submenu = NSMenu(title: title)
    items.forEach { submenu.addItem($0) }
    entry.submenu = submenu
    return entry
  }

  @objc private func showMenu(_ sender: Any?) {
    redraw()
    let menu = NSMenu(title: "CodexVolt")
    menu.delegate = self
    let heading = row("CodexVolt  ·  剩余额度")
    heading.attributedTitle = NSAttributedString(
      string: heading.title, attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)])
    menu.addItem(heading)
    if let b = snapshot?.bucket(bucketID) {
      if b.windows.isEmpty { menu.addItem(row("该账户未提供百分比额度")) }
      for window in b.windows {
        menu.addItem(row("\(window.label)    \(window.percentage)% 剩余"))
        if let reset = window.reset { menu.addItem(row("    重置于 \(formatted(reset))")) }
      }
    } else {
      menu.addItem(row(fetching ? "正在读取额度…" : "暂无额度数据"))
    }
    if let date = snapshot?.fetchedAt {
      let ago = max(0, Int(Date().timeIntervalSince(date)))
      menu.addItem(row("\(stale ? "待更新 · " : "")\(ago < 60 ? "\(ago) 秒前更新" : "\(ago/60) 分钟前更新")"))
    }
    if let error = lastError { menu.addItem(row(error)) }
    menu.addItem(.separator())
    let refreshItem = row(fetching ? "正在刷新…" : "立即刷新", action: #selector(manualRefresh(_:)))
    refreshItem.isEnabled = !fetching
    menu.addItem(refreshItem)
    menu.addItem(row("打开 Codex", action: #selector(openCodex(_:))))
    menu.addItem(.separator())
    menu.addItem(row("浏览全部 10 款外观…", action: #selector(showGallery(_:))))
    menu.addItem(
      group(
        "外观 · \(theme.name)",
        items: MeterTheme.allCases.map { style in
          let entry = row(
            style.name, action: #selector(selectTheme(_:)), represented: style.rawValue,
            checked: style == theme)
          entry.image = IconPainter.image(
            theme: style, percent: selected?.percentage ?? 73,
            dark: item.button?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
          return entry
        }))
    menu.addItem(
      group(
        "显示额度",
        items: [
          row(
            "自动 · 显示剩余最少的窗口", action: #selector(selectWindow(_:)), represented: "auto",
            checked: windowKey == "auto")
        ]
          + (snapshot?.bucket(bucketID)?.windows ?? []).map {
            row(
              $0.label, action: #selector(selectWindow(_:)), represented: $0.key,
              checked: windowKey == $0.key)
          }))
    if let buckets = snapshot?.buckets, buckets.count > 1 {
      menu.addItem(
        group(
          "额度分组",
          items: buckets.map {
            row(
              $0.name, action: #selector(selectBucket(_:)), represented: $0.id,
              checked: snapshot?.bucket(bucketID)?.id == $0.id)
          }))
    }
    menu.addItem(
      group(
        "刷新间隔",
        items: [15, 30, 60, 300].map { seconds in
          row(
            seconds == 300 ? "5 分钟 · 节能" : "\(seconds) 秒\(seconds == 30 ? " · 默认" : "")",
            action: #selector(selectInterval(_:)), represented: seconds,
            checked: Int(interval) == seconds)
        }))
    menu.addItem(row("紧凑图标", action: #selector(toggleCompact(_:)), checked: compact))
    menu.addItem(row(suspended ? "继续自动刷新" : "暂停自动刷新", action: #selector(togglePause(_:))))
    let loginOn = SMAppService.mainApp.status == .enabled
    menu.addItem(row("登录时启动", action: #selector(toggleLogin(_:)), checked: loginOn))
    menu.addItem(
      group(
        "更多",
        items: [
          row("选择 Codex CLI…", action: #selector(chooseCLI(_:))),
          row("恢复 CLI 自动检测", action: #selector(resetCLI(_:))),
          row("关于 CodexVolt…", action: #selector(about(_:))),
        ]))
    menu.addItem(.separator())
    menu.addItem(row("退出 CodexVolt", action: #selector(quit(_:))))
    if let source = sender as? NSButton, source !== item.button {
      menu.popUp(positioning: nil, at: NSPoint(x: 0, y: source.bounds.maxY + 4), in: source)
    } else {
      item.menu = menu
      item.button?.performClick(nil)
    }
  }

  func menuDidClose(_ menu: NSMenu) { item.menu = nil }
  @objc private func manualRefresh(_ sender: Any?) {
    suspended = false
    refresh()
  }
  @objc private func selectTheme(_ sender: NSMenuItem) {
    if let value = sender.representedObject as? String {
      defaults.set(value, forKey: "theme")
      redraw()
    }
  }
  @objc private func selectWindow(_ sender: NSMenuItem) {
    defaults.set(sender.representedObject, forKey: "window")
    redraw()
  }
  @objc private func selectBucket(_ sender: NSMenuItem) {
    defaults.set(sender.representedObject, forKey: "bucket")
    defaults.set("auto", forKey: "window")
    redraw()
  }
  @objc private func selectInterval(_ sender: NSMenuItem) {
    defaults.set(sender.representedObject, forKey: "interval")
    schedule()
  }
  @objc private func toggleCompact(_ sender: Any?) {
    defaults.set(!compact, forKey: "compact")
    redraw()
  }
  @objc private func togglePause(_ sender: Any?) {
    suspended.toggle()
    if suspended { timer?.invalidate() } else { refresh() }
    redraw()
  }
  @objc private func openCodex(_ sender: Any?) {
    let candidates = ["com.openai.codex", "com.openai.chat"]
    for id in candidates {
      if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        return
      }
    }
    let panel = NSOpenPanel()
    panel.title = "选择 Codex 应用"
    panel.directoryURL = URL(fileURLWithPath: "/Applications")
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    NSApp.activate(ignoringOtherApps: true)
    if panel.runModal() == .OK, let url = panel.url {
      NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
  }
  @objc private func chooseCLI(_ sender: Any?) {
    let panel = NSOpenPanel()
    panel.title = "选择 codex 可执行文件"
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.showsHiddenFiles = true
    panel.allowsMultipleSelection = false
    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      ".local/bin")
    NSApp.activate(ignoringOtherApps: true)
    if panel.runModal() == .OK, let path = panel.url?.path,
      FileManager.default.isExecutableFile(atPath: path)
    {
      defaults.set(path, forKey: "cliPath")
      refresh()
    }
  }
  @objc private func resetCLI(_ sender: Any?) {
    defaults.removeObject(forKey: "cliPath")
    refresh()
  }
  @objc private func toggleLogin(_ sender: Any?) {
    do {
      if SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
      } else {
        try SMAppService.mainApp.register()
      }
    } catch { alert("登录启动设置未完成", text: "可在系统设置 → 通用 → 登录项中检查。\n\(error.localizedDescription)") }
  }
  private func alert(_ title: String, text: String) {
    NSApp.activate(ignoringOtherApps: true)
    let a = NSAlert()
    a.messageText = title
    a.informativeText = text
    a.addButton(withTitle: "好")
    a.runModal()
  }
  @objc private func about(_ sender: Any?) {
    alert(
      "CodexVolt 1.0",
      text:
        "10 款原生额度图标\n默认每 30 秒读取一次 Codex 官方额度，点击可立即刷新。低电量模式至少间隔 2 分钟，睡眠时暂停。\n\n百分比表示套餐窗口剩余量；橙点表示数据待更新。使用现有 Codex CLI 登录，不保存密码或令牌，不发起模型对话。\n\nMIT 开源 · github.com/xx1999DK/CodexVolt"
    )
  }
  @objc private func quit(_ sender: Any?) { NSApp.terminate(nil) }

  @objc func showGallery(_ sender: Any?) {
    if let gallery = gallery {
      NSApp.activate(ignoringOtherApps: true)
      gallery.makeKeyAndOrderFront(nil)
      return
    }
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 650),
      styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    window.title = "CodexVolt · 10 款外观"
    window.isReleasedWhenClosed = false
    window.delegate = self
    let content = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 650))
    window.contentView = content
    let title = NSTextField(labelWithString: "给额度，换一种心情。")
    title.font = .systemFont(ofSize: 23, weight: .semibold)
    title.frame = NSRect(x: 24, y: 598, width: 510, height: 33)
    content.addSubview(title)
    let label = NSTextField(labelWithString: "")
    label.font = .systemFont(ofSize: 12)
    label.textColor = .secondaryLabelColor
    label.frame = NSRect(x: 24, y: 571, width: 512, height: 24)
    content.addSubview(label)
    galleryLabel = label
    cards = []
    for (index, style) in MeterTheme.allCases.enumerated() {
      let col = index % 2
      let row = index / 2
      let card = ThemeCard(
        theme: style, frame: NSRect(x: 24 + col * 262, y: 454 - row * 104, width: 250, height: 96))
      card.target = self
      card.action = #selector(cardSelected(_:))
      content.addSubview(card)
      cards.append(card)
    }
    let foot = NSTextField(labelWithString: "外观切换不影响额度 · 设置自动保存")
    foot.font = .systemFont(ofSize: 11)
    foot.textColor = .secondaryLabelColor
    foot.frame = NSRect(x: 24, y: 12, width: 370, height: 20)
    content.addSubview(foot)
    let settings = NSButton(title: "菜单栏设置", target: self, action: #selector(showMenu(_:)))
    settings.bezelStyle = .rounded
    settings.frame = NSRect(x: 426, y: 9, width: 110, height: 26)
    content.addSubview(settings)
    gallery = window
    redraw()
    window.center()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }
  @objc private func cardSelected(_ sender: ThemeCard) {
    defaults.set(sender.theme.rawValue, forKey: "theme")
    redraw()
  }
  func windowWillClose(_ notification: Notification) {
    if (notification.object as? NSWindow) === gallery {
      cards = []
      galleryLabel = nil
      gallery = nil
    }
  }
}
