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

@objc public enum DailyBriefingPresentationState: Int {
    case loading
    case settings
    case empty
    case stories
}

@objc public enum FeedSelectionPresentation: Int {
    case loadFeedDetail
    case showFeedsListThenLoadFeedDetail
    case wait
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

@objcMembers public final class FeedSelectionPresentationDecision: NSObject {
    public class func presentation(
        isPhone: Bool,
        userInterfaceIdiomPhone: Bool
    ) -> FeedSelectionPresentation {
        if !isPhone {
            return .loadFeedDetail
        }

        if userInterfaceIdiomPhone {
            return .showFeedsListThenLoadFeedDetail
        }

        return .wait
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

        // The feed detail controller only receives this edge gesture while the
        // story titles pane is actually on screen, so cached presentation
        // state should not block the initial reveal gesture.
        let _ = presentation
        return true
    }
}

@objcMembers public final class DailyBriefingPresentationDecision: NSObject {
    public class func presentationState(
        hasLoadedPreferences: Bool,
        preferencesEnabled: Bool,
        isLoadingInitialData: Bool,
        hasStories: Bool
    ) -> DailyBriefingPresentationState {
        if !hasLoadedPreferences || (isLoadingInitialData && !hasStories) {
            return .loading
        }

        if !preferencesEnabled {
            return .settings
        }

        return hasStories ? .stories : .empty
    }

    public class func shouldFetchStories(
        page: Int,
        hasLoadedPreferences: Bool,
        preferencesEnabled: Bool
    ) -> Bool {
        if page <= 1 {
            return true
        }

        return hasLoadedPreferences && preferencesEnabled
    }
}

@objcMembers public final class DailyBriefingLinkDecision: NSObject {
    @objc(storyHashForURL:isDailyBriefing:)
    public class func storyHash(for url: NSURL?, isDailyBriefing: Bool) -> String? {
        guard isDailyBriefing, let url = url as URL? else {
            return nil
        }

        guard url.path.contains("/briefing") else {
            return nil
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        return components.queryItems?.first(where: { $0.name == "story" })?.value
    }
}

@objcMembers public final class DailyBriefingPaginationDecision: NSObject {
    public class func shouldPrefetchNextPage(
        remainingOffset: CGFloat,
        isDragging: Bool,
        isDecelerating: Bool
    ) -> Bool {
        guard remainingOffset <= 500 else {
            return false
        }

        return isDragging || isDecelerating
    }
}

@objcMembers public final class FetchingBannerAccessoryLayoutDecision: NSObject {
    @objc(fixedAccessoryDimensionForOffline:)
    public class func fixedAccessoryDimension(isOffline: Bool) -> CGFloat {
        isOffline ? 16 : 0
    }

    @objc(revealsAccessoryAfterBannerExpansionForOffline:)
    public class func revealsAccessoryAfterBannerExpansion(isOffline: Bool) -> Bool {
        !isOffline
    }
}

public struct DailyBriefingListGroup: Equatable {
    public let id: String
    public let title: String
    public let dateText: String
    public let storyHashes: [String]

    public init(id: String, title: String, dateText: String, storyHashes: [String]) {
        self.id = id
        self.title = title
        self.dateText = dateText
        self.storyHashes = storyHashes
    }
}

public struct DailyBriefingListSection: Equatable {
    public let id: String
    public let title: String
    public let dateText: String
    public let rowLocations: [Int]
    public let isCollapsed: Bool
    public let isLoadingSection: Bool

    public init(
        id: String,
        title: String,
        dateText: String,
        rowLocations: [Int],
        isCollapsed: Bool,
        isLoadingSection: Bool
    ) {
        self.id = id
        self.title = title
        self.dateText = dateText
        self.rowLocations = rowLocations
        self.isCollapsed = isCollapsed
        self.isLoadingSection = isLoadingSection
    }
}

public enum DailyBriefingSectionLayoutDecision {
    public static func defaultCollapsedGroupIDs(for groupIDs: [String]) -> Set<String> {
        Set(groupIDs.dropFirst())
    }

