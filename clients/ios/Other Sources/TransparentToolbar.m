//
//  TransparentToolbar.m
//  NewsBlur
//
//  Created by Samuel Clay on 8/13/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import "TransparentToolbar.h"

@implementation TransparentToolbar

@synthesize onRightSide;

// Override draw rect to avoid
// background coloring
- (void)drawRect:(CGRect)rect {
    // do nothing in here
}

// Set properties to make background
// translucent.
- (void) applyTranslucentBackground
{
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    self.translucent = YES;
}

// Override init.
- (id) init
{
    self = [super init];
    [self applyTranslucentBackground];
    return self;
}

// Override initWithFrame.
- (id) initWithFrame:(CGRect) frame
{
    self = [super initWithFrame:frame];
    [self applyTranslucentBackground];
    return self;
}

- (UIEdgeInsets)alignmentRectInsets {
    UIEdgeInsets insets;
    if (self.keepSpacing) return UIEdgeInsetsZero;
    
    if (![self isLeftButton] || self.onRightSide) {
        insets = UIEdgeInsetsMake(0, 0, 0, 9.0f);
    } else {
        insets = UIEdgeInsetsMake(0, 9.0f, 0, 0);
    }
    return insets;
}

- (BOOL)isLeftButton {
    return self.frame.origin.x < (self.window.frame.size.width / 2);
}

@end