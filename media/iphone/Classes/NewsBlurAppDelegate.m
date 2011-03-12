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
#import "OriginalStoryViewController.h"

@implementation NewsBlurAppDelegate

@synthesize window;
@synthesize navigationController;
@synthesize feedsViewController;
@synthesize feedDetailViewController;
@synthesize storyDetailViewController;
@synthesize loginViewController;
@synthesize originalStoryViewController;

@synthesize logoutDelegate;
@synthesize activeUsername;
@synthesize activeFeed;
@synthesize activeFeedStories;
@synthesize activeStory;
@synthesize activeOriginalStoryURL;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    navigationController.viewControllers = [NSArray arrayWithObject:feedsViewController];
    
    [window addSubview:navigationController.view];
    [window makeKeyAndVisible];
    
    [feedsViewController fetchFeedList];
    
	return YES;
}

- (void)dealloc {
    [feedsViewController release];
    [feedDetailViewController release];
    [storyDetailViewController release];
    [loginViewController release];
    [originalStoryViewController release];
    [navigationController release];
    [window release];
    [activeUsername release];
    [activeFeed release];
    [activeFeedStories release];
    [activeStory release];
    [activeOriginalStoryURL release];
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

- (void)showLogin {
    UINavigationController *navController = self.navigationController;
    [navController presentModalViewController:loginViewController animated:YES];
}

- (void)reloadFeedsView {
    NSLog(@"Reloading feeds list");
    [self setTitle:@"NewsBlur"];
    [feedsViewController fetchFeedList];
    [loginViewController dismissModalViewControllerAnimated:YES];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.6];
}
   
- (void)loadFeedDetailView {
    UINavigationController *navController = self.navigationController;
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"All" style:UIBarButtonItemStylePlain target:nil action:nil];
    navController.navigationItem.backBarButtonItem = backButton;
    [backButton release];
    [navController pushViewController:feedDetailViewController animated:YES];
    [feedDetailViewController fetchFeedDetail];
    [self showNavigationBar:YES];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.8];
}

- (void)loadStoryDetailView {
    UINavigationController *navController = self.navigationController;   
    [navController pushViewController:storyDetailViewController animated:YES];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
}

- (void)setTitle:(NSString *)title {
    UILabel *label = [[UILabel alloc] init];
    [label setFont:[UIFont boldSystemFontOfSize:16.0]];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setTextColor:[UIColor whiteColor]];
    [label setText:title];
    [label sizeToFit];
    [navigationController.navigationBar.topItem setTitleView:label];
    [label release];
}

- (void)showOriginalStory:(NSURL *)url {
    self.activeOriginalStoryURL = url;
    UINavigationController *navController = self.navigationController;
    [navController presentModalViewController:originalStoryViewController animated:YES];
}

- (void)closeOriginalStory {
    [originalStoryViewController dismissModalViewControllerAnimated:YES];
}

+ (int)computeStoryScore:(NSDictionary *)intelligence {
    int score = 0;
//    int score_max = 0;
//    [intelligence objectForKey:@"title"]
//    var score_max = Math.max(story.intelligence['title'],
//                             story.intelligence['author'],
//                             story.intelligence['tags']);
//    var score_min = Math.min(story.intelligence['title'],
//                             story.intelligence['author'],
//                             story.intelligence['tags']);
//    if (score_max > 0) score = score_max;
//    else if (score_min < 0) score = score_min;
//    
//    if (score == 0) score = story.intelligence['feed'];
    
    return score;
}

@end
