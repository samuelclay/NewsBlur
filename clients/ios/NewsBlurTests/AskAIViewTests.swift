import XCTest
import UIKit
import SwiftUI

@testable import NewsBlur

@MainActor final class Test_AskAIComposerLayout: XCTestCase {
    func test_customQuestionRemainsEditableWhenKeyboardShrinksThePopover() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        let model = AskAIViewModel(story: ["story_hash": "layout-fixture", "story_title": "Fixture story"])
        model.customQuestion = "Keep this draft when the keyboard appears"
        let host = UIHostingController(rootView: AskAIView(viewModel: model, onDismiss: {}))
        root.addChild(host)
        root.view.addSubview(host.view)
        host.didMove(toParent: root)
        host.view.clipsToBounds = true
        defer {
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }

        // AskAIViewTests.swift reproduces the popover's reduced height above a landscape iPad keyboard.
        for height: CGFloat in [630, 400, 280, 630] {
            host.view.frame = CGRect(x: 20, y: 40, width: 500, height: height)
            host.view.setNeedsLayout()
            root.view.layoutIfNeeded()
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                host.view.layoutIfNeeded()
                return self.textFields(in: host.view).contains { $0.bounds.height > 0 }
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: SimulatorTestTiming.realWorkTimeout), .completed)
            let field = try XCTUnwrap(textFields(in: host.view).first)
            let frame = field.convert(field.bounds, to: host.view)
            XCTAssertTrue(host.view.bounds.contains(frame),
                          "The custom question must stay completely visible after the popover shrinks to \(height): \(frame)")
            XCTAssertEqual(field.text, model.customQuestion)
            XCTAssertFalse(model.hasAskedQuestion, "Resizing the composer must preserve the draft without sending it")
        }
    }

    private func textFields(in view: UIView) -> [UITextField] {
        (view as? UITextField).map { [$0] } ?? view.subviews.flatMap { textFields(in: $0) }
    }
}

