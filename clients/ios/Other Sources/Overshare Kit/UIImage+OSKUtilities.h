//
//  UIImage+OSKUtilities.h
//  Overshare
//
//  Created by Jared Sinclair 10/29/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//
//  Based on code by Ole Zorn (https://gist.github.com/omz/1102091)
//

#import <UIKit/UIKit.h>

@interface UIImage (OSKUtilities)

+ (UIImage *)osk_maskedImage:(UIImage *)image color:(UIColor *)color;
+ (CGFloat)osk_recommendedUploadQuality:(UIImage *)image;
+ (BOOL)osk_imageSizeIsLikelyADeviceScreenShot:(CGSize)size;

@end
