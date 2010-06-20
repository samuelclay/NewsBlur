//
//  NewsBlurAppDelegate.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright __MyCompanyName__ 2010. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "NewsBlurViewController.h"

@implementation NewsBlurAppDelegate

@synthesize window;
@synthesize viewController;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    // Override point for customization after app launch    
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];
	
	return YES;
}


- (void)dealloc {
    [viewController release];
    [window release];
    [super dealloc];
}


@end
