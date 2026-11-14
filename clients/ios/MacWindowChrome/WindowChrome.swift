// WindowChrome.swift supplies the AppKit backdrop for the Catalyst reader window.
import AppKit

@objc(NBWindowChrome)
final class WindowChrome: NSObject {
    private weak var window: NSWindow?
    private let backdrop = NSVisualEffectView()
    private let tint = NSView()
    private var appearanceOptions = NSDictionary()

    override init() {
        super.init()
        // WindowChrome.swift waits for Catalyst to create its NSWindow after SceneDelegate.swift connects the scene.
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidUpdate(_:)),
                                               name: NSWindow.didUpdateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowsDidFinishRestoring),
                                               name: NSApplication.didFinishRestoringWindowsNotification, object: nil)
    }

    @objc private func windowsDidFinishRestoring() {
        // WindowChrome.swift bridges AppKit restoration completion to SceneDelegate.swift without importing AppKit into Catalyst.
        let readerWindow = window ?? NSApplication.shared.windows.first { $0.toolbar?.identifier == "main" }
        var userInfo: [String: Any] = [:]
        if let readerWindow, let mainDisplay = NSScreen.screens.first {
            userInfo["systemFrame"] = NSValue(rect: systemFrame(readerWindow.frame, relativeTo: mainDisplay))
        }
        NotificationCenter.default.post(name: Notification.Name("NewsBlurMacDidFinishRestoringWindows"), object: nil, userInfo: userInfo)
    }

    @objc private func windowDidUpdate(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window.toolbar?.identifier == "main",
              backdrop.window !== window else { return }
        self.window = window
        updateAppearance(appearanceOptions)
    }

    @objc(usableDisplayFrameForSystemFrame:)
    func usableDisplayFrame(forSystemFrame value: NSValue) -> NSValue? {
        guard let mainDisplay = NSScreen.screens.first else { return nil }
        let target = value.rectValue
        let intersecting = NSScreen.screens.map { screen in
            let overlap = systemFrame(screen.frame, relativeTo: mainDisplay).intersection(target)
            return (screen, overlap.isNull ? 0 : overlap.width * overlap.height)
        }.max { $0.1 < $1.1 }
        let screen = intersecting.flatMap { $0.1 > 0 ? $0.0 : nil } ?? window?.screen ?? NSScreen.main ?? mainDisplay
        return NSValue(rect: systemFrame(screen.visibleFrame, relativeTo: mainDisplay))
    }

    private func systemFrame(_ rect: CGRect, relativeTo mainDisplay: NSScreen) -> CGRect {
        // WindowChrome.swift converts AppKit's bottom-left screen coordinates to SceneDelegate.swift's top-left system coordinates.
        CGRect(x: rect.minX, y: mainDisplay.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    @objc func updateAppearance(_ options: NSDictionary) {
        appearanceOptions = options
        // WindowChrome.swift identifies the reader by SceneDelegate.swift's toolbar, excluding sheets and auxiliary windows.
        guard let window = window ?? NSApplication.shared.windows.first(where: {
            $0.toolbar?.identifier == "main"
        }), let content = window.contentView else { return }
        self.window = window

        let dark = options["dark"] as? Bool ?? false
        let warm = options["warm"] as? Bool ?? false
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbar?.showsBaselineSeparator = false
        window.styleMask.insert(.fullSizeContentView)

        if backdrop.superview !== content {
            backdrop.material = .sidebar
            backdrop.blendingMode = .behindWindow
            backdrop.state = .active
            backdrop.autoresizingMask = [.width, .height]
            content.addSubview(backdrop, positioned: .below, relativeTo: nil)
            tint.wantsLayer = true
            tint.autoresizingMask = [.width, .height]
            backdrop.addSubview(tint)
        }
        backdrop.frame = content.bounds
        tint.frame = backdrop.bounds
        tint.layer?.backgroundColor = (warm
            ? NSColor(red: 0.85, green: 0.68, blue: 0.43, alpha: 0.13)
            : NSColor.clear).cgColor
    }
}
