//
//  NewsBlurApplication.m
//  NewsBlur
//
//  Created by David Sinclair on 2025-08-27.
//  Copyright © 2025 NewsBlur. All rights reserved.
//

#import "NewsBlurApplication.h"
#import "NewsBlur-Swift.h"

@implementation NewsBlurApplication

- (void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder {
    [super buildMenuWithBuilder:builder];

    if (builder.system == UIMenuSystem.mainSystem) {
        [AppMenuHelper.shared buildMenuWithBuilder:builder];
    }
}

@end
