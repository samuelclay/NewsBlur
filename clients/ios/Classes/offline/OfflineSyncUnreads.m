//
//  OfflineSyncUnreads.m
//  NewsBlur
//
//  Created by Samuel Clay on 7/15/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "OfflineSyncUnreads.h"
#import "NewsBlurAppDelegate.h"
#import "FMResultSet.h"
#import "FMDatabase.h"
#import "NewsBlur-Swift.h"

@implementation OfflineSyncUnreads

@synthesize appDelegate;

- (void)main {
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    });
    
//    NSLog(@"Syncing Unreads...");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.appDelegate.feedsViewController showSyncingNotifier];
    });

    __block NSCondition *lock = [NSCondition new];
    [lock lock];

    NSString *urlString = [NSString stringWithFormat:@"%@/reader/unread_story_hashes?include_timestamps=true",
                           self.appDelegate.url];
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    manager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [manager GET:urlString parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"Syncing stories success");
        [self storeUnreadHashes:responseObject];
        [lock signal];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"Failed fetch all story hashes: %@", error);
        [lock signal];
    }];
    
    BOOL completed = [lock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:30]];
    if (!completed) {
        [self cancel];
        [manager invalidateSessionCancelingTasks:YES];
    }
    [lock unlock];

    NSLog(@"Finished syncing stories");
}

- (void)storeUnreadHashes:(NSDictionary *)results {
    if (self.isCancelled) {
//        NSLog(@"Canceled storing unread hashes");
//        [request cancel];
        return;
    }
    
    if (![results isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *hashes = results[@"unread_feed_story_hashes"];
    if (![hashes isKindOfClass:[NSDictionary class]]) return;
    for (id feed in hashes) {
        if (![hashes[feed] isKindOfClass:[NSArray class]]) return;
        for (id tuple in hashes[feed]) {
            if (![tuple isKindOfClass:[NSArray class]] || [tuple count] < 2 ||
                ![tuple[0] isKindOfClass:[NSString class]] ||
                ![tuple[1] respondsToSelector:@selector(doubleValue)]) return;
        }
    }

    __block BOOL cleaned = NO;
    [self.appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if (self.isCancelled || self.appDelegate.clearingOfflineCache) return;
        BOOL success = [db executeUpdate:@"DELETE FROM unread_hashes"];
        for (NSString *feed in hashes) {
            for (NSArray *tuple in hashes[feed]) {
                if (!success) break;
                success = [db executeUpdate:@"INSERT INTO unread_hashes (story_feed_id, story_hash, story_timestamp) VALUES (?, ?, ?)", feed, tuple[0], tuple[1]];
            }
        }
        NSInteger limit = [[NSUserDefaults standardUserDefaults] integerForKey:@"offline_store_limit"];
        BOOL oldestFirst = [[[NSUserDefaults standardUserDefaults] stringForKey:@"default_order"] isEqualToString:@"oldest"];
        if (success) success = [OfflineCacheCleanup pruneDatabase:db limit:limit oldestFirst:oldestFirst];
        *rollback = !success;
        cleaned = success;
    }];
    if (!cleaned || self.isCancelled) return;
    [self.appDelegate.database inDatabase:^(FMDatabase *db) {
        if (self.isCancelled || self.appDelegate.clearingOfflineCache) return;
        [OfflineCacheCleanup removeUnreferencedImagesWithDatabase:db directory:[self.appDelegate.documentsURL URLByAppendingPathComponent:@"story_images"]];
        [OfflineCacheCleanup compactDatabase:db force:NO];
    }];

    self.appDelegate.totalUnfetchedStoryCount = 0;
    self.appDelegate.remainingUnfetchedStoryCount = 0;
    self.appDelegate.latestFetchedStoryDate = 0;
    self.appDelegate.totalUncachedImagesCount = 0;
    self.appDelegate.remainingUncachedImagesCount = 0;
    
//    NSLog(@"Done syncing Unreads...");
    if (!self.isCancelled && !self.appDelegate.clearingOfflineCache) {
        [self.appDelegate startOfflineFetchStories];
    }
}

@end
