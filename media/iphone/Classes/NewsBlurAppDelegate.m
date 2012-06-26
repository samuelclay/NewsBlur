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
#import "FeedDashboardViewController.h"
#import "FeedsMenuViewController.h"
#import "StoryDetailViewController.h"
#import "FirstTimeUserViewController.h"
#import "GoogleReaderViewController.h"
#import "LoginViewController.h"
#import "AddSiteViewController.h"
#import "MoveSiteViewController.h"
#import "OriginalStoryViewController.h"
#import "SplitStoryDetailViewController.h"
#import "ShareViewController.h"
#import "MBProgressHUD.h"
#import "Utilities.h"
#import "StringHelper.h"

@implementation NewsBlurAppDelegate

@synthesize window;

@synthesize splitStoryController;
@synthesize navigationController;
@synthesize splitStoryDetailNavigationController;
@synthesize googleReaderViewController;
@synthesize feedsViewController;
@synthesize feedsMenuViewController;
@synthesize feedDetailViewController;
@synthesize feedDashboardViewController;
@synthesize firstTimeUserViewController;
@synthesize fontSettingsViewController;
@synthesize storyDetailViewController;
@synthesize shareViewController;
@synthesize loginViewController;
@synthesize addSiteViewController;
@synthesize moveSiteViewController;
@synthesize originalStoryViewController;
@synthesize splitStoryDetailViewController;

@synthesize feedDetailPortraitYCoordinate;
@synthesize activeUsername;
@synthesize isRiverView;
@synthesize popoverHasFeedView;
@synthesize activeComment;
@synthesize activeFeed;
@synthesize activeFolder;
@synthesize activeFolderFeeds;
@synthesize activeFeedStories;
@synthesize activeFeedStoryLocations;
@synthesize activeFeedStoryLocationIds;
@synthesize activeFeedUserProfiles;
@synthesize activeStory;
@synthesize storyCount;
@synthesize visibleUnreadCount;
@synthesize originalStoryCount;
@synthesize selectedIntelligence;
@synthesize activeOriginalStoryURL;
@synthesize recentlyReadStories;
@synthesize recentlyReadFeeds;
@synthesize readStories;

@synthesize dictFolders;
@synthesize dictFeeds;
@synthesize dictSocialFeeds;
@synthesize dictFoldersArray;
@synthesize socialFeedsArray;

+ (NewsBlurAppDelegate*) sharedAppDelegate {
	return (NewsBlurAppDelegate*) [UIApplication sharedApplication].delegate;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
//    [TestFlight takeOff:@"101dd20fb90f7355703b131d9af42633_MjQ0NTgyMDExLTA4LTIxIDIzOjU3OjEzLjM5MDcyOA"];
    [ASIHTTPRequest setDefaultUserAgentString:@"NewsBlur iPhone App v1.0"];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        navigationController.viewControllers = [NSArray arrayWithObject:feedsViewController];
        
        splitStoryDetailNavigationController.viewControllers = [NSArray arrayWithObject:splitStoryDetailViewController];
        splitStoryDetailNavigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
        splitStoryDetailViewController.navigationItem.title = @"NewsBlur";
        
        splitStoryController.viewControllers = [NSArray arrayWithObjects:navigationController, splitStoryDetailNavigationController, nil];
        
        [window addSubview:splitStoryController.view];
        
        self.window.rootViewController = self.splitStoryController;

        
    } else {
        navigationController.viewControllers = [NSArray arrayWithObject:feedsViewController];
        [window addSubview:navigationController.view];
    }
    
    // set default x coordinate for feedDetailY from saved preferences
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSInteger savedFeedDetailPortraitYCoordinate = [userPreferences integerForKey:@"feedDetailPortraitYCoordinate"];
    if (savedFeedDetailPortraitYCoordinate) {
        self.feedDetailPortraitYCoordinate = savedFeedDetailPortraitYCoordinate;
    } else {
        self.feedDetailPortraitYCoordinate = 960;
    }
    
    [window makeKeyAndVisible];
    [feedsViewController fetchFeedList:YES];
    //[self showFirstTimeUser];
	return YES;
}

- (void)viewDidLoad {
    self.selectedIntelligence = 1;
    self.visibleUnreadCount = 0;
    [self setRecentlyReadStories:[NSMutableArray array]];
}

