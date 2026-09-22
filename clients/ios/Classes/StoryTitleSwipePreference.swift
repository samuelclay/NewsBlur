import SwiftUI

@objc enum StoryTitleSwipeAction: Int {
    case back, read, save, share, menu

    var value: String { ["back", "read", "save", "share", "menu"][rawValue] }
    var title: String { ["Back to feeds", "Read / unread", "Save / unsave", "Share", "Show actions"][rawValue] }
}

@objc final class StoryTitleSwipePreference: NSObject {
    static let actions: [StoryTitleSwipeAction] = [.back, .read, .save, .share, .menu]

    static func action(_ value: String?, fallback: StoryTitleSwipeAction) -> StoryTitleSwipeAction {
        actions.first { $0.value == value } ?? fallback
    }

    @objc static var rightAction: StoryTitleSwipeAction {
        action(UserDefaults.standard.string(forKey: "story_title_swipe_right"), fallback: .back)
    }

    @objc static var leftAction: StoryTitleSwipeAction {
        action(UserDefaults.standard.string(forKey: "story_title_swipe_left"), fallback: .read)
    }

    @objc static var usesFullScreenBack: Bool { actionsEnabled && rightAction == .back }

    @objc static var actionsEnabled: Bool {
        GesturePreferences.storiesEnabled
    }

    @objc static func migrateLegacyStyle() {
        guard let domainName = Bundle.main.bundleIdentifier else { return }
        migrateLegacyStyle(in: .standard, persistentDomainName: domainName)
    }

    static func migrateLegacyStyle(in defaults: UserDefaults, persistentDomainName: String) {
        // StoryTitleSwipePreference.swift distinguishes explicit choices from registered fallbacks.
        let saved = defaults.persistentDomain(forName: persistentDomainName) ?? [:]
        let arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        let legacyStyle = arguments["story_title_swipe_style"] as? String
            ?? saved["story_title_swipe_style"] as? String
        if legacyStyle == "classic" {
            for (key, value) in ["story_title_swipe_right": "save", "story_title_swipe_left": "read"] {
                if saved[key] == nil && arguments[key] == nil {
                    defaults.set(value, forKey: key)
                }
            }
        }
        defaults.removeObject(forKey: "story_title_swipe_style")
    }

    @objc(usesRowSwipeRight:canMarkRead:) static func usesRowSwipe(right: Bool, canMarkRead: Bool) -> Bool {
        guard actionsEnabled else { return false }
        let action = right ? rightAction : leftAction
        return action != .menu && !(right && action == .back) && (action != .read || canMarkRead)
    }

    @objc(iconNameForAction:isRead:score:) static func iconName(for action: StoryTitleSwipeAction, isRead: Bool, score: Int) -> String {
        switch action {
        case .back: return "barbutton_back"
        case .read: return score == -1 ? "indicator-hidden" : (score == 1 ? "indicator-focus" : "indicator-unread")
        case .save: return "saved-stories"
        case .share: return "email"
        case .menu: return "more"
        }
    }

    @objc(colorForAction:isSaved:isRead:) static func color(for action: StoryTitleSwipeAction, isSaved: Bool, isRead: Bool) -> UIColor {
        switch action {
        case .save:
            return UIColor(Color.themed(isSaved ? [0xF69E89, 0xD98973, 0xAA5B47, 0x874433]
                                               : [0xA4D97B, 0x98C572, 0x52763A, 0x3D592D]))
        case .read:
            return UIColor(Color.themed(isRead ? [0xBED49F, 0xB3C18D, 0x566447, 0x3F4C33]
                                              : [0xFFFFD2, 0xEEE6BC, 0x777148, 0x5A5534]))
        case .back, .share, .menu:
            return UIColor(Color.themed([0xC5CFDC, 0xCFC3AF, 0x545458, 0x48484A]))
        }
    }
}

