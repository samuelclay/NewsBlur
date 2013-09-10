//
//  UIActivitiesControl.m
//  NewsBlur
//
//  Created by Samuel Clay on 7/19/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "NBContainerViewController.h"
#import "UIActivitiesControl.h"
#import "TUSafariActivity.h"
#import "RWInstapaperActivity.h"
#import "ReadabilityActivity.h"
#import "PocketAPIActivity.h"
#import "VUPinboardActivity.h"
#import "ARChromeActivity.h"

@implementation UIActivitiesControl

+ (UIActivityViewController *)activityViewControllerForView:(UIViewController *)vc {
    NewsBlurAppDelegate *appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    NSURL *url = [NSURL URLWithString:[appDelegate.activeStory
                                       objectForKey:@"story_permalink"]];

    return [self activityViewControllerForView:vc withUrl:url];
}

+ (UIActivityViewController *)activityViewControllerForView:(UIViewController *)vc withUrl:(NSURL *)url {
    NewsBlurAppDelegate *appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSString *title = [appDelegate.activeStory
                       objectForKey:@"story_title"];
    NSMutableArray* appActivities = [NSMutableArray array];
    
    TUSafariActivity *openInSafari = [[TUSafariActivity alloc] init];
    [appActivities addObject:openInSafari];
    
    if ([[UIApplication sharedApplication]
         canOpenURL:[NSURL URLWithString:@"googlechrome://"]]) {
        ARChromeActivity *chromeActivity = [[ARChromeActivity alloc]
                                            initWithCallbackURL:[NSURL URLWithString:@"newsblur://"]];
        [appActivities addObject:chromeActivity];
    }
    if ([[preferences objectForKey:@"enable_instapaper"] boolValue]) {
        RWInstapaperActivity *instapaper = [[RWInstapaperActivity alloc] init];
        instapaper.username = [preferences objectForKey:@"instapaper_username"];
        instapaper.password = [preferences objectForKey:@"instapaper_password"];
        [appActivities addObject:instapaper];
    }
    if ([[preferences objectForKey:@"enable_readability"] boolValue] &&
        [ReadabilityActivity canPerformActivity]) {
        ReadabilityActivity *readabilityActivity = [[ReadabilityActivity alloc] init];
        [appActivities addObject:readabilityActivity];
    }
    if ([[preferences objectForKey:@"enable_pocket"] boolValue]) {
        PocketAPIActivity *pocket = [[PocketAPIActivity alloc] init];
        [appActivities addObject:pocket];
    }
    if ([[preferences objectForKey:@"enable_pinboard"] boolValue]) {
        VUPinboardActivity *pinboard = [[VUPinboardActivity alloc] init];
        [appActivities addObject:pinboard];
    }
    
    UIActivityViewController *shareSheet = [[UIActivityViewController alloc]
                                            initWithActivityItems:@[title, url]
                                            applicationActivities:appActivities];
    
    [shareSheet setValue:[appDelegate.activeStory objectForKey:@"story_title"] forKey:@"subject"];
    
    [shareSheet setCompletionHandler:^(NSString *activityType, BOOL completed) {
        if (completed) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(keyboardDidHide:)
                                                         name:UIKeyboardDidHideNotification
                                                       object:nil];
            
            NSString *_completedString;
            if ([activityType isEqualToString:UIActivityTypePostToTwitter]) {
                _completedString = @"Posted";
            } else if ([activityType isEqualToString:UIActivityTypePostToFacebook]) {
                _completedString = @"Posted";
            } else if ([activityType isEqualToString:UIActivityTypeMail]) {
                _completedString = @"Sent";
            } else if ([activityType isEqualToString:UIActivityTypeSaveToCameraRoll]) {
                _completedString = @"Saved";
            } else if ([activityType isEqualToString:@"instapaper"]) {
                _completedString = @"Saved";
            } else if ([activityType isEqualToString:@"UIActivityReadability"]) {
                _completedString = @"Saved";
            } else if ([activityType isEqualToString:@"Pocket"]) {
                _completedString = @"Saved";
            } else if ([activityType isEqualToString:@"pinboard"]) {
                _completedString = @"Saved";
            }
            [MBProgressHUD hideHUDForView:vc.view animated:NO];
            MBProgressHUD *storyHUD = [MBProgressHUD showHUDAddedTo:vc.view animated:YES];
            storyHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
            storyHUD.mode = MBProgressHUDModeCustomView;
            storyHUD.removeFromSuperViewOnHide = YES;
            storyHUD.labelText = _completedString;
            [storyHUD hide:YES afterDelay:1];
        }
    }];
    
    shareSheet.excludedActivityTypes = @[UIActivityTypePostToWeibo,UIActivityTypeAssignToContact];

    return shareSheet;
}

@end
