//
//  NSString+OSKEmoji.m
//  Unread
//
//  Created by Jared on 1/18/14.
//  Copyright (c) 2014 Nice Boy LLC. All rights reserved.
//

#import "NSString+OSKEmoji.h"

@implementation NSString (OSKEmoji)

- (NSUInteger)osk_lengthAdjustingForComposedCharacters {
    return [self lengthOfBytesUsingEncoding:NSUTF32StringEncoding]/4;
}

@end