// StoryTitleSwipePreference.swift gives direct story actions the same 20% trigger as MCSwipeTableViewCell.m.
struct StoryTitleSwipeView<Content: View>: View {
    @ObservedObject var cache: StoryCache
    let storyID: String
    let rightAction: StoryTitleSwipeAction
    let leftAction: StoryTitleSwipeAction
    let isSaved: Bool
    let isRead: Bool
    let canMarkRead: Bool
    let perform: (StoryTitleSwipeAction) -> Void
    let open: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var restingOffset: CGFloat = 0
    @State private var width: CGFloat = 0

    private var action: StoryTitleSwipeAction { offset > 0 ? rightAction : leftAction }
    private var menuWidth: CGFloat { min(width * 0.82, canMarkRead ? 234 : 156) }

    var body: some View {
        ZStack {
            if offset != 0 {
                if action == .menu {
                    HStack(spacing: 0) {
                        if offset < 0 { Spacer(minLength: 0) }
                        HStack(spacing: 0) {
                            if canMarkRead { menuButton(.read) }
                            menuButton(.save)
                            menuButton(.share)
                        }
                        .frame(width: menuWidth)
                        if offset > 0 { Spacer(minLength: 0) }
                    }
                } else {
                    ZStack(alignment: offset > 0 ? .leading : .trailing) {
                        Color(StoryTitleSwipePreference.color(for: action, isSaved: isSaved, isRead: isRead))
                        Image(StoryTitleSwipePreference.iconName(for: action, isRead: isRead, score: 0))
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(Color.themed([0x404040, 0x4C4435, 0xFFFFFF, 0xFFFFFF]))
                            .padding(.horizontal, 24)
                    }
                    .opacity(abs(offset) >= width * 0.2 ? 1 : 0.4)
                    .accessibilityHidden(true)
                }
            }
            content().offset(x: offset)
        }
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear { width = geometry.size.width }
                    .onChange(of: geometry.size.width) { width = $0 }
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .onChange(of: cache.openSwipeStoryID) { newValue in
            if newValue != storyID { close() }
        }
        .onChange(of: rightAction) { _ in close() }
        .onChange(of: leftAction) { _ in close() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    // StoryTitleSwipePreference.swift reserves edge navigation and the default full-screen back gesture.
                    guard value.startLocation.x >= 20, StoryTitleSwipePreference.actionsEnabled,
                          abs(value.translation.width) > abs(value.translation.height) else { return }
                    let next = restingOffset + value.translation.width
                    let selected = next > 0 ? rightAction : leftAction
                    guard !(next > 0 && selected == .back), selected != .read || canMarkRead else { return }
                    cache.openSwipeStoryID = storyID
                    offset = next
                }
                .onEnded { value in
                    guard value.startLocation.x >= 20, StoryTitleSwipePreference.actionsEnabled,
                          width > 0, abs(value.translation.width) > abs(value.translation.height) else {
                        close()
                        return
                    }
                    if action == .menu {
                        if abs(offset) > width * 0.65, canMarkRead {
                            perform(.read)
                            close()
                        } else if abs(offset) > width * 0.15 {
                            restingOffset = offset > 0 ? menuWidth : -menuWidth
                            withAnimation(.easeOut(duration: 0.2)) { offset = restingOffset }
                        } else { close() }
                    } else {
                        if abs(offset) >= width * 0.2 { perform(action) }
                        close()
                    }
                }
                // StoryTitleSwipePreference.swift prevents a canceled short swipe from also opening the story.
                .exclusively(before: TapGesture().onEnded {
                    if restingOffset != 0 { close() }
                    else { open() }
                })
        )
    }

    private func menuButton(_ action: StoryTitleSwipeAction) -> some View {
        Button {
            perform(action)
            close()
        } label: {
            VStack(spacing: 6) {
                Image(StoryTitleSwipePreference.iconName(for: action, isRead: isRead, score: 0))
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text(action == .read ? (isRead ? "Mark Unread" : "Mark Read") :
                     action == .save ? (isSaved ? "Unsave" : "Save") : "Share")
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(Color.themed([0x404040, 0x4C4435, 0xFFFFFF, 0xFFFFFF]))
            .background(Color(StoryTitleSwipePreference.color(for: action, isSaved: isSaved, isRead: isRead)))
        }
        .buttonStyle(.plain)
    }

    private func close() {
        restingOffset = 0
        withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
    }
}
