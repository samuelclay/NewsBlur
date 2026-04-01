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
