//
//  StoriesCollection.m
//  NewsBlur
//
//  Created by Samuel Clay on 2/12/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "StoriesCollection.h"
#import "SBJson4.h"
#import "NSObject+SBJSON.h"
#import "FMDatabase.h"
#import "Utilities.h"

@interface StoriesCollection ()

@property (nonatomic, strong) NSMutableDictionary *recentlyReadHashes;

@end

@implementation StoriesCollection

@synthesize appDelegate;
@synthesize activeFeed;
@synthesize activeClassifiers;
@synthesize activePopularTags;
@synthesize activePopularAuthors;
@synthesize activeSavedStoryTag;
@synthesize activeFolder;
@synthesize activeFolderFeeds;
@synthesize activeFeedStories;
@synthesize activeFeedStoryLocations;
@synthesize activeFeedStoryLocationIds;
@synthesize activeFeedUserProfiles;
@synthesize storyCount;
@synthesize storyLocationsCount;
@synthesize visibleUnreadCount;
@synthesize feedPage;

@synthesize isRiverView;
@synthesize isSocialView;
@synthesize isSocialRiverView;
@synthesize isSavedView;
@synthesize isReadView;
@synthesize transferredFromDashboard;
@synthesize inSearch;
@synthesize searchQuery;

- (id)init {
    if (self = [super init]) {
        self.visibleUnreadCount = 0;
        self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
        self.activeClassifiers = [NSMutableDictionary dictionary];
        self.recentlyReadHashes = [NSMutableDictionary dictionary];
    }

    return self;
}

- (id)initForDashboard {
    if (self = [self init]) {
        
    }
    
    return self;
}

- (void)reset {
    [self setStories:nil];
    [self setFeedUserProfiles:nil];

    self.feedPage = 1;
    self.activeFeed = nil;
    self.activeSavedStoryTag = nil;
    self.activeFolder = nil;
    self.activeFolderFeeds = nil;
    self.activeClassifiers = [NSMutableDictionary dictionary];
    
    self.transferredFromDashboard = NO;
    self.isRiverView = NO;
    self.isSocialView = NO;
    self.isSocialRiverView = NO;
    self.isSavedView = NO;
    self.isReadView = NO;
    self.isWidgetView = NO;
}

- (void)transferStoriesFromCollection:(StoriesCollection *)fromCollection {
    self.feedPage = fromCollection.feedPage;
    [self setStories:fromCollection.activeFeedStories];
    [self setFeedUserProfiles:fromCollection.activeFeedUserProfiles];
    self.activeFolderFeeds = fromCollection.activeFolderFeeds;
    self.activeClassifiers = fromCollection.activeClassifiers;
    self.inSearch = fromCollection.inSearch;
    self.searchQuery = fromCollection.searchQuery;
    self.savedSearchQuery = fromCollection.savedSearchQuery;
}

#pragma mark - Story Traversal

- (BOOL)isStoryUnread:(NSDictionary *)story {
    BOOL readStatusUnread = [[story objectForKey:@"read_status"] intValue] == 0;
    BOOL storyHashUnread = [[appDelegate.unreadStoryHashes
                             objectForKey:[story objectForKey:@"story_hash"]] boolValue];
    BOOL recentlyRead = [[appDelegate.recentlyReadStories
                          objectForKey:[story objectForKey:@"story_hash"]] boolValue];
    
    //    NSLog(@"isUnread: (%d || %d) && %d (%@ / %@)", readStatusUnread, storyHashUnread,
    //          !recentlyRead, [[story objectForKey:@"story_title"] substringToIndex:10],
    //          [story objectForKey:@"story_hash"]);
    
    return (readStatusUnread || storyHashUnread) && !recentlyRead;
}

- (void)calculateStoryLocations {
    self.visibleUnreadCount = 0;
    self.activeFeedStoryLocations = [NSMutableArray array];
    self.activeFeedStoryLocationIds = [NSMutableArray array];
    
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [self.activeFeedStories objectAtIndex:i];
        NSInteger score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
        BOOL want = NO;
        if (self.showHiddenStories) {
            want = YES;
        } else if (self.appDelegate.isSavedStoriesIntelligenceMode) {
            want = [story[@"starred"] boolValue];
        } else {
            want = score >= appDelegate.selectedIntelligence || [[story objectForKey:@"sticky"] boolValue];
        }
        
        if (want) {
            NSNumber *location = [NSNumber numberWithInt:i];
            [self.activeFeedStoryLocations addObject:location];
            [self.activeFeedStoryLocationIds addObject:[story objectForKey:@"story_hash"]];
            if ([[story objectForKey:@"read_status"] intValue] == 0) {
                self.visibleUnreadCount += 1;
            }
        }
    }
    self.storyLocationsCount = (int)[self.activeFeedStoryLocations count];
}

