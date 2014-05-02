//
//  OSKFacebookUtility.h
//  Overshare
//
//  Created by Jared Sinclair 10/29/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;
@import Accounts;

@class OSKMicroblogPostContentItem;

@interface OSKFacebookUtility : NSObject

+ (void)postContentItem:(OSKMicroblogPostContentItem *)item
        toSystemAccount:(ACAccount *)account
                options:(NSDictionary *)options /* At this time, just ACFacebookAudienceKey */
             completion:(void(^)(BOOL success, NSError *error))completion;

@end
