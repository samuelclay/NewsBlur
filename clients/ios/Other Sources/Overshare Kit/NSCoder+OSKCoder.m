//
//  NSCoder+OSKCoder.m
//  Overshare
//
//  Created by Jared Sinclair on 10/11/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "NSCoder+OSKCoder.h"

@implementation NSCoder (OSKCoder)

+ (void)osk_encodeObjectIfNotNil:(id)object forKey:(NSString *)key withCoder:(NSCoder *)anEncoder {
    if (object != nil && [object isKindOfClass:[NSNull class]] == NO) {
        [anEncoder encodeObject:object forKey:key];
    }
}

@end



