// MacReaderChrome.swift keeps native window materials separate from the opaque reading surface.
import UIKit

#if targetEnvironment(macCatalyst)
enum MacReaderChrome {
    static let didFinishRestoringWindows = Notification.Name("NewsBlurMacDidFinishRestoringWindows")

    private static let nativeChrome: NSObject? = {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("MacWindowChrome.bundle"),
              let bundle = Bundle(url: url),
              let type = bundle.principalClass as? NSObject.Type else {
            NSLog("MacReaderChrome.swift could not load MacWindowChrome.bundle")
            return nil
        }
        return type.init()
    }()

    static func prepareDefaults() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["split_behavior": "tile"])
        guard !defaults.bool(forKey: "mac_three_pane_default_applied") else { return }
        // MacReaderChrome.swift upgrades the previous automatic default once, retaining explicit two- and one-pane choices.
        if defaults.string(forKey: "split_behavior") == "auto" {
            defaults.set("tile", forKey: "split_behavior")
        }
        defaults.set(true, forKey: "mac_three_pane_default_applied")
    }

    static func usableDisplayFrame(for frame: CGRect) -> CGRect? {
        let result = nativeChrome?.perform(NSSelectorFromString("usableDisplayFrameForSystemFrame:"), with: NSValue(cgRect: frame))
        return (result?.takeUnretainedValue() as? NSValue)?.cgRectValue
    }

    static func updateTheme() {
        let manager = ThemeManager.shared!
        nativeChrome?.perform(NSSelectorFromString("updateAppearance:"), with: [
            "dark": manager.isDarkTheme,
            "warm": manager.effectiveTheme == "sepia"
        ] as NSDictionary)
    }

    static func clearBackground(of view: UIView?) {
        view?.backgroundColor = .clear
        view?.isOpaque = false
    }
}

@objc(MacSidebarLayout)
final class MacSidebarLayout: NSObject {
    @objc(contentRectForView:bounds:)
    static func contentRect(for referenceView: UIView, bounds: CGRect) -> CGRect {
        let outerMargin: CGFloat = 10
        let maximumInset = min(outerMargin, max(0, bounds.width) / 2)
        var left = maximumInset
        var right = maximumInset
        var ancestor = referenceView.superview
        while let view = ancestor {
            if let table = view as? UITableView {
                // MacReaderChrome.swift counts native row/header insets toward the total margin, including ancestor containers.
                let frame = referenceView.convert(referenceView.bounds, to: table)
                left = min(maximumInset, max(0, outerMargin - (frame.minX - table.bounds.minX)))
                right = min(maximumInset, max(0, outerMargin - (table.bounds.maxX - frame.maxX)))
                break
            }
            ancestor = view.superview
        }
        return bounds.inset(by: UIEdgeInsets(top: 0, left: left, bottom: 0, right: right))
    }
}

final class MacReaderContainerViewController: UIViewController {
    let readerNavigationController: UINavigationController

    init(reader: UINavigationController) {
        readerNavigationController = reader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("MacReaderContainerViewController is created by SplitViewController.swift")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        MacReaderChrome.clearBackground(of: view)
        addChild(readerNavigationController)
        let reader = readerNavigationController.view!
        reader.translatesAutoresizingMaskIntoConstraints = false
        reader.layer.cornerRadius = 12
        reader.layer.cornerCurve = .continuous
        reader.layer.borderWidth = 1 / traitCollection.displayScale
        reader.clipsToBounds = true
        view.addSubview(reader)
        // MacReaderChrome.swift uses the safe area because Catalyst extends the secondary column underneath its sidebar.
        NSLayoutConstraint.activate([
            reader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            reader.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            reader.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            reader.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
        readerNavigationController.didMove(toParent: self)
        updateTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // MacReaderChrome.swift removes the navigation background UIKit supplies around a split-column child.
        navigationController?.setNavigationBarHidden(true, animated: false)
        MacReaderChrome.clearBackground(of: navigationController?.view)
    }

    func updateTheme() {
        guard isViewLoaded else { return }
        readerNavigationController.view.layer.borderColor = ThemeManager.color(fromRGB: [
            0xC9CCC5, 0xD4C8B8, 0x4A4A4A, 0x383838
        ]).cgColor
    }
}
#endif
