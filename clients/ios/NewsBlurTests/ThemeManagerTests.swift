import XCTest
import UIKit

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

    @MainActor func test_storyListSurfaceDoesNotFlashWhileRowsEnter() throws {
        // ThemeManagerTests.swift protects the exposed loading/entrance surface, not a particular palette value.
        // Leaving UIKit's default background under the fading story artwork produces a black flash in Gray.
        let controller = StorySurfaceController()
        controller.appDelegate = nil
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 375, height: 200), style: .plain)
        let source = StorySurfaceDataSource()
        table.dataSource = source
        table.rowHeight = 120
        table.separatorStyle = .none
        controller.storyTitlesTable = table
        controller.view = UIView(frame: table.frame)
        controller.view.addSubview(table)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(controller.view)
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }

        for theme in ["medium", "sepia", "light", "dark"] {
            defaults.set(theme, forKey: "theme_style")
            controller.updateTheme()
            table.reloadData()
            table.layoutIfNeeded()
            let cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)) as? FeedDetailTableCell)
            cell.contentView.alpha = 1
            cell.setNeedsDisplay()
            cell.layer.displayIfNeeded()
            (cell.value(forKey: "cellContent") as? UIView)?.layer.displayIfNeeded()
            let point = CGPoint(x: table.bounds.width - 30, y: cell.frame.midY)
            let settled = try backgroundPixel(table, point: point)
            for opacity: CGFloat in [0, 0.5] {
                cell.contentView.alpha = opacity
                let entering = try backgroundPixel(table, point: point)
                for channel in 0..<3 {
                    XCTAssertEqual(entering[channel], settled[channel], accuracy: 2,
                                   "\(theme) must keep the settled story surface while entrance opacity is \(opacity)")
                }
            }
            cell.contentView.alpha = 1
            cell.isHidden = true
            let loading = try backgroundPixel(table, point: point)
            for channel in 0..<3 {
                XCTAssertEqual(loading[channel], settled[channel], accuracy: 2,
                               "\(theme) loading surface must match the story rows about to appear")
            }
            cell.isHidden = false
        }
    }

    @MainActor private func backgroundPixel(_ view: UIView, point: CGPoint) throws -> [Double] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image {
            view.layer.render(in: $0.cgContext)
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8,
                                             bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cgImage, in: CGRect(x: -point.x, y: point.y - view.bounds.height + 1,
                                       width: view.bounds.width, height: view.bounds.height))
        return pixel.map(Double.init)
    }

    @MainActor func test_loadingPulseStaysCloseToStoryListSurface() throws {
        // ThemeManagerTests.swift catches a loading placeholder swinging from Gray to almost black before stories arrive.
        let controller = StorySurfaceController()
        controller.appDelegate = nil
        controller.view = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 200))
        controller.storyTitlesTable = UITableView(frame: controller.view.bounds)
        controller.view.addSubview(controller.storyTitlesTable)
        let loading = NBLoadingCell(frame: CGRect(x: 0, y: 0, width: 375, height: 120))
        controller.storyTitlesTable.addSubview(loading)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(controller.view)
        window.makeKeyAndVisible()
        defer {
            loading.endAnimation()
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }

        for theme in ["medium", "sepia", "light", "dark"] {
            defaults.set(theme, forKey: "theme_style")
            controller.updateTheme()
            loading.animate()
            let pulse = try XCTUnwrap(loading.layer.animation(forKey: "readerLoadingPulse") as? CABasicAnimation)
            let base = try XCTUnwrap(controller.storyTitlesTable.backgroundColor)
            let endpoints = try [pulse.fromValue, pulse.toValue].map { value in
                UIColor(cgColor: try XCTUnwrap(value as! CGColor?))
            }
            var baseR: CGFloat = 0, baseG: CGFloat = 0, baseB: CGFloat = 0, baseA: CGFloat = 0
            base.getRed(&baseR, green: &baseG, blue: &baseB, alpha: &baseA)
            for endpoint in endpoints {
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                endpoint.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                for (component, surface) in zip([red, green, blue], [baseR, baseG, baseB]) {
                    XCTAssertGreaterThanOrEqual(component, surface - 0.01, "\(theme) loading must not flash darker than its surrounding surface")
                    XCTAssertLessThanOrEqual(component - surface, 0.08, "\(theme) loading activity should remain a subtle surface change")
                }
            }
        }
    }
}

@MainActor private final class StorySurfaceController: FeedDetailObjCViewController {
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewDidLayoutSubviews() {}
    override func reload() {}
}

@MainActor private final class StorySurfaceDataSource: NSObject, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
        cell.storyTitle = "A story to reveal"
        cell.storyAuthor = ""
        cell.storyDate = ""
        cell.storyContent = ""
        cell.storyHash = "surface-test"
        cell.textSize = .short
        return cell
    }
}
