//
//  RWInstapaperActivityRequest.h
//  InstapaperActivity
//
//  Created by Justin Ridgewell on 2/28/13.
//
//

#import <Foundation/Foundation.h>
#import "ZYInstapaperAddRequestDelegate.h"

@class ZYInstapaperActivityItem;
@interface RWInstapaperActivityRequest : NSObject

- (id)initWithItem:(ZYInstapaperActivityItem *)item username:(NSString *)username password:(NSString *)password delegate:(id<ZYInstapaperAddRequestDelegate>)delegate;
- (void)cancel;

@end
