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
#import "AFJSONRequestOperation.h"

@interface OfflineSyncUnreads : NSOperation

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) AFJSONRequestOperation *request;

- (void)storeUnreadHashes:(NSDictionary *)results;

@end
