//
//  SyncNotifierView.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2025-01-12.
//  Copyright (c) 2025 NewsBlur. All rights reserved.
//

import UIKit

@objc enum SyncNotifierStyle: Int {
    case offline = 1
    case loading = 2
    case syncing = 3
    case syncingProgress = 4
    case done = 5
}

@objcMembers
class SyncNotifierView: UIView {

    // MARK: - Properties

    private let blurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "WhitneySSm-Book", size: 13) ?? .systemFont(ofSize: 13)
        label.textColor = .white
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: -0.5)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 1
        label.layer.masksToBounds = false
        return label
    }()

    private let accessoryContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()

    private let progressBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 0xD0/255.0, green: 0x50/255.0, blue: 0x46/255.0, alpha: 0.8)
        view.isHidden = true
        return view
    }()

    private let offlineTintView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 0.4, green: 0.15, blue: 0.1, alpha: 0.4)
        view.isHidden = true
        return view
    }()

    private let passiveTintView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // Lighter overlay to reduce intensity for passive states (downloading, done)
        view.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        view.isHidden = true
        return view
    }()

    private var progressWidthConstraint: NSLayoutConstraint?
    private var isShowing = false
    private var pendingHide = false
    private var pendingShow = false
    private var pendingShowDuration: TimeInterval = 0
    private var hideWorkItem: DispatchWorkItem?

    var title: String = "" {
        didSet {
            titleLabel.text = title
        }
    }

    var style: SyncNotifierStyle = .loading {
        didSet {
            updateStyle()
        }
    }

    // MARK: - Constants

    private let pillHeight: CGFloat = 28
    private let horizontalPadding: CGFloat = 10
    private let iconSize: CGFloat = 16
    private let animationDuration: TimeInterval = 0.3

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    @objc convenience init(title: String) {
        self.init(frame: .zero)
        self.title = title
        self.titleLabel.text = title
    }

    // MARK: - Setup

    private func setupView() {
        // Use frame-based layout for outer view positioning
        translatesAutoresizingMaskIntoConstraints = true
        clipsToBounds = true
        layer.cornerRadius = pillHeight / 2

        // Set initial frame (will be repositioned by parent)
        frame = CGRect(x: 0, y: 0, width: 150, height: pillHeight)

        // Add blur background
        addSubview(blurView)

        // Add tint overlays (hidden by default)
        blurView.contentView.addSubview(offlineTintView)
        blurView.contentView.addSubview(passiveTintView)

        // Add content view on top of blur
        blurView.contentView.addSubview(contentView)

        // Add progress bar at bottom
        addSubview(progressBar)

        // Add label and accessory container
        contentView.addSubview(titleLabel)
        contentView.addSubview(accessoryContainer)

        // Add spinner and icon to accessory container
        accessoryContainer.addSubview(activityIndicator)
        accessoryContainer.addSubview(iconImageView)

        // Add subtle border
        layer.borderWidth = 0.5
        layer.borderColor = UIColor(white: 1.0, alpha: 0.2).cgColor

        setupConstraints()

        // Start hidden and off-screen
        alpha = 0
        transform = CGAffineTransform(translationX: 100, y: 0)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Blur view fills the entire view
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Offline tint view fills blur content
            offlineTintView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            offlineTintView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            offlineTintView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            offlineTintView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),

            // Passive tint view fills blur content (for lighter passive states)
            passiveTintView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            passiveTintView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            passiveTintView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            passiveTintView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),

            // Content view fills blur content view
            contentView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: horizontalPadding),
            contentView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -horizontalPadding),
            contentView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),

            // Progress bar at bottom
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 2),

            // Title label - left side, vertically centered
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: accessoryContainer.leadingAnchor, constant: -6),

            // Accessory container - right side
            accessoryContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            accessoryContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            accessoryContainer.widthAnchor.constraint(equalToConstant: iconSize),
            accessoryContainer.heightAnchor.constraint(equalToConstant: iconSize),

            // Activity indicator centered in accessory container
            activityIndicator.centerXAnchor.constraint(equalTo: accessoryContainer.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: accessoryContainer.centerYAnchor),

            // Icon centered in accessory container
            iconImageView.centerXAnchor.constraint(equalTo: accessoryContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: accessoryContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: iconSize),
            iconImageView.heightAnchor.constraint(equalToConstant: iconSize),
        ])

        // Initial progress bar width
        progressWidthConstraint = progressBar.widthAnchor.constraint(equalToConstant: 0)
        progressWidthConstraint?.isActive = true
    }

    // MARK: - Sizing

    override var intrinsicContentSize: CGSize {
        let labelWidth = titleLabel.intrinsicContentSize.width
        let totalWidth = horizontalPadding + labelWidth + 6 + iconSize + horizontalPadding
        return CGSize(width: totalWidth, height: pillHeight)
    }

    override func sizeToFit() {
        let size = intrinsicContentSize
        frame.size = size
    }

    @objc func updateFrameInSuperview() {
        sizeToFit()
        guard let superview = superview else { return }

        // Position at right side of screen, vertically centered
        // Convert to superview's coordinate system since we're inside titleView
        let screenWidth = UIScreen.main.bounds.width
        let targetX = screenWidth - frame.width - 16

        // Get superview's position in window coordinates
        if let window = superview.window {
            let superviewFrameInWindow = superview.convert(superview.bounds, to: window)
            let x = targetX - superviewFrameInWindow.origin.x
            let y = (superview.bounds.height - frame.height) / 2
            frame.origin = CGPoint(x: x, y: y)
        } else {
            // Fallback if window not available yet
            let y = (superview.bounds.height - frame.height) / 2
            frame.origin = CGPoint(x: superview.bounds.width - frame.width, y: y)
        }
    }

    // MARK: - Style Updates

    private func updateStyle() {
        // Reset state
        activityIndicator.stopAnimating()
        iconImageView.isHidden = true
        progressBar.isHidden = true
        offlineTintView.isHidden = true
        passiveTintView.isHidden = true

        switch style {
        case .loading, .syncing:
            // Active states - full intensity (no tint overlay)
            activityIndicator.startAnimating()
            iconImageView.isHidden = true

        case .syncingProgress:
            // Passive state - lighter appearance (already has progress bar indicator)
            activityIndicator.stopAnimating()
            iconImageView.image = UIImage(named: "g_icn_offline")?.withRenderingMode(.alwaysTemplate)
            iconImageView.isHidden = false
            progressBar.isHidden = false
            passiveTintView.isHidden = false

        case .offline:
            activityIndicator.stopAnimating()
            iconImageView.image = UIImage(named: "g_icn_offline")?.withRenderingMode(.alwaysTemplate)
            iconImageView.isHidden = false
            offlineTintView.isHidden = false

        case .done:
            // Passive state - lighter appearance
            activityIndicator.stopAnimating()
            iconImageView.image = UIImage(named: "checkmark")?.withRenderingMode(.alwaysTemplate)
            iconImageView.isHidden = false
            passiveTintView.isHidden = false
        }
    }

    // MARK: - Progress

    @objc func setProgress(_ progress: CGFloat) {
        progressWidthConstraint?.isActive = false
        progressWidthConstraint = progressBar.widthAnchor.constraint(equalTo: widthAnchor, multiplier: progress)
        progressWidthConstraint?.isActive = true

        UIView.animate(withDuration: 0.5) {
            self.layoutIfNeeded()
        }
    }

    // MARK: - Show/Hide Animation

    @objc func show() {
        showIn(animationDuration)
    }

    @objc func showIn(_ duration: TimeInterval) {
        guard window != nil else {
            pendingHide = false
            pendingShow = true
            pendingShowDuration = duration
            return
        }

        // If already showing, don't animate - just ensure visible
        if isShowing {
            return
        }

        isShowing = true
        pendingHide = false
        pendingShow = false
        isHidden = false

        // Update frame and position before animating
        updateFrameInSuperview()

        // Start off-screen to the right
        transform = CGAffineTransform(translationX: frame.width + 20, y: 0)
        alpha = 0

        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut]
        ) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    @objc func hide() {
        hideIn(animationDuration)
    }

    @objc func hideNow() {
        hideIn(0)
    }

    @objc func hideIn(_ duration: TimeInterval) {
        if pendingShow {
            pendingShow = false
        }
        guard isShowing else { return }

        // If no window yet, mark as pending and it will hide when window is set
        guard window != nil else {
            pendingHide = true
            return
        }

        pendingHide = false

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseIn]
        ) {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: self.frame.width + 20, y: 0)
        } completion: { _ in
            self.isHidden = true
            self.isShowing = false
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            updateFrameInSuperview()
            if pendingShow {
                let duration = pendingShowDuration
                pendingShow = false
                showIn(duration)
                return
            }
        }
        // Execute pending hide when we get a window
        if window != nil && pendingHide {
            hide()
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        updateFrameInSuperview()
    }

    // MARK: - Convenience Methods for ObjC

    @objc func showWithStyle(_ style: SyncNotifierStyle, title: String) {
        // Cancel any pending hide timer when showing new content
        cancelPendingHide()

        let wasShowing = isShowing

        self.style = style
        self.title = title
        setProgress(0)

        if wasShowing {
            // Already visible - just animate the size change
            UIView.animate(withDuration: 0.2) {
                self.updateFrameInSuperview()
            }
        } else {
            // Not visible - animate in
            show()
        }
    }

    @objc func showWithStyle(_ style: SyncNotifierStyle, title: String, progress: CGFloat) {
        // Cancel any pending hide timer when showing new content
        cancelPendingHide()

        let wasShowing = isShowing

        self.style = style
        self.title = title
        setProgress(progress)

        if wasShowing {
            // Already visible - just animate the size change
            UIView.animate(withDuration: 0.2) {
                self.updateFrameInSuperview()
            }
        } else {
            // Not visible - animate in
            show()
        }
    }

    // MARK: - Delayed Hide

    /// Cancels any pending hide timer
    private func cancelPendingHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    /// Hides the notifier after a delay, canceling any previously scheduled hide
    @objc func hideAfter(_ delay: TimeInterval) {
        // Cancel any existing pending hide
        cancelPendingHide()

        // Create new work item for delayed hide
        let workItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

}
