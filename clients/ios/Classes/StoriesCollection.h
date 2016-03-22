//
//  StoriesCollection.h
//  NewsBlur
//
//  Created by Samuel Clay on 2/12/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"

@interface StoriesCollection : NSObject {
    NSDictionary * activeFeed;
    NSString * activeFolder;
    NSArray * activeFolderFeeds;
    NSArray * activeFeedStories;
    NSArray * activeFeedUserProfiles;
    NSMutableArray * activeFeedStoryLocations;
    NSMutableArray * activeFeedStoryLocationIds;
    NSMutableDictionary * activeClassifiers;
    NSArray * activePopularTags;
    NSArray * activePopularAuthors;
    int storyCount;
    int storyLocationsCount;
    int visibleUnreadCount;
    int feedPage;

    BOOL isRiverView;
    BOOL isSocialView;
    BOOL isSocialRiverView;
    BOOL transferredFromDashboard;
    BOOL inSearch;
    NSString *searchQuery;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (readwrite) NSDictionary * activeFeed;
@property (nonatomic) NSString * activeSavedStoryTag;
@property (readwrite) NSString * activeFolder;
@property (readwrite) NSArray * activeFolderFeeds;
@property (readwrite) NSArray * activeFeedStories;
@property (readwrite) NSArray * activeFeedUserProfiles;
@property (readwrite) NSMutableArray * activeFeedStoryLocations;
@property (readwrite) NSMutableArray * activeFeedStoryLocationIds;
@property (strong, readwrite) NSMutableDictionary * activeClassifiers;
@property (strong, readwrite) NSArray * activePopularTags;
@property (strong, readwrite) NSArray * activePopularAuthors;
@property (readwrite) int storyCount;
@property (readwrite) int storyLocationsCount;
@property (readwrite) int visibleUnreadCount;
@property (nonatomic, readwrite) int feedPage;

@property (nonatomic, readwrite) BOOL isRiverView;
@property (nonatomic, readwrite) BOOL isSocialView;
@property (nonatomic, readwrite) BOOL isSocialRiverView;
@property (nonatomic, readwrite) BOOL isSavedView;
@property (nonatomic, readwrite) BOOL isReadView;
@property (nonatomic, readwrite) BOOL transferredFromDashboard;
@property (nonatomic, readwrite) BOOL inSearch;
@property (nonatomic) NSString *searchQuery;

- (id)initForDashboard;
- (void)reset;
- (void)transferStoriesFromCollection:(StoriesCollection *)fromCollection;

- (BOOL)isStoryUnread:(NSDictionary *)story;
- (void)calculateStoryLocations;
- (NSInteger)indexOfNextUnreadStory;
- (NSInteger)locationOfNextUnreadStory;
- (NSInteger)indexOfNextStory;
- (NSInteger)locationOfNextStory;
- (NSInteger)indexOfActiveStory;
- (NSInteger)indexOfStoryId:(id)storyId;
- (NSInteger)locationOfActiveStory;
- (NSInteger)indexFromLocation:(NSInteger)location;
- (NSInteger)locationOfStoryId:(id)storyId;
- (NSString *)activeOrder;
- (NSString *)activeReadFilter;
- (NSString *)activeStoryView;
- (NSString *)orderKey;
- (NSString *)readFilterKey;
- (NSString *)storyViewKey;

- (void)setStories:(NSArray *)activeFeedStoriesValue;
- (void)setFeedUserProfiles:(NSArray *)activeFeedUserProfilesValue;
- (void)addStories:(NSArray *)stories;
- (void)addFeedUserProfiles:(NSArray *)activeFeedUserProfilesValue;
- (void)pushReadStory:(id)storyId;
- (id)popReadStory;

- (void)syncStoryAsRead:(NSDictionary *)story;
- (void)syncStoryAsUnread:(NSDictionary *)story;

- (void)toggleStoryUnread;
- (void)toggleStoryUnread:(NSDictionary *)story;
- (void)markStoryRead:(NSDictionary *)story;
- (void)markStoryRead:(NSString *)storyId feedId:(id)feedId;
- (void)markStoryRead:(NSDictionary *)story feed:(NSDictionary *)feed;
- (void)markStoryUnread:(NSDictionary *)story;
- (void)markStoryUnread:(NSString *)storyId feedId:(id)feedId;
- (void)markStoryUnread:(NSDictionary *)story feed:(NSDictionary *)feed;

- (NSDictionary *)markStory:(NSDictionary *)story asSaved:(BOOL)saved;
- (NSDictionary *)markStory:(NSDictionary *)story asSaved:(BOOL)saved forceUpdate:(BOOL)forceUpdate;
- (void)toggleStorySaved;
- (BOOL)toggleStorySaved:(NSDictionary *)story;
- (void)syncStoryAsSaved:(NSDictionary *)story;
- (void)finishMarkAsSaved:(ASIFormDataRequest *)request;
- (void)failedMarkAsSaved:(ASIFormDataRequest *)request;
- (void)syncStoryAsUnsaved:(NSDictionary *)story;
- (void)finishMarkAsUnsaved:(ASIFormDataRequest *)request;
- (void)failedMarkAsUnsaved:(ASIFormDataRequest *)request;

@end
