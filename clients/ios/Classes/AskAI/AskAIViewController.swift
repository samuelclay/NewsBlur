//
//  AskAIViewController.swift
//  NewsBlur
//
//  Created by Claude on 2024-12-06.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI
import Combine

@available(iOS 15.0, *)
@objc class AskAIViewController: BaseViewController {
    private var story: [String: Any]
    private var hostingController: UIHostingController<AskAIView>?
    private(set) var viewModel: AskAIViewModel?
    private var cancellables = Set<AnyCancellable>()

    /// Called when user selects a question (for iPad popover-to-sheet transition)
    @objc var onQuestionAsked: (() -> Void)?

    @objc init(story: [String: Any]) {
        self.story = story
        super.init(nibName: nil, bundle: nil)
        // Must set appDelegate manually since super.init(nibName:bundle:) doesn't call BaseViewController.init
        self.appDelegate = NewsBlurAppDelegate.shared()
    }

    /// Initialize with an existing view model (for re-presenting after popover dismissal)
    /// Not @objc because AskAIViewModel isn't ObjC-representable
    init(existingViewModel: AskAIViewModel) {
        self.story = existingViewModel.story
        self.viewModel = existingViewModel
        super.init(nibName: nil, bundle: nil)
        self.appDelegate = NewsBlurAppDelegate.shared()
    }

    /// Factory method for ObjC to create a view controller with existing view model
    @objc static func create(withViewModel viewModel: Any) -> AskAIViewController? {
        guard let vm = viewModel as? AskAIViewModel else { return nil }
        return AskAIViewController(existingViewModel: vm)
    }

    /// Get view model as Any for storing in ObjC property
    @objc var viewModelAsAny: Any? {
        return viewModel
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set background color to match theme
        updateBackgroundColor()

        // Create view model if not already provided
        let viewModel = self.viewModel ?? AskAIViewModel(story: story)
        self.viewModel = viewModel

        // Observe hasAskedQuestion to enable large detent when answer mode
        viewModel.$hasAskedQuestion
            .dropFirst() // Skip initial value to only react to changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasAsked in
                if hasAsked {
                    self?.onQuestionAsked?()
                    self?.enableLargeDetent()
                    // Grow popover for response view
                    self?.preferredContentSize = CGSize(width: 500, height: 630)
                }
            }
            .store(in: &cancellables)

        // Create SwiftUI view
        let askAIView = AskAIView(viewModel: viewModel) { [weak self] in
            self?.dismiss(animated: true)
        }

        // Create hosting controller
        let hostingController = UIHostingController(rootView: askAIView)
        hostingController.view.backgroundColor = .clear
        self.hostingController = hostingController

        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        // Setup constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func updateBackgroundColor() {
        // Get background color based on current effective theme (resolves auto to actual variant)
        let theme = ThemeManager.shared.effectiveTheme ?? ThemeStyleLight
        let backgroundColor: UIColor
        switch theme {
        case ThemeStyleSepia:
            backgroundColor = UIColor(red: 0.96, green: 0.90, blue: 0.83, alpha: 1.0) // #F5E6D3
        case ThemeStyleMedium:
            backgroundColor = UIColor(red: 0.24, green: 0.24, blue: 0.24, alpha: 1.0) // #3D3D3D
        case ThemeStyleDark:
            backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0) // #1A1A1A
        default:
            backgroundColor = UIColor(red: 0.92, green: 0.93, blue: 0.90, alpha: 1.0) // #EAECE6
        }
        view.backgroundColor = backgroundColor
    }

    private func enableLargeDetent() {
        guard let sheet = navigationController?.sheetPresentationController else { return }
        // Add large detent option but don't auto-expand - let user expand manually
        sheet.detents = [.medium(), .large()]
        // Also update largestUndimmedDetentIdentifier to allow the large size
        sheet.largestUndimmedDetentIdentifier = .large
        // Enable scroll-to-expand when answer is visible
        sheet.prefersScrollingExpandsWhenScrolledToEdge = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Ensure WebSocket is connected
        ensureSocketConnected()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Cancel any ongoing request
        viewModel?.cancelRequest()
    }

    private func ensureSocketConnected() {
        let socket = NewsBlurSocketClient.shared

        guard !socket.connected else { return }

        // Get username and feeds from app delegate
        guard let username = appDelegate.activeUsername as String? else { return }

        // Get feed IDs
        var feeds: [String] = []
        if let feedsDict = appDelegate.dictFeeds as? [String: Any] {
            feeds = feedsDict.keys.map { String($0) }
        }

        socket.connect(username: username, feeds: feeds)
    }
}
