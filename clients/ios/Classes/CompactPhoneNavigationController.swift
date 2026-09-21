import UIKit

/// CompactPhoneNavigationController.swift shares measured Duo title geometry with DetailViewController's expanded navigation.
@MainActor final class VerticalNavigationTitleLayout {
    private weak var navigation: UINavigationController?
    private weak var controller: UIViewController?
    private var originalTopInset: CGFloat = 0
    private var appliedTopInset: CGFloat = 0
    private var titleOffset: CGFloat = 0
    private var originalTitleFrame: CGRect?
    private var appliedTitleFrame: CGRect?

    func update(navigation: UINavigationController?, controller: UIViewController?, enabled: Bool,
                titleContent: UIView? = nil) {
        guard enabled, let navigation, let controller,
              navigation.topViewController === controller,
              !navigation.isNavigationBarHidden,
              let window = navigation.viewIfLoaded?.window,
              let barParent = navigation.navigationBar.superview,
              abs(navigation.view.convert(navigation.view.bounds, to: window).minY - window.bounds.minY) < 1 else {
            restore()
            return
        }
        // CompactPhoneNavigationController.swift inherits Duo's side status area only for its fullscreen titles overlay; its own toolbar remains horizontal.
        let isDuoFullscreenOverlay = (controller as? FeedDetailViewController)?.appDelegate?.detailViewController?.isDuoFullscreenReader == true
        guard Utilities.usesSystemVerticalBar(navigation.traitCollection) ||
                (isDuoFullscreenOverlay && Utilities.usesSystemVerticalBar(window.traitCollection)) else {
            restore()
            return
        }
        if self.controller !== controller || self.navigation !== navigation {
            restore()
            self.navigation = navigation
            self.controller = controller
            originalTopInset = controller.additionalSafeAreaInsets.top
            appliedTopInset = originalTopInset
        }

        // CompactPhoneNavigationController.swift removes the obsolete horizontal status-band offset when status and actions occupy Duo's side rail.
        let bar = navigation.navigationBar
        let protectedTop = window.bounds.minY + window.safeAreaInsets.top
        let titleTop = barParent.convert(CGPoint(x: 0, y: protectedTop), from: window).y
        let redundantOffset = bar.frame.minY - titleTop
        if redundantOffset > 0.5 { titleOffset = redundantOffset }
        if abs(bar.frame.minY - titleTop) > 0.5 {
            var frame = bar.frame
            originalTitleFrame = frame
            frame.origin.y = titleTop
            bar.frame = frame
            appliedTitleFrame = frame
        }

        let titleIsMinimized = titleContent.map { content in
            guard content.window === window, content.isDescendant(of: bar),
                  content.bounds.width > 0, content.bounds.height > 0 else { return false }
            // CompactPhoneNavigationController.swift ignores startup fades; only a title translated above the protected edge has minimized.
            return content.convert(content.bounds, to: window).maxY <= protectedTop + 0.5
        } ?? false
        // CompactPhoneNavigationController.swift observes our own title view: UIKit retains the outer 58pt bar after its title has minimized.
        let titleBottom = titleIsMinimized
            ? controller.view.convert(CGPoint(x: window.bounds.minX, y: protectedTop), from: window).y
            : bar.convert(bar.bounds, to: controller.view).maxY
        let requiredSafeTop = max(0, titleBottom - controller.view.bounds.minY) + originalTopInset
        var inset = controller.additionalSafeAreaInsets
        if titleIsMinimized, titleOffset < 0.5 {
            // CompactPhoneNavigationController.swift handles an owner first appearing minimized, without mistaking an uncommitted full-title inset for a status gap.
            let residual = controller.view.safeAreaInsets.top - requiredSafeTop + originalTopInset - inset.top
            if residual > 0.5, residual < bar.bounds.height - 0.5 {
                titleOffset = residual
            }
        }
        // CompactPhoneNavigationController.swift bounds compensation to the measured gap so repeated safe-area callbacks cannot accumulate it.
        let correctedTop = min(originalTopInset,
                               max(originalTopInset - titleOffset,
                                   inset.top + requiredSafeTop - controller.view.safeAreaInsets.top))
        if abs(inset.top - correctedTop) > 0.5 {
            inset.top = correctedTop
            controller.additionalSafeAreaInsets = inset
        }
        appliedTopInset = inset.top
    }