- (NSInteger)indexOfNextUnreadStory {
    NSInteger location = [self locationOfNextUnreadStory];
    return [self indexFromLocation:location];
}

- (NSInteger)locationOfNextUnreadStory {
    NSInteger activeLocation = [self locationOfActiveStory];
    
    for (NSInteger i=activeLocation+1; i < [self.activeFeedStoryLocations count]; i++) {
        NSInteger storyIndex = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
        NSDictionary *story = [activeFeedStories objectAtIndex:storyIndex];
        if ([self isStoryUnread:story]) {
            return i;
        }
    }
    if (activeLocation > 0) {
        for (NSInteger i=activeLocation-1; i >= 0; i--) {
            NSInteger storyIndex = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
            NSDictionary *story = [activeFeedStories objectAtIndex:storyIndex];
            if ([self isStoryUnread:story]) {
                return i;
            }
        }
    }
    return -1;
}

- (NSInteger)indexOfNextStory {
    NSInteger location = [self locationOfNextStory];
    return [self indexFromLocation:location];
}

- (NSInteger)locationOfNextStory {
    NSInteger activeLocation = [self locationOfActiveStory];
    NSInteger nextStoryLocation = activeLocation + 1;
    if (nextStoryLocation < [self.activeFeedStoryLocations count]) {
        return nextStoryLocation;
    }
    return -1;
}

