import UIKit
import WebKit
import Photos
import ImageIO
import UniformTypeIdentifiers

struct StoryImageSource {
    let loadID: String
    let token: String
    let url: URL
    let originalURL: URL?
    let link: URL?
    let title: String
    let hoverText: String?
    let showActions: Bool
    let naturalSize: CGSize
    let rect: CGRect
    let viewportWidth: CGFloat

    init?(_ body: Any) {
        guard let body = body as? [String: Any], let loadID = body["loadID"] as? String,
              let token = body["token"] as? String, !token.isEmpty,
              token.allSatisfy({ $0.isASCII && $0.isNumber }),
              let src = body["src"] as? String, let url = URL(string: src),
              ["https", "http", "data"].contains(url.scheme?.lowercased() ?? ""),
              let dimensions = Self.dimensions(body), let geometry = Self.geometry(body["rect"]) else { return nil }
        self.loadID = loadID
        self.token = token
        self.url = url
        originalURL = Self.browserURL(body["originalURL"] as? String)
        link = Self.browserURL(body["link"] as? String)
        title = (body["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Story image"
        hoverText = (body["hoverText"] as? String).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
        showActions = body["showActions"] as? Bool == true
        naturalSize = dimensions
        rect = geometry.0
        viewportWidth = geometry.1
    }

    static func browserURL(_ string: String?) -> URL? {
        guard let string, let url = URL(string: string),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }

    private static func dimensions(_ body: [String: Any]) -> CGSize? {
        guard let width = (body["naturalWidth"] as? NSNumber)?.doubleValue, let height = (body["naturalHeight"] as? NSNumber)?.doubleValue,
              width.isFinite, height.isFinite, width > 1, height > 1 else { return nil }
        return CGSize(width: width, height: height)
    }

    static func geometry(_ value: Any?) -> (CGRect, CGFloat)? {
        guard let value = value as? [String: Any], let x = (value["x"] as? NSNumber)?.doubleValue,
              let y = (value["y"] as? NSNumber)?.doubleValue, let width = (value["width"] as? NSNumber)?.doubleValue,
              let height = (value["height"] as? NSNumber)?.doubleValue, let viewport = (value["viewportWidth"] as? NSNumber)?.doubleValue,
              [x, y, width, height, viewport].allSatisfy(\.isFinite),
              width > 0, height > 0, viewport > 0 else { return nil }
        return (CGRect(x: x, y: y, width: width, height: height), CGFloat(viewport))
    }

    @MainActor static func viewRect(_ rect: CGRect, viewportWidth: CGFloat, in webView: WKWebView) -> CGRect {
        let scale = webView.bounds.width / viewportWidth
        let offset = webView.scrollView.contentOffset
        return rect.applying(CGAffineTransform(scaleX: scale, y: scale))
            .offsetBy(dx: -offset.x, dy: -offset.y)
    }

    static func fittedSize(_ size: CGSize, in bounds: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(1, bounds.width / size.width, bounds.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

// StoryDetailObjCViewController.m calls this after substituting each offline image URL.
@objc(StoryImageOfflineSource) final class StoryImageOfflineSource: NSObject {
    private static let imageStarts = try? NSRegularExpression(pattern: #"<img\b"#, options: .caseInsensitive)

    private static func isWhitespace(_ character: unichar) -> Bool {
        character == 32 || character == 9 || character == 10 || character == 12 || character == 13
    }

    @objc static func annotate(_ html: String, cachedURL: String, originalURL: String) -> String {
        guard let imageStarts else { return html }
        let document = html as NSString
        var insertionLocations: [Int] = []
        var previousTagEnd = 0
        // StoryImageViewerController.swift scans attributes linearly; image bytes never enter a regex or a replacement template.
        for image in imageStarts.matches(in: html, range: NSRange(location: 0, length: document.length)) {
            if image.range.location < previousTagEnd { continue }
            var cursor = NSMaxRange(image.range)
            var sourceLocation: Int?
            var alreadyAnnotated = false
            while cursor < document.length {
                let character = document.character(at: cursor)
                if character == 62 {
                    previousTagEnd = cursor + 1
                    if !alreadyAnnotated, let sourceLocation { insertionLocations.append(sourceLocation) }
                    break
                }
                if character == 60 { break }
                if isWhitespace(character) || character == 47 { cursor += 1; continue }
                let nameStart = cursor
                while cursor < document.length {
                    let character = document.character(at: cursor)
                    if isWhitespace(character) || [61, 47, 62, 60, 34, 39].contains(character) { break }
                    cursor += 1
                }
                if cursor == nameStart { break }
                let name = document.substring(with: NSRange(location: nameStart, length: cursor - nameStart)).lowercased()
                if name == "data-newsblur-original-src" { alreadyAnnotated = true }
                while cursor < document.length && isWhitespace(document.character(at: cursor)) { cursor += 1 }
                guard cursor < document.length, document.character(at: cursor) == 61 else { continue }
                cursor += 1
                while cursor < document.length && isWhitespace(document.character(at: cursor)) { cursor += 1 }
                guard cursor < document.length else { break }
                let quote = document.character(at: cursor)
                if quote == 34 || quote == 39 {
                    cursor += 1
                    let end = document.range(of: quote == 34 ? "\"" : "'", options: .literal,
                                             range: NSRange(location: cursor, length: document.length - cursor))
                    guard end.location != NSNotFound else { break }
                    let valueRange = NSRange(location: cursor, length: end.location - cursor)
                    // StoryDetailObjCViewController.m supplies case-sensitive data URLs; keep original quoting and surrounding markup intact.
                    if name == "src", sourceLocation == nil,
                       document.compare(cachedURL, options: .literal, range: valueRange) == .orderedSame {
                        sourceLocation = nameStart
                    }
                    cursor = NSMaxRange(end)
                } else {
                    while cursor < document.length && !isWhitespace(document.character(at: cursor)) &&
                        document.character(at: cursor) != 62 && document.character(at: cursor) != 60 { cursor += 1 }
                }
            }
        }
        guard !insertionLocations.isEmpty else { return html }
        let escaped = originalURL.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
        let annotation = "data-newsblur-original-src=\"\(escaped)\" "
        let result = NSMutableString(string: html)
        for location in insertionLocations.reversed() { result.insert(annotation, at: location) }
        return result as String
    }
}

extension StoryDetailViewController {
    func receiveImageMessage(_ message: WKScriptMessage) {
        let accessibility = (message.body as? [String: Any])?["accessibilityActivation"] as? Bool == true
        guard message.frameInfo.isMainFrame, message.webView === webView,
              let source = StoryImageSource(message.body), isCurrentStoryImageLoad(source.loadID),
              canOpenStoryImage(accessibility: accessibility || source.showActions),
              appDelegate.storyPagesViewController.currentPage === self,
              let window = webView.window, let presenter = window.rootViewController,
              presenter.presentedViewController == nil, !openingImage else { return }
        openingImage = true
        let scrollOffset = webView.scrollView.contentOffset
        let localRect = StoryImageSource.viewRect(source.rect, viewportWidth: source.viewportWidth, in: webView)
        let sourceRect = webView.convert(localRect, to: window)
        let configuration = WKSnapshotConfiguration()
        configuration.rect = localRect.intersection(webView.bounds)
        configuration.afterScreenUpdates = false
        webView.takeSnapshot(with: configuration) { [weak self, weak presenter] snapshot, _ in
            guard let self else { return }
            self.openingImage = false
            guard let presenter, self.isCurrentStoryImageLoad(source.loadID),
                  self.canOpenStoryImage(accessibility: accessibility || source.showActions),
                  self.webView.scrollView.contentOffset == scrollOffset,
                  self.appDelegate.storyPagesViewController.currentPage === self,
                  self.webView.window === window, presenter.presentedViewController == nil else { return }
            let viewer = StoryImageViewerController(source: source, preview: snapshot, origin: sourceRect)
            viewer.returnRect = { [weak self] completion in
                guard let self, self.webView.window === window,
                      self.isCurrentStoryImageLoad(source.loadID),
                      self.appDelegate.storyPagesViewController.currentPage === self else { completion(nil); return }
                // StoryImageSource validates the token; JSON encoding protects the document generation argument.
                let arguments = (try? JSONSerialization.data(withJSONObject: [source.token, source.loadID]))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                self.webView.evaluateJavaScript("newsblurImageRect.apply(null, \(arguments))") { [weak self] result, _ in
                    guard let self, self.isCurrentStoryImageLoad(source.loadID),
                          let (rect, viewport) = StoryImageSource.geometry(result) else { completion(nil); return }
                    let local = StoryImageSource.viewRect(rect, viewportWidth: viewport, in: self.webView)
                    completion(local.intersects(self.webView.bounds) ? self.webView.convert(local, to: window) : nil)
                }
            }
            presenter.present(viewer, animated: false)
        }
    }
}

// StoryImageViewerController.swift overlays every reader column without disturbing the underlying web view.
final class StoryImageViewerController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let source: StoryImageSource
    private let origin: CGRect
    private let backdrop = UIView()
    private let scroll = UIScrollView()
    private let imageView = UIImageView()
    private let controls = UIView()
    private let menuButton = UIButton(type: .system)
    private let hoverDisclosure = UIScrollView()
    private let hoverLabel = UILabel()
    private let actionDisclosure = UIStackView()
    private var actionButtons: [UIButton] = []
    private var disclosuresVisible = false
    private let status = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var imageData: Data?
    private var imageType: String?
    private var task: URLSessionDataTask?
    private var sharedFile: URL?
    private var fittedSize = CGSize.zero
    private var laidOutViewport = CGRect.zero
    private var entered = false
    private var closing = false
    private var dragging = false
    private var transitionImage: UIImageView?
    var returnRect: ((@escaping (CGRect?) -> Void) -> Void)?

    init(source: StoryImageSource, preview: UIImage?, origin: CGRect) {
        self.source = source
        self.origin = origin
        disclosuresVisible = source.showActions
        super.init(nibName: nil, bundle: nil)
        imageView.image = preview
        modalPresentationStyle = .overFullScreen
        modalPresentationCapturesStatusBarAppearance = true
    }

    required init?(coder: NSCoder) { fatalError("StoryImageViewerController.swift uses init(source:preview:origin:)") }
    private var usesEdgeToEdgePresentation: Bool {
        // StoryImageViewerController.swift reads the presenting window before attachment so Duo's status rail is hidden from the first frame.
        let traits = viewIfLoaded?.window?.traitCollection
            ?? presentingViewController?.viewIfLoaded?.window?.traitCollection
            ?? traitCollection
        return Utilities.usesSystemVerticalBar(traits)
    }

    override var prefersStatusBarHidden: Bool { usesEdgeToEdgePresentation }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.accessibilityIdentifier = "story-image-viewer"
        view.accessibilityViewIsModal = true
        overrideUserInterfaceStyle = .dark
        backdrop.backgroundColor = .black
        backdrop.alpha = 0
        view.addSubview(backdrop)
        scroll.delegate = self
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.bouncesZoom = true
        scroll.accessibilityIdentifier = "story-image-zoom"
        view.addSubview(scroll)
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = source.title
        imageView.accessibilityIdentifier = "fullscreen-story-image"
        scroll.addSubview(imageView)
        view.addSubview(controls)
        let close = makeButton(symbol: "xmark", label: "Close image")
        close.addTarget(self, action: #selector(closeImage), for: .touchUpInside)
        controls.addSubview(close)
        configureButton(menuButton, symbol: "ellipsis", label: "Image actions")
        menuButton.showsMenuAsPrimaryAction = true
        controls.addSubview(menuButton)
        close.translatesAutoresizingMaskIntoConstraints = false
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            close.leadingAnchor.constraint(equalTo: controls.leadingAnchor), close.topAnchor.constraint(equalTo: controls.topAnchor),
            close.widthAnchor.constraint(equalToConstant: 48), close.heightAnchor.constraint(equalToConstant: 48),
            menuButton.trailingAnchor.constraint(equalTo: controls.trailingAnchor), menuButton.topAnchor.constraint(equalTo: controls.topAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 48), menuButton.heightAnchor.constraint(equalToConstant: 48)
        ])
        hoverDisclosure.backgroundColor = UIColor(white: 0.14, alpha: 1)
        hoverDisclosure.layer.cornerRadius = 16
        hoverDisclosure.accessibilityIdentifier = "image-hover-disclosure"
        hoverDisclosure.contentInsetAdjustmentBehavior = .never
        hoverLabel.text = source.hoverText
        hoverLabel.font = .preferredFont(forTextStyle: .body)
        hoverLabel.adjustsFontForContentSizeCategory = true
        hoverLabel.textColor = .white
        hoverLabel.numberOfLines = 0
        hoverDisclosure.addSubview(hoverLabel)
        view.addSubview(hoverDisclosure)
        actionDisclosure.axis = .vertical
        actionDisclosure.distribution = .fillEqually
        actionDisclosure.backgroundColor = UIColor(white: 0.14, alpha: 1)
        actionDisclosure.layer.cornerRadius = 16
        actionDisclosure.clipsToBounds = true
        actionDisclosure.accessibilityIdentifier = "image-action-disclosure"
        for (title, symbol, selector) in [
            ("Copy Image", "doc.on.doc", #selector(copyImage)),
            ("Save Image", "square.and.arrow.down", #selector(saveImage)),
            ("Share Image…", "square.and.arrow.up", #selector(shareImage))
        ] {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.title = title
            configuration.image = UIImage(systemName: symbol)
            configuration.imagePlacement = .trailing
            configuration.imagePadding = 16
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
            configuration.baseForegroundColor = .white
            button.configuration = configuration
            button.contentHorizontalAlignment = .fill
            button.addTarget(self, action: selector, for: .touchUpInside)
            actionDisclosure.addArrangedSubview(button)
            actionButtons.append(button)
            if actionButtons.count < 3 {
                let separator = UIView()
                separator.backgroundColor = UIColor(white: 1, alpha: 0.12)
                separator.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(separator)
                NSLayoutConstraint.activate([
                    separator.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
                    separator.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                    separator.bottomAnchor.constraint(equalTo: button.bottomAnchor),
                    separator.heightAnchor.constraint(equalToConstant: 0.5)
                ])
            }
        }
        view.addSubview(actionDisclosure)
        status.textColor = .white
        status.font = .preferredFont(forTextStyle: .footnote)
        status.textAlignment = .center
        status.numberOfLines = 0
        status.text = "Loading image…"
        view.addSubview(status)
        spinner.color = .white
        view.addSubview(spinner)
        spinner.startAnimating()
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(zoomImage(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(tapImage))
        // StoryImageViewerController.swift lets a double tap zoom without also dismissing the viewer.
        singleTap.require(toFail: doubleTap)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(revealImageActions(_:)))
        singleTap.require(toFail: longPress)
        scroll.addGestureRecognizer(longPress)
        scroll.addGestureRecognizer(singleTap)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragImage(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        scroll.addGestureRecognizer(pan)
        scroll.panGestureRecognizer.require(toFail: pan)
        imageView.isUserInteractionEnabled = true
        updateMenu()
        loadImage()
    }

    private func makeButton(symbol: String, label: String) -> UIButton {
        let button = UIButton(type: .system)
        configureButton(button, symbol: symbol, label: label)
        return button
    }

    private func configureButton(_ button: UIButton, symbol: String, label: String) {
        if #available(iOS 26.0, *) { button.configuration = .glass() }
        else { button.configuration = .filled(); button.configuration?.baseBackgroundColor = UIColor(white: 0.18, alpha: 0.85) }
        button.configuration?.cornerStyle = .capsule
        button.configuration?.baseForegroundColor = .white
        button.configuration?.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
        button.accessibilityLabel = label
        button.isPointerInteractionEnabled = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backdrop.frame = view.bounds
        controls.frame = CGRect(x: view.safeAreaInsets.left + 16, y: view.safeAreaInsets.top + 12,
                                width: view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right - 32, height: 48)
        status.frame = CGRect(x: 30, y: view.bounds.height - view.safeAreaInsets.bottom - 72, width: view.bounds.width - 60, height: 44)
        spinner.center = CGPoint(x: view.bounds.midX, y: status.frame.minY - 16)
        var viewport = usesEdgeToEdgePresentation ? view.bounds : view.bounds.inset(by: view.safeAreaInsets)
        hoverDisclosure.isHidden = !disclosuresVisible || source.hoverText == nil
        actionDisclosure.isHidden = !disclosuresVisible
        if disclosuresVisible {
            viewport = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: 16, dy: 0)
            viewport.origin.y = controls.frame.maxY + 12
            viewport.size.height = max(1, view.bounds.height - view.safeAreaInsets.bottom - viewport.minY - 44)
            let rowHeight = max(44, UIFont.preferredFont(forTextStyle: .body).lineHeight + 22)
            let menuHeight = rowHeight * 3
            let menuWidth = min(260, viewport.width)
            // StoryImageViewerController.swift keeps the image useful on short landscape screens by placing actions beside it.
            if viewport.width > viewport.height * 1.6, viewport.width > 500 {
                actionDisclosure.frame = CGRect(x: viewport.maxX - menuWidth, y: viewport.midY - menuHeight / 2,
                                                width: menuWidth, height: menuHeight)
                viewport.size.width -= menuWidth + 16
            } else {
                actionDisclosure.frame = CGRect(x: viewport.midX - menuWidth / 2, y: viewport.maxY - menuHeight,
                                                width: menuWidth, height: menuHeight)
                viewport.size.height = max(1, viewport.height - menuHeight - 16)
            }
            if !hoverDisclosure.isHidden {
                let textSize = hoverLabel.sizeThatFits(CGSize(width: viewport.width - 32, height: .greatestFiniteMagnitude))
                let height = min(textSize.height + 28, max(44, viewport.height * 0.35))
                hoverDisclosure.frame = CGRect(x: viewport.minX, y: viewport.minY, width: viewport.width, height: height)
                hoverLabel.frame = CGRect(x: 16, y: 14, width: viewport.width - 32, height: textSize.height)
                hoverDisclosure.contentSize = CGSize(width: viewport.width, height: textSize.height + 28)
                viewport.origin.y += height + 12
                viewport.size.height = max(1, viewport.height - height - 12)
            }
            status.frame = CGRect(x: controls.frame.minX, y: view.bounds.height - view.safeAreaInsets.bottom - 40,
                                  width: controls.frame.width, height: 36)
            spinner.center = CGPoint(x: viewport.midX, y: viewport.midY)
        }
        guard laidOutViewport != viewport, !closing else { return }
        laidOutViewport = viewport
        // StoryImageViewerController.swift fills Duo's display beneath its cutout while retaining ordinary status-bar protection and live dismissal transforms.
        scroll.bounds.size = viewport.size
        scroll.center = CGPoint(x: viewport.midX, y: viewport.midY)
        layoutImage()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        view.setNeedsLayout()
    }

    private func layoutImage() {
        scroll.setZoomScale(1, animated: false)
        fittedSize = StoryImageSource.fittedSize(source.naturalSize, in: scroll.bounds.size)
        imageView.transform = .identity
        imageView.frame = CGRect(origin: .zero, size: fittedSize)
        scroll.contentSize = fittedSize
        scroll.minimumZoomScale = 1
        // StoryImageViewerController.swift fits without upscaling, but lets deliberate zoom exceed native resolution.
        scroll.maximumZoomScale = max(4, min(12, 2 * source.naturalSize.width / max(fittedSize.width, 1)))
        centerImage()
    }

    private func centerImage() {
        imageView.center = CGPoint(x: max(scroll.bounds.width, scroll.contentSize.width) / 2,
                                   y: max(scroll.bounds.height, scroll.contentSize.height) / 2)
        scroll.accessibilityValue = scroll.zoomScale > 1.01 ? "Zoomed" : "Fitted"
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage() }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !entered else { return }
        entered = true
        let flying = UIImageView(image: imageView.image)
        flying.contentMode = .scaleAspectFit
        flying.frame = view.convert(origin, from: view.window)
        view.insertSubview(flying, belowSubview: controls)
        transitionImage = flying
        scroll.alpha = 0
        controls.alpha = 0
        let target = imageView.convert(imageView.bounds, to: view)
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0.18 : 0.35, delay: 0,
                       usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
            self.backdrop.alpha = 1
            self.controls.alpha = 1
            if UIAccessibility.isReduceMotionEnabled { flying.alpha = 0 } else { flying.frame = target }
        } completion: { _ in
            flying.removeFromSuperview()
            self.transitionImage = nil
            self.scroll.alpha = 1
            UIAccessibility.post(notification: .screenChanged, argument: self.imageView)
        }
    }

    @objc private func zoomImage(_ gesture: UITapGestureRecognizer) {
        guard !closing else { return }
        if scroll.zoomScale > 1.01 { scroll.setZoomScale(1, animated: true); return }
        let zoom = min(3, scroll.maximumZoomScale)
        let point = gesture.location(in: imageView)
        let size = CGSize(width: scroll.bounds.width / zoom, height: scroll.bounds.height / zoom)
        scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                               width: size.width, height: size.height), animated: true)
    }

    @objc private func tapImage() {
        guard !closing, transitionImage == nil, !dragging, presentedViewController == nil else { return }
        if scroll.zoomScale > 1.01 {
            scroll.setZoomScale(1, animated: true)
        } else {
            closeImage()
        }
    }

    @objc private func revealImageActions(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, !closing, transitionImage == nil, !dragging,
              presentedViewController == nil else { return }
        disclosuresVisible = true
        view.setNeedsLayout()
        view.layoutIfNeeded()
        UIAccessibility.post(notification: .layoutChanged, argument: source.hoverText == nil ? actionDisclosure : hoverLabel)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        !closing && transitionImage == nil && scroll.zoomScale <= 1.01 && presentedViewController == nil
    }

    @objc private func dragImage(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let distance = hypot(translation.x, translation.y)
        switch gesture.state {
        case .began, .changed:
            dragging = true
            let scale = max(0.75, 1 - distance / max(view.bounds.height, view.bounds.width) * 0.35)
            scroll.transform = CGAffineTransform(translationX: translation.x, y: translation.y).scaledBy(x: scale, y: scale)
            backdrop.alpha = max(0.15, 1 - distance / 320)
            controls.alpha = max(0, 1 - distance / 100)
            hoverDisclosure.alpha = controls.alpha
            actionDisclosure.alpha = controls.alpha
            status.alpha = controls.alpha
        case .ended:
            dragging = false
            let velocity = gesture.velocity(in: view)
            if distance > 90 || (distance > 25 && hypot(velocity.x, velocity.y) > 650) { closeImage() }
            else { restoreDrag() }
        case .cancelled, .failed:
            dragging = false
            restoreDrag()
        default: break
        }
    }

    private func restoreDrag() {
        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.scroll.transform = .identity
            self.backdrop.alpha = 1
            self.controls.alpha = 1
            self.hoverDisclosure.alpha = 1
            self.actionDisclosure.alpha = 1
            self.status.alpha = 1
        }
    }

    @objc private func closeImage() {
        closeViewer(completion: nil)
    }

    private func closeViewer(completion: (() -> Void)?) {
        guard !closing else { return }
        closing = true
        task?.cancel()
        if let returnRect { returnRect { [weak self] rect in self?.animateClosed(to: rect, completion: completion) } }
        else { animateClosed(to: nil, completion: completion) }
    }

    private func animateClosed(to rect: CGRect?, completion: (() -> Void)?) {
        let flying = UIImageView(image: imageView.image)
        flying.contentMode = .scaleAspectFit
        flying.frame = imageView.convert(imageView.bounds, to: view)
        view.insertSubview(flying, belowSubview: controls)
        scroll.alpha = 0
        spinner.stopAnimating()
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0.18 : 0.3, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            self.backdrop.alpha = 0
            self.controls.alpha = 0
            self.hoverDisclosure.alpha = 0
            self.actionDisclosure.alpha = 0
            self.status.alpha = 0
            if let rect, !UIAccessibility.isReduceMotionEnabled { flying.frame = self.view.convert(rect, from: self.view.window) }
            else { flying.alpha = 0 }
        } completion: { _ in self.dismiss(animated: false, completion: completion) }
    }

