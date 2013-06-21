//
//  NewsBlurAppDelegate.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "NewsBlurViewController.h"
#import "NBContainerViewController.h"
#import "FeedDetailViewController.h"
#import "DashboardViewController.h"
#import "FeedsMenuViewController.h"
#import "FeedDetailMenuViewController.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "FirstTimeUserViewController.h"
#import "FriendsListViewController.h"
#import "LoginViewController.h"
#import "AddSiteViewController.h"
#import "MoveSiteViewController.h"
#import "TrainerViewController.h"
#import "OriginalStoryViewController.h"
#import "ShareViewController.h"
#import "UserProfileViewController.h"
#import "NBContainerViewController.h"
#import "AFJSONRequestOperation.h"
#import "InteractionsModule.h"
#import "ActivityModule.h"
#import "FirstTimeUserViewController.h"
#import "FirstTimeUserAddSitesViewController.h"
#import "FirstTimeUserAddFriendsViewController.h"
#import "FirstTimeUserAddNewsBlurViewController.h"
#import "MBProgressHUD.h"
#import "Utilities.h"
#import "StringHelper.h"
#import "AuthorizeServicesViewController.h"
#import "ShareThis.h"
#import "Reachability.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "FMDatabaseAdditions.h"
#import "JSON.h"

@implementation NewsBlurAppDelegate

#define CURRENT_DB_VERSION 9
#define IS_IPHONE_5 ( fabs( ( double )[ [ UIScreen mainScreen ] bounds ].size.height - ( double )568 ) < DBL_EPSILON )

@synthesize window;

@synthesize ftuxNavigationController;
@synthesize navigationController;
@synthesize modalNavigationController;
@synthesize shareNavigationController;
@synthesize trainNavigationController;
@synthesize userProfileNavigationController;
@synthesize masterContainerViewController;
@synthesize dashboardViewController;
@synthesize feedsViewController;
@synthesize feedsMenuViewController;
@synthesize feedDetailViewController;
@synthesize feedDetailMenuViewController;
@synthesize feedDashboardViewController;
@synthesize friendsListViewController;
@synthesize fontSettingsViewController;
@synthesize storyDetailViewController;
@synthesize storyPageControl;
@synthesize shareViewController;
@synthesize loginViewController;
@synthesize addSiteViewController;
@synthesize moveSiteViewController;
@synthesize trainerViewController;
@synthesize originalStoryViewController;
@synthesize userProfileViewController;

@synthesize firstTimeUserViewController;
@synthesize firstTimeUserAddSitesViewController;
@synthesize firstTimeUserAddFriendsViewController;
@synthesize firstTimeUserAddNewsBlurViewController;

@synthesize feedDetailPortraitYCoordinate;
@synthesize activeUsername;
@synthesize activeUserProfileId;
@synthesize activeUserProfileName;
@synthesize hasNoSites;
@synthesize isRiverView;
@synthesize isSocialView;
@synthesize isSocialRiverView;
@synthesize isTryFeedView;

@synthesize inFindingStoryMode;
@synthesize hasQueuedReadStories;
@synthesize tryFeedStoryId;
@synthesize tryFeedCategory;
@synthesize popoverHasFeedView;
@synthesize inFeedDetail;
@synthesize inStoryDetail;
@synthesize activeComment;
@synthesize activeShareType;

@synthesize activeFeed;
@synthesize activeClassifiers;
@synthesize activePopularTags;
@synthesize activePopularAuthors;
@synthesize activeFolder;
@synthesize activeFolderFeeds;
@synthesize activeFeedStories;
@synthesize activeFeedStoryLocations;
@synthesize activeFeedStoryLocationIds;
@synthesize activeFeedUserProfiles;
@synthesize activeStory;
@synthesize storyCount;
@synthesize storyLocationsCount;
@synthesize visibleUnreadCount;
@synthesize savedStoriesCount;
@synthesize totalUnfetchedStoryCount;
@synthesize remainingUnfetchedStoryCount;
@synthesize latestFetchedStoryDate;
@synthesize originalStoryCount;
@synthesize selectedIntelligence;
@synthesize activeOriginalStoryURL;
@synthesize recentlyReadStories;
@synthesize recentlyReadFeeds;
@synthesize readStories;
@synthesize folderCountCache;

@synthesize dictFolders;
@synthesize dictFeeds;
@synthesize dictActiveFeeds;
@synthesize dictSocialFeeds;
@synthesize dictSocialProfile;
@synthesize dictUserProfile;
@synthesize dictSocialServices;
@synthesize userInteractionsArray;
@synthesize userActivitiesArray;
@synthesize dictFoldersArray;

@synthesize database;
@synthesize categories;
@synthesize categoryFeeds;

+ (NewsBlurAppDelegate*) sharedAppDelegate {
	return (NewsBlurAppDelegate*) [UIApplication sharedApplication].delegate;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    NSString *currentiPhoneVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    self.navigationController.delegate = self;
    self.navigationController.viewControllers = [NSArray arrayWithObject:self.feedsViewController];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [ASIHTTPRequest setDefaultUserAgentString:[NSString stringWithFormat:@"NewsBlur iPad App v%@",
                                                   currentiPhoneVersion]];
        [window addSubview:self.masterContainerViewController.view];
        self.window.rootViewController = self.masterContainerViewController;
    } else {
        [ASIHTTPRequest setDefaultUserAgentString:[NSString stringWithFormat:@"NewsBlur iPhone App v%@",
                                                   currentiPhoneVersion]];
        [window addSubview:self.navigationController.view];
        self.window.rootViewController = self.navigationController;
    }
    
    
    [window makeKeyAndVisible];
    [self.feedsViewController fetchFeedList:YES];
    
    [ShareThis startSessionWithFacebookURLSchemeSuffix:@"newsblur" pocketAPI:@"c23d9HbTT2a8fma098AfIr9zQTgcF0l9" readabilityKey:@"samuelclay" readabilitySecret:@"ktLQc88S9WCE8PfvZ4u4q995Q3HMzg6Q"];
    
    [[UINavigationBar appearance]
     setBackgroundImage:[UIImage imageNamed:@"navbar_background.png"]
     forBarMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance]
     setBackgroundImage:[UIImage imageNamed:@"navbar_landscape_background.png"]
     forBarMetrics:UIBarMetricsLandscapePhone];
    [[UIToolbar appearance]
     setBackgroundImage:[UIImage imageNamed:@"toolbar_background.png"]
     forToolbarPosition:UIToolbarPositionBottom barMetrics:UIBarMetricsDefault];
    [[UIToolbar appearance]
     setBackgroundImage:[UIImage imageNamed:@"navbar_background.png"]
     forToolbarPosition:UIToolbarPositionTop barMetrics:UIBarMetricsDefault];
    [[UIToolbar appearance]
     setBackgroundImage:[UIImage imageNamed:@"navbar_landscape_background.png"]
     forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsLandscapePhone];

    [[UINavigationBar appearance]
     setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                             UIColorFromRGB(0x404040), UITextAttributeTextColor,
                             UIColorFromRGB(0xFAFAFA), UITextAttributeTextShadowColor,
                             [NSValue valueWithUIOffset:UIOffsetMake(0, -1)],
                             UITextAttributeTextShadowOffset,
                             nil]];
    
    [self performSelectorOnMainThread:@selector(showSplashView) withObject:nil waitUntilDone:NO];
    [self createDatabaseConnection];
//    [self showFirstTimeUser];

	return YES;
}

- (void)showSplashView {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    splashView = [[UIImageView alloc] init];
//    int rotate = 0;
//    if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
//        NSLog(@"UPSIDE DOWN");
//        rotate = -2;
//    } else if (orientation == UIInterfaceOrientationLandscapeLeft) {
//        rotate = -1;
//    } else if (orientation == UIInterfaceOrientationLandscapeRight) {
//        rotate = 1;
//    }
//    splashView.transform = CGAffineTransformMakeRotation(M_PI * rotate * 90.0 / 180);
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
        UIInterfaceOrientationIsLandscape(orientation)) {
        splashView.frame = CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width);
        splashView.image = [UIImage imageNamed:@"Default-Landscape.png"];
        NSLog(@"Window frame; %@", NSStringFromCGRect(self.view.frame));
    } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        splashView.frame = self.view.frame;
        splashView.image = [UIImage imageNamed:@"Default-Portrait.png"];
    } else if (IS_IPHONE_5) {
        splashView.frame = CGRectMake(0, 0, self.window.frame.size.width, 568);
        splashView.image = [UIImage imageNamed:@"Default-568h.png"];
    } else {
        splashView.frame = self.window.frame;
        splashView.image = [UIImage imageNamed:@"Default.png"];
    }
    
    //    [splashView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    splashView.alpha = 1.0;
    [window.rootViewController.view addSubview:splashView];
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:.6];
    [UIView setAnimationTransition:UIViewAnimationTransitionNone forView:window cache:YES];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(startupAnimationDone:finished:context:)];
//    splashView.alpha = 0;
    splashView.frame = CGRectMake(0, -1 * splashView.frame.size.height, splashView.frame.size.width, splashView.frame.size.height);
    //    splashView.frame = CGRectMake(-60, -80, 440, 728);
    [UIView commitAnimations];
    [self setupReachability];
}

