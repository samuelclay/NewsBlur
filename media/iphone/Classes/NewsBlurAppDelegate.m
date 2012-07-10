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
#import "FriendsListViewController.h"
#import "GoogleReaderViewController.h"
#import "LoginViewController.h"
#import "AddSiteViewController.h"
#import "MoveSiteViewController.h"
#import "MGSplitViewController.h"
#import "OriginalStoryViewController.h"
#import "ShareViewController.h"
#import "UserProfileViewController.h"

#import "MBProgressHUD.h"
#import "Utilities.h"
#import "StringHelper.h"

@implementation NewsBlurAppDelegate

@synthesize window;

@synthesize splitStoryController;
@synthesize navigationController;
@synthesize findFriendsNavigationController;
@synthesize splitStoryDetailNavigationController;
@synthesize googleReaderViewController;
@synthesize dashboardViewController;
@synthesize feedsViewController;
@synthesize feedsMenuViewController;
@synthesize feedDetailViewController;
@synthesize feedDashboardViewController;
@synthesize firstTimeUserViewController;
@synthesize friendsListViewController;
@synthesize fontSettingsViewController;
@synthesize storyDetailViewController;
@synthesize shareViewController;
@synthesize loginViewController;
@synthesize addSiteViewController;
@synthesize moveSiteViewController;
@synthesize originalStoryViewController;
@synthesize userProfileViewController;

@synthesize feedDetailPortraitYCoordinate;
@synthesize activeUsername;
@synthesize activeUserProfileId;
@synthesize isRiverView;
@synthesize isSocialView;
@synthesize isShowingShare;
@synthesize popoverHasFeedView;
@synthesize inStoryDetail;
@synthesize inFeedDetail;
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
@synthesize dictActiveFeeds;
@synthesize dictSocialFeeds;
@synthesize dictUserProfile;
@synthesize dictUserInteractions;
@synthesize dictFoldersArray;

+ (NewsBlurAppDelegate*) sharedAppDelegate {
	return (NewsBlurAppDelegate*) [UIApplication sharedApplication].delegate;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
//    [TestFlight takeOff:@"101dd20fb90f7355703b131d9af42633_MjQ0NTgyMDExLTA4LTIxIDIzOjU3OjEzLjM5MDcyOA"];
    
    NSString *currentiPhoneVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [ASIHTTPRequest setDefaultUserAgentString:[NSString stringWithFormat:@"NewsBlur iPad App v%@",
                                                   currentiPhoneVersion]];
    } else {
        [ASIHTTPRequest setDefaultUserAgentString:[NSString stringWithFormat:@"NewsBlur iPhone App v%@",
                                                   currentiPhoneVersion]];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        self.navigationController.viewControllers = [NSArray arrayWithObject:feedsViewController];
        self.splitStoryDetailNavigationController.viewControllers = [NSArray arrayWithObject:self.dashboardViewController];
        self.splitStoryController.viewControllers = [NSArray arrayWithObjects:navigationController, splitStoryDetailNavigationController, nil];
        
        [window addSubview:self.splitStoryController.view];
        self.window.rootViewController = self.splitStoryController;
    } else {
        self.navigationController.viewControllers = [NSArray arrayWithObject:self.feedsViewController];
        [window addSubview:self.navigationController.view];
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
    [self.feedsViewController fetchFeedList:YES refreshFeeds:YES];
    
    //[self showFirstTimeUser];
	return YES;
}

- (void)viewDidLoad {
    self.selectedIntelligence = 1;
    self.visibleUnreadCount = 0;
    [self setRecentlyReadStories:[NSMutableArray array]];
}

- (void)dealloc {
    [dashboardViewController release];
    [feedsViewController release];
    [feedsMenuViewController release];
    [feedDetailViewController release];
    [friendsListViewController release];
    [storyDetailViewController release];
    [loginViewController release];
    [addSiteViewController release];
    [moveSiteViewController release];
    [originalStoryViewController release];
    [navigationController release];
    [userProfileViewController release];
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
    [dictActiveFeeds release];
    [dictFeeds release];
    [dictSocialFeeds release];
    [dictUserProfile release];
    [dictUserInteractions release];
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

- (void)showAddSite {
    UINavigationController *navController = self.navigationController;
    [navController dismissModalViewControllerAnimated:NO];
    [addSiteViewController initWithNibName:nil bundle:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        addSiteViewController.modalPresentationStyle = UIModalPresentationFormSheet;
        [navController presentModalViewController:addSiteViewController animated:YES];
        //it's important to do this after presentModalViewController
        addSiteViewController.view.superview.frame = CGRectMake(0, 0, 320, 460); 
        if ([self isPortrait]) {
            addSiteViewController.view.superview.center = self.view.center;
        } else {
            addSiteViewController.view.superview.center = CGPointMake(self.view.center.y, self.view.center.x);
        }
    } else {
        [navController presentModalViewController:addSiteViewController animated:YES];
    }
    
    [addSiteViewController reload];
}

#pragma mark -
#pragma mark Social Views

- (void)showUserProfile {
    self.findFriendsNavigationController.viewControllers = [NSArray arrayWithObject:userProfileViewController];
    self.findFriendsNavigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    
    self.findFriendsNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        
        [splitStoryController presentModalViewController:findFriendsNavigationController animated:NO];
    } else {
        [navigationController presentModalViewController:findFriendsNavigationController animated:NO];
    }

}

