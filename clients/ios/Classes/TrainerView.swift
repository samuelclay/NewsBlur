//
//  TrainerView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-04-02.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

/// A protocol of interaction between the trainer view and the enclosing view controller.
@MainActor protocol TrainerInteraction {
    var isStoryTrainer: Bool { get set }
}

struct TrainerView: View {
    var interaction: TrainerInteraction

    @ObservedObject var cache: StoryCache

    let columns = [GridItem(.adaptive(minimum: 50))]

    @State private var scopeOverrides: [String: ClassifierScope] = [:]

    @State private var showExplainerExamples = false

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What do you 👍 \(Text("like").colored(.green)) and 👎 \(Text("dislike").colored(.red)) about this \(feedOrStoryLowercase)?")
                    .font(font(named: "WhitneySSm-Medium", size: 16))
                    .foregroundColor(textColor)

                explainerBanner
            }
            .padding()

            List {
                Section(content: {
                    VStack(alignment: .leading) {
                        if interaction.isStoryTrainer {
                            Text("Choose one or more words from the title:")
                                .font(font(named: "WhitneySSm-Medium", size: 12))
                                .foregroundColor(secondaryTextColor)
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

                            if !addingTitle.isEmpty {
                                HStack {
                                    Button(action: {
                                        cache.appDelegate.toggleTitleClassifier(addingTitle, feedId: feed?.id, score: 0)
                                        addingTitle = ""
                                    }, label: {
                                        TrainerCapsule(score: .none, header: "Title", value: addingTitle)
                                    })
                                    .buttonStyle(BorderlessButtonStyle())
                                    .padding([.top, .bottom], 5)

                                    Button {
                                        addingTitle = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .imageScale(.large)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }

                        WrappingHStack(models: titles) { title in
                            classifierRow(
                                capsule: TrainerCapsule(score: title.score, header: "Title", value: title.name, count: title.count, showsScope: true, scope: scopeBinding(for: "title", name: title.name, default: title.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                    handleScopeChange(classifierType: "title", name: title.name, score: title.score, defaultScope: title.scope, defaultFolderName: title.folderName, newScope: newScope)
                                }),
                                score: title.score,
                                onTap: { cache.appDelegate.toggleTitleClassifier(title.name, feedId: feed?.id, score: 0, scope: currentScope(for: "title", name: title.name, default: title.scope).rawValue, folderName: currentFolderName(for: "title", name: title.name, default: title.scope, defaultFolderName: title.folderName)) },
                                onDislike: { cache.appDelegate.toggleTitleClassifier(title.name, feedId: feed?.id, score: title.score == .dislike ? 0 : -1, scope: currentScope(for: "title", name: title.name, default: title.scope).rawValue, folderName: currentFolderName(for: "title", name: title.name, default: title.scope, defaultFolderName: title.folderName)) },
                                onSuperDislike: { cache.appDelegate.toggleTitleClassifier(title.name, feedId: feed?.id, score: title.score == .superDislike ? 0 : -2, scope: currentScope(for: "title", name: title.name, default: title.scope).rawValue, folderName: currentFolderName(for: "title", name: title.name, default: title.scope, defaultFolderName: title.folderName)) }
                            )
                        }

                        if !titleRegexes.isEmpty {
                            WrappingHStack(models: titleRegexes) { item in
                                classifierRow(
                                    capsule: TrainerCapsule(score: item.score, header: "Title", value: item.name, count: item.count, isRegex: true, showsScope: true, scope: scopeBinding(for: "title_regex", name: item.name, default: item.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                        handleScopeChange(classifierType: "title_regex", name: item.name, score: item.score, defaultScope: item.scope, defaultFolderName: item.folderName, newScope: newScope)
                                    }),
                                    score: item.score,
                                    onTap: { cache.appDelegate.toggleTitleRegexClassifier(item.name, feedId: feed?.id, scope: currentScope(for: "title_regex", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "title_regex", name: item.name, default: item.scope, defaultFolderName: item.folderName)) },
                                    onDislike: { cache.appDelegate.toggleTitleRegexClassifier(item.name, feedId: feed?.id, score: item.score == .dislike ? 0 : -1, scope: currentScope(for: "title_regex", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "title_regex", name: item.name, default: item.scope, defaultFolderName: item.folderName)) },
                                    onSuperDislike: { cache.appDelegate.toggleTitleRegexClassifier(item.name, feedId: feed?.id, score: item.score == .superDislike ? 0 : -2, scope: currentScope(for: "title_regex", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "title_regex", name: item.name, default: item.scope, defaultFolderName: item.folderName)) }
                                )
                            }
                        }

                        TrainerRegexInput(sectionType: .title, story: cache.selected, feedId: feed?.id, appDelegate: cache.appDelegate, fontBuilder: font, cache: cache)

                        Spacer().frame(height: 8)
                    }
                    .listRowBackground(rowBackground)
                }, header: {
                    header(story: "Story Title", feed: "Titles & Phrases")
                })

                Section(content: {
                    WrappingHStack(models: authors) { author in
                        classifierRow(
                            capsule: TrainerCapsule(score: author.score, header: "Author", value: author.name, count: author.count, showsScope: true, scope: scopeBinding(for: "author", name: author.name, default: author.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                handleScopeChange(classifierType: "author", name: author.name, score: author.score, defaultScope: author.scope, defaultFolderName: author.folderName, newScope: newScope)
                            }),
                            score: author.score,
                            onTap: { cache.appDelegate.toggleAuthorClassifier(author.name, feedId: feed?.id, scope: currentScope(for: "author", name: author.name, default: author.scope).rawValue, folderName: currentFolderName(for: "author", name: author.name, default: author.scope, defaultFolderName: author.folderName)) },
                            onDislike: { cache.appDelegate.toggleAuthorClassifier(author.name, feedId: feed?.id, score: author.score == .dislike ? 0 : -1, scope: currentScope(for: "author", name: author.name, default: author.scope).rawValue, folderName: currentFolderName(for: "author", name: author.name, default: author.scope, defaultFolderName: author.folderName)) },
                            onSuperDislike: { cache.appDelegate.toggleAuthorClassifier(author.name, feedId: feed?.id, score: author.score == .superDislike ? 0 : -2, scope: currentScope(for: "author", name: author.name, default: author.scope).rawValue, folderName: currentFolderName(for: "author", name: author.name, default: author.scope, defaultFolderName: author.folderName)) }
                        )
                    }
                    .listRowBackground(rowBackground)
                }, header: {
                    header(story: "Story Author", feed: "Authors")
                })

                Section(content: {
                    WrappingHStack(models: tags) { tag in
                        classifierRow(
                            capsule: TrainerCapsule(score: tag.score, header: "Tag", value: tag.name, count: tag.count, showsScope: true, scope: scopeBinding(for: "tag", name: tag.name, default: tag.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                handleScopeChange(classifierType: "tag", name: tag.name, score: tag.score, defaultScope: tag.scope, defaultFolderName: tag.folderName, newScope: newScope)
                            }),
                            score: tag.score,
                            onTap: { cache.appDelegate.toggleTagClassifier(tag.name, feedId: feed?.id, scope: currentScope(for: "tag", name: tag.name, default: tag.scope).rawValue, folderName: currentFolderName(for: "tag", name: tag.name, default: tag.scope, defaultFolderName: tag.folderName)) },
                            onDislike: { cache.appDelegate.toggleTagClassifier(tag.name, feedId: feed?.id, score: tag.score == .dislike ? 0 : -1, scope: currentScope(for: "tag", name: tag.name, default: tag.scope).rawValue, folderName: currentFolderName(for: "tag", name: tag.name, default: tag.scope, defaultFolderName: tag.folderName)) },
                            onSuperDislike: { cache.appDelegate.toggleTagClassifier(tag.name, feedId: feed?.id, score: tag.score == .superDislike ? 0 : -2, scope: currentScope(for: "tag", name: tag.name, default: tag.scope).rawValue, folderName: currentFolderName(for: "tag", name: tag.name, default: tag.scope, defaultFolderName: tag.folderName)) }
                        )
                    }
                    .listRowBackground(rowBackground)
                }, header: {
                    header(story: "Story Categories & Tags", feed: "Categories & Tags")
                })

                Section(content: {
                    VStack(alignment: .leading) {
                        if !texts.isEmpty {
                            WrappingHStack(models: texts) { item in
                                classifierRow(
                                    capsule: TrainerCapsule(score: item.score, header: "Text", value: item.name, count: item.count, showsScope: true, scope: scopeBinding(for: "text", name: item.name, default: item.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                        handleScopeChange(classifierType: "text", name: item.name, score: item.score, defaultScope: item.scope, defaultFolderName: item.folderName, newScope: newScope)
                                    }),
                                    score: item.score,
                                    onTap: { cache.appDelegate.toggleTextClassifier(item.name, feedId: feed?.id, scope: currentScope(for: "text", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "text", name: item.name, default: item.scope, defaultFolderName: item.folderName)) },
                                    onDislike: { cache.appDelegate.toggleTextClassifier(item.name, feedId: feed?.id, score: item.score == .dislike ? 0 : -1, scope: currentScope(for: "text", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "text", name: item.name, default: item.scope, defaultFolderName: item.folderName)) },
                                    onSuperDislike: { cache.appDelegate.toggleTextClassifier(item.name, feedId: feed?.id, score: item.score == .superDislike ? 0 : -2, scope: currentScope(for: "text", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "text", name: item.name, default: item.scope, defaultFolderName: item.folderName)) }
                                )
                            }
                        }

                        if !textRegexes.isEmpty {
                            WrappingHStack(models: textRegexes) { item in
                                classifierRow(
                                    capsule: TrainerCapsule(score: item.score, header: "Text", value: item.name, count: item.count, isRegex: true, showsScope: true, scope: scopeBinding(for: "text_regex", name: item.name, default: item.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                        handleScopeChange(classifierType: "text_regex", name: item.name, score: item.score, defaultScope: item.scope, defaultFolderName: item.folderName, newScope: newScope)
                                    }),
                                    score: item.score,
                                    onTap: { cache.appDelegate.toggleTextRegexClassifier(item.name, feedId: feed?.id, scope: currentScope(for: "text_regex", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "text_regex", name: item.name, default: item.scope, defaultFolderName: item.folderName)) },
                                    onDislike: { cache.appDelegate.toggleTextRegexClassifier(item.name, feedId: feed?.id, score: item.score == .dislike ? 0 : -1, scope: currentScope(for: "text_regex", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "text_regex", name: item.name, default: item.scope, defaultFolderName: item.folderName)) },
                                    onSuperDislike: { cache.appDelegate.toggleTextRegexClassifier(item.name, feedId: feed?.id, score: item.score == .superDislike ? 0 : -2, scope: currentScope(for: "text_regex", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "text_regex", name: item.name, default: item.scope, defaultFolderName: item.folderName)) }
                                )
                            }
                        }

                        TrainerRegexInput(sectionType: .text, story: cache.selected, feedId: feed?.id, appDelegate: cache.appDelegate, fontBuilder: font, cache: cache)

                        Spacer().frame(height: 8)
                    }
                    .listRowBackground(rowBackground)
                }, header: {
                    header(story: "Story Text", feed: "Text & Phrases")
                })

                Section(content: {
                    VStack(alignment: .leading) {
                        if !urls.isEmpty {
                            WrappingHStack(models: urls) { item in
                                classifierRow(
                                    capsule: TrainerCapsule(score: item.score, header: "URL", value: item.name, count: item.count, showsScope: true, scope: scopeBinding(for: "url", name: item.name, default: item.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                        handleScopeChange(classifierType: "url", name: item.name, score: item.score, defaultScope: item.scope, defaultFolderName: item.folderName, newScope: newScope)
                                    }),
                                    score: item.score,
                                    onTap: { cache.appDelegate.toggleUrlClassifier(item.name, feedId: feed?.id, scope: currentScope(for: "url", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "url", name: item.name, default: item.scope, defaultFolderName: item.folderName)) },
                                    onDislike: { cache.appDelegate.toggleUrlClassifier(item.name, feedId: feed?.id, score: item.score == .dislike ? 0 : -1, scope: currentScope(for: "url", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "url", name: item.name, default: item.scope, defaultFolderName: item.folderName)) },
                                    onSuperDislike: { cache.appDelegate.toggleUrlClassifier(item.name, feedId: feed?.id, score: item.score == .superDislike ? 0 : -2, scope: currentScope(for: "url", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "url", name: item.name, default: item.scope, defaultFolderName: item.folderName)) }
                                )
                            }
                        }

                        if !urlRegexes.isEmpty {
                            WrappingHStack(models: urlRegexes) { item in
                                classifierRow(
                                    capsule: TrainerCapsule(score: item.score, header: "URL", value: item.name, count: item.count, isRegex: true, showsScope: true, scope: scopeBinding(for: "url_regex", name: item.name, default: item.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                        handleScopeChange(classifierType: "url_regex", name: item.name, score: item.score, defaultScope: item.scope, defaultFolderName: item.folderName, newScope: newScope)
                                    }),
                                    score: item.score,
                                    onTap: { cache.appDelegate.toggleUrlRegexClassifier(item.name, feedId: feed?.id, scope: currentScope(for: "url_regex", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "url_regex", name: item.name, default: item.scope, defaultFolderName: item.folderName)) },
                                    onDislike: { cache.appDelegate.toggleUrlRegexClassifier(item.name, feedId: feed?.id, score: item.score == .dislike ? 0 : -1, scope: currentScope(for: "url_regex", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "url_regex", name: item.name, default: item.scope, defaultFolderName: item.folderName)) },
                                    onSuperDislike: { cache.appDelegate.toggleUrlRegexClassifier(item.name, feedId: feed?.id, score: item.score == .superDislike ? 0 : -2, scope: currentScope(for: "url_regex", name: item.name, default: item.scope).rawValue, folderName: currentFolderName(for: "url_regex", name: item.name, default: item.scope, defaultFolderName: item.folderName)) }
                                )
                            }
                        }

                        TrainerRegexInput(sectionType: .url, story: cache.selected, feedId: feed?.id, appDelegate: cache.appDelegate, fontBuilder: font, cache: cache)

                        Spacer().frame(height: 8)
                    }
                    .listRowBackground(rowBackground)
                }, header: {
                    header(story: "Story URL", feed: "URLs")
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
                    .listRowBackground(rowBackground)
                }, header: {
                    header(feed: "Everything by This Publisher")
                })
            }
            .font(font(named: "WhitneySSm-Medium", size: 12))
            .scrollContentBackground(.hidden)
            .background(listBackground)
        }
        .background(listBackground)
        .onAppear {
            addingTitle = ""
            cache.reload()
        }
    }

    func font(named: String, size: CGFloat) -> Font {
        return Font.custom(named, size: size + cache.settings.fontSize.offset, relativeTo: .caption)
    }

    func reload() {
        cache.reload()
        addingTitle = ""
    }

    // MARK: - Classifier Row

    func classifierRow(capsule: TrainerCapsule, score: Feed.Score, onTap: @escaping () -> Void, onDislike: @escaping () -> Void, onSuperDislike: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            TrainerCapsule(score: capsule.score, header: capsule.header, image: capsule.image, value: capsule.value, count: capsule.count, isRegex: capsule.isRegex, showsScope: capsule.showsScope, scope: capsule.$scope, isPremiumArchive: capsule.isPremiumArchive, onScopeChanged: capsule.onScopeChanged, onDislike: onDislike, onSuperDislike: onSuperDislike)
        }
        .buttonStyle(BorderlessButtonStyle())
        .padding([.top, .bottom], 5)
    }

    // MARK: - Explainer Banner

    var superDislikeColor: Color {
        Color.themed([0x6B0001, 0x6B0001, 0xFF6B6B, 0xFF6B6B])
    }

    var likeColor: Color {
        Color.themed([0x34912E, 0x34912E, 0x7ECE72, 0x7ECE72])
    }

    var dislikeColor: Color {
        Color.themed([0xA90103, 0xA90103, 0xE87272, 0xE87272])
    }

    var separatorTextColor: Color {
        Color.themed([0xAAAAAA, 0xAAAAAA, 0x777777, 0x777777])
    }

    var explainerLineColor: Color {
        Color.themed([0xCCCCCC, 0xCCCCCC, 0x555555, 0x555555])
    }

    var explainerBodyColor: Color {
        Color.themed([0x777777, 0x777777, 0xAAAAAA, 0xAAAAAA])
    }

    var explainerBanner: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation { showExplainerExamples.toggle() } }) {
                HStack(spacing: 0) {
                    explainerHierarchyChain
                    Spacer()
                    Text("\u{24D8}")
                        .font(.system(size: 14))
                        .foregroundColor(separatorTextColor)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.themed([0x000000, 0x000000, 0xFFFFFF, 0xFFFFFF]).opacity(0.06))
                )
            }
            .buttonStyle(PlainButtonStyle())

            if showExplainerExamples {
                explainerExamples
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    var explainerHierarchyChain: some View {
        HStack(spacing: 0) {
            explainerPill("Super dislike", color: superDislikeColor, bgOpacity: 0.1, icon: "hand.thumbsdown.fill", iconSize: 10, isSuperDislike: true)
            explainerSeparator
            explainerPill("Like", color: likeColor, bgOpacity: 0.1, icon: "hand.thumbsup.fill", iconSize: 9)
            explainerSeparator
            explainerPill("Dislike", color: dislikeColor, bgOpacity: 0.1, icon: "hand.thumbsdown.fill", iconSize: 9)
        }
    }

    func explainerPill(_ label: String, color: Color, bgOpacity: Double, icon: String, iconSize: CGFloat, isSuperDislike: Bool = false) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            if isSuperDislike {
                DoubleThumbsDownIcon(size: iconSize + 2, color: color)
            } else {
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(bgOpacity))
        )
    }

    var explainerSeparator: some View {
        HStack(spacing: 3) {
            Rectangle().fill(explainerLineColor).frame(width: 8, height: 1)
            Text("BEATS")
                .font(.system(size: 7, weight: .medium))
                .tracking(0.5)
                .foregroundColor(separatorTextColor)
            Rectangle().fill(explainerLineColor).frame(width: 8, height: 1)
        }
        .padding(.horizontal, 1)
    }

    var explainerExamples: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text("Like beats any number of dislikes:")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(textColor)

                HStack(spacing: 4) {
                    examplePill("tech", color: dislikeColor, icon: "hand.thumbsdown.fill")
                    examplePill("review", color: dislikeColor, icon: "hand.thumbsdown.fill")
                    examplePill("John Gruber", color: likeColor, icon: "hand.thumbsup.fill")
                }

                HStack(spacing: 6) {
                    Text("\u{2192}")
                        .font(.system(size: 12))
                        .foregroundColor(explainerBodyColor)
                    Text("Story is shown (like wins)")
                        .font(.system(size: 10, weight: .medium))
                        .italic()
                        .foregroundColor(likeColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Super dislike beats any number of likes:")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(textColor)

                HStack(spacing: 4) {
                    examplePill("John Gruber", color: likeColor, icon: "hand.thumbsup.fill")
                    examplePill("Apple", color: likeColor, icon: "hand.thumbsup.fill")
                    examplePill("sponsored", color: superDislikeColor, icon: "hand.thumbsdown.fill", isSuperDislike: true)
                }

                HStack(spacing: 6) {
                    Text("\u{2192}")
                        .font(.system(size: 12))
                        .foregroundColor(explainerBodyColor)
                    Text("Story is hidden (super dislike wins)")
                        .font(.system(size: 10, weight: .medium))
                        .italic()
                        .foregroundColor(superDislikeColor)
                }
            }
        }
        .padding(.top, 4)
    }

    func examplePill(_ label: String, color: Color, icon: String, isSuperDislike: Bool = false) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(color)
            if isSuperDislike {
                DoubleThumbsDownIcon(size: 10, color: color)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
    }

    var feedOrStoryLowercase: String {
        return interaction.isStoryTrainer ? "story" : "site"
    }

    var listBackground: Color {
        Color.themed([0xF0F2ED, 0xF3E2CB, 0x2C2C2E, 0x1C1C1E])
    }

    var rowBackground: Color {
        Color.themed([0xFFFFFF, 0xFAF5ED, 0x3A3A3C, 0x2C2C2E])
    }

    var textColor: Color {
        Color.themed([0x1C1C1E, 0x3C3226, 0xF2F2F7, 0xF2F2F7])
    }

    var secondaryTextColor: Color {
        Color.themed([0x6E6E73, 0x8B7B6B, 0xAEAEB2, 0x98989D])
    }

    @ViewBuilder
    func header(story: String? = nil, feed: String) -> some View {
        if let story {
            Text(interaction.isStoryTrainer ? story : feed)
                .font(font(named: "WhitneySSm-Medium", size: 16))
                .foregroundColor(textColor)
        } else {
            Text(feed)
                .font(font(named: "WhitneySSm-Medium", size: 16))
                .foregroundColor(textColor)
        }
    }

    func score(key: String, value: String) -> Feed.Score {
        guard let classifiers = feed?.classifiers(for: key),
              let score = classifiers[value] as? Int else {
            return .none
        }

        return Feed.Score(rawValue: score) ?? (score > 0 ? .like : score < 0 ? .dislike : .none)
    }

    var titleWords: [String] {
        if interaction.isStoryTrainer, let story = cache.selected {
            return story.title.components(separatedBy: .whitespaces)
        } else {
            return []
        }
    }

    @State private var addingTitle = ""


    var feed: Feed? {
        return cache.currentFeed ?? cache.selected?.feed
    }

    var isArchive: Bool {
        return cache.appDelegate.isPremiumArchive
    }

    var currentFolderName: String {
        guard let feedId = feed?.id else { return "" }
        let folders = cache.appDelegate.parentFolders(forFeed: feedId) as? [String] ?? []
        return folders.first ?? ""
    }

    // MARK: - Scope

    func scopeBinding(for type: String, name: String, default defaultScope: ClassifierScope) -> Binding<ClassifierScope> {
        let key = ClassifierScopeResolver.overrideKey(type: type, name: name)
        return Binding(
            get: { scopeOverrides[key] ?? defaultScope },
            set: { scopeOverrides[key] = $0 }
        )
    }

    func currentScope(for type: String, name: String, default defaultScope: ClassifierScope) -> ClassifierScope {
        return ClassifierScopeResolver.effectiveScope(
            overrides: scopeOverrides,
            type: type,
            name: name,
            default: defaultScope
        )
    }

    func currentFolderName(
        for type: String,
        name: String,
        default defaultScope: ClassifierScope,
        defaultFolderName: String
    ) -> String {
        let key = ClassifierScopeResolver.overrideKey(type: type, name: name)
        if let overrideScope = scopeOverrides[key] {
            return overrideScope == .folder ? currentFolderName : ""
        }
        return defaultScope == .folder ? defaultFolderName : ""
    }

    func handleScopeChange(
        classifierType: String,
        name: String,
        score: Feed.Score,
        defaultScope: ClassifierScope,
        defaultFolderName: String,
        newScope: ClassifierScope
    ) {
        let key = ClassifierScopeResolver.overrideKey(type: classifierType, name: name)
        let oldScope = currentScope(for: classifierType, name: name, default: defaultScope)
        let oldFolderName = currentFolderName(
            for: classifierType,
            name: name,
            default: defaultScope,
            defaultFolderName: defaultFolderName
        )
        scopeOverrides[key] = newScope

        guard let feedId = feed?.id else { return }
        cache.appDelegate.changeClassifierScope(
            classifierType,
            value: name,
            feedId: feedId,
            score: Int(score.rawValue),
            oldScope: oldScope.rawValue,
            oldFolderName: oldFolderName,
            scope: newScope.rawValue,
            folderName: newScope == .folder ? currentFolderName : ""
        )
    }

    // MARK: - Classifiers

    var titles: [Feed.Training] {
        if interaction.isStoryTrainer {
            return cache.selected?.titles ?? []
        } else {
            return feed?.titles ?? []
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

    var titleRegexes: [Feed.Training] {
        if interaction.isStoryTrainer {
            return cache.selected?.titleRegexes ?? []
        } else {
            return feed?.titleRegex ?? []
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
            return feed?.urls ?? []
        }
    }

    var urlRegexes: [Feed.Training] {
        if interaction.isStoryTrainer {
            return cache.selected?.urlRegexes ?? []
        } else {
            return feed?.urlRegex ?? []
        }
    }

}

//#Preview {
//    TrainerViewController()
//}