- (void)viewDidLoad {
    self.visibleUnreadCount = 0;
    self.savedStoriesCount = 0;
    self.totalUnfetchedStoryCount = 0;
    self.remainingUnfetchedStoryCount = 0;
    self.latestFetchedStoryDate = 0;
    [self setRecentlyReadStories:[NSMutableArray array]];
}

- (void)startupAnimationDone:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    [splashView removeFromSuperview];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[NSNotificationCenter defaultCenter] postNotificationName:AppDidBecomeActiveNotificationName object:nil];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[NSNotificationCenter defaultCenter] postNotificationName:AppWillTerminateNotificationName object:nil];
}
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [ShareThis handleFacebookOpenUrl:url];
}

- (void)setupReachability {
    Reachability* reach = [Reachability reachabilityWithHostname:NEWSBLUR_HOST];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    reach.reachableBlock = ^(Reachability *reach) {
        NSLog(@"Reachable: %@", reach);
    };
    reach.unreachableBlock = ^(Reachability *reach) {
        NSLog(@"Un-Reachable: %@", reach);
    };
    [reach startNotifier];
}

- (void)reachabilityChanged:(id)something {
    NSLog(@"Reachability changed: %@", something);
}

#pragma mark -
#pragma mark Social Views

- (void)showUserProfileModal:(id)sender {
    UserProfileViewController *newUserProfile = [[UserProfileViewController alloc] init];
    self.userProfileViewController = newUserProfile; 
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.userProfileViewController];
    self.userProfileNavigationController = navController;

    
    // adding Done button
    UIBarButtonItem *donebutton = [[UIBarButtonItem alloc]
                                   initWithTitle:@"Close" 
                                   style:UIBarButtonItemStyleDone 
                                   target:self 
                                   action:@selector(hideUserProfileModal)];
    
    newUserProfile.navigationItem.rightBarButtonItem = donebutton;
    newUserProfile.navigationItem.title = self.activeUserProfileName;
    newUserProfile.navigationItem.backBarButtonItem.title = self.activeUserProfileName;
    [newUserProfile getUserProfile];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController showUserProfilePopover:sender];
    } else {
        [self.navigationController presentViewController:navController animated:YES completion:nil];
    }

}

- (void)pushUserProfile {
    UserProfileViewController *userProfileView = [[UserProfileViewController alloc] init];


    // adding Done button
    UIBarButtonItem *donebutton = [[UIBarButtonItem alloc]
                                   initWithTitle:@"Close" 
                                   style:UIBarButtonItemStyleDone 
                                   target:self 
                                   action:@selector(hideUserProfileModal)];
    
    userProfileView.navigationItem.rightBarButtonItem = donebutton;
    userProfileView.navigationItem.title = self.activeUserProfileName;
    userProfileView.navigationItem.backBarButtonItem.title = self.activeUserProfileName;
    [userProfileView getUserProfile];   
    if (self.modalNavigationController.view.window == nil) {
        [self.userProfileNavigationController pushViewController:userProfileView animated:YES];
    } else {
        [self.modalNavigationController pushViewController:userProfileView animated:YES];
    };

}

- (void)hideUserProfileModal {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController hidePopover];
    } else {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)showFindFriends {
    FriendsListViewController *friendsBVC = [[FriendsListViewController alloc] init];
    UINavigationController *friendsNav = [[UINavigationController alloc] initWithRootViewController:friendsListViewController];
    
    self.friendsListViewController = friendsBVC;    
    self.modalNavigationController = friendsNav;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.modalNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
        [masterContainerViewController presentViewController:modalNavigationController animated:YES completion:nil];
    } else {
        [navigationController presentViewController:modalNavigationController animated:YES completion:nil];
    }
    [self.friendsListViewController loadSuggestedFriendsList];
}

- (void)showShareView:(NSString *)type 
            setUserId:(NSString *)userId 
          setUsername:(NSString *)username 
      setReplyId:(NSString *)replyId {
    
    [self.shareViewController setCommentType:type];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController transitionToShareView];
    } else {
        if (self.shareNavigationController == nil) {
            UINavigationController *shareNav = [[UINavigationController alloc]
                                                initWithRootViewController:self.shareViewController];
            self.shareNavigationController = shareNav;
        }
        [self.shareViewController setSiteInfo:type setUserId:userId setUsername:username setReplyId:replyId];
        [self.navigationController presentViewController:self.shareNavigationController animated:YES completion:nil];
    }

    [self.shareViewController setSiteInfo:type setUserId:userId setUsername:username setReplyId:replyId];
}

- (void)hideShareView:(BOOL)resetComment {
    if (resetComment) {
        self.shareViewController.commentField.text = @"";
        self.shareViewController.currentType = nil;
    }
        
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {        
        [self.masterContainerViewController transitionFromShareView];
    } else {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        [self.shareViewController.commentField resignFirstResponder];
    }
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
    self.userActivitiesArray = nil;
    self.userInteractionsArray = nil;
    
    [self.feedsViewController.feedTitlesTable reloadData];
    [self.feedsViewController resetToolbar];
    
    [self.dashboardViewController.interactionsModule.interactionsTable reloadData];
    [self.dashboardViewController.activitiesModule.activitiesTable reloadData];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];    
    [userPreferences setInteger:-1 forKey:@"selectedIntelligence"];
    [userPreferences synchronize];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController presentViewController:loginViewController animated:NO completion:nil];
    } else {
        [feedsMenuViewController dismissViewControllerAnimated:NO completion:nil];
        [self.navigationController presentViewController:loginViewController animated:NO completion:nil];
    }
}

- (void)showFirstTimeUser {
//    [self.feedsViewController changeToAllMode];
    
    UINavigationController *ftux = [[UINavigationController alloc] initWithRootViewController:self.firstTimeUserViewController];
    
    self.ftuxNavigationController = ftux;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.ftuxNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
        [self.masterContainerViewController presentViewController:self.ftuxNavigationController animated:YES completion:nil];
        
        self.ftuxNavigationController.view.superview.frame = CGRectMake(0, 0, 540, 540);//it's important to do this after 
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            self.ftuxNavigationController.view.superview.center = self.view.center;
        } else {
            self.ftuxNavigationController.view.superview.center = CGPointMake(self.view.center.y, self.view.center.x);
        }
            
    } else {
        [self.navigationController presentViewController:self.ftuxNavigationController animated:YES completion:nil];
    }
}

- (void)showMoveSite {
    UINavigationController *navController = self.navigationController;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        moveSiteViewController.modalPresentationStyle=UIModalPresentationFormSheet;
        [navController presentViewController:moveSiteViewController animated:YES completion:nil];
    } else {
        [navController presentViewController:moveSiteViewController animated:YES completion:nil];
    }
}

- (void)openTrainSite {
    UINavigationController *navController = self.navigationController;
    trainerViewController.feedTrainer = YES;
    trainerViewController.storyTrainer = NO;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
//        trainerViewController.modalPresentationStyle=UIModalPresentationFormSheet;
//        [navController presentViewController:trainerViewController animated:YES completion:nil];
        [self.masterContainerViewController showTrainingPopover:self.feedDetailViewController.settingsBarButton];
    } else {
        if (self.trainNavigationController == nil) {
            self.trainNavigationController = [[UINavigationController alloc]
                                              initWithRootViewController:self.trainerViewController];
        }
        [navController presentViewController:self.trainNavigationController animated:YES completion:nil];
    }
}

- (void)openTrainStory:(id)sender {
    UINavigationController *navController = self.navigationController;
    trainerViewController.feedTrainer = NO;
    trainerViewController.storyTrainer = YES;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController showTrainingPopover:sender];
    } else {
        if (self.trainNavigationController == nil) {
            self.trainNavigationController = [[UINavigationController alloc]
                                              initWithRootViewController:self.trainerViewController];
        }
        [navController presentViewController:self.trainNavigationController animated:YES completion:nil];
    }
}

- (void)reloadFeedsView:(BOOL)showLoader {
    [feedsViewController fetchFeedList:showLoader];
    [loginViewController dismissViewControllerAnimated:NO completion:nil];
}

- (void)loadFeedDetailView {
    [self setStories:nil];
    [self setFeedUserProfiles:nil];
    self.inFeedDetail = YES;    
    popoverHasFeedView = YES;
    
    UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc]
                                      initWithTitle: @"All"
                                      style: UIBarButtonItemStyleBordered
                                      target: nil
                                      action: nil];
    [feedsViewController.navigationItem setBackBarButtonItem:newBackButton];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController transitionToFeedDetail];
    } else {
        [navigationController pushViewController:feedDetailViewController
                                        animated:YES];
    }
    
    [feedDetailViewController resetFeedDetail];
    [feedDetailViewController fetchFeedDetail:1 withCallback:nil];
    [self flushQueuedReadStories:NO withCallback:nil];
}

