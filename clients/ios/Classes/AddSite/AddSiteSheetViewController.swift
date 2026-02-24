//
//  AddSiteSheetViewController.swift
//  NewsBlur
//
//  Created by Claude on 2026-02-23.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
@objc class AddSiteSheetViewController: BaseViewController {
    private static var sharedViewModel: AddSiteViewModel?

    private var hostingController: UIHostingController<AddSiteView>?
    private var viewModel: AddSiteViewModel?
    private weak var sheetController: UISheetPresentationController?

    @objc var initialFeedAddress: String?
    @objc var onDismiss: (() -> Void)?
    @objc var onSuccess: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        updateBackgroundColor()

        let viewModel: AddSiteViewModel
        if let existing = Self.sharedViewModel {
            viewModel = existing
            // Only override search text if an explicit address was passed
            if let address = initialFeedAddress, !address.isEmpty {
                viewModel.searchText = address
                viewModel.autocompleteResults = []
            }
            // Clear transient state from previous presentation
            viewModel.isAdding = false
            viewModel.errorMessage = nil
            viewModel.addedSuccess = false
        } else {
            viewModel = AddSiteViewModel()
            if let address = initialFeedAddress, !address.isEmpty {
                viewModel.searchText = address
            }
            Self.sharedViewModel = viewModel
        }
        self.viewModel = viewModel

        viewModel.onResultsAppeared = { [weak self] in
            self?.expandSheet()
        }
        viewModel.onResultsCleared = { [weak self] in
            self?.shrinkSheet()
        }

        let addSiteView = AddSiteView(
            viewModel: viewModel,
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            }
        )

        let hostingController = UIHostingController(rootView: addSiteView)
        hostingController.view.backgroundColor = .clear
        self.hostingController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        observeSuccess()
    }

    @objc func setSheetController(_ sheet: UISheetPresentationController?) {
        self.sheetController = sheet
    }

    private func expandSheet() {
        guard let sheet = sheetController ?? navigationController?.sheetPresentationController else { return }
        sheet.animateChanges {
            sheet.selectedDetentIdentifier = .medium
        }
    }

    private func shrinkSheet() {
        guard let sheet = sheetController ?? navigationController?.sheetPresentationController else { return }
        if #available(iOS 16.0, *) {
            sheet.animateChanges {
                sheet.selectedDetentIdentifier = UISheetPresentationController.Detent.Identifier("addSiteSmall")
            }
        }
    }

    private func observeSuccess() {
        guard let viewModel = viewModel else { return }

        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self, weak viewModel] timer in
            guard let self = self, let viewModel = viewModel else {
                timer.invalidate()
                return
            }
            if viewModel.addedSuccess {
                timer.invalidate()
                Self.sharedViewModel = nil
                self.dismiss(animated: true) {
                    self.onSuccess?()
                    self.appDelegate?.reloadFeedsView(false)
                }
            }
        }
    }

    private func updateBackgroundColor() {
        let theme = ThemeManager.shared?.effectiveTheme ?? ThemeStyleLight
        let backgroundColor: UIColor
        switch theme {
        case ThemeStyleSepia:
            backgroundColor = UIColor(red: 0.96, green: 0.90, blue: 0.83, alpha: 1.0)
        case ThemeStyleMedium:
            backgroundColor = UIColor(red: 0.24, green: 0.24, blue: 0.24, alpha: 1.0)
        case ThemeStyleDark:
            backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        default:
            backgroundColor = UIColor(red: 0.92, green: 0.93, blue: 0.90, alpha: 1.0)
        }
        view.backgroundColor = backgroundColor
    }
}