- (void)showFindFriends {
    self.findFriendsNavigationController.viewControllers = [NSArray arrayWithObject:friendsListViewController];
    self.findFriendsNavigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    
    self.findFriendsNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [splitStoryController presentModalViewController:findFriendsNavigationController animated:YES];
    } else {
        [navigationController presentModalViewController:findFriendsNavigationController animated:YES];
    }
}

- (void)showShareView:(NSString *)userId 
          setUsername:(NSString *)username {
    
    self.isShowingShare = YES;
    
    
    [storyDetailViewController.view addSubview:shareViewController.view];    
    
    if (userId && username) {
        [shareViewController setSiteInfo:userId setUsername:username];  
    }
    


    shareViewController.view.frame = CGRectMake(0, 
                                                storyDetailViewController.view.frame.size.height, 
                                                storyDetailViewController.view.frame.size.width, 
                                                0);
    
    int newShareHeight = storyDetailViewController.view.frame.size.height - SHARE_MODAL_HEIGHT;
    int newStoryHeight = storyDetailViewController.view.frame.size.height - SHARE_MODAL_HEIGHT + 44;
    
    shareViewController.view.hidden = NO;
    
    [UIView animateWithDuration:0.35 animations:^{
        shareViewController.view.frame = CGRectMake(0, 
                                                    newShareHeight, 
                                                    storyDetailViewController.view.frame.size.width, 
                                                    SHARE_MODAL_HEIGHT);
    } completion:^(BOOL finished) {
        storyDetailViewController.view.frame = CGRectMake(0,
                                                          0,
                                                          storyDetailViewController.view.frame.size.width,
                                                          newStoryHeight);
    }]; 
}

- (void)hideShareView {
    self.isShowingShare = NO;
    
    storyDetailViewController.view.frame = CGRectMake(0,
                                                      0,
                                                      storyDetailViewController.view.frame.size.width,
                                                       storyDetailViewController.view.frame.size.height);
    
    [UIView animateWithDuration:0.35 animations:^{
        shareViewController.view.frame = CGRectMake(0, 
                                                    storyDetailViewController.view.frame.size.height + SHARE_MODAL_HEIGHT,
                                                    storyDetailViewController.view.frame.size.width,
                                                    0);
    } completion:^(BOOL finished) {
        shareViewController.view.hidden = YES;
    }]; 
    
}

- (void)refreshComments {
    [storyDetailViewController refreshComments];
}

- (void)resetShareComments {
    [shareViewController clearComments];
}

#pragma mark -
#pragma mark Views

- (void)showLogin {
    self.dictFeeds = nil;
    self.dictSocialFeeds = nil;
    self.dictFolders = nil;
    self.dictFoldersArray = nil;
    
    [self.feedsViewController.feedTitlesTable reloadData];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.splitStoryController presentModalViewController:loginViewController animated:YES];
    } else {
        [feedsMenuViewController dismissModalViewControllerAnimated:NO];
        [self.navigationController presentModalViewController:loginViewController animated:YES];
    }
        
}

- (void)showFirstTimeUser {
    [loginViewController dismissModalViewControllerAnimated:NO];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
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
    [feedsViewController fetchFeedList:showLoader refreshFeeds:YES];
    [loginViewController dismissModalViewControllerAnimated:YES];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
}

- (void)loadFeedDetailView {
    [self setStories:nil];
    [self setFeedUserProfiles:nil];
    
    self.inFeedDetail = YES;
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
    
    [feedDetailViewController resetFeedDetail];
    [feedDetailViewController fetchFeedDetail:1 withCallback:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if ([[self.splitStoryDetailNavigationController viewControllers] containsObject:self.feedDashboardViewController]) {
            //[self.storyDetailViewController initStory];
        } else {
            [self.splitStoryDetailNavigationController pushViewController:self.feedDashboardViewController animated:YES];
        }
    }  
}

