// native-render.swift retains approved Sage artwork with measured open or closed Duo frames.
// export-native.rb validates temporary renders before installing a complete four-panel set.
import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Copy: Decodable {
    let language: String
    let headlines: [String]
    let labels: [String]
}

// export-native.rb supplies frame measurements; native-render.swift never infers an opening from capture size.
struct FrameSpec: Decodable {
    struct Opening: Decodable {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let cornerRadius: CGFloat
    }
    let frame: String
    let width: CGFloat
    let height: CGFloat
    let pose: String
    let opening: Opening
    var clip: String? = nil
}

struct TextLayout {
    let lines: [CTLine]
    let size: CGFloat
    let lineHeight: CGFloat
    let font: NSFont
    var height: CGFloat { CGFloat(lines.count) * lineHeight }
}

func fail(_ message: String) -> Never {
    fputs(message + "\n", stderr)
    exit(1)
}

var arguments: [String: String] = [:]
let args = Array(CommandLine.arguments.dropFirst())
guard args.count % 2 == 0 else { fail("Arguments must be --name value pairs.") }
for index in stride(from: 0, to: args.count, by: 2) { arguments[args[index]] = args[index + 1] }
let root = URL(fileURLWithPath: arguments["--root"] ?? FileManager.default.currentDirectoryPath + "/clients/store/artwork/ios/16.0.1/duo")
guard let language = arguments["--language"], let size = arguments["--size"],
      let panelString = arguments["--panel"], let panel = Int(panelString), (1...4).contains(panel),
      let outputPath = arguments["--output"] else {
    fail("Usage: native-render --language en --size 2853x2007 --panel 1 --output /tmp/panel.png")
}
let output = URL(fileURLWithPath: outputPath).standardizedFileURL
guard output.path.hasPrefix("/tmp/") || output.path.hasPrefix("/private/tmp/") else { fail("Alternate outputs must stay under /tmp.") }
guard ["2853x2007"].contains(size) else { fail("Unsupported size.") }
let dimensions = size.split(separator: "x").map { Int($0)! }
let width = CGFloat(dimensions[0]), height = CGFloat(dimensions[1])
let device = "duo"
let rtl = ["ar", "he"].contains(language)
let copy = try JSONDecoder().decode(Copy.self, from: Data(contentsOf: root.appendingPathComponent("../../16.0/screenshots/copy/\(language).json")))
guard copy.language == language && copy.headlines.count == 4 && copy.labels.count == 4 else { fail("Invalid locale copy.") }
let view = ["stories", "feeds", "reader", "saved"][panel - 1]
let capturePath = "captures/\(language)/\(device)-\(view).png"

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fail("Cannot load image: \(url.path)")
    }
    return image
}
let capture = loadImage(arguments["--capture"].map { URL(fileURLWithPath: $0) } ?? root.appendingPathComponent(capturePath))
let frameSpec: FrameSpec
let frameURL: URL
if let specPath = arguments["--frame-spec"] {
    let specURL = URL(fileURLWithPath: specPath)
    frameSpec = try JSONDecoder().decode(FrameSpec.self, from: Data(contentsOf: specURL))
    frameURL = URL(fileURLWithPath: frameSpec.frame, relativeTo: specURL.deletingLastPathComponent()).standardizedFileURL
} else {
    frameSpec = FrameSpec(frame: "assets/iphone-duo-inner-landscape.png", width: 3093, height: 2247, pose: "open",
        opening: FrameSpec.Opening(x: 120, y: 120, width: 2853, height: 2007, cornerRadius: 202))
    frameURL = root.appendingPathComponent(frameSpec.frame)
}
let opening = frameSpec.opening
guard ["open", "closed"].contains(frameSpec.pose), frameSpec.width > 0, frameSpec.height > 0,
      opening.x >= 0, opening.y >= 0, opening.width > 0, opening.height > 0,
      opening.x + opening.width <= frameSpec.width, opening.y + opening.height <= frameSpec.height,
      opening.cornerRadius >= 0, opening.cornerRadius <= min(opening.width, opening.height) / 2 else {
    fail("Invalid measured frame opening.")
}
guard CGFloat(capture.width) == opening.width && CGFloat(capture.height) == opening.height else {
    fail("Native capture dimensions do not match the measured frame opening.")
}
let assets = root.appendingPathComponent("../../16.0/selected/assets")
let bezel = loadImage(frameURL)
guard CGFloat(bezel.width) == frameSpec.width && CGFloat(bezel.height) == frameSpec.height else {
    fail("Official frame dimensions do not match frame metadata.")
}
guard frameSpec.clip == nil || frameSpec.clip == "frame-alpha" else { fail("Unsupported frame clipping mode.") }
func frameOpeningMask() -> CGImage {
    // native-render.swift follows the official frame's connected screen opening, including asymmetric corners.
    let bitmap = NSBitmapImageRep(cgImage: bezel)
    guard bitmap.bitsPerSample == 8, bitmap.samplesPerPixel == 4, !bitmap.isPlanar,
          let pixels = bitmap.bitmapData else { fail("Frame must decode to 8-bit RGBA for alpha clipping.") }
    let maskWidth = Int(opening.width), maskHeight = Int(opening.height)
    let alphaOffset = bitmap.bitmapFormat.contains(.alphaFirst) ? 0 : 3
    func alpha(_ index: Int) -> UInt8 {
        pixels[(Int(opening.y) + index / maskWidth) * bitmap.bytesPerRow +
            (Int(opening.x) + index % maskWidth) * 4 + alphaOffset]
    }
    let seed = maskHeight / 2 * maskWidth + maskWidth / 2
    guard alpha(seed) == 0 else { fail("Frame screen center is not transparent.") }
    var mask = [UInt8](repeating: 0, count: maskWidth * maskHeight)
    mask[seed] = 255
    var queue = [seed]
    var cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]
        cursor += 1
        let x = index % maskWidth, y = index / maskWidth
        var neighbors: [Int] = []
        if x > 0 { neighbors.append(index - 1) }
        if x + 1 < maskWidth { neighbors.append(index + 1) }
        if y > 0 { neighbors.append(index - maskWidth) }
        if y + 1 < maskHeight { neighbors.append(index + maskWidth) }
        for next in neighbors where mask[next] == 0 && alpha(next) < 255 {
            mask[next] = 255
            queue.append(next)
        }
    }
    guard queue.count > mask.count / 2,
          let provider = CGDataProvider(data: Data(mask) as CFData),
          let image = CGImage(width: maskWidth, height: maskHeight, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: maskWidth, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
        fail("Cannot derive the official frame's screen mask.")
    }
    return image
}
let icon = loadImage(assets.appendingPathComponent("icon.png"))
guard let context = CGContext(data: nil, width: dimensions[0], height: dimensions[1], bitsPerComponent: 8,
    bytesPerRow: dimensions[0] * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fail("Cannot create image context.") }
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
context.setShouldSmoothFonts(true)
context.setShouldSubpixelPositionFonts(true)
context.interpolationQuality = .high