- (void)loadTryFeedDetailView:(NSString *)feedId
                    withStory:(NSString *)contentId
                     isSocial:(BOOL)social
                     withUser:(NSDictionary *)user
             showFindingStory:(BOOL)showHUD {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.navigationController popToRootViewControllerAnimated:NO];
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        if (self.feedsViewController.popoverController) {
            [self.feedsViewController.popoverController dismissPopoverAnimated:NO];
        }
    }
    
    NSDictionary *feed = nil;
    
    if (social) {
        feed = [self.dictSocialFeeds objectForKey:feedId];
        self.isSocialView = YES;
        self.inFindingStoryMode = YES;
  
        if (feed == nil) {
            feed = user;
            self.isTryFeedView = YES;
        }
    } else {
        feed = [self.dictFeeds objectForKey:feedId];
        if (feed == nil) {
            feed = user;
            self.isTryFeedView = YES;

        }
        [self setIsSocialView:NO];
        [self setInFindingStoryMode:NO];
    }
            
    self.tryFeedStoryId = contentId;
    self.activeFeed = feed;
    self.activeFolder = nil;
    
    [self loadFeedDetailView];
    
    if (showHUD) {
        [self.storyPageControl showShareHUD:@"Finding story..."];
    }
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

- (NSString *)orderKey {
    if (self.isRiverView) {
        return [NSString stringWithFormat:@"folder:%@:order", self.activeFolder];
    } else {
        return [NSString stringWithFormat:@"%@:order", [self.activeFeed objectForKey:@"id"]];
    }
}

- (NSString *)readFilterKey {
    if (self.isRiverView) {
        return [NSString stringWithFormat:@"folder:%@:read_filter", self.activeFolder];
    } else {
        return [NSString stringWithFormat:@"%@:read_filter", [self.activeFeed objectForKey:@"id"]];
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
}

- (void)showConnectToService:(NSString *)serviceName {
    AuthorizeServicesViewController *serviceVC = [[AuthorizeServicesViewController alloc] init];
    serviceVC.url = [NSString stringWithFormat:@"/oauth/%@_connect", serviceName];
    serviceVC.type = serviceName;
    serviceVC.fromStory = YES;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UINavigationController *connectNav = [[UINavigationController alloc]
                                              initWithRootViewController:serviceVC];
        self.modalNavigationController = connectNav;
        self.modalNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
        [self.masterContainerViewController presentViewController:modalNavigationController
                                                              animated:YES completion:nil];
    } else {
        [self.shareNavigationController pushViewController:serviceVC animated:YES];
    }
}

- (void)refreshUserProfile:(void(^)())callback {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/social/load_user_profile",
                                       NEWSBLUR_URL]];
    ASIHTTPRequest *_request = [ASIHTTPRequest requestWithURL:url];
    __weak ASIHTTPRequest *request = _request;
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    [request setFailedBlock:^(void) {
        NSLog(@"Failed user profile");
        callback();
    }];
    [request setCompletionBlock:^(void) {
        NSString *responseString = [request responseString];
        NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error;
        NSDictionary *results = [NSJSONSerialization
                                 JSONObjectWithData:responseData
                                 options:kNilOptions
                                 error:&error];
        
        self.dictUserProfile = [results objectForKey:@"user_profile"];
        self.dictSocialServices = [results objectForKey:@"services"];
        callback();
    }];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 1) { // this is logout
        if (buttonIndex == 0) {
            return;
        } else {
            NSLog(@"Logging out...");
            NSString *urlS = [NSString stringWithFormat:@"%@/reader/logout?api=1",
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

    [feedDetailViewController resetFeedDetail];
    [feedDetailViewController fetchRiverPage:1 withCallback:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController transitionToFeedDetail];
    } else {
        UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle: @"All" 
                                                                          style: UIBarButtonItemStyleBordered 
                                                                         target: nil 
                                                                         action: nil];
        [feedsViewController.navigationItem setBackBarButtonItem: newBackButton];
        UINavigationController *navController = self.navigationController;
        [navController pushViewController:feedDetailViewController animated:YES];
    }
}

- (void)adjustStoryDetailWebView {
    // change UIWebView
    [storyPageControl.currentPage changeWebViewWidth];
    [storyPageControl.nextPage changeWebViewWidth];
    [storyPageControl.previousPage changeWebViewWidth];
}

- (void)calibrateStoryTitles {
    [self.feedDetailViewController checkScroll];
    [self.feedDetailViewController changeActiveFeedDetailRow];
    
}

- (void)recalculateIntelligenceScores:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
    NSMutableArray *newFeedStories = [NSMutableArray array];
    
    for (NSDictionary *story in self.activeFeedStories) {
        NSString *storyFeedId = [NSString stringWithFormat:@"%@",
                                 [story objectForKey:@"story_feed_id"]];
        if (![storyFeedId isEqualToString:feedIdStr]) {
            [newFeedStories addObject:story];
            continue;
        }

        NSMutableDictionary *newStory = [story mutableCopy];

        // If the story is visible, mark it as sticky so it doesn;t go away on page loads.
        int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
        if (score >= self.selectedIntelligence) {
            [newStory setObject:[NSNumber numberWithBool:YES] forKey:@"sticky"];
        }
        
        NSNumber *zero = [NSNumber numberWithInt:0];
        NSMutableDictionary *intelligence = [NSMutableDictionary
                                             dictionaryWithObjects:[NSArray arrayWithObjects:
                                                                    [zero copy], [zero copy],
                                                                    [zero copy], [zero copy], nil]
                                             forKeys:[NSArray arrayWithObjects:
                                                      @"author", @"feed", @"tags", @"title", nil]];
        NSDictionary *classifiers = [self.activeClassifiers objectForKey:feedIdStr];
        
        for (NSString *title in [classifiers objectForKey:@"titles"]) {
            if ([[intelligence objectForKey:@"title"] intValue] <= 0 &&
                [[story objectForKey:@"story_title"] containsString:title]) {
                int score = [[[classifiers objectForKey:@"titles"] objectForKey:title] intValue];
                [intelligence setObject:[NSNumber numberWithInt:score] forKey:@"title"];
            }
        }
        
        for (NSString *author in [classifiers objectForKey:@"authors"]) {
            if ([[intelligence objectForKey:@"author"] intValue] <= 0 &&
                [[story objectForKey:@"story_authors"] class] != [NSNull class] &&
                [[story objectForKey:@"story_authors"] containsString:author]) {
                int score = [[[classifiers objectForKey:@"authors"] objectForKey:author] intValue];
                [intelligence setObject:[NSNumber numberWithInt:score] forKey:@"author"];
            }
        }
        
        for (NSString *tag in [classifiers objectForKey:@"tags"]) {
            if ([[intelligence objectForKey:@"tags"] intValue] <= 0 &&
                [[story objectForKey:@"story_tags"] class] != [NSNull class] &&
                [[story objectForKey:@"story_tags"] containsObject:tag]) {
                int score = [[[classifiers objectForKey:@"tags"] objectForKey:tag] intValue];
                [intelligence setObject:[NSNumber numberWithInt:score] forKey:@"tags"];
            }
        }
        
        for (NSString *feed in [classifiers objectForKey:@"feeds"]) {
            if ([[intelligence objectForKey:@"feed"] intValue] <= 0 &&
                [storyFeedId isEqualToString:feed]) {
                int score = [[[classifiers objectForKey:@"feeds"] objectForKey:feed] intValue];
                [intelligence setObject:[NSNumber numberWithInt:score] forKey:@"feed"];
            }
        }
        
        [newStory setObject:intelligence forKey:@"intelligence"];
        [newFeedStories addObject:newStory];
    }
    
    self.activeFeedStories = newFeedStories;
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
        if ([self.activeFolder isEqualToString:@"river_blurblogs"]) {
            feedTitle = @"All Shared Stories";
        } else if ([self.activeFolder isEqualToString:@"river_global"]) {
            feedTitle = @"Global Shared Stories";
        } else if ([self.activeFolder isEqualToString:@"everything"]) {
            feedTitle = @"All Stories";
        } else if ([self.activeFolder isEqualToString:@"saved_stories"]) {
            feedTitle = @"Saved Stories";
        } else {
            feedTitle = self.activeFolder;
        }
    } else {
        feedTitle = [activeFeed objectForKey:@"feed_title"];
    }
    
    int activeStoryLocation = [self locationOfActiveStory];
    if (activeStoryLocation >= 0) {
        BOOL animated = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
                         !self.tryFeedCategory);
        [self.storyPageControl changePage:activeStoryLocation animated:animated];
        //        [self.storyPageControl updatePageWithActiveStory:activeStoryLocation];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle:feedTitle style: UIBarButtonItemStyleBordered target: nil action: nil];
        [feedDetailViewController.navigationItem setBackBarButtonItem: newBackButton];
        UINavigationController *navController = self.navigationController;
        [navController pushViewController:storyPageControl animated:YES];
        [navController.navigationItem setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:feedTitle style:UIBarButtonItemStyleBordered target:nil action:nil]];
        navController.navigationItem.hidesBackButton = YES;
    }
    
}

- (void)navigationController:(UINavigationController *)navController 
      willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
         [viewController viewWillAppear:animated];
    }
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [viewController viewDidAppear:animated];
    }    
}

- (void)setTitle:(NSString *)title {
    UILabel *label = [[UILabel alloc] init];
    [label setFont:[UIFont boldSystemFontOfSize:16.0]];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setTextColor:UIColorFromRGB(0x404040)];
    [label setText:title];
    [label setShadowOffset:CGSizeMake(0, -1)];
    [label setShadowColor:UIColorFromRGB(0xFAFAFA)];
    [label sizeToFit];
    [navigationController.navigationBar.topItem setTitleView:label];
}

