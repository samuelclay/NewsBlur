//
//  OSKTwitterUtility.m
//  Overshare
//
//  Created by Justin Williams on 10/15/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Social;
@import Accounts;

#import "OSKTwitterUtility.h"
#import "OSKShareableContentItem.h"
#import "OSKSystemAccountStore.h"
#import "OSKLogger.h"

@implementation OSKTwitterUtility

+ (void)postContentItem:(OSKMicroblogPostContentItem *)item
        toSystemAccount:(ACAccount *)account
             completion:(void(^)(BOOL success, NSError *error))completion {
    SLRequestHandler requestHandler = ^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (responseData != nil)
        {
            NSInteger statusCode = urlResponse.statusCode;
            if ((statusCode >= 200) && (statusCode < 300))
            {
                NSDictionary *postResponseData =
                [NSJSONSerialization JSONObjectWithData:responseData
                                                options:NSJSONReadingMutableContainers
                                                  error:NULL];
                OSKLog(@"[OSKTwitterUtility] Successfully created Tweet with ID: %@", postResponseData[@"id_str"]);
                
                NSString *string = [NSString stringWithFormat:@"https://twitter.com/%@/status/%@", account.username, postResponseData[@"id_str"]];
                NSURL *tweetURL = [NSURL URLWithString:string];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion((tweetURL != nil), nil);
                });
                
            }
            else
            {
                OSKLog(@"[OSKTwitterUtility] Error received when trying to create a new tweet. Server responded with status code %li and response: %@", (long)statusCode, [NSHTTPURLResponse localizedStringForStatusCode:statusCode]);
                
                NSError *error = [NSError errorWithDomain:@"com.secondgear.PhotosPlus.Errors" code:statusCode userInfo:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, error);
                });
            }
        }
        else
        {
            OSKLog(@"[OSKTwitterUtility] An error occurred while attempting to post a new tweet: %@", [error localizedDescription]);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
    };
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:@{ @"status" : item.text }];
    if ((item.latitude != 0.0) && (item.longitude != 0.0))
    {
        params[@"lat"] = [@(item.latitude) stringValue];
        params[@"long"] = [@(item.longitude) stringValue];
    }

    NSURL *twitterApiURL = nil;
    if ([item.images count] > 0)
    {
        twitterApiURL = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update_with_media.json"];;
    }
    else
    {
        twitterApiURL = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update.json"];
    }
    
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:twitterApiURL parameters:params];
    
    for (UIImage *image in item.images)
    {
        NSData *imageData = UIImageJPEGRepresentation(image, 1.f);
        [request addMultipartData:imageData withName:@"media[]" type:@"image/jpeg" filename:@"image.jpg"];
    }
    
    request.account = account;
    
    //    OSKLog(@"[OSKTwitterUtility] Beginning request to upload new tweet.");
    [request performRequestWithHandler:requestHandler];
}

@end
