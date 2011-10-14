//
//  Utilities.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/13/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import "Utilities.h"

@implementation Utilities

+ (void)cacheImage:(UIImage *)image forFeedId:(NSString *)feedId {
//    UIImage *image = [[UIImage alloc] initWithData:imageData];
    NSString *path = [NSString stringWithFormat:@"%@_favicon.png", feedId];
    [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
    [image release];
}

+ (UIImage *)getCachedImage:(NSString *)feedId {
    NSString *path = [NSString stringWithFormat:@"%@_favicon.png", feedId];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return [UIImage imageWithContentsOfFile:path];
    } else {
        UIImage *image = [UIImage imageNamed:@"world.png"];
        return image;
    }

}

@end