- (void)dealloc {
    NSLog(@"Dealloc on AppDelegate");
    [feedsViewController release];
    [feedsMenuViewController release];
    [feedDetailViewController release];
    [storyDetailViewController release];
    [loginViewController release];
    [addSiteViewController release];
    [moveSiteViewController release];
    [originalStoryViewController release];
    [splitStoryDetailViewController release];
    [navigationController release];
    [firstTimeUserViewController release];
    [window release];
    [activeUsername release];
    [activeFeed release];
    [activeFolder release];
    [activeFeedStories release];
    [activeFeedStoryLocations release];
    [activeFeedStoryLocationIds release];
    [activeStory release];
    [activeOriginalStoryURL release];
    [recentlyReadStories release];
    [recentlyReadFeeds release];
    [readStories release];
    
    [dictFolders release];
    [dictFeeds release];
    [dictSocialFeeds release];
    [dictFoldersArray release];
    [socialFeedsArray release];
    
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
#pragma mark FeedsView

- (void)showFeedsMenu {
    UINavigationController *navController = self.navigationController;
    [navController presentModalViewController:feedsMenuViewController animated:YES];
}

- (void)hideFeedsMenu {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [feedsViewController dismissFeedsMenu];
    } else {
        UINavigationController *navController = self.navigationController;
        [navController dismissModalViewControllerAnimated:YES];
    }
}

- (void)showAdd {
    UINavigationController *navController = self.navigationController;
    [navController dismissModalViewControllerAnimated:NO];
    [addSiteViewController initWithNibName:nil bundle:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        addSiteViewController.modalPresentationStyle=UIModalPresentationFormSheet;
        [navController presentModalViewController:addSiteViewController animated:YES];
        //it's important to do this after presentModalViewController
        addSiteViewController.view.superview.frame = CGRectMake(0, 0, 320, 440); 
        addSiteViewController.view.superview.center = self.view.center;
    } else {
        [navController presentModalViewController:addSiteViewController animated:YES];
    }
    
    [addSiteViewController reload];
}

#pragma mark -
#pragma mark Views

- (void)showLogin {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.splitStoryDetailViewController.masterPopoverController dismissPopoverAnimated:YES];
        [self.splitStoryController presentModalViewController:loginViewController animated:YES];
    } else {
        [feedsMenuViewController dismissModalViewControllerAnimated:NO];
        [self.navigationController presentModalViewController:loginViewController animated:YES];
    }
        
}

- (void)showFirstTimeUser {
    [loginViewController dismissModalViewControllerAnimated:NO];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.splitStoryDetailViewController.masterPopoverController dismissPopoverAnimated:YES];
        [self.splitStoryController presentModalViewController:firstTimeUserViewController animated:YES];
    } else {
        [self.navigationController presentModalViewController:loginViewController animated:YES];
    }
}

- (void)showGoogleReaderAuthentication {
    googleReaderViewController.modalPresentationStyle = UIModalPresentationFormSheet;
    [firstTimeUserViewController presentModalViewController:googleReaderViewController animated:YES];
}

- (void)addedGoogleReader {
    [firstTimeUserViewController selectGoogleReaderButton];
}

- (void)showMasterPopover {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [splitStoryDetailViewController showPopover];
        NSArray *subviews = [[splitStoryDetailViewController.view subviews] copy];
        for (UIView *subview in subviews) {
            if (subview.tag == FEED_DETAIL_VIEW_TAG) {
                [subview removeFromSuperview];
            }
        }
        [subviews release];
    }
}

- (void)showMoveSite {
    UINavigationController *navController = self.navigationController;
    [moveSiteViewController initWithNibName:nil bundle:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        moveSiteViewController.modalPresentationStyle=UIModalPresentationFormSheet;
        [navController presentModalViewController:moveSiteViewController animated:YES];
        //it's important to do this after presentModalViewController
        moveSiteViewController.view.superview.frame = CGRectMake(0, 0, 320, 440); 
        moveSiteViewController.view.superview.center = self.view.center;
    } else {
        [navController presentModalViewController:moveSiteViewController animated:YES];
    }
}

- (void)reloadFeedsView:(BOOL)showLoader {
    [feedsViewController fetchFeedList:showLoader];
    [loginViewController dismissModalViewControllerAnimated:YES];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
}

