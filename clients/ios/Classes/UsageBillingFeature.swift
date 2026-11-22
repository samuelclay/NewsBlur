//
//  UsageBillingFeature.swift
//  NewsBlur
//
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation

/// UsageBillingFeature.swift is the one switch for every way the iOS and Mac app opens usage billing on Stripe: the
/// AI credits screen's Set up and Manage buttons, its monthly limit field and invoice links (AICreditsView.swift),
/// and the trainer's Keep filters running, Turn on usage billing, Manage billing and Change limit buttons
/// (AIClassifiers.swift AICreditsNotice).
@objcMembers final class UsageBillingFeature: NSObject {
    /// Off for this release. Usage billing is paid on Stripe, and outside the US the App Store's rules don't let the
    /// app send readers to an external purchase. With it off, readers still see their AI credits, the forecast, why
    /// filters are paused and, when they turned usage billing on elsewhere, what it has cost and their limit, but
    /// nothing that opens Stripe or points them anywhere to pay. The billing code stays in place and stays tested, so
    /// turning this back on restores every entry point. NewsBlurTests turn it on to test the billing paths themselves.
    static var isEnabled = false
}
