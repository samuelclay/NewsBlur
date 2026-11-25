import XCTest

@testable import NewsBlur

/// PremiumArchiveCardTests.swift: what the Premium Archive card sells on the premium screen (PremiumView.swift) once
/// the 1 hour / 10 hours Listen toggle can turn it into Premium Archive Extra.
final class Test_PremiumArchiveCard: XCTestCase {
    func test_withoutTheExtraProductTheCardStaysPlainPremiumArchive() {
        // A choice left on the toggle must not sell a product StoreKit didn't return.
        let free = PremiumArchiveCard(chosenPlan: .archiveExtra)
        XCTAssertFalse(free.showsListenToggle)
        XCTAssertEqual(free.status, .purchase(.archive, upgradeFrom: nil))

        let premium = PremiumArchiveCard(isPremium: true, chosenPlan: .archiveExtra)
        XCTAssertEqual(premium.status, .purchase(.archive, upgradeFrom: .premium))

        let archive = PremiumArchiveCard(isPremium: true, isArchive: true, chosenPlan: .archiveExtra)
        XCTAssertFalse(archive.showsListenToggle)
        XCTAssertEqual(archive.status, .active)
    }

    func test_archiveSubscriberPickingExtraIsOfferedTheUpgrade() {
        var card = PremiumArchiveCard(isPremium: true, isArchive: true, storeSellsArchiveExtra: true)
        XCTAssertTrue(card.showsListenToggle)
        XCTAssertEqual(card.plan, .archive)
        XCTAssertEqual(card.status, .active)

        card.chosenPlan = .archiveExtra
        XCTAssertEqual(card.status, .purchase(.archiveExtra, upgradeFrom: .archive))
    }

    func test_extraSubscriberStartsOnExtraAndIsNeverSoldPremiumArchive() {
        // The account's tier comes from the server, so the toggle shows even when StoreKit returned nothing.
        for storeSellsArchiveExtra in [true, false] {
            var card = PremiumArchiveCard(isPremium: true, isArchive: true, isArchiveExtra: true,
                                          storeSellsArchiveExtra: storeSellsArchiveExtra)
            XCTAssertTrue(card.showsListenToggle)
            XCTAssertEqual(card.plan, .archiveExtra)
            XCTAssertEqual(card.status, .active)

            card.chosenPlan = .archive
            XCTAssertEqual(card.status, .included(by: .archiveExtra))
        }
    }

    func test_proSubscriberSeesTheArchiveCardWithoutTheToggle() {
        let card = PremiumArchiveCard(isPremium: true, isArchive: true, isPro: true, storeSellsArchiveExtra: true,
                                      chosenPlan: .archiveExtra)
        XCTAssertFalse(card.showsListenToggle)
        XCTAssertEqual(card.plan, .archive)
        XCTAssertEqual(card.status, .included(by: .pro))
    }
}
