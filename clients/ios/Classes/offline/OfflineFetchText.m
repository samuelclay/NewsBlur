//
//  OfflineFetchText.m
//  NewsBlur
//
//  Created by David Sinclair on 2019-10-25.
//  Copyright © 2019 NewsBlur. All rights reserved.
//

#import "OfflineFetchText.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "Utilities.h"
#import "NSObject+SBJSON.h"
#import "NewsBlur-Swift.h"

@implementation OfflineFetchText

- (void)main {
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    });
    
    while (YES) {
        BOOL fetched = [self fetchText];
        if (!fetched) break;
    }
}

- (BOOL)fetchText {
    if (self.isCancelled) {
        NSLog(@"Text cancelled.");
        return NO;
    }
    
    NSLog(@"Fetching text...");
    NSArray *pendingTextDictionaries = [self uncachedTextDictionaries];
    
    if (![[[NSUserDefaults standardUserDefaults]
           objectForKey:@"offline_text_download"] boolValue] ||
        ![[[NSUserDefaults standardUserDefaults]
           objectForKey:@"offline_allowed"] boolValue] ||
        [pendingTextDictionaries count] == 0) {
        NSLog(@"Finished caching text. %ld total", (long)self.appDelegate.totalUncachedTextCount);
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"offline_image_download"]) {
                [self.appDelegate.feedsViewController showCachingNotifier:@"Images" progress:0 hoursBack:1];
                [self.appDelegate startOfflineFetchImages];
            } else {
                [self.appDelegate.feedsViewController showDoneNotifier];
                [self.appDelegate.feedsViewController hideNotifier];
                [self.appDelegate finishBackground];
            }
        });
        return NO;
    }
    
    if (![self.appDelegate isReachableForOffline]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.appDelegate.feedsViewController showDoneNotifier];
            [self.appDelegate.feedsViewController hideNotifier];
        });
        return NO;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/rss_feeds/original_text", self.appDelegate.url];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
    manager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    
    dispatch_group_t group = dispatch_group_create();
    
    for (NSDictionary *pendingTextDictionary in pendingTextDictionaries) {
        id storyHash = pendingTextDictionary[@"story_hash"];
        id feedId = pendingTextDictionary[@"story_feed_id"];
        NSInteger storyTimestamp = [pendingTextDictionary[@"story_timestamp"] integerValue];
        
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        [params setObject:storyHash forKey:@"story_id"];
        [params setObject:feedId forKey:@"feed_id"];
        
        dispatch_group_enter(group);
        //        NSLog(@" ---> Fetching offline text: %@", urlString);
        [manager POST:urlString parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            //            NSLog(@" ---> Fetched %@: %@", storyHash, urlString);
            NSString *text = [responseObject objectForKey:@"original_text"];
            
            if ([text isKindOfClass:[NSString class]]) {
                [self storeText:text forStoryHash:storyHash storyTimestamp:storyTimestamp];
            } else {
                [self storeFailedTextForStoryHash:storyHash];
            }
            dispatch_group_leave(group);
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            //            NSLog(@" ---> Failed to fetch text %@: %@", storyHash, urlString);
            [self storeFailedTextForStoryHash:storyHash];
            dispatch_group_leave(group);
        }];
    }
    
//    dispatch_sync(dispatch_get_main_queue(), ^{
//        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
//    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    NSLog(@"Queue finished: %ld total (%ld remaining)", (long)self.appDelegate.totalUncachedTextCount, (long)self.appDelegate.remainingUncachedTextCount);
    
    [self updateProgress];
    
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
//    });
    
    return YES;
}

- (NSArray *)uncachedTextDictionaries {
    NSMutableArray *pendingTextDictionaries = [NSMutableArray array];
    
    [self.appDelegate.database inDatabase:^(FMDatabase *db) {
        NSString *commonQuery = @"FROM cached_text c "
        "INNER JOIN unread_hashes u ON (c.story_hash = u.story_hash) "
        "WHERE c.text_json is null ";
        int count = [db intForQuery:[NSString stringWithFormat:@"SELECT COUNT(1) %@", commonQuery]];
        if (self.appDelegate.totalUncachedTextCount == 0) {
            self.appDelegate.totalUncachedTextCount = count;
            self.appDelegate.remainingUncachedTextCount = self.appDelegate.totalUncachedTextCount;
        } else {
            self.appDelegate.remainingUncachedTextCount = count;
        }
        
        int limit = 120;
        NSString *order;
        if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"default_order"] isEqualToString:@"oldest"]) {
            order = @"ASC";
        } else {
            order = @"DESC";
        }
        NSString *sql = [NSString stringWithFormat:@"SELECT * %@ ORDER BY u.story_timestamp %@ LIMIT %d", commonQuery, order, limit];
        FMResultSet *cursor = [db executeQuery:sql];
        
        while ([cursor next]) {
            [pendingTextDictionaries addObject:[cursor resultDictionary]];
        }
        
        [cursor close];
    }];
    
    return pendingTextDictionaries;
}

- (void)updateProgress {
    if (self.isCancelled) return;
    
    NSInteger start = (NSInteger)[[NSDate date] timeIntervalSince1970];
    NSInteger end = self.appDelegate.latestCachedTextDate;
    NSInteger seconds = start - (end ? end : start);
    __block int hours = (int)round(seconds / 60.f / 60.f);
    
    __block float progress = 0.f;
    if (self.appDelegate.totalUncachedTextCount) {
        progress = 1.f - ((float)self.appDelegate.remainingUncachedTextCount /
                          (float)self.appDelegate.totalUncachedTextCount);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.appDelegate.feedsViewController showCachingNotifier:@"Text" progress:progress hoursBack:hours];
    });
}

- (void)storeText:(NSString *)text forStoryHash:(NSString *)storyHash storyTimestamp:(NSInteger)storyTimestamp {
    if (self.isCancelled) {
        NSLog(@"Text cancelled.");
        return;
    }
    
    NSDictionary *textDictionary = @{@"text" : text};
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,
                                             (unsigned long)NULL), ^{
        [self storeTextDictionary:textDictionary forStoryHash:storyHash];
        
        if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"default_order"] isEqualToString:@"oldest"]) {
            if (storyTimestamp > self.appDelegate.latestCachedTextDate) {
                self.appDelegate.latestCachedTextDate = storyTimestamp;
            }
        } else {
            if (!self.appDelegate.latestCachedTextDate || storyTimestamp < self.appDelegate.latestCachedTextDate) {
                self.appDelegate.latestCachedTextDate = storyTimestamp;
            }
        }
        
        @synchronized (self) {
            self.appDelegate.remainingUncachedTextCount--;
            if (self.appDelegate.remainingUncachedTextCount % 10 == 0) {
                [self updateProgress];
            }
        }
    });
}

- (void)storeFailedTextForStoryHash:(NSString *)storyHash {
    NSDictionary *textDictionary = @{@"failed" : @YES};
    
    [self storeTextDictionary:textDictionary forStoryHash:storyHash];
}

- (void)storeTextDictionary:(NSDictionary *)textDictionary forStoryHash:(NSString *)storyHash {
    [self.appDelegate.database inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"UPDATE cached_text SET text_json = ? WHERE story_hash = ?",
         [textDictionary JSONRepresentation],
         storyHash];
    }];
}

@end