- (void)loadFeedDetailView {
    [self setStories:nil];
    [self setFeedUserProfiles:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && 
        UIInterfaceOrientationIsPortrait(splitStoryDetailViewController.interfaceOrientation) &&
        self.feedDetailPortraitYCoordinate != 960) {

        // remove existing feedDetailViewController
        [self hideStoryDetailView];
        
        feedDetailViewController.view.tag = FEED_DETAIL_VIEW_TAG;
        [splitStoryDetailViewController.view addSubview:feedDetailViewController.view];
        
        feedDashboardViewController.view.tag = FEED_DASHBOARD_VIEW_TAG;
        [splitStoryDetailViewController.view addSubview:feedDashboardViewController.view];
        
        [self adjustStoryDetailWebView:YES shouldCheckLayout:YES];
        [self.splitStoryDetailViewController.masterPopoverController dismissPopoverAnimated:YES];
    } else {
        UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle: @"All" 
                                                                          style: UIBarButtonItemStyleBordered 
                                                                         target: nil 
                                                                         action: nil];
        [feedsViewController.navigationItem setBackBarButtonItem: newBackButton];
        [newBackButton release];
        UINavigationController *navController = self.navigationController;        
        [navController pushViewController:feedDetailViewController animated:YES];
        [self showNavigationBar:YES];
        navController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
        //    navController.navigationBar.tintColor = UIColorFromRGB(0x59f6c1);
        
        popoverHasFeedView = YES;
    }
    
    [feedDetailViewController resetFeedDetail];
    [feedDetailViewController fetchFeedDetail:1 withCallback:nil];
}

- (void)hideStoryDetailView {
    NSArray *subviews = [[splitStoryDetailViewController.view subviews] copy];
    for (UIView *subview in subviews) {
        if (subview.tag == FEED_DETAIL_VIEW_TAG ||
            subview.tag == STORY_DETAIL_VIEW_TAG || 
            subview.tag == FEED_DASHBOARD_VIEW_TAG) {
            [subview removeFromSuperview];
        }
    }
    [subviews release];
}

- (void)showShareView:(NSString *)userId 
          setUsername:(NSString *)username {
    [splitStoryDetailViewController.view addSubview:shareViewController.view];
    
    [shareViewController setSiteInfo:userId setUsername:username];
    if (UIInterfaceOrientationIsPortrait(splitStoryDetailViewController.interfaceOrientation)) {
        
        shareViewController.view.frame = CGRectMake(0, 
                                                    960, 
                                                    768, 
                                                    0);

        
        [UIView animateWithDuration:0.35 animations:^{
            shareViewController.view.frame = CGRectMake(0, 
                                                        (960 - SHARE_MODAL_HEIGHT), 
                                                        768, 
                                                        SHARE_MODAL_HEIGHT + 44);

            
            NSLog(@"The value is %i", (960 - self.feedDetailPortraitYCoordinate) > SHARE_MODAL_HEIGHT);
            if ((960 - self.feedDetailPortraitYCoordinate) > SHARE_MODAL_HEIGHT) {
                feedDetailViewController.view.frame = CGRectMake(0,
                                                                 (960 - SHARE_MODAL_HEIGHT + 44), 
                                                                 768, 
                                                                 SHARE_MODAL_HEIGHT);
                storyDetailViewController.view.frame = CGRectMake(0,
                                                                  0,
                                                                  768,
                                                                  (960 - SHARE_MODAL_HEIGHT + 44));
            }


        }
         completion:^(BOOL finished) {
             if ((960 - self.feedDetailPortraitYCoordinate) < SHARE_MODAL_HEIGHT) {
                 storyDetailViewController.view.frame = CGRectMake(0,
                                                                   0,
                                                                   768,
                                                                   (960 - SHARE_MODAL_HEIGHT + 44));
             }
         }]; 
    }
}

- (void)hideShareView {    
    if (UIInterfaceOrientationIsPortrait(splitStoryDetailViewController.interfaceOrientation)) {
        if ((960 - self.feedDetailPortraitYCoordinate) < SHARE_MODAL_HEIGHT) {
            storyDetailViewController.view.frame = CGRectMake(0,
                                                              0,
                                                              768,
                                                              self.feedDetailPortraitYCoordinate);
        }
                
        [UIView animateWithDuration:0.35 animations:^{
            shareViewController.view.frame = CGRectMake(0, 
                                                        960, 
                                                        768, 
                                                        0);
            feedDetailViewController.view.frame = CGRectMake(0,
                                                             self.feedDetailPortraitYCoordinate,
                                                             768,
                                                             960 - self.feedDetailPortraitYCoordinate); 
            
            storyDetailViewController.view.frame = CGRectMake(0,
                                                              0,
                                                              768,
                                                              self.feedDetailPortraitYCoordinate);
            feedDetailViewController.view.frame = CGRectMake(0,
                                                             self.feedDetailPortraitYCoordinate,
                                                             768,
                                                             960 - self.feedDetailPortraitYCoordinate);
        }]; 
    }
    
}

