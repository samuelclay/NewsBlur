//
//  OfflineSyncUnreads.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/15/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NewsBlurAppDelegate.h"
#import "FMDatabaseQueue.h"
#import "NewsBlur-Swift.h"

@interface OfflineSyncUnreads : NSOperation

@property (nonatomic) NewsBlurAppDelegate *appDelegate;

- (void)storeUnreadHashes:(NSDictionary *)results;

@end
