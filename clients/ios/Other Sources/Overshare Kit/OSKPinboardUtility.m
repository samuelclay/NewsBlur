//
//  OSKPinboardUtility.m
//  Overshare
//
//  Created by Jared Sinclair on 10/21/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKPinboardUtility.h"

#import "OSKPinboardActivity.h"
#import "OSKApplicationCredential.h"
#import "OSKShareableContentItem.h"
#import "OSKLogger.h"
#import "OSKManagedAccount.h"
#import "OSKManagedAccountCredential.h"
#import "NSMutableURLRequest+OSKUtilities.h"
#import "NSHTTPURLResponse+OSKUtilities.h"

static NSString * OSKPinboardActivity_BaseURL = @"https://api.pinboard.in";
static NSString * OSKPinboardActivity_AddBookmarkPath = @"/v1/posts/add";
static NSString * OSKPinboardActivity_GetTokenPath = @"/v1/user/api_token/";
static NSString * OSKPinboardActivity_TokenParamKey = @"auth_token";
static NSString * OSKPinboardActivity_TokenParamValue = @"%@:%@"; // username and token are the arguments

@implementation OSKPinboardUtility

+ (void)signIn:(NSString *)username password:(NSString *)password completion:(void(^)(OSKManagedAccount *account, NSError *error))completion {
    NSString *path = [NSString stringWithFormat:@"%@%@", OSKPinboardActivity_BaseURL, OSKPinboardActivity_GetTokenPath];
    NSMutableURLRequest *request = [NSMutableURLRequest osk_requestWithMethod:@"GET" URLString:path parameters:@{@"format":@"json"} serialization:OSKParameterSerializationType_Query];
    NSString *base64string = [[[NSString stringWithFormat:@"%@:%@", username, password] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    [request setValue:[NSString stringWithFormat:@"Basic %@", base64string] forHTTPHeaderField:@"Authorization"];
    NSURLSession *sesh = [NSURLSession sharedSession];
    [[sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            OSKManagedAccount *newAccount = nil;
            NSError *theError = nil;
            NSDictionary *responseDictionary = nil;
            if (data) {
                responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            }
            NSString *token = [responseDictionary objectForKey:@"result"];
            if (token.length) {
                NSString *identifier = [OSKManagedAccount generateNewOvershareAccountIdentifier];
                OSKManagedAccountCredential *credential = [[OSKManagedAccountCredential alloc]
                                                           initWithOvershareAccountIdentifier:identifier
                                                           accountID:username
                                                           accessToken:token];
                newAccount = [[OSKManagedAccount alloc] initWithOvershareAccountIdentifier:identifier
                                                                              activityType:[OSKPinboardActivity activityType]
                                                                                credential:credential];
                newAccount.username = username;
            }
            else {
                theError = [NSError errorWithDomain:@"OSKPinboardUtility" code:500 userInfo:@{NSLocalizedFailureReasonErrorKey:@"Unable to sign into Pinboard because the token could not be parsed from the response."}];
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (theError) {
                        OSKLog(@"Unable to sign into Pinboard: %@", error);
                    }
                    completion(newAccount, theError);
                });
            }
        });
    }] resume];
}

+ (void)addBookmark:(OSKLinkBookmarkContentItem *)linkItem withAccountCredential:(OSKManagedAccountCredential *)accountCredential completion:(void(^)(BOOL success, NSError *error))completion {
    BOOL hasValidURL = (linkItem.url.absoluteString.length);
    BOOL hasValidCredentials = (accountCredential.token != nil && accountCredential.accountID != nil);
    if (hasValidURL == NO || hasValidCredentials == NO) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                NSError *error = nil;
                if (hasValidCredentials == NO) {
                    NSDictionary *info = @{NSLocalizedFailureReasonErrorKey:@"OSKPinboardUtility: Invalid credentials. Perhaps try signing out and back in again."};
                    error = [[NSError alloc] initWithDomain:@"Overshare" code:400 userInfo:info];
                }
                else if (hasValidURL == NO) {
                    NSDictionary *info = @{NSLocalizedFailureReasonErrorKey:@"OSKPinboardUtility: Unable to obtain a valid string from the NSURL."};
                    error = [[NSError alloc] initWithDomain:@"Overshare" code:400 userInfo:info];
                }
                completion(NO, error);
            }
        });
    }
    else if (linkItem.title.length) {
        [self _addBookmarkWithExistingTitle:linkItem withAccountCredential:accountCredential completion:completion];
    }
    else {
        [self _getWebPageTitleForURL:linkItem.url.absoluteString completion:^(NSString *fetchedTitle) {
            [linkItem setTitle:fetchedTitle];
            [self _addBookmarkWithExistingTitle:linkItem withAccountCredential:accountCredential completion:completion];
        }];
    }
}

