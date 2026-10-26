import AppKit

enum MeterTheme: String, CaseIterable {
  case aurora, segments, minimal, terminal, pixel, neko, ribbon, mecha, lunar, forest
  var name: String {
    switch self {
    case .aurora: return "极光电池"
    case .segments: return "分段电池"
    case .minimal: return "极简线框"
    case .terminal: return "极客终端"
    case .pixel: return "像素电玩"
    case .neko: return "猫耳动漫"
    case .ribbon: return "樱粉蝴蝶结"
    case .mecha: return "机甲核心"
    case .lunar: return "月光星轨"
    case .forest: return "森系叶片"
    }
  }
  var subtitle: String {
    switch self {
    case .aurora: return "青蓝渐变 · 玻璃高光"
    case .segments: return "能量刻度 · 冷色科技"
    case .minimal: return "黑白线框 · 跟随系统"
    case .terminal: return "荧光绿 · 等宽数字"
    case .pixel: return "8-bit 轮廓 · 复古游戏"
    case .neko: return "橘色猫耳 · 漫画轮廓"
    case .ribbon: return "粉色丝带 · 少女风格"
    case .mecha: return "装甲切角 · 橙色核心"
    case .lunar: return "新月星点 · 深蓝夜空"
    case .forest: return "嫩绿叶片 · 自然清新"
    }
  }
  var colors: (NSColor, NSColor) {
    switch self {
    case .aurora: return (.hex(0x29d9dd), .hex(0x8072ff))
    case .segments: return (.hex(0x5ce1cc), .hex(0x32a8be))
    case .minimal: return (.labelColor, .labelColor)
    case .terminal: return (.hex(0x8bff95), .hex(0x39c765))
    case .pixel: return (.hex(0xfed666), .hex(0xff935b))
    case .neko: return (.hex(0xffd381), .hex(0xfb9d6e))
    case .ribbon: return (.hex(0xffbadb), .hex(0xe997dc))
    case .mecha: return (.hex(0xffce53), .hex(0xff7448))
    case .lunar: return (.hex(0xa9b0ff), .hex(0x7270da))
    case .forest: return (.hex(0xc5e68b), .hex(0x73bb8d))
    }
  }
}

extension NSColor {
  static func hex(_ rgb: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
      srgbRed: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
      blue: CGFloat(rgb & 255) / 255, alpha: alpha)
  }
}

enum IconPainter {
  static let size = NSSize(width: 54, height: 22)
  static func path(_ points: [NSPoint], closed: Bool = true) -> NSBezierPath {
    let p = NSBezierPath()
    if let first = points.first { p.move(to: first) }
    points.dropFirst().forEach { p.line(to: $0) }
    if closed { p.close() }
    return p
  }
  static func image(
    theme: MeterTheme, percent: Int?, stale: Bool = false, dark: Bool = false, compact: Bool = false
  ) -> NSImage {
    let target = NSSize(width: compact ? 46 : 54, height: 22)
    let image = NSImage(size: target, flipped: false) { rect in
      NSGraphicsContext.saveGraphicsState()
      let t = NSAffineTransform()
      t.scaleX(by: rect.width / 54, yBy: rect.height / 22)
      t.concat()
      draw(theme: theme, percent: percent, stale: stale, dark: dark)
      NSGraphicsContext.restoreGraphicsState()
      return true
    }
    image.isTemplate = false
    image.accessibilityDescription =
      "Codex 剩余 \(percent.map { "\($0)%" } ?? "未知")\(stale ? "，数据待更新" : "")"
    return image
  }

