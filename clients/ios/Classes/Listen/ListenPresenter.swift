//
//  ListenPresenter.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI
import UIKit

/// ListenPresenter.swift presents Now Playing and voice settings: a page sheet on iPhone, a form sheet on iPad and Mac.
enum ListenPresenter {
    private static weak var nowPlaying: UIViewController?

    static func presentNowPlaying() {
        guard ListenPlayer.shared.isActive else { return }
        if let nowPlaying, nowPlaying.presentingViewController != nil { return }
        let controller = ListenHostingController(rootView: AnyView(
            NavigationStack {
                ListenNowPlayingView()
            }
        ))
        nowPlaying = controller
        present(controller)
    }

    /// Voice settings on their own, from Preferences.
    static func presentVoiceSettings(from presenter: UIViewController?) {
        let controller = ListenHostingController(rootView: AnyView(
            NavigationStack {
                ListenVoiceSettingsView(showsDoneButton: true)
            }
        ))
        present(controller, from: presenter)
    }

    static func dismissNowPlaying(completion: (() -> Void)? = nil) {
        guard let nowPlaying, nowPlaying.presentingViewController != nil else {
            completion?()
            return
        }
        nowPlaying.dismiss(animated: true, completion: completion)
    }

    /// Dismisses Listen sheets first so the premium screen isn't stacked under them (NewsBlurAppDelegate.m).
    static func showUpgrade(_ upgrade: ListenPlaybackError.Upgrade) {
        guard let appDelegate = NewsBlurAppDelegate.shared() else { return }
        dismissNowPlaying {
            if upgrade == .pro {
                appDelegate.showPremiumDialogForPro()
            } else {
                appDelegate.showPremiumDialogForArchive()
            }
        }
    }

    private static func present(_ controller: UIViewController, from presenter: UIViewController? = nil) {
        guard let appDelegate = NewsBlurAppDelegate.shared() else { return }
        controller.overrideUserInterfaceStyle = ListenColors.interfaceStyle
        if appDelegate.isPhone {
            controller.modalPresentationStyle = .pageSheet
            if let sheet = controller.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 16
            }
        } else {
            controller.modalPresentationStyle = .formSheet
            controller.preferredContentSize = CGSize(width: 460, height: 720)
        }
        var top: UIViewController? = presenter ?? appDelegate.splitViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        top?.present(controller, animated: true)
    }
}

/// Hosts a Listen SwiftUI screen with the NewsBlur theme's background (ListenPresenter.swift).
final class ListenHostingController: UIHostingController<AnyView> {
    private var themeObserver: NSObjectProtocol?

    override init(rootView: AnyView) {
        super.init(rootView: rootView)
        themeObserver = NotificationCenter.default.addObserver(forName: ListenThemeObserver.didChange, object: nil,
                                                               queue: .main) { [weak self] _ in
            self?.applyTheme()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()
    }

    private func applyTheme() {
        overrideUserInterfaceStyle = ListenColors.interfaceStyle
        view.backgroundColor = ListenColors.uiColor(light: 0xF0F2ED, sepia: 0xF3E8D8, medium: 0x2C2C2E, dark: 0x111111)
    }
}
