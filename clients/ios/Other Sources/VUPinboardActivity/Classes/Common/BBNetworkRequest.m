//
//  BBNetworkRequest.m
//
//  Created by Boris Buegling on 05.08.12.
//  Copyright (c) 2012 Boris Buegling. All rights reserved.
//

#import "BBNetworkRequest.h"

static NSString* const kAuthHeaderField = @"Authorization";

@implementation BBNetworkRequest

+(NSString*)escapeStringAsParameter:(NSString*)string {
    // Encode all the reserved characters, per RFC 3986 (<http://www.ietf.org/rfc/rfc3986.txt>)
    CFStringRef escaped = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                  (CFStringRef)string,
                                                                  NULL,
                                                                  (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                  kCFStringEncodingUTF8);
    return CFBridgingRelease(escaped);
}

+(id)requestWithURLString:(NSString*)urlString {
    return [self requestWithURL:[NSURL URLWithString:urlString]];
}

+(id)requestWithURLString:(NSString *)urlString parameters:(NSDictionary*)parameters {
    NSMutableArray* parameterArray = [NSMutableArray arrayWithCapacity:parameters.count];
    
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        [parameterArray addObject:[NSString stringWithFormat:@"%@=%@",
                                   [self escapeStringAsParameter:key],
                                   [self escapeStringAsParameter:value]]];
    }];
    
    if (parameterArray.count > 0) {
        urlString = [urlString stringByAppendingFormat:@"?%@", [parameterArray componentsJoinedByString:@"&"]];
    }
    
    return [self requestWithURL:[NSURL URLWithString:urlString]];
}

-(void)sendAsynchronousRequestWithCompletionHandler:(void (^)(NSHTTPURLResponse*, NSData*))completionHandler
                                       errorHandler:(void (^)(NSHTTPURLResponse*, NSData*, NSError*))errorHandler {
    [NSURLConnection sendAsynchronousRequest:self queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse* response, NSData* data, NSError* error) {
                               NSHTTPURLResponse* httpResponse = nil;
                               NSUInteger statusCode = 200;
                               
                               if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                                   httpResponse = (NSHTTPURLResponse*)response;
                                   statusCode = httpResponse.statusCode;
                               }
                               
                               if (data && data.length > 0 && statusCode >= 200 && statusCode < 400) {
                                   if (completionHandler) {
                                       completionHandler(httpResponse, data);
                                   }
                               } else {
                                   if (errorHandler) {
                                       errorHandler(httpResponse, data, error);
                                   }
                               }
                           }];
}

@end
