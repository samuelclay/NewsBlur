//
//  NBBarButtonItem.m
//  NewsBlur
//
//  Created by Samuel Clay on 9/24/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "NBBarButtonItem.h"

@implementation NBBarButtonItem

@synthesize onRightSide;

- (UIEdgeInsets)alignmentRectInsets {
    UIEdgeInsets insets;
    if (![self isLeftButton] || self.onRightSide) {
        insets = UIEdgeInsetsMake(0, 0, 0, 8.0f);
    } else {
        insets = UIEdgeInsetsMake(0, 8.0f, 0, 0);
    }
    return insets;
}

- (BOOL)isLeftButton {
    return self.frame.origin.x < (self.window.frame.size.width / 2);
}

@end
