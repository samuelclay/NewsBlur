import XCTest

@testable import StoryAutoCollapseDecision

final class ClassifierScopeResolverTests: XCTestCase {
    func test_resolveInfo_reads_global_text_scope_metadata() {
        let classifiers: [AnyHashable: Any] = [
            "texts_scope": [
                "Claude Code": [
                    "scope": "global",
                    "folder_name": "",
                ]
            ]
        ]

        let info = ClassifierScopeResolver.resolveInfo(
            from: classifiers,
            classifierKey: "texts",
            name: "Claude Code"
        )

        XCTAssertEqual(info.scope, .global)
        XCTAssertEqual(info.folderName, "")
    }

    func test_resolveInfo_reads_author_regex_scope_from_authors_scope_like_the_server() {
        let classifiers: [AnyHashable: Any] = [
            "authors_scope": [
                "department of \\w+": [
                    "scope": "folder",
                    "folder_name": "Apple",
                ]
            ]
        ]

        let info = ClassifierScopeResolver.resolveInfo(
            from: classifiers,
            classifierKey: "author_regex",
            name: "department of \\w+"
        )

        XCTAssertEqual(info.scope, .folder)
        XCTAssertEqual(info.folderName, "Apple")
    }

    func test_effectiveScope_preserves_default_scope_without_override() {
        let scope = ClassifierScopeResolver.effectiveScope(
            overrides: [:],
            type: "text",
            name: "Claude Code",
            default: .global
        )

        XCTAssertEqual(scope, .global)
    }
}
