//
//  WidgetBarView.swift
//  Widget Extension
//
//  Created by David Sinclair on 2019-12-23.
//  Copyright © 2021 NewsBlur. All rights reserved.
//

import SwiftUI

/// Color bars at the left of the feed cell.
struct WidgetBarView: View {
    /// The left bar color.
    var leftColor: Color?
    
    /// The right bar color.
    var rightColor: Color?
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 2, y: 0))
                path.addLine(to: CGPoint(x: 2, y: geometry.size.height))
            }
            .stroke(lineWidth: 4)
            .foregroundColor(leftColor)
            
            Path { path in
                path.move(to: CGPoint(x: 6, y: 0))
                path.addLine(to: CGPoint(x: 6, y: geometry.size.height))
            }
            .stroke(lineWidth: 4)
            .foregroundColor(rightColor)
        }
    }
    
//    override func draw(_ rect: CGRect) {
//        guard let leftColor, let rightColor = rightColor, let context = UIGraphicsGetCurrentContext() else {
//            return
//        }
//
//        let height = bounds.height
//
//        context.setStrokeColor(leftColor.cgColor)
//        context.setLineWidth(4)
//        context.beginPath()
//        context.move(to: CGPoint(x: 2, y: 0))
//        context.addLine(to: CGPoint(x: 2, y: height))
//        context.strokePath()
//
//        context.setStrokeColor(rightColor.cgColor)
//        context.beginPath()
//        context.move(to: CGPoint(x: 6, y: 0))
//        context.addLine(to: CGPoint(x: 6, y: height))
//        context.strokePath()
//
//        let isDark = traitCollection.userInterfaceStyle == .dark
//
//        context.setStrokeColor(isDark ? UIColor.black.cgColor : UIColor.white.cgColor)
//        context.setLineWidth(1)
//        context.beginPath()
//        context.move(to: CGPoint(x: 0, y: 0.5))
//        context.addLine(to: CGPoint(x: bounds.width, y: 0.5))
//        context.strokePath()
//    }
}

struct WidgetBarView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetBarView()
    }
}