- (void)showDashboard {
    self.inStoryDetail = NO;
    self.inFeedDetail = NO;
    [self.splitStoryDetailNavigationController popToRootViewControllerAnimated:YES];
}


- (BOOL)isSocialFeed:(NSString *)feedIdStr {
    if ([feedIdStr length] > 6) {
        NSString *feedIdSubStr = [feedIdStr substringToIndex:6];
        if ([feedIdSubStr isEqualToString:@"social"]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isPortrait {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;        
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        return YES;
    } else {
        return NO;
    }
}

- (void)confirmLogout {
    UIAlertView *logoutConfirm = [[UIAlertView alloc] initWithTitle:@"Positive?" 
                                                            message:nil 
                                                           delegate:self 
                                                  cancelButtonTitle:@"Cancel" 
                                                  otherButtonTitles:@"Logout", nil];
    [logoutConfirm show];
    [logoutConfirm setTag:1];
    [logoutConfirm release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 1) { // this is logout
        if (buttonIndex == 0) {
            return;
        } else {
            NSLog(@"Logging out...");
            NSString *urlS = [NSString stringWithFormat:@"http://%@/reader/logout?api=1",
                              NEWSBLUR_URL];
            NSURL *url = [NSURL URLWithString:urlS];
            
            __block ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
            [request setDelegate:self];
            [request setResponseEncoding:NSUTF8StringEncoding];
            [request setDefaultResponseEncoding:NSUTF8StringEncoding];
            [request setFailedBlock:^(void) {
                [MBProgressHUD hideHUDForView:self.view animated:YES];
            }];
            [request setCompletionBlock:^(void) {
                NSLog(@"Logout successful");
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                [self showLogin];
            }];
            [request setTimeOutSeconds:30];
            [request startAsynchronous];
            
            [ASIHTTPRequest setSessionCookies:nil];
            
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            HUD.labelText = @"Logging out...";
        }
    }
}

- (void)loadRiverFeedDetailView {
    [self setStories:nil];
    [self setFeedUserProfiles:nil];
    self.inFeedDetail = YES;

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
    
    [feedDetailViewController resetFeedDetail];
    [feedDetailViewController fetchRiverPage:1 withCallback:nil];
    
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if ([[self.splitStoryDetailNavigationController viewControllers] containsObject:self.feedDashboardViewController]) {
            //[self.storyDetailViewController initStory];
        } else {
            [self.splitStoryDetailNavigationController pushViewController:self.feedDashboardViewController animated:YES];
        }
    }  
}

- (void)adjustStoryDetailWebView {
    if (!self.inFeedDetail) {
        return;
    }
//        
//    if (self.isShowingShare) {
//        [self showShareView:nil setUsername:nil];
//    } else {
//        [self hideShareView];
//    }
//    
    UIImage *slide;
    if (self.splitStoryController.isShowingMaster) {
        slide = [[UIImage imageNamed: @"slide_left.png"] retain];
        
        [self.storyDetailViewController.toggleViewButton setImage:slide];

        self.storyDetailViewController.navigationItem.titleView = nil;
    } else {
        slide = [[UIImage imageNamed: @"slide_right.png"] retain];
        [self.storyDetailViewController.toggleViewButton setImage:slide];
        
        UIView *titleLabel = [self makeFeedTitle:self.activeFeed];
        if (storyDetailViewController.navigationItem){
            storyDetailViewController.navigationItem.titleView = titleLabel;
        }
    }
    [slide release];
//    
//    int contentWidth = splitStoryDetailViewController.view.frame.size.width;
//    // set the styles inside the UIWebView
//            
//    if (UIInterfaceOrientationIsPortrait(splitStoryDetailViewController.interfaceOrientation)) {        
//        storyDetailViewController.view.frame = CGRectMake(0, 
//                                                          0, 
//                                                          splitStoryDetailViewController.view.frame.size.width, 
//                                                          splitStoryDetailViewController.view.frame.size.height);
//    } else {
//        storyDetailViewController.view.frame = CGRectMake(0, 
//                                                          0, 
//                                                          splitStoryDetailViewController.view.frame.size.width, 
//                                                          splitStoryDetailViewController.view.frame.size.height);
//    }
//    

//    
//    // change UIWebView
//    [storyDetailViewController changeWebViewWidth:contentWidth];
}

- (void)animateHidingMasterView {
    if (!self.splitStoryController.isShowingMaster) {
        return;
    }
    
    int width = storyDetailViewController.view.frame.size.width + 291;
    [UIView animateWithDuration:0.1 animations:^{
        storyDetailViewController.view.frame = CGRectMake(0, 
                                                    0, 
                                                    width, 
                                                    storyDetailViewController.view.frame.size.height);
    }];
        
    [self.splitStoryController toggleMasterView:nil];    
    [self performSelector:@selector(adjustStoryDetailWebView) withObject:self afterDelay:0.1 ];
}

- (void)animateShowingMasterView {
    if (self.splitStoryController.isShowingMaster) {
        return;
    }
    
    int width = storyDetailViewController.view.frame.size.width - 291;
    [UIView animateWithDuration:0.50 animations:^{
        storyDetailViewController.view.frame = CGRectMake(0, 
                                                          0, 
                                                          width, 
                                                          storyDetailViewController.view.frame.size.height);
    }]; 

    [self.splitStoryController toggleMasterView:nil];
    [self performSelector:@selector(adjustStoryDetailWebView) withObject:self afterDelay:.1 ];
}

- (void)dragFeedDetailView:(float)y {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if (UIInterfaceOrientationIsPortrait(storyDetailViewController.interfaceOrientation)) {
        y = y + 20;
        
        if(y > 955) {
            self.feedDetailPortraitYCoordinate = 960;
        } else if(y < 950 && y > 200) {
            self.feedDetailPortraitYCoordinate = y;
        }
        
        [userPreferences setInteger:self.feedDetailPortraitYCoordinate forKey:@"feedDetailPortraitYCoordinate"];
        [userPreferences synchronize];
        [self adjustStoryDetailWebView];        
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
        if ([[self.splitStoryDetailNavigationController viewControllers] containsObject:self.storyDetailViewController]) {
            [self.storyDetailViewController initStory];
        } else {
            [self.splitStoryDetailNavigationController pushViewController:self.storyDetailViewController animated:YES];
        }
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
    self.activeOriginalStoryURL = url;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [splitStoryController presentModalViewController:originalStoryViewController animated:YES];
    } else {
        UINavigationController *navController = self.navigationController;
        [navController presentModalViewController:originalStoryViewController animated:YES];
    }

}

- (void)closeOriginalStory {
    [originalStoryViewController dismissModalViewControllerAnimated:YES];
}

- (void)hideStoryDetailView {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.splitStoryDetailNavigationController popViewControllerAnimated:YES];
    }
}

