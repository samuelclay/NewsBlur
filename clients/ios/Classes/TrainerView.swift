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

    var body: some View {
        VStack(alignment: .leading) {
            Text("What do you 👍 \(Text("like").colored(.green)) and 👎 \(Text("dislike").colored(.red)) about this \(feedOrStoryLowercase)?")
                .font(font(named: "WhitneySSm-Medium", size: 16))
                .foregroundColor(textColor)
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
                            Button(action: {
                                cache.appDelegate.toggleTitleClassifier(title.name, feedId: feed?.id, score: 0, scope: currentScope(for: "title", name: title.name).rawValue, folderName: currentFolderName)
                            }, label: {
                                TrainerCapsule(score: title.score, header: "Title", value: title.name, count: title.count, showsScope: true, scope: scopeBinding(for: "title", name: title.name, default: title.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                    handleScopeChange(classifierType: "title", name: title.name, score: title.score, newScope: newScope)
                                })
                            })
                            .buttonStyle(BorderlessButtonStyle())
                            .padding([.top, .bottom], 5)
                        }

                        if !titleRegexes.isEmpty {
                            WrappingHStack(models: titleRegexes) { item in
                                Button(action: {
                                    cache.appDelegate.toggleTitleRegexClassifier(item.name, feedId: feed?.id, scope: currentScope(for: "title_regex", name: item.name).rawValue, folderName: currentFolderName)
                                }, label: {
                                    TrainerCapsule(score: item.score, header: "Title", value: item.name, count: item.count, isRegex: true, showsScope: true, scope: scopeBinding(for: "title_regex", name: item.name, default: item.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                        handleScopeChange(classifierType: "title_regex", name: item.name, score: item.score, newScope: newScope)
                                    })
                                })
                                .buttonStyle(BorderlessButtonStyle())
                                .padding([.top, .bottom], 5)
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
                        Button(action: {
                            cache.appDelegate.toggleAuthorClassifier(author.name, feedId: feed?.id, scope: currentScope(for: "author", name: author.name).rawValue, folderName: currentFolderName)
                        }, label: {
                            TrainerCapsule(score: author.score, header: "Author", value: author.name, count: author.count, showsScope: true, scope: scopeBinding(for: "author", name: author.name, default: author.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                handleScopeChange(classifierType: "author", name: author.name, score: author.score, newScope: newScope)
                            })
                        })
                        .buttonStyle(BorderlessButtonStyle())
                        .padding([.top, .bottom], 5)
                    }
                    .listRowBackground(rowBackground)
                }, header: {
                    header(story: "Story Author", feed: "Authors")
                })

                Section(content: {
                    WrappingHStack(models: tags) { tag in
                        Button(action: {
                            cache.appDelegate.toggleTagClassifier(tag.name, feedId: feed?.id, scope: currentScope(for: "tag", name: tag.name).rawValue, folderName: currentFolderName)
                        }, label: {
                            TrainerCapsule(score: tag.score, header: "Tag", value: tag.name, count: tag.count, showsScope: true, scope: scopeBinding(for: "tag", name: tag.name, default: tag.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                handleScopeChange(classifierType: "tag", name: tag.name, score: tag.score, newScope: newScope)
                            })
                        })
                        .buttonStyle(BorderlessButtonStyle())
                        .padding([.top, .bottom], 5)
                    }
                    .listRowBackground(rowBackground)
                }, header: {
                    header(story: "Story Categories & Tags", feed: "Categories & Tags")
                })

                Section(content: {
                    VStack(alignment: .leading) {
                        if !texts.isEmpty {
                            WrappingHStack(models: texts) { item in
                                Button(action: {
                                    cache.appDelegate.toggleTextClassifier(item.name, feedId: feed?.id, scope: currentScope(for: "text", name: item.name).rawValue, folderName: currentFolderName)
                                }, label: {
                                    TrainerCapsule(score: item.score, header: "Text", value: item.name, count: item.count, showsScope: true, scope: scopeBinding(for: "text", name: item.name, default: item.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                        handleScopeChange(classifierType: "text", name: item.name, score: item.score, newScope: newScope)
                                    })
                                })
                                .buttonStyle(BorderlessButtonStyle())
                                .padding([.top, .bottom], 5)
                            }
                        }

                        if !textRegexes.isEmpty {
                            WrappingHStack(models: textRegexes) { item in
                                Button(action: {
                                    cache.appDelegate.toggleTextRegexClassifier(item.name, feedId: feed?.id, scope: currentScope(for: "text_regex", name: item.name).rawValue, folderName: currentFolderName)
                                }, label: {
                                    TrainerCapsule(score: item.score, header: "Text", value: item.name, count: item.count, isRegex: true, showsScope: true, scope: scopeBinding(for: "text_regex", name: item.name, default: item.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                        handleScopeChange(classifierType: "text_regex", name: item.name, score: item.score, newScope: newScope)
                                    })
                                })
                                .buttonStyle(BorderlessButtonStyle())
                                .padding([.top, .bottom], 5)
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
                                Button(action: {
                                    cache.appDelegate.toggleUrlClassifier(item.name, feedId: feed?.id, scope: currentScope(for: "url", name: item.name).rawValue, folderName: currentFolderName)
                                }, label: {
                                    TrainerCapsule(score: item.score, header: "URL", value: item.name, count: item.count, showsScope: true, scope: scopeBinding(for: "url", name: item.name, default: item.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                        handleScopeChange(classifierType: "url", name: item.name, score: item.score, newScope: newScope)
                                    })
                                })
                                .buttonStyle(BorderlessButtonStyle())
                                .padding([.top, .bottom], 5)
                            }
                        }

                        if !urlRegexes.isEmpty {
                            WrappingHStack(models: urlRegexes) { item in
                                Button(action: {
                                    cache.appDelegate.toggleUrlRegexClassifier(item.name, feedId: feed?.id, scope: currentScope(for: "url_regex", name: item.name).rawValue, folderName: currentFolderName)
                                }, label: {
                                    TrainerCapsule(score: item.score, header: "URL", value: item.name, count: item.count, isRegex: true, showsScope: true, scope: scopeBinding(for: "url_regex", name: item.name, default: item.scope), isPremiumArchive: isArchive, onScopeChanged: { newScope in
                                        handleScopeChange(classifierType: "url_regex", name: item.name, score: item.score, newScope: newScope)
                                    })
                                })
                                .buttonStyle(BorderlessButtonStyle())
                                .padding([.top, .bottom], 5)
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

        if score > 0 {
            return .like
        } else if score < 0 {
            return .dislike
        } else {
            return .none
        }
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
        let key = "\(type):\(name)"
        return Binding(
            get: { scopeOverrides[key] ?? defaultScope },
            set: { scopeOverrides[key] = $0 }
        )
    }

    func currentScope(for type: String, name: String) -> ClassifierScope {
        return scopeOverrides["\(type):\(name)"] ?? .feed
    }

    func handleScopeChange(classifierType: String, name: String, score: Feed.Score, newScope: ClassifierScope) {
        let key = "\(classifierType):\(name)"
        let oldScope = scopeOverrides[key] ?? .feed
        let oldFolderName = (oldScope == .folder) ? currentFolderName : ""
        scopeOverrides[key] = newScope

        guard let feedId = feed?.id else { return }
        cache.appDelegate.changeClassifierScope(classifierType, value: name, feedId: feedId, score: Int(score.rawValue), oldScope: oldScope.rawValue, oldFolderName: oldFolderName, scope: newScope.rawValue, folderName: currentFolderName)
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
