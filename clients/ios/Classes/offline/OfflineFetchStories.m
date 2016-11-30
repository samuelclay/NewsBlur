//
//  OfflineFetchStories.m
//  NewsBlur
//
//  Created by Samuel Clay on 7/15/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "OfflineFetchStories.h"
#import "NewsBlurAppDelegate.h"
#import "NewsBlurViewController.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "AFHTTPRequestOperation.h"
#import "SBJson4.h"
#import "NSObject+SBJSON.h"

@implementation OfflineFetchStories

@synthesize appDelegate;

- (void)main {
    appDelegate = [NewsBlurAppDelegate sharedAppDelegate];

    while (YES) {
        BOOL fetched = [self fetchStories];
        if (!fetched) break;
    }
}

- (BOOL)fetchStories {
    if (self.isCancelled) {
        NSLog(@"FetchStories is canceled.");
        return NO;
    }
    
    
    BOOL offlineAllowed = [[[NSUserDefaults standardUserDefaults]
                            objectForKey:@"offline_allowed"] boolValue];
    if (!offlineAllowed ||
        ![appDelegate isReachableForOffline]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [appDelegate.feedsViewController showDoneNotifier];
            [appDelegate.feedsViewController hideNotifier];
        });
        return NO;
    }
    
    NSArray *hashes = [self unfetchedStoryHashes];
    
    if ([hashes count] == 0) {
//        NSLog(@"Finished downloading unread stories. %d total", appDelegate.totalUnfetchedStoryCount);
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![[[NSUserDefaults standardUserDefaults]
                   objectForKey:@"offline_image_download"] boolValue]) {
                [appDelegate.feedsViewController showDoneNotifier];
                [appDelegate.feedsViewController hideNotifier];
                [appDelegate finishBackground];
            } else {
                [appDelegate.feedsViewController showCachingNotifier:0 hoursBack:1];
                [appDelegate startOfflineFetchImages];
            }
        });
        return NO;
    }
    
    __block NSCondition *lock = [NSCondition new];
    __weak __typeof(&*self)weakSelf = self;

    [lock lock];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/reader/river_stories?include_hidden=true&page=0&h=%@",
                                       self.appDelegate.url, [hashes componentsJoinedByString:@"&h="]]];
    if (request) request = nil;

    request = [[AFHTTPRequestOperation alloc] initWithRequest:[NSURLRequest requestWithURL:url]];
    [request setResponseSerializer:[AFJSONResponseSerializer serializer]];
    [request setCompletionBlockWithSuccess:^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject) {
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf storeAllUnreadStories:responseObject withHashes:hashes];
        [lock signal];
    } failure:^(AFHTTPRequestOperation * _Nonnull operation, NSError * _Nonnull error) {
        NSLog(@"Failed fetch all unreads: %@", error);
        [lock signal];
    }];
    [request setCompletionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, (unsigned long)NULL)];

    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [request start];
    [request waitUntilFinished];
    
    [request.outputStream close];
    
    [lock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:30]];
    [lock unlock];
    
    return YES;
}

- (NSArray *)unfetchedStoryHashes {
    NSMutableArray *hashes = [NSMutableArray array];
    __weak __typeof(&*self)weakSelf = self;
    
    [appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *commonQuery = @"FROM unread_hashes u "
        "LEFT OUTER JOIN stories s ON (s.story_hash = u.story_hash) "
        "WHERE s.story_hash IS NULL";
        int count = [db intForQuery:[NSString stringWithFormat:@"SELECT COUNT(1) %@", commonQuery]];
        if (appDelegate.totalUnfetchedStoryCount == 0) {
            appDelegate.totalUnfetchedStoryCount = count;
            appDelegate.remainingUnfetchedStoryCount = appDelegate.totalUnfetchedStoryCount;
        } else {
            appDelegate.remainingUnfetchedStoryCount = count;
        }
        
        int limit = 100;
        NSString *order;
        if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"default_order"] isEqualToString:@"oldest"]) {
            order = @"ASC";
        } else {
            order = @"DESC";
        }
        FMResultSet *cursor = [db executeQuery:[NSString stringWithFormat:@"SELECT u.story_hash %@ ORDER BY u.story_timestamp %@ LIMIT %d", commonQuery, order, limit]];
        
        while ([cursor next]) {
            [hashes addObject:[cursor objectForColumnName:@"story_hash"]];
        }
        
        [cursor close];
        [strongSelf updateProgress];
    }];
    
    return hashes;
}