- (void)showOriginalStory:(NSURL *)url {
    self.activeOriginalStoryURL = url;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController presentViewController:originalStoryViewController animated:YES completion:nil];
    } else {
        [self.navigationController presentViewController:originalStoryViewController animated:YES completion:nil];
    }
}

- (void)closeOriginalStory {
    if (![self.presentedViewController isBeingDismissed]) {
        [originalStoryViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)hideStoryDetailView {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController transitionFromFeedDetail];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (int)indexOfNextUnreadStory {
    int location = [self locationOfNextUnreadStory];
    return [self indexFromLocation:location];
}

- (int)locationOfNextUnreadStory {
    int activeLocation = [self locationOfActiveStory];
    int readStatus = -1;
    for (int i=activeLocation+1; i < [self.activeFeedStoryLocations count]; i++) {
        int storyIndex = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
        NSDictionary *story = [activeFeedStories objectAtIndex:storyIndex];
        readStatus = [[story objectForKey:@"read_status"] intValue];
        if (readStatus == 0) {
            return i;
        }
    }
    if (activeLocation > 0) {
        for (int i=activeLocation-1; i >= 0; i--) {
            int storyIndex = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
            NSDictionary *story = [activeFeedStories objectAtIndex:storyIndex];
            readStatus = [[story objectForKey:@"read_status"] intValue];
            if (readStatus == 0) {
                return i;
            }
        }
    }
    return -1;
}

- (int)indexOfNextStory {
    int location = [self locationOfNextStory];
    return [self indexFromLocation:location];
}

- (int)locationOfNextStory {
    int activeLocation = [self locationOfActiveStory];
    int nextStoryLocation = activeLocation + 1;
    if (nextStoryLocation < [self.activeFeedStoryLocations count]) {
        return nextStoryLocation;
    }
    return -1;
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

- (int)indexOfStoryId:(id)storyId {
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [activeFeedStories objectAtIndex:i];
        if ([story objectForKey:@"id"] == storyId) {
            return i;
        }
    }
    return -1;
}

- (int)locationOfStoryId:(id)storyId {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([activeFeedStoryLocationIds objectAtIndex:i] == storyId) {
            return i;
        }
    }
    return -1;
}

- (int)locationOfActiveStory {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([[activeFeedStoryLocationIds objectAtIndex:i]
             isEqualToString:[self.activeStory objectForKey:@"id"]]) {
            return i;
        }
    }
    return -1;
}

