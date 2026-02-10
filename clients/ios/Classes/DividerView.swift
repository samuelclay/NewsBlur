//
//  DividerView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2026-01-27.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import UIKit
#if targetEnvironment(macCatalyst)
import AppKit
#endif

/// A view that shows a split-divider pointer when hovered, with a grab handle for touch dragging.
class DividerView: UIView, UIPointerInteractionDelegate {

#if targetEnvironment(macCatalyst)
    private var cursorPushed = false
#endif

    /// The amount to expand the touch area on each side of the divider for easier finger targeting.
    private let touchExpansion: CGFloat = 20

    /// The grab handle pill view centered on the divider.
    private let grabHandle = UIView()

    /// Whether the grab handle is highlighted during a drag.
    var isHighlighted = false {
        didSet {
            guard isHighlighted != oldValue else { return }
            UIView.animate(withDuration: 0.15) {
                self.grabHandle.alpha = self.isHighlighted ? 1.0 : 0.5
                self.grabHandle.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 1.5, y: 1.5)
                    : .identity
            }
        }
    }

    private var dividerLineColor: UIColor {
        return ThemeManager.color(fromRGB: [0xE9E8E4, 0xD4C8B8, 0x333333, 0x222222])
    }

    private var grabHandleColor: UIColor {
        return ThemeManager.color(fromRGB: [0xC8C7C3, 0xBEB2A2, 0x666666, 0x555555])
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isUserInteractionEnabled = true
        setupGrabHandle()
        updateTheme()

#if targetEnvironment(macCatalyst)
        // Use AppKit cursors on Mac for the exact system feel.
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        addGestureRecognizer(hover)
#else
        addInteraction(UIPointerInteraction(delegate: self))
#endif
    }

    private func setupGrabHandle() {
        grabHandle.alpha = 0.5
        grabHandle.isUserInteractionEnabled = false
        addSubview(grabHandle)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let isVerticalDivider = bounds.height >= bounds.width
        let handleLength: CGFloat = 36
        let handleThickness: CGFloat = 4

        if isVerticalDivider {
            grabHandle.frame = CGRect(
                x: (bounds.width - handleThickness) / 2,
                y: (bounds.height - handleLength) / 2,
                width: handleThickness,
                height: handleLength
            )
        } else {
            grabHandle.frame = CGRect(
                x: (bounds.width - handleLength) / 2,
                y: (bounds.height - handleThickness) / 2,
                width: handleLength,
                height: handleThickness
            )
        }
        grabHandle.layer.cornerRadius = handleThickness / 2
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let isVerticalDivider = bounds.height >= bounds.width

        let path = UIBezierPath()
        path.lineWidth = 1.0

        if isVerticalDivider {
            let x = 0.5
            path.move(to: CGPoint(x: x, y: bounds.minY))
            path.addLine(to: CGPoint(x: x, y: bounds.maxY))
        } else {
            let y = 0.5
            path.move(to: CGPoint(x: bounds.minX, y: y))
            path.addLine(to: CGPoint(x: bounds.maxX, y: y))
        }

        dividerLineColor.setStroke()
        path.stroke()
    }

    @objc func updateTheme() {
        let lineColor = dividerLineColor
        for view in subviews where view !== grabHandle {
            view.backgroundColor = lineColor
        }
        grabHandle.backgroundColor = grabHandleColor
        setNeedsDisplay()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateTheme()
    }

    // MARK: - Expanded touch area

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Don't expand hit area when divider is hidden off-screen.
        if let superview, !superview.bounds.intersects(frame) {
            return super.point(inside: point, with: event)
        }

        let isVerticalDivider = bounds.height >= bounds.width
        let expanded: CGRect
        if isVerticalDivider {
            expanded = bounds.insetBy(dx: -touchExpansion, dy: 0)
        } else {
            expanded = bounds.insetBy(dx: 0, dy: -touchExpansion)
        }
        return expanded.contains(point)
    }

    // MARK: - iPadOS pointer

#if !targetEnvironment(macCatalyst)

    func pointerInteraction(_ interaction: UIPointerInteraction,
                            regionFor request: UIPointerRegionRequest,
                            defaultRegion: UIPointerRegion) -> UIPointerRegion? {
        guard bounds.contains(request.location) else { return nil }

        let r: CGFloat = 0.5
        let rect = CGRect(x: request.location.x - r,
                          y: request.location.y - r,
                          width: r * 2,
                          height: r * 2)

        return UIPointerRegion(rect: rect, identifier: "divider" as NSString)
    }

    func pointerInteraction(_ interaction: UIPointerInteraction,
                            styleFor region: UIPointerRegion) -> UIPointerStyle? {
        let isVerticalDivider = bounds.height >= bounds.width

        let barThickness: CGFloat = 5
        let barLength: CGFloat = 32
        let cornerRadius: CGFloat = barThickness / 2

        let barRect: CGRect
        if isVerticalDivider {
            barRect = CGRect(x: 0,
                             y: 0,
                             width: barThickness,
                             height: barLength)
        } else {
            barRect = CGRect(x: 0,
                             y: 0,
                             width: barLength,
                             height: barThickness)
        }

        let shape = UIPointerShape.roundedRect(barRect, radius: cornerRadius)
        let axes: UIAxis = isVerticalDivider ? .vertical : .horizontal

        let style = UIPointerStyle(shape: shape, constrainedAxes: axes)

        if #available(iOS 15.0, *) {
            style.accessories = isVerticalDivider
            ? [.arrow(.left), .arrow(.right)]
            : [.arrow(.top), .arrow(.bottom)]
        }

        return style
    }

#endif

    // MARK: - Mac Catalyst cursor

#if targetEnvironment(macCatalyst)

    @objc private func handleHover(_ gr: UIHoverGestureRecognizer) {
        let isVerticalDivider = bounds.height >= bounds.width

        switch gr.state {
            case .began, .changed:
                if !cursorPushed {
                    cursorPushed = true
                    // Push so we can reliably restore on exit.
                    if #available(macCatalyst 18.0, *) {
                        (isVerticalDivider ? NSCursor.columnResize : NSCursor.rowResize).push()
                    } else {
                        NSCursor.crosshair.push()
                    }
                }
            default:
                if cursorPushed {
                    cursorPushed = false
                    NSCursor.pop()
                }
        }
    }

    deinit {
        if cursorPushed { NSCursor.pop() }
    }

#endif
}