- (void)refreshComments {
    [storyDetailViewController refreshComments];
}

- (void)loadRiverFeedDetailView {
    [self setStories:nil];
    [self setFeedUserProfiles:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && 
        UIInterfaceOrientationIsPortrait(splitStoryDetailViewController.interfaceOrientation) &&
        self.feedDetailPortraitYCoordinate != 960) {
        // remove existing feedDetailViewController
        [self hideStoryDetailView];
        feedDashboardViewController.view.tag = FEED_DASHBOARD_VIEW_TAG;
        [splitStoryDetailViewController.view addSubview:feedDashboardViewController.view];
        [self adjustStoryDetailWebView:YES shouldCheckLayout:YES];
        [self.splitStoryDetailViewController.masterPopoverController dismissPopoverAnimated:YES];
    } else {
        UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle: @"All" 
                                                                          style: UIBarButtonItemStyleBordered 
                                                                         target: nil 
                                                                         action: nil];
        [feedsViewController.navigationItem setBackBarButtonItem: newBackButton];
        [newBackButton release];
        UINavigationController *navController = self.navigationController;
        [navController pushViewController:feedDetailViewController animated:YES];
        [self showNavigationBar:YES];
        navController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    }
    
    [feedDetailViewController resetFeedDetail];
    [feedDetailViewController fetchRiverPage:1 withCallback:nil];
}

- (void)adjustStoryDetailWebView:(BOOL)init shouldCheckLayout:(BOOL)checkLayout {
    UINavigationController *navController = self.navigationController;

    if (UIInterfaceOrientationIsPortrait(splitStoryDetailViewController.interfaceOrientation)) {        
        if( (960 - self.feedDetailPortraitYCoordinate) < 44 ) {
            feedDetailViewController.view.frame = CGRectMake(0, 
                                                             self.feedDetailPortraitYCoordinate + (44 - (960 - self.feedDetailPortraitYCoordinate)), 
                                                             768, 
                                                             960 - self.feedDetailPortraitYCoordinate);                    
        } else {
            feedDetailViewController.view.frame = CGRectMake(0, 
                                                             self.feedDetailPortraitYCoordinate, 
                                                             768, 
                                                             960 - self.feedDetailPortraitYCoordinate);
        }
        
        // the storyDetailView is full screen
        if (self.feedDetailPortraitYCoordinate == 960) {
            storyDetailViewController.view.frame = CGRectMake(0, 0, 768, 960);
            feedDashboardViewController.view.frame = CGRectMake(0,
                                                                0,
                                                                storyDetailViewController.view.frame.size.width,
                                                                960);
            if (checkLayout) {
                // move the feedDetialViewController to the subview
                if (!popoverHasFeedView) {
                    [navController pushViewController:feedDetailViewController animated:NO];
                    popoverHasFeedView = YES;
                }
            }

        } else {
            if (init) {
                feedDashboardViewController.view.frame = CGRectMake(0,
                                                                    0,
                                                                    768,
                                                                    self.feedDetailPortraitYCoordinate);
            } else {
                storyDetailViewController.view.frame = CGRectMake(0,
                                                                  0,
                                                                  768,
                                                                  self.feedDetailPortraitYCoordinate);
                feedDashboardViewController.view.frame = CGRectMake(0,
                                                                    0, 
                                                                    768, 
                                                                    self.feedDetailPortraitYCoordinate);
            }
            
            if (checkLayout) {
                //remove the feedDetailView from the popover
                if (popoverHasFeedView) {
                    [navController popViewControllerAnimated:NO];
                    popoverHasFeedView = NO;
                }
            }

            [splitStoryDetailViewController.view addSubview:feedDetailViewController.view];
        }
    } else {
        if (init) {
            feedDashboardViewController.view.frame = CGRectMake(0,0,704,704);  
        } else {
            storyDetailViewController.view.frame = CGRectMake(0,0,704,704);
            NSArray *subviews = [[splitStoryDetailViewController.view subviews] copy];
            for (UIView *subview in subviews) {
                if (subview.tag == FEED_DASHBOARD_VIEW_TAG) {
                    [subview removeFromSuperview];
                }
            }
            [subviews release];
        }
                
        if (checkLayout) {
            if (!popoverHasFeedView) {
                [navController pushViewController:feedDetailViewController animated:NO];
                popoverHasFeedView = YES;
            }
        }

    }
}

