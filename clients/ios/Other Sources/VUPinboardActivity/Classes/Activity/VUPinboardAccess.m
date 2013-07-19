//
//  VUPinboardAccess.m
//  UIActivityDemo
//
//  Created by Boris Buegling on 30.09.12.
//  Copyright (c) 2012 Boris Buegling. All rights reserved.
//

#import "BBNetworkRequest.h"
#import "VUPinboardAccess.h"

static NSString* const kBaseURL = @"https://api.pinboard.in/v1/";

@interface VUPinboardAccess ()

@property (nonatomic, strong) NSString* accessToken;

@end

@implementation VUPinboardAccess

-(id)initWithAccessToken:(NSString*)accessToken {
    self = [super init];
    if (self) {
        self.accessToken = accessToken;
    }
    return self;
}

-(void)addURL:(NSURL*)url description:(NSString*)description tags:(NSString*)tags shared:(BOOL)shared toread:(BOOL)toread
        withCompletionHandler:(VUPinboardCompletionHandler)completionHandler {
    if (!description || description.length == 0) {
        description = @"none";
    }
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithDictionary:@{
        @"auth_token": self.accessToken,
        @"description": description,
        @"url" : [url absoluteString],
        @"shared": shared ? @"yes" : @"no",
        @"toread": toread ? @"yes" : @"no"
    }];
    
    if (tags) {
        [parameters setValue:tags forKey:@"tags"];
    }
                                       
    BBNetworkRequest* request = [BBNetworkRequest requestWithURLString:[kBaseURL stringByAppendingString:@"posts/add"] parameters:parameters];
    [request sendAsynchronousRequestWithCompletionHandler:^(NSHTTPURLResponse* response, NSData* data) {
        if (completionHandler) {
            completionHandler(YES, NULL);
        }
    } errorHandler:^(NSHTTPURLResponse* response, NSData* data, NSError* error) {
        if (completionHandler) {
            completionHandler(NO, error);
        }
    }];
}

@end
