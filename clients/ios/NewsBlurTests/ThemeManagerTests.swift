import XCTest

@testable import NewsBlur

final class ThemeManagerTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let keys = ["theme_style", "theme_light", "theme_dark"]
    private var savedValues: [String: Any] = [:]

    override func setUp() {
        super.setUp()

        for key in keys {
            if let value = defaults.object(forKey: key) {
                savedValues[key] = value
            }
            defaults.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in keys {
            defaults.removeObject(forKey: key)
            if let value = savedValues[key] {
                defaults.set(value, forKey: key)
            }
        }

        savedValues.removeAll()
        super.tearDown()
    }

    func test_themeDisplayName_usesExplicitLightAndDarkVariants() throws {
        let manager = try XCTUnwrap(ThemeManager.shared)

        defaults.set("light", forKey: "theme_style")
        defaults.set("sepia", forKey: "theme_light")
        XCTAssertEqual(manager.themeDisplayName, "Warm")

        defaults.set("dark", forKey: "theme_style")
        defaults.set("medium", forKey: "theme_dark")
        XCTAssertEqual(manager.themeDisplayName, "Gray")
    }

    func test_themeCSSSuffix_followsExplicitThemeVariants() throws {
        let manager = try XCTUnwrap(ThemeManager.shared)

        defaults.set("light", forKey: "theme_style")
        defaults.set("light", forKey: "theme_light")
        XCTAssertEqual(manager.themeCSSSuffix, "Light")

        defaults.set("dark", forKey: "theme_style")
        defaults.set("dark", forKey: "theme_dark")
        XCTAssertEqual(manager.themeCSSSuffix, "Dark")
    }
}
