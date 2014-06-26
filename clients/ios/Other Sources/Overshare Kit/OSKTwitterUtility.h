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

/**
 Use these two keys to fetch an NSNumber value from the dictionary returned in the completion
 block of requestTwitterConfiguration that indicates the length that URLs will be shortened to
 by Twitter's link shortener service
 */
extern NSString * const OSKTwitterImageHttpURLLengthKey;
extern NSString * const OSKTwitterImageHttpsURLLengthKey;


@interface OSKTwitterUtility : NSObject

+ (void)postContentItem:(OSKMicroblogPostContentItem *)item
        toSystemAccount:(ACAccount *)account
             completion:(void(^)(BOOL success, NSError *error))completion; // called on main queue

/**
 Asynchronouse fetch of Twitter configuration parameters returned in dictionary. 
 Per Twitter's recommendations, this call will cache values and not redundantly fetch them.
 For details on the values returned see: https://dev.twitter.com/docs/api/1.1/get/help/configuration
 */
+ (void) requestTwitterConfiguration:(ACAccount *)account
						  completion:(void(^)(NSError* error, NSDictionary* configurationParameters))completion; // called on main queue

@end
