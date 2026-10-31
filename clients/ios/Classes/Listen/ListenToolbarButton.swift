//
//  ListenToolbarButton.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-31.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import UIKit

/// ListenToolbarButton.swift keeps the Listen buttons in the story reader's chrome in step with ListenPlayer: the
/// navigation bar item on iPad, the iOS 27 vertical reader toolbar item and the button in the iPhone's
/// full-screen StoryToolbar (StoryToolbar.swift). Headphones start reading the story on screen aloud, a pause
/// symbol shows while that story is being read and a play symbol while it is paused. Every button calls
/// toggleListen: (BaseViewController.m), the same action as the Y key and the end-of-story Listen button. The Mac
/// keeps its own toolbar item (ToolbarDelegate.swift), so StoryPagesObjCViewController.m adds none of these there.
@objcMembers final class ListenToolbarButton: NSObject {
    /// Whether Listen appears at all. The "listen" story button preference (ListenPreferences.swift) hides the
    /// end-of-story button and these together.
    static var isShown: Bool { ListenPreferences.showsStoryButton("listen") }

    private struct State {
        let symbol: String
        let title: String
        let isActive: Bool
    }

    private static let idleSymbol = "headphones"
    private static let buttonSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)

    private let story: () -> [AnyHashable: Any]?
    private var barItems: [UIBarButtonItem] = []
    private var buttons: [UIButton] = []
    private var observers: [NSObjectProtocol] = []

    /// `story` returns the story on screen, whose state the buttons show (StoryPagesObjCViewController.m
    /// currentPage.activeStory).
    init(story: @escaping () -> [AnyHashable: Any]?) {
        self.story = story
        super.init()
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: ListenPlayer.stateDidChange, object: nil, queue: .main) { [weak self] _ in
                self?.update()
            },
            center.addObserver(forName: ListenPreferences.didChange, object: nil, queue: .main) { [weak self] _ in
                self?.update()
            },
            center.addObserver(forName: ListenThemeObserver.didChange, object: nil, queue: .main) { [weak self] _ in
                self?.update()
            }
        ]
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// A navigation bar item that sends `action` to `target` (StoryPagesObjCViewController.m, toggleListen:).
    func makeBarItem(target: Any?, action: Selector, identifier: String) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: UIImage(systemName: Self.idleSymbol), style: .plain, target: target, action: action)
        item.accessibilityIdentifier = identifier
        attach(barItem: item)
        return item
    }

    /// Adopts an item made elsewhere, like the vertical reader toolbar's (StoryPagesObjCViewController.m
    /// readerBarButtonWithTitle:symbol:identifier:action:).
    @objc(attachBarItem:)
    func attach(barItem: UIBarButtonItem) {
        barItems.append(barItem)
        update()
    }

    /// Adopts a plain button, like StoryToolbar.swift's.
    @objc(attachButton:)
    func attach(button: UIButton) {
        buttons.append(button)
        update()
    }

    /// Redraws every button for the story on screen, the player's state, the preference and the theme.
    func update() {
        let state = currentState
        let hidden = !Self.isShown
        let image = UIImage(systemName: state.symbol)
        let tint = state.isActive ? Self.activeTint : Self.idleTint
        for item in barItems {
            item.image = image
            item.title = state.title
            item.accessibilityLabel = state.title
            item.tintColor = tint
            item.isHidden = hidden
        }
        for button in buttons {
            button.setImage(image?.withConfiguration(Self.buttonSymbolConfiguration), for: .normal)
            button.accessibilityLabel = state.title
            button.tintColor = tint
            button.isHidden = hidden
        }
    }

    private var currentState: State {
        let player = ListenPlayer.shared
        guard player.isLoaded(storyHash: story()?["story_hash"] as? String) else {
            return State(symbol: Self.idleSymbol, title: NBLocalization.text("Listen"), isActive: false)
        }
        if player.wantsToPlay {
            return State(symbol: "pause.circle", title: NBLocalization.text("Pause Listening"), isActive: true)
        }
        return State(symbol: "play.circle", title: NBLocalization.text("Resume Listening"), isActive: true)
    }

    /// The reader's toolbar button tint (StoryPagesObjCViewController.m applyToolbarButtonTint).
    private static var idleTint: UIColor {
        ListenColors.uiColor(light: 0x8F918B, sepia: 0x8B7B6B, medium: 0xAEAFAF, dark: 0xAEAFAF)
    }

    /// Listen's accent (ListenTheme.swift), for the story being read.
    private static var activeTint: UIColor {
        ListenColors.uiColor(light: 0x709E5D, sepia: 0x6E865F, medium: 0x8BBF74, dark: 0x8BBF74)
    }
}
