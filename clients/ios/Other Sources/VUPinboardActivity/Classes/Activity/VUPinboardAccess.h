//
//  VUPinboardAccess.h
//  UIActivityDemo
//
//  Created by Boris Buegling on 30.09.12.
//  Copyright (c) 2012 Boris Buegling. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^VUPinboardCompletionHandler)(BOOL success, NSError* error);

@interface VUPinboardAccess : NSObject

-(id)initWithAccessToken:(NSString*)accessToken;

-(void)addURL:(NSURL*)url description:(NSString*)description tags:(NSString*)tags shared:(BOOL)shared toread:(BOOL)toread
    withCompletionHandler:(VUPinboardCompletionHandler)completionHandler;

@end
