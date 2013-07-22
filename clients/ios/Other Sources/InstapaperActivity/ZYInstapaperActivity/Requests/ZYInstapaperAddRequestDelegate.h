//
//  ZYInstapaperAddRequestDelegate.h
//  ZYInstapaperActivity
//
//  Created by Mariano Abdala on 9/30/12.
//  Copyright (c) 2012 Zerously. All rights reserved.
//
//  https://github.com/marianoabdala/ZYInstapaperActivity
//

#import <Foundation/Foundation.h>

@protocol ZYInstapaperAddRequestDelegate <NSObject>

- (void)instapaperAddRequestSucceded:(id)request;
- (void)instapaperAddRequestFailed:(id)request;
- (void)instapaperAddRequestIncorrectPassword:(id)request;

@end
