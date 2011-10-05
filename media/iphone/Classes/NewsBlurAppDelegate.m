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
#import "AddViewController.h"
#import "OriginalStoryViewController.h"

@implementation NewsBlurAppDelegate

@synthesize window;
@synthesize navigationController;
@synthesize feedsViewController;
@synthesize feedDetailViewController;
@synthesize storyDetailViewController;
@synthesize loginViewController;
@synthesize addViewController;
@synthesize originalStoryViewController;

@synthesize activeUsername;
@synthesize activeFeed;
@synthesize activeFeedStories;
@synthesize activeFeedStoryLocations;
@synthesize activeFeedStoryLocationIds;
@synthesize activeStory;
@synthesize storyCount;
@synthesize originalStoryCount;
@synthesize selectedIntelligence;
@synthesize activeOriginalStoryURL;
@synthesize recentlyReadStories;
@synthesize activeFeedIndexPath;
@synthesize readStories;

@synthesize dictFolders;
@synthesize dictFeeds;
@synthesize dictFoldersArray;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
//    [TestFlight takeOff:@"101dd20fb90f7355703b131d9af42633_MjQ0NTgyMDExLTA4LTIxIDIzOjU3OjEzLjM5MDcyOA"];
    [ASIHTTPRequest setDefaultUserAgentString:@"NewsBlur iPhone App v1.0"];
    
    navigationController.viewControllers = [NSArray arrayWithObject:feedsViewController];
    [window addSubview:navigationController.view];
    [window makeKeyAndVisible];
    
    [feedsViewController fetchFeedList:YES];
    
	return YES;
}

- (void)viewDidLoad {
    self.selectedIntelligence = 1;
    [self setRecentlyReadStories:[NSMutableArray array]];
}

- (void)dealloc {
    NSLog(@"Dealloc on AppDelegate");
    [feedsViewController release];
    [feedDetailViewController release];
    [storyDetailViewController release];
    [loginViewController release];
    [addViewController release];
    [originalStoryViewController release];
    [navigationController release];
    [window release];
    [activeUsername release];
    [activeFeed release];
    [activeFeedStories release];
    [activeFeedStoryLocations release];
    [activeFeedStoryLocationIds release];
    [activeStory release];
    [activeOriginalStoryURL release];
    [recentlyReadStories release];
    [activeFeedIndexPath release];
    [readStories release];
    
    [dictFolders release];
    [dictFeeds release];
    [dictFoldersArray release];
    
    [super dealloc];
}

- (void)hideNavigationBar:(BOOL)animated {
    [[self navigationController] setNavigationBarHidden:YES animated:animated];
}

- (void)showNavigationBar:(BOOL)animated {
    [[self navigationController] setNavigationBarHidden:NO animated:animated];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
}

#pragma mark -
#pragma mark Views

- (void)showLogin {
    UINavigationController *navController = self.navigationController;
    [navController presentModalViewController:loginViewController animated:YES];
}

- (void)showAdd {
    UINavigationController *navController = self.navigationController;
    [navController presentModalViewController:addViewController animated:YES];
}

- (void)reloadFeedsView {
    [self setTitle:@"NewsBlur"];
    [feedsViewController fetchFeedList:YES];
    [loginViewController dismissModalViewControllerAnimated:YES];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
}
   
- (void)loadFeedDetailView {
    UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle: @"All" style: UIBarButtonItemStyleBordered target: nil action: nil];
    [feedsViewController.navigationItem setBackBarButtonItem: newBackButton];
    [newBackButton release];
    UINavigationController *navController = self.navigationController;
    [self setStories:nil];
    [navController pushViewController:feedDetailViewController animated:YES];
    [feedDetailViewController resetFeedDetail];
    [feedDetailViewController fetchFeedDetail:1 withCallback:nil];
    [self showNavigationBar:YES];
    navController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
//    navController.navigationBar.tintColor = UIColorFromRGB(0x59f6c1);
}

