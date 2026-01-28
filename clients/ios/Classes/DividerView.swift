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

/// A view that shows a split-divider pointer when hovered.
class DividerView: UIView, UIPointerInteractionDelegate {
    
#if targetEnvironment(macCatalyst)
    private var cursorPushed = false
#endif
    
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
        
#if targetEnvironment(macCatalyst)
        // Use AppKit cursors on Mac for the exact system feel.
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        addGestureRecognizer(hover)
#else
        addInteraction(UIPointerInteraction(delegate: self))
#endif
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
        
        UIColor.systemGray.setStroke()
        path.stroke()
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
