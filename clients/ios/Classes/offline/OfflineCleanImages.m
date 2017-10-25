//
//  OfflineCleanImages.m
//  NewsBlur
//
//  Created by Samuel Clay on 8/5/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "OfflineCleanImages.h"

@implementation OfflineCleanImages

@synthesize appDelegate;

- (void)main {
    dispatch_sync(dispatch_get_main_queue(), ^{
        appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    });
    
    NSLog(@"Cleaning stale offline images...");
    
    int deleted = 0;
    int checked = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"story_images"];
    NSDirectoryEnumerator* en = [fileManager enumeratorAtPath:cacheDirectory];
    NSDate *d = [[NSDate date] dateByAddingTimeInterval:-30*24*60*60];
    NSDateFormatter *df = [[NSDateFormatter alloc] init]; // = [NSDateFormatter initWithDateFormat:@"yyyy-MM-dd"];
    [df setDateFormat:@"EEEE d"];
    
    NSString *filepath;
    NSDate *creationDate;
    NSString* file;
    while (file = [en nextObject])
    {
        filepath = [NSString stringWithFormat:[cacheDirectory stringByAppendingString:@"/%@"],file];
        creationDate = [[fileManager attributesOfItemAtPath:filepath error:nil] fileCreationDate];
        checked += 1;
        
        if ([creationDate compare:d] == NSOrderedAscending) {
            [[NSFileManager defaultManager]
             removeItemAtPath:[cacheDirectory stringByAppendingPathComponent:file]
             error:nil];
            deleted += 1;
        }
        
        if (self.isCancelled) {
            NSLog(@"Canceling image cleaning...");
            break;
        }
    }
    
    NSLog(@"Deleted %d/%d old cached images", deleted, checked);
}

@end
