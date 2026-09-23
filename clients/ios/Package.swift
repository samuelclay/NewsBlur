// swift-tools-version: 6.0

import PackageDescription

// Package.swift excludes iOS interfaces from the portable logic targets.
let iOSInterfaceResources = [
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
]

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
            exclude: iOSInterfaceResources,
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
        .target(
            name: "FeedSubscriptionURLs",
            path: "Classes",
            exclude: iOSInterfaceResources,
            sources: ["FeedSubscriptionURL.swift"]
        ),
        .target(
            name: "FeedSubscriptionRequest",
            path: "Subscribe Extension",
            exclude: ["Info.plist", "Subscribe Extension.entitlements",
                      "SubscribeIcon@2x.png", "SubscribeIcon@3x.png"],
            sources: ["FeedSubscriptionRequest.swift"]
        ),
        .testTarget(
            name: "FeedSubscriptionTests",
            dependencies: ["FeedSubscriptionURLs", "FeedSubscriptionRequest"],
            path: "Tests/FeedSubscriptionTests"
        ),
    ]
)
