//
//  OSKTwitterUtility.h
//  Overshare
//
//  Created by Justin Williams on 10/15/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;
@import Social;

@class OSKMicroblogPostContentItem;

@interface OSKTwitterUtility : NSObject

+ (void)postContentItem:(OSKMicroblogPostContentItem *)item
        toSystemAccount:(ACAccount *)account
             completion:(void(^)(BOOL success, NSError *error))completion; // called on main queue


@end
