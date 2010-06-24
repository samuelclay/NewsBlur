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
//@synthesize feedDetailViewController;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    navigationController.viewControllers = [NSArray arrayWithObject:feedsViewController];
    
    [window addSubview:navigationController.view];
    [window makeKeyAndVisible];
	return YES;
}

- (void)dealloc {
    [feedsViewController release];
//    [feedDetailViewController release];
    [navigationController release];
    [window release];
    [super dealloc];
}

- (void)hideNavigationBar:(BOOL)animated {
    [[self navigationController] setNavigationBarHidden:YES animated:animated];
}

- (void)showNavigationBar:(BOOL)animated {
    [[self navigationController] setNavigationBarHidden:NO animated:animated];
}

#pragma mark -
#pragma mark Views

- (void)loadFeedDetailView:(NSMutableDictionary *)activeFeed {
    UINavigationController *navController = self.navigationController;
    FeedDetailViewController *feedDetailViewController = [[FeedDetailViewController alloc] initWithNibName:@"FeedDetailViewController" bundle:nil];
    //NSLog(@"feedDetailViewController: %@", feedDetailViewController);
    //[feedDetailViewController setView:nil];
    feedDetailViewController.activeFeed = [[NSDictionary alloc] initWithDictionary:activeFeed];
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"Feeds" style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationController.navigationItem.backBarButtonItem = backButton;
    [backButton release];
    [navController popViewControllerAnimated:NO];
    [navController pushViewController:feedDetailViewController animated:YES];
    [feedDetailViewController release];
    NSLog(@"Released feedDetailViewController");
}



@end
