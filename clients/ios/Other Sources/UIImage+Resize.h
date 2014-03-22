//
//  UIImage+Resize.h
//  NewsBlur
//
//  Created by Samuel Clay on 2/11/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Resize)

- (UIImage*)imageByScalingAndCroppingForSize:(CGSize)targetSize;

@end
