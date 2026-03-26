//
//  StoryAutoCollapseDecision.swift
//  NewsBlur
//
//  Created by Codex on 2026-03-12.
//

import CoreGraphics
import Foundation

public enum StoryAutoCollapseBehavior: String {
    case auto
    case tile
    case displace
    case overlay
}

@objc public enum StorySplitPreferredBehavior: Int {
    case tile
    case displace
    case overlay
}

@objc public enum StorySplitPreferredDisplayMode: Int {
    case secondaryOnly
    case oneBesideSecondary
    case oneOverSecondary
    case twoBesideSecondary
    case twoOverSecondary
    case twoDisplaceSecondary
}

@objc public enum FullscreenSidebarPresentation: Int {
    case fullscreen
    case storyTitles
    case feeds
}

@objcMembers public final class StorySplitBehaviorDecision: NSObject {
    public class func preferredBehavior(
        for behaviorValue: String?,
        width: CGFloat,
        height: CGFloat,
        isMac: Bool
    ) -> StorySplitPreferredBehavior {
        switch resolvedBehavior(for: behaviorValue, width: width, height: height, isMac: isMac) {
        case .tile:
            return .tile
        case .overlay:
            return .overlay
        default:
            return .displace
        }
    }

    public class func preferredDisplayMode(
        for behaviorValue: String?,
        width: CGFloat,
        height: CGFloat,
        isMac: Bool
    ) -> StorySplitPreferredDisplayMode {
        usesTiledSidebarLayout(for: behaviorValue, width: width, height: height, isMac: isMac)
            ? .twoBesideSecondary
            : .secondaryOnly
    }

    public class func usesTiledSidebarLayout(
        for behaviorValue: String?,
        width: CGFloat,
        height: CGFloat,
        isMac: Bool
    ) -> Bool {
        preferredBehavior(for: behaviorValue, width: width, height: height, isMac: isMac) == .tile
    }

    public class func sidebarDisplayMode(
        forTiledLayout isTiledLayout: Bool,
        currentDisplayMode: StorySplitPreferredDisplayMode
    ) -> StorySplitPreferredDisplayMode {
        if isTiledLayout {
            return currentDisplayMode == .secondaryOnly ? .twoBesideSecondary : .secondaryOnly
        }

        return currentDisplayMode == .secondaryOnly ? .oneOverSecondary : .secondaryOnly
    }

    public class func shouldResetTemporarySidebarReveal(
        for behaviorValue: String?,
        width: CGFloat,
        height: CGFloat,
        isMac: Bool
    ) -> Bool {
        !usesTiledSidebarLayout(for: behaviorValue, width: width, height: height, isMac: isMac)
    }

    private class func resolvedBehavior(
        for behaviorValue: String?,
        width: CGFloat,
        height: CGFloat,
        isMac: Bool
    ) -> StoryAutoCollapseBehavior {
        let requestedBehavior = StoryAutoCollapseBehavior(
            rawValue: behaviorValue ?? StoryAutoCollapseBehavior.auto.rawValue
        ) ?? .auto

        guard requestedBehavior == .auto else {
            return requestedBehavior
        }

        if isMac && width < 1100 {
            return .overlay
        } else if width > height {
            return .tile
        } else {
            return .displace
        }
    }
}

@objcMembers public final class FullscreenSidebarPresentationDecision: NSObject {
    public class func presentation(
        for displayMode: StorySplitPreferredDisplayMode
    ) -> FullscreenSidebarPresentation {
        switch displayMode {
        case .secondaryOnly:
            return .fullscreen
        case .oneBesideSecondary, .oneOverSecondary:
            return .storyTitles
        case .twoBesideSecondary, .twoOverSecondary, .twoDisplaceSecondary:
            return .feeds
        }
    }

    public class func nativeDisplayMode(
        for presentation: FullscreenSidebarPresentation
    ) -> StorySplitPreferredDisplayMode {
        switch presentation {
        case .fullscreen:
            return .secondaryOnly
        case .storyTitles:
            return .oneOverSecondary
        case .feeds:
            return .twoOverSecondary
        }
    }

    public class func needsNativeDisplayModeUpdate(
        for presentation: FullscreenSidebarPresentation,
        currentDisplayMode: StorySplitPreferredDisplayMode
    ) -> Bool {
        self.presentation(for: currentDisplayMode) != presentation
    }

    public class func presentationAfterSidebarTap(
        _ currentPresentation: FullscreenSidebarPresentation
    ) -> FullscreenSidebarPresentation {
        switch currentPresentation {
        case .fullscreen:
            return .storyTitles
        case .storyTitles:
            return .feeds
        case .feeds:
            return .storyTitles
        }
    }

    public class func presentationAfterKeyboardHide(
        _ currentPresentation: FullscreenSidebarPresentation
    ) -> FullscreenSidebarPresentation {
        let _ = currentPresentation
        return .fullscreen
    }

    public class func presentationAfterKeyboardReveal(
        _ currentPresentation: FullscreenSidebarPresentation
    ) -> FullscreenSidebarPresentation {
        let _ = currentPresentation
        return .storyTitles
    }

    public class func presentationAfterStorySelection(
        _ currentPresentation: FullscreenSidebarPresentation
    ) -> FullscreenSidebarPresentation {
        let _ = currentPresentation
        return .fullscreen
    }

    public class func presentationAfterFeedSelection(
        _ currentPresentation: FullscreenSidebarPresentation,
        usesNativeFullscreenSidebar: Bool
    ) -> FullscreenSidebarPresentation {
        let _ = currentPresentation
        return usesNativeFullscreenSidebar ? .fullscreen : .storyTitles
    }

