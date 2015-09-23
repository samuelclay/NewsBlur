//
//  OfflineFetchStories.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/15/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFHTTPRequestOperation.h"
#import "NewsBlurAppDelegate.h"

@interface OfflineFetchStories : NSOperation {
    AFHTTPRequestOperation *request;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;

- (BOOL)fetchStories;
- (NSArray *)unfetchedStoryHashes;
- (void)storeAllUnreadStories:(NSDictionary *)results withHashes:(NSArray *)hashes;

@end
