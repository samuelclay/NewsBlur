//
//  Utilities.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/17/11.
//  Copyright (c) 2011 NewsBlur. All rights reserved.
//

#import "Utilities.h"

@implementation Utilities

static NSCache *imageCache;

+ (void)saveImage:(UIImage *)image feedId:(NSString *)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [paths objectAtIndex:0];
    NSString *path = [cacheDirectory stringByAppendingPathComponent:filename];
    
    [UIImageJPEGRepresentation(image, 1.0) writeToFile:path atomically:YES];
    
    [imageCache setObject:image forKey:filename];
}

+ (UIImage *)getImage:(NSString *)filename {
    UIImage *image;
    
    image = [imageCache objectForKey:filename];
    if (!image) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *cacheDirectory = [paths objectAtIndex:0];
        NSString *path = [cacheDirectory stringByAppendingPathComponent:filename];
        
        image = [UIImage imageWithContentsOfFile:path];
    }
    
    if (image) {  
        return image;
    } else {
        return nil;
    }
}

@end
