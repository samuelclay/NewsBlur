//
//  OSKReadabilityUtility.m
//  Overshare
//
//  Created by Jared Sinclair on 10/20/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKReadabilityUtility.h"

#import "OSKReadabilityActivity.h"
#import "OSKApplicationCredential.h"
#import "OSKLogger.h"
#import "OSKManagedAccount.h"
#import "OSKManagedAccountCredential.h"
#import "OSKOAuthUtility.h"
#import "NSMutableURLRequest+OSKUtilities.h"
#import "NSHTTPURLResponse+OSKUtilities.h"

#define kReadabilityBaseURL @"https://www.readability.com"
#define kReadabilityGETAuthTokenPath @"/api/rest/v1/oauth/access_token/"
#define kReadabilityPOSTNewBookmark @"/api/rest/v1/bookmarks"
#define kXAuthUsername @"x_auth_username"
#define kXAuthPassword @"x_auth_password"
#define kXAuthMode @"x_auth_mode"
#define kOauthTokenSecret @"oauth_token_secret"
#define kOauthToken @"oauth_token"

@implementation OSKReadabilityUtility

+ (void)signIn:(NSString *)username password:(NSString *)password appCredential:(OSKApplicationCredential *)appCredential completion:(void(^)(OSKManagedAccount *account, NSError *error))completion {
    NSString *baseURLPlusAuthPath = [NSString stringWithFormat:@"%@%@", kReadabilityBaseURL, kReadabilityGETAuthTokenPath];
    NSDictionary *bodyXAuthParams = @{kXAuthUsername : [username copy],
                                      kXAuthPassword : [password copy],
                                      kXAuthMode : @"client_auth"};
    NSString *oauthAuthorizationString = nil;
    oauthAuthorizationString = [OSKOAuthUtility oauth_headerStringWithHTTPMethod:@"GET"
                                                                         baseURL:baseURLPlusAuthPath
                                                               queryStringParams:nil
                                                                      bodyParams:bodyXAuthParams
                                                                     consumerKey:appCredential.applicationKey
                                                                  consumerSecret:appCredential.applicationSecret
                                                                     accessToken:nil
                                                               accessTokenSecret:nil];
    NSString *path = [NSString stringWithFormat:@"%@%@", kReadabilityBaseURL, kReadabilityGETAuthTokenPath];
    NSMutableURLRequest *request = [NSMutableURLRequest osk_requestWithMethod:@"GET" URLString:path parameters:bodyXAuthParams serialization:OSKParameterSerializationType_Query];
    [request setValue:oauthAuthorizationString forHTTPHeaderField:@"Authorization"];
    NSURLSession *sesh = [NSURLSession sharedSession];
    [[sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            OSKManagedAccount *newAccount = nil;
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSArray *componentPairs = [responseString componentsSeparatedByString:@"&"];
            NSMutableDictionary *keyValuePairs = [NSMutableDictionary dictionary];
            for (NSString *pair in componentPairs) {
                NSArray *keyValuePair = [pair componentsSeparatedByString:@"="];
                if (keyValuePair.count == 2) {
                    NSString *key = [keyValuePair objectAtIndex:0];
                    NSString *value = [keyValuePair objectAtIndex:1];
                    [keyValuePairs setObject:value forKey:key];
                }
            }
            NSString *token = [keyValuePairs objectForKey:kOauthToken];
            NSString *secret = [keyValuePairs objectForKey:kOauthTokenSecret];
            if (token.length && secret.length) {
                NSString *identifier = [OSKManagedAccount generateNewOvershareAccountIdentifier];
                OSKManagedAccountCredential *credential = [[OSKManagedAccountCredential alloc]
                                                           initWithOvershareAccountIdentifier:identifier
                                                           accountID:username
                                                           OauthToken:token OauthTokenSecret:secret];
                newAccount = [[OSKManagedAccount alloc]
                              initWithOvershareAccountIdentifier:identifier
                              activityType:[OSKReadabilityActivity activityType]
                              credential:credential];
                [newAccount setUsername:username];
                
            }
            NSError *theError = error;
            if (theError == nil && newAccount == nil) {
                theError = [NSError errorWithDomain:@"OSKReadabilityUtility" code:400 userInfo:@{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Request failed: %@", response.description]}];
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(newAccount, theError);
                });
            }
        });
    }] resume];
}

+ (void)saveURL:(NSURL *)URL withAccountCredential:(OSKManagedAccountCredential *)accountCredential appCredential:(OSKApplicationCredential *)appCredential completion:(void(^)(BOOL success, NSError *error))completion {
    NSDictionary *parameters = @{@"url" : [URL absoluteString]};
    NSString *baseURLPlusAuthPath = [NSString stringWithFormat:@"%@%@", kReadabilityBaseURL, kReadabilityPOSTNewBookmark];
    NSString *oauthAuthorizationString = [OSKOAuthUtility oauth_headerStringWithHTTPMethod:@"POST"
                                                                                baseURL:baseURLPlusAuthPath
                                                                      queryStringParams:nil
                                                                             bodyParams:parameters
                                                                            consumerKey:appCredential.applicationKey
                                                                         consumerSecret:appCredential.applicationSecret
                                                                            accessToken:accountCredential.token
                                                                      accessTokenSecret:accountCredential.tokenSecret];
    NSMutableURLRequest *request = [NSMutableURLRequest osk_requestWithMethod:@"POST" URLString:baseURLPlusAuthPath parameters:parameters serialization:OSKParameterSerializationType_HTTPBody_FormData];
    [request setValue:oauthAuthorizationString forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSURLSession *sesh = [NSURLSession sharedSession];
    [[sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *theError = error;
                BOOL codeIsAcceptable = [NSHTTPURLResponse statusCodeAcceptableForResponse:response
                                                                      otherAcceptableCodes:[NSIndexSet indexSetWithIndex:409]];
                if (codeIsAcceptable == NO && error == nil) {
                    theError = [NSError errorWithDomain:@"OSKReadabilityUtility" code:400 userInfo:@{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Request failed: %@", response.description]}];
                }
                completion((theError == nil), theError);
            });
        }
    }] resume];
}

@end






