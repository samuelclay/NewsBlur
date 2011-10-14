//
//  Utilities.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/13/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Utilities : NSObject {
    
}

+ (void)cacheImage:(UIImage *)image forFeedId:(NSString *)feedId;
+ (UIImage *)getCachedImage:(NSString *)feedId;

@end
