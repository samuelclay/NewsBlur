//
//  OSKLinkShorteningUtility.m
//  Unread
//
//  Created by Jared Sinclair 11/19/13.
//  Copyright (c) 2013 Nice Boy LLC. All rights reserved.
//

#import "OSKLinkShorteningUtility.h"

#import "NSMutableURLRequest+OSKUtilities.h"

static NSString * OSKBitlyGenericToken = @"09f518c26b9cde0b42550e3e02d45b13a1d76f4a";
static NSString * OSKBitlyLinkShorteningURL = @"https://api-ssl.bitly.com/v3/shorten";
static NSString * OSKBitlyParamKey_AccessToken = @"access_token";
static NSString * OSKBitlyParamKey_LongURL = @"longURL";
static NSString * OSKBitlyResponseKey_Data = @"data";
static NSString * OSKBitlyResponseKey_Hash = @"hash";
static NSString * OSKBitlyDomain = @"bit.ly";

static NSInteger OSKShorteningThreshold = 30;

@implementation OSKLinkShorteningUtility

+ (BOOL)shorteningRecommended:(NSString *)longURL {
    return longURL.length > OSKShorteningThreshold;
}

+ (void)shortenURL:(NSString *)longURL completion:(void(^)(NSString *shortURL))completion {
    NSString *path = OSKBitlyLinkShorteningURL;
    NSDictionary *params = @{OSKBitlyParamKey_AccessToken:OSKBitlyGenericToken, OSKBitlyParamKey_LongURL:longURL};
    NSMutableURLRequest *request = nil;
    request = [NSMutableURLRequest osk_requestWithMethod:@"GET" URLString:path parameters:params serialization:OSKParameterSerializationType_Query];
    NSURLSession *sesh = [NSURLSession sharedSession];
    [[sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *shortURL = nil;
        if (data) {
            NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSDictionary *dataObject = responseDictionary[OSKBitlyResponseKey_Data];
            NSString *hash = dataObject[OSKBitlyResponseKey_Hash];
            if (hash.length) {
                shortURL = [NSString stringWithFormat:@"http://%@/%@", OSKBitlyDomain, hash];
            }
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(shortURL);
            });
        }
    }] resume];
}

@end








