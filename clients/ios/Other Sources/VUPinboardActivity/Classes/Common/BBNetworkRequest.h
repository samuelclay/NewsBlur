//
//  BBNetworkRequest.h
//
//  Created by Boris Buegling on 05.08.12.
//  Copyright (c) 2012 Boris Buegling. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BBNetworkRequest : NSMutableURLRequest

+(id)requestWithURLString:(NSString*)urlString;
+(id)requestWithURLString:(NSString *)urlString parameters:(NSDictionary*)parameters;

-(void)sendAsynchronousRequestWithCompletionHandler:(void (^)(NSHTTPURLResponse*, NSData*))completionHandler
                                       errorHandler:(void (^)(NSHTTPURLResponse*, NSData*, NSError*))errorHandler;

@end
