//
//  OSKInMemoryImageCache.m
//  Overshare
//
//  Created by Jared Sinclair on 10/22/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKInMemoryImageCache.h"

static NSString * OSKActivitySettingsIconMaskImageKey = @"OSKActivitySettingsIconMaskImageKey";

@implementation OSKInMemoryImageCache

+ (id)sharedInstance {
    static dispatch_once_t once;
    static OSKInMemoryImageCache * sharedInstance;
    dispatch_once(&once, ^ { sharedInstance = [[self alloc] init]; });
    return sharedInstance;
}

- (UIImage *)settingsIconMaskImage {
    UIImage *settingsIconMaskImage = [self objectForKey:OSKActivitySettingsIconMaskImageKey];
    if (settingsIconMaskImage == nil) {
        settingsIconMaskImage = [UIImage imageNamed:@"osk-iconMask-bw-29.png"];
        if (settingsIconMaskImage) {
            [self setObject:settingsIconMaskImage forKey:OSKActivitySettingsIconMaskImageKey];
        }
    }
    return settingsIconMaskImage;
}

@end
