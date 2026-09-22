// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NewsBluriOSLogic",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "StoryAutoCollapseDecision",
            targets: ["StoryAutoCollapseDecision"]
        ),
    ],
    targets: [
        .target(
            name: "StoryAutoCollapseDecision",
            path: "Classes",
            // Package.swift tests portable logic; SwiftPM must not compile the neighboring iOS interfaces.
            exclude: [
                "AuthorizeServicesViewController.xib",
                "FeedChooserViewController.xib",
                "FirstTimeUserAddFriendsViewController.xib",
                "FirstTimeUserAddNewsBlurViewController.xib",
                "FirstTimeUserAddSitesViewController.xib",
                "FirstTimeUserViewController.xib",
                "FontListViewController.xib",
                "FontSettingsViewController.xib",
                "LaunchScreen.xib",
                "LaunchScreenDev.xib",
                "MenuViewController.xib",
                "PremiumViewController.xib",
                "ShareViewController~ipad.xib",
                "StoryPagesViewController.xib",
            ],
            sources: ["StoryAutoCollapseDecision.swift", "ClassifierScope.swift"]
        ),
        .testTarget(
            name: "StoryAutoCollapseDecisionTests",
            dependencies: ["StoryAutoCollapseDecision"],
            path: "Tests/StoryAutoCollapseDecisionTests"
        ),
        .testTarget(
            name: "StoryDetailHighlightTests",
            path: "Tests/StoryDetailHighlightTests"
        ),
    ]
)
