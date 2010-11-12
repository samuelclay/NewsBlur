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
#import "StoryDetailViewController.h"
#import "LoginViewController.h"

@implementation NewsBlurAppDelegate

@synthesize window;
@synthesize navigationController;
@synthesize feedsViewController;
@synthesize feedDetailViewController;
@synthesize storyDetailViewController;
@synthesize loginViewController;

@synthesize activeFeed;
@synthesize activeFeedStories;
@synthesize activeStory;
@synthesize isLoggedIn;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    UINavigationController *navController = self.navigationController;
    NSLog(@"storyDetailViewController: %@", storyDetailViewController);
    navigationController.viewControllers = [NSArray arrayWithObject:feedsViewController];
    
    [window addSubview:navigationController.view];
    [window makeKeyAndVisible];
    NSLog(@"loginViewController: %@", loginViewController);
    [navController presentModalViewController:loginViewController animated:YES];
    
	return YES;
}

- (void)dealloc {
    [feedsViewController release];
    [feedDetailViewController release];
    [storyDetailViewController release];
    [loginViewController release];
    [navigationController release];
    [window release];
    [activeFeed release];
    [activeFeedStories release];
    [activeStory release];
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

- (void)reloadFeedsView {
    NSLog(@"Reloading feeds list");
    [loginViewController dismissModalViewControllerAnimated:YES];
    [feedsViewController fetchFeedList];
}
   
- (void)loadFeedDetailView {
    UINavigationController *navController = self.navigationController;
    
    [navController pushViewController:feedDetailViewController animated:YES];
    NSLog(@"Released feedDetailViewController");
}

- (void)loadStoryDetailView {
    UINavigationController *navController = self.navigationController;   
    [navController pushViewController:storyDetailViewController animated:YES];
}



@end
