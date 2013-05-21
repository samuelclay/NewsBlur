/* Copyright 2012 IGN Entertainment, Inc. */

#import "SafariService.h"

@implementation SafariService

NSString *const SafariActivity =
@"SafariActivity";

+ (void)shareWithParams:(NSDictionary *)params onViewController:(UIViewController *)viewController
{
    NSURL *url = [params objectForKey:@"url"];
    [[UIApplication sharedApplication] openURL:url];
}

@end
