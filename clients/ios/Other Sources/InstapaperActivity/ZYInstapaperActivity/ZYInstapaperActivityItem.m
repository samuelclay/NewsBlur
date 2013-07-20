//
//  ZYInstapaperActivityItem.m
//  ZYInstapaperActivity
//
//  Created by Mariano Abdala on 9/29/12.
//  Copyright (c) 2012 Zerously. All rights reserved.
//
//  https://github.com/marianoabdala/ZYInstapaperActivity
//

#import "ZYInstapaperActivityItem.h"

@interface ZYInstapaperActivityItem ()

@property (copy, nonatomic) NSURL *url;

@end

@implementation ZYInstapaperActivityItem

#pragma mark - Hierarchy
#pragma mark NSObject
- (BOOL)isEqual:(id)object {
    
    if (object == nil) {
        
        return NO;
    }
    
    if ([object isKindOfClass:[ZYInstapaperActivityItem class]] == NO) {
        
        return NO;
    }
    
    ZYInstapaperActivityItem *item =
    (ZYInstapaperActivityItem *)object;
    
    return
    [item.url isEqual:self.url] &&
    [item.title isEqual:self.title] &&
    [item.description isEqual:self.description];
}


#pragma mark - Self
#pragma mark ZYInstapaperActivityItem
- (id)initWithURL:(NSURL *)url {

    if (url == nil) {
        
        return nil;
    }
    
    self =
    [super init];

    if (self != nil) {
        self.url = url;
		self.title = @"";
		self.description = @"";
    }

    return self;
}

@end
