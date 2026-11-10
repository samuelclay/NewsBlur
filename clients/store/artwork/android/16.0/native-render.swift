// native-render.swift composes Android store artwork without changing captured app pixels.
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
    let feature_headline: String
    let feature_subheadline: String
}
struct TextLayout {
    let lines: [CTLine]
    let size: CGFloat
    let lineHeight: CGFloat
    let font: NSFont
    var height: CGFloat { CGFloat(lines.count) * lineHeight }
}
func fail(_ message: String) -> Never { fputs(message + "\n", stderr); exit(1) }
func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fail("Cannot load image: \(url.path)") }
    return image
}
let args = Array(CommandLine.arguments.dropFirst())
guard args.count % 2 == 0 else { fail("Arguments must be --name value pairs.") }
var arguments: [String: String] = [:]
for index in stride(from: 0, to: args.count, by: 2) { arguments[args[index]] = args[index + 1] }
guard let rootPath = arguments["--root"], let language = arguments["--language"],
      let placement = arguments["--placement"], let outputPath = arguments["--output"],
      ["icon", "featureGraphic", "phoneScreenshots", "sevenInchScreenshots", "tenInchScreenshots"].contains(placement),
      language.range(of: "^[a-z]{2}(?:-[A-Za-z]{2,4})?$", options: .regularExpression) != nil else {
    fail("Usage: native-render --root PATH --language en --placement phoneScreenshots --panel 1 --output /tmp/panel.png")
}
let root = URL(fileURLWithPath: rootPath)
let output = URL(fileURLWithPath: outputPath).standardizedFileURL
guard output.path.hasPrefix("/tmp/") || output.path.hasPrefix("/private/tmp/") else { fail("Temporary outputs must stay under /tmp.") }
let panel = Int(arguments["--panel"] ?? "1") ?? 0
guard (1...4).contains(panel) else { fail("Panel must be 1 through 4.") }
let copy = try JSONDecoder().decode(Copy.self, from: Data(contentsOf: root.appendingPathComponent("copy/\(language).json")))
guard copy.language == language && copy.headlines.count == 4 && copy.labels.count == 4 &&
    (copy.headlines + copy.labels + [copy.feature_headline, copy.feature_subheadline]).allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { fail("Invalid localized copy.") }
let rtl = ["ar", "he"].contains(language)
let views = ["stories", "feeds", "reader", "saved"]
let device = placement == "sevenInchScreenshots" ? "tablet7" : placement == "tenInchScreenshots" ? "tablet10" : "phone"
let isTablet = device != "phone"
var sources: [(String, CGImage)] = []
if placement == "featureGraphic" {
    for view in ["stories", "reader"] {
        let path = "captures/\(language)/phone-\(view).png"
        sources.append((path, loadImage(root.appendingPathComponent(path))))
    }
} else if placement != "icon" {
    let path = "captures/\(language)/\(device)-\(views[panel - 1]).png"
    sources.append((path, loadImage(root.appendingPathComponent(path))))
}
for (_, capture) in sources {
    guard capture.width >= 320 && capture.height >= 320 && max(capture.width, capture.height) <= 7680 &&
        max(capture.width, capture.height) <= min(capture.width, capture.height) * 2 else {
        // Phone capture aspect ratios may exceed the Play output ratio; they are fitted without cropping.
        if !isTablet && capture.height > capture.width && capture.height <= capture.width * 3 { continue }
        fail("Capture dimensions are unsuitable for the requested placement.")
    }
}
let dimensions: [Int] = placement == "icon" ? [512, 512] : placement == "featureGraphic" ? [1024, 500] :
    isTablet ? [sources[0].1.width, sources[0].1.height] : [1080, 1920]
