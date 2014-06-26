//
//  NSDictionary+OSKModel.h
//  Overshare
//
//  Created by Jared Sinclair on 10/10/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "NSDictionary+OSKModel.h"

@implementation NSDictionary (OSKModel)

- (NSString *)osk_nonNullStringIDForKey:(NSString *)key {
    NSString *string = nil;
    id value = [self osk_nonNullObjectForKey:key];
    if ([value isKindOfClass:[NSNumber class]]) {
        string = [(NSNumber *)value stringValue];
    } else {
        string = value;
    }
    return string;
}

- (id)osk_nonNullObjectForKey:(NSString *)key {
    id value = [self objectForKey:key];
    if ([value isKindOfClass:[NSNull class]]) {
        value = nil;
    }
    return value;
}

@end
