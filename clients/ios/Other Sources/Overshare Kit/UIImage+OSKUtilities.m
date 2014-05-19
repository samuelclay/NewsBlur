//
//  UIImage+OSKUtilities.m
//  Overshare
//
//  Created by Jared Sinclair 10/29/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//
//  Based on code by Ole Zorn (https://gist.github.com/omz/1102091)
//

#import "UIImage+OSKUtilities.h"

@implementation UIImage (OSKUtilities)

+ (UIImage *)osk_maskedImage:(UIImage *)image color:(UIColor *)color {
	CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
	UIGraphicsBeginImageContextWithOptions(rect.size, NO, image.scale);
	CGContextRef c = UIGraphicsGetCurrentContext();
	[image drawInRect:rect];
	CGContextSetFillColorWithColor(c, [color CGColor]);
	CGContextSetBlendMode(c, kCGBlendModeSourceAtop);
	CGContextFillRect(c, rect);
	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	return result;
}

+ (CGFloat)osk_recommendedUploadQuality:(UIImage *)image {
    CGFloat quality;
    CGFloat scale = image.scale;
    CGFloat adjustedWidth = image.size.width * scale;
    CGFloat adjustedHeight = image.size.height * scale;
    if ([self osk_imageSizeIsLikelyADeviceScreenShot:CGSizeMake(adjustedWidth, adjustedHeight)]) {
        quality = 1.0f;
    }
    else if (adjustedWidth < 1000 && adjustedHeight < 1000) {
        quality = 1.0f;
    }
    else if (adjustedWidth < 2000 && adjustedHeight < 2000) {
        quality = 0.5f;
    }
    else {
        quality = 0.25f;
    }
    return quality;
}

+ (BOOL)osk_imageSizeIsLikelyADeviceScreenShot:(CGSize)size {
    BOOL isAScreenshot = NO;
    NSArray *commonScreenshotSizes = @[
                                       [NSValue valueWithCGSize:CGSizeMake(640, 1136)],
                                       [NSValue valueWithCGSize:CGSizeMake(1136, 640)],
                                       [NSValue valueWithCGSize:CGSizeMake(640, 960)],
                                       [NSValue valueWithCGSize:CGSizeMake(960, 640)],
                                       [NSValue valueWithCGSize:CGSizeMake(320, 480)],
                                       [NSValue valueWithCGSize:CGSizeMake(480, 320)],
                                       [NSValue valueWithCGSize:CGSizeMake(768, 1024)],
                                       [NSValue valueWithCGSize:CGSizeMake(1024, 768)],
                                       [NSValue valueWithCGSize:CGSizeMake(1536, 2048)],
                                       [NSValue valueWithCGSize:CGSizeMake(2048, 1536)]
                                       ];
    for (NSValue *value in commonScreenshotSizes) {
        CGSize commonSize;
        [value getValue:&commonSize];
        if (size.width == commonSize.width && size.height == commonSize.height) {
            isAScreenshot = YES;
            break;
        }
    }
    return isAScreenshot;
}


@end
