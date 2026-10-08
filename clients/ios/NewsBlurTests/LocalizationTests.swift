import XCTest

@testable import NewsBlur

@MainActor
final class Test_Localization: XCTestCase {
    func test_missingObjectiveCCountOmitsTheStatistic() {
        // LocalizationTests.swift reproduces NotificationsViewController.m passing a missing feed statistic.
        let result = NBLocalization.perform(#selector(NBLocalization.plural(_:count:)),
                                            with: "%@ stories/month", with: nil)
        XCTAssertEqual(result?.takeUnretainedValue() as? String, "")
    }

    func test_accountOverrideControlsPluralRules() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: NBLocalization.preferenceKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: NBLocalization.preferenceKey)
            } else {
                defaults.removeObject(forKey: NBLocalization.preferenceKey)
            }
        }

        // LocalizationTests.swift catches using the device's English plural rule with Russian copy.
        defaults.set("ru", forKey: NBLocalization.preferenceKey)
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", count: 1), "1 подписчик")
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", count: 2), "2 подписчика")
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", count: 5), "5 подписчиков")

        defaults.set("en", forKey: NBLocalization.preferenceKey)
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", count: 1), "1 subscriber")
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", count: 2), "2 subscribers")
    }
}
