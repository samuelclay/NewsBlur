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

    static func fittedSize(_ size: CGSize, in bounds: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(1, bounds.width / size.width, bounds.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

// StoryDetailObjCViewController.m calls this after substituting each offline image URL.
@objc(StoryImageOfflineSource) final class StoryImageOfflineSource: NSObject {
    @objc static func annotate(_ html: String, cachedURL: String, originalURL: String) -> String {
        let pattern = "(<img\\b[^>]*?\\s)src\\s*=\\s*([\"'])" + NSRegularExpression.escapedPattern(for: cachedURL) + "\\2"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return html }
        let escaped = originalURL.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
        let replacement = "$1data-newsblur-original-src=\"" + NSRegularExpression.escapedTemplate(for: escaped) + "\" src=$2" + NSRegularExpression.escapedTemplate(for: cachedURL) + "$2"
        return regex.stringByReplacingMatches(in: html, range: NSRange(html.startIndex..., in: html), withTemplate: replacement)
    }
}

extension StoryDetailViewController {
    func receiveImageMessage(_ message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.webView === webView,
              let source = StoryImageSource(message.body), isCurrentStoryImageLoad(source.loadID),
              appDelegate.storyPagesViewController.currentPage === self,
              let window = webView.window, let presenter = window.rootViewController,
              presenter.presentedViewController == nil, !openingImage else { return }
        openingImage = true
        let scale = webView.bounds.width / source.viewportWidth
        let localRect = source.rect.applying(CGAffineTransform(scaleX: scale, y: scale))
        let sourceRect = webView.convert(localRect, to: window)
        let configuration = WKSnapshotConfiguration()
        configuration.rect = localRect.intersection(webView.bounds)
        configuration.afterScreenUpdates = false
        webView.takeSnapshot(with: configuration) { [weak self, weak presenter] snapshot, _ in
            guard let self else { return }
            self.openingImage = false
            guard let presenter, self.isCurrentStoryImageLoad(source.loadID),
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
                    let scale = self.webView.bounds.width / viewport
                    let local = rect.applying(CGAffineTransform(scaleX: scale, y: scale))
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
    private let status = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var imageData: Data?
    private var imageType: String?
    private var task: URLSessionDataTask?
    private var sharedFile: URL?
    private var fittedSize = CGSize.zero
    private var laidOutSize = CGSize.zero
    private var entered = false
    private var closing = false
    private var dragging = false
    private var transitionImage: UIImageView?
    var returnRect: ((@escaping (CGRect?) -> Void) -> Void)?

    init(source: StoryImageSource, preview: UIImage?, origin: CGRect) {
        self.source = source
        self.origin = origin
        super.init(nibName: nil, bundle: nil)
        imageView.image = preview
        modalPresentationStyle = .overFullScreen
        modalPresentationCapturesStatusBarAppearance = true
    }

    required init?(coder: NSCoder) { fatalError("StoryImageViewerController.swift uses init(source:preview:origin:)") }
    override var prefersStatusBarHidden: Bool { true }
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
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragImage(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        scroll.addGestureRecognizer(pan)
        scroll.panGestureRecognizer.require(toFail: pan)
        imageView.addInteraction(UIContextMenuInteraction(delegate: self))
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
        scroll.frame = view.bounds
        controls.frame = CGRect(x: view.safeAreaInsets.left + 16, y: view.safeAreaInsets.top + 12,
                                width: view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right - 32, height: 48)
        status.frame = CGRect(x: 30, y: view.bounds.height - view.safeAreaInsets.bottom - 72, width: view.bounds.width - 60, height: 44)
        spinner.center = CGPoint(x: view.bounds.midX, y: status.frame.minY - 16)
        guard laidOutSize != view.bounds.size, !closing else { return }
        laidOutSize = view.bounds.size
        layoutImage()
    }

    private func layoutImage() {
        scroll.setZoomScale(1, animated: false)
        fittedSize = StoryImageSource.fittedSize(source.naturalSize, in: view.bounds.size)
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

    private func copyImage() {
        guard let imageData else { return }
        UIPasteboard.general.setData(imageData, forPasteboardType: imageType ?? UTType.image.identifier)
        announce("Image copied")
    }

    private func shareImage() {
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

    private func saveImage() {
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

extension StoryImageViewerController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in self?.menuButton.menu }
    }
}