    override func accessibilityPerformEscape() -> Bool { closeImage(); return true }

    private func loadImage() {
        let finish: (Data?, Error?) -> Void = { [weak self] data, error in
            // Decode off the main thread and cap the display bitmap; retain original bytes for copying and Photos.
            let source = data.flatMap { CGImageSourceCreateWithData($0 as CFData, nil) }
            let bitmap = source.flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 4096, kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary) }
            let image = bitmap.map { UIImage(cgImage: $0) }
            let type = source.flatMap { CGImageSourceGetType($0) as String? }
            DispatchQueue.main.async {
                guard let self, !self.closing else { return }
                self.spinner.stopAnimating()
                if let image, let data {
                    self.imageData = data
                    self.imageType = type
                    self.imageView.image = image
                    self.transitionImage?.image = image
                    self.status.text = nil
                } else {
                    self.status.text = "Couldn’t load the full image. You can try opening it in your browser."
                }
                self.updateMenu()
            }
        }
        if source.url.scheme == "data" {
            let url = source.url
            DispatchQueue.global(qos: .userInitiated).async {
                do { finish(try Data(contentsOf: url), nil) } catch { finish(nil, error) }
            }
        } else {
            var request = URLRequest(url: source.url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
            request.setValue("image/*", forHTTPHeaderField: "Accept")
            task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                    finish(nil, error ?? URLError(.badServerResponse)); return
                }
                finish(data, error)
            }
            task?.resume()
        }
    }

    private func updateMenu() {
        actionButtons.forEach { $0.isEnabled = imageData != nil }
        func action(_ title: String, _ symbol: String, enabled: Bool = true, _ body: @escaping () -> Void) -> UIAction {
            UIAction(title: title, image: UIImage(systemName: symbol), attributes: enabled ? [] : [.disabled]) { _ in body() }
        }
        let fileActions = [
            action("Save Image", "square.and.arrow.down", enabled: imageData != nil) { [weak self] in self?.saveImage() },
            action("Copy Image", "doc.on.doc", enabled: imageData != nil) { [weak self] in self?.copyImage() },
            action("Share Image…", "square.and.arrow.up", enabled: imageData != nil) { [weak self] in self?.shareImage() }
        ]
        var links: [UIAction] = []
        if let url = source.originalURL {
            links.append(action("Open Image in Browser", "safari") { [weak self] in self?.openURL(url) })
        }
        if let link = source.link {
            links.append(action("Open Link", "link") { [weak self] in self?.openURL(link) })
        }
        menuButton.menu = UIMenu(children: [UIMenu(options: .displayInline, children: fileActions)] +
                              (links.isEmpty ? [] : [UIMenu(options: .displayInline, children: links)]))
    }

    @objc private func copyImage() {
        guard let imageData else { return }
        UIPasteboard.general.setData(imageData, forPasteboardType: imageType ?? UTType.image.identifier)
        announce("Image copied")
    }

    @objc private func shareImage() {
        guard let imageData else { return }
        // StoryImageViewerController.swift shares the original file, preserving resolution and animated formats.
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(imageType.flatMap { UTType($0)?.preferredFilenameExtension } ?? "png")
        do { try imageData.write(to: file, options: .atomic) }
        catch { announce("Couldn’t prepare the image for sharing."); return }
        sharedFile = file
        let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = menuButton
        sheet.popoverPresentationController?.sourceRect = menuButton.bounds
        sheet.completionWithItemsHandler = { [weak self] _, _, _, _ in
            try? FileManager.default.removeItem(at: file)
            self?.sharedFile = nil
        }
        present(sheet, animated: true)
    }

    private func openURL(_ url: URL) {
        closeViewer { UIApplication.shared.open(url) }
    }

    @objc private func saveImage() {
        guard let imageData else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] authorization in
            guard authorization == .authorized || authorization == .limited else {
                DispatchQueue.main.async { self?.showError("Allow NewsBlur to add photos in Settings to save this image.") }; return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData, options: nil)
            } completionHandler: { saved, error in
                DispatchQueue.main.async {
                    if saved { self?.announce("Image saved to Photos") }
                    else { self?.showError(error?.localizedDescription ?? "The image could not be saved.") }
                }
            }
        }
    }

    private func announce(_ text: String) {
        status.text = text
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    private func showError(_ message: String) {
        guard !closing else { return }
        let alert = UIAlertController(title: "Save Image", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    deinit {
        task?.cancel()
        if let sharedFile { try? FileManager.default.removeItem(at: sharedFile) }
    }
}
