//
//  StoryToolbarScrollHandler.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2026-02-24.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import UIKit

/// Pure state machine that tracks toolbar offset from scroll deltas.
/// toolbarOffset: 0 = fully visible, toolbarHeight = fully hidden.
@objcMembers
class StoryToolbarScrollHandler: NSObject {

    var toolbarHeight: CGFloat = 44.0
    var showThreshold: CGFloat = 50.0
    private(set) var toolbarOffset: CGFloat = 0.0
    private var upwardAccumulator: CGFloat = 0.0

    func handleScrollDelta(_ deltaY: CGFloat, atTop: Bool, atBottom: Bool, nearTop: Bool) {
        if atTop {
            toolbarOffset = 0
            upwardAccumulator = 0
            return
        }

        if deltaY > 0 {
            // Scrolling down — hide toolbar, reset upward accumulator
            upwardAccumulator = 0
            toolbarOffset = max(0, min(toolbarHeight, toolbarOffset + deltaY))
        } else if deltaY < 0 {
            // Near top of content — show toolbar immediately, no threshold
            if nearTop {
                toolbarOffset = max(0, min(toolbarHeight, toolbarOffset + deltaY))
            } else {
                // Scrolling up — accumulate before showing toolbar
                upwardAccumulator += abs(deltaY)
                if upwardAccumulator > showThreshold {
                    toolbarOffset = max(0, min(toolbarHeight, toolbarOffset + deltaY))
                }
            }
        }
    }

    func snapTarget() -> CGFloat {
        toolbarOffset > toolbarHeight / 2 ? toolbarHeight : 0
    }

    func reset() {
        toolbarOffset = 0
        upwardAccumulator = 0
    }

    func setOffset(_ offset: CGFloat) {
        toolbarOffset = max(0, min(toolbarHeight, offset))
    }
}
