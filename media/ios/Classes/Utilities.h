//
//  Utilities.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/17/11.
//  Copyright (c) 2011 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>

void drawLinearGradient(CGContextRef context, CGRect rect, CGColorRef startColor, 
                        CGColorRef  endColor);

@interface Utilities : NSObject <NSCacheDelegate> {
    NSCache *imageCache;
}

+ (void)saveImage:(UIImage *)image feedId:(NSString *)filename;
+ (UIImage *)getImage:(NSString *)filename;
+ (UIImage *)getImage:(NSString *)filename isSocial:(BOOL)isSocial;
+ (void)drawLinearGradientWithRect:(CGRect)rect startColor:(CGColorRef)startColor endColor:(CGColorRef)endColor;
+ (void)saveimagesToDisk;
+ (UIImage *)roundCorneredImage:(UIImage *)orig radius:(CGFloat)r;

@end