+ (void)_addBookmarkWithExistingTitle:(OSKLinkBookmarkContentItem *)linkItem withAccountCredential:(OSKManagedAccountCredential *)accountCredential completion:(void(^)(BOOL success, NSError *error))completion {
    NSString *path = [NSString stringWithFormat:@"%@%@", OSKPinboardActivity_BaseURL, OSKPinboardActivity_AddBookmarkPath];
    NSDictionary *params = [self _bookmarkParamsWithItem:linkItem credential:accountCredential];
    NSURLSession *sesh = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [NSMutableURLRequest osk_requestWithMethod:@"GET" URLString:path parameters:params serialization:OSKParameterSerializationType_Query];
    [[sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *theError = error;
                if ([NSHTTPURLResponse statusCodeAcceptableForResponse:response] == NO && error == nil) {
                    theError = [NSError errorWithDomain:@"OSKPinboardUtility" code:400 userInfo:@{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Request failed: %@", response.description]}];
                }
                if (theError) {
                    OSKLog(@"Unable to add bookmark to Pinboard: %@", theError);
                }
                completion((error == nil), theError);
            });
        }
    }] resume];
}

+ (NSDictionary *)_bookmarkParamsWithItem:(OSKLinkBookmarkContentItem *)item credential:(OSKManagedAccountCredential *)credential {
    NSString *title = item.title.copy;
    
    if (title.length == 0) {
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        title = [NSString stringWithFormat:@"Saved with %@", appName];
    }
    
    NSString *tokenString = [NSString stringWithFormat:OSKPinboardActivity_TokenParamValue, credential.accountID, credential.token];
    
    NSMutableDictionary *mutableParams = [NSMutableDictionary dictionary];
    
    mutableParams[@"url"] = item.url.absoluteString;
    mutableParams[@"description"] = title;
    mutableParams[@"format"] = @"json";
    mutableParams[OSKPinboardActivity_TokenParamKey] = tokenString;
    mutableParams[@"toread"] = (item.markToRead) ? @"yes" : @"no";
    if (item.tags.count) {
        mutableParams[@"tags"] = [item.tags componentsJoinedByString:@","];
    }
    if (item.notes.length) {
        mutableParams[@"extended"] = item.notes.copy;
    }

    return mutableParams;
}

+ (void)_getWebPageTitleForURL:(NSString *)url completion:(void(^)(NSString *fetchedTitle))completion {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSURLSession *sesh = [NSURLSession sharedSession];
    [[sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __block NSString *title = nil;
            if (data) {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (html.length) {
                    NSError *error = NULL;
                    NSRegularExpression *regex = [NSRegularExpression
                                                  regularExpressionWithPattern:@"<title>(.+)</title>"
                                                  options:NSRegularExpressionCaseInsensitive
                                                  error:&error];
                    [regex enumerateMatchesInString:html options:0 range:NSMakeRange(0, [html length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop){
                        title = [html substringWithRange:[match rangeAtIndex:1]];
                        *stop = YES;
                    }];
                }
            }
            
            if (title.length) {
                title = [title stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                title = [self _stripHTMLEntitiesFromString:title];
            }
            
            if (title.length == 0) {
                NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
                title = [NSString stringWithFormat:@"Saved with %@", appName];
            }
            
            if (completion) {
                completion(title);
            }
        });
    }] resume];
}

+ (NSString *)_stripHTMLEntitiesFromString:(NSString *)sourceString {
    if (sourceString.length == 0) {
        return @"";
    }
    NSMutableString *string = [NSMutableString stringWithString:sourceString];
    NSDictionary *symbolReplacementPairs = @{
                                             @"&nbsp;":@" ",
                                             @"&amp;":@"&",
                                             @"&cent;":@"¢",
                                             @"&pound;":@"£",
                                             @"&yen;":@"¥",
                                             @"&euro;":@"€",
                                             @"&copy;":@"©",
                                             @"&reg;":@"®",
                                             @"&trade;":@"™",
                                             @"&nbsp;":@" ",
                                             @"&quot;":@"\"",
                                             @"&apos;":@"'",
                                             @"&iexcl;":@"¡",
                                             @"&ndash;":@"–",
                                             @"&mdash;":@"—",
                                             @"&lsquo;":@"‘",
                                             @"&rsquo;":@"’",
                                             @"&ldquo;":@"“",
                                             @"&rdquo;":@"”",
                                             @"&#8211;":@"–",
                                             @"&#39;":@"'",
                                             @"&#34;":@"\"",
                                             @"&#38;":@"&",
                                             @"&#8216;":@"‘",
                                             @"&#8217;":@"’",
                                             @"&#8220;":@"“",
                                             @"&#8221;":@"”	",
                                             };
    for (NSString *key in symbolReplacementPairs.allKeys) {
        NSString *replacement = [symbolReplacementPairs objectForKey:key];
        [string replaceOccurrencesOfString:key
                                withString:replacement
                                   options:NSCaseInsensitiveSearch
                                     range:NSMakeRange(0, string.length)];
    }
    return string;
}

@end








