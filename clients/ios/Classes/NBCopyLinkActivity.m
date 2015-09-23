//
//  NBCopyLinkActivity.m
//  NewsBlur
//
//  Created by Samuel Clay on 9/22/15.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import "NBCopyLinkActivity.h"

@implementation NBCopyLinkActivity {
    NSURL *_URL;
}

- (NSString *)activityType {
    return NSStringFromClass([self class]);
}

- (NSString *)activityTitle {
    return @"Copy Link";
}

- (UIImage *)activityImage {
    return [UIImage imageNamed:@"copy_link"];
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    for (id activityItem in activityItems) {
        if ([activityItem isKindOfClass:[NSURL class]] && [[UIApplication sharedApplication] canOpenURL:activityItem]) {
            return YES;
        }
    }
    
    return NO;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
    for (id activityItem in activityItems) {
        if ([activityItem isKindOfClass:[NSURL class]]) {
            _URL = activityItem;
        }
    }
}

- (void)performActivity {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [pasteboard setString:[_URL absoluteString]];
    
    [self activityDidFinish:YES];
}

@end