func color(_ value: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
}
func rect(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(x: x, y: height - top - h, width: w, height: h)
}
func fill(_ rectangle: CGRect, _ rgb: UInt32) {
    context.setFillColor(color(rgb)); context.fill(rectangle)
}
func attributes(_ font: NSFont, _ tracking: CGFloat, _ rgb: UInt32, _ rightToLeft: Bool) -> [NSAttributedString.Key: Any] {
    let paragraph = NSMutableParagraphStyle()
    paragraph.baseWritingDirection = rightToLeft ? .rightToLeft : .leftToRight
    paragraph.lineBreakMode = .byWordWrapping
    return [NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(rgb),
        NSAttributedString.Key(kCTKernAttributeName as String): tracking,
        NSAttributedString.Key(kCTLanguageAttributeName as String): language,
        .paragraphStyle: paragraph]
}
func textLines(_ text: String, font: NSFont, tracking: CGFloat, maxWidth: CGFloat, rgb: UInt32, rightToLeft: Bool) -> [CTLine] {
    let attributed = NSAttributedString(string: text, attributes: attributes(font, tracking, rgb, rightToLeft))
    let typesetter = CTTypesetterCreateWithAttributedString(attributed)
    let string = text as NSString
    var start = 0
    var lines: [CTLine] = []
    while start < string.length {
        let count = max(1, CTTypesetterSuggestLineBreak(typesetter, start, Double(maxWidth)))
        var end = min(start + count, string.length)
        // native-render.swift keeps whole words while balancing the narrow text column.
        if !["ja", "zh-Hans", "zh-Hant", "th"].contains(language) && end < string.length {
            func isSpace(_ position: Int) -> Bool {
                string.substring(with: NSRange(location: position, length: 1)).unicodeScalars.allSatisfy { CharacterSet.whitespaces.contains($0) }
            }
            if !isSpace(end - 1) && !isSpace(end) {
                var boundary = end
                while boundary > start && !isSpace(boundary - 1) { boundary -= 1 }
                if boundary > start { end = boundary }
                else { while end < string.length && !isSpace(end) { end += 1 } }
            }
        }
        // CoreText balancing must keep Thai repetition marks and closing punctuation off line starts.
        let closing = CharacterSet(charactersIn: "ๆฯ,.;:!?%)]}、。，．？！：；）》」』】〕〉")
        while end < string.length {
            let next = string.substring(with: NSRange(location: end, length: 1))
            guard next.unicodeScalars.allSatisfy({ closing.contains($0) }) else { break }
            end += 1
        }
        let trimmed = string.substring(with: NSRange(location: start, length: end - start)).trimmingCharacters(in: .whitespaces)
        lines.append(CTLineCreateWithAttributedString(NSAttributedString(string: trimmed, attributes: attributes(font, tracking, rgb, rightToLeft))))
        start = end
    }
    return lines
}
func balancedLines(_ text: String, font: NSFont, tracking: CGFloat, maxWidth: CGFloat, rgb: UInt32, rightToLeft: Bool) -> [CTLine] {
    let original = textLines(text, font: font, tracking: tracking, maxWidth: maxWidth, rgb: rgb, rightToLeft: rightToLeft)
    guard original.count > 1 else { return original }
    var low = maxWidth / CGFloat(original.count), high = maxWidth
    for _ in 0..<18 {
        let middle = (low + high) / 2
        let candidate = textLines(text, font: font, tracking: tracking, maxWidth: middle, rgb: rgb, rightToLeft: rightToLeft)
        if candidate.count > original.count { low = middle } else { high = middle }
    }
    return textLines(text, font: font, tracking: tracking, maxWidth: high + 0.1, rgb: rgb, rightToLeft: rightToLeft)
}
func fitText(_ text: String, initial: CGFloat, maxWidth: CGFloat, maxHeight: CGFloat, lineSpacing: CGFloat,
             tracking: CGFloat, rgb: UInt32, weight: NSFont.Weight, rightToLeft: Bool, balanced: Bool) -> TextLayout {
    var size = initial
    while size >= initial * 0.55 {
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        // native-render.swift keeps words intact in the narrow landscape column.
        // CJK and Thai use CoreText's language-aware character or dictionary boundaries instead.
        if !["ja", "zh-Hans", "zh-Hant", "th"].contains(language) {
            let longestWord: CGFloat = text.components(separatedBy: .whitespacesAndNewlines).map { word -> CGFloat in
                let line = CTLineCreateWithAttributedString(NSAttributedString(string: word,
                    attributes: attributes(font, tracking, rgb, rightToLeft)))
                return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            }.max() ?? 0
            if longestWord > maxWidth { size -= 0.5; continue }
        }
        let lines = balanced ? balancedLines(text, font: font, tracking: tracking, maxWidth: maxWidth, rgb: rgb, rightToLeft: rightToLeft)
            : textLines(text, font: font, tracking: tracking, maxWidth: maxWidth, rgb: rgb, rightToLeft: rightToLeft)
        let result = TextLayout(lines: lines, size: size, lineHeight: size * lineSpacing, font: font)
        let widest = lines.map { CGFloat(CTLineGetTypographicBounds($0, nil, nil, nil)) }.max() ?? 0
        if result.height <= maxHeight && widest <= maxWidth + 1 && (balanced || lines.count == 1) { return result }
        size -= 0.5
    }
    fail("Text does not fit: \(text)")
}
func drawText(_ layout: TextLayout, x: CGFloat, top: CGFloat, width: CGFloat, rightToLeft: Bool) {
    let metricHeight = layout.font.ascender - layout.font.descender
    let baselineOffset = layout.font.ascender + (layout.lineHeight - metricHeight) / 2
    for (index, line) in layout.lines.enumerated() {
        let offset = rightToLeft ? CGFloat(CTLineGetPenOffsetForFlush(line, 1, Double(width))) : 0
        context.textPosition = CGPoint(x: x + offset, y: height - top - baselineOffset - CGFloat(index) * layout.lineHeight)
        CTLineDraw(line, context)
    }
}