- (NSInteger)indexOfActiveStory {
    for (NSInteger i=0; i < self.storyCount; i++) {
        NSDictionary *story = [activeFeedStories objectAtIndex:i];
        if ([[appDelegate.activeStory objectForKey:@"story_hash"] isEqualToString:[story objectForKey:@"story_hash"]]) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)indexOfStoryId:(id)storyId {
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [activeFeedStories objectAtIndex:i];
        if ([[story objectForKey:@"story_hash"] isEqualToString:storyId]) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)locationOfStoryId:(id)storyId {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([[activeFeedStoryLocationIds objectAtIndex:i] isEqualToString:storyId]) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)locationOfActiveStory {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([[activeFeedStoryLocationIds objectAtIndex:i]
             isEqualToString:[appDelegate.activeStory objectForKey:@"story_hash"]]) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)indexFromLocation:(NSInteger)location {
    if (location == -1) return -1;
    if (location >= [activeFeedStoryLocations count]) return -1;
    return [[activeFeedStoryLocations objectAtIndex:location] intValue];
}

- (NSString *)activeOrder {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *orderPrefDefault = [userPreferences stringForKey:@"default_order"];
    NSString *orderPref = [userPreferences stringForKey:[self orderKey]];
    
    if (orderPref) {
        return orderPref;
    } else if (orderPrefDefault) {
        return orderPrefDefault;
    } else {
        return @"newest";
    }
}

- (NSString *)activeReadFilter {
    if (self.appDelegate.isSavedStoriesIntelligenceMode) {
        return @"starred";
    }
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *readFilterFeedPrefDefault = [userPreferences stringForKey:@"default_feed_read_filter"];
    NSString *readFilterFolderPrefDefault = [userPreferences stringForKey:@"default_folder_read_filter"];
    NSString *readFilterPref = [userPreferences stringForKey:[self readFilterKey]];
    
    if (readFilterPref) {
        return readFilterPref;
    } else if (self.activeFolder && (self.isRiverView || self.isSocialRiverView)) {
        if (readFilterFolderPrefDefault) {
            return readFilterFolderPrefDefault;
        } else {
            return @"unread";
        }
    } else {
        if (readFilterFeedPrefDefault) {
            return readFilterFeedPrefDefault;
        } else {
            return @"all";
        }
    }
}

- (NSString *)activeStoryView {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *storyViewPref = [userPreferences stringForKey:[self storyViewKey]];
//    NSLog(@"Story pref: %@ (%d)", storyViewPref, self.isRiverView);
    if (storyViewPref) {
        return storyViewPref;
    } else {
        return @"story";
    }
}

- (NSString *)orderKey {
    if (self.isRiverView) {
        return [NSString stringWithFormat:@"folder:%@:order", self.activeFolder];
    } else {
        return [NSString stringWithFormat:@"%@:order", [self.activeFeed objectForKey:@"id"]];
    }
}

- (NSString *)readFilterKey {
    if (self.isRiverView) {
        return [NSString stringWithFormat:@"folder:%@:read_filter", self.activeFolder];
    } else {
        return [NSString stringWithFormat:@"%@:read_filter", [self.activeFeed objectForKey:@"id"]];
    }
}

- (NSString *)scrollReadFilterKey {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    BOOL shouldOverride = [userPreferences boolForKey:@"override_scroll_read_filter"];
    
    if (!shouldOverride) {
        return @"default_scroll_read_filter";
    } else if (self.isRiverView) {
        return [NSString stringWithFormat:@"folder:%@:scroll_read_filter", self.activeFolder];
    } else {
        return [NSString stringWithFormat:@"%@:scroll_read_filter", [self.activeFeed objectForKey:@"id"]];
    }
}

- (NSString *)storyViewKey {
    if (self.isRiverView) {
        return [NSString stringWithFormat:@"folder:%@:story_view", self.activeFolder];
    } else {
        return [NSString stringWithFormat:@"%@:story_view", [self.activeFeed objectForKey:@"id"]];
    }
}

- (NSString *)activeTitle {
    if (isRiverView) {
        if ([activeFolder isEqualToString:@"river_blurblogs"]) {
            return @"All Shared Stories";
        } else if ([activeFolder isEqualToString:@"river_global"]) {
            return @"Global Shared Stories";
        } else if ([activeFolder isEqualToString:@"everything"]) {
            return @"All Site Stories";
        } else if ([activeFolder isEqualToString:@"infrequent"]) {
            return @"Infrequent Site Stories";
        } else if (isSavedView && activeSavedStoryTag) {
            return activeSavedStoryTag;
        } else if ([activeFolder isEqualToString:@"widget_stories"]) {
            return @"Widget Site Stories";
        } else if ([activeFolder isEqualToString:@"read_stories"]) {
            return @"Read Stories";
        } else if ([activeFolder isEqualToString:@"saved_searches"]) {
            return @"Saved Searches";
        } else if ([activeFolder isEqualToString:@"saved_stories"]) {
            return @"Saved Stories";
        } else {
            return activeFolder;
        }
    } else {
        return [activeFeed objectForKey:@"feed_title"];
    }
}

#pragma mark - Story Management

- (void)addStories:(NSArray *)stories {
    self.activeFeedStories = [self.activeFeedStories arrayByAddingObjectsFromArray:stories];
    self.storyCount = (int)[self.activeFeedStories count];
    [self calculateStoryLocations];
    self.storyLocationsCount = (int)[self.activeFeedStoryLocations count];
}

- (void)setStories:(NSArray *)activeFeedStoriesValue {
    self.activeFeedStories = activeFeedStoriesValue;
    self.storyCount = (int)[self.activeFeedStories count];
    appDelegate.recentlyReadFeeds = [NSMutableSet set];
    [self calculateStoryLocations];
    self.storyLocationsCount = (int)[self.activeFeedStoryLocations count];
}

- (void)setFeedUserProfiles:(NSArray *)activeFeedUserProfilesValue{
    self.activeFeedUserProfiles = activeFeedUserProfilesValue;
}

- (void)addFeedUserProfiles:(NSArray *)activeFeedUserProfilesValue {
    self.activeFeedUserProfiles = [self.activeFeedUserProfiles arrayByAddingObjectsFromArray:activeFeedUserProfilesValue];
}

- (void)pushReadStory:(id)storyId {
    if ([appDelegate.readStories lastObject] != storyId) {
        [appDelegate.readStories addObject:storyId];
    }
}

- (id)popReadStory {
    if (storyCount == 0) {
        return nil;
    } else {
        [appDelegate.readStories removeLastObject];
        id lastStory = [appDelegate.readStories lastObject];
        return lastStory;
    }
}


#pragma mark -
#pragma mark Story Actions - read on server

- (void)syncStoryAsRead:(NSDictionary *)story {
    if (!story) {
        NSLog(@" ***> ERROR: No story found for syncStoryAsRead!");
        return;
    }
    NSString *hash = story[@"story_hash"];
    NSString *title = story[@"story_title"];
    
    if (self.recentlyReadHashes[hash]) {
        NSLog(@"🔧 trying to sync as read when already read: %@: %@", hash, title);  // log
        return;
    }
    self.recentlyReadHashes[hash] = [NSString stringWithFormat:@"IN PROGRESS - %@", title];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_story_hashes_as_read",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:hash
               forKey:@"story_hash"];
    [params setObject:[story objectForKey:@"story_feed_id"]
               forKey:@"story_feed_id"];
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        self.recentlyReadHashes[hash] = [NSString stringWithFormat:@"SYNCED - %@", title];
        [self finishMarkAsRead:responseObject];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        self.recentlyReadHashes[hash] = nil;
        [self failedMarkAsRead:params];
    }];
}