    public class func presentationAfterFullscreenButtonTap(
        _ currentPresentation: FullscreenSidebarPresentation
    ) -> FullscreenSidebarPresentation {
        let _ = currentPresentation
        return .fullscreen
    }

    public class func presentationAfterLeadingEdgeReveal(
        _ currentPresentation: FullscreenSidebarPresentation
    ) -> FullscreenSidebarPresentation {
        presentationAfterKeyboardReveal(currentPresentation)
    }
}

@objcMembers public final class StorySidebarRevealGestureDecision: NSObject {
    public class func shouldBeginLeadingEdgeStoryTitlesReveal(
        usesOverlay: Bool,
        presentation: FullscreenSidebarPresentation,
        storyTitlesOnLeft: Bool,
        isPhoneOrCompact: Bool
    ) -> Bool {
        guard usesOverlay, storyTitlesOnLeft, !isPhoneOrCompact else {
            return false
        }

        return presentation == .fullscreen
    }
}

@objcMembers public final class FeedSidebarRevealGestureDecision: NSObject {
    public class func shouldBeginLeadingEdgeFeedsReveal(
        presentation: FullscreenSidebarPresentation,
        isPhoneOrCompact: Bool
    ) -> Bool {
        guard !isPhoneOrCompact else {
            return false
        }

        return presentation != .fullscreen
    }
}

@objcMembers public final class StoryTitlesHeaderButtonDecision: NSObject {
    public class func showsFullscreenButton(
        for presentation: FullscreenSidebarPresentation,
        storyTitlesOnLeft: Bool,
        usesNativeFullscreenSidebar: Bool,
        isPhoneOrCompact: Bool,
        width: CGFloat,
        height: CGFloat
    ) -> Bool {
        let _ = width

        guard storyTitlesOnLeft, !isPhoneOrCompact, presentation != .fullscreen else {
            return false
        }

        if usesNativeFullscreenSidebar {
            return true
        }

        return height >= width
    }
}

@objcMembers public final class StoryInitialSelectionDecision: NSObject {
    public class func shouldAutomaticallyOpenFirstStory(
        feedOpeningPreference: String?,
        isPhone: Bool,
        isDashboard: Bool,
        usesOverlay: Bool
    ) -> Bool {
        guard !isDashboard else {
            return false
        }

        if usesOverlay && !isPhone {
            return true
        }

        if let feedOpeningPreference {
            return feedOpeningPreference == "story"
        }

        return !isPhone
    }
}

@objcMembers public final class StorySelectionAnimationDecision: NSObject {
    public class func shouldAnimateSelection(
        isPhoneOrCompact: Bool,
        usesNativeFullscreenSidebar: Bool,
        presentation: FullscreenSidebarPresentation
    ) -> Bool {
        guard !isPhoneOrCompact else {
            return true
        }

        let _ = usesNativeFullscreenSidebar
        return presentation == .fullscreen
    }
}

@objcMembers public final class StorySelectionNavigationDecision: NSObject {
    public class func shouldUseExplicitLocation(
        isPhoneOrCompact: Bool,
        usesNativeFullscreenSidebar: Bool,
        presentation: FullscreenSidebarPresentation
    ) -> Bool {
        guard !isPhoneOrCompact else {
            return false
        }

        let _ = usesNativeFullscreenSidebar
        return presentation != .fullscreen
    }
}

@objcMembers public final class StoryPageChangeDecision: NSObject {
    public class func shouldImmediatelyRealignPages(
        currentPageIndex: Int,
        targetPageIndex: Int,
        animated: Bool
    ) -> Bool {
        !animated && currentPageIndex != targetPageIndex
    }
}

@objcMembers public final class StorySelectionSidebarRefreshDecision: NSObject {
    public class func shouldRefreshStoryTitlesSidebar(
        isPhoneOrCompact: Bool,
        usesNativeFullscreenSidebar: Bool,
        presentation: FullscreenSidebarPresentation
    ) -> Bool {
        guard !isPhoneOrCompact else {
            return true
        }

        let _ = usesNativeFullscreenSidebar
        return presentation == .fullscreen
    }
}

@objcMembers public final class StoryRefreshSelectionDecision: NSObject {
    public class func targetLocation(
        activeStoryLocation: Int,
        storyLocationsCount: Int
    ) -> Int {
        guard storyLocationsCount > 0 else {
            return -1
        }

        if activeStoryLocation >= 0 {
            return activeStoryLocation
        }

        return 0
    }
}

@objcMembers public final class StoryPageRefreshDecision: NSObject {
    public class func shouldBeginRefresh(isRefreshInProgress: Bool) -> Bool {
        !isRefreshInProgress
    }
}

public struct StoryAutoCollapseDecision {
    public static func shouldCollapse(
        isPhone: Bool,
        isCompact: Bool,
        hasActiveStory: Bool,
        behavior: StoryAutoCollapseBehavior,
        size: CGSize,
        isMac: Bool
    ) -> Bool {
        guard !isPhone, !isCompact, hasActiveStory else {
            return false
        }

        switch behavior {
        case .tile:
            return false
        case .auto, .displace:
            return false
        case .overlay:
            return true
        }
    }

    public static func resolvedShouldCollapse(
        baseShouldCollapse: Bool,
        fullscreenSidebarPresentation: FullscreenSidebarPresentation,
        usesNativeFullscreenSidebar: Bool,
        isTemporaryFullScreen: Bool
    ) -> Bool {
        if usesNativeFullscreenSidebar || isTemporaryFullScreen {
            return true
        }

        return fullscreenSidebarPresentation == .fullscreen ? baseShouldCollapse : false
    }
}
