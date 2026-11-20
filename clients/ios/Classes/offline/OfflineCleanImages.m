//
//  OfflineCleanImages.m
//  NewsBlur
//
//  Created by Samuel Clay on 8/5/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "OfflineCleanImages.h"
#import "NewsBlur-Swift.h"

@implementation OfflineCleanImages

@synthesize appDelegate;

- (void)main {
    dispatch_sync(dispatch_get_main_queue(), ^{
        appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    });
    
    [appDelegate.database inDatabase:^(FMDatabase *db) {
        if (self.isCancelled || appDelegate.clearingOfflineCache) return;
        [OfflineCacheCleanup removeUnreferencedImagesWithDatabase:db directory:[appDelegate.documentsURL URLByAppendingPathComponent:@"story_images"]];
    }];
}

@end
