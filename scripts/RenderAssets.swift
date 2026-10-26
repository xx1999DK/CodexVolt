import AppKit

@main struct RenderAssets {
  static func canvas(_ w: Int, _ h: Int, _ path: String, draw: () -> Void) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: w, height: h)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
  }
  static func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ color: NSColor,
    _ weight: NSFont.Weight = .regular) {
    (s as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
      .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
  }
  static func fill(_ r: NSRect, _ c: NSColor, _ radius: CGFloat = 0) {
    c.setFill(); NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill()
  }
  static func main() throws {
    _ = NSApplication.shared
    let root = CommandLine.arguments[1]
    let dark = NSColor.hex(0x0c1524), mint = NSColor.hex(0x7df5c4), muted = NSColor.hex(0x9bb2c8)
    try canvas(1200, 430, root + "/docs/images/hero.png") {
      fill(NSRect(x: 0, y: 0, width: 1200, height: 430), dark)
      fill(NSRect(x: 68, y: 334, width: 230, height: 34), NSColor.hex(0x19372e), 17)
      text("NATIVE  /  LIGHTWEIGHT", 86, 343, 13, mint, .semibold)
      text("CodexVolt", 64, 223, 80, .white, .bold)
      text("Your Codex quota, at a glance.", 68, 169, 27, muted)
      text("10 THEMES   ·   macOS 13+   ·   SWIFT + APPKIT", 68, 70, 16, mint, .medium)
      IconPainter.image(theme: .aurora, percent: 73, dark: true).draw(in:
        NSRect(x: 820, y: 163, width: 302, height: 123))
      text("A LITTLE ENERGY FOR YOUR MENU BAR", 800, 120, 12, muted)
    }
    let english = ["Aurora", "Segments", "Minimal", "Terminal", "Pixel", "Neko", "Ribbon", "Mecha", "Lunar", "Forest"]
    try canvas(1200, 1030, root + "/docs/images/themes.png") {
      fill(NSRect(x: 0, y: 0, width: 1200, height: 1030), NSColor.hex(0xf2f5f8))
      text("TEN WAYS TO STAY CHARGED", 48, 960, 30, dark, .bold)
      text("Original native vectors · Light & dark · Sample quota: 73%", 48, 920, 17, NSColor.hex(0x57687b))
      for (i, theme) in MeterTheme.allCases.enumerated() {
        let x = CGFloat(48 + (i % 2) * 566), y = CGFloat(735 - (i / 2) * 169)
        fill(NSRect(x: x, y: y, width: 538, height: 149), .white, 18)
        text(String(format: "%02d", i + 1), x + 20, y + 108, 14, NSColor.hex(0x8595a6), .medium)
        text(theme.name + " / " + english[i], x + 60, y + 104, 20, dark, .semibold)
        fill(NSRect(x: x + 275, y: y + 18, width: 243, height: 66), dark, 10)
        IconPainter.image(theme: theme, percent: 73, dark: false).draw(in:
          NSRect(x: x + 70, y: y + 28, width: 130, height: 53))
        IconPainter.image(theme: theme, percent: 73, dark: true).draw(in:
          NSRect(x: x + 330, y: y + 28, width: 130, height: 53))
      }
      text("CodexVolt  ·  All themes are switchable in the menu bar.", 48, 26, 16, NSColor.hex(0x57687b))
    }
    for pixels in [16, 32, 64, 128, 256, 512, 1024] {
      try canvas(pixels, pixels, root + "/.build/icon-\(pixels).png") {
        let s = CGFloat(pixels)
        fill(NSRect(x: s * 0.05, y: s * 0.05, width: s * 0.9, height: s * 0.9), dark, s * 0.21)
        IconPainter.image(theme: .aurora, percent: 73, dark: true).draw(in:
          NSRect(x: s * 0.12, y: s * 0.34, width: s * 0.76, height: s * 0.31))
      }
    }
  }
}