// native-render.swift retains Sage colors and typography in a landscape editorial layout.
fill(CGRect(x: 0, y: 0, width: width, height: height), 0xedefeb)
fill(rect(width * 0.325, 0, width * 0.675, height), 0xdbe1d3)
fill(rect(width * 0.325, 0, 1, height), 0xc8d0be)
let margin = width * 0.05
let textWidth = width * 0.245
let iconSide = width * 0.034
let iconTop = height * 0.068
let iconRect = rect(margin, iconTop, iconSide, iconSide)
context.saveGState()
context.addPath(CGPath(roundedRect: iconRect, cornerWidth: iconSide * 0.21, cornerHeight: iconSide * 0.21, transform: nil))
context.clip()
context.draw(icon, in: iconRect)
context.restoreGState()
let brand = fitText("NewsBlur", initial: width * 0.024, maxWidth: textWidth - iconSide - width * 0.013,
    maxHeight: iconSide, lineSpacing: 1, tracking: 0, rgb: 0x272c25, weight: .semibold, rightToLeft: false, balanced: false)
drawText(brand, x: margin + iconSide + width * 0.013, top: iconTop + (iconSide - brand.lineHeight) / 2,
    width: textWidth - iconSide - width * 0.013, rightToLeft: false)

// native-render.swift uniformly fits a measured frame into the Sage device column, without cropping the screen.
// The default open-frame arithmetic preserves the original exports' device placement.
let deviceWidth = frameSpec.pose == "closed" ? min(width * 0.635, height * 0.80 * frameSpec.width / frameSpec.height) : width * 0.635
let deviceHeight = deviceWidth * frameSpec.height / frameSpec.width
let deviceLeft = width * 0.345 + (width * 0.635 - deviceWidth) / 2
let deviceTop = (height - deviceHeight) / 2
let scale = deviceWidth / frameSpec.width
let displayLeft = deviceLeft + opening.x * scale
let displayTop = deviceTop + opening.y * scale
let displayWidth = opening.width * scale
let displayHeight = opening.height * scale
let displayRect = rect(displayLeft, displayTop, displayWidth, displayHeight)
context.saveGState()
if frameSpec.clip == "frame-alpha" {
    context.clip(to: displayRect, mask: frameOpeningMask())
} else {
    context.addPath(CGPath(roundedRect: displayRect, cornerWidth: opening.cornerRadius * scale, cornerHeight: opening.cornerRadius * scale, transform: nil))
    context.clip()
}
fill(displayRect, 0xe8eae5)
context.draw(capture, in: displayRect)
context.restoreGState()
context.draw(bezel, in: rect(deviceLeft, deviceTop, deviceWidth, deviceHeight))

