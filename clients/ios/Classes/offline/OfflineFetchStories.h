//
//  OfflineFetchStories.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/15/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NewsBlurAppDelegate.h"

@interface OfflineFetchStories : NSOperation

@property (nonatomic) NewsBlurAppDelegate *appDelegate;

- (NSArray *)unfetchedStoryHashes;
- (void)storeAllUnreadStories:(NSDictionary *)results;

@end