    public static func sections(
        groups: [DailyBriefingListGroup],
        storyLocationsByHash: [String: Int],
        collapsedGroupIDs: Set<String>,
        includesLoadingSection: Bool
    ) -> [DailyBriefingListSection] {
        var sections = groups.map { group in
            DailyBriefingListSection(
                id: group.id,
                title: group.title,
                dateText: group.dateText,
                rowLocations: group.storyHashes.compactMap { storyLocationsByHash[$0] },
                isCollapsed: collapsedGroupIDs.contains(group.id),
                isLoadingSection: false
            )
        }

        if includesLoadingSection {
            sections.append(
                DailyBriefingListSection(
                    id: "__loading__",
                    title: "",
                    dateText: "",
                    rowLocations: [],
                    isCollapsed: false,
                    isLoadingSection: true
                )
            )
        }

        return sections
    }
}

@objcMembers public final class StoryRowLookupDecision: NSObject {
    public class func storyIndex(
        for location: Int,
        isDailyBriefing: Bool,
        allStoriesCount: Int,
        visibleStoryLocations: [NSNumber]
    ) -> NSNumber? {
        guard location >= 0 else {
            return nil
        }

        if isDailyBriefing {
            guard location < allStoriesCount else {
                return nil
            }

            return NSNumber(value: location)
        }

        guard visibleStoryLocations.indices.contains(location) else {
            return nil
        }

        return visibleStoryLocations[location]
    }
}

@objcMembers public final class FeedRowLoadingDecision: NSObject {
    public class func shouldShowLoadingCell(
        isLegacyTable: Bool,
        isDailyBriefing: Bool,
        hasRowDescriptor: Bool,
        storyLocation: Int,
        storyCount: Int
    ) -> Bool {
        if isLegacyTable && !isDailyBriefing && !hasRowDescriptor {
            return true
        }

        if !isLegacyTable && storyLocation >= storyCount {
            return true
        }

        return false
    }
}

@objcMembers public final class FeedDetailReturnFrameDecision: NSObject {
    public class func correctedFrame(
        _ frame: CGRect,
        containerBounds: CGRect,
        navigationBarMinY: CGFloat,
        isPhoneOrCompact: Bool
    ) -> CGRect {
        guard isPhoneOrCompact, containerBounds.width > 0 else {
            return frame
        }

        var corrected = frame

        if abs(corrected.minX - containerBounds.minX) > 0.5 ||
            abs(corrected.width - containerBounds.width) > 0.5 {
            corrected.origin.x = containerBounds.minX
            corrected.size.width = containerBounds.width
        }

        if corrected.minY == 0, navigationBarMinY < 0 {
            corrected.origin.y = -navigationBarMinY
        }

        return corrected
    }
}

@objcMembers public final class StoryDetailFullscreenButtonDecision: NSObject {
    public class func showsTemporaryFullscreenButton(
        storyDetailVisible: Bool,
        isPhoneOrCompact: Bool,
        isMac: Bool,
        isUserOverlayMode: Bool,
        isTemporaryFullScreen: Bool
    ) -> Bool {
        guard storyDetailVisible, !isPhoneOrCompact, !isMac else {
            return false
        }

        return isTemporaryFullScreen || !isUserOverlayMode
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

@objcMembers public final class StoryClusterDisplayDecision: NSObject {
    @objc(isClusterMarkReadEnabledWithUserProfile:)
    public class func isClusterMarkReadEnabled(userProfile: NSDictionary?) -> Bool {
        guard let preferences = preferencesDictionary(from: userProfile) else {
            return false
        }

        guard let value = preferences["cluster_mark_read"] else {
            return false
        }

        return boolValue(from: value)
    }

    @objc(effectiveClusterReadStatusWithIsClusterRead:parentRead:clusterMarkReadEnabled:isPremiumArchive:)
    public class func effectiveClusterReadStatus(
        isClusterRead: Bool,
        parentRead: Bool,
        clusterMarkReadEnabled: Bool,
        isPremiumArchive: Bool
    ) -> Bool {
        guard isPremiumArchive, clusterMarkReadEnabled, parentRead else {
            return isClusterRead
        }

        return true
    }

    @objc(updatedClusterStories:parentRead:clusterMarkReadEnabled:isPremiumArchive:)
    public class func updatedClusterStories(
        _ clusterStories: NSArray?,
        parentRead: Bool,
        clusterMarkReadEnabled: Bool,
        isPremiumArchive: Bool
    ) -> NSArray {
        guard
            let clusterStories,
            effectiveClusterReadStatus(
                isClusterRead: false,
                parentRead: parentRead,
                clusterMarkReadEnabled: clusterMarkReadEnabled,
                isPremiumArchive: isPremiumArchive
            )
        else {
            return clusterStories ?? []
        }

        return clusterStories.compactMap { item in
            guard let story = item as? NSDictionary else {
                return item
            }

            let updatedStory = NSMutableDictionary(dictionary: story)
            updatedStory["read_status"] = 1
            return updatedStory.copy()
        } as NSArray
    }

    @objc(indicatorImageNameForScore:)
    public class func indicatorImageName(forScore score: Int) -> String {
        if score < 0 {
            return "indicator-hidden"
        } else if score > 0 {
            return "indicator-focus"
        } else {
            return "indicator-unread"
        }
    }

    @objc(visibleClusterStories:subscribedFeedIds:isPremiumArchive:)
    public class func visibleClusterStories(
        _ clusterStories: NSArray?,
        subscribedFeedIds: NSSet?,
        isPremiumArchive: Bool
    ) -> NSArray {
        guard
            let clusterStories = clusterStories as? [NSDictionary],
            let subscribedFeedIds
        else {
            return []
        }

        let allowedFeedIds = Set(subscribedFeedIds.compactMap { stringValue(from: $0) })
        let visibleClusterStories = clusterStories
            .filter { clusterStory in
                guard let feedId = stringValue(from: clusterStory["story_feed_id"]) else {
                    return false
                }

                return allowedFeedIds.contains(feedId)
            }
            .sorted { lhs, rhs in
                timestamp(from: lhs) > timestamp(from: rhs)
            }

        guard !isPremiumArchive, visibleClusterStories.count > 1 else {
            return visibleClusterStories as NSArray
        }

        return Array(visibleClusterStories.prefix(1)) as NSArray
    }

    @objc(canSafelyReloadClusterRowsWithCurrentTableRowCount:visibleStoryRowCount:targetRows:)
    public class func canSafelyReloadClusterRows(
        currentTableRowCount: Int,
        visibleStoryRowCount: Int,
        targetRows: NSArray?
    ) -> Bool {
        guard let targetRows = targetRows as? [NSNumber], !targetRows.isEmpty else {
            return false
        }

        let expectedTableRowCount = visibleStoryRowCount + 1
        guard currentTableRowCount == expectedTableRowCount else {
            return false
        }

        return targetRows.allSatisfy { targetRow in
            let row = targetRow.intValue
            return row >= 0 && row < currentTableRowCount
        }
    }

    private class func preferencesDictionary(from userProfile: NSDictionary?) -> NSDictionary? {
        guard let preferencesValue = userProfile?["preferences"] else {
            return nil
        }

        if let preferences = preferencesValue as? NSDictionary {
            return preferences
        }

        guard
            let preferencesJSON = preferencesValue as? String,
            let data = preferencesJSON.data(using: .utf8),
            let preferences = try? JSONSerialization.jsonObject(with: data) as? NSDictionary
        else {
            return nil
        }

        return preferences
    }

    private class func boolValue(from value: Any) -> Bool {
        if let boolValue = value as? Bool {
            return boolValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }

        if let stringValue = value as? String {
            return NSString(string: stringValue).boolValue
        }

        return false
    }

    private class func stringValue(from value: Any?) -> String? {
        guard let value else {
            return nil
        }

        if let stringValue = value as? String, !stringValue.isEmpty {
            return stringValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.stringValue
        }

        return nil
    }

    private class func timestamp(from clusterStory: NSDictionary) -> Int {
        if let timestamp = clusterStory["story_timestamp"] as? NSNumber {
            return timestamp.intValue
        }

        if let timestamp = clusterStory["story_timestamp"] as? NSString {
            return timestamp.integerValue
        }

        return 0
    }
}

@objcMembers public final class TryFeedPresentationDecision: NSObject {
    @objc(isTryFeedPreviewWithFeed:)
    public class func isTryFeedPreview(feed: NSDictionary?) -> Bool {
        guard let value = feed?["temp"] else {
            return false
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }

        if let stringValue = value as? String {
            return NSString(string: stringValue).boolValue
        }

        return false
    }
}

@objcMembers public final class StoryPageRefreshDecision: NSObject {
    public class func shouldBeginRefresh(isRefreshInProgress: Bool) -> Bool {
        !isRefreshInProgress
    }
}

@objcMembers public final class DailyBriefingFolderPlacementDecision: NSObject {
    @objc(orderedFoldersFromFolderNames:isEnabled:)
    public class func orderedFolders(folderNames: [String], isEnabled: Bool) -> [String] {
        let foldersWithoutBriefing = folderNames.filter { $0 != "daily_briefing" }
        let _ = isEnabled

        var orderedFolders = foldersWithoutBriefing
        let insertionIndex = orderedFolders.firstIndex(of: "infrequent")
            ?? orderedFolders.firstIndex(of: "everything")
            ?? 0
        orderedFolders.insert("daily_briefing", at: insertionIndex)

        return orderedFolders
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
