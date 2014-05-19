//
//  OSKOAuthUtility.h
//  Overshare Kit
//
//  Created by Jared Sinclair October 20, 2013.
//  Copyright (c) 2013 Jared Sinclair & Justin Williams LLC. All rights reserved.
//

@import Foundation;

@interface OSKOAuthUtility : NSObject

+ (NSString *)oauth_headerStringWithHTTPMethod:(NSString *)method
                                       baseURL:(NSString *)baseURL
                             queryStringParams:(NSDictionary *)queryParams
                                    bodyParams:(NSDictionary *)bodyParams
                                   consumerKey:(NSString *)consumerKey
                                consumerSecret:(NSString *)consumerSecret
                                   accessToken:(NSString *)tokenOrNil
                             accessTokenSecret:(NSString *)tokenSecretOrNil;

@end