- (void)updateProgress {
    if (self.isCancelled) return;
    
    int start = (int)[[NSDate date] timeIntervalSince1970];
    int end = appDelegate.latestFetchedStoryDate;
    int seconds = start - (end ? end : start);
    __block int hours = (int)round(seconds / 60.f / 60.f);
    
    __block float progress = 0.f;
    if (appDelegate.totalUnfetchedStoryCount) {
        progress = 1.f - ((float)appDelegate.remainingUnfetchedStoryCount /
                          (float)appDelegate.totalUnfetchedStoryCount);
    }
    __weak __typeof(&*self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
//        NSLog(@"appDelegate.remainingUnfetchedStoryCount %d (%f)", appDelegate.remainingUnfetchedStoryCount, progress);
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        if (!strongSelf) return;
        if (strongSelf.isCancelled) return;
        [appDelegate.feedsViewController showSyncingNotifier:progress hoursBack:hours];
    });
}

- (void)storeAllUnreadStories:(NSDictionary *)results withHashes:(NSArray *)hashes {
    NSMutableArray *storyHashes = [hashes mutableCopy];
    __weak __typeof(&*self)weakSelf = self;

    [appDelegate.database inDatabase:^(FMDatabase *db) {
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        if (!strongSelf) return;
        BOOL anyInserted = NO;
        for (NSDictionary *story in [results objectForKey:@"stories"]) {
            NSString *storyTimestamp = [story objectForKey:@"story_timestamp"];
            BOOL inserted = [db executeUpdate:@"INSERT into stories "
                             "(story_feed_id, story_hash, story_timestamp, story_json) VALUES "
                             "(?, ?, ?, ?)",
                             [story objectForKey:@"story_feed_id"],
                             [story objectForKey:@"story_hash"],
                             storyTimestamp,
                             [story JSONRepresentation]
                             ];
            if ([[story objectForKey:@"image_urls"] class] != [NSNull class] &&
                [[story objectForKey:@"image_urls"] count]) {
                for (NSString *imageUrl in [story objectForKey:@"image_urls"]) {
                    [db executeUpdate:@"INSERT INTO cached_images "
                     "(story_feed_id, story_hash, image_url) VALUES "
                     "(?, ?, ?)",
                     [story objectForKey:@"story_feed_id"],
                     [story objectForKey:@"story_hash"],
                     imageUrl
                     ];
                }
            }
            if (inserted) {
                anyInserted = YES;
                [storyHashes removeObject:[story objectForKey:@"story_hash"]];
            }
            if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"default_order"] isEqualToString:@"oldest"]) {
                if ([storyTimestamp intValue] > appDelegate.latestFetchedStoryDate) {
                    appDelegate.latestFetchedStoryDate = [storyTimestamp intValue];
                }
            } else {
                if (!appDelegate.latestFetchedStoryDate ||
                    [storyTimestamp intValue] < appDelegate.latestFetchedStoryDate) {
                    appDelegate.latestFetchedStoryDate = [storyTimestamp intValue];
                }
            }
            appDelegate.remainingUnfetchedStoryCount--;
            if (appDelegate.remainingUnfetchedStoryCount % 10 == 0) {
                [strongSelf updateProgress];
            }

        }
        if (anyInserted) {
            NSDictionary *lastStory;
            if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"default_order"]
                 isEqualToString:@"oldest"]) {
                lastStory = [[results objectForKey:@"stories"] firstObject];
            } else {
                lastStory = [[results objectForKey:@"stories"] lastObject];
            }
            appDelegate.latestFetchedStoryDate = [[lastStory
                                                   objectForKey:@"story_timestamp"]
                                                  intValue];
        }
        if ([storyHashes count]) {
            NSLog(@"Failed to fetch stories: %@", storyHashes);
            [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM unread_hashes WHERE story_hash IN (\"%@\")",
                               [storyHashes componentsJoinedByString:@"\",\" "]]];
        }
    }];
    
    [appDelegate storeUserProfiles:[results objectForKey:@"user_profiles"]];
}


@end
