//
// Created by Jesper Kamstrup Linnet on 14/07/13.
// Copyright (c) 2013 NewsBlur. All rights reserved.
//


#import "CheckmarkHud.h"
#import "NewsBlurAppDelegate.h"
#import "StoryPageControl.h"


@implementation CheckmarkHud

- (void)flashCheckmarkHud:(NSString *)messageType onView:(UIView *)view {
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view animated:YES];
    hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
    hud.mode = MBProgressHUDModeCustomView;
    hud.removeFromSuperViewOnHide = YES;

    if ([messageType isEqualToString:@"reply"]) {
        hud.labelText = @"Replied";
    } else if ([messageType isEqualToString:@"edit-reply"]) {
        hud.labelText = @"Edited Reply";
    } else if ([messageType isEqualToString:@"edit-share"]) {
        hud.labelText = @"Edited Comment";
    } else if ([messageType isEqualToString:@"share"]) {
        hud.labelText = @"Shared";
    } else if ([messageType isEqualToString:@"like-comment"]) {
        hud.labelText = @"Favorited";
    } else if ([messageType isEqualToString:@"unlike-comment"]) {
        hud.labelText = @"Unfavorited";
    } else if ([messageType isEqualToString:@"saved"]) {
        hud.labelText = @"Saved";
    } else if ([messageType isEqualToString:@"unsaved"]) {
        hud.labelText = @"No longer saved";
    } else if ([messageType isEqualToString:@"unread"]) {
        hud.labelText = @"Unread";
    } else if ([messageType isEqualToString:@"added"]) {
        hud.labelText = @"Added";
    }
    [hud hide:YES afterDelay:1];
}

@end