import UIKit

/// CompactPhoneNavigationController.swift provides a native, standalone landscape phone header.
@objc(CompactPhoneNavigationController)
final class CompactPhoneNavigationController: UINavigationController, UINavigationBarDelegate, UIGestureRecognizerDelegate {
    let compactNavigationBar = UINavigationBar()
    private var compactTopConstraint: NSLayoutConstraint?
    private weak var insetController: UIViewController?
    private var originalTopInset: CGFloat = 0
    private weak var originalPopDelegate: UIGestureRecognizerDelegate?
    private var compactHeaderActive = false
    private var requestedNavigationBarHidden = false
    private var mirroredItem: UINavigationItem?
    private var mirroredIdentity: [ObjectIdentifier] = []
    private var mirroredButtonState: [Bool] = []
    private var mirroredTitle: String?
    private var mirroredBackTitle: String?
    private var isUpdatingHeader = false

    private var usesCompactHeader: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && traitCollection.verticalSizeClass == .compact &&
            (topViewController is FeedsObjCViewController || topViewController is FeedDetailObjCViewController)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        compactNavigationBar.translatesAutoresizingMaskIntoConstraints = false
        compactNavigationBar.delegate = self
        compactNavigationBar.isHidden = true
        compactNavigationBar.accessibilityIdentifier = "compact-phone-navigation-bar"
        view.addSubview(compactNavigationBar)
        let top = compactNavigationBar.topAnchor.constraint(equalTo: view.topAnchor)
        compactTopConstraint = top
        NSLayoutConstraint.activate([
            top,
            compactNavigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            compactNavigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            compactNavigationBar.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCompactHeader()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateCompactHeader()
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.updateCompactHeader()
        })
    }

    override func setNavigationBarHidden(_ hidden: Bool, animated: Bool) {
        requestedNavigationBarHidden = hidden
        // CompactPhoneNavigationController.swift lets the reader keep its own toolbar and hidden native bar.
        if isViewLoaded && usesCompactHeader {
            super.setNavigationBarHidden(true, animated: false)
            updateCompactHeader()
        } else {
            super.setNavigationBarHidden(hidden, animated: animated)
        }
    }

    private func updateCompactHeader() {
        guard !isUpdatingHeader else { return }
        isUpdatingHeader = true
        defer { isUpdatingHeader = false }

        guard usesCompactHeader, let controller = topViewController else {
            compactNavigationBar.isHidden = true
            restoreContentInset()
            restorePopDelegate()
            if compactHeaderActive {
                compactHeaderActive = false
                compactNavigationBar.setItems(nil, animated: false)
                if let item = mirroredItem {
                    // CompactPhoneNavigationController.swift hands custom views back to the managed bar.
                    let titleView = item.titleView
                    item.titleView = nil
                    item.titleView = titleView
                    item.setLeftBarButtonItems(item.leftBarButtonItems, animated: false)
                    item.setRightBarButtonItems(item.rightBarButtonItems, animated: false)
                }
                mirroredItem = nil
                mirroredIdentity = []
                super.setNavigationBarHidden(requestedNavigationBarHidden, animated: false)
                navigationBar.setNeedsLayout()
            }
            return
        }

        compactHeaderActive = true
        super.setNavigationBarHidden(true, animated: false)
        compactTopConstraint?.constant = view.window?.safeAreaInsets.top ?? 0
        if insetController !== controller {
            restoreContentInset()
            insetController = controller
            originalTopInset = controller.additionalSafeAreaInsets.top
            var inset = controller.additionalSafeAreaInsets
            inset.top = originalTopInset + 44
            controller.additionalSafeAreaInsets = inset
        }
        synchronizeItems(from: controller.navigationItem)
        compactNavigationBar.isHidden = false
        view.bringSubviewToFront(compactNavigationBar)
        if viewControllers.count <= 1 {
            restorePopDelegate()
        } else if let gesture = interactivePopGestureRecognizer, gesture.isEnabled,
           (gesture.delegate as AnyObject?) !== self {
            originalPopDelegate = gesture.delegate
            gesture.delegate = self
        }
    }

    private func restoreContentInset() {
        if let controller = insetController {
            var inset = controller.additionalSafeAreaInsets
            inset.top = originalTopInset
            controller.additionalSafeAreaInsets = inset
        }
        insetController = nil
    }

    private func restorePopDelegate() {
        if let gesture = interactivePopGestureRecognizer, (gesture.delegate as AnyObject?) === self {
            gesture.delegate = originalPopDelegate
        }
        originalPopDelegate = nil
    }

    private func synchronizeItems(from source: UINavigationItem) {
        if topViewController is FeedsObjCViewController, let titleView = source.titleView {
            // CompactPhoneNavigationController.swift sizes the account header from its visible bar,
            // since the hidden managed bar can retain the previous orientation's width.
            var bounds = titleView.bounds
            let leadingInset = max(view.safeAreaInsets.left, compactNavigationBar.layoutMargins.left)
            let trailingInset = max(view.safeAreaInsets.right, compactNavigationBar.layoutMargins.right)
            bounds.size.width = max(0, view.bounds.width - leadingInset - trailingInset)
            bounds.size.height = 38
            if titleView.bounds != bounds {
                titleView.bounds = bounds
            }
        }
        let previous = viewControllers.dropLast().last?.navigationItem
        let backTitle = previous?.backBarButtonItem?.title ?? previous?.backButtonTitle ?? previous?.title ?? "Back"
        let buttons = (source.leftBarButtonItems ?? []) + (source.rightBarButtonItems ?? [])
        let objects: [AnyObject] = [source.titleView, navigationBar.standardAppearance].compactMap { $0 } +
            buttons
        let identity = objects.map(ObjectIdentifier.init)
        let buttonState = buttons.flatMap { [$0.isEnabled, $0.isHidden] } +
            [source.hidesBackButton, source.leftItemsSupplementBackButton]
        guard mirroredItem !== source || identity != mirroredIdentity || buttonState != mirroredButtonState ||
                source.title != mirroredTitle || backTitle != mirroredBackTitle else {
            return
        }
        mirroredItem = source
        mirroredIdentity = identity
        mirroredButtonState = buttonState
        mirroredTitle = source.title
        mirroredBackTitle = backTitle

        compactNavigationBar.standardAppearance = navigationBar.standardAppearance
        compactNavigationBar.compactAppearance = navigationBar.compactAppearance
        compactNavigationBar.scrollEdgeAppearance = navigationBar.scrollEdgeAppearance
        compactNavigationBar.compactScrollEdgeAppearance = navigationBar.compactScrollEdgeAppearance
        compactNavigationBar.tintColor = navigationBar.tintColor
        compactNavigationBar.barStyle = navigationBar.barStyle
        compactNavigationBar.isTranslucent = navigationBar.isTranslucent

        let item = UINavigationItem(title: source.title ?? "")
        if let titleView = source.titleView {
            // CompactPhoneNavigationController.swift keeps the account avatar and counts inside the 44pt header.
            var bounds = titleView.bounds
            bounds.size.height = min(bounds.height, 38)
            titleView.bounds = bounds
            item.titleView = titleView
        }
        item.leftBarButtonItems = source.leftBarButtonItems?.map(copyButton)
        item.rightBarButtonItems = source.rightBarButtonItems?.map(copyButton)
        item.hidesBackButton = source.hidesBackButton
        item.leftItemsSupplementBackButton = source.leftItemsSupplementBackButton
        let items: [UINavigationItem]
        if viewControllers.count > 1 && !source.hidesBackButton {
            let backItem = UINavigationItem(title: backTitle)
            backItem.backButtonDisplayMode = previous?.backButtonDisplayMode ?? .default
            items = [backItem, item]
        } else {
            items = [item]
        }
        compactNavigationBar.setItems(items, animated: false)
    }

    private func copyButton(_ source: UIBarButtonItem) -> UIBarButtonItem {
        let button: UIBarButtonItem
        if let customView = source.customView {
            button = UIBarButtonItem(customView: customView)
        } else if let image = source.image {
            button = UIBarButtonItem(image: image, style: source.style, target: source.target, action: source.action)
        } else {
            button = UIBarButtonItem(title: source.title, style: source.style, target: source.target, action: source.action)
        }
        button.isEnabled = source.isEnabled
        button.isHidden = source.isHidden
        button.tintColor = source.tintColor
        button.menu = source.menu
        button.accessibilityLabel = source.accessibilityLabel
        button.accessibilityIdentifier = source.accessibilityIdentifier
        return button
    }

    func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
        guard navigationBar === compactNavigationBar else { return true }
        popViewController(animated: true)
        return false
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard compactHeaderActive && gestureRecognizer === interactivePopGestureRecognizer else {
            return originalPopDelegate?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
        }
        return viewControllers.count > 1 && transitionCoordinator == nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        originalPopDelegate?.gestureRecognizer?(gestureRecognizer, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer) ?? false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        originalPopDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: touch) ?? true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
        originalPopDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: press) ?? true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        originalPopDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: event) ?? true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        originalPopDelegate?.gestureRecognizer?(gestureRecognizer, shouldRequireFailureOf: otherGestureRecognizer) ?? false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        originalPopDelegate?.gestureRecognizer?(gestureRecognizer, shouldBeRequiredToFailBy: otherGestureRecognizer) ?? false
    }
}
