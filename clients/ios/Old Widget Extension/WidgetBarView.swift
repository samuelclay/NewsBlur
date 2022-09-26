//
//  WidgetBarView.swift
//  Widget Extension
//
//  Created by David Sinclair on 2019-12-23.
//  Copyright © 2019 NewsBlur. All rights reserved.
//

import UIKit

/// Color bars at the left of the feed cell.
class BarView: UIView {
    /// The left bar color.
    var leftColor: UIColor?
    
    /// The right bar color.
    var rightColor: UIColor?
    
    override func draw(_ rect: CGRect) {
        guard let leftColor, let rightColor = rightColor, let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        let height = bounds.height
        
        context.setStrokeColor(leftColor.cgColor)
        context.setLineWidth(4)
        context.beginPath()
        context.move(to: CGPoint(x: 2, y: 0))
        context.addLine(to: CGPoint(x: 2, y: height))
        context.strokePath()
        
        context.setStrokeColor(rightColor.cgColor)
        context.beginPath()
        context.move(to: CGPoint(x: 6, y: 0))
        context.addLine(to: CGPoint(x: 6, y: height))
        context.strokePath()
        
        let isDark = traitCollection.userInterfaceStyle == .dark
        
        context.setStrokeColor(isDark ? UIColor.black.cgColor : UIColor.white.cgColor)
        context.setLineWidth(1)
        context.beginPath()
        context.move(to: CGPoint(x: 0, y: 0.5))
        context.addLine(to: CGPoint(x: bounds.width, y: 0.5))
        context.strokePath()
    }
}