- (void)finishMarkAsRead:(NSDictionary *)results {

}

- (void)failedMarkAsRead:(NSDictionary *)params {
    NSString *storyFeedId = [params objectForKey:@"story_feed_id"];
    NSString *storyHash = [params objectForKey:@"story_hash"];
    
    [appDelegate queueReadStories:@{storyFeedId: @[storyHash]}];
}

- (void)syncStoryAsUnread:(NSDictionary *)story {
    NSString *hash = story[@"story_hash"];
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_story_as_unread",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    [params setObject:hash
                   forKey:@"story_id"];
    [params setObject:[story objectForKey:@"story_feed_id"]
                   forKey:@"feed_id"];
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishMarkAsUnread:responseObject];
        self.recentlyReadHashes[hash] = nil;
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self failedMarkAsUnread:params];
    }];
}

- (void)finishMarkAsUnread:(NSDictionary *)results {
    
}

- (void)failedMarkAsUnread:(NSDictionary *)params {
    NSString *storyFeedId = [params objectForKey:@"story_feed_id"];
    NSString *storyHash = [params objectForKey:@"story_hash"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        BOOL dequeued = [self.appDelegate dequeueReadStoryHash:storyHash inFeed:storyFeedId];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!dequeued) {
                // Offline means can't unread a story unless it was read while offline.
                [self markStoryRead:storyHash feedId:storyFeedId];
        //        [self.storyTitlesTable reloadData];
                [self.appDelegate failedMarkAsUnread:params];
            } else {
                // Offline but read story while offline, so it never touched the server.
                [self.appDelegate.unreadStoryHashes setObject:[NSNumber numberWithBool:YES] forKey:storyHash];
        //        [self.storyTitlesTable reloadData];
            }
        });
    });
}

#pragma mark - Story Actions

- (void)toggleStoryUnread {
    [self toggleStoryUnread:appDelegate.activeStory];
}

- (void)toggleStoryUnread:(NSDictionary *)story {
    BOOL isUnread = [self isStoryUnread:story];
    if (!isUnread) {
        [self markStoryUnread:story];
        [self syncStoryAsUnread:story];
    } else {
        [self markStoryRead:story];
        [self syncStoryAsRead:story];
    }
}

- (void)markStoryRead:(NSDictionary *)story {
    [self markStoryRead:[story objectForKey:@"story_hash"] feedId:[story objectForKey:@"story_feed_id"]];
}

- (void)markStoryRead:(NSString *)storyId feedId:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [appDelegate getFeed:feedIdStr];
    NSDictionary *story = nil;
    for (NSDictionary *s in self.activeFeedStories) {
        if ([[s objectForKey:@"story_hash"] isEqualToString:storyId]) {
            story = s;
            break;
        }
    }
    [self markStoryRead:story feed:feed];
    
    NSArray *otherFriendShares = [story objectForKey:@"shared_by_friends"];
    if ([otherFriendShares count]) {
        NSLog(@"Shared by friends: %@", otherFriendShares);
    }
    
    // decrement all other friend feeds if they have the same story
    if (![feedIdStr hasPrefix:@"social:"]) {
        for (int i = 0; i < otherFriendShares.count; i++) {
            feedIdStr = [NSString stringWithFormat:@"social:%@",
                         [otherFriendShares objectAtIndex:i]];
            NSDictionary *feed = [appDelegate getFeed:feedIdStr];
            [self markStoryRead:story feed:feed];
        }
    }
}

