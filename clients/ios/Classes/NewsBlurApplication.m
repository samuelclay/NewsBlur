//
//  NewsBlurApplication.m
//  NewsBlur
//
//  Created by David Sinclair on 2025-08-27.
//  Copyright © 2025 NewsBlur. All rights reserved.
//

#import "NewsBlurApplication.h"
#import "NewsBlurAppDelegate.h"

@implementation NewsBlurApplication

- (void)buildMenuWithBuilder:(id)builder {
    [super buildMenuWithBuilder:builder];
    
    NewsBlurAppDelegate *delegate = (NewsBlurAppDelegate *)self.delegate;
    
    [delegate buildMenuWithBuilder:builder];
}

@end