- (int)indexFromLocation:(int)location {
    if (location == -1) return -1;
    return [[activeFeedStoryLocations objectAtIndex:location] intValue];
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

- (int)unreadCount {
    if (self.isRiverView || self.isSocialRiverView) {
        return [self unreadCountForFolder:nil];
    } else { 
        return [self unreadCountForFeed:nil];
    }
}

- (int)allUnreadCount {
    int total = 0;
    for (id key in self.dictSocialFeeds) {
        NSDictionary *feed = [self.dictSocialFeeds objectForKey:key];
        total += [[feed objectForKey:@"ps"] intValue];
        total += [[feed objectForKey:@"nt"] intValue];
        NSLog(@"feed title and number is %@ %i", [feed objectForKey:@"feed_title"], ([[feed objectForKey:@"ps"] intValue] + [[feed objectForKey:@"nt"] intValue]));
        NSLog(@"total is %i", total);
    }
    
    for (id key in self.dictFeeds) {
        NSDictionary *feed = [self.dictFeeds objectForKey:key];
        total += [[feed objectForKey:@"ps"] intValue];
        total += [[feed objectForKey:@"nt"] intValue];
        NSLog(@"feed title and number is %@ %i", [feed objectForKey:@"feed_title"], ([[feed objectForKey:@"ps"] intValue] + [[feed objectForKey:@"nt"] intValue]));
        NSLog(@"total is %i", total);
    }

    return total;
}

- (int)unreadCountForFeed:(NSString *)feedId {
    int total = 0;
    NSDictionary *feed;

    if (feedId) {
        NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
        if ([feedIdStr containsString:@"social:"]) {
            feed = [self.dictSocialFeeds objectForKey:feedIdStr];
        } else {
            feed = [self.dictFeeds objectForKey:feedIdStr];
        }

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
    
    if ([folderName isEqual:@"river_blurblogs"] ||
        (!folderName && [self.activeFolder isEqual:@"river_blurblogs"])) {
        for (id feedId in self.dictSocialFeeds) {
            total += [self unreadCountForFeed:feedId];
        }
    } else if ([folderName isEqual:@"river_global"] ||
               (!folderName && [self.activeFolder isEqual:@"river_global"])) {
        total = 0;
    } else if ([folderName isEqual:@"everything"] ||
               (!folderName && [self.activeFolder isEqual:@"everything"])) {
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


- (UnreadCounts *)splitUnreadCountForFeed:(NSString *)feedId {
    UnreadCounts *counts = [UnreadCounts alloc];
    NSDictionary *feed;
    
    if (feedId) {
        NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
        if ([feedIdStr containsString:@"social:"]) {
            feed = [self.dictSocialFeeds objectForKey:feedIdStr];
        } else {
            feed = [self.dictFeeds objectForKey:feedIdStr];
        }
        
    } else {
        feed = self.activeFeed;
    }
    
    counts.ps += [[feed objectForKey:@"ps"] intValue];
    counts.nt += [[feed objectForKey:@"nt"] intValue];
    counts.ng += [[feed objectForKey:@"ng"] intValue];
    
    return counts;
}

- (UnreadCounts *)splitUnreadCountForFolder:(NSString *)folderName {
    UnreadCounts *counts = [UnreadCounts alloc];
    NSArray *folder;
    
    if ([[self.folderCountCache objectForKey:folderName] boolValue]) {
        counts.ps = [[self.folderCountCache objectForKey:[NSString stringWithFormat:@"%@-ps", folderName]] intValue];
        counts.nt = [[self.folderCountCache objectForKey:[NSString stringWithFormat:@"%@-nt", folderName]] intValue];
        counts.ng = [[self.folderCountCache objectForKey:[NSString stringWithFormat:@"%@-ng", folderName]] intValue];
        return counts;
    }
    
    if ([folderName isEqual:@"river_blurblogs"] ||
        (!folderName && [self.activeFolder isEqual:@"river_blurblogs"])) {
        for (id feedId in self.dictSocialFeeds) {
            [counts addCounts:[self splitUnreadCountForFeed:feedId]];
        }
    } else if ([folderName isEqual:@"river_global"] ||
            (!folderName && [self.activeFolder isEqual:@"river_global"])) {
        // Nothing for global
    } else if ([folderName isEqual:@"everything"] ||
               (!folderName && [self.activeFolder isEqual:@"everything"])) {
        for (NSArray *folder in [self.dictFolders allValues]) {
            for (id feedId in folder) {
                [counts addCounts:[self splitUnreadCountForFeed:feedId]];
            }
        }
    } else {
        if (!folderName) {
            folder = [self.dictFolders objectForKey:self.activeFolder];
        } else {
            folder = [self.dictFolders objectForKey:folderName];
        }
        
        for (id feedId in folder) {
            [counts addCounts:[self splitUnreadCountForFeed:feedId]];
        }
    }
    
    if (!self.folderCountCache) {
        self.folderCountCache = [[NSMutableDictionary alloc] init];
    }
    [self.folderCountCache setObject:[NSNumber numberWithBool:YES] forKey:folderName];
    [self.folderCountCache setObject:[NSNumber numberWithInt:counts.ps] forKey:[NSString stringWithFormat:@"%@-ps", folderName]];
    [self.folderCountCache setObject:[NSNumber numberWithInt:counts.nt] forKey:[NSString stringWithFormat:@"%@-nt", folderName]];
    [self.folderCountCache setObject:[NSNumber numberWithInt:counts.ng] forKey:[NSString stringWithFormat:@"%@-ng", folderName]];
        
    return counts;
}

- (void)addStories:(NSArray *)stories {
    self.activeFeedStories = [self.activeFeedStories arrayByAddingObjectsFromArray:stories];
    self.storyCount = [self.activeFeedStories count];
    [self calculateStoryLocations];
    self.storyLocationsCount = [self.activeFeedStoryLocations count];
}

- (void)setStories:(NSArray *)activeFeedStoriesValue {
    self.activeFeedStories = activeFeedStoriesValue;
    self.storyCount = [self.activeFeedStories count];
    self.recentlyReadStories = [NSMutableArray array];
    self.recentlyReadFeeds = [NSMutableSet set];
    [self calculateStoryLocations];
    self.storyLocationsCount = [self.activeFeedStoryLocations count];
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
    
    // changes the story layout in story feed detail
    [self.feedDetailViewController changeActiveStoryTitleCellLayout];
 
    int activeIndex = [[activeFeedStoryLocations objectAtIndex:activeLocation] intValue];
    
    NSDictionary *feed;
    NSDictionary *friendFeed;
    id feedId;
    NSString *feedIdStr;
    NSDictionary *story = [activeFeedStories objectAtIndex:activeIndex];
    NSMutableArray *otherFriendShares = [[self.activeStory objectForKey:@"shared_by_friends"] mutableCopy];
    NSMutableArray *otherFriendComments = [[self.activeStory objectForKey:@"commented_by_friends"] mutableCopy];
    
    if (self.isSocialView) {
        feedId = [self.activeStory objectForKey:@"social_user_id"];
        feedIdStr = [NSString stringWithFormat:@"social:%@",feedId];        
        feed = [self.dictSocialFeeds objectForKey:feedIdStr];
        
        [otherFriendShares removeObject:feedId];
        NSLog(@"otherFriendFeeds is %@", otherFriendShares);
        [otherFriendComments removeObject:feedId];
        NSLog(@"otherFriendFeeds is %@", otherFriendComments);
        
        // make sure we set the active feed
        self.activeFeed = feed;
    } else if (self.isSocialRiverView) {
        if ([[self.activeStory objectForKey:@"friend_user_ids"] count]) {
            feedId = [[self.activeStory objectForKey:@"friend_user_ids"] objectAtIndex:0];
            feedIdStr = [NSString stringWithFormat:@"social:%@",feedId];
            feed = [self.dictSocialFeeds objectForKey:feedIdStr];
        
            [otherFriendShares removeObject:feedId];
            NSLog(@"otherFriendFeeds is %@", otherFriendShares);
            [otherFriendComments removeObject:feedId];
            NSLog(@"otherFriendFeeds is %@", otherFriendComments);
        
            // make sure we set the active feed
            self.activeFeed = feed;
        }
    } else {
        feedId = [self.activeStory objectForKey:@"story_feed_id"];
        feedIdStr = [NSString stringWithFormat:@"%@",feedId];
        feed = [self.dictFeeds objectForKey:feedIdStr];
        
        // make sure we set the active feed
        self.activeFeed = feed;
    }
    
    // decrement all other friend feeds if they have the same story
    if (self.isSocialView || self.isSocialRiverView) {
        for (int i = 0; i < otherFriendShares.count; i++) {
            feedIdStr = [NSString stringWithFormat:@"social:%@",
                         [otherFriendShares objectAtIndex:i]];   
            friendFeed = [self.dictSocialFeeds objectForKey:feedIdStr];
            [self markStoryRead:story feed:friendFeed];
        }
        
        for (int i = 0; i < otherFriendComments.count; i++) {
            feedIdStr = [NSString stringWithFormat:@"social:%@",
                         [otherFriendComments objectAtIndex:i]];   
            friendFeed = [self.dictSocialFeeds objectForKey:feedIdStr];
            [self markStoryRead:story feed:friendFeed];
        }
    }

    [self.recentlyReadStories addObject:[NSNumber numberWithInt:activeLocation]];
    [self markStoryRead:story feed:feed];
    self.activeStory = [self.activeFeedStories objectAtIndex:activeIndex];
}

- (void)markActiveStoryUnread {
    int activeLocation = [self locationOfActiveStory];
    if (activeLocation == -1) {
        return;
    }
    
    // changes the story layout in story feed detail
    [self.feedDetailViewController changeActiveStoryTitleCellLayout];
    
    int activeIndex = [[activeFeedStoryLocations objectAtIndex:activeLocation] intValue];
    
    NSDictionary *feed;
    NSDictionary *friendFeed;
    id feedId;
    NSString *feedIdStr;
    NSDictionary *story = [activeFeedStories objectAtIndex:activeIndex];
    NSMutableArray *otherFriendShares = [[self.activeStory objectForKey:@"shared_by_friends"] mutableCopy];
    NSMutableArray *otherFriendComments = [[self.activeStory objectForKey:@"commented_by_friends"] mutableCopy];
    
    if (self.isSocialView) {
        feedId = [self.activeStory objectForKey:@"social_user_id"];
        feedIdStr = [NSString stringWithFormat:@"social:%@",feedId];
        feed = [self.dictSocialFeeds objectForKey:feedIdStr];
        
        [otherFriendShares removeObject:feedId];
        NSLog(@"otherFriendFeeds is %@", otherFriendShares);
        [otherFriendComments removeObject:feedId];
        NSLog(@"otherFriendFeeds is %@", otherFriendComments);
        
        // make sure we set the active feed
        self.activeFeed = feed;
    } else if (self.isSocialRiverView) {
        feedId = [[self.activeStory objectForKey:@"friend_user_ids"] objectAtIndex:0];
        feedIdStr = [NSString stringWithFormat:@"social:%@",feedId];
        feed = [self.dictSocialFeeds objectForKey:feedIdStr];
        
        [otherFriendShares removeObject:feedId];
        NSLog(@"otherFriendFeeds is %@", otherFriendShares);
        [otherFriendComments removeObject:feedId];
        NSLog(@"otherFriendFeeds is %@", otherFriendComments);
        
        // make sure we set the active feed
        self.activeFeed = feed;
    } else {
        feedId = [self.activeStory objectForKey:@"story_feed_id"];
        feedIdStr = [NSString stringWithFormat:@"%@",feedId];
        feed = [self.dictFeeds objectForKey:feedIdStr];
        
        // make sure we set the active feed
        self.activeFeed = feed;
    }
    
    // decrement all other friend feeds if they have the same story
    if (self.isSocialView || self.isSocialRiverView) {
        for (int i = 0; i < otherFriendShares.count; i++) {
            feedIdStr = [NSString stringWithFormat:@"social:%@",
                         [otherFriendShares objectAtIndex:i]];
            friendFeed = [self.dictSocialFeeds objectForKey:feedIdStr];
            [self markStoryUnread:story feed:friendFeed];
        }
        
        for (int i = 0; i < otherFriendComments.count; i++) {
            feedIdStr = [NSString stringWithFormat:@"social:%@",
                         [otherFriendComments objectAtIndex:i]];
            friendFeed = [self.dictSocialFeeds objectForKey:feedIdStr];
            [self markStoryUnread:story feed:friendFeed];
        }
    }
    
    [self.recentlyReadStories removeObject:[NSNumber numberWithInt:activeLocation]];
    [self markStoryUnread:story feed:feed];

    self.activeStory = [self.activeFeedStories objectAtIndex:activeIndex];
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
    
    NSMutableDictionary *newStory = [story mutableCopy];
    [newStory setValue:[NSNumber numberWithInt:1] forKey:@"read_status"];
    
    // make the story as read in self.activeFeedStories
    NSString *newStoryIdStr = [NSString stringWithFormat:@"%@", [newStory valueForKey:@"id"]];
    NSMutableArray *newActiveFeedStories = [self.activeFeedStories mutableCopy];
    for (int i = 0; i < [newActiveFeedStories count]; i++) {
        NSMutableArray *thisStory = [[newActiveFeedStories objectAtIndex:i] mutableCopy];
        NSString *thisStoryIdStr = [NSString stringWithFormat:@"%@", [thisStory valueForKey:@"id"]];
        if ([newStoryIdStr isEqualToString:thisStoryIdStr]) {
            [newActiveFeedStories replaceObjectAtIndex:i withObject:newStory];
            break;
        }
    }
    self.activeFeedStories = newActiveFeedStories;
    
    [self.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSString *storyHash = [newStory objectForKey:@"story_hash"];
        [db executeUpdate:@"UPDATE stories SET story_json = ? WHERE story_hash = ?",
         [newStory JSONRepresentation],
         storyHash];
        [db executeUpdate:@"DELETE FROM unread_hashes WHERE story_hash = ?",
         storyHash];
    }];
    
    self.visibleUnreadCount -= 1;
    if (![self.recentlyReadFeeds containsObject:[newStory objectForKey:@"story_feed_id"]]) {
        [self.recentlyReadFeeds addObject:[newStory objectForKey:@"story_feed_id"]];
    }
    
    NSMutableDictionary *newFeed = [feed mutableCopy];
    int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    if (score > 0) {
        int unreads = MAX(0, [[newFeed objectForKey:@"ps"] intValue] - 1);
        [newFeed setValue:[NSNumber numberWithInt:unreads] forKey:@"ps"];
    } else if (score == 0) {
        int unreads = MAX(0, [[newFeed objectForKey:@"nt"] intValue] - 1);
        [newFeed setValue:[NSNumber numberWithInt:unreads] forKey:@"nt"];
    } else if (score < 0) {
        int unreads = MAX(0, [[newFeed objectForKey:@"ng"] intValue] - 1);
        [newFeed setValue:[NSNumber numberWithInt:unreads] forKey:@"ng"];
    }
    
    if (self.isSocialView || self.isSocialRiverView) {
        [self.dictSocialFeeds setValue:newFeed forKey:feedIdStr];
    } else {
        [self.dictFeeds setValue:newFeed forKey:feedIdStr];
    }
    
    self.activeFeed = newFeed;
}


- (void)markStoryUnread:(NSString *)storyId feedId:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
    NSDictionary *story = nil;
    for (NSDictionary *s in self.activeFeedStories) {
        if ([[s objectForKey:@"story_guid"] isEqualToString:storyId]) {
            story = s;
            break;
        }
    }
    [self markStoryUnread:story feed:feed];
}

- (void)markStoryUnread:(NSDictionary *)story feed:(NSDictionary *)feed {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
    
    NSMutableDictionary *newStory = [story mutableCopy];
    [newStory setValue:[NSNumber numberWithInt:0] forKey:@"read_status"];
    
    // make the story as read in self.activeFeedStories
    NSString *newStoryIdStr = [NSString stringWithFormat:@"%@", [newStory valueForKey:@"id"]];
    NSMutableArray *newActiveFeedStories = [self.activeFeedStories mutableCopy];
    for (int i = 0; i < [newActiveFeedStories count]; i++) {
        NSMutableArray *thisStory = [[newActiveFeedStories objectAtIndex:i] mutableCopy];
        NSString *thisStoryIdStr = [NSString stringWithFormat:@"%@", [thisStory valueForKey:@"id"]];
        if ([newStoryIdStr isEqualToString:thisStoryIdStr]) {
            [newActiveFeedStories replaceObjectAtIndex:i withObject:newStory];
            break;
        }
    }
    self.activeFeedStories = newActiveFeedStories;
    
    self.visibleUnreadCount += 1;
//    if ([self.recentlyReadFeeds containsObject:[newStory objectForKey:@"story_feed_id"]]) {
        [self.recentlyReadFeeds removeObject:[newStory objectForKey:@"story_feed_id"]];
//    }
    
    NSMutableDictionary *newFeed = [feed mutableCopy];
    int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    if (score > 0) {
        int unreads = MAX(1, [[newFeed objectForKey:@"ps"] intValue] + 1);
        [newFeed setValue:[NSNumber numberWithInt:unreads] forKey:@"ps"];
    } else if (score == 0) {
        int unreads = MAX(1, [[newFeed objectForKey:@"nt"] intValue] + 1);
        [newFeed setValue:[NSNumber numberWithInt:unreads] forKey:@"nt"];
    } else if (score < 0) {
        int unreads = MAX(1, [[newFeed objectForKey:@"ng"] intValue] + 1);
        [newFeed setValue:[NSNumber numberWithInt:unreads] forKey:@"ng"];
    }
    
    if (self.isSocialView || self.isSocialRiverView) {
        [self.dictSocialFeeds setValue:newFeed forKey:feedIdStr];
    } else {
        [self.dictFeeds setValue:newFeed forKey:feedIdStr];
    }
    
    self.activeFeed = newFeed;
}

- (void)markActiveStorySaved:(BOOL)saved {
    NSMutableDictionary *newStory = [self.activeStory mutableCopy];
    [newStory setValue:[NSNumber numberWithBool:saved] forKey:@"starred"];
    
    self.activeStory = newStory;
    
    // make the story as read in self.activeFeedStories
    NSString *newStoryIdStr = [NSString stringWithFormat:@"%@", [newStory valueForKey:@"id"]];
    NSMutableArray *newActiveFeedStories = [self.activeFeedStories mutableCopy];
    for (int i = 0; i < [newActiveFeedStories count]; i++) {
        NSMutableArray *thisStory = [[newActiveFeedStories objectAtIndex:i] mutableCopy];
        NSString *thisStoryIdStr = [NSString stringWithFormat:@"%@", [thisStory valueForKey:@"id"]];
        if ([newStoryIdStr isEqualToString:thisStoryIdStr]) {
            [newActiveFeedStories replaceObjectAtIndex:i withObject:newStory];
            break;
        }
    }
    self.activeFeedStories = newActiveFeedStories;
    
    if (saved) {
        self.savedStoriesCount += 1;
    } else {
        self.savedStoriesCount -= 1;
    }
}

- (void)markActiveFeedAllRead {
    id feedId = [self.activeFeed objectForKey:@"id"];
    [self markFeedAllRead:feedId];
}

- (void)markActiveFolderAllRead {
    if ([self.activeFolder isEqual:@"everything"]) {
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
    NSMutableDictionary *feed = self.isSocialView ? [[self.dictSocialFeeds objectForKey:feedIdStr] mutableCopy] : [[self.dictFeeds objectForKey:feedIdStr] mutableCopy];
    
    [feed setValue:[NSNumber numberWithInt:0] forKey:@"ps"];
    [feed setValue:[NSNumber numberWithInt:0] forKey:@"nt"];
    [feed setValue:[NSNumber numberWithInt:0] forKey:@"ng"];
    if (self.isSocialView) {
        [self.dictSocialFeeds setValue:feed forKey:feedIdStr];    
    } else {
        [self.dictFeeds setValue:feed forKey:feedIdStr];    
    }
}

- (void)calculateStoryLocations {
    self.visibleUnreadCount = 0;
    self.activeFeedStoryLocations = [NSMutableArray array];
    self.activeFeedStoryLocationIds = [NSMutableArray array];
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [self.activeFeedStories objectAtIndex:i];
        int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
        if (score >= self.selectedIntelligence || [[story objectForKey:@"sticky"] boolValue]) {
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
    if ([folderName containsString:@"Top Level"] ||
        [folderName isEqual:@"everything"]) {
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
    if ([folderName containsString:@"Top Level"] ||
        [folderName isEqual:@"everything"]) {
        folderName = @"";
    }
    if ([folderName containsString:@" - "]) {
        int folder_loc = [folderName rangeOfString:@" - " options:NSBackwardsSearch].location;
        folderName = [folderName substringFromIndex:(folder_loc + 3)];
    }
    
    return folderName;
}

- (NSDictionary *)getFeed:(NSString *)feedId {
    NSDictionary *feed;
    if (self.isSocialView || self.isSocialRiverView) {
        feed = [self.dictActiveFeeds objectForKey:feedId];
        // this is to catch when a user is already subscribed
        if (!feed) {
            feed = [self.dictFeeds objectForKey:feedId];
        }
    } else {
        feed = [self.dictFeeds objectForKey:feedId];
    }
    
    return feed;
}

#pragma mark -
#pragma mark Feed Templates

+ (void)fillGradient:(CGRect)r startColor:(UIColor *)startColor endColor:(UIColor *)endColor {
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIGraphicsPushContext(context);
    
    CGGradientRef gradient;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[2] = {0.0f, 1.0f};
    CGFloat startRed, startGreen, startBlue, startAlpha;
    CGFloat endRed, endGreen, endBlue, endAlpha;
    
    [startColor getRed:&startRed green:&startGreen blue:&startBlue alpha:&startAlpha];
    [endColor getRed:&endRed green:&endGreen blue:&endBlue alpha:&endAlpha];
    
    CGFloat components[8] = {
        startRed, startGreen, startBlue, startAlpha,
        endRed, endGreen, endBlue, endAlpha
    };
    gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
    CGColorSpaceRelease(colorSpace);
    
    CGPoint startPoint = CGPointMake(CGRectGetMinX(r), r.origin.y);
    CGPoint endPoint = CGPointMake(startPoint.x, r.origin.y + r.size.height);
    
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGGradientRelease(gradient);
    UIGraphicsPopContext();
}

+ (UIView *)makeGradientView:(CGRect)rect startColor:(NSString *)start endColor:(NSString *)end {
    UIView *gradientView = [[UIView alloc] initWithFrame:rect];
    
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
    if (self.isRiverView || self.isSocialView || self.isSocialRiverView) {
        gradientView = [NewsBlurAppDelegate 
                        makeGradientView:rect
                        startColor:[feed objectForKey:@"favicon_fade"] 
                        endColor:[feed objectForKey:@"favicon_color"]];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = [feed objectForKey:@"feed_title"];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textAlignment = NSTextAlignmentLeft;
        titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
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
        
        [gradientView addSubview:titleLabel];
        [gradientView addSubview:titleImageView];
    } else {
        gradientView = [NewsBlurAppDelegate 
                        makeGradientView:CGRectMake(0, -1, rect.size.width, 10)
                        // hard coding the 1024 as a hack for window.frame.size.width
                        startColor:[feed objectForKey:@"favicon_fade"] 
                        endColor:[feed objectForKey:@"favicon_color"]];
    }
    
    gradientView.opaque = YES;
    
    return gradientView;
}

- (UIView *)makeFeedTitle:(NSDictionary *)feed {
    UILabel *titleLabel = [[UILabel alloc] init];
    if (self.isSocialRiverView && [self.activeFolder isEqualToString:@"river_blurblogs"]) {
        titleLabel.text = [NSString stringWithFormat:@"     All Shared Stories"];
    } else if (self.isSocialRiverView && [self.activeFolder isEqualToString:@"river_global"]) {
            titleLabel.text = [NSString stringWithFormat:@"     Global Shared Stories"];
    } else if (self.isRiverView && [self.activeFolder isEqualToString:@"everything"]) {
        titleLabel.text = [NSString stringWithFormat:@"     All Stories"];
    } else if (self.isRiverView && [self.activeFolder isEqualToString:@"saved_stories"]) {
        titleLabel.text = [NSString stringWithFormat:@"     Saved Stories"];
    } else if (self.isRiverView) {
        titleLabel.text = [NSString stringWithFormat:@"     %@", self.activeFolder];
    } else if (self.isSocialView) {
        titleLabel.text = [NSString stringWithFormat:@"     %@", [feed objectForKey:@"feed_title"]];
    } else {
        titleLabel.text = [NSString stringWithFormat:@"     %@", [feed objectForKey:@"feed_title"]];
    }
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:15.0];
    titleLabel.textColor = UIColorFromRGB(0x404040);
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.numberOfLines = 1;
    titleLabel.shadowColor = UIColorFromRGB(0xF5F5F5);
    titleLabel.shadowOffset = CGSizeMake(0, -1);
    titleLabel.center = CGPointMake(0, -2);
    [titleLabel sizeToFit];
    
    if (!self.isSocialView) {
        titleLabel.center = CGPointMake(28, -2);
        NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
        UIImage *titleImage;
        if (self.isSocialRiverView && [self.activeFolder isEqualToString:@"river_global"]) {
            titleImage = [UIImage imageNamed:@"ak-icon-global.png"];
        } else if (self.isSocialRiverView && [self.activeFolder isEqualToString:@"river_blurblogs"]) {
            titleImage = [UIImage imageNamed:@"ak-icon-blurblogs.png"];
        } else if (self.isRiverView && [self.activeFolder isEqualToString:@"everything"]) {
            titleImage = [UIImage imageNamed:@"ak-icon-allstories.png"];
        } else if (self.isRiverView && [self.activeFolder isEqualToString:@"saved_stories"]) {
            titleImage = [UIImage imageNamed:@"clock.png"];
        } else if (self.isRiverView) {
            titleImage = [UIImage imageNamed:@"g_icn_folder.png"];
        } else {
            titleImage = [Utilities getImage:feedIdStr];
        }
        UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
        titleImageView.frame = CGRectMake(0.0, 2.0, 16.0, 16.0);
        [titleLabel addSubview:titleImageView];
    }
    return titleLabel;
}

- (UIButton *)makeRightFeedTitle:(NSDictionary *)feed {
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
    UIImage *titleImage  = [Utilities getImage:feedIdStr];

    titleImage = [Utilities roundCorneredImage:titleImage radius:6];
    
    UIButton *titleImageButton = [UIButton buttonWithType:UIButtonTypeCustom];
    titleImageButton.bounds = CGRectMake(0, 0, 32, 32);

    [titleImageButton setImage:titleImage forState:UIControlStateNormal];
    return titleImageButton;
}

#pragma mark -
#pragma mark Classifiers

- (void)toggleAuthorClassifier:(NSString *)author feedId:(NSString *)feedId {
    int authorScore = [[[[self.activeClassifiers objectForKey:feedId]
                         objectForKey:@"authors"]
                        objectForKey:author] intValue];
    if (authorScore > 0) {
        authorScore = -1;
    } else if (authorScore < 0) {
        authorScore = 0;
    } else {
        authorScore = 1;
    }
    NSMutableDictionary *feedClassifiers = [[self.activeClassifiers objectForKey:feedId]
                                            mutableCopy];
    NSMutableDictionary *authors = [[feedClassifiers objectForKey:@"authors"] mutableCopy];
    [authors setObject:[NSNumber numberWithInt:authorScore] forKey:author];
    [feedClassifiers setObject:authors forKey:@"authors"];
    [self.activeClassifiers setObject:feedClassifiers forKey:feedId];
    [self.storyPageControl refreshHeaders];
    [self.trainerViewController refresh];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/classifier/save",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:author
                   forKey:authorScore >= 1 ? @"like_author" :
                          authorScore <= -1 ? @"dislike_author" :
                          @"remove_like_author"];
    [request setPostValue:feedId forKey:@"feed_id"];
    [request setCompletionBlock:^{
        [self.feedsViewController refreshFeedList:feedId];
    }];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
    
    [self recalculateIntelligenceScores:feedId];
    [self.feedDetailViewController.storyTitlesTable reloadData];
}

- (void)toggleTagClassifier:(NSString *)tag feedId:(NSString *)feedId {
    NSLog(@"toggleTagClassifier: %@", tag);
    int tagScore = [[[[self.activeClassifiers objectForKey:feedId]
                      objectForKey:@"tags"]
                     objectForKey:tag] intValue];
    
    if (tagScore > 0) {
        tagScore = -1;
    } else if (tagScore < 0) {
        tagScore = 0;
    } else {
        tagScore = 1;
    }
    
    NSMutableDictionary *feedClassifiers = [[self.activeClassifiers objectForKey:feedId]
                                            mutableCopy];
    NSMutableDictionary *tags = [[feedClassifiers objectForKey:@"tags"] mutableCopy];
    [tags setObject:[NSNumber numberWithInt:tagScore] forKey:tag];
    [feedClassifiers setObject:tags forKey:@"tags"];
    [self.activeClassifiers setObject:feedClassifiers forKey:feedId];
    [self.storyPageControl refreshHeaders];
    [self.trainerViewController refresh];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/classifier/save",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:tag
                   forKey:tagScore >= 1 ? @"like_tag" :
                          tagScore <= -1 ? @"dislike_tag" :
                          @"remove_like_tag"];
    [request setPostValue:feedId forKey:@"feed_id"];
    [request setCompletionBlock:^{
        [self.feedsViewController refreshFeedList:feedId];
    }];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
    
    [self recalculateIntelligenceScores:feedId];
    [self.feedDetailViewController.storyTitlesTable reloadData];
}

- (void)toggleTitleClassifier:(NSString *)title feedId:(NSString *)feedId score:(int)score {
    NSLog(@"toggle Title: %@ (%@) / %d", title, feedId, score);
    int titleScore = [[[[self.activeClassifiers objectForKey:feedId]
                        objectForKey:@"titles"]
                       objectForKey:title] intValue];
    
    if (score) {
        titleScore = score;
    } else {
        if (titleScore > 0) {
            titleScore = -1;
        } else if (titleScore < 0) {
            titleScore = 0;
        } else {
            titleScore = 1;
        }
    }
    
    NSMutableDictionary *feedClassifiers = [[self.activeClassifiers objectForKey:feedId]
                                            mutableCopy];
    NSMutableDictionary *titles = [[feedClassifiers objectForKey:@"titles"] mutableCopy];
    [titles setObject:[NSNumber numberWithInt:titleScore] forKey:title];
    [feedClassifiers setObject:titles forKey:@"titles"];
    [self.activeClassifiers setObject:feedClassifiers forKey:feedId];
    [self.storyPageControl refreshHeaders];
    [self.trainerViewController refresh];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/classifier/save",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:title
                   forKey:titleScore >= 1 ? @"like_title" :
                          titleScore <= -1 ? @"dislike_title" :
                          @"remove_like_title"];
    [request setPostValue:feedId forKey:@"feed_id"];
    [request setCompletionBlock:^{
        [self.feedsViewController refreshFeedList:feedId];
    }];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
    
    [self recalculateIntelligenceScores:feedId];
    [self.feedDetailViewController.storyTitlesTable reloadData];
}

- (void)toggleFeedClassifier:(NSString *)feedId {
    int feedScore = [[[[self.activeClassifiers objectForKey:feedId]
                       objectForKey:@"feeds"]
                      objectForKey:feedId] intValue];
    
    if (feedScore > 0) {
        feedScore = -1;
    } else if (feedScore < 0) {
        feedScore = 0;
    } else {
        feedScore = 1;
    }
    
    NSMutableDictionary *feedClassifiers = [[self.activeClassifiers objectForKey:feedId]
                                            mutableCopy];
    NSMutableDictionary *feeds = [[feedClassifiers objectForKey:@"feeds"] mutableCopy];
    [feeds setObject:[NSNumber numberWithInt:feedScore] forKey:feedId];
    [feedClassifiers setObject:feeds forKey:@"feeds"];
    [self.activeClassifiers setObject:feedClassifiers forKey:feedId];
    [self.storyPageControl refreshHeaders];
    [self.trainerViewController refresh];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/classifier/save",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:feedId
                   forKey:feedScore >= 1 ? @"like_feed" :
                          feedScore <= -1 ? @"dislike_feed" :
                          @"remove_like_feed"];
    [request setPostValue:feedId forKey:@"feed_id"];
    [request setCompletionBlock:^{
        [self.feedsViewController refreshFeedList:feedId];
    }];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
    
    [self recalculateIntelligenceScores:feedId];
    [self.feedDetailViewController.storyTitlesTable reloadData];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
    [self informError:error];
}

