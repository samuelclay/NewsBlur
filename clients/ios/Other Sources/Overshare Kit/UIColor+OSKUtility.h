//
//  UIColor+OSKUtility.h
//  Overshare
//
//  Created by Jared Sinclair on 10/24/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//
//
//  Based on UIColor+Extended by Erica Sadun
//

@import UIKit;

@interface UIColor (OSKUtility)

- (CGColorSpaceModel)osk_colorSpaceModel;
- (BOOL)osk_canProvideRGBComponents;
- (CGFloat)osk_luminance;
- (UIColor *)osk_colorByInterpolatingToColor:(UIColor *)color byFraction:(CGFloat)fraction;
- (UIColor *)osk_contrastingColor;

@end