- (void)dragFeedDetailView:(float)y {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if (UIInterfaceOrientationIsPortrait(splitStoryDetailViewController.interfaceOrientation)) {
        y = y + 20;
        
        if(y > 955) {
            self.feedDetailPortraitYCoordinate = 960;
        } else if(y < 950 && y > 200) {
            self.feedDetailPortraitYCoordinate = y;
        }
        
        [userPreferences setInteger:self.feedDetailPortraitYCoordinate forKey:@"feedDetailPortraitYCoordinate"];
        [userPreferences synchronize];
        [self adjustStoryDetailWebView:NO shouldCheckLayout:YES];        
    }
}

- (void)changeActiveFeedDetailRow {
    [feedDetailViewController changeActiveFeedDetailRow];
}

- (void)loadStoryDetailView {
    NSString *feedTitle;
    if (self.isRiverView) {
        feedTitle = self.activeFolder;
    } else {
        feedTitle = [activeFeed objectForKey:@"feed_title"];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        // With some valid UIView *view:
        NSArray *subviews = [[splitStoryDetailViewController.view subviews] copy];
        for (UIView *subview in subviews) {
            if (subview.tag == STORY_DETAIL_VIEW_TAG) {
                [subview removeFromSuperview];
            }
        }
        [subviews release];
        
        storyDetailViewController.view.tag = STORY_DETAIL_VIEW_TAG;
        [splitStoryDetailViewController.view addSubview:storyDetailViewController.view];
        [self adjustStoryDetailWebView:NO shouldCheckLayout:NO];        
    } else{
        UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle:feedTitle style: UIBarButtonItemStyleBordered target: nil action: nil];
        [feedDetailViewController.navigationItem setBackBarButtonItem: newBackButton];
        [newBackButton release];
        UINavigationController *navController = self.navigationController;   
        [navController pushViewController:storyDetailViewController animated:YES];
        [navController.navigationItem setLeftBarButtonItem:[[[UIBarButtonItem alloc] initWithTitle:feedTitle style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease]];
        navController.navigationItem.hidesBackButton = YES;
        navController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    }
}

- (void)navigationController:(UINavigationController *)navController 
      willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
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
    [MBProgressHUD hideHUDForView:originalStoryViewController.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:originalStoryViewController.view animated:YES];
    HUD.labelText = @"On its way...";
    self.activeOriginalStoryURL = url;
    UINavigationController *navController = self.navigationController;
    [navController presentModalViewController:originalStoryViewController animated:YES];
}

- (void)closeOriginalStory {
    [originalStoryViewController dismissModalViewControllerAnimated:YES];
}

