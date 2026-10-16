// ScreenshotReadiness.swift checks captured pixels without modifying the screenshot.
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 6,
      let data = try? Data(contentsOf: URL(fileURLWithPath: args[1])),
      let image = NSBitmapImageRep(data: data) else {
    fputs("Usage: ScreenshotReadiness image x y width height\n", stderr)
    exit(2)
}
let rect = args.dropFirst(2).compactMap(Double.init)
guard rect.count == 4, rect.allSatisfy({ $0 >= 0 && $0 <= 1 }) else { exit(2) }
let x0 = Int(rect[0] * Double(image.pixelsWide))
let y0 = Int(rect[1] * Double(image.pixelsHigh))
let x1 = min(image.pixelsWide, Int((rect[0] + rect[2]) * Double(image.pixelsWide)))
let y1 = min(image.pixelsHigh, Int((rect[1] + rect[3]) * Double(image.pixelsHigh)))
var colored = 0
var sampled = 0
for y in stride(from: y0, to: y1, by: 8) {
    for x in stride(from: x0, to: x1, by: 8) {
        guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
        let components = [color.redComponent, color.greenComponent, color.blueComponent]
        if components.max()! - components.min()! > 0.12 { colored += 1 }
        sampled += 1
    }
}
print(sampled == 0 ? 0 : Double(colored) / Double(sampled))
