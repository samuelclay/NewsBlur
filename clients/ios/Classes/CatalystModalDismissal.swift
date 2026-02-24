// CatalystModalDismissal.swift
// NewsBlur
//
// Adds escape key dismissal and tap-on-overlay dismissal for
// modal dialogs on Mac Catalyst (Organize Sites, Preferences,
// Mute Sites, Widget Sites, etc.).

import UIKit
import ObjectiveC.runtime

@objcMembers
final class CatalystModalDismissal: NSObject {
    static func install() {
        #if targetEnvironment(macCatalyst)
        swizzlePresentMethod()
        swizzleDismissMethod()
        #endif
    }

    private static func swizzlePresentMethod() {
        let original = #selector(UIViewController.present(_:animated:completion:))
        let swizzled = #selector(UIViewController.nb_catalystPresent(_:animated:completion:))
        guard let om = class_getInstanceMethod(UIViewController.self, original),
              let sm = class_getInstanceMethod(UIViewController.self, swizzled) else { return }
        method_exchangeImplementations(om, sm)
    }

    private static func swizzleDismissMethod() {
        let original = #selector(UIViewController.dismiss(animated:completion:))
        let swizzled = #selector(UIViewController.nb_catalystDismiss(animated:completion:))
        guard let om = class_getInstanceMethod(UIViewController.self, original),
              let sm = class_getInstanceMethod(UIViewController.self, swizzled) else { return }
        method_exchangeImplementations(om, sm)
    }
}

// MARK: - Associated object keys

private struct CatalystDismissKeys {
    static var dimmingView: UInt8 = 0
}

// MARK: - UIViewController swizzled methods

private extension UIViewController {

    // MARK: Present

    @objc func nb_catalystPresent(_ vc: UIViewController, animated: Bool, completion: (() -> Void)?) {
        let shouldAddDismissal = nb_shouldAddCatalystDismissal(for: vc)

        if shouldAddDismissal {
            nb_addEscapeKeyCommands(to: vc)
        }

        // Call the original present (method is swizzled, so this calls the real one)
        nb_catalystPresent(vc, animated: animated, completion: completion)

        if shouldAddDismissal {
            // On the next run loop the container view and transition coordinator exist
            DispatchQueue.main.async { [weak self, weak vc] in
                guard let vc = vc else { return }
                self?.nb_addDimmingOverlay(for: vc, animated: animated)
            }
        }
    }

    // MARK: Dismiss

    @objc func nb_catalystDismiss(animated: Bool, completion: (() -> Void)?) {
        // Find the VC being dismissed: if self has a presentedViewController, that's being
        // dismissed; otherwise self is the presented VC being dismissed.
        let target = presentedViewController ?? self

        if let dimming = objc_getAssociatedObject(target, &CatalystDismissKeys.dimmingView) as? UIView {
            let duration: TimeInterval = animated ? 0.25 : 0
            UIView.animate(withDuration: duration) {
                dimming.alpha = 0
            }
        }

        nb_catalystDismiss(animated: animated, completion: completion)
    }

    // MARK: Filter

    func nb_shouldAddCatalystDismissal(for presented: UIViewController) -> Bool {
        if presented is UIAlertController {
            return false
        }

        let style = presented.modalPresentationStyle
        switch style {
        case .fullScreen, .overFullScreen, .popover, .overCurrentContext, .currentContext:
            return false
        case .formSheet, .pageSheet, .automatic:
            return true
        default:
            return false
        }
    }

    // MARK: Dimming overlay

    func nb_addDimmingOverlay(for presented: UIViewController, animated: Bool) {
        guard let containerView = presented.presentationController?.containerView else { return }

        // Don't add twice
        if objc_getAssociatedObject(presented, &CatalystDismissKeys.dimmingView) != nil { return }

        let dimming = UIView()
        dimming.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dimming.frame = containerView.bounds
        dimming.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimming.alpha = 0
        containerView.insertSubview(dimming, at: 0)

        let tap = UITapGestureRecognizer(target: presented, action: #selector(nb_dismissFromOverlayTap))
        dimming.addGestureRecognizer(tap)

        objc_setAssociatedObject(presented, &CatalystDismissKeys.dimmingView, dimming, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Animate alongside the presentation transition if the coordinator is still active
        if let coordinator = presented.transitionCoordinator, animated {
            coordinator.animate(alongsideTransition: { _ in
                dimming.alpha = 1
            })
        } else {
            UIView.animate(withDuration: animated ? 0.25 : 0) {
                dimming.alpha = 1
            }
        }
    }

    // MARK: Escape key commands

    func nb_addEscapeKeyCommands(to presented: UIViewController) {
        var targets: [UIViewController] = [presented]
        if let nav = presented as? UINavigationController, let top = nav.topViewController {
            targets.append(top)
        }

        for target in targets {
            let existing = target.keyCommands ?? []
            let hasEscape = existing.contains { $0.input == UIKeyCommand.inputEscape && $0.modifierFlags == [] }
            let hasCmdDot = existing.contains { $0.input == "." && $0.modifierFlags.contains(.command) }

            if !hasEscape {
                let cmd = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(nb_dismissFromOverlayTap))
                cmd.discoverabilityTitle = "Close"
                if #available(iOS 15.0, *) {
                    cmd.wantsPriorityOverSystemBehavior = true
                }
                target.addKeyCommand(cmd)
            }

            if !hasCmdDot {
                let cmd = UIKeyCommand(input: ".", modifierFlags: [.command], action: #selector(nb_dismissFromOverlayTap))
                cmd.discoverabilityTitle = "Close"
                if #available(iOS 15.0, *) {
                    cmd.wantsPriorityOverSystemBehavior = true
                }
                target.addKeyCommand(cmd)
            }
        }
    }

    // MARK: Actions

    @objc func nb_dismissFromOverlayTap() {
        dismiss(animated: true)
    }
}
