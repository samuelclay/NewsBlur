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
@property (readwrite) ASINetworkQueue *imageDownloadOperationQueue;

- (BOOL)fetchImages;
- (NSArray *)uncachedImageUrls;
- (void)storeCachedImage:(ASIHTTPRequest *)request;
- (void)storeFailedImage:(ASIHTTPRequest *)request;
- (void)cachedImageQueueFinished:(ASINetworkQueue *)queue;

@end