  static func draw(theme: MeterTheme, percent: Int?, stale: Bool, dark: Bool) {
    let fraction = CGFloat(min(100, max(0, percent ?? 0))) / 100
    let base = NSColor.hex(0x172333)
    let isSoft = [MeterTheme.neko, .ribbon, .forest].contains(theme)
    let ink = isSoft ? NSColor.hex(0x382d3e) : .white
    let monochrome = theme == .minimal
    let systemInk = dark ? NSColor.white : NSColor.hex(0x30343d)
    var (start, end) = theme.colors
    if let p = percent, p <= 10 {
      start = .hex(0xff707b)
      end = .hex(0xdf4569)
    } else if let p = percent, p <= 20 {
      start = .hex(0xffd069)
      end = .hex(0xff9850)
    }
    if stale || percent == nil {
      start = .hex(0x8a94a6)
      end = .hex(0x6d7788)
    }
    let body: NSRect
    if theme == .neko || theme == .ribbon {
      body = NSRect(x: 5, y: 2.5, width: 42, height: 15)
    } else {
      body = NSRect(x: 4, y: 3, width: 43, height: 16)
    }
    let outline: NSBezierPath
    switch theme {
    case .pixel:
      outline = path([
        .init(x: 6, y: 3), .init(x: 44, y: 3), .init(x: 44, y: 5), .init(x: 47, y: 5),
        .init(x: 47, y: 17), .init(x: 44, y: 17), .init(x: 44, y: 19), .init(x: 6, y: 19),
        .init(x: 6, y: 17), .init(x: 4, y: 17), .init(x: 4, y: 5), .init(x: 6, y: 5),
      ])
    case .mecha:
      outline = path([
        .init(x: 4, y: 7), .init(x: 8, y: 3), .init(x: 43, y: 3), .init(x: 47, y: 7),
        .init(x: 47, y: 15), .init(x: 43, y: 19), .init(x: 8, y: 19), .init(x: 4, y: 15),
      ])
    default:
      outline = NSBezierPath(
        roundedRect: body, xRadius: theme == .segments || theme == .terminal ? 2 : 4,
        yRadius: theme == .segments || theme == .terminal ? 2 : 4)
    }
    (monochrome
      ? (dark ? NSColor.hex(0x22242a) : NSColor.hex(0xf4f5f7))
      : isSoft ? .hex(theme == .ribbon ? 0xffeaf4 : theme == .forest ? 0xe5efdb : 0xffebd4) : base)
      .setFill()
    outline.fill()
    // Static vector fills only: no timers, blur layers, or looping animation.
    NSGraphicsContext.saveGraphicsState()
    outline.addClip()
    let inner = body.insetBy(dx: 2, dy: 2)
    if monochrome {
      systemInk.withAlphaComponent(0.14).setFill()
      NSBezierPath(
        rect: NSRect(
          x: inner.minX, y: inner.minY, width: inner.width * fraction, height: inner.height)
      ).fill()
    } else if theme == .segments || theme == .pixel {
      let count = theme == .segments ? 10 : 8
      let gap: CGFloat = theme == .segments ? 1.5 : 1.8
      let width = (inner.width - CGFloat(count - 1) * gap) / CGFloat(count)
      for i in 0..<count {
        let unit = min(1, max(0, fraction * CGFloat(count) - CGFloat(i)))
        start.withAlphaComponent(unit > 0 ? 0.8 : 0.09).setFill()
        NSBezierPath(
          rect: NSRect(
            x: inner.minX + CGFloat(i) * (width + gap), y: inner.minY,
            width: width * (unit > 0 ? unit : 1), height: inner.height)
        ).fill()
      }
    } else if theme == .terminal {
      for i in 0..<6 {
        start.withAlphaComponent(0.04).setFill()
        NSBezierPath(
          rect: NSRect(
            x: inner.minX, y: inner.minY + CGFloat(i) * 2, width: inner.width, height: 0.5)
        ).fill()
      }
      start.setFill()
      NSBezierPath(
        rect: NSRect(x: inner.minX, y: inner.minY, width: inner.width * fraction, height: 1.5)
      ).fill()
    } else {
      let fill = NSBezierPath(
        roundedRect: NSRect(
          x: inner.minX, y: inner.minY, width: inner.width * fraction, height: inner.height),
        xRadius: 2, yRadius: 2)
      NSGradient(starting: start, ending: end)?.draw(in: fill, angle: 0)
      if theme == .aurora || theme == .lunar {
        NSColor.white.withAlphaComponent(0.18).setFill()
        NSBezierPath(
          roundedRect: NSRect(
            x: inner.minX, y: inner.maxY - 3, width: inner.width * fraction, height: 2), xRadius: 1,
          yRadius: 1
        ).fill()
      }
    }
    NSGraphicsContext.restoreGraphicsState()
    (monochrome ? systemInk : isSoft ? end.withAlphaComponent(0.9) : start.withAlphaComponent(0.65))
      .setStroke()
    outline.lineWidth = theme == .pixel ? 1.5 : 1
    outline.stroke()
    if theme != .neko && theme != .ribbon && theme != .forest {
      (monochrome ? systemInk.withAlphaComponent(0.7) : start.withAlphaComponent(0.7)).setFill()
      NSBezierPath(
        roundedRect: NSRect(x: 48.5, y: 8, width: 2, height: 6), xRadius: 0.8, yRadius: 0.8
      ).fill()
    }
    switch theme {
    case .neko:
      start.setFill()
      path([.init(x: 7, y: 16), .init(x: 8, y: 21), .init(x: 15, y: 17)]).fill()
      path([.init(x: 37, y: 17), .init(x: 44, y: 21), .init(x: 45, y: 16)]).fill()
      NSColor.hex(0xf18c94).setFill()
      NSBezierPath(ovalIn: .init(x: 7, y: 6, width: 3, height: 1.5)).fill()
      NSBezierPath(ovalIn: .init(x: 42, y: 6, width: 3, height: 1.5)).fill()
    case .ribbon:
      NSColor.hex(0xe97daf).setFill()
      path([.init(x: 25, y: 18), .init(x: 19, y: 21), .init(x: 19, y: 16)]).fill()
      path([.init(x: 27, y: 18), .init(x: 33, y: 21), .init(x: 33, y: 16)]).fill()
      NSColor.hex(0xffd7e9).setFill()
      NSBezierPath(ovalIn: .init(x: 24, y: 16, width: 4, height: 4)).fill()
    case .mecha:
      start.setStroke()
      for x in [CGFloat(1), CGFloat(50)] {
        let p = path([.init(x: x, y: 5), .init(x: x + 2, y: 8)], closed: false)
        p.lineWidth = 1.4
        p.stroke()
        let q = path([.init(x: x, y: 13), .init(x: x + 2, y: 16)], closed: false)
        q.lineWidth = 1.4
        q.stroke()
      }
    case .lunar:
      NSColor.hex(0xe2ddff).setFill()
      NSBezierPath(ovalIn: .init(x: 0.5, y: 13, width: 4, height: 5)).fill()
      base.setFill()
      NSBezierPath(ovalIn: .init(x: 2, y: 14, width: 3, height: 4)).fill()
      start.setFill()
      NSBezierPath(ovalIn: .init(x: 49, y: 17, width: 1.5, height: 1.5)).fill()
    case .forest:
      let leaf = NSBezierPath()
      leaf.move(to: .init(x: 47, y: 10))
      leaf.curve(
        to: .init(x: 53, y: 17), controlPoint1: .init(x: 47, y: 16),
        controlPoint2: .init(x: 51, y: 18))
      leaf.curve(
        to: .init(x: 47, y: 10), controlPoint1: .init(x: 54, y: 12),
        controlPoint2: .init(x: 51, y: 9))
      start.setFill()
      leaf.fill()
      NSColor.hex(0x45896c).setStroke()
      let vein = path([.init(x: 47, y: 10), .init(x: 51, y: 15)], closed: false)
      vein.lineWidth = 0.7
      vein.stroke()
    default: break
    }
    let text = percent.map { "\($0)%" } ?? "—"
    let font: NSFont =
      theme == .terminal || theme == .pixel
      ? .monospacedSystemFont(ofSize: 10.5, weight: .bold) : .systemFont(ofSize: 11, weight: .bold)
    let color: NSColor =
      monochrome
      ? (percent ?? 100 <= 10 ? .systemRed : systemInk) : theme == .terminal ? start : ink
    var attributes: [NSAttributedString.Key: Any] = [
      .font: font, .foregroundColor: color, .kern: -0.25,
    ]
    if !isSoft && !monochrome {
      let shadow = NSShadow()
      shadow.shadowColor = NSColor.black.withAlphaComponent(0.9)
      shadow.shadowBlurRadius = 2
      shadow.shadowOffset = .init(width: 0, height: -0.5)
      attributes[.shadow] = shadow
      attributes[.strokeColor] = NSColor.black.withAlphaComponent(0.45)
      attributes[.strokeWidth] = -1.5
    }
    let textSize = (text as NSString).size(withAttributes: attributes)
    (text as NSString).draw(
      at: .init(x: body.midX - textSize.width / 2, y: body.midY - textSize.height / 2 + 0.4),
      withAttributes: attributes)
    if stale {
      NSColor.systemOrange.setFill()
      NSBezierPath(ovalIn: .init(x: 49, y: 1, width: 3, height: 3)).fill()
    }
  }

  static func exportPNG(
    theme: MeterTheme, percent: Int, to url: URL, scale: CGFloat = 4, dark: Bool = true
  ) throws {
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
      pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(theme: theme, percent: percent, stale: false, dark: dark)
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
  }
}
