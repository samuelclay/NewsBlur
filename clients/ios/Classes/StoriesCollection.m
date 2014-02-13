//
//  StoriesCollection.m
//  NewsBlur
//
//  Created by Samuel Clay on 2/12/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "StoriesCollection.h"

@implementation StoriesCollection

@synthesize appDelegate;
@synthesize activeFeed;
@synthesize activeClassifiers;
@synthesize activePopularTags;
@synthesize activePopularAuthors;
@synthesize activeFolder;
@synthesize activeFolderFeeds;
@synthesize activeFeedStories;
@synthesize activeFeedStoryLocations;
@synthesize activeFeedStoryLocationIds;
@synthesize activeFeedUserProfiles;
@synthesize storyCount;
@synthesize storyLocationsCount;
@synthesize visibleUnreadCount;

@synthesize isRiverView;
@synthesize isSocialView;
@synthesize isSocialRiverView;


- (id)init {
    if (self = [super init]) {
        self.visibleUnreadCount = 0;
        self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    }

    return self;
}

- (id)initForDashboard {
    if (self = [self init]) {
        
    }
    
    return self;
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
        if (score >= appDelegate.selectedIntelligence || [[story objectForKey:@"sticky"] boolValue]) {
            NSNumber *location = [NSNumber numberWithInt:i];
            [self.activeFeedStoryLocations addObject:location];
            [self.activeFeedStoryLocationIds addObject:[story objectForKey:@"id"]];
            if ([[story objectForKey:@"read_status"] intValue] == 0) {
                self.visibleUnreadCount += 1;
            }
        }
    }
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
        if ([appDelegate.activeStory objectForKey:@"id"] == [story objectForKey:@"id"]) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)indexOfStoryId:(id)storyId {
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [activeFeedStories objectAtIndex:i];
        if ([story objectForKey:@"id"] == storyId) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)locationOfStoryId:(id)storyId {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([activeFeedStoryLocationIds objectAtIndex:i] == storyId) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)locationOfActiveStory {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([[activeFeedStoryLocationIds objectAtIndex:i]
             isEqualToString:[appDelegate.activeStory objectForKey:@"id"]]) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)indexFromLocation:(NSInteger)location {
    if (location == -1) return -1;
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
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *readFilterFeedPrefDefault = [userPreferences stringForKey:@"default_feed_read_filter"];
    NSString *readFilterFolderPrefDefault = [userPreferences stringForKey:@"default_folder_read_filter"];
    NSString *readFilterPref = [userPreferences stringForKey:[self readFilterKey]];
    
    if (readFilterPref) {
        return readFilterPref;
    } else if (self.isRiverView || self.isSocialRiverView) {
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


#pragma mark - Story Management

- (void)addStories:(NSArray *)stories {
    self.activeFeedStories = [self.activeFeedStories arrayByAddingObjectsFromArray:stories];
    self.storyCount = [self.activeFeedStories count];
    [self calculateStoryLocations];
    self.storyLocationsCount = [self.activeFeedStoryLocations count];
}

- (void)setStories:(NSArray *)activeFeedStoriesValue {
    self.activeFeedStories = activeFeedStoriesValue;
    self.storyCount = [self.activeFeedStories count];
    appDelegate.recentlyReadFeeds = [NSMutableSet set];
    [self calculateStoryLocations];
    self.storyLocationsCount = [self.activeFeedStoryLocations count];
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

@end
