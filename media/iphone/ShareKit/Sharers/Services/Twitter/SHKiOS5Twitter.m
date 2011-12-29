//
//  SHKiOS5Twitter.m
//  ShareKit
//
//  Created by Vilem Kurz on 17.11.2011.
//  Copyright (c) 2011 Cocoa Miners. All rights reserved.
//

#import "SHKiOS5Twitter.h"
#import <Twitter/Twitter.h>

@interface SHKiOS5Twitter ()

@property (retain) UIViewController *currentTopViewController;

- (UIViewController *)getCurrentRootViewController;
- (UIViewController *)getCurrentTopViewController;

@end

@implementation SHKiOS5Twitter

@synthesize currentTopViewController;

- (void)dealloc {
    
    [currentTopViewController release];
    [super dealloc];
}

+ (NSString *)sharerTitle
{
	return @"Twitter";
}

+ (NSString *)sharerId
{
	return @"SHKTwitter";
}

- (void)share {
    
    TWTweetComposeViewController *iOS5twitter = [[TWTweetComposeViewController alloc] init];
    
    [iOS5twitter addImage:self.item.image];    
    [iOS5twitter addURL:self.item.URL];
    
    if (self.item.shareType == SHKShareTypeText ) {
        [iOS5twitter setInitialText:[item.text length]>140 ? [item.text substringToIndex:140] : item.text];
    } else {
        [iOS5twitter setInitialText:[item.title length]>140 ? [item.title substringToIndex:140] : item.title];
    }
    
    iOS5twitter.completionHandler = ^(TWTweetComposeViewControllerResult result) 
    {
        [self.currentTopViewController dismissViewControllerAnimated:YES completion:nil];
        
        switch (result) {
                
            case TWTweetComposeViewControllerResultDone:
                [self sendDidFinish];
                break;
                
            case TWTweetComposeViewControllerResultCancelled:
                [self sendDidCancel];                
                
            default:
                break;
        }
    };   
    
    self.currentTopViewController = [self getCurrentTopViewController];    
    [self.currentTopViewController presentViewController:iOS5twitter animated:YES completion:nil];
    [iOS5twitter release];       
}

#pragma mark -

- (UIViewController *)getCurrentRootViewController {
    
    UIWindow *topWindow = [[UIApplication sharedApplication] keyWindow];
    if (topWindow.windowLevel != UIWindowLevelNormal)
    {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(topWindow in windows)
        {
            if (topWindow.windowLevel == UIWindowLevelNormal)
                break;
        }
    }
    
    UIView *rootView = [[topWindow subviews] objectAtIndex:0];	
    id nextResponder = [rootView nextResponder];
    
    UIViewController *result = nil;    
    if ([nextResponder isKindOfClass:[UIViewController class]]) 
        result = nextResponder;
    
    return result;
}

- (UIViewController *)getCurrentTopViewController {
    
    UIViewController *result = [self getCurrentRootViewController];
    while (result.modalViewController != nil)
		result = result.modalViewController;
	return result;    
}

# pragma mark SHKSharerDelegate methods

- (void)sharerFinishedSending:(SHKSharer *)sharer {
    
    if (!quiet) 
        [[SHKActivityIndicator currentIndicator] displayCompleted:SHKLocalizedString(@"Saved!")];
}

- (void)sharerCancelledSending:(SHKSharer *)sharer {
    
}

@end
