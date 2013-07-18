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
#import "AFJSONRequestOperation.h"
#import "JSON.h"

@implementation OfflineFetchStories

@synthesize appDelegate;

- (void)main {
    appDelegate = [NewsBlurAppDelegate sharedAppDelegate];

    while (YES) {
        BOOL fetched = [self fetchStories];
        NSLog(@"Fetched: %d", fetched);
        if (!fetched) break;
    }
}

- (BOOL)fetchStories {
    if (self.isCancelled) {
        NSLog(@"FetchStories is canceled.");
        return NO;
    }
    
    
    if (![[[NSUserDefaults standardUserDefaults]
           objectForKey:@"offline_allowed"] boolValue]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [appDelegate.feedsViewController showDoneNotifier];
            [appDelegate.feedsViewController hideNotifier];
        });
        return NO;
    }
    NSLog(@"Fetching Stories...");
    
    NSArray *hashes = [self unfetchedStoryHashes];
    
    if ([hashes count] == 0) {
        NSLog(@"Finished downloading unread stories. %d total", appDelegate.totalUnfetchedStoryCount);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![[[NSUserDefaults standardUserDefaults]
                   objectForKey:@"offline_image_download"] boolValue]) {
                [appDelegate.feedsViewController showDoneNotifier];
                [appDelegate.feedsViewController hideNotifier];
            } else {
                [appDelegate.feedsViewController showCachingNotifier:0 hoursBack:1];
                [appDelegate startOfflineFetchImages];
            }
        });
        return NO;
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/reader/river_stories?page=0&h=%@",
                                       NEWSBLUR_URL, [hashes componentsJoinedByString:@"&h="]]];
    AFJSONRequestOperation *request = [AFJSONRequestOperation
                                       JSONRequestOperationWithRequest:[NSURLRequest requestWithURL:url]
                                       success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                                           [self storeAllUnreadStories:JSON withHashes:hashes];
                                       } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                                           NSLog(@"Failed fetch all unreads.");
                                       }];
    request.successCallbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                             (unsigned long)NULL);
    [request start];
    [request waitUntilFinished];
    
    return YES;
}

- (NSArray *)unfetchedStoryHashes {
    NSMutableArray *hashes = [NSMutableArray array];
    
    [appDelegate.database inDatabase:^(FMDatabase *db) {
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
        int start = (int)[[NSDate date] timeIntervalSince1970];
        int end = appDelegate.latestFetchedStoryDate;
        int seconds = start - (end ? end : start);
        __block int hours = (int)round(seconds / 60.f / 60.f);
        
        __block float progress = 0.f;
        if (appDelegate.totalUnfetchedStoryCount) {
            progress = 1.f - ((float)appDelegate.remainingUnfetchedStoryCount /
                              (float)appDelegate.totalUnfetchedStoryCount);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [appDelegate.feedsViewController showSyncingNotifier:progress hoursBack:hours];
        });
    }];
    
    return hashes;
}

- (void)storeAllUnreadStories:(NSDictionary *)results withHashes:(NSArray *)hashes {
    NSMutableArray *storyHashes = [hashes mutableCopy];
    [appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL anyInserted = NO;
        for (NSDictionary *story in [results objectForKey:@"stories"]) {
            BOOL inserted = [db executeUpdate:@"INSERT into stories "
                             "(story_feed_id, story_hash, story_timestamp, story_json) VALUES "
                             "(?, ?, ?, ?)",
                             [story objectForKey:@"story_feed_id"],
                             [story objectForKey:@"story_hash"],
                             [story objectForKey:@"story_timestamp"],
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
        }
        if (anyInserted) {
            appDelegate.latestFetchedStoryDate = [[[[results objectForKey:@"stories"] lastObject]
                                                   objectForKey:@"story_timestamp"] intValue];
        }
        if ([storyHashes count]) {
            NSLog(@"Failed to fetch stories: %@", storyHashes);
            [db executeUpdate:[NSString stringWithFormat:@"DELTE FROM unread_hashes WHERE story_hash IN (%@)",
                               [storyHashes componentsJoinedByString:@", "]]];
        }
    }];
}


@end
