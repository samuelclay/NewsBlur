//
//  NBLoadingCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/12/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "NBLoadingCell.h"

@implementation NBLoadingCell

@synthesize animating;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColorFromLightDarkRGB(0x5C89C9, 0x666666);
        animating = YES;
    }
    return self;
}

- (void)endAnimation {
    animating = NO;
}
- (void)setNeedsLayout {
	[super setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

- (void)animate {
    if (!self.window || !self.superview.window) return;
    if (!animating) return;
    self.backgroundColor = UIColorFromLightDarkRGB(0x5C89C9, 0x666666);
    [UIView animateWithDuration:.650f delay:0.f options:nil animations:^{
        self.backgroundColor = UIColorFromLightDarkRGB(0xE1EBFF, 0x222222);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:1.05f animations:^{
            self.backgroundColor = UIColorFromLightDarkRGB(0x5C89C9, 0x666666);
        } completion:^(BOOL finished) {
            [self animate];
        }];
    }];
}

@end
