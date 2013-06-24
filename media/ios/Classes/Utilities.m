//
//  Utilities.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/17/11.
//  Copyright (c) 2011 NewsBlur. All rights reserved.
//

#import "Utilities.h"
#import <CommonCrypto/CommonCrypto.h>

void drawLinearGradient(CGContextRef context, CGRect rect, CGColorRef startColor, 
                        CGColorRef  endColor) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = { 0.0, 1.0 };
    
    NSArray *colors = [NSArray arrayWithObjects:(__bridge id)startColor, (__bridge id)endColor, nil];
    
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, 
                                                        (__bridge CFArrayRef) colors, locations);
    
    CGPoint startPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
    CGPoint endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));
    
    CGContextSaveGState(context);
    CGContextAddRect(context, rect);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGContextRestoreGState(context);
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

@implementation Utilities

static NSMutableDictionary *imageCache;

+ (void)saveImage:(UIImage *)image feedId:(NSString *)filename {
    if (!imageCache) {
        imageCache = [NSMutableDictionary dictionary];
    }
    
    // Save image to memory-based cache, for performance when reading.
//    NSLog(@"Saving %@", [imageCache allKeys]);
    if (image && [filename class] != [NSNull class]) {
        [imageCache setObject:image forKey:filename];
    } else {
//        NSLog(@"%@ has no image!!!", filename);
    }
}

+ (UIImage *)getImage:(NSString *)filename {
    return [self getImage:filename isSocial:NO];
}

+ (UIImage *)getImage:(NSString *)filename isSocial:(BOOL)isSocial {
    UIImage *image;
    if (filename && [[imageCache allKeys] containsObject:filename]) {
        image = [imageCache objectForKey:filename];
    }
    
    if (!image || [image class] == [NSNull class]) {
        // Image not in cache, search on disk.
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDirectory = [paths objectAtIndex:0];
        if (isSocial) {
            cacheDirectory = [cacheDirectory stringByAppendingPathComponent:@"avatars"];
        } else {
            cacheDirectory = [cacheDirectory stringByAppendingPathComponent:@"favicons"];
        }
        NSString *path = [cacheDirectory stringByAppendingPathComponent:filename];
        
        image = [UIImage imageWithContentsOfFile:path];
    }
    
    if (image) {  
        return image;
    } else {
        if (isSocial) {
//            return [UIImage imageNamed:@"user_light.png"];
            return nil;
        } else {
            return [UIImage imageNamed:@"world.png"];
        }
    }
}

+ (void)drawLinearGradientWithRect:(CGRect)rect startColor:(CGColorRef)startColor endColor:(CGColorRef)endColor {
    CGContextRef context = UIGraphicsGetCurrentContext(); 
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = { 0.0, 1.0 };
    
    NSArray *colors = [NSArray arrayWithObjects:(__bridge id)startColor, (__bridge id)endColor, nil];
    
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, 
                                                        (__bridge CFArrayRef) colors, locations);
    
    CGPoint startPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
    CGPoint endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));
    
    CGContextSaveGState(context);
    CGContextAddRect(context, rect);
    CGContextClip(context);
    
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGContextRestoreGState(context);
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

+ (void)saveimagesToDisk {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0);
    
    dispatch_async(queue, [^{
        for (NSString *filename in [imageCache allKeys]) {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *cacheDirectory = [paths objectAtIndex:0];
            if ([filename hasPrefix:@"social"]) {
                cacheDirectory = [cacheDirectory stringByAppendingPathComponent:@"avatars"];
            } else {
                cacheDirectory = [cacheDirectory stringByAppendingPathComponent:@"favicons"];
            }
            NSString *path = [cacheDirectory stringByAppendingPathComponent:filename];
            
            // Save image to disk
            UIImage *image = [imageCache objectForKey:filename];
            [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
        }
    } copy]);
}

+ (UIImage *)roundCorneredImage: (UIImage*) orig radius:(CGFloat) r {
    UIGraphicsBeginImageContextWithOptions(orig.size, NO, 0);
    [[UIBezierPath bezierPathWithRoundedRect:(CGRect){CGPointZero, orig.size} 
                                cornerRadius:r] addClip];
    [orig drawInRect:(CGRect){CGPointZero, orig.size}];
    UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

+ (NSString *)md5:(NSString *)string {
    const char *cStr = [string UTF8String];
    unsigned char result[16];
    CC_MD5( cStr, strlen(cStr), result ); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];  
}

@end