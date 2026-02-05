//
//  TrainerView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-04-02.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

private final class TrainerThemeObserver: ObservableObject {
    @Published var themeVersion: Int = 0
    private var observers: [NSObjectProtocol] = []

    init() {
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.themeVersion += 1
        }
        observers.append(observer)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

private struct TrainerColors {
    static var isDark: Bool {
        ThemeManager.shared?.isDarkTheme ?? false
    }

    static var background: Color {
        themedColor(light: 0xF0F2ED, dark: 0x1C1C1E)
    }

    static var cardBackground: Color {
        themedColor(light: 0xFFFFFF, dark: 0x2C2C2E)
    }

    static var secondaryBackground: Color {
        themedColor(light: 0xF7F7F5, dark: 0x38383A)
    }

    static var textPrimary: Color {
        themedColor(light: 0x1C1C1E, dark: 0xF2F2F7)
    }

    static var textSecondary: Color {
        themedColor(light: 0x6E6E73, dark: 0xAEAEB2)
    }

    static var border: Color {
        themedColor(light: 0xD1D1D6, dark: 0x3A3A3C)
    }

    static var accent: Color {
        Color(red: 0.439, green: 0.620, blue: 0.365)
    }

    private static func themedColor(light: Int, dark: Int) -> Color {
        let hex = isDark ? dark : light
        return Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

/// A protocol of interaction between the trainer view and the enclosing view controller.
@MainActor protocol TrainerInteraction {
    var isStoryTrainer: Bool { get set }
}

struct TrainerView: View {
    var interaction: TrainerInteraction
    
    @ObservedObject var cache: StoryCache
    
    let columns = [GridItem(.adaptive(minimum: 50))]

    enum MatchType: String, CaseIterable, Identifiable {
        case exact
        case regex
        
        var id: String { rawValue }
        
        var label: String {
            switch self {
            case .exact:
                return "Exact phrase"
            case .regex:
                return "Regex"
            }
        }
    }
    
    var body: some View {
        ZStack {
            TrainerColors.background.ignoresSafeArea()
            VStack(alignment: .leading) {
                (Text("What do you ")
                    + Text("like").bold()
                    + Text(" and ")
                    + Text("dislike").bold()
                    + Text(" about this \(feedOrStoryLowercase)?"))
                    .font(font(named: "WhitneySSm-Medium", size: 16))
                    .foregroundColor(TrainerColors.textPrimary)
                    .padding()

                List {
                    if interaction.isStoryTrainer {
                        Section(content: {
                            textSectionContent()
                                .listRowBackground(TrainerColors.cardBackground)
                        }, header: {
                            header(story: "Story Text", feed: "Text Phrases")
                        })
                    }

                    Section(content: {
                        titleSectionContent()
                            .listRowBackground(TrainerColors.cardBackground)
                    }, header: {
                        header(story: "Story Title", feed: "Titles & Phrases")
                    })

                    if !interaction.isStoryTrainer {
                        Section(content: {
                            textSectionContent()
                                .listRowBackground(TrainerColors.cardBackground)
                        }, header: {
                            header(feed: "Text Phrases")
                        })
                    }

                    if interaction.isStoryTrainer {
                        Section(content: {
                            urlSectionContent()
                                .listRowBackground(TrainerColors.cardBackground)
                        }, header: {
                            header(story: "Story URL", feed: "Story URL")
                        })
                    }

                    Section(content: {
                        WrappingHStack(models: authors) { author in
                            Button(action: {
                                cache.appDelegate.toggleAuthorClassifier(author.name, feedId: feed?.id)
                            }, label: {
                                TrainerCapsule(score: author.score, header: "Author", value: author.name, count: author.count)
                            })
                            .buttonStyle(BorderlessButtonStyle())
                            .padding([.top, .bottom], 5)
                        }
                        .listRowBackground(TrainerColors.cardBackground)
                    }, header: {
                        header(story: "Story Authors", feed: "Authors")
                    })

                    Section(content: {
                        WrappingHStack(models: tags) { tag in
                            Button(action: {
                                cache.appDelegate.toggleTagClassifier(tag.name, feedId: feed?.id)
                            }, label: {
                                TrainerCapsule(score: tag.score, header: "Tag", value: tag.name, count: tag.count)
                            })
                            .buttonStyle(BorderlessButtonStyle())
                            .padding([.top, .bottom], 5)
                        }
                        .listRowBackground(TrainerColors.cardBackground)
                    }, header: {
                        header(story: "Story Categories & Tags", feed: "Categories & Tags")
                    })

                    Section(content: {
                        HStack {
                            if let feed = feed {
                                Button(action: {
                                    cache.appDelegate.toggleFeedClassifier(feed.id)
                                }, label: {
                                    TrainerCapsule(score: score(key: "feeds", value: feed.id), header: "Site", image: feed.image, value: feed.name)
                                })
                                .buttonStyle(BorderlessButtonStyle())
                                .padding([.top, .bottom], 5)
                            }
                        }
                        .listRowBackground(TrainerColors.cardBackground)
                    }, header: {
                        header(story: "Publisher", feed: "Publisher")
                    })
                }
                .font(font(named: "WhitneySSm-Medium", size: 12))
                .listStyle(PlainListStyle())
                .trainerListBackground()
                .background(TrainerColors.background)
            }
        }
        .id(themeObserver.themeVersion)
        .environment(\.colorScheme, TrainerColors.isDark ? .dark : .light)
        .onAppear {
            resetInputs()
        }
        .onChange(of: cache.selected?.hash) { _ in
            if interaction.isStoryTrainer {
                resetInputs()
            }
        }
        .onChange(of: cache.currentFeed?.id) { _ in
            if !interaction.isStoryTrainer {
                resetInputs()
            }
        }
    }
    
    func font(named: String, size: CGFloat) -> Font {
        return Font.custom(named, size: size + cache.settings.fontSize.offset, relativeTo: .caption)
    }
    
    func reload() {
        cache.reload()
        resetInputs()
    }

    func resetInputs() {
        addingTitle = ""
        titleMatchType = .exact
        textInput = ""
        textMatchType = .exact
        urlMatchType = .exact
        urlInput = interaction.isStoryTrainer ? storyUrlDisplay : ""
    }
    
    var feedOrStoryLowercase: String {
        return interaction.isStoryTrainer ? "story" : "site"
    }

    var canUseArchiveClassifiers: Bool {
        return cache.appDelegate.isPremiumArchive || cache.appDelegate.isPremiumPro
    }

    var canUseRegexClassifiers: Bool {
        return cache.appDelegate.isPremiumPro
    }

    func openArchiveUpsell() {
        cache.appDelegate.showPremiumDialogForArchive()
    }

    func openProUpsell() {
        cache.appDelegate.showPremiumDialogForPro()
    }
    
    @ViewBuilder
    func header(story: String? = nil, feed: String) -> some View {
        if let story {
            Text(interaction.isStoryTrainer ? story : feed)
                .font(font(named: "WhitneySSm-Medium", size: 16))
                .foregroundColor(TrainerColors.textPrimary)
        } else {
            Text(feed)
                .font(font(named: "WhitneySSm-Medium", size: 16))
                .foregroundColor(TrainerColors.textPrimary)
        }
    }

    @ViewBuilder
    func notice(_ text: String, link: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(spacing: 4) {
            Text(text)
            if let link, let action {
                Button(link, action: action)
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(TrainerColors.accent)
            }
        }
        .font(font(named: "WhitneySSm-Medium", size: 11))
        .foregroundColor(TrainerColors.textSecondary)
        .padding(.top, 2)
    }

    @ViewBuilder
    func matchTypePicker(selection: Binding<MatchType>, canUseRegex: Bool) -> some View {
        Picker("", selection: selection) {
            ForEach(MatchType.allCases) { matchType in
                Text(matchType.label).tag(matchType)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.top, 4)
        .disabled(!canUseRegex)
        .opacity(canUseRegex ? 1.0 : 0.6)
    }

    @ViewBuilder
    func textSectionContent() -> some View {
        let canUseText = canUseArchiveClassifiers
        let canUseRegex = canUseRegexClassifiers

        VStack(alignment: .leading) {
            if !canUseText {
                notice("Requires", link: "Premium Archive", action: openArchiveUpsell)
            }
            if !canUseRegex {
                notice("Regex requires", link: "Premium Pro", action: openProUpsell)
            }
            
            VStack(alignment: .leading) {
                HStack {
                    TextField("Enter text to match...", text: $textInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Add") {
                        addTextClassifier()
                    }
                    .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              !canUseText ||
                              (textMatchType == .regex && !canUseRegex))
                }
                matchTypePicker(selection: $textMatchType, canUseRegex: canUseRegex)
                
                WrappingHStack(models: texts) { text in
                    Button(action: {
                        guard canUseText else {
                            openArchiveUpsell()
                            return
                        }
                        cache.appDelegate.toggleTextClassifier(text.name, feedId: feed?.id, score: 0)
                    }, label: {
                        TrainerCapsule(score: text.score, header: "Text", value: text.name, count: text.count)
                    })
                    .buttonStyle(BorderlessButtonStyle())
                    .padding([.top, .bottom], 5)
                }
                
                WrappingHStack(models: textRegexes) { text in
                    Button(action: {
                        guard canUseText else {
                            openArchiveUpsell()
                            return
                        }
                        guard canUseRegex else {
                            openProUpsell()
                            return
                        }
                        cache.appDelegate.toggleTextRegexClassifier(text.name, feedId: feed?.id, score: 0)
                    }, label: {
                        TrainerCapsule(score: text.score, header: "Text Regex", value: text.name, count: text.count)
                    })
                    .buttonStyle(BorderlessButtonStyle())
                    .padding([.top, .bottom], 5)
                }
                .opacity(canUseRegex ? 1.0 : 0.5)
                .allowsHitTesting(canUseRegex)
            }
            .opacity(canUseText ? 1.0 : 0.45)
            .disabled(!canUseText)
        }
    }

    @ViewBuilder
    func titleSectionContent() -> some View {
        let canUseRegex = canUseRegexClassifiers

        VStack(alignment: .leading) {
            if interaction.isStoryTrainer {
                Text("Choose one or more words from the title:")
                    .font(font(named: "WhitneySSm-Medium", size: 12))
                    .foregroundColor(TrainerColors.textSecondary)
                    .padding([.top], 10)
                
                WrappingHStack(models: titleWords, horizontalSpacing: 1) { word in
                    Button(action: {
                        if addingTitle.isEmpty {
                            addingTitle = word
                        } else {
                            addingTitle.append(" \(word)")
                        }
                    }, label: {
                        TrainerWord(word: word)
                    })
                    .buttonStyle(BorderlessButtonStyle())
                    .padding([.top, .bottom], 5)
                }
            }
            
            HStack {
                TextField("Enter title phrase...", text: $addingTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Add") {
                    addTitleClassifier()
                }
                .disabled(addingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          (titleMatchType == .regex && !canUseRegex))
            }
            matchTypePicker(selection: $titleMatchType, canUseRegex: canUseRegex)
            
            if !canUseRegex {
                notice("Regex requires", link: "Premium Pro", action: openProUpsell)
            }
            
            WrappingHStack(models: titles) { title in
                Button(action: {
                    cache.appDelegate.toggleTitleClassifier(title.name, feedId: feed?.id, score: 0)
                }, label: {
                    TrainerCapsule(score: title.score, header: "Title", value: title.name, count: title.count)
                })
                .buttonStyle(BorderlessButtonStyle())
                .padding([.top, .bottom], 5)
            }
            
            WrappingHStack(models: titleRegexes) { title in
                Button(action: {
                    guard canUseRegex else {
                        openProUpsell()
                        return
                    }
                    cache.appDelegate.toggleTitleRegexClassifier(title.name, feedId: feed?.id, score: 0)
                }, label: {
                    TrainerCapsule(score: title.score, header: "Title Regex", value: title.name, count: title.count)
                })
                .buttonStyle(BorderlessButtonStyle())
                .padding([.top, .bottom], 5)
            }
            .opacity(canUseRegex ? 1.0 : 0.5)
            .allowsHitTesting(canUseRegex)
        }
    }

    @ViewBuilder
    func urlSectionContent() -> some View {
        let canUseUrl = canUseArchiveClassifiers
        let canUseRegex = canUseRegexClassifiers

        VStack(alignment: .leading) {
            if !canUseUrl {
                notice("Requires", link: "Premium Archive", action: openArchiveUpsell)
            }
            if !canUseRegex {
                notice("Regex requires", link: "Premium Pro", action: openProUpsell)
            }
            
            VStack(alignment: .leading) {
                HStack {
                    TextField("Enter URL pattern to match...", text: $urlInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Add") {
                        addUrlClassifier()
                    }
                    .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              !canUseUrl ||
                              (urlMatchType == .regex && !canUseRegex))
                }
                matchTypePicker(selection: $urlMatchType, canUseRegex: canUseRegex)
                
                WrappingHStack(models: urls) { url in
                    Button(action: {
                        guard canUseUrl else {
                            openArchiveUpsell()
                            return
                        }
                        cache.appDelegate.toggleUrlClassifier(url.name, feedId: feed?.id, score: 0)
                    }, label: {
                        TrainerCapsule(score: url.score, header: "URL", value: url.name, count: url.count)
                    })
                    .buttonStyle(BorderlessButtonStyle())
                    .padding([.top, .bottom], 5)
                }
                
                WrappingHStack(models: urlRegexes) { url in
                    Button(action: {
                        guard canUseUrl else {
                            openArchiveUpsell()
                            return
                        }
                        guard canUseRegex else {
                            openProUpsell()
                            return
                        }
                        cache.appDelegate.toggleUrlRegexClassifier(url.name, feedId: feed?.id, score: 0)
                    }, label: {
                        TrainerCapsule(score: url.score, header: "URL Regex", value: url.name, count: url.count)
                    })
                    .buttonStyle(BorderlessButtonStyle())
                    .padding([.top, .bottom], 5)
                }
                .opacity(canUseRegex ? 1.0 : 0.5)
                .allowsHitTesting(canUseRegex)
            }
            .opacity(canUseUrl ? 1.0 : 0.45)
            .disabled(!canUseUrl)
        }
    }
    
    func score(key: String, value: String) -> Feed.Score {
        guard let classifiers = feed?.classifiers(for: key),
              let score = classifiers[value] as? Int else {
            return .none
        }
        
        if score > 0 {
            return .like
        } else if score < 0 {
            return .dislike
        } else {
            return .none
        }
    }

    func addTitleClassifier() {
        let value = addingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let feedId = feed?.id else {
            return
        }

        if titleMatchType == .regex && !canUseRegexClassifiers {
            openProUpsell()
            return
        }
        
        if titleMatchType == .regex {
            cache.appDelegate.toggleTitleRegexClassifier(value, feedId: feedId, score: 0)
        } else {
            cache.appDelegate.toggleTitleClassifier(value, feedId: feedId, score: 0)
        }
        
        addingTitle = ""
    }

    func addTextClassifier() {
        let value = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let feedId = feed?.id else {
            return
        }

        if !canUseArchiveClassifiers {
            openArchiveUpsell()
            return
        }
        if textMatchType == .regex && !canUseRegexClassifiers {
            openProUpsell()
            return
        }
        
        if textMatchType == .regex {
            cache.appDelegate.toggleTextRegexClassifier(value, feedId: feedId, score: 0)
        } else {
            cache.appDelegate.toggleTextClassifier(value, feedId: feedId, score: 0)
        }
        
        textInput = ""
    }

    func addUrlClassifier() {
        let value = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let feedId = feed?.id else {
            return
        }

        if !canUseArchiveClassifiers {
            openArchiveUpsell()
            return
        }
        if urlMatchType == .regex && !canUseRegexClassifiers {
            openProUpsell()
            return
        }
        
        if urlMatchType == .regex {
            cache.appDelegate.toggleUrlRegexClassifier(value, feedId: feedId, score: 0)
        } else {
            cache.appDelegate.toggleUrlClassifier(value, feedId: feedId, score: 0)
        }
        
        urlInput = storyUrlDisplay
    }
    
    var titleWords: [String] {
        if interaction.isStoryTrainer, let story = cache.selected {
            return story.title.components(separatedBy: .whitespaces)
        } else {
            return []
        }
    }
    
    @StateObject private var themeObserver = TrainerThemeObserver()
    @State private var addingTitle = ""
    @State private var titleMatchType: MatchType = .exact
    @State private var textInput = ""
    @State private var textMatchType: MatchType = .exact
    @State private var urlInput = ""
    @State private var urlMatchType: MatchType = .exact
    
    var feed: Feed? {
        return cache.currentFeed ?? cache.selected?.feed
    }
    
    var titles: [Feed.Training] {
        if interaction.isStoryTrainer {
            return cache.selected?.titles ?? []
        } else {
            return feed?.titles ?? []
        }
    }

    var titleRegexes: [Feed.Training] {
        if interaction.isStoryTrainer {
            return cache.selected?.titleRegexes ?? []
        } else {
            return feed?.titleRegex ?? []
        }
    }
    
    var authors: [Feed.Training] {
        if interaction.isStoryTrainer {
            return cache.selected?.authors ?? []
        } else {
            return feed?.authors ?? []
        }
    }
    
    var tags: [Feed.Training] {
        if interaction.isStoryTrainer {
            return cache.selected?.tags ?? []
        } else {
            return feed?.tags ?? []
        }
    }

    var texts: [Feed.Training] {
        if interaction.isStoryTrainer {
            return cache.selected?.texts ?? []
        } else {
            return feed?.texts ?? []
        }
    }

    var textRegexes: [Feed.Training] {
        if interaction.isStoryTrainer {
            return cache.selected?.textRegexes ?? []
        } else {
            return feed?.textRegex ?? []
        }
    }

    var urls: [Feed.Training] {
        if interaction.isStoryTrainer {
            return cache.selected?.urls ?? []
        } else {
            return []
        }
    }

    var urlRegexes: [Feed.Training] {
        if interaction.isStoryTrainer {
            return cache.selected?.urlRegexes ?? []
        } else {
            return []
        }
    }

    var storyUrlDisplay: String {
        guard interaction.isStoryTrainer, let story = cache.selected else {
            return ""
        }
        
        var permalink = story.dictionary["story_permalink"] as? String ?? ""
        if let range = permalink.range(of: "://") {
            permalink = String(permalink[range.upperBound...])
        }
        return permalink
    }
}

private extension View {
    @ViewBuilder
    func trainerListBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

//#Preview {
//    TrainerViewController()
//}
