//
//  NSString+OSKEmoji.h
//  Unread
//
//  Created by Jared on 1/18/14.
//  Copyright (c) 2014 Nice Boy LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (OSKEmoji)

- (NSUInteger)osk_lengthAdjustingForComposedCharacters;

@end