- (int)indexOfNextUnreadStory {
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

- (int)indexOfNextStory {
    int activeLocation = [self locationOfActiveStory];
    int nextStoryLocation = activeLocation + 1;
    if (nextStoryLocation < [self.activeFeedStoryLocations count]) {
        int location = [[self.activeFeedStoryLocations objectAtIndex:nextStoryLocation] intValue];
        return location;
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

    int activeIndex = [[activeFeedStoryLocations objectAtIndex:activeLocation] intValue];
    
    NSDictionary *feed;
    id feedId;;
    NSString *feedIdStr;
    NSMutableArray *otherFriendFeeds = [self.activeStory objectForKey:@"shared_by_friends"];
    
    if (self.isSocialView) {
        feedId = [self.activeStory objectForKey:@"social_user_id"];
        feedIdStr = [NSString stringWithFormat:@"social:%@",feedId];        
        feed = [self.dictSocialFeeds objectForKey:feedIdStr];
        
        [otherFriendFeeds removeObject:feedId];
         NSLog(@"otherFriendFeeds is %@", otherFriendFeeds);
        
        
    } else {
        feedId = [self.activeStory objectForKey:@"story_feed_id"];
        feedIdStr = [NSString stringWithFormat:@"%@",feedId];
        feed = [self.dictFeeds objectForKey:feedIdStr];
    }
    
    NSDictionary *story = [activeFeedStories objectAtIndex:activeIndex];
//    if (self.activeFeed != feed) {
//        self.activeFeed = feed;
//    }
    
    [self.recentlyReadStories addObject:[NSNumber numberWithInt:activeLocation]];
    [self markStoryRead:story feed:feed];
    
    // decrement all other friend feeds
    if (self.isSocialView) {
        for (int i = 0; i < otherFriendFeeds.count; i++) {
            feedIdStr = [NSString stringWithFormat:@"social:%@",
                         [otherFriendFeeds objectAtIndex:i]];   
            feed = [self.dictSocialFeeds objectForKey:feedIdStr];
            [self markStoryRead:story feed:feed];
        }
    }

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
    if (self.isRiverView || self.isSocialView) {
        gradientView = [NewsBlurAppDelegate 
                        makeGradientView:rect
                        startColor:[feed objectForKey:@"favicon_fade"] 
                        endColor:[feed objectForKey:@"favicon_color"]];
        
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
                        startColor:[feed objectForKey:@"favicon_fade"] 
                        endColor:[feed objectForKey:@"favicon_color"]];
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
