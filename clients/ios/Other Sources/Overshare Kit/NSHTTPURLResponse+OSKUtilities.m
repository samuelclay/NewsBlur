//
//  NSHTTPURLResponse+OSKUtilities.m
//  Overshare
//
//  Created by Jared Sinclair on 10/28/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "NSHTTPURLResponse+OSKUtilities.h"

static NSIndexSet *OSKAcceptableStatusCodes;

@implementation NSHTTPURLResponse (OSKUtilities)

+ (BOOL)statusCodeAcceptableForResponse:(NSURLResponse *)response {
    NSUInteger statusCode = ([response isKindOfClass:[NSHTTPURLResponse class]])
                            ? (NSUInteger)[(NSHTTPURLResponse *)response statusCode]
                            : 200;
    if (OSKAcceptableStatusCodes == nil) {
        OSKAcceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    }
    return [OSKAcceptableStatusCodes containsIndex:statusCode];
}

+ (BOOL)statusCodeAcceptableForResponse:(NSURLResponse *)response otherAcceptableCodes:(NSIndexSet *)otherCodes {
    NSUInteger statusCode = ([response isKindOfClass:[NSHTTPURLResponse class]])
    ? (NSUInteger)[(NSHTTPURLResponse *)response statusCode]
    : 200;
    if (OSKAcceptableStatusCodes == nil) {
        OSKAcceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    }
    return ([OSKAcceptableStatusCodes containsIndex:statusCode] || [otherCodes containsIndex:statusCode]);
}

@end
