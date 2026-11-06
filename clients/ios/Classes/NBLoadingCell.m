//
//  NBLoadingCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/12/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "NBLoadingCell.h"

@interface NBLoadingCell ()
@property (nonatomic) CFTimeInterval pulseStartTime;
@end

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
    [self.layer removeAnimationForKey:@"readerLoadingPulse"];
}
- (void)setNeedsLayout {
	[super setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

- (void)animate {
    if (!self.window || !self.superview.window) return;
    animating = YES;
    UIColor *base = UIColorFromLightDarkRGB(0x5C89C9, 0x666666);
    UIColor *highlight = UIColorFromLightDarkRGB(0xE1EBFF, 0x222222);
    CABasicAnimation *existing = (CABasicAnimation *)[self.layer animationForKey:@"readerLoadingPulse"];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self.layer removeAnimationForKey:@"readerLoadingPulse"];
        self.backgroundColor = base;
        return;
    }
    if (existing && CGColorEqualToColor((__bridge CGColorRef)existing.fromValue, base.CGColor) &&
        CGColorEqualToColor((__bridge CGColorRef)existing.toValue, highlight.CGColor)) return;
    self.backgroundColor = base;
    // NBLoadingCell.m retains phase across reloadData detach/reattach and never stacks recursive pulses.
    if (self.pulseStartTime == 0) self.pulseStartTime = CACurrentMediaTime();
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
    pulse.fromValue = (id)base.CGColor;
    pulse.toValue = (id)highlight.CGColor;
    pulse.duration = 0.85;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    pulse.beginTime = [self.layer convertTime:self.pulseStartTime fromLayer:nil];
    [self.layer addAnimation:pulse forKey:@"readerLoadingPulse"];
}

@end
