//
//  OSKBorderedButton.m
//  Overshare
//
//  Created by Jared Sinclair on 10/12/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKBorderedButton.h"


#import "OSKPresentationManager.h"

@import QuartzCore;

@implementation OSKBorderedButton

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self commonInit];
}

- (void)commonInit {
    self.backgroundColor = [UIColor clearColor];
    CGFloat lineThickness = ([[UIScreen mainScreen] scale] > 1) ? 0.5f : 1.0f;
    self.layer.borderWidth = lineThickness;
    [self updateColors];
}

- (void)updateColors {
    OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
    
    UIColor *actionColor = [presentationManager color_action];
    
    [self setTitleColor:actionColor forState:UIControlStateNormal];

    UIColor *borderColor = [presentationManager color_toolbarBorders];
    self.layer.borderColor = borderColor.CGColor;
    
    UIColor *highlightedColor = [presentationManager color_cancelButtonColor_BackgroundHighlighted];
    UIImage *highlightedImage = [self generateHighlightedImageFromColor:highlightedColor];
    [self setBackgroundImage:highlightedImage forState:UIControlStateHighlighted];
}

- (UIImage *)generateHighlightedImageFromColor:(UIColor *)color {
    UIGraphicsBeginImageContext(CGSizeMake(32.0f, 32.0f));
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, 32.0f, 32.0f));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end




