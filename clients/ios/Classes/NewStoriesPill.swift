//
//  NewStoriesPill.swift
//  NewsBlur
//
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import UIKit

/// The "3 new stories" capsule that floats over the story list when RealtimeUpdates.swift has fetched stories that
/// arrived over the socket. It sits at the top of a newest-first list and at the bottom of an oldest-first one.
/// Tapping it puts the stories into the list.
@objcMembers final class NewStoriesPill: UIControl {
    private let capsuleView = UIView()
    private let arrowImageView = UIImageView()
    private let titleLabel = UILabel()
    private(set) var count = 0
    private(set) var atBottom = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "new-stories-pill"

        capsuleView.translatesAutoresizingMaskIntoConstraints = false
        capsuleView.isUserInteractionEnabled = false
        capsuleView.layer.cornerRadius = 17
        capsuleView.layer.cornerCurve = .continuous
        capsuleView.layer.shadowOffset = CGSize(width: 0, height: 3)
        capsuleView.layer.shadowRadius = 10
        capsuleView.layer.shadowOpacity = 0.22
        addSubview(capsuleView)

        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        capsuleView.addSubview(arrowImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "WhitneySSm-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = false
        titleLabel.numberOfLines = 1
        capsuleView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            capsuleView.topAnchor.constraint(equalTo: topAnchor),
            capsuleView.leadingAnchor.constraint(equalTo: leadingAnchor),
            capsuleView.trailingAnchor.constraint(equalTo: trailingAnchor),
            capsuleView.bottomAnchor.constraint(equalTo: bottomAnchor),
            capsuleView.heightAnchor.constraint(equalToConstant: 34),

            arrowImageView.leadingAnchor.constraint(equalTo: capsuleView.leadingAnchor, constant: 13),
            arrowImageView.centerYAnchor.constraint(equalTo: capsuleView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 13),

            titleLabel.leadingAnchor.constraint(equalTo: arrowImageView.trailingAnchor, constant: 7),
            titleLabel.trailingAnchor.constraint(equalTo: capsuleView.trailingAnchor, constant: -15),
            titleLabel.centerYAnchor.constraint(equalTo: capsuleView.centerYAnchor)
        ])

        updateTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(count: Int, atBottom: Bool) {
        self.count = count
        self.atBottom = atBottom
        let title = NBLocalization.plural("%@ new stories", groupedCount: count)
        titleLabel.text = title
        accessibilityLabel = title
        arrowImageView.image = UIImage(systemName: atBottom ? "arrow.down" : "arrow.up")?.withRenderingMode(.alwaysTemplate)
    }

    func updateTheme() {
        capsuleView.backgroundColor = ThemeManager.color(fromRGB: [0x477DBF, 0x8A6A33, 0x4F7FBA, 0x3F6EA8])
        capsuleView.layer.shadowColor = ThemeManager.shared.isDarkTheme
            ? UIColor.black.cgColor
            : ThemeManager.color(fromRGB: [0x3B4A5C]).cgColor
        titleLabel.textColor = .white
        arrowImageView.tintColor = .white
    }

    override var isHighlighted: Bool {
        didSet { capsuleView.alpha = isHighlighted ? 0.8 : 1 }
    }

    /// VoiceOver, and the Mac's accessibility press, activate the pill without touching it. A custom UIControl
    /// ignores that by default, so NewStoriesPill.swift treats it as a tap.
    override func accessibilityActivate() -> Bool {
        sendActions(for: .touchUpInside)
        return true
    }
}

extension FeedDetailViewController {
    private var newStoriesPill: NewStoriesPill? {
        view.subviews.first { $0 is NewStoriesPill } as? NewStoriesPill
    }

    /// Show or update the pill. RealtimeUpdates.swift passes the number of waiting stories the list would show.
    @objc func showNewStoriesPill(count: Int, atBottom: Bool) {
        guard isViewLoaded else { return }
        if let pill = newStoriesPill, pill.atBottom != atBottom { pill.removeFromSuperview() }
        let pill = newStoriesPill ?? makeNewStoriesPill(atBottom: atBottom)
        let appearing = pill.isHidden || pill.alpha < 1
        pill.configure(count: count, atBottom: atBottom)
        view.bringSubviewToFront(pill)
        guard appearing else { return }
        pill.isHidden = false
        let offset: CGFloat = atBottom ? 12 : -12
        if UIAccessibility.isReduceMotionEnabled {
            pill.transform = .identity
            UIView.animate(withDuration: 0.2) { pill.alpha = 1 }
        } else {
            pill.transform = CGAffineTransform(translationX: 0, y: offset)
            UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                pill.alpha = 1
                pill.transform = .identity
            }
        }
    }

    @objc func hideNewStoriesPill() {
        guard isViewLoaded, let pill = newStoriesPill, !pill.isHidden else { return }
        UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState]) {
            pill.alpha = 0
        } completion: { finished in
            if finished && pill.alpha == 0 { pill.isHidden = true }
        }
    }

    @objc func updateNewStoriesPillTheme() {
        newStoriesPill?.updateTheme()
    }

    func bringNewStoriesPillToFront() {
        if let pill = newStoriesPill { view.bringSubviewToFront(pill) }
    }

    private func makeNewStoriesPill(atBottom: Bool) -> NewStoriesPill {
        let pill = NewStoriesPill(frame: .zero)
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.alpha = 0
        pill.isHidden = true
        pill.addTarget(self, action: #selector(didTapNewStoriesPill), for: .touchUpInside)
        view.addSubview(pill)
        var constraints = [pill.centerXAnchor.constraint(equalTo: view.centerXAnchor)]
        if atBottom {
            constraints.append(pill.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14))
        } else if let headerBar = storyTitlesHeaderBar {
            constraints.append(pill.topAnchor.constraint(equalTo: headerBar.contentTopAnchor, constant: 10))
        } else {
            constraints.append(pill.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10))
        }
        NSLayoutConstraint.activate(constraints)
        return pill
    }

    @objc private func didTapNewStoriesPill() {
        hideNewStoriesPill()
        RealtimeUpdates.shared.insertBufferedStories()
    }

    /// The stories that arrived join the list by date, so one published a while before it was fetched can land
    /// below others. Show the first of them: the list's top when it's one of the first few rows, otherwise that row.
    @objc func scrollToRealtimeStory(hash: String?, atBottom: Bool) {
        guard let collection = storiesCollection else { return }
        let location = hash.map { collection.location(ofStoryId: $0) } ?? -1
        let staysAtTop = !atBottom && location <= Self.newStoryRowsShownFromTop
        if isLegacyTable {
            guard let table = storyTitlesTable else { return }
            table.layoutIfNeeded()
            if staysAtTop || location < 0 {
                table.setContentOffset(CGPoint(x: 0, y: -table.adjustedContentInset.top), animated: true)
            } else if let path = indexPath(forStoryLocation: location) {
                table.scrollToRow(at: path, at: atBottom ? .middle : .top, animated: true)
            }
        } else if let scrollView = gridScrollView {
            // The SwiftUI grid gets no scroll hooks of its own: an onChange added to FeedDetailGridView.swift crashed
            // Mac Catalyst when the reader opened a story. A newest-first list shows its new stories at the top; an
            // oldest-first one gains them at the bottom.
            scrollView.layoutIfNeeded()
            let inset = scrollView.adjustedContentInset
            let bottom = max(-inset.top, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom)
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: atBottom ? bottom : -inset.top),
                                        animated: true)
        }
    }

    /// A new story this close to the top of a newest-first list is in view once the list scrolls to its top.
    private static var newStoryRowsShownFromTop: Int { 2 }
}
