//
//  OfflineSyncUnreads.m
//  NewsBlur
//
//  Created by Samuel Clay on 7/15/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "OfflineSyncUnreads.h"
#import "NewsBlurAppDelegate.h"
#import "NewsBlurViewController.h"
#import "FMResultSet.h"
#import "FMDatabase.h"
#import "AFHTTPRequestOperation.h"

@implementation OfflineSyncUnreads

@synthesize appDelegate;
@synthesize request;

- (void)main {
    appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
//    NSLog(@"Syncing Unreads...");
    dispatch_async(dispatch_get_main_queue(), ^{
        [appDelegate.feedsViewController showSyncingNotifier];
    });

    __block NSCondition *lock = [NSCondition new];
    __weak __typeof(&*self)weakSelf = self;
    [lock lock];

    NSURL *url = [NSURL URLWithString:[NSString
                                       stringWithFormat:@"%@/reader/unread_story_hashes?include_timestamps=true",
                                       self.appDelegate.url]];
    request = [[AFHTTPRequestOperation alloc] initWithRequest:[NSURLRequest requestWithURL:url]];
    [request setResponseSerializer:[AFJSONResponseSerializer serializer]];
    [request setCompletionBlockWithSuccess:^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject) {
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        NSLog(@"Syncing stories success: %@-%@", weakSelf, strongSelf);
        if (!strongSelf) return;
        [strongSelf storeUnreadHashes:responseObject];
        [lock signal];
    } failure:^(AFHTTPRequestOperation * _Nonnull operation, NSError * _Nonnull error) {
        NSLog(@"Failed fetch all story hashes: %@", error);
        [lock signal];
    }];
    [request setCompletionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL)];
    [request start];

    [lock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:30]];
    [lock unlock];

    NSLog(@"Finished syncing stories");
}

- (void)storeUnreadHashes:(NSDictionary *)results {
    if (self.isCancelled) {
//        NSLog(@"Canceled storing unread hashes");
        [request cancel];
        return;
    }
    
    [appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
//        NSLog(@"Storing unread story hashes...");
        [db executeUpdate:@"DROP TABLE unread_hashes"];
        [appDelegate setupDatabase:db];
        NSDictionary *hashes = [results objectForKey:@"unread_feed_story_hashes"];
        for (NSString *feed in [hashes allKeys]) {
            NSArray *story_hashes = [hashes objectForKey:feed];
            for (NSArray *story_hash_tuple in story_hashes) {
                [db executeUpdate:@"INSERT into unread_hashes"
                 "(story_feed_id, story_hash, story_timestamp) VALUES "
                 "(?, ?, ?)",
                 feed,
                 [story_hash_tuple objectAtIndex:0],
                 [story_hash_tuple objectAtIndex:1]
                 ];
            }
        }
    }];
    [appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        // Once all unread hashes are in, only keep under preference for offline limit
        NSInteger offlineLimit = [[NSUserDefaults standardUserDefaults]
                                  integerForKey:@"offline_store_limit"];
        NSString *order;
        NSString *orderComp;
        if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"default_order"]
             isEqualToString:@"oldest"]) {
            order = @"ASC";
            orderComp = @">";
        } else {
            order = @"DESC";
            orderComp = @"<";
        }
        NSString *lastStorySql = [NSString stringWithFormat:
                                  @"SELECT story_timestamp FROM unread_hashes "
                                  "ORDER BY story_timestamp %@ LIMIT 1 OFFSET %ld",
                                  order, (long)offlineLimit];
        FMResultSet *cursor = [db executeQuery:lastStorySql];
        int offlineLimitTimestamp = 0;
        while ([cursor next]) {
            offlineLimitTimestamp = [cursor intForColumn:@"story_timestamp"];
            break;
        }
        [cursor close];
        
        if (offlineLimitTimestamp) {
//            NSLog(@"Deleting stories over limit: %ld - %d", (long)offlineLimit, offlineLimitTimestamp);
            [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM unread_hashes WHERE story_timestamp %@ %d", orderComp, offlineLimitTimestamp]];
            [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM stories WHERE story_timestamp %@ %d", orderComp, offlineLimitTimestamp]];
//            [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM story_scrolls WHERE story_timestamp %@ %d", orderComp, offlineLimitTimestamp]]; // Don't cleanup story scrolls just yet
        }
    }];
    
    appDelegate.totalUnfetchedStoryCount = 0;
    appDelegate.remainingUnfetchedStoryCount = 0;
    appDelegate.latestFetchedStoryDate = 0;
    appDelegate.totalUncachedImagesCount = 0;
    appDelegate.remainingUncachedImagesCount = 0;
    
//    NSLog(@"Done syncing Unreads...");
    [appDelegate startOfflineFetchStories];
}

@end
