// native-render.swift renders the approved Sage composition with CoreGraphics/CoreText, without a browser.
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
let root = URL(fileURLWithPath: arguments["--root"] ?? FileManager.default.currentDirectoryPath + "/clients/store/artwork/ios/16.0/screenshots")
guard let language = arguments["--language"], let size = arguments["--size"],
      let panelString = arguments["--panel"], let panel = Int(panelString), (1...4).contains(panel),
      let outputPath = arguments["--output"] else {
    fail("Usage: native-render --language en --size 2064x2752 --panel 1 --output /tmp/panel.png")
}
let output = URL(fileURLWithPath: outputPath).standardizedFileURL
guard output.path.hasPrefix("/tmp/") || output.path.hasPrefix("/private/tmp/") else { fail("Alternate outputs must stay under /tmp.") }
guard ["1320x2868", "1206x2622", "2064x2752"].contains(size) else { fail("Unsupported size.") }
let dimensions = size.split(separator: "x").map { Int($0)! }
let width = CGFloat(dimensions[0]), height = CGFloat(dimensions[1])
let ipad = size == "2064x2752"
let device = ipad ? "ipad" : "iphone"
let rtl = ["ar", "he"].contains(language)
let copy = try JSONDecoder().decode(Copy.self, from: Data(contentsOf: root.appendingPathComponent("copy/\(language).json")))
guard copy.language == language && copy.headlines.count == 4 && copy.labels.count == 4 else { fail("Invalid locale copy.") }
let view = ["stories", "feeds", "reader", "saved"][panel - 1]
let capturePath = "captures/" + (language == "en" ? "" : "localized/\(language)/") + "\(device)-\(view).png"

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fail("Cannot load image: \(url.path)")
    }
    return image
}
let capture = loadImage(root.appendingPathComponent(capturePath))
guard capture.width == (ipad ? 2064 : 1320) && capture.height == (ipad ? 2752 : 2868) else { fail("Native capture dimensions do not match the device.") }
let assets = root.appendingPathComponent("../selected/assets")
let bezel = loadImage(assets.appendingPathComponent(ipad ? "ipad-pro-m5.png" : "iphone-18-pro-max.png"))
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

// Geometry and colors mirror index.html, with the original PNGs drawn into the same screen openings.
fill(CGRect(x: 0, y: 0, width: width, height: height), 0xedefeb)
fill(rect(0, height * 0.26, width, height * 0.74), 0xdbe1d3)
fill(rect(0, height * 0.26, width, 1), 0xc8d0be)
let iconRect = rect(width * 0.08, height * (ipad ? 0.04 : 0.043), width * 0.052, width * 0.052)
context.saveGState()
context.addPath(CGPath(roundedRect: iconRect, cornerWidth: width * 0.011, cornerHeight: width * 0.011, transform: nil))
context.clip()
context.draw(icon, in: iconRect)
context.restoreGState()
let brand = fitText("NewsBlur", initial: width * 0.032, maxWidth: width * 0.5, maxHeight: width * 0.052,
    lineSpacing: 1, tracking: 0, rgb: 0x272c25, weight: .semibold, rightToLeft: false, balanced: false)
drawText(brand, x: width * (0.08 + 0.052 + 0.017), top: height * (ipad ? 0.04 : 0.043) + (width * 0.052 - brand.lineHeight) / 2, width: width * 0.5, rightToLeft: false)

let deviceWidth = width * (ipad ? 0.70 : 0.76)
let deviceHeight = deviceWidth * (ipad ? 3000.0 / 2300 : 3000.0 / 1470)
let deviceLeft = width * (ipad ? 0.15 : 0.12)
let deviceTop = height * (ipad ? 0.935 : 0.938) - deviceHeight
let displayLeft = deviceLeft + deviceWidth * (ipad ? 118.0 / 2300 : 75.0 / 1470)
let displayTop = deviceTop + deviceHeight * (ipad ? 124.0 / 3000 : 66.0 / 3000)
let displayWidth = deviceWidth * (ipad ? 2064.0 / 2300 : 1320.0 / 1470)
let displayHeight = deviceHeight * (ipad ? 2752.0 / 3000 : 2868.0 / 3000)
let displayRect = rect(displayLeft, displayTop, displayWidth, displayHeight)
context.saveGState()
context.addPath(CGPath(roundedRect: displayRect, cornerWidth: displayWidth * (ipad ? 0.031 : 0.14), cornerHeight: displayHeight * (ipad ? 0.023 : 0.065), transform: nil))
context.clip()
fill(displayRect, 0xe8eae5)
context.draw(capture, in: displayRect)
context.restoreGState()
context.draw(bezel, in: rect(deviceLeft, deviceTop, deviceWidth, deviceHeight))

let headlineTop = height * (ipad ? 0.11 : 0.10)
let headline = fitText(copy.headlines[panel - 1], initial: width * (ipad ? 0.077 : 0.088), maxWidth: width * 0.8,
    maxHeight: deviceTop - headlineTop - width * 0.018, lineSpacing: ipad ? 1.08 : 1.09,
    tracking: rtl ? 0 : -width * 0.0035, rgb: 0x272c25, weight: NSFont.Weight(rawValue: 0.286), rightToLeft: rtl, balanced: true)
drawText(headline, x: width * 0.08, top: headlineTop, width: width * 0.8, rightToLeft: rtl)
let label = fitText(copy.labels[panel - 1], initial: width * 0.028, maxWidth: width * 0.35, maxHeight: height * 0.05 - width * 0.01 - 1,
    lineSpacing: 1.5, tracking: rtl ? 0 : width * 0.001, rgb: 0x68715d, weight: .regular, rightToLeft: rtl, balanced: false)
let labelTop = height * 0.973 - label.lineHeight
fill(rect(width * 0.08, labelTop - width * 0.01 - 1, width * 0.35, 1), 0xb8c3ac)
drawText(label, x: width * 0.08, top: labelTop, width: width * 0.35, rightToLeft: rtl)
let index = fitText(String(format: "%02d / 04", panel), initial: width * 0.028, maxWidth: width * 0.3, maxHeight: height * 0.05,
    lineSpacing: 1.5, tracking: 0, rgb: 0x68715d, weight: .regular, rightToLeft: false, balanced: false)
let indexWidth = CGFloat(CTLineGetTypographicBounds(index.lines[0], nil, nil, nil))
drawText(index, x: width * 0.92 - indexWidth, top: height * 0.973 - index.lineHeight, width: indexWidth, rightToLeft: false)

try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else { fail("Cannot create PNG output.") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fail("PNG encoding failed.") }
let evidence: [String: Any] = ["language": language, "size": size, "panel": panel, "capture": capturePath,
    "output": output.path, "headline_font": headline.font.fontName, "headline_size": headline.size,
    "headline_lines": headline.lines.count, "capture_bounds": ["x": displayLeft, "y": displayTop, "width": displayWidth, "height": displayHeight],
    "status": "rendered_requires_pixel_and_visual_review"]
let evidenceData = try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
try evidenceData.write(to: output.deletingPathExtension().appendingPathExtension("json"))
print(String(data: evidenceData, encoding: .utf8)!)
