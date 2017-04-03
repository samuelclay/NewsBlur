//
//  OfflineFetchImages.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/15/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NewsBlurAppDelegate.h"
#import "FMDatabaseQueue.h"

@interface OfflineFetchImages : NSOperation

@property (nonatomic) NewsBlurAppDelegate *appDelegate;

- (BOOL)fetchImages;
- (NSArray *)uncachedImageUrls;

@end
