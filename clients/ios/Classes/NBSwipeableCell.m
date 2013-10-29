//
//  NBSwipeableCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 9/27/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "NBSwipeableCell.h"
#import "MCSwipeTableViewCell.h"

@implementation NBSwipeableCell

- (void)setNeedsDisplay {
    [super setNeedsDisplay];
    for (UIView *view in self.contentView.subviews) {
        [view setNeedsDisplay];
    }
}

- (void)setNeedsLayout {
    [super setNeedsLayout];
    for (UIView *view in self.contentView.subviews) {
        [view setNeedsLayout];
    }
}

- (void) setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:NO];
    
    if (animated) {
        [CATransaction begin];
        CATransition* animation = [CATransition animation];
        animation.type = kCATransitionFade;
        animation.duration = 0.6;
        [animation setTimingFunction:[CAMediaTimingFunction
                                      functionWithName:kCAMediaTimingFunctionDefault]];
        [self.contentView.layer addAnimation:animation forKey:@"deselectRow"];
        [CATransaction commit];
    }
}

- (UIImage *)imageByApplyingAlpha:(UIImage *)image withAlpha:(CGFloat) alpha {
    UIGraphicsBeginImageContextWithOptions(image.size, NO, 0.0f);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect area = CGRectMake(0, 0, image.size.width, image.size.height);
    
    CGContextScaleCTM(ctx, 1, -1);
    CGContextTranslateCTM(ctx, 0, -area.size.height);
    
    CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
    
    CGContextSetAlpha(ctx, alpha);
    
    CGContextDrawImage(ctx, area, image.CGImage);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return newImage;
}

@end
