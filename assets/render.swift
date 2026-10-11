// Draws every trails image from one definition of the mark, so the logo, the README art
// and the menu-bar icons never drift apart. Run it after changing the mark:
//
//   swift assets/render.swift assets                 the logo and lockups, into assets/
//   swift assets/render.swift --menubar <dir>        the menu-bar icon set, into <dir>
//
// The mark is a lowercase t drawn as one stroke, its crossbar and foot each ending in a dot:
// the top dot is "wants you" (amber when an agent finished its turn, red when one is asking
// you something), the bottom one "working" (green). Drawn in a 24-unit box, y down.
import AppKit

func hex(_ h: Int) -> NSColor {
  NSColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255,
          blue: CGFloat(h & 255) / 255, alpha: 1)
}
let amber = hex(0xF5A524), green = hex(0x2BD47F), red = hex(0xF0525E), idleDot = hex(0x8A8F98)
let cream = hex(0xECE8E0), ink = hex(0x16191A), night = hex(0x0E1412), paper = hex(0xF2EFE8)

func drawMark(_ g: CGContext, ink: NSColor, top: NSColor, bottom: NSColor) {
  g.setStrokeColor(ink.cgColor); g.setLineWidth(3.2); g.setLineCap(.round); g.setLineJoin(.round)
  g.beginPath()
  g.move(to: CGPoint(x: 6, y: 2.5)); g.addLine(to: CGPoint(x: 6, y: 15))
  g.addQuadCurve(to: CGPoint(x: 10.5, y: 20), control: CGPoint(x: 6, y: 20))
  g.addLine(to: CGPoint(x: 13, y: 20))
  g.move(to: CGPoint(x: 6, y: 9)); g.addLine(to: CGPoint(x: 13, y: 9))
  g.strokePath()
  for (y, col) in [(CGFloat(9), top), (CGFloat(20), bottom)] {
    g.setFillColor(col.cgColor); g.fillEllipse(in: CGRect(x: 18 - 2.9, y: y - 2.9, width: 5.8, height: 5.8))
  }
}

// A PNG of `points` x `points`-ish at `scale`, with its DPI set so an app that loads it
// (SwiftBar) sizes it in points, not pixels.
func png(_ path: String, width: CGFloat, height: CGFloat, scale: CGFloat, _ body: (CGContext) -> Void) {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  rep.size = NSSize(width: width, height: height)
  let ctx = NSGraphicsContext(bitmapImageRep: rep)!
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ctx
  let g = ctx.cgContext
  g.translateBy(x: 0, y: height); g.scaleBy(x: 1, y: -1) // y down, like the mark
  body(g)
  NSGraphicsContext.restoreGraphicsState()
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
  print("wrote \(path)")
}

func lockup(_ path: String, bg: NSColor?, fg: NSColor) {
  let w: CGFloat = 360, h: CGFloat = 112
  png(path, width: w, height: h, scale: 2) { g in
    if let bg { g.setFillColor(bg.cgColor); g.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerWidth: 22, cornerHeight: 22, transform: nil)); g.fillPath() }
    g.saveGState(); g.translateBy(x: 26, y: 20); g.scaleBy(x: 72 / 24, y: 72 / 24)
    drawMark(g, ink: fg, top: amber, bottom: green); g.restoreGState()
    // Text through AppKit, which draws y-up: flip back for it.
    g.saveGState(); g.translateBy(x: 0, y: h); g.scaleBy(x: 1, y: -1)
    let font = NSFont.monospacedSystemFont(ofSize: 60, weight: .heavy)
    NSAttributedString(string: "trails", attributes: [.font: font, .foregroundColor: fg]).draw(at: NSPoint(x: 116, y: 22))
    g.restoreGState()
  }
}

let args = Array(CommandLine.arguments.dropFirst())
if args.first == "--menubar", args.count == 2 {
  // Every state the menu bar can be in, for a light and a dark bar. 18 pt is the menu-bar
  // icon height; @2x for Retina.
  let tops: [(String, NSColor)] = [("none", idleDot), ("idle", amber), ("blocked", red)]
  let bottoms: [(String, NSColor)] = [("rest", idleDot), ("working", green)]
  for (bar, inkCol) in [("light", ink), ("dark", cream)] {
    for (tn, tc) in tops { for (bn, bc) in bottoms {
      png("\(args[1])/trails-\(bar)-\(tn)-\(bn).png", width: 18, height: 18, scale: 2) { g in
        g.scaleBy(x: 18 / 24, y: 18 / 24); drawMark(g, ink: inkCol, top: tc, bottom: bc)
      }
    } }
  }
} else if args.count == 1 {
  let dir = args[0]
  png("\(dir)/mark.png", width: 128, height: 128, scale: 2) { g in
    g.setFillColor(night.cgColor)
    g.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 128, height: 128), cornerWidth: 28, cornerHeight: 28, transform: nil)); g.fillPath()
    g.translateBy(x: 22, y: 22); g.scaleBy(x: 84 / 24, y: 84 / 24); drawMark(g, ink: cream, top: amber, bottom: green)
  }
  lockup("\(dir)/logo-dark.png", bg: nil, fg: cream)
  lockup("\(dir)/logo-light.png", bg: nil, fg: ink)
} else {
  FileHandle.standardError.write("usage: swift render.swift <dir> | --menubar <dir>\n".data(using: .utf8)!)
  exit(1)
}