- (int)indexOfNextStory {
    int activeLocation = [self locationOfActiveStory];
    int readStatus = -1;
    for (int i=activeLocation+1; i < [self.activeFeedStoryLocations count]; i++) {
        int location = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
        NSDictionary *story = [activeFeedStories objectAtIndex:location];
        readStatus = [[story objectForKey:@"read_status"] intValue];
        if (readStatus == 0) {
            return location;
        }
    }
    if (activeLocation > 0) {
        for (int i=activeLocation-1; i >= 0; i--) {
            int location = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
            NSDictionary *story = [activeFeedStories objectAtIndex:location];
            readStatus = [[story objectForKey:@"read_status"] intValue];
            if (readStatus == 0) {
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
    if (self.isRiverView) {
        return [self unreadCountForFolder:nil];
    } else { 
        return [self unreadCountForFeed:nil];
    }
}

- (int)unreadCountForFeed:(NSString *)feedId {
    int total = 0;
    NSDictionary *feed;

    if (feedId) {
        NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
        feed = [self.dictFeeds objectForKey:feedIdStr];
    } else {
        feed = self.activeFeed;
    }
    
    total += [[feed objectForKey:@"ps"] intValue];
    if ([self selectedIntelligence] <= 0) {
        total += [[feed objectForKey:@"nt"] intValue];
    }
    if ([self selectedIntelligence] <= -1) {
        total += [[feed objectForKey:@"ng"] intValue];
    }
    
    return total;
}

- (int)unreadCountForFolder:(NSString *)folderName {
    int total = 0;
    NSArray *folder;
    
    if (!folderName && self.activeFolder == @"Everything") {
        for (id feedId in self.dictFeeds) {
            total += [self unreadCountForFeed:feedId];
        }
    } else {
        if (!folderName) {
            folder = [self.dictFolders objectForKey:self.activeFolder];
        } else {
            folder = [self.dictFolders objectForKey:folderName];
        }
    
        for (id feedId in folder) {
            total += [self unreadCountForFeed:feedId];
        }
    }
    
    return total;
}

- (void)addStories:(NSArray *)stories {
    self.activeFeedStories = [self.activeFeedStories arrayByAddingObjectsFromArray:stories];
    self.storyCount = [self.activeFeedStories count];
    [self calculateStoryLocations];
}

- (void)setStories:(NSArray *)activeFeedStoriesValue {
    self.activeFeedStories = activeFeedStoriesValue;
    self.storyCount = [self.activeFeedStories count];
    self.recentlyReadStories = [NSMutableArray array];
    self.recentlyReadFeeds = [NSMutableSet set];
    [self calculateStoryLocations];
}

- (void)setFeedUserProfiles:(NSArray *)activeFeedUserProfilesValue{
    self.activeFeedUserProfiles = activeFeedUserProfilesValue;
}

- (void)addFeedUserProfiles:(NSArray *)activeFeedUserProfilesValue {
    self.activeFeedUserProfiles = [self.activeFeedUserProfiles arrayByAddingObjectsFromArray:activeFeedUserProfilesValue];
}

- (void)markActiveStoryRead {
    int activeLocation = [self locationOfActiveStory];
    if (activeLocation == -1) {
        return;
    }
    id feedId = [self.activeStory objectForKey:@"story_feed_id"];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    int activeIndex = [[activeFeedStoryLocations objectAtIndex:activeLocation] intValue];
    NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
    NSDictionary *story = [activeFeedStories objectAtIndex:activeIndex];
    if (self.activeFeed != feed) {
        self.activeFeed = feed;
    }
    
    [self.recentlyReadStories addObject:[NSNumber numberWithInt:activeLocation]];
    [self markStoryRead:story feed:feed];
}

- (NSDictionary *)markVisibleStoriesRead {
    NSMutableDictionary *feedsStories = [NSMutableDictionary dictionary];
    for (NSDictionary *story in self.activeFeedStories) {
        if ([[story objectForKey:@"read_status"] intValue] != 0) {
            continue;
        }
        NSString *feedIdStr = [NSString stringWithFormat:@"%@",[story objectForKey:@"story_feed_id"]];
        NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
        if (![feedsStories objectForKey:feedIdStr]) {
            [feedsStories setObject:[NSMutableArray array] forKey:feedIdStr];
        }
        NSMutableArray *stories = [feedsStories objectForKey:feedIdStr];
        [stories addObject:[story objectForKey:@"id"]];
        [self markStoryRead:story feed:feed];
    }   
    NSLog(@"feedsStories: %@", feedsStories);
    return feedsStories;
}

- (void)markStoryRead:(NSString *)storyId feedId:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
    NSDictionary *story = nil;
    for (NSDictionary *s in self.activeFeedStories) {
        if ([[s objectForKey:@"story_guid"] isEqualToString:storyId]) {
            story = s;
            break;
        }
    }
    [self markStoryRead:story feed:feed];
}

- (void)markStoryRead:(NSDictionary *)story feed:(NSDictionary *)feed {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
    [story setValue:[NSNumber numberWithInt:1] forKey:@"read_status"];
    self.visibleUnreadCount -= 1;
    if (![self.recentlyReadFeeds containsObject:[story objectForKey:@"story_feed_id"]]) {
        [self.recentlyReadFeeds addObject:[story objectForKey:@"story_feed_id"]];
    }
    int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    if (score > 0) {
        int unreads = MAX(0, [[feed objectForKey:@"ps"] intValue] - 1);
        [feed setValue:[NSNumber numberWithInt:unreads] forKey:@"ps"];
    } else if (score == 0) {
        int unreads = MAX(0, [[feed objectForKey:@"nt"] intValue] - 1);
        [feed setValue:[NSNumber numberWithInt:unreads] forKey:@"nt"];
    } else if (score < 0) {
        int unreads = MAX(0, [[feed objectForKey:@"ng"] intValue] - 1);
        [feed setValue:[NSNumber numberWithInt:unreads] forKey:@"ng"];
    }
    [self.dictFeeds setValue:feed forKey:feedIdStr];

}

- (void)markActiveFeedAllRead {    
    id feedId = [self.activeFeed objectForKey:@"id"];
    [self markFeedAllRead:feedId];
}

- (void)markActiveFolderAllRead {
    if (self.activeFolder == @"Everything") {
        for (NSString *folderName in self.dictFoldersArray) {
            for (id feedId in [self.dictFolders objectForKey:folderName]) {
                [self markFeedAllRead:feedId];
            }        
        }
    } else {
        for (id feedId in [self.dictFolders objectForKey:self.activeFolder]) {
            [self markFeedAllRead:feedId];
        }
    }
}

- (void)markFeedAllRead:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
    
    [feed setValue:[NSNumber numberWithInt:0] forKey:@"ps"];
    [feed setValue:[NSNumber numberWithInt:0] forKey:@"nt"];
    [feed setValue:[NSNumber numberWithInt:0] forKey:@"ng"];
    [self.dictFeeds setValue:feed forKey:feedIdStr];    
}

- (void)calculateStoryLocations {
    self.visibleUnreadCount = 0;
    self.activeFeedStoryLocations = [NSMutableArray array];
    self.activeFeedStoryLocationIds = [NSMutableArray array];
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [self.activeFeedStories objectAtIndex:i];
        int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
        if (score >= self.selectedIntelligence) {
            NSNumber *location = [NSNumber numberWithInt:i];
            [self.activeFeedStoryLocations addObject:location];
            [self.activeFeedStoryLocationIds addObject:[story objectForKey:@"id"]];
            if ([[story objectForKey:@"read_status"] intValue] == 0) {
                self.visibleUnreadCount += 1;
            }
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



- (NSString *)extractParentFolderName:(NSString *)folderName {
    if ([folderName containsString:@"Top Level"]) {
        folderName = @"";
    }
    
    if ([folderName containsString:@" - "]) {
        int lastFolderLoc = [folderName rangeOfString:@" - " options:NSBackwardsSearch].location;
        folderName = [folderName substringToIndex:lastFolderLoc];
    } else {
        folderName = @"— Top Level —";
    }
    
    return folderName;
}

- (NSString *)extractFolderName:(NSString *)folderName {
    if ([folderName containsString:@"Top Level"]) {
        folderName = @"";
    }
    
    if ([folderName containsString:@" - "]) {
        int folder_loc = [folderName rangeOfString:@" - " options:NSBackwardsSearch].location;
        folderName = [folderName substringFromIndex:(folder_loc + 3)];
    }
    
    return folderName;
}

#pragma mark -
#pragma mark Feed Templates

+ (UIView *)makeGradientView:(CGRect)rect startColor:(NSString *)start endColor:(NSString *)end {
    UIView *gradientView = [[[UIView alloc] initWithFrame:rect] autorelease];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0, 1, rect.size.width, rect.size.height-1);
    gradient.opacity = 0.7;
    unsigned int color = 0;
    unsigned int colorFade = 0;
    if ([start class] == [NSNull class]) {
        start = @"505050";
    }
    if ([end class] == [NSNull class]) {
        end = @"303030";
    }
    NSScanner *scanner = [NSScanner scannerWithString:start];
    [scanner scanHexInt:&color];
    NSScanner *scannerFade = [NSScanner scannerWithString:end];
    [scannerFade scanHexInt:&colorFade];
    gradient.colors = [NSArray arrayWithObjects:(id)[UIColorFromRGB(color) CGColor], (id)[UIColorFromRGB(colorFade) CGColor], nil];
    
    CALayer *whiteBackground = [CALayer layer];
    whiteBackground.frame = CGRectMake(0, 1, rect.size.width, rect.size.height-1);
    whiteBackground.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7].CGColor;
    [gradientView.layer addSublayer:whiteBackground];
    
    [gradientView.layer addSublayer:gradient];
    
    CALayer *topBorder = [CALayer layer];
    topBorder.frame = CGRectMake(0, 1, rect.size.width, 1);
    topBorder.backgroundColor = [UIColorFromRGB(colorFade) colorWithAlphaComponent:0.7].CGColor;
    topBorder.opacity = 1;
    [gradientView.layer addSublayer:topBorder];
    
    CALayer *bottomBorder = [CALayer layer];
    bottomBorder.frame = CGRectMake(0, rect.size.height-1, rect.size.width, 1);
    bottomBorder.backgroundColor = [UIColorFromRGB(colorFade) colorWithAlphaComponent:0.7].CGColor;
    bottomBorder.opacity = 1;
    [gradientView.layer addSublayer:bottomBorder];
    
    return gradientView;
}

- (UIView *)makeFeedTitleGradient:(NSDictionary *)feed withRect:(CGRect)rect {
    UIView *gradientView;
    if (self.isRiverView) {
        gradientView = [NewsBlurAppDelegate 
                        makeGradientView:rect
                        startColor:[feed objectForKey:@"favicon_color"] 
                        endColor:[feed objectForKey:@"favicon_fade"]];
        
        UILabel *titleLabel = [[[UILabel alloc] init] autorelease];
        titleLabel.text = [feed objectForKey:@"feed_title"];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textAlignment = UITextAlignmentLeft;
        titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
        titleLabel.numberOfLines = 1;
        titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:11.0];
        titleLabel.shadowOffset = CGSizeMake(0, 1);
        if ([[feed objectForKey:@"favicon_text_color"] class] != [NSNull class]) {
            titleLabel.textColor = [[feed objectForKey:@"favicon_text_color"] 
                                    isEqualToString:@"white"] ?
                [UIColor whiteColor] :
                [UIColor blackColor];            
            titleLabel.shadowColor = [[feed objectForKey:@"favicon_text_color"] 
                                      isEqualToString:@"white"] ?
                UIColorFromRGB(0x202020) :
                UIColorFromRGB(0xd0d0d0);
        } else {
            titleLabel.textColor = [UIColor whiteColor];
            titleLabel.shadowColor = [UIColor blackColor];
        }
        titleLabel.frame = CGRectMake(32, 1, rect.size.width-32, 20);
        
        NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
        UIImage *titleImage = [Utilities getImage:feedIdStr];
        UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
        titleImageView.frame = CGRectMake(8, 3, 16.0, 16.0);
        [titleLabel addSubview:titleImageView];
        [titleImageView release];
        
        [gradientView addSubview:titleLabel];
        [gradientView addSubview:titleImageView];
    } else {
        gradientView = [NewsBlurAppDelegate 
                        makeGradientView:CGRectMake(0, -1, 1024, 10) 
                        // hard coding the 1024 as a hack for window.frame.size.width
                        startColor:[feed objectForKey:@"favicon_color"] 
                        endColor:[feed objectForKey:@"favicon_fade"]];
    }
    
    gradientView.opaque = YES;
    
    return gradientView;
}

- (UIView *)makeFeedTitle:(NSDictionary *)feed {
    
    UILabel *titleLabel = [[[UILabel alloc] init] autorelease];
    if (self.isRiverView) {
        titleLabel.text = [NSString stringWithFormat:@"     %@", self.activeFolder];        
    } else {
        titleLabel.text = [NSString stringWithFormat:@"     %@", [feed objectForKey:@"feed_title"]];
    }
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textAlignment = UITextAlignmentLeft;
    titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:15.0];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
    titleLabel.numberOfLines = 1;
    titleLabel.shadowColor = [UIColor blackColor];
    titleLabel.shadowOffset = CGSizeMake(0, -1);
    titleLabel.center = CGPointMake(28, -2);
    [titleLabel sizeToFit];
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
    UIImage *titleImage;
    if (self.isRiverView) {
        titleImage = [UIImage imageNamed:@"folder.png"];
    } else {
        titleImage = [Utilities getImage:feedIdStr];
    }
	UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
	titleImageView.frame = CGRectMake(0.0, 2.0, 16.0, 16.0);
    [titleLabel addSubview:titleImageView];
    [titleImageView release];

    return titleLabel;
}

@end
