import XCTest
import UIKit

@testable import NewsBlur

@MainActor
final class Test_CustomIconRenderer: XCTestCase {
    private let icon_size = CGSize(width: 28, height: 28)

    func test_repeated_emoji_requests_reuse_the_rendered_image() throws {
        let data: [AnyHashable: Any] = ["icon_type": "emoji", "icon_data": "📰"]
        let first = try XCTUnwrap(CustomIconRenderer.renderIcon(data, size: icon_size))
        let second = try XCTUnwrap(CustomIconRenderer.renderIcon(data, size: icon_size))

        XCTAssertTrue(first === second, "Scrolling should reuse an emoji bitmap instead of drawing it again.")
        XCTAssertEqual(first.pngData(), CustomIconRenderer.emojiToImage("📰", size: icon_size)?.pngData())
    }

    func test_repeated_uploaded_icon_requests_reuse_the_resized_image() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let encoded = try XCTUnwrap(source.pngData()).base64EncodedString()
        let data: [AnyHashable: Any] = ["icon_type": "upload", "icon_data": "data:image/png;base64,\(encoded)"]
        let first = try XCTUnwrap(CustomIconRenderer.renderIcon(data, size: icon_size))
        let second = try XCTUnwrap(CustomIconRenderer.renderIcon(data, size: icon_size))

        XCTAssertTrue(first === second, "Scrolling should not decode and resize the same upload again.")
        XCTAssertEqual(first.size, icon_size)
    }

    func test_repeated_preset_requests_reuse_the_tinted_image() throws {
        let data = preset_data(color: "#ff5722")
        let first = try XCTUnwrap(CustomIconRenderer.renderIcon(data, size: icon_size))
        let second = try XCTUnwrap(CustomIconRenderer.renderIcon(data, size: icon_size))

        XCTAssertTrue(first === second, "Scrolling should not load and tint the same preset again.")
        let expected = CustomIconRenderer.presetIcon(
            "folder", iconSet: "lucide", size: icon_size, color: CustomIconRenderer.colorFromHex("#ff5722")
        )
        XCTAssertEqual(first.pngData(), expected?.pngData())
    }

    func test_editing_icon_configuration_never_returns_the_old_bitmap() throws {
        let original_data = preset_data(color: "#ff5722")
        let original = try XCTUnwrap(CustomIconRenderer.renderIcon(original_data, size: icon_size))
        let changes = [
            ["icon_color": "#0088ff"],
            ["icon_data": "star"],
            ["icon_set": "heroicons-solid"],
            ["icon_type": "emoji", "icon_data": "⭐️"],
        ]

        for change in changes {
            let edited_data = original_data.merging(change) { _, new_value in new_value }
            let edited = try XCTUnwrap(CustomIconRenderer.renderIcon(edited_data, size: icon_size))
            XCTAssertFalse(original === edited)
            XCTAssertNotEqual(original.pngData(), edited.pngData(), "Changed settings must change the pixels: \(change)")
        }

        XCTAssertNil(CustomIconRenderer.renderIcon(["icon_type": "none", "icon_data": "folder"], size: icon_size))
    }

    func test_icon_sizes_do_not_share_a_bitmap() throws {
        let data: [AnyHashable: Any] = ["icon_type": "emoji", "icon_data": "🌳"]
        let small = try XCTUnwrap(CustomIconRenderer.renderIcon(data, size: CGSize(width: 16, height: 16)))
        let wide = try XCTUnwrap(CustomIconRenderer.renderIcon(data, size: CGSize(width: 28, height: 16)))
        let large = try XCTUnwrap(CustomIconRenderer.renderIcon(data, size: icon_size))

        XCTAssertEqual(small.size, CGSize(width: 16, height: 16))
        XCTAssertEqual(wide.size, CGSize(width: 28, height: 16))
        XCTAssertEqual(large.size, icon_size)
        XCTAssertFalse(small === wide)
        XCTAssertFalse(wide === large)
    }

    func test_cached_icons_match_fresh_drawing_after_appearance_changes() throws {
        let data = preset_data(color: "#95968e")
        for style in [UIUserInterfaceStyle.light, .dark] {
            for scale: CGFloat in [2, 3] {
                let traits = UITraitCollection(traitsFrom: [
                    UITraitCollection(userInterfaceStyle: style),
                    UITraitCollection(displayScale: scale),
                    UITraitCollection(accessibilityContrast: .high),
                ])
                traits.performAsCurrent {
                    let cached = CustomIconRenderer.renderIcon(data, size: icon_size)
                    let fresh = CustomIconRenderer.presetIcon(
                        "folder", iconSet: "lucide", size: icon_size,
                        color: CustomIconRenderer.colorFromHex("#95968e")
                    )
                    XCTAssertNotNil(cached)
                    XCTAssertEqual(cached?.scale, fresh?.scale)
                    XCTAssertEqual(cached?.pngData(), fresh?.pngData())
                }
            }
        }
    }

    func test_invalid_configuration_does_not_reuse_a_previous_image() {
        XCTAssertNil(CustomIconRenderer.renderIcon(nil, size: icon_size))
        XCTAssertNil(CustomIconRenderer.renderIcon(["icon_type": "emoji"], size: icon_size))
        XCTAssertNil(CustomIconRenderer.renderIcon(["icon_type": "emoji", "icon_data": ""], size: icon_size))
        XCTAssertNil(CustomIconRenderer.renderIcon(["icon_type": "upload", "icon_data": "invalid"], size: icon_size))
        XCTAssertNil(CustomIconRenderer.renderIcon(["icon_type": "preset", "icon_data": "not-an-icon"], size: icon_size))
    }

    func test_repeated_icon_rendering_performance() {
        let configurations: [[AnyHashable: Any]] = [
            ["icon_type": "emoji", "icon_data": "📰"],
            ["icon_type": "emoji", "icon_data": "🌳"],
            preset_data(color: "#95968e"),
        ]
        measure {
            for _ in 0..<100 {
                for configuration in configurations {
                    autoreleasepool {
                        _ = CustomIconRenderer.renderIcon(configuration, size: icon_size)
                    }
                }
            }
        }
    }

    private func preset_data(color: String) -> [AnyHashable: Any] {
        ["icon_type": "preset", "icon_data": "folder", "icon_set": "lucide", "icon_color": color]
    }
}
