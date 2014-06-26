//
//  OSKFacebookUtility.m
//  Overshare
//
//  Created by Jared Sinclair 10/29/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Social;

#import "OSKFacebookUtility.h"
#import "OSKShareableContentItem.h"
#import "OSKSystemAccountStore.h"
#import "OSKLogger.h"

@implementation OSKFacebookUtility

+ (void)renewCredentials:(ACAccount *)account completion:(void(^)(BOOL success, NSError *error))completion {
    [[OSKSystemAccountStore sharedInstance] renewCredentialsForAccount:account completion:^(ACAccountCredentialRenewResult renewResult, NSError *theError) {
        if (completion) {
            completion((renewResult == ACAccountCredentialRenewResultRenewed), theError);
        }
    }];
}

+ (void)postContentItem:(OSKFacebookContentItem *)item toSystemAccount:(ACAccount *)account options:(NSDictionary *)options completion:(void(^)(BOOL success, NSError *error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self renewCredentials:(ACAccount *)account completion:^(BOOL theSuccess, NSError *theError) {
            if (theSuccess) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self _postContentItem:item toSystemAccount:account options:options completion:completion];
                });
            } else {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(NO, theError);
                    });
                }
            }
        }];
    });
}

+ (void)_postContentItem:(OSKFacebookContentItem *)item toSystemAccount:(ACAccount *)account options:(NSDictionary *)options completion:(void(^)(BOOL success, NSError *error))completion {
    SLRequestHandler requestHandler = ^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (responseData != nil) {
            
            __unused NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            OSKLog(@"%@", response);
            
            NSInteger statusCode = urlResponse.statusCode;
            if ((statusCode >= 200) && (statusCode < 300)) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES, nil);
                });
            }
            else {
                NSString *errorMessage = [NSString stringWithFormat:@"[OSKFacebookUtility] Error received when trying to create a new tweet. Server responded with status code %li and response: %@", (long)statusCode, [NSHTTPURLResponse localizedStringForStatusCode:statusCode]];
                OSKLog(@"%@", errorMessage);
                NSError *error = [NSError errorWithDomain:@"com.overshare.errors"
                                                     code:statusCode
                                                 userInfo:@{NSLocalizedFailureReasonErrorKey:errorMessage}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, error);
                });
            }
        }
        else {
            NSString *errorMessage = [NSString stringWithFormat:@"[OSKFacebookUtility] An error occurred while attempting to post a new tweet: %@", [error localizedDescription]];
            OSKLog(@"%@", errorMessage);
            NSError *error = [NSError errorWithDomain:@"com.overshare.errors"
                                                 code:400
                                             userInfo:@{NSLocalizedFailureReasonErrorKey:errorMessage}];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
    };
    
    if (item.images.count == 0) {
        SLRequest *feedRequest = [self plainTextMessageRequestForContentItem:item options:options account:account];
        [feedRequest performRequestWithHandler:requestHandler];
    } else {
        __block NSInteger remainingCount = item.images.count;
        __block BOOL failed = NO;
        NSIndexSet *successRange = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
        for (UIImage *image in item.images) {
            SLRequest *feedRequest = [self photoUploadRequestForContentItem:item options:options image:image account:account];
            [feedRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        remainingCount--;
                        if (error != nil || [successRange containsIndex:[urlResponse statusCode]] == NO) {
                            failed = YES;
                            completion(NO, error);
                        }
                        if (remainingCount == 0 && failed == NO) {
                            completion(YES, nil);
                        }
                    });
                }
            }];
        }
    }
}

+ (SLRequest *)plainTextMessageRequestForContentItem:(OSKFacebookContentItem *)item options:(NSDictionary *)options account:(ACAccount *)account {
    SLRequest *feedRequest = nil;
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:@{@"message" : item.text.copy}];
    if (item.link.absoluteString) {
        [parameters setObject:item.link.absoluteString forKey:@"link"];
    }
    [parameters setObject:[self _queryParameterForAudience:options[ACFacebookAudienceKey]] forKey:@"privacy"];
    NSURL *feedURL = [NSURL URLWithString:@"https://graph.facebook.com/me/feed"];
    feedRequest = [SLRequest
                   requestForServiceType:SLServiceTypeFacebook
                   requestMethod:SLRequestMethodPOST
                   URL:feedURL
                   parameters:parameters];
    feedRequest.account = account;
    
    return feedRequest;
}

+ (SLRequest *)photoUploadRequestForContentItem:(OSKFacebookContentItem *)item options:(NSDictionary *)options image:(UIImage *)image account:(ACAccount *)account {
    SLRequest *feedRequest = nil;
    
    NSDictionary* parametersDictionary = [item.text length] > 0 ? @{@"message": item.text.copy} : @{};
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:parametersDictionary];
    [parameters setObject:[self _queryParameterForAudience:options[ACFacebookAudienceKey]] forKey:@"privacy"];
    NSURL *feedURL = [NSURL URLWithString:@"https://graph.facebook.com/me/photos"];
    feedRequest = [SLRequest
                   requestForServiceType:SLServiceTypeFacebook
                   requestMethod:SLRequestMethodPOST
                   URL:feedURL
                   parameters:parameters];
    feedRequest.account = account;
    NSData *imageData = UIImageJPEGRepresentation(image, 0.25f);
    NSString *dateSuffix = [self _todaysDateSuffix];
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    NSString *filename = [NSString stringWithFormat:@"Image_from_%@_%@.jpg", appName, dateSuffix];
    [feedRequest addMultipartData:imageData withName:@"source" type:@"image/jpeg" filename:filename];
    
    
    return feedRequest;
}

+ (NSString *)_todaysDateSuffix {
	NSDate *today = [NSDate date];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.dateFormat = @"yyyy-MM-dd";
	NSString *suffix = [formatter stringFromDate:today];
	return suffix;
}

+ (NSString *)_queryParameterForAudience:(NSString *)audience {
    NSString *param = nil;
    if ([audience isEqualToString:ACFacebookAudienceEveryone]) {
        param = @"{\"value\":\"EVERYONE\"}";
    }
    else if ([audience isEqualToString:ACFacebookAudienceFriends]) {
        param = @"{\"value\":\"ALL_FRIENDS\"}";
    }
    else if ([audience isEqualToString:ACFacebookAudienceOnlyMe]) {
        param = @"{\"value\":\"SELF\"}";
    }
    return param;
}

@end