let width = CGFloat(dimensions[0]), height = CGFloat(dimensions[1])
guard let context = CGContext(data: nil, width: dimensions[0], height: dimensions[1], bitsPerComponent: 8,
    bytesPerRow: dimensions[0] * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: (placement == "icon" ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue) else { fail("Cannot create image context.") }
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
        // Korean headlines wrap at spaces rather than splitting Hangul words into syllables.
        if language == "ko" && end < string.length {
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


var captureEvidence: [[String: Any]] = []
var textEvidence: [[String: Any]] = []
func drawCapture(_ source: (String, CGImage), box: CGRect, surround: Bool = false) {
    let scale = min(box.width / CGFloat(source.1.width), box.height / CGFloat(source.1.height))
    let w = CGFloat(source.1.width) * scale, h = CGFloat(source.1.height) * scale
    let target = CGRect(x: box.midX - w / 2, y: box.midY - h / 2, width: w, height: h)
    if surround {
        context.setFillColor(color(0xc5cebc)); context.fill(target.insetBy(dx: -1, dy: -1))
    }
    context.draw(source.1, in: target)
    captureEvidence.append(["path": source.0, "source_width": source.1.width, "source_height": source.1.height,
        "bounds": ["x": target.minX, "y": height - target.maxY, "width": target.width, "height": target.height]])
}
func writeText(_ text: String, box: CGRect, size: CGFloat, color: UInt32 = 0x272c25, weight: NSFont.Weight = .medium, rightToLeft: Bool = false) {
    let layout = fitText(text, initial: size, maxWidth: box.width, maxHeight: box.height, lineSpacing: 1.15,
        tracking: 0, rgb: color, weight: weight, rightToLeft: rightToLeft, balanced: true)
    drawText(layout, x: box.minX, top: height - box.maxY, width: box.width, rightToLeft: rightToLeft)
    textEvidence.append(["text": text, "font_size": layout.size, "line_count": layout.lines.count])
}
let canvas = CGRect(x: 0, y: 0, width: width, height: height)
fill(canvas, 0xedefeb)
let icon = loadImage(root.appendingPathComponent("assets/icon-source.png"))
if placement == "icon" {
    // Google adds its own icon masking and shadow; native-render.swift adds neither.
    context.draw(icon, in: canvas)
} else if isTablet {
    // Google recommends tablet screenshots of the actual full-screen app without device frames or external text.
    drawCapture(sources[0], box: canvas)
} else if placement == "phoneScreenshots" {
    // Modest localized headings and a Sage surround keep the complete native screen dominant.
    fill(rect(0, 260, width, height - 260), 0xdbe1d3)
    fill(rect(0, 260, width, 1), 0xc8d0be)
    context.draw(icon, in: rect(62, 40, 46, 46))
    writeText("NewsBlur", box: rect(124, 44, 400, 42), size: 32, weight: .semibold)
    writeText(copy.headlines[panel - 1], box: rect(62, 111, width - 124, 124), size: 56, rightToLeft: rtl)
    drawCapture(sources[0], box: rect(36, 280, width - 72, height - 312), surround: true)
} else {
    // Feature artwork retains the Sage palette and real app screenshots; no manufactured UI or Apple devices.
    fill(rect(536, 0, width - 536, height), 0xdbe1d3)
    fill(rect(536, 0, 1, height), 0xc8d0be)
    context.draw(icon, in: rect(48, 52, 42, 42))
    writeText("NewsBlur", box: rect(104, 57, 380, 36), size: 25, weight: .semibold)
    writeText(copy.feature_headline, box: rect(48, 139, 440, 180), size: 48, rightToLeft: rtl)
    writeText(copy.feature_subheadline, box: rect(48, 344, 420, 90), size: 24, color: 0x68715d, weight: .regular, rightToLeft: rtl)
    drawCapture(sources[0], box: rect(558, 42, 204, 416), surround: true)
    drawCapture(sources[1], box: rect(780, 42, 204, 416), surround: true)
}
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else { fail("Cannot create PNG output.") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fail("PNG encoding failed.") }
let evidence: [String: Any] = ["language": language, "placement": placement, "panel": panel,
    "width": dimensions[0], "height": dimensions[1], "captures": captureEvidence, "text": textEvidence,
    "status": "rendered_requires_visual_review", "output": output.path]
let data = try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
try data.write(to: output.deletingPathExtension().appendingPathExtension("json"))
print(String(data: data, encoding: .utf8)!)
