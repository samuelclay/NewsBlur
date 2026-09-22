import UIKit
import XCTest

@testable import NewsBlur

@MainActor final class Test_StoryReaderPopGesture: XCTestCase {
    private let keys = ["story_detail_swipe_left_edge", "scroll_stories_horizontally"]
    private var preferences: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        let bundle = Bundle(for: NewsBlurAppDelegate.self).bundleIdentifier ?? ""
        let persisted = UserDefaults.standard.persistentDomain(forName: bundle) ?? [:]
        for key in keys { preferences[key] = persisted[key] }
    }

    override func tearDown() {
        for key in keys {
            if let value = preferences[key] { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        preferences.removeAll()
        super.tearDown()
    }

    func test_initialAppearanceHonorsPreviousStoryAndBackPreferences() throws {
        for preference in ["previous_story", "pop_to_story_list"] {
            for horizontal in [true, false] {
                UserDefaults.standard.set(preference, forKey: keys[0])
                UserDefaults.standard.set(horizontal, forKey: keys[1])
                let (pages, navigation) = makeReader()
                pages.viewDidAppear(false)
                try assertGestures(pages, navigation, preference: preference, horizontal: horizontal)
            }
        }
    }

    func test_changingScrollOrientationPreservesBothPreferences() throws {
        for preference in ["previous_story", "pop_to_story_list"] {
            UserDefaults.standard.set(preference, forKey: keys[0])
            let (pages, navigation) = makeReader()
            pages.viewDidAppear(false)
            for horizontal in [true, false, true] {
                UserDefaults.standard.set(horizontal, forKey: keys[1])
                pages.changedScrollOrientation()
                try assertGestures(pages, navigation, preference: preference, horizontal: horizontal)
            }
        }
    }

    func test_reappearingReaderRechecksPreferenceForExistingGestures() throws {
        for horizontal in [true, false] {
            UserDefaults.standard.set(horizontal, forKey: keys[1])
            let (pages, navigation) = makeReader()
            for preference in ["pop_to_story_list", "previous_story", "pop_to_story_list"] {
                UserDefaults.standard.set(preference, forKey: keys[0])
                pages.viewDidAppear(false)
                try assertGestures(pages, navigation, preference: preference, horizontal: horizontal)
            }
        }
    }

    private func makeReader() -> (ReaderPopGesturePages, UINavigationController) {
        let pages = ReaderPopGesturePages()
        pages.appDelegate = ReaderPopGestureAppDelegate()
        pages.loadViewIfNeeded()
        pages.scrollView = UIScrollView(frame: pages.view.bounds)
        pages.view.addSubview(pages.scrollView)
        let navigation = UINavigationController()
        navigation.viewControllers = [UIViewController(), pages]
        navigation.loadViewIfNeeded()
        return (pages, navigation)
    }

    private func assertGestures(_ pages: ReaderPopGesturePages, _ navigation: UINavigationController,
                                preference: String, horizontal: Bool) throws {
        let edge = try XCTUnwrap(navigation.interactivePopGestureRecognizer)
        let fullScreen = try XCTUnwrap(pages.fullScreenPopGesture)
        let enabled = preference == "pop_to_story_list"
        XCTAssertEqual(edge.isEnabled, enabled && horizontal, "preference=\(preference), horizontal=\(horizontal)")
        XCTAssertEqual(fullScreen.isEnabled, enabled && !horizontal, "preference=\(preference), horizontal=\(horizontal)")
    }
}

@MainActor private final class ReaderPopGesturePages: StoryPagesObjCViewController {
    // StoryReaderPopGestureTests.swift exercises real appearance and gesture setup without loading article content.
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 667)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func reorientPages() {}
}

private final class ReaderPopGestureAppDelegate: NewsBlurAppDelegate {
    override var isCompactWidth: Bool { true }
    override func adjustStoryDetailWebView() {}
}
