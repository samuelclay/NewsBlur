//
//  AskAIViewController.swift
//  NewsBlur
//
//  Created by Claude on 2024-12-06.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
@objc class AskAIViewController: BaseViewController {
    private var story: [String: Any]
    private var hostingController: UIHostingController<AskAIView>?
    private var viewModel: AskAIViewModel?

    @objc init(story: [String: Any]) {
        self.story = story
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create view model
        let viewModel = AskAIViewModel(story: story)
        self.viewModel = viewModel

        // Create SwiftUI view
        let askAIView = AskAIView(viewModel: viewModel) { [weak self] in
            self?.dismiss(animated: true)
        }

        // Create hosting controller
        let hostingController = UIHostingController(rootView: askAIView)
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

        // Configure navigation bar
        navigationItem.title = "Ask AI"
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