    func restore() {
        if let controller, abs(controller.additionalSafeAreaInsets.top - appliedTopInset) < 0.5 {
            var inset = controller.additionalSafeAreaInsets
            inset.top = originalTopInset
            controller.additionalSafeAreaInsets = inset
        }
        if let bar = navigation?.navigationBar, let original = originalTitleFrame,
           let applied = appliedTitleFrame, bar.frame == applied {
            bar.frame = original
        }
        controller = nil
        navigation = nil
        titleOffset = 0
        originalTitleFrame = nil
        appliedTitleFrame = nil
    }
}

/// CompactPhoneNavigationController.swift applies the expanded Duo correction after UIKit finishes laying out its managed title bar.
@objc(DetailNavigationController)
final class DetailNavigationController: UINavigationController {
    private let verticalTitleLayout = VerticalNavigationTitleLayout()
    private weak var feedsTitleOwner: DetailViewController?
    private var feedsTitleView: ExpandedFeedsNavigationTitleView?
    private var feedsTitleItem: UIBarButtonItem?
    private let centeredTitlePlaceholder = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    private weak var titleHeaderScrollOwner: DetailViewController?
    private weak var titleHeaderScrollView: UIScrollView?
    private var previousTitleHeaderScrollView: UIScrollView?
    private var restoreTitleHeaderMinimization: (() -> Void)?
    private var isUpdatingTitleHeaderScrolling = false
    private var isTitleHeaderUpdateScheduled = false
    private var isLeavingTitleHeader = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let detail = topViewController as? DetailViewController
        updateFeedsTitle(for: detail)
        verticalTitleLayout.update(navigation: self, controller: detail,
                                   enabled: detail.map { !$0.isPhoneOrCompact && !$0.isDiscoverSitesVisible } ?? false,
                                   titleContent: feedsTitleView)
        scheduleTitleHeaderScrollingUpdate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isLeavingTitleHeader = false
        scheduleTitleHeaderScrollingUpdate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        verticalTitleLayout.restore()
        restoreFeedsTitle()
        isLeavingTitleHeader = true
        scheduleTitleHeaderScrollingUpdate()
    }

    private func scheduleTitleHeaderScrollingUpdate() {
        guard !isUpdatingTitleHeaderScrolling, !isTitleHeaderUpdateScheduled else { return }
        isTitleHeaderUpdateScheduled = true
        // CompactPhoneNavigationController.swift must not make UIKit observe or detach a table from inside its enclosing layout transaction.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isTitleHeaderUpdateScheduled = false
            self.updateTitleHeaderScrolling()
        }
    }

    private func updateTitleHeaderScrolling() {
        guard !isUpdatingTitleHeaderScrolling else { return }
        isUpdatingTitleHeaderScrolling = true
        defer { isUpdatingTitleHeaderScrolling = false }
        // CompactPhoneNavigationController.swift resolves the current owner here so a queued update cannot attach a replaced list or Discover's old table.
        guard #available(iOS 27.0, *), !isLeavingTitleHeader,
              let detail = topViewController as? DetailViewController, detail.isPhone, !detail.isPhoneOrCompact,
              !detail.isDiscoverSitesVisible, !isNavigationBarHidden,
              let table = detail.feedDetailViewController?.storyTitlesTable,
              table.window != nil, table.window === view.window, table.isDescendant(of: detail.view),
              isVisibleTitleHeaderTable(table, in: detail.view) else {
            restoreTitleHeaderScrolling()
            return
        }
        guard isCommittedTitleHeaderTable(table), table.numberOfSections > 0 else { return }
        if let oldTable = titleHeaderScrollView as? UITableView,
           !isCommittedTitleHeaderTable(oldTable) { return }
        if titleHeaderScrollOwner !== detail {
            guard restoreTitleHeaderScrolling() else { return }
            titleHeaderScrollOwner = detail
            previousTitleHeaderScrollView = detail.contentScrollView(for: .top)
            restoreTitleHeaderMinimization = Utilities.beginNavigationBarMinimization(detail.navigationItem)
        }
        if titleHeaderScrollView !== table || detail.contentScrollView(for: .top) !== table {
            // CompactPhoneNavigationController.swift gives the leading header exclusively to its own story list, never the article column.
            titleHeaderScrollView = table
            detail.setContentScrollView(table, for: .top)
        }
    }

    private func isVisibleTitleHeaderTable(_ table: UITableView, in container: UIView) -> Bool {
        guard table.bounds.width > 0, table.bounds.height > 0 else { return false }
        var ancestor: UIView? = table
        while let view = ancestor {
            if view.isHidden || view.alpha < 0.01 { return false }
            if view === container { return true }
            ancestor = view.superview
        }
        return false
    }

    private func isCommittedTitleHeaderTable(_ table: UITableView) -> Bool {
        guard !table.hasUncommittedUpdates else { return false }
        let sectionCount = table.numberOfSections
        let dataSourceSections = table.dataSource.map { $0.numberOfSections?(in: table) ?? 1 } ?? 0
        guard sectionCount == dataSourceSections else { return false }
        var rowCounts: [Int] = []
        for section in 0..<sectionCount {
            let rows = table.numberOfRows(inSection: section)
            guard rows == table.dataSource?.tableView(table, numberOfRowsInSection: section) else { return false }
            rowCounts.append(rows)
        }
        // CompactPhoneNavigationController.swift rejects the startup state where old visible cells survive a reload to zero sections.
        return table.visibleCells.allSatisfy { cell in
            guard let path = table.indexPath(for: cell), path.section < rowCounts.count else { return false }
            return path.row < rowCounts[path.section]
        }
    }

    @discardableResult private func restoreTitleHeaderScrolling() -> Bool {
        if let owner = titleHeaderScrollOwner, owner.contentScrollView(for: .top) === titleHeaderScrollView {
            if let table = titleHeaderScrollView as? UITableView, !isCommittedTitleHeaderTable(table) { return false }
            if let table = previousTitleHeaderScrollView as? UITableView, !isCommittedTitleHeaderTable(table) { return false }
            owner.setContentScrollView(previousTitleHeaderScrollView, for: .top)
        }
        restoreTitleHeaderMinimization?()
        titleHeaderScrollOwner = nil
        titleHeaderScrollView = nil
        previousTitleHeaderScrollView = nil
        restoreTitleHeaderMinimization = nil
        return true
    }

    @objc func updateFeedsTitleAfterSidebarUpdate() {
        guard let detail = feedsTitleOwner, topViewController === detail else { return }
        // CompactPhoneNavigationController.swift keeps its existing leading heading attached when a later child refresh replaces the shared Sidebar/Settings items.
        updateFeedsTitle(for: detail)
    }

    private func updateFeedsTitle(for detail: DetailViewController?) {
        if let detail, detail.isDuoFullscreenReader {
            restoreFeedsTitle()
            // CompactPhoneNavigationController.swift leaves the source heading inside the primary overlay while the article fills secondary.
            detail.navigationItem.titleView = nil
            return
        }
        guard let detail, detail.isPhone, !detail.isPhoneOrCompact,
              !detail.isDiscoverSitesVisible, !isNavigationBarHidden else {
            restoreFeedsTitle()
            return
        }
        let item = detail.navigationItem
        if feedsTitleOwner !== detail || item.titleView !== centeredTitlePlaceholder {
            restoreFeedsTitle()
            let source = item.titleView
            // CompactPhoneNavigationController.swift lets UIKit release its old title before that same view becomes a child of the replacement.
            item.titleView = nil
            let title = ExpandedFeedsNavigationTitleView(sourceTitle: source) { [weak detail] in
                detail?.show(column: .primary, animated: true)
            }
            feedsTitleOwner = detail
            feedsTitleView = title
            let leadingItem = UIBarButtonItem(customView: title)
            Utilities.keepBarButtonInHorizontalBar(leadingItem)
            if #available(iOS 26.0, *) {
                leadingItem.hidesSharedBackground = true
                leadingItem.sharesBackground = false
            }
            feedsTitleItem = leadingItem
            // CompactPhoneNavigationController.swift leaves the shared center empty because this title belongs to the leading story column.
            item.titleView = centeredTitlePlaceholder
        }
        guard let leadingItem = feedsTitleItem else { return }
        let settingsItem = detail.feedDetailViewController?.settingsBarButton
        var otherItems = (item.leftBarButtonItems ?? []).filter { $0 !== leadingItem }
        if let settingsItem, otherItems.contains(where: { $0 === settingsItem }) {
            otherItems.removeAll { $0 === settingsItem }
            otherItems.append(settingsItem)
        }
        let availableWidth = navigationBar.bounds.width - navigationBar.safeAreaInsets.left - navigationBar.safeAreaInsets.right
        // CompactPhoneNavigationController.swift includes UIKit's additional bar margins when the tiled story column occupies the entire horizontal bar.
        let barContentWidth = navigationBar.layoutMarginsGuide.layoutFrame.width
        var columnWidth = min(availableWidth, barContentWidth > 0 ? barContentWidth : availableWidth)
        var columnCenter = navigationBar.safeAreaInsets.left + availableWidth / 2
        if let storiesView = detail.feedDetailViewController?.viewIfLoaded,
           storiesView.window === view.window, !storiesView.isHidden, storiesView.bounds.width > 0 {
            let columnFrame = storiesView.convert(storiesView.bounds, to: navigationBar)
            columnWidth = min(columnWidth, columnFrame.width)
            columnCenter = columnFrame.midX
        }
        // CompactPhoneNavigationController.swift reserves horizontal space for custom title actions while native actions occupy Duo's side rail.
        let horizontalItems = Utilities.usesSystemVerticalBar(traitCollection)
            ? otherItems.filter { $0.customView != nil } : otherItems
        let otherItemsWidth = horizontalItems.reduce(CGFloat.zero) { width, button in
            width + max(44, button.customView?.intrinsicContentSize.width ?? 44) + 8
        }
        feedsTitleView?.update(plainTitle: item.title ?? detail.title, navigationBar: navigationBar,
                               maximumWidth: max(44, columnWidth - 32 - otherItemsWidth), columnCenter: columnCenter)
        let desiredItems = [leadingItem] + otherItems
        if item.leftBarButtonItems != desiredItems {
            item.setLeftBarButtonItems(desiredItems, animated: false)
        }
    }

    private func restoreFeedsTitle() {
        if let item = feedsTitleOwner?.navigationItem, let title = feedsTitleView {
            if let leadingItem = feedsTitleItem {
                let remaining = (item.leftBarButtonItems ?? []).filter { $0 !== leadingItem }
                item.setLeftBarButtonItems(remaining, animated: false)
            }
            let source = title.releaseSourceTitle()
            if item.titleView === centeredTitlePlaceholder {
                // CompactPhoneNavigationController.swift restores the live source, leaving a newer owner's replacement title untouched.
                item.titleView = source
            }
        }
        feedsTitleOwner = nil
        feedsTitleView = nil
        feedsTitleItem = nil
    }
}