let headline = fitText(copy.headlines[panel - 1], initial: width * 0.050, maxWidth: textWidth,
    maxHeight: height * 0.52, lineSpacing: 1.08, tracking: rtl ? 0 : -width * 0.0018,
    rgb: 0x272c25, weight: NSFont.Weight(rawValue: 0.286), rightToLeft: rtl, balanced: true)
let headlineTop = max(height * 0.28, (height - headline.height) / 2)
drawText(headline, x: margin, top: headlineTop, width: textWidth, rightToLeft: rtl)
let label = fitText(copy.labels[panel - 1], initial: width * 0.019, maxWidth: textWidth,
    maxHeight: height * 0.06, lineSpacing: 1.5, tracking: rtl ? 0 : width * 0.0005,
    rgb: 0x68715d, weight: .regular, rightToLeft: rtl, balanced: false)
let labelTop = height * 0.923 - label.lineHeight
fill(rect(margin, labelTop - width * 0.012, textWidth, 1), 0xb8c3ac)
drawText(label, x: margin, top: labelTop, width: textWidth, rightToLeft: rtl)
let index = fitText(String(format: "%02d / 04", panel), initial: width * 0.019, maxWidth: width * 0.3,
    maxHeight: height * 0.06, lineSpacing: 1.5, tracking: 0, rgb: 0x68715d,
    weight: .regular, rightToLeft: false, balanced: false)
let indexWidth = CGFloat(CTLineGetTypographicBounds(index.lines[0], nil, nil, nil))
drawText(index, x: width * 0.95 - indexWidth, top: height * 0.923 - index.lineHeight,
    width: indexWidth, rightToLeft: false)

try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else { fail("Cannot create PNG output.") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fail("PNG encoding failed.") }
let evidence: [String: Any] = ["language": language, "size": size, "panel": panel, "capture": arguments["--capture"] ?? capturePath,
    "frame": frameURL.path, "frame_pose": frameSpec.pose, "frame_clip": frameSpec.clip ?? "rounded-rectangle",
    "output": output.path, "headline_font": headline.font.fontName, "headline_size": headline.size,
    "headline_lines": headline.lines.count, "capture_bounds": ["x": displayLeft, "y": displayTop, "width": displayWidth, "height": displayHeight],
    "status": "rendered_requires_pixel_and_visual_review"]
let evidenceData = try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
try evidenceData.write(to: output.deletingPathExtension().appendingPathExtension("json"))
print(String(data: evidenceData, encoding: .utf8)!)
