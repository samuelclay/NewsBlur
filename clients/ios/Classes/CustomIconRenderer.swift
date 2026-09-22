//
//  CustomIconRenderer.swift
//  NewsBlur
//
//  Created by Samuel Clay on 1/7/26.
//  Copyright (c) 2026 NewsBlur. All rights reserved.
//

import UIKit

@objcMembers
class CustomIconRenderer: NSObject {

    private static let renderedIconCache: NSCache<RenderedIconKey, UIImage> = {
        let cache = NSCache<RenderedIconKey, UIImage>()
        cache.name = "CustomIconRenderer.renderedIcons"
        cache.countLimit = 512
        cache.totalCostLimit = 8 * 1024 * 1024
        return cache
    }()

    private final class RenderedIconKey: NSObject {
        let iconType: String
        let iconData: String
        let iconColor: String?
        let iconSet: String
        let size: CGSize
        let scale: CGFloat
        let traits: UITraitCollection

        init(iconType: String, iconData: String, iconColor: String?, iconSet: String, size: CGSize) {
            self.iconType = iconType
            self.iconData = iconData
            self.iconColor = iconColor
            self.iconSet = iconSet
            self.size = size
            self.scale = UIGraphicsImageRendererFormat.default().scale
            self.traits = UITraitCollection.current
        }

        override var hash: Int {
            var hasher = Hasher()
            hasher.combine(iconType)
            hasher.combine(iconData)
            hasher.combine(iconColor)
            hasher.combine(iconSet)
            hasher.combine(size.width)
            hasher.combine(size.height)
            hasher.combine(scale)
            hasher.combine(traits.hash)
            return hasher.finalize()
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? RenderedIconKey else {
                return false
            }

            return iconType == other.iconType && iconData == other.iconData &&
                iconColor == other.iconColor && iconSet == other.iconSet &&
                size == other.size && scale == other.scale && traits.isEqual(other.traits)
        }
    }

    /// Renders a custom icon from icon data dictionary.
    /// - Parameters:
    ///   - iconData: Dictionary containing icon_type, icon_data, icon_color, icon_set
    ///   - size: The desired size for the icon
    /// - Returns: UIImage of the rendered icon, or nil if icon_type is "none" or invalid
    static func renderIcon(_ iconData: [AnyHashable: Any]?, size: CGSize) -> UIImage? {
        guard let iconData = iconData else {
            return nil
        }

        guard let iconType = iconData["icon_type"] as? String,
              iconType != "none",
              let iconDataStr = iconData["icon_data"] as? String else {
            return nil
        }

        let iconColor = iconData["icon_color"] as? String
        let iconSet = (iconData["icon_set"] as? String) ?? "lucide"

        // CustomIconRenderer.swift keys by configuration so icon edits and appearance changes take effect immediately.
        let cacheKey = RenderedIconKey(
            iconType: iconType, iconData: iconDataStr, iconColor: iconColor, iconSet: iconSet, size: size
        )
        if let image = renderedIconCache.object(forKey: cacheKey) {
            return image
        }

        var color: UIColor?
        if let iconColor = iconColor, !iconColor.isEmpty {
            color = colorFromHex(iconColor)
        }

        let renderedImage: UIImage?
        switch iconType {
        case "emoji":
            renderedImage = emojiToImage(iconDataStr, size: size)
        case "upload":
            guard var image = base64ToImage(iconDataStr) else {
                return nil
            }
            if image.size.width != size.width || image.size.height != size.height {
                let renderer = UIGraphicsImageRenderer(size: size)
                image = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
            }
            renderedImage = image
        case "preset":
            renderedImage = presetIcon(iconDataStr, iconSet: iconSet, size: size, color: color)
        default:
            return nil
        }

        if let image = renderedImage, let bitmap = image.cgImage {
            // CustomIconRenderer.swift includes retained upload strings in the cache's memory budget.
            let cost = bitmap.bytesPerRow * bitmap.height + iconDataStr.utf8.count +
                iconType.utf8.count + iconSet.utf8.count + (iconColor?.utf8.count ?? 0)
            if cost <= renderedIconCache.totalCostLimit {
                renderedIconCache.setObject(image, forKey: cacheKey, cost: cost)
            }
        }
        return renderedImage
    }