- (void)markStoryRead:(NSDictionary *)story feed:(NSDictionary *)feed {
    NSString *feedIdStr;
    if (feed) {
        feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
    } else {
        feedIdStr = @"0";
    }
    
    NSMutableDictionary *newStory = [story mutableCopy];
    [newStory setValue:[NSNumber numberWithInt:1] forKey:@"read_status"];
    
    if ([[appDelegate.activeStory objectForKey:@"story_hash"]
         isEqualToString:[newStory objectForKey:@"story_hash"]]) {
        appDelegate.activeStory = newStory;
    }
    
    // make the story as read in self.activeFeedStories
    NSString *newStoryIdStr = [NSString stringWithFormat:@"%@", [newStory valueForKey:@"story_hash"]];
    [self replaceStory:newStory withId:newStoryIdStr];
    
    id storyFeedId = [newStory objectForKey:@"story_feed_id"];
    
    // If not a feed, then don't bother updating local feed
    if (!feed || !storyFeedId) return;
    
    self.visibleUnreadCount -= 1;
    if (![appDelegate.recentlyReadFeeds containsObject:storyFeedId]) {
        [appDelegate.recentlyReadFeeds addObject:storyFeedId];
    }
    
    NSDictionary *unreadCounts = [appDelegate.dictUnreadCounts objectForKey:feedIdStr];
    if (unreadCounts) {
        NSMutableDictionary *newUnreadCounts = [unreadCounts mutableCopy];
        NSInteger score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
        if (score > 0) {
            int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ps"] intValue] - 1);
            [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ps"];
        } else if (score == 0) {
            int unreads = MAX(0, [[newUnreadCounts objectForKey:@"nt"] intValue] - 1);
            [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"nt"];
        } else if (score < 0) {
            int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ng"] intValue] - 1);
            [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ng"];
        }
        [appDelegate.dictUnreadCounts setObject:newUnreadCounts forKey:feedIdStr];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                 (unsigned long)NULL), ^(void) {
            [self.appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
                NSString *storyHash = [newStory objectForKey:@"story_hash"];
                [db executeUpdate:@"UPDATE stories SET story_json = ? WHERE story_hash = ?",
                 [newStory JSONRepresentation],
                 storyHash];
                [db executeUpdate:@"DELETE FROM unread_hashes WHERE story_hash = ?",
                 storyHash];
                [db executeUpdate:@"UPDATE unread_counts SET ps = ?, nt = ?, ng = ? WHERE feed_id = ?",
                 [newUnreadCounts objectForKey:@"ps"],
                 [newUnreadCounts objectForKey:@"nt"],
                 [newUnreadCounts objectForKey:@"ng"],
                 feedIdStr];
            }];
        });
        
        [appDelegate.recentlyReadStories setObject:[NSNumber numberWithBool:YES]
                                            forKey:[story objectForKey:@"story_hash"]];
        [appDelegate.unreadStoryHashes removeObjectForKey:[story objectForKey:@"story_hash"]];
    }
    [appDelegate finishMarkAsRead:story];
}

- (void)replaceStory:(NSDictionary *)newStory withId:(NSString *)newStoryIdStr {
    NSMutableArray *newActiveFeedStories = [self.activeFeedStories mutableCopy];
    for (int i = 0; i < [newActiveFeedStories count]; i++) {
        NSMutableArray *thisStory = [[newActiveFeedStories objectAtIndex:i] mutableCopy];
        NSString *thisStoryIdStr = [NSString stringWithFormat:@"%@", [thisStory valueForKey:@"story_hash"]];
        if ([newStoryIdStr isEqualToString:thisStoryIdStr]) {
            [newActiveFeedStories replaceObjectAtIndex:i withObject:newStory];
            break;
        }
    }
    self.activeFeedStories = newActiveFeedStories;
}

- (void)markStoryUnread:(NSDictionary *)story {
    [self markStoryUnread:[story objectForKey:@"story_hash"]
                   feedId:[story objectForKey:@"story_feed_id"]];
}

- (void)markStoryUnread:(NSString *)storyId feedId:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [appDelegate getFeed:feedIdStr];
    NSDictionary *story = nil;
    for (NSDictionary *s in self.activeFeedStories) {
        if ([[s objectForKey:@"story_hash"] isEqualToString:storyId]) {
            story = s;
            break;
        }
    }
    [self markStoryUnread:story feed:feed];
    
    NSArray *otherFriendShares = [story objectForKey:@"shared_by_friends"];
    if ([otherFriendShares count]) {
        NSLog(@"Shared by friends: %@", otherFriendShares);
    }
    
    // decrement all other friend feeds if they have the same story
    if (![feedIdStr hasPrefix:@"social:"]) {
        for (int i = 0; i < otherFriendShares.count; i++) {
            feedIdStr = [NSString stringWithFormat:@"social:%@",
                         [otherFriendShares objectAtIndex:i]];
            NSDictionary *feed = [appDelegate getFeed:feedIdStr];
            [self markStoryUnread:story feed:feed];
        }
    }
}

