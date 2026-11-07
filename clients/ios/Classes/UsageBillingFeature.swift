//
//  UsageBillingFeature.swift
//  NewsBlur
//
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation

/// UsageBillingFeature.swift is the one switch for every way into natural language classifier billing
/// (UsageBillingView.swift) in the iOS and Mac app: the settings menu item, the Premium screen's link, and the
/// trainer's billing buttons and banner links.
@objcMembers final class UsageBillingFeature: NSObject {
    /// Off for this release. Usage billing is paid on Stripe, and outside the US the App Store's rules don't let the
    /// app send readers to an external purchase. The billing code stays in place and stays tested, so turning this
    /// back on restores every entry point. NewsBlurTests turn it on to test the billing screen itself.
    static var isEnabled = false
}
