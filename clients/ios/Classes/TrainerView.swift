//
//  TrainerView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-04-02.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

/// A protocol of interaction between the trainer view and the enclosing view controller.
protocol TrainerInteraction {
    var isStoryTrainer: Bool { get set }
}

struct TrainerView: View {
    var interaction: TrainerInteraction
    
    @ObservedObject var cache: StoryCache
    
    let columns = [GridItem(.adaptive(minimum: 50))]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("What do you 👍 \(Text("like").colored(.green)) and 👎 \(Text("dislike").colored(.red)) about this \(feedOrStoryLowercase)?")
                .font(font(named: "WhitneySSm-Medium", size: 16))
                .padding()
            
            List {
                Section(content: {
                    VStack(alignment: .leading) {
                        if interaction.isStoryTrainer {
                            Text("Choose one or more words from the title:")
                                .font(font(named: "WhitneySSm-Medium", size: 12))
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
                                cache.appDelegate.toggleTitleClassifier(title.name, feedId: feed?.id, score: 0)
                            }, label: {
                                TrainerCapsule(score: title.score, header: "Title", value: title.name, count: title.count)
                            })
                            .buttonStyle(BorderlessButtonStyle())
                            .padding([.top, .bottom], 5)
                        }
                    }
                }, header: {
                    header(story: "Story Title", feed: "Titles & Phrases")
                })
                
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
                }, header: {
                    header(story: "Story Author", feed: "Authors")
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
                }, header: {
                    header(feed: "Everything by This Publisher")
                })
            }
            .font(font(named: "WhitneySSm-Medium", size: 12))
        }
        .onAppear {
            addingTitle = ""
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
    
    @ViewBuilder
    func header(story: String? = nil, feed: String) -> some View {
        if let story {
            Text(interaction.isStoryTrainer ? story : feed)
                .font(font(named: "WhitneySSm-Medium", size: 16))
        } else {
            Text(feed)
                .font(font(named: "WhitneySSm-Medium", size: 16))
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
}

//#Preview {
//    TrainerViewController()
//}