- (void)markStoryUnread:(NSDictionary *)story feed:(NSDictionary *)feed {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
    if (!feed) {
        feedIdStr = @"0";
    }
        
    NSMutableDictionary *newStory = [story mutableCopy];
    [newStory setValue:[NSNumber numberWithInt:0] forKey:@"read_status"];
    
    if ([[appDelegate.activeStory objectForKey:@"story_hash"]
         isEqualToString:[newStory objectForKey:@"story_hash"]]) {
        appDelegate.activeStory = newStory;
    }
    
    // make the story as read in self.activeFeedStories
    NSString *newStoryIdStr = [NSString stringWithFormat:@"%@", [newStory valueForKey:@"story_hash"]];
    [self replaceStory:newStory withId:newStoryIdStr];

    // If not a feed, then don't bother updating local feed.
    if (!feed) return;
    
    self.visibleUnreadCount += 1;
    //    if ([self.recentlyReadFeeds containsObject:[newStory objectForKey:@"story_feed_id"]]) {
    [appDelegate.recentlyReadFeeds removeObject:[newStory objectForKey:@"story_feed_id"]];
    //    }
    
    NSDictionary *unreadCounts = [appDelegate.dictUnreadCounts objectForKey:feedIdStr];
    NSMutableDictionary *newUnreadCounts = [unreadCounts mutableCopy];
    NSInteger score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    if (score > 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ps"] intValue] + 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ps"];
    } else if (score == 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"nt"] intValue] + 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"nt"];
    } else if (score < 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ng"] intValue] + 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ng"];
    }
    if (newUnreadCounts) {
        [appDelegate.dictUnreadCounts setObject:newUnreadCounts forKey:feedIdStr];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                 (unsigned long)NULL), ^(void) {
            [self.appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
                NSString *storyHash = [newStory objectForKey:@"story_hash"];
                [db executeUpdate:@"UPDATE stories SET story_json = ? WHERE story_hash = ?",
                 [newStory JSONRepresentation],
                 storyHash];
                [db executeUpdate:@"INSERT INTO unread_hashes "
                 "(story_hash, story_feed_id, story_timestamp) VALUES (?, ?, ?)",
                 storyHash, feedIdStr, [newStory objectForKey:@"story_timestamp"]];
                [db executeUpdate:@"UPDATE unread_counts SET ps = ?, nt = ?, ng = ? WHERE feed_id = ?",
                 [newUnreadCounts objectForKey:@"ps"],
                 [newUnreadCounts objectForKey:@"nt"],
                 [newUnreadCounts objectForKey:@"ng"],
                 feedIdStr];
            }];
        });

        [appDelegate.recentlyReadStories removeObjectForKey:[story objectForKey:@"story_hash"]];
    }
    [appDelegate finishMarkAsUnread:story];
}

#pragma mark - Saved Stories

- (void)toggleStorySaved {
    [self toggleStorySaved:appDelegate.activeStory];
}

- (BOOL)toggleStorySaved:(NSDictionary *)story {
    BOOL isSaved = [[story objectForKey:@"starred"] boolValue];
    
    if (isSaved) {
        story = [self markStory:story asSaved:NO];
        [self syncStoryAsUnsaved:story];
    } else {
        story = [self markStory:story asSaved:YES];
        [self syncStoryAsSaved:story];
    }
    
    return !isSaved;
}

- (NSDictionary *)markStory:(NSDictionary *)story asSaved:(BOOL)saved {
    return [self markStory:story asSaved:saved forceUpdate:NO];
}
    
