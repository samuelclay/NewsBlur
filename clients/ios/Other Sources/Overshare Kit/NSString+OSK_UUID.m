//
//  NSString+OSK_UUID.m
//
//
//
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "NSString+OSK_UUID.h"

@implementation NSString (OSK_UUID)

+ (NSString *)osk_stringWithNewUUID {
    CFUUIDRef UUIDref = CFUUIDCreate(nil);
    NSString *newUUID = (__bridge_transfer NSString*)CFUUIDCreateString(nil, UUIDref);
    CFRelease(UUIDref);
    return newUUID;
}

@end
