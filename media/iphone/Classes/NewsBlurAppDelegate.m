//
//  NewsBlurAppDelegate.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "NewsBlurViewController.h"
#import "FeedDetailViewController.h"

@implementation NewsBlurAppDelegate

@synthesize window;
@synthesize navigationController;
@synthesize feedsViewController;
@synthesize feedDetailViewController;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    navigationController.viewControllers = [NSArray arrayWithObject:feedsViewController];
    
    [window addSubview:navigationController.view];
    //[window addSubview:feedDetailViewController.view];
    [window makeKeyAndVisible];
	return YES;
}


- (void)dealloc {
    [feedsViewController release];
    [feedDetailViewController release];
    [navigationController release];
    [window release];
    [super dealloc];
}

- (void)loadFeedDetailView {
    NSLog(@"Loading feed detail view: %@, %@", navigationController, feedDetailViewController);
    [[self navigationController] pushViewController:feedDetailViewController animated:YES];
}

- (void)hideNavigationBar:(BOOL)animated {
    [[self navigationController] setNavigationBarHidden:YES animated:animated];
}

- (void)showNavigationBar:(BOOL)animated {
    [[self navigationController] setNavigationBarHidden:NO animated:animated];
}

@end