/// CompactPhoneNavigationController.swift keeps Feeds leading and centers the existing title inside its story column.
@MainActor private final class ExpandedFeedsNavigationTitleView: UIView {
    private let sourceTitle: UIView?
    private let originalSourceFrame: CGRect?
    private let plainTitleLabel = UILabel()
    private let feedsButton = UIButton(type: .system)
    private let spacing: CGFloat = 12
    private var maximumWidth: CGFloat = 0
    private var lastPreferredSize: CGSize = .zero
    private weak var titleCoordinateView: UIView?
    private var columnCenter: CGFloat = 0
    private var originalTitleImages: [(view: UIImageView, original: UIImage, displayed: UIImage)] = []
    private var sourceTitleImages: [(view: UIImageView, index: Int, frame: CGRect)] = []
    private var originalTitleShadow: UIColor?

    init(sourceTitle: UIView?, showFeeds: @escaping () -> Void) {
        self.sourceTitle = sourceTitle
        originalSourceFrame = sourceTitle?.frame
        super.init(frame: .zero)
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Feeds"
        configuration.image = UIImage(systemName: "chevron.backward")
        configuration.imagePadding = 6
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
        feedsButton.configuration = configuration
        feedsButton.accessibilityIdentifier = "expanded-feeds-back"
        feedsButton.accessibilityLabel = "Feeds"
        feedsButton.addAction(UIAction { _ in showFeeds() }, for: .touchUpInside)
        addSubview(feedsButton)
        plainTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        plainTitleLabel.lineBreakMode = .byTruncatingTail
        addSubview(sourceTitle ?? plainTitleLabel)
        if let sourceTitle { preserveSourceImageColors(in: sourceTitle) }
        if let label = sourceTitle as? UILabel {
            // CompactPhoneNavigationController.swift keeps favicon colors outside the label's vibrant subtree and avoids recoloring its legacy shadow into duplicate text.
            originalTitleShadow = label.shadowColor
            label.shadowColor = nil
            for (index, child) in label.subviews.enumerated() {
                guard let imageView = child as? UIImageView else { continue }
                sourceTitleImages.append((imageView, index, imageView.frame))
                addSubview(imageView)
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var content: UIView { sourceTitle ?? plainTitleLabel }
    private var buttonWidth: CGFloat { max(44, feedsButton.intrinsicContentSize.width) }
    private var contentSize: CGSize {
        let intrinsic = content.intrinsicContentSize
        return CGSize(width: max(0, intrinsic.width >= 0 ? intrinsic.width : (originalSourceFrame?.width ?? 0)),
                      height: min(44, max(0, intrinsic.height >= 0 ? intrinsic.height : (originalSourceFrame?.height ?? 0))))
    }

    override var intrinsicContentSize: CGSize {
        let width = buttonWidth + spacing + contentSize.width
        return CGSize(width: maximumWidth > 0 ? maximumWidth : width, height: 44)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let preferred = intrinsicContentSize
        return CGSize(width: size.width > 0 ? min(size.width, preferred.width) : preferred.width, height: preferred.height)
    }

    func update(plainTitle: String?, navigationBar: UINavigationBar, maximumWidth: CGFloat, columnCenter: CGFloat) {
        if let sourceTitle { preserveSourceImageColors(in: sourceTitle) }
        for entry in sourceTitleImages { preserveSourceImageColors(in: entry.view) }
        if plainTitleLabel.text != plainTitle { plainTitleLabel.text = plainTitle }
        let attributes = navigationBar.titleTextAttributes ?? navigationBar.standardAppearance.titleTextAttributes
        plainTitleLabel.font = attributes[.font] as? UIFont ?? .systemFont(ofSize: 17, weight: .semibold)
        plainTitleLabel.textColor = attributes[.foregroundColor] as? UIColor ?? .label
        tintColor = navigationBar.tintColor
        self.maximumWidth = maximumWidth
        titleCoordinateView = navigationBar
        if self.columnCenter != columnCenter {
            self.columnCenter = columnCenter
            setNeedsLayout()
        }
        let preferred = intrinsicContentSize
        if lastPreferredSize != preferred {
            lastPreferredSize = preferred
            invalidateIntrinsicContentSize()
            if bounds.isEmpty { frame.size = preferred }
        }
        // CompactPhoneNavigationController.swift also relays live source text/font changes when the full-column item's width stays constant.
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = min(bounds.width, buttonWidth)
        feedsButton.frame = CGRect(x: 0, y: (bounds.height - 44) / 2, width: width, height: 44)
        let size = contentSize
        let center = titleCoordinateView.map { convert(CGPoint(x: columnCenter, y: 0), from: $0).x } ?? bounds.midX
        // CompactPhoneNavigationController.swift truncates symmetrically around the actual column center, leaving both native actions usable.
        let halfSpace = max(0, min(center - width - spacing, bounds.width - center))
        let titleWidth = min(size.width, halfSpace * 2)
        content.frame = CGRect(x: center - titleWidth / 2, y: (bounds.height - size.height) / 2,
                               width: titleWidth, height: size.height)
        for entry in sourceTitleImages {
            entry.view.frame = content.convert(entry.frame, to: self)
        }
    }

    private func preserveSourceImageColors(in view: UIView) {
        if let imageView = view as? UIImageView, let image = imageView.image,
           image.renderingMode == .automatic {
            // CompactPhoneNavigationController.swift preserves favicon pixels when UIKit hosts the title inside a bar button.
            let displayed = image.withRenderingMode(.alwaysOriginal)
            originalTitleImages.removeAll { $0.view === imageView }
            originalTitleImages.append((imageView, image, displayed))
            imageView.image = displayed
        }
        for child in view.subviews { preserveSourceImageColors(in: child) }
    }

    func releaseSourceTitle() -> UIView? {
        sourceTitle?.removeFromSuperview()
        for entry in originalTitleImages where entry.view.image === entry.displayed {
            entry.view.image = entry.original
        }
        originalTitleImages.removeAll()
        if let sourceTitle {
            for entry in sourceTitleImages where entry.view.superview === self {
                sourceTitle.insertSubview(entry.view, at: min(entry.index, sourceTitle.subviews.count))
                entry.view.frame = entry.frame
            }
        }
        sourceTitleImages.removeAll()
        if let label = sourceTitle as? UILabel, label.shadowColor == nil {
            label.shadowColor = originalTitleShadow
        }
        if let originalSourceFrame { sourceTitle?.frame = originalSourceFrame }
        return sourceTitle
    }
}

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
    private var ownsVerticalNavigationBackground = false
    private var originalNavigationBackground: UIColor?
    private var appliedVerticalNavigationBackground: UIColor?
    private var clearsVerticalBarBackground = false
    private var originalVerticalBarBackground: UIColor?
    private let verticalTitleLayout = VerticalNavigationTitleLayout()

    private var usesCompactHeader: Bool {
        if Utilities.usesSystemVerticalBar(traitCollection) {
            // CompactPhoneNavigationController.swift leaves Duo's navigation and safe-area placement to the managed side bar.
            return false
        }
        return UIDevice.current.userInterfaceIdiom == .phone && traitCollection.verticalSizeClass == .compact &&
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
        verticalTitleLayout.update(navigation: self, controller: topViewController,
                                   enabled: topViewController is FeedDetailObjCViewController &&
                                    (traitCollection.horizontalSizeClass == .compact ||
                                     (topViewController as? FeedDetailViewController)?.appDelegate.detailViewController.isDuoFullscreenReader == true))
        updateVerticalNavigationBackground()
    }

    private func updateVerticalNavigationBackground() {
        let needsBackground = Utilities.usesSystemVerticalBar(traitCollection) && !isNavigationBarHidden &&
            (topViewController is FeedDetailObjCViewController || topViewController is DiscoverSitesViewController)
        guard needsBackground,
              let color = navigationBar.barTintColor ?? navigationBar.standardAppearance.backgroundColor ?? navigationBar.backgroundColor else {
            if clearsVerticalBarBackground {
                // CompactPhoneNavigationController.swift restores its fill only for ordinary owners; the reader manages its own transparent bar.
                if navigationBar.backgroundColor == .clear, !(topViewController is StoryPagesObjCViewController) {
                    navigationBar.backgroundColor = originalVerticalBarBackground
                }
                clearsVerticalBarBackground = false
                originalVerticalBarBackground = nil
            }
            if ownsVerticalNavigationBackground {
                // CompactPhoneNavigationController.swift restores only its own fill, preserving a new owner's explicit background.
                if view.backgroundColor == appliedVerticalNavigationBackground {
                    view.backgroundColor = originalNavigationBackground
                }
                ownsVerticalNavigationBackground = false
                originalNavigationBackground = nil
                appliedVerticalNavigationBackground = nil
            }
            return
        }
        if !ownsVerticalNavigationBackground {
            originalNavigationBackground = view.backgroundColor
            ownsVerticalNavigationBackground = true
        }
        // CompactPhoneNavigationController.swift fills the exposed space above Duo's native title bar using its current theme.
        if view.backgroundColor != color { view.backgroundColor = color }
        appliedVerticalNavigationBackground = color
        if !clearsVerticalBarBackground || navigationBar.backgroundColor != .clear {
            originalVerticalBarBackground = navigationBar.backgroundColor
            clearsVerticalBarBackground = true
        }
        // CompactPhoneNavigationController.swift lets UIKit scroll its title/background away without leaving a fixed opaque UIView over the stories.
        if navigationBar.backgroundColor != .clear { navigationBar.backgroundColor = .clear }
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
