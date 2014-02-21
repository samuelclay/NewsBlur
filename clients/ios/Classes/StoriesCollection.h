//
//  StoriesCollection.h
//  NewsBlur
//
//  Created by Samuel Clay on 2/12/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>

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

    BOOL isRiverView;
    BOOL isSocialView;
    BOOL isSocialRiverView;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (readwrite) NSDictionary * activeFeed;
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

@property (nonatomic, readwrite) BOOL isRiverView;
@property (nonatomic, readwrite) BOOL isSocialView;
@property (nonatomic, readwrite) BOOL isSocialRiverView;

- (id)initForDashboard;

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
- (NSString *)orderKey;
- (NSString *)readFilterKey;

- (void)setStories:(NSArray *)activeFeedStoriesValue;
- (void)setFeedUserProfiles:(NSArray *)activeFeedUserProfilesValue;
- (void)addStories:(NSArray *)stories;
- (void)addFeedUserProfiles:(NSArray *)activeFeedUserProfilesValue;
- (void)pushReadStory:(id)storyId;
- (id)popReadStory;

- (void)markStoryRead:(NSString *)storyId feedId:(id)feedId;
- (void)markStoryRead:(NSDictionary *)story feed:(NSDictionary *)feed;
- (void)markStoryUnread:(NSString *)storyId feedId:(id)feedId;
- (void)markStoryUnread:(NSDictionary *)story feed:(NSDictionary *)feed;


@end