- (void)loadStoryDetailView {
    UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle:[activeFeed objectForKey:@"feed_title"] style: UIBarButtonItemStyleBordered target: nil action: nil];
    [feedDetailViewController.navigationItem setBackBarButtonItem: newBackButton];
    [newBackButton release];
    UINavigationController *navController = self.navigationController;   
    [navController pushViewController:storyDetailViewController animated:YES];
    [navController.navigationItem setLeftBarButtonItem:[[[UIBarButtonItem alloc] initWithTitle:[self.activeFeed objectForKey:@"feed_title"] style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease]];
    navController.navigationItem.hidesBackButton = YES;
    navController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
}

- (void)navigationController:(UINavigationController *)navController 
      willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    NSLog(@"willShow %@", viewController);
    if (viewController == feedDetailViewController) {
        UIView *backButtonView = [[UIView alloc] initWithFrame:CGRectMake(0,0,70,35)];
        UIButton *myBackButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        [myBackButton setFrame:CGRectMake(0,0,70,35)];
        [myBackButton setImage:[UIImage imageNamed:@"toolbar_back_button.png"] forState:UIControlStateNormal];
        [myBackButton setEnabled:YES];
        [myBackButton addTarget:viewController.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
        [backButtonView addSubview:myBackButton];
        [myBackButton release];
        UIBarButtonItem* backButton = [[UIBarButtonItem alloc] initWithCustomView:backButtonView];
        viewController.navigationItem.leftBarButtonItem = backButton;
        navController.navigationItem.leftBarButtonItem = backButton;
        viewController.navigationItem.hidesBackButton = YES;
        navController.navigationItem.hidesBackButton = YES;
        
        [backButtonView release];
        [backButton release];
    }
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

- (int)indexOfNextStory {
    int activeLocation = [self locationOfActiveStory];
//    int activeIndex = [[activeFeedStoryLocations objectAtIndex:activeLocation] intValue];
    int readStatus = -1;
//    NSLog(@"ActiveStory: %d (%d)/%d", activeLocation, activeIndex, self.storyCount);
    for (int i=activeLocation+1; i < [self.activeFeedStoryLocations count]; i++) {
        int location = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
        NSDictionary *story = [activeFeedStories objectAtIndex:location];
        readStatus = [[story objectForKey:@"read_status"] intValue];
//        NSLog(@"+1 readStatus at %d (%d): %d", location, i, readStatus);
        if (readStatus == 0) {
//            NSLog(@"NextStory after: %d", i);
            return location;
        }
    }
    if (activeLocation > 0) {
        for (int i=activeLocation-1; i >= 0; i--) {
            int location = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
            NSDictionary *story = [activeFeedStories objectAtIndex:location];
            readStatus = [[story objectForKey:@"read_status"] intValue];
//            NSLog(@"-1 readStatus at %d (%d): %d", location, i, readStatus);
            if (readStatus == 0) {
//                NSLog(@"NextStory before: %d", i);
                return location;
            }
        }
    }
    return -1;
}

- (int)indexOfPreviousStory {
    NSInteger activeIndex = [self indexOfActiveStory];
    return MAX(-1, activeIndex-1);
}

- (int)indexOfActiveStory {
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [activeFeedStories objectAtIndex:i];
        if ([activeStory objectForKey:@"id"] == [story objectForKey:@"id"]) {
            return i;
        }
    }
    return -1;
}

- (int)locationOfActiveStory {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([activeFeedStoryLocationIds objectAtIndex:i] == 
            [self.activeStory objectForKey:@"id"]) {
            return i;
        }
    }
    return -1;
}

- (void)pushReadStory:(id)storyId {
    if ([self.readStories lastObject] != storyId) {
        [self.readStories addObject:storyId];
    }
}

- (id)popReadStory {
    if (storyCount == 0) {
        return nil;
    } else {
        [self.readStories removeLastObject];
        id lastStory = [self.readStories lastObject];
        return lastStory;
    }
}

- (int)locationOfStoryId:(id)storyId {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([activeFeedStoryLocationIds objectAtIndex:i] == storyId) {
            return [[activeFeedStoryLocations objectAtIndex:i] intValue];
        }
    }
    return -1;
}

