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

+ (void)drawLinearGradientWithRect:(CGRect)rect startColor:(CGColorRef)startColor endColor:(CGColorRef)endColor;
+ (UIImage *)roundCorneredImage:(UIImage *)orig radius:(CGFloat)r;
+ (UIImage *)roundCorneredImage: (UIImage*)orig radius:(CGFloat)r convertToSize:(CGSize)size;
+ (UIImage *)templateImageNamed:(NSString *)imageName sized:(CGFloat)size;
+ (UIImage *)imageNamed:(NSString *)imageName sized:(CGFloat)size;
+ (UIImage *)imageWithImage:(UIImage *)image convertToSize:(CGSize)size;
+ (NSString *)md5:(NSString *)string;
+ (NSString *)formatLongDateFromTimestamp:(NSInteger)timestamp;
+ (NSString *)formatShortDateFromTimestamp:(NSInteger)timestamp;

@end

@interface UIResponder (FirstResponder)

+(id)currentFirstResponder;

@end
