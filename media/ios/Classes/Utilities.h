//
//  Utilities.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/17/11.
//  Copyright (c) 2011 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Utilities : NSObject <NSCacheDelegate> {
    NSCache *imageCache;
}

+ (void)saveImage:(UIImage *)image feedId:(NSString *)filename;
+ (UIImage *)getImage:(NSString *)filename;
+ (void)saveimagesToDisk;
+ (UIImage *)roundCorneredImage:(UIImage *)orig radius:(CGFloat)r;

@end
