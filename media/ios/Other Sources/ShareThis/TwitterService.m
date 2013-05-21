/* Copyright 2012 IGN Entertainment, Inc. */

#import "TwitterService.h"
#import <Social/Social.h>
#import <Twitter/Twitter.h>

@implementation TwitterService

+ (void)shareWithParams:(NSDictionary *)params onViewController:(UIViewController *)viewController
{
    // IOS 6+ services
    if ([ShareThis isSocialAvailable]) {
        __block __weak SLComposeViewController *slComposeSheet = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
        [slComposeSheet setInitialText:[params objectForKey:@"title"]];
        [slComposeSheet addURL:[params objectForKey:@"url"]];
        [slComposeSheet addImage:[params objectForKey:@"image"]];
        
        [slComposeSheet setCompletionHandler:^
         (SLComposeViewControllerResult result){
             switch (result) {
                 case SLComposeViewControllerResultCancelled:
                     break;
                 case SLComposeViewControllerResultDone:
                     break;
                 default:
                     break;
             }
             // Bug in framework where you have to press Cancel button twice for twitter
            [slComposeSheet dismissViewControllerAnimated:YES completion:nil];
         }];
        [viewController presentViewController:slComposeSheet animated:YES completion:nil];
        
    } else {
        // Create the view controller
        TWTweetComposeViewController *twitter = [[TWTweetComposeViewController alloc] init];
        [twitter addURL:[params objectForKey:@"url"]];
        [twitter addImage:[params objectForKey:@"image"]];
        [twitter setInitialText:[params objectForKey:@"title"]];
        // Show twitter view on passed in viewcontroller
        [viewController presentViewController:twitter animated:YES completion:nil];
    }

}

@end