- (NSDictionary *)markStory:(NSDictionary *)story asSaved:(BOOL)saved forceUpdate:(BOOL)forceUpdate {
    BOOL firstSaved = NO;
    NSMutableDictionary *newStory = [story mutableCopy];
    BOOL isSaved = [[story objectForKey:@"starred"] boolValue];
    if (isSaved == saved && !forceUpdate) {
        return newStory;
    }
    [newStory setValue:[NSNumber numberWithBool:saved] forKey:@"starred"];
    if (saved && ![newStory objectForKey:@"starred_date"]) {
        [newStory setObject:[Utilities formatLongDateFromTimestamp:0] forKey:@"starred_date"];
        appDelegate.savedStoriesCount += 1;
        firstSaved = YES;
    } else if (!saved) {
        [newStory removeObjectForKey:@"starred_date"];
        appDelegate.savedStoriesCount -= 1;
    }
    
    if ([[newStory objectForKey:@"story_hash"]
         isEqualToString:[appDelegate.activeStory objectForKey:@"story_hash"]]) {
        appDelegate.activeStory = newStory;
    }
    
    // Add folder tags if no user tags
    if (![story objectForKey:@"user_tags"]) {
        NSArray *parentFolders = [appDelegate parentFoldersForFeed:[story objectForKey:@"story_feed_id"]];
        NSLog(@"Saving in folders: %@", parentFolders);
        [newStory setObject:parentFolders forKey:@"user_tags"];
    }

    // Fake increased count on saved tags if saving for the first time,
    // will be recounted when save request returns
    if (firstSaved) {
        for (NSString *userTag in [newStory objectForKey:@"user_tags"]) {
            [appDelegate adjustSavedStoryCount:userTag direction:(saved ? 1 : -1)];
        }
    }

    // make the story as read in self.activeFeedStories
    NSString *newStoryIdStr = [NSString stringWithFormat:@"%@", [newStory valueForKey:@"story_hash"]];
    [self replaceStory:newStory withId:newStoryIdStr];
    
    return newStory;
}

- (void)syncStoryAsSaved:(NSDictionary *)story {
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_story_as_starred",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSString *storyHash = [story objectForKey:@"story_hash"];
    NSString *storyFeedId = [story objectForKey:@"story_feed_id"];
    NSMutableArray *tags = [NSMutableArray array];
    for (NSString *userTag in [story objectForKey:@"user_tags"]) {
        [tags addObject:userTag];
    }
    
    [params setObject:storyHash forKey:@"story_id"];
    [params setObject:storyFeedId forKey:@"feed_id"];
    [params setObject:tags forKey:@"user_tags"];
    
    [self.appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishMarkAsSaved:responseObject withParams:params];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self.appDelegate queueSavedStory:story];
    }];
}

- (void)finishMarkAsSaved:(NSDictionary *)results withParams:(NSDictionary *)params {
    [self updateSavedStoryCounts:results withParams:params];
    
    [self.appDelegate finishMarkAsSaved:params];
}

- (void)updateSavedStoryCounts:(NSDictionary *)results withParams:(NSDictionary *)params {
    NSArray *savedStories = [self.appDelegate updateStarredStoryCounts:results];
    NSMutableDictionary *allFolders = [self.appDelegate.dictFolders mutableCopy];
    [allFolders setValue:savedStories forKey:@"saved_stories"];
    self.appDelegate.dictFolders = allFolders;
}

- (void)syncStoryAsUnsaved:(NSDictionary *)story {
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_story_as_unstarred",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSString *storyHash = [story objectForKey:@"story_hash"];
    NSString *storyFeedId = [story objectForKey:@"story_feed_id"];
    
    [params setObject:storyHash forKey:@"story_id"];
    [params setObject:storyFeedId forKey:@"feed_id"];
    
    [self.appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishMarkAsUnsaved:responseObject withParams:params];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self.appDelegate queueSavedStory:story];
    }];
}

- (void)finishMarkAsUnsaved:(NSDictionary *)results withParams:(NSDictionary *)params {
    [self updateSavedStoryCounts:results withParams:params];
    [self.appDelegate finishMarkAsUnsaved:params];
}

- (void)failedMarkAsUnsaved:(NSDictionary *)params {
    NSString *storyFeedId = [params objectForKey:@"story_feed_id"];
    NSString *storyHash = [params objectForKey:@"story_hash"];
    BOOL dequeued = [self.appDelegate dequeueReadStoryHash:storyHash inFeed:storyFeedId];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!dequeued) {
            // Offline means can't unsave a story unless it was saved while offline.
            NSDictionary *story = [self.appDelegate getStory:storyHash];
            
            if (story) {
                [self markStory:story asSaved:NO];
                [self.appDelegate failedMarkAsUnsaved:params];
            }
        } else {
            // Offline but saved story while offline, so it never touched the server.
            [self.appDelegate.unsavedStoryHashes setObject:[NSNumber numberWithBool:YES] forKey:storyHash];
        }
    });
}

@end