    /// Renders an emoji string to a UIImage.
    /// - Parameters:
    ///   - emoji: The emoji character(s) to render
    ///   - size: The desired size for the image
    /// - Returns: UIImage containing the rendered emoji
    static func emojiToImage(_ emoji: String, size: CGSize) -> UIImage? {
        guard !emoji.isEmpty else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            // Calculate font size to fit the emoji in the given size
            // Use 85% of the size to leave some padding
            let fontSize = size.height * 0.85
            let font = UIFont.systemFont(ofSize: fontSize)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font
            ]

            // Calculate the size of the emoji with this font
            let textSize = emoji.size(withAttributes: attributes)

            // Center the emoji in the image
            let drawPoint = CGPoint(
                x: (size.width - textSize.width) / 2.0,
                y: (size.height - textSize.height) / 2.0
            )

            emoji.draw(at: drawPoint, withAttributes: attributes)
        }
    }

    /// Decodes a base64 PNG string to UIImage.
    /// - Parameter base64String: Base64-encoded PNG data (may include data:image/png;base64, prefix)
    /// - Returns: UIImage decoded from the base64 string, or nil if invalid
    static func base64ToImage(_ base64String: String) -> UIImage? {
        guard !base64String.isEmpty else {
            return nil
        }

        // Remove data URL prefix if present
        var cleanBase64 = base64String
        if let commaIndex = base64String.firstIndex(of: ",") {
            cleanBase64 = String(base64String[base64String.index(after: commaIndex)...])
        }

        guard let imageData = Data(base64Encoded: cleanBase64, options: .ignoreUnknownCharacters) else {
            return nil
        }

        return UIImage(data: imageData)
    }

    /// Loads a preset icon from bundled assets.
    /// - Parameters:
    ///   - iconName: The name of the icon (e.g., "star", "folder")
    ///   - iconSet: The icon set ("lucide" or "heroicons-solid")
    ///   - size: The desired size for the icon
    ///   - color: Optional tint color for the icon
    /// - Returns: UIImage of the preset icon, or nil if not found
    static func presetIcon(_ iconName: String, iconSet: String, size: CGSize, color: UIColor?) -> UIImage? {
        guard !iconName.isEmpty else {
            return nil
        }

        // Sanitize icon set name
        let setName = iconSet.isEmpty ? "lucide" : iconSet
        let subpath = "Icons/\(setName)"

        // Try @3x first for best quality on modern devices
        var pngPath = Bundle.main.path(forResource: "\(iconName)@3x", ofType: "png", inDirectory: subpath)

        // Fall back to @2x
        if pngPath == nil {
            pngPath = Bundle.main.path(forResource: "\(iconName)@2x", ofType: "png", inDirectory: subpath)
        }

        guard let path = pngPath, var image = UIImage(contentsOfFile: path) else {
            return nil
        }

        // Render the image as a template if we need to apply color
        if let color = color {
            image = image.withRenderingMode(.alwaysTemplate)

            let renderer = UIGraphicsImageRenderer(size: size)
            image = renderer.image { context in
                color.setFill()
                let rect = CGRect(origin: .zero, size: size)

                // Flip the context for correct orientation
                context.cgContext.translateBy(x: 0, y: size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)

                // Draw the image as a mask
                context.cgContext.clip(to: rect, mask: image.cgImage!)
                context.cgContext.fill(rect)
            }
        } else {
            // Resize the image if needed
            if image.size.width != size.width || image.size.height != size.height {
                let renderer = UIGraphicsImageRenderer(size: size)
                image = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
            }
        }

        return image
    }

    /// Parses a hex color string to UIColor.
    /// - Parameter hexString: Hex color string (e.g., "#ff5722" or "ff5722")
    /// - Returns: UIColor from the hex string, or nil if invalid
    static func colorFromHex(_ hexString: String) -> UIColor? {
        guard !hexString.isEmpty else {
            return nil
        }

        // Remove # prefix if present
        var hex = hexString
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }

        // Must be 6 characters for RGB
        guard hex.count == 6 else {
            return nil
        }

        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        guard scanner.scanHexInt64(&rgbValue) else {
            return nil
        }

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
