//
//  OSKInstapaperUtility.m
//  Overshare
//
//  Created by Jared Sinclair on 10/19/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKInstapaperUtility.h"

#import "OSKActivity.h"
#import "OSKLogger.h"
#import "OSKManagedAccount.h"
#import "OSKManagedAccountCredential.h"
#import "NSMutableURLRequest+OSKUtilities.h"
#import "NSHTTPURLResponse+OSKUtilities.h"

static NSString * OSKInstapaperBaseURL = @"https://www.instapaper.com/api/";
static NSString * OSKInstapaperAPIAuthenticate = @"authenticate";
static NSString * OSKInstapaperAPIAddURL = @"add";

@implementation OSKInstapaperUtility

+ (void)createNewAccountWithUsername:(NSString *)username password:(NSString *)password completion:(void(^)(OSKManagedAccount *account, NSError *error))completion {
    NSURLSession *sesh = [NSURLSession sharedSession];
    NSDictionary *params = @{@"username":username,@"password":password};
    NSString *path = [NSString stringWithFormat:@"%@%@", OSKInstapaperBaseURL, OSKInstapaperAPIAuthenticate];
    NSMutableURLRequest *request = [NSMutableURLRequest osk_requestWithMethod:@"GET" URLString:path parameters:params serialization:OSKParameterSerializationType_Query];
    [[sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            OSKManagedAccount *account = nil;
            BOOL isValidResponse = [NSHTTPURLResponse statusCodeAcceptableForResponse:response];
            NSError *theError = error;
            
            if (isValidResponse) {
                NSString *identifier = [OSKManagedAccount generateNewOvershareAccountIdentifier];
                OSKManagedAccountCredential *accountCredential = [[OSKManagedAccountCredential alloc]
                                                              initWithOvershareAccountIdentifier:identifier
                                                              username:username
                                                              password:password];
                account = [[OSKManagedAccount alloc]
                                          initWithOvershareAccountIdentifier:identifier
                                          activityType:OSKActivityType_API_Instapaper
                                          credential:accountCredential];
                account.username = username;
            }
            else if (theError == nil) {
                theError = [NSError errorWithDomain:@"OSKInstapaperUtility" code:400 userInfo:@{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Request failed: %@", response.description]}];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (theError) {
                    OSKLog(@"Failed to sign into Instapaper: %@", error);
                }
                if (completion) {
                    completion(account, theError);
                }
            });
        });
    }] resume];
}

+ (void)saveURL:(NSURL *)URL credential:(OSKManagedAccountCredential *)credential completion:(void(^)(BOOL success, NSError *error))completion {
    NSString *urlString = URL.absoluteString;
    if (urlString.length == 0) {
        if (completion) {
            NSDictionary *info = @{NSLocalizedFailureReasonErrorKey:@"OSKInstapaperUtility: Unable to obtain a valid string from the NSURL."};
            NSError *error = [[NSError alloc] initWithDomain:@"Overshare" code:400 userInfo:info];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
    }
    else if (credential.username == nil || credential.password == nil) {
        if (completion) {
            NSDictionary *info = @{NSLocalizedFailureReasonErrorKey:@"OSKInstapaperUtility: Unable to save the link because a username and/or password were not provided."};
            NSError *error = [[NSError alloc] initWithDomain:@"Overshare" code:401 userInfo:info];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
    }
    else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSURLSession *sesh = [NSURLSession sharedSession];
            NSDictionary *parameters = @{@"username":credential.username,
                                         @"password":credential.password,
                                         @"url":urlString};
            NSString *path = [NSString stringWithFormat:@"%@%@", OSKInstapaperBaseURL, OSKInstapaperAPIAddURL];
            NSMutableURLRequest *request = [NSMutableURLRequest osk_requestWithMethod:@"POST" URLString:path parameters:parameters serialization:OSKParameterSerializationType_HTTPBody_FormData];
            
            [[sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (completion) {
                    NSError *theError = error;
                    if ([NSHTTPURLResponse statusCodeAcceptableForResponse:response] == NO && error == nil) {
                        theError = [NSError errorWithDomain:@"OSKInstapaperUtility" code:400 userInfo:@{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Request failed: %@", response.description]}];
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion((theError == nil), theError);
                    });
                }
            }] resume];
        });
    }
    
}

@end