#pragma mark -
#pragma mark Storing Stories for Offline

- (int)databaseSchemaVersion:(FMDatabase *)db {
    int version = 0;
    FMResultSet *resultSet = [db executeQuery:@"PRAGMA user_version"];
    if ([resultSet next]) {
        version = [resultSet intForColumnIndex:0];
    }
    return version;
}

- (void)createDatabaseConnection {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *docsPath = [paths objectAtIndex:0];
    NSString *dbName = [NSString stringWithFormat:@"%@.sqlite", NEWSBLUR_HOST];
    NSString *path = [docsPath stringByAppendingPathComponent:dbName];
    
    database = [FMDatabaseQueue databaseQueueWithPath:path];
    [database inDatabase:^(FMDatabase *db) {
        [self setupDatabase:db];
    }];
}

- (void)setupDatabase:(FMDatabase *)db {
    if ([self databaseSchemaVersion:db] < CURRENT_DB_VERSION) {
        // FMDB cannot execute this query because FMDB tries to use prepared statements
        [db executeQuery:@"drop table if exists `stories`"];
        [db executeQuery:@"drop table if exists `unread_hashes`"];
        //        [db executeQuery:@"drop table if exists `queued_read_hashes`"];
        NSLog(@"Dropped db: %@", [db lastErrorMessage]);
        sqlite3_exec(db.sqliteHandle, [[NSString stringWithFormat:@"PRAGMA user_version = %d", CURRENT_DB_VERSION] UTF8String], NULL, NULL, NULL);
    }
    NSString *createFeedsTable = [NSString stringWithFormat:@"create table if not exists feeds "
                                  "("
                                  " username varchar(36),"
                                  " download_date date,"
                                  " feeds_json text,"
                                  " UNIQUE(username) ON CONFLICT REPLACE"
                                  ")"];
    [db executeUpdate:createFeedsTable];
    
    NSString *createStoryTable = [NSString stringWithFormat:@"create table if not exists stories "
                                  "("
                                  " story_feed_id number,"
                                  " story_hash varchar(24),"
                                  " story_timestamp number,"
                                  " story_json text,"
                                  " UNIQUE(story_hash) ON CONFLICT REPLACE"
                                  ")"];
    [db executeUpdate:createStoryTable];
    
    NSString *createUnreadHashTable = [NSString stringWithFormat:@"create table if not exists unread_hashes "
                                       "("
                                       " story_feed_id number,"
                                       " story_hash varchar(24),"
                                       " story_timestamp number,"
                                       " UNIQUE(story_hash) ON CONFLICT IGNORE"
                                       ")"];
    [db executeUpdate:createUnreadHashTable];
    
    NSString *createReadTable = [NSString stringWithFormat:@"create table if not exists queued_read_hashes "
                                 "("
                                 " story_feed_id number,"
                                 " story_hash varchar(24),"
                                 " UNIQUE(story_hash) ON CONFLICT IGNORE"
                                 ")"];
    [db executeUpdate:createReadTable];
    
    NSLog(@"Create db %d: %@", [db lastErrorCode], [db lastErrorMessage]);
}

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)fetchUnreadHashes {
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/reader/unread_story_hashes?include_timestamps=true",
                                       NEWSBLUR_URL]];
    ASIHTTPRequest *_request = [ASIHTTPRequest requestWithURL:url];
    __weak ASIHTTPRequest *request = _request;
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    [request setFailedBlock:^(void) {
        NSLog(@"Failed fetch all story hashes.");
    }];
    [request setCompletionBlock:^(void) {
        [self storeUnreadHashes:request];
    }];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.feedsViewController showSyncingNotifier];
    });
}