- (int)unreadCount {
    int total = 0;
    total += [[self.activeFeed objectForKey:@"ps"] intValue];
    if ([self selectedIntelligence] <= 0) {
        total += [[self.activeFeed objectForKey:@"nt"] intValue];
    }
    if ([self selectedIntelligence] <= -1) {
        total += [[self.activeFeed objectForKey:@"ng"] intValue];
    }
    return total;
}

- (int)visibleUnreadCount {
    return 0;
}

- (void)addStories:(NSArray *)stories {
    self.activeFeedStories = [self.activeFeedStories arrayByAddingObjectsFromArray:stories];
    self.storyCount = [self.activeFeedStories count];
    [self calculateStoryLocations];
}

- (void)setStories:(NSArray *)activeFeedStoriesValue {
    self.activeFeedStories = activeFeedStoriesValue;
    self.storyCount = [self.activeFeedStories count];
    [self setRecentlyReadStories:[NSMutableArray array]];
    [self calculateStoryLocations];
}

- (void)markActiveStoryRead {
    int activeLocation = [self locationOfActiveStory];
    if (activeLocation == -1) {
        return;
    }
    int activeIndex = [[activeFeedStoryLocations objectAtIndex:activeLocation] intValue];
    
    NSDictionary *story = [activeFeedStories objectAtIndex:activeIndex];
    [story setValue:[NSNumber numberWithInt:1] forKey:@"read_status"];
    [self.recentlyReadStories addObject:[NSNumber numberWithInt:activeLocation]];
    int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    if (score > 0) {
        int unreads = MAX(0, [[activeFeed objectForKey:@"ps"] intValue] - 1);
        [self.activeFeed setValue:[NSNumber numberWithInt:unreads] forKey:@"ps"];
    } else if (score == 0) {
        int unreads = MAX(0, [[activeFeed objectForKey:@"nt"] intValue] - 1);
        [self.activeFeed setValue:[NSNumber numberWithInt:unreads] forKey:@"nt"];
    } else if (score < 0) {
        int unreads = MAX(0, [[activeFeed objectForKey:@"ng"] intValue] - 1);
        [self.activeFeed setValue:[NSNumber numberWithInt:unreads] forKey:@"ng"];
    }
//    NSLog(@"Marked read %d-%d: %@: %d", activeIndex, activeLocation, self.recentlyReadStories, score);
}

- (void)markActiveFeedAllRead {    
    [self.activeFeed setValue:[NSNumber numberWithInt:0] forKey:@"ps"];
    [self.activeFeed setValue:[NSNumber numberWithInt:0] forKey:@"nt"];
    [self.activeFeed setValue:[NSNumber numberWithInt:0] forKey:@"ng"];
}

- (void)calculateStoryLocations {
    self.activeFeedStoryLocations = [NSMutableArray array];
    self.activeFeedStoryLocationIds = [NSMutableArray array];
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [self.activeFeedStories objectAtIndex:i];
        int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
        if (score >= self.selectedIntelligence) {
            NSNumber *location = [NSNumber numberWithInt:i];
            [self.activeFeedStoryLocations addObject:location];
            [self.activeFeedStoryLocationIds addObject:[story objectForKey:@"id"]];
        }
    }
}

+ (int)computeStoryScore:(NSDictionary *)intelligence {
    int score = 0;
    int title = [[intelligence objectForKey:@"title"] intValue];
    int author = [[intelligence objectForKey:@"author"] intValue];
    int tags = [[intelligence objectForKey:@"tags"] intValue];

    int score_max = MAX(title, MAX(author, tags));
    int score_min = MIN(title, MIN(author, tags));

    if (score_max > 0)      score = score_max;
    else if (score_min < 0) score = score_min;
    
    if (score == 0) score = [[intelligence objectForKey:@"feed"] integerValue];

//    NSLog(@"%d/%d -- %d: %@", score_max, score_min, score, intelligence);
    return score;
}

+ (void)informError:(NSError *)error {
    NSString* localizedDescription = [error localizedDescription];
    UIAlertView* alertView = [[UIAlertView alloc]
                              initWithTitle:@"Error"
                              message:localizedDescription delegate:nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];
}

@end
