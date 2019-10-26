//
//  OfflineFetchText.h
//  NewsBlur
//
//  Created by David Sinclair on 2019-10-25.
//  Copyright © 2019 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NewsBlurAppDelegate.h"
#import "FMDatabaseQueue.h"

NS_ASSUME_NONNULL_BEGIN

@interface OfflineFetchText : NSOperation

@property (nonatomic) NewsBlurAppDelegate *appDelegate;

- (BOOL)fetchText;

@end

NS_ASSUME_NONNULL_END