- (void)storeUnreadHashes:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSDictionary *results = [NSJSONSerialization
                             JSONObjectWithData:responseData
                             options:kNilOptions
                             error:&error];
    __block __typeof__(self) _self = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [_self.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            [db executeUpdate:@"DROP TABLE unread_hashes"];
            [_self setupDatabase:db];
            NSDictionary *hashes = [results objectForKey:@"unread_feed_story_hashes"];
            for (NSString *feed in [hashes allKeys]) {
                NSArray *story_hashes = [hashes objectForKey:feed];
                for (NSArray *story_hash_tuple in story_hashes) {
                    [db executeUpdate:@"INSERT into unread_hashes"
                     "(story_feed_id, story_hash, story_timestamp) VALUES "
                     "(?, ?, ?)",
                     feed,
                     [story_hash_tuple objectAtIndex:0],
                     [story_hash_tuple objectAtIndex:1]
                     ];
                }
            }
        }];
        
        _self.totalUnfetchedStoryCount = 0;
        _self.remainingUnfetchedStoryCount = 0;
        _self.latestFetchedStoryDate = 0;
        [_self fetchAllUnreadStories];
    });
}

- (NSArray *)unfetchedStoryHashes {
    NSMutableArray *hashes = [NSMutableArray array];
    
    [self.database inDatabase:^(FMDatabase *db) {
        NSString *commonQuery = @"FROM unread_hashes u "
                                 "LEFT OUTER JOIN stories s ON (s.story_hash = u.story_hash) "
                                 "WHERE s.story_hash IS NULL";
        int count = [db intForQuery:[NSString stringWithFormat:@"SELECT COUNT(1) %@", commonQuery]];
        if (self.totalUnfetchedStoryCount == 0) {
            self.totalUnfetchedStoryCount = count;
            self.remainingUnfetchedStoryCount = self.totalUnfetchedStoryCount;
        } else {
            self.remainingUnfetchedStoryCount = count;
        }
        
        int limit = 100;
        FMResultSet *cursor = [db executeQuery:[NSString stringWithFormat:@"SELECT u.story_hash %@ ORDER BY u.story_timestamp DESC LIMIT %d", commonQuery, limit]];
        
        while ([cursor next]) {
            [hashes addObject:[cursor objectForColumnName:@"story_hash"]];
        }
        int start = (int)[[NSDate date] timeIntervalSince1970];
        int end = self.latestFetchedStoryDate;
        int seconds = start - (end ? end : start);
        __block int hours = (int)round(seconds / 60.f / 60.f);
        
        __block float progress = 0.f;
        if (self.totalUnfetchedStoryCount) {
            progress = 1.f - ((float)self.remainingUnfetchedStoryCount /
                              (float)self.totalUnfetchedStoryCount);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.feedsViewController showSyncingNotifier:progress hoursBack:hours];
        });
    }];
    
    return hashes;
}

