// Рисует иконку приложения 1024×1024 (тёмная плитка, зелёные ступеньки, оранжевый блик) — запускается при сборке.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r / 255, g / 255, b / 255, a])!
}

let s = CGFloat(size)
let bg = CGGradient(colorsSpace: space, colors: [rgb(38, 52, 45), rgb(18, 24, 21)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

let glow = CGGradient(colorsSpace: space, colors: [rgb(255, 111, 44, 0.45), rgb(255, 111, 44, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: s * 0.9, y: s * 0.1), startRadius: 0,
                       endCenter: CGPoint(x: s * 0.9, y: s * 0.1), endRadius: s * 0.55, options: [])

// Ступеньки (в CoreGraphics ось Y идёт вверх)
let pts: [(CGFloat, CGFloat)] = [(250, 770), (425, 770), (425, 595), (600, 595), (600, 420), (775, 420), (775, 250)]
ctx.setStrokeColor(rgb(127, 224, 168))
ctx.setLineWidth(92)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: pts[0].0, y: s - pts[0].1))
for p in pts.dropFirst() { ctx.addLine(to: CGPoint(x: p.0, y: s - p.1)) }
ctx.strokePath()

guard let image = ctx.makeImage() else { exit(1) }
let out = URL(fileURLWithPath: CommandLine.arguments[1])
guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
exit(CGImageDestinationFinalize(dest) ? 0 : 1)