- (void)fetchAllUnreadStories {
    NSArray *hashes = [self unfetchedStoryHashes];
    
    if ([hashes count] == 0) {
        NSLog(@"Finished downloading unread stories. %d total", self.totalUnfetchedStoryCount);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.feedsViewController hideNotifier];
        });
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/reader/river_stories?page=0&h=%@",
                                       NEWSBLUR_URL, [hashes componentsJoinedByString:@"&h="]]];
    ASIHTTPRequest *_request = [ASIHTTPRequest requestWithURL:url];
    __weak ASIHTTPRequest *request = _request;
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    [request setFailedBlock:^(void) {
        NSLog(@"Failed fetch all unreads.");
    }];
    [request setCompletionBlock:^(void) {
        [self storeAllUnreadStories:request];
    }];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];
}

- (void)storeAllUnreadStories:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSDictionary *results = [NSJSONSerialization
                             JSONObjectWithData:responseData
                             options:kNilOptions
                             error:&error];
    __block BOOL anySuccess = NO;
    __block __typeof__(self) _self = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [_self.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            for (NSDictionary *story in [results objectForKey:@"stories"]) {
                BOOL inserted = [db executeUpdate:@"INSERT into stories"
                 "(story_feed_id, story_hash, story_timestamp, story_json) VALUES "
                 "(?, ?, ?, ?)",
                 [story objectForKey:@"story_feed_id"],
                 [story objectForKey:@"story_hash"],
                 [story objectForKey:@"story_timestamp"],
                 [story JSONRepresentation]
                 ];
                if (!anySuccess && inserted) anySuccess = YES;
            }
            if (anySuccess) {
                _self.latestFetchedStoryDate = [[[[results objectForKey:@"stories"] lastObject]
                                                 objectForKey:@"story_timestamp"] intValue];
            }
        }];
        
        if (anySuccess) {
            [_self fetchAllUnreadStories];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_self.feedsViewController hideNotifier];
            });
        }
    });
}

- (void)flushQueuedReadStories:(BOOL)forceCheck withCallback:(void(^)())callback {
    if (hasQueuedReadStories || forceCheck) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                 (unsigned long)NULL), ^(void) {
            [self.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
                NSMutableDictionary *hashes = [NSMutableDictionary dictionary];
                FMResultSet *stories = [db executeQuery:@"SELECT * FROM queued_read_hashes"];
                while ([stories next]) {
                    NSString *storyFeedId = [NSString stringWithFormat:@"%@", [stories objectForColumnName:@"story_feed_id"]];
                    NSString *storyHash = [stories objectForColumnName:@"story_hash"];
                    if (![hashes objectForKey:storyFeedId]) {
                        [hashes setObject:[NSMutableArray array] forKey:storyFeedId];
                    }
                    [[hashes objectForKey:storyFeedId] addObject:storyHash];
                }
                
                if ([[hashes allKeys] count]) {
                    hasQueuedReadStories = NO;
                    [self syncQueuedReadStories:db withStories:hashes withCallback:callback];
                } else {
                    if (callback) callback();
                }
            }];
        });
    } else {
        if (callback) callback();
    }
}

- (void)syncQueuedReadStories:(FMDatabase *)db withStories:(NSDictionary *)hashes withCallback:(void(^)())callback {
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_stories_as_read",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableArray *completedHashes = [NSMutableArray array];
    for (NSArray *storyHashes in [hashes allValues]) {
        [completedHashes addObjectsFromArray:storyHashes];
    }
    NSString *completedHashesStr = [completedHashes componentsJoinedByString:@"\",\""];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:[hashes JSONRepresentation] forKey:@"feeds_stories"];
    [request setDelegate:self];
    [request setCompletionBlock:^{
        NSLog(@"Completed clearing %@ hashes", completedHashesStr);
        [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM queued_read_hashes WHERE story_hash in (\"%@\")", completedHashesStr]]
        ;
        if (callback) callback();
    }];
    [request setFailedBlock:^{
        NSLog(@"Failed mark read queued.");
        hasQueuedReadStories = YES;
        if (callback) callback();
    }];
    [request startAsynchronous];
}

@end

#pragma mark -
#pragma mark Unread Counts


@implementation UnreadCounts

@synthesize ps, nt, ng;


- (id)init {
    if (self = [super init]) {
        ps = 0;
        nt = 0;
        ng = 0;
    }
    return self;
}

- (void)addCounts:(UnreadCounts *)counts {
    ps += counts.ps;
    nt += counts.nt;
    ng += counts.ng;
}

@end