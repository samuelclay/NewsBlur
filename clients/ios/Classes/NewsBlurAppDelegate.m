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
#import "ASINetworkQueue.h"
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
#import "Reachability.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "FMDatabaseAdditions.h"
#import "JSON.h"
#import "IASKAppSettingsViewController.h"
#import "OfflineSyncUnreads.h"
#import "OfflineFetchStories.h"
#import "OfflineFetchImages.h"
#import "OfflineCleanImages.h"
#import "PocketAPI.h"

@implementation NewsBlurAppDelegate

#define CURRENT_DB_VERSION 31
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
@synthesize originalStoryViewNavController;
@synthesize userProfileViewController;
@synthesize preferencesViewController;

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
@synthesize hasLoadedFeedDetail;
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
@synthesize latestCachedImageDate;
@synthesize totalUncachedImagesCount;
@synthesize remainingUncachedImagesCount;
@synthesize originalStoryCount;
@synthesize selectedIntelligence;
@synthesize activeOriginalStoryURL;
@synthesize recentlyReadStories;
@synthesize recentlyReadStoryLocations;
@synthesize recentlyReadFeeds;
@synthesize readStories;
@synthesize unreadStoryHashes;
@synthesize folderCountCache;

@synthesize dictFolders;
@synthesize dictFeeds;
@synthesize dictActiveFeeds;
@synthesize dictSocialFeeds;
@synthesize dictSocialProfile;
@synthesize dictUserProfile;
@synthesize dictSocialServices;
@synthesize dictUnreadCounts;
@synthesize userInteractionsArray;
@synthesize userActivitiesArray;
@synthesize dictFoldersArray;

@synthesize database;
@synthesize categories;
@synthesize categoryFeeds;
@synthesize activeCachedImages;
@synthesize hasQueuedReadStories;
@synthesize offlineQueue;
@synthesize offlineCleaningQueue;

+ (NewsBlurAppDelegate*) sharedAppDelegate {
	return (NewsBlurAppDelegate*) [UIApplication sharedApplication].delegate;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    NSString *currentiPhoneVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [self registerDefaultsFromSettingsBundle];
    
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
//    [self performSelectorOnMainThread:@selector(showSplashView) withObject:nil waitUntilDone:NO];
    
    [[UINavigationBar appearance] setBarTintColor:UIColorFromRGB(0xE0E3DB)];
    [[UIToolbar appearance] setBarTintColor:UIColorFromRGB(0xE0E3DB)];
    [[UISegmentedControl appearance] setTintColor:UIColorFromRGB(0x8F918B)];
//    [[UISegmentedControl appearance] setBackgroundColor:UIColorFromRGB(0x8F918B)];
    
    [self createDatabaseConnection];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [self.feedsViewController loadOfflineFeeds:NO];
    });

    [[PocketAPI sharedAPI] setConsumerKey:@"16638-05adf4465390446398e53b8b"];

//    [self showFirstTimeUser];

	return YES;
}

- (void)registerDefaultsFromSettingsBundle {
    NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    if(!settingsBundle) {
        NSLog(@"Could not find Settings.bundle");
        return;
    }
    
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
    NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];
    
    NSMutableDictionary *defaultsToRegister = [[NSMutableDictionary alloc] initWithCapacity:[preferences count]];
    for(NSDictionary *prefSpecification in preferences) {
        NSString *key = [prefSpecification objectForKey:@"Key"];
        if (key && [[prefSpecification allKeys] containsObject:@"DefaultValue"]) {
            [defaultsToRegister setObject:[prefSpecification objectForKey:@"DefaultValue"] forKey:key];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsToRegister];
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
    self.latestCachedImageDate = 0;
    self.totalUncachedImagesCount = 0;
    self.remainingUncachedImagesCount = 0;
}

- (void)startupAnimationDone:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    [splashView removeFromSuperview];
}

//- (void)applicationDidBecomeActive:(UIApplication *)application {
//    [[NSNotificationCenter defaultCenter] postNotificationName:AppDidBecomeActiveNotificationName object:nil];
//}
//
//- (void)applicationWillTerminate:(UIApplication *)application {
//    [[NSNotificationCenter defaultCenter] postNotificationName:AppWillTerminateNotificationName object:nil];
//}
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    if ([[PocketAPI sharedAPI] handleOpenURL:url]){
        return YES;
    } else {
        return NO;
    }
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

- (NSDictionary *)getUser:(NSInteger)userId {
    for (int i = 0; i < self.activeFeedUserProfiles.count; i++) {
        if ([[[self.activeFeedUserProfiles objectAtIndex:i] objectForKey:@"user_id"] intValue] == userId) {
            return [self.activeFeedUserProfiles objectAtIndex:i];
        }
    }
    
    // Check DB if not found in active feed
    __block NSDictionary *user;
    [self.database inDatabase:^(FMDatabase *db) {
        NSString *userSql = [NSString stringWithFormat:@"SELECT * FROM users WHERE user_id = %ld", (long)userId];
        FMResultSet *cursor = [db executeQuery:userSql];
        while ([cursor next]) {
            user = [NSJSONSerialization
                    JSONObjectWithData:[[cursor stringForColumn:@"user_json"]
                                        dataUsingEncoding:NSUTF8StringEncoding]
                    options:nil error:nil];
            if (user) break;
        }
        [cursor close];
    }];
    
    return user;
}

- (void)showUserProfileModal:(id)sender {
    UserProfileViewController *newUserProfile = [[UserProfileViewController alloc] init];
    self.userProfileViewController = newUserProfile; 
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.userProfileViewController];
    self.userProfileNavigationController = navController;
    self.userProfileNavigationController.navigationBar.translucent = NO;

    
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

- (void)showPreferences {
    if (!preferencesViewController) {
        preferencesViewController = [[IASKAppSettingsViewController alloc] init];
    }

    preferencesViewController.delegate = self.feedsViewController;
    preferencesViewController.showDoneButton = YES;
    preferencesViewController.showCreditsFooter = NO;
    preferencesViewController.title = @"Preferences";
    BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"offline_allowed"];
    preferencesViewController.hiddenKeys = enabled ? nil :
    [NSSet setWithObjects:@"offline_image_download",
     @"offline_download_connection",
     @"offline_store_limit",
     nil];
    [[NSUserDefaults standardUserDefaults] setObject:@"Delete offline stories..."
                                              forKey:@"offline_cache_empty_stories"];
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:preferencesViewController];
    self.modalNavigationController = navController;
    self.modalNavigationController.navigationBar.translucent = NO;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.modalNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
        [masterContainerViewController presentViewController:modalNavigationController animated:YES completion:nil];
    } else {
        [navigationController presentViewController:modalNavigationController animated:YES completion:nil];
    }
}

- (void)showFindFriends {
    FriendsListViewController *friendsBVC = [[FriendsListViewController alloc] init];
    UINavigationController *friendsNav = [[UINavigationController alloc] initWithRootViewController:friendsListViewController];
    
    self.friendsListViewController = friendsBVC;
    self.modalNavigationController = friendsNav;
    self.modalNavigationController.navigationBar.translucent = NO;
    
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
            self.shareNavigationController.navigationBar.translucent = NO;
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
#pragma mark View Management

- (void)showLogin {
    self.dictFeeds = nil;
    self.dictSocialFeeds = nil;
    self.dictFolders = nil;
    self.dictFoldersArray = nil;
    self.userActivitiesArray = nil;
    self.userInteractionsArray = nil;
    self.dictUnreadCounts = nil;
    
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
    self.ftuxNavigationController.navigationBar.translucent = NO;
    
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
    // Needs a delay because the menu will close the popover.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
                       [self
                        openTrainSiteWithFeedLoaded:YES
                        from:self.feedDetailViewController.settingsBarButton];
                   });
}

- (void)openTrainSiteWithFeedLoaded:(BOOL)feedLoaded from:(id)sender {
    UINavigationController *navController = self.navigationController;
    trainerViewController.feedTrainer = YES;
    trainerViewController.storyTrainer = NO;
    trainerViewController.feedLoaded = feedLoaded;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
//        trainerViewController.modalPresentationStyle=UIModalPresentationFormSheet;
//        [navController presentViewController:trainerViewController animated:YES completion:nil];
        [self.masterContainerViewController showTrainingPopover:sender];
    } else {
        if (self.trainNavigationController == nil) {
            self.trainNavigationController = [[UINavigationController alloc]
                                              initWithRootViewController:self.trainerViewController];
        }
        self.trainNavigationController.navigationBar.translucent = NO;
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
        self.trainNavigationController.navigationBar.translucent = NO;
        [navController presentViewController:self.trainNavigationController animated:YES completion:nil];
    }
}

- (void)reloadFeedsView:(BOOL)showLoader {
    [feedsViewController fetchFeedList:showLoader];
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
    [feedDetailViewController resetFeedDetail];
    
    [self flushQueuedReadStories:NO withCallback:^{
        [feedDetailViewController fetchFeedDetail:1 withCallback:nil];
    }];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController transitionToFeedDetail];
    } else {
        [navigationController pushViewController:feedDetailViewController
                                        animated:YES];
    }
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
    
    NSDictionary *feed = [self getFeed:feedId];
    
    if (social) {
        self.isSocialView = YES;
        self.inFindingStoryMode = YES;
  
        if (feed == nil) {
            feed = user;
            self.isTryFeedView = YES;
        }
    } else {
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
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.storyPageControl showShareHUD:@"Finding story..."];
        } else {
            MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.feedDetailViewController.view animated:YES];
            HUD.labelText = @"Finding story...";
        }        
    }
}

- (void)loadStarredDetailViewWithStory:(NSString *)contentId
                      showFindingStory:(BOOL)showHUD {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.navigationController popToRootViewControllerAnimated:NO];
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        if (self.feedsViewController.popoverController) {
            [self.feedsViewController.popoverController dismissPopoverAnimated:NO];
        }
    }

    self.isSocialRiverView = NO;
    self.isRiverView = YES;
    self.inFindingStoryMode = YES;
    self.isSocialView = NO;
    
    self.tryFeedStoryId = contentId;
    self.activeFeed = nil;
    self.activeFolder = @"saved_stories";
    
    [self loadRiverFeedDetailView];
    
    if (showHUD) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.storyPageControl showShareHUD:@"Finding story..."];
        } else {
            MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.feedDetailViewController.view animated:YES];
            HUD.labelText = @"Finding story...";
        }
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
        self.modalNavigationController.navigationBar.translucent = NO;
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
    
    [self flushQueuedReadStories:NO withCallback:^{
        [feedDetailViewController fetchRiverPage:1 withCallback:nil];
    }];
    
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
        NSInteger score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
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
    
    NSInteger activeStoryLocation = [self locationOfActiveStory];
    if (activeStoryLocation >= 0) {
        BOOL animated = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
                         !self.tryFeedCategory);
        [self.storyPageControl changePage:activeStoryLocation animated:animated];
        //        [self.storyPageControl updatePageWithActiveStory:activeStoryLocation];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        if ([feedTitle length] >= 12) {
            feedTitle = [NSString stringWithFormat:@"%@...", [feedTitle substringToIndex:MIN(9, [feedTitle length])]];
        }
        UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle:feedTitle style: UIBarButtonItemStylePlain target: nil action: nil];
        [feedDetailViewController.navigationItem setBackBarButtonItem: newBackButton];
        UINavigationController *navController = self.navigationController;
        [navController pushViewController:storyPageControl animated:YES];
        [navController.navigationItem setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:feedTitle style:UIBarButtonItemStyleBordered target:nil action:nil]];
        navController.navigationItem.hidesBackButton = YES;
    }
    
    [MBProgressHUD hideHUDForView:self.storyPageControl.view animated:YES];
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
    UINavigationController *navController = [[UINavigationController alloc]
                                             initWithRootViewController:self.originalStoryViewController];
    navController.navigationBar.translucent = NO;
    self.originalStoryViewNavController = navController;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController presentViewController:self.originalStoryViewNavController
                                                         animated:YES completion:nil];
    } else {
        [self.navigationController presentViewController:self.originalStoryViewNavController
                                                animated:YES completion:nil];
    }
}

- (void)closeOriginalStory {
    if (![self.presentedViewController isBeingDismissed]) {
        [originalStoryViewNavController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)hideStoryDetailView {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController transitionFromFeedDetail];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Story Traversal

- (BOOL)isStoryUnread:(NSDictionary *)story {
    BOOL readStatusUnread = [[story objectForKey:@"read_status"] intValue] == 0;
    BOOL storyHashUnread = [[self.unreadStoryHashes
                             objectForKey:[story objectForKey:@"story_hash"]] boolValue];
    BOOL recentlyRead = [[self.recentlyReadStories
                          objectForKey:[story objectForKey:@"story_hash"]] boolValue];
    
//    NSLog(@"isUnread: (%d || %d) && %d (%@ / %@)", readStatusUnread, storyHashUnread,
//          !recentlyRead, [[story objectForKey:@"story_title"] substringToIndex:10],
//          [story objectForKey:@"story_hash"]);

    return (readStatusUnread || storyHashUnread) && !recentlyRead;
}

- (NSInteger)indexOfNextUnreadStory {
    NSInteger location = [self locationOfNextUnreadStory];
    return [self indexFromLocation:location];
}

- (NSInteger)locationOfNextUnreadStory {
    NSInteger activeLocation = [self locationOfActiveStory];

    for (NSInteger i=activeLocation+1; i < [self.activeFeedStoryLocations count]; i++) {
        NSInteger storyIndex = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
        NSDictionary *story = [activeFeedStories objectAtIndex:storyIndex];
        if ([self isStoryUnread:story]) {
            return i;
        }
    }
    if (activeLocation > 0) {
        for (NSInteger i=activeLocation-1; i >= 0; i--) {
            NSInteger storyIndex = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
            NSDictionary *story = [activeFeedStories objectAtIndex:storyIndex];
            if ([self isStoryUnread:story]) {
                return i;
            }
        }
    }
    return -1;
}

- (NSInteger)indexOfNextStory {
    NSInteger location = [self locationOfNextStory];
    return [self indexFromLocation:location];
}

- (NSInteger)locationOfNextStory {
    NSInteger activeLocation = [self locationOfActiveStory];
    NSInteger nextStoryLocation = activeLocation + 1;
    if (nextStoryLocation < [self.activeFeedStoryLocations count]) {
        return nextStoryLocation;
    }
    return -1;
}

- (NSInteger)indexOfActiveStory {
    for (NSInteger i=0; i < self.storyCount; i++) {
        NSDictionary *story = [activeFeedStories objectAtIndex:i];
        if ([activeStory objectForKey:@"id"] == [story objectForKey:@"id"]) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)indexOfStoryId:(id)storyId {
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [activeFeedStories objectAtIndex:i];
        if ([story objectForKey:@"id"] == storyId) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)locationOfStoryId:(id)storyId {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([activeFeedStoryLocationIds objectAtIndex:i] == storyId) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)locationOfActiveStory {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([[activeFeedStoryLocationIds objectAtIndex:i]
             isEqualToString:[self.activeStory objectForKey:@"id"]]) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)indexFromLocation:(NSInteger)location {
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

- (NSString *)activeOrder {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *orderPrefDefault = [userPreferences stringForKey:@"default_order"];
    NSString *orderPref = [userPreferences stringForKey:[self orderKey]];
    
    if (orderPref) {
        return orderPref;
    } else if (orderPrefDefault) {
        return orderPrefDefault;
    } else {
        return @"newest";
    }
}

- (NSString *)activeReadFilter {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *readFilterFeedPrefDefault = [userPreferences stringForKey:@"default_feed_read_filter"];
    NSString *readFilterFolderPrefDefault = [userPreferences stringForKey:@"default_folder_read_filter"];
    NSString *readFilterPref = [userPreferences stringForKey:[self readFilterKey]];
    
    if (readFilterPref) {
        return readFilterPref;
    } else if (self.isRiverView || self.isSocialRiverView) {
        if (readFilterFolderPrefDefault) {
            return readFilterFolderPrefDefault;
        } else {
            return @"unread";
        }
    } else {
        if (readFilterFeedPrefDefault) {
            return readFilterFeedPrefDefault;
        } else {
            return @"all";
        }
    }
}

#pragma mark - Unread Counts

- (void)populateDictUnreadCounts {
    self.dictUnreadCounts = [NSMutableDictionary dictionary];
    
    [self.database inDatabase:^(FMDatabase *db) {
        FMResultSet *cursor = [db executeQuery:@"SELECT * FROM unread_counts"];
        
        while ([cursor next]) {
            NSDictionary *unreadCounts = [cursor resultDictionary];
            [self.dictUnreadCounts setObject:unreadCounts forKey:[unreadCounts objectForKey:@"feed_id"]];
        }
        
        [cursor close];
    }];
}

- (NSInteger)unreadCount {
    if (self.isRiverView || self.isSocialRiverView) {
        return [self unreadCountForFolder:nil];
    } else { 
        return [self unreadCountForFeed:nil];
    }
}

- (NSInteger)allUnreadCount {
    NSInteger total = 0;
    for (id key in self.dictSocialFeeds) {
        NSDictionary *feed = [self.dictSocialFeeds objectForKey:key];
        total += [[feed objectForKey:@"ps"] integerValue];
        total += [[feed objectForKey:@"nt"] integerValue];
        NSLog(@"feed title and number is %@ %i", [feed objectForKey:@"feed_title"], ([[feed objectForKey:@"ps"] intValue] + [[feed objectForKey:@"nt"] intValue]));
        NSLog(@"total is %ld", (long)total);
    }
    
    for (id key in self.dictUnreadCounts) {
        NSDictionary *feed = [self.dictUnreadCounts objectForKey:key];
        total += [[feed objectForKey:@"ps"] intValue];
        total += [[feed objectForKey:@"nt"] intValue];
//        NSLog(@"feed title and number is %@ %i", [feed objectForKey:@"feed_title"], ([[feed objectForKey:@"ps"] intValue] + [[feed objectForKey:@"nt"] intValue]));
//        NSLog(@"total is %i", total);
    }

    return total;
}

- (NSInteger)unreadCountForFeed:(NSString *)feedId {
    NSInteger total = 0;
    NSDictionary *feed;

    if (feedId) {
        NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
        if ([feedIdStr containsString:@"social:"]) {
            feed = [self.dictSocialFeeds objectForKey:feedIdStr];
        } else {
            feed = [self.dictUnreadCounts objectForKey:feedIdStr];
        }

    } else {
        NSString *feedIdStr = [NSString stringWithFormat:@"%@", [self.activeFeed objectForKey:@"id"]];
        feed = [self.dictUnreadCounts objectForKey:feedIdStr];
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

- (NSInteger)unreadCountForFolder:(NSString *)folderName {
    NSInteger total = 0;
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
        for (id feedId in self.dictUnreadCounts) {
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
    NSDictionary *feedCounts;
    
    if (!feedId) {
        feedId = [self.activeFeed objectForKey:@"id"];
    }
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
    feedCounts = [self.dictUnreadCounts objectForKey:feedIdStr];
    
    counts.ps += [[feedCounts objectForKey:@"ps"] intValue];
    counts.nt += [[feedCounts objectForKey:@"nt"] intValue];
    counts.ng += [[feedCounts objectForKey:@"ng"] intValue];
    
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

#pragma mark - Story Management

- (void)addStories:(NSArray *)stories {
    self.activeFeedStories = [self.activeFeedStories arrayByAddingObjectsFromArray:stories];
    self.storyCount = [self.activeFeedStories count];
    [self calculateStoryLocations];
    self.storyLocationsCount = [self.activeFeedStoryLocations count];
}

- (void)setStories:(NSArray *)activeFeedStoriesValue {
    self.activeFeedStories = activeFeedStoriesValue;
    self.storyCount = [self.activeFeedStories count];
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
    NSInteger activeLocation = [self locationOfActiveStory];
    if (activeLocation == -1) {
        return;
    }
    
    // changes the story layout in story feed detail
    [self.feedDetailViewController changeActiveStoryTitleCellLayout];
 
    NSInteger activeIndex = [[activeFeedStoryLocations objectAtIndex:activeLocation] intValue];
    
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
    } else if (self.isSocialRiverView && [[self.activeStory objectForKey:@"friend_user_ids"] count]) {
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
            [self markStoryRead:story feed:friendFeed];
        }
        
        for (int i = 0; i < otherFriendComments.count; i++) {
            feedIdStr = [NSString stringWithFormat:@"social:%@",
                         [otherFriendComments objectAtIndex:i]];   
            friendFeed = [self.dictSocialFeeds objectForKey:feedIdStr];
            [self markStoryRead:story feed:friendFeed];
        }
    }

    [self markStoryRead:story feed:feed];
    self.activeStory = [self.activeFeedStories objectAtIndex:activeIndex];
}

- (void)markActiveStoryUnread {
    NSInteger activeLocation = [self locationOfActiveStory];
    if (activeLocation == -1) {
        return;
    }
    
    // changes the story layout in story feed detail
    [self.feedDetailViewController changeActiveStoryTitleCellLayout];
    
    NSInteger activeIndex = [[activeFeedStoryLocations objectAtIndex:activeLocation] intValue];
    
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
    } else if (self.isSocialRiverView && [[self.activeStory objectForKey:@"friend_user_ids"] count]) {
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
        NSDictionary *feed = [self getFeed:feedIdStr];
        if (![feedsStories objectForKey:feedIdStr]) {
            [feedsStories setObject:[NSMutableArray array] forKey:feedIdStr];
        }
        NSMutableArray *stories = [feedsStories objectForKey:feedIdStr];
        [stories addObject:[story objectForKey:@"story_hash"]];
        [self markStoryRead:story feed:feed];
    }   
    return feedsStories;
}

- (void)markStoryRead:(NSString *)storyId feedId:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [self getFeed:feedIdStr];
    NSDictionary *story = nil;
    for (NSDictionary *s in self.activeFeedStories) {
        if ([[s objectForKey:@"story_hash"] isEqualToString:storyId]) {
            story = s;
            break;
        }
    }
    [self markStoryRead:story feed:feed];
}

- (void)markStoryRead:(NSDictionary *)story feed:(NSDictionary *)feed {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
    if (!feed) {
        feedIdStr = @"0";
    }
    
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
    if ([[self.activeStory objectForKey:@"story_hash"]
         isEqualToString:[newStory objectForKey:@"story_hash"]]) {
        self.activeStory = newStory;
    }
    
    // If not a feed, then don't bother updating local feed.
    if (!feed) return;
    
    self.visibleUnreadCount -= 1;
    if (![self.recentlyReadFeeds containsObject:[newStory objectForKey:@"story_feed_id"]]) {
        [self.recentlyReadFeeds addObject:[newStory objectForKey:@"story_feed_id"]];
    }
    
    NSDictionary *unreadCounts = [self.dictUnreadCounts objectForKey:feedIdStr];
    NSMutableDictionary *newUnreadCounts = [unreadCounts mutableCopy];
    NSInteger score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    if (score > 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ps"] intValue] - 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ps"];
    } else if (score == 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"nt"] intValue] - 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"nt"];
    } else if (score < 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ng"] intValue] - 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ng"];
    }
    [self.dictUnreadCounts setObject:newUnreadCounts forKey:feedIdStr];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [self.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            NSString *storyHash = [newStory objectForKey:@"story_hash"];
            [db executeUpdate:@"UPDATE stories SET story_json = ? WHERE story_hash = ?",
             [newStory JSONRepresentation],
             storyHash];
            [db executeUpdate:@"DELETE FROM unread_hashes WHERE story_hash = ?",
             storyHash];
            [db executeUpdate:@"UPDATE unread_counts SET ps = ?, nt = ?, ng = ? WHERE feed_id = ?",
             [newUnreadCounts objectForKey:@"ps"],
             [newUnreadCounts objectForKey:@"nt"],
             [newUnreadCounts objectForKey:@"ng"],
             feedIdStr];
        }];
    });
    
    NSInteger location = [self locationOfStoryId:[story objectForKey:@"id"]];
    [self.recentlyReadStories setObject:[NSNumber numberWithBool:YES]
                                 forKey:[story objectForKey:@"story_hash"]];
    [self.recentlyReadStoryLocations addObject:[NSNumber numberWithInteger:location]];
    [self.unreadStoryHashes removeObjectForKey:[story objectForKey:@"story_hash"]];

}

- (void)markStoryUnread:(NSString *)storyId feedId:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [self getFeed:feedIdStr];
    NSDictionary *story = nil;
    for (NSDictionary *s in self.activeFeedStories) {
        if ([[s objectForKey:@"story_hash"] isEqualToString:storyId]) {
            story = s;
            break;
        }
    }
    [self markStoryUnread:story feed:feed];
}

- (void)markStoryUnread:(NSDictionary *)story feed:(NSDictionary *)feed {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
    if (!feed) {
        feedIdStr = @"0";
    }

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

    // If not a feed, then don't bother updating local feed.
    if (!feed) return;

    self.visibleUnreadCount += 1;
//    if ([self.recentlyReadFeeds containsObject:[newStory objectForKey:@"story_feed_id"]]) {
        [self.recentlyReadFeeds removeObject:[newStory objectForKey:@"story_feed_id"]];
//    }
    
    NSDictionary *unreadCounts = [self.dictUnreadCounts objectForKey:feedIdStr];
    NSMutableDictionary *newUnreadCounts = [unreadCounts mutableCopy];
    NSInteger score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    if (score > 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ps"] intValue] + 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ps"];
    } else if (score == 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"nt"] intValue] + 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"nt"];
    } else if (score < 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ng"] intValue] + 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ng"];
    }
    [self.dictUnreadCounts setObject:newUnreadCounts forKey:feedIdStr];
    
    [self.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSString *storyHash = [newStory objectForKey:@"story_hash"];
        [db executeUpdate:@"UPDATE stories SET story_json = ? WHERE story_hash = ?",
         [newStory JSONRepresentation],
         storyHash];
        [db executeUpdate:@"INSERT INTO unread_hashes "
         "(story_hash, story_feed_id, story_timestamp) VALUES (?, ?, ?)",
         storyHash, feedIdStr, [newStory objectForKey:@"story_timestamp"]];
        [db executeUpdate:@"UPDATE unread_counts SET ps = ?, nt = ?, ng = ? WHERE feed_id = ?",
         [newUnreadCounts objectForKey:@"ps"],
         [newUnreadCounts objectForKey:@"nt"],
         [newUnreadCounts objectForKey:@"ng"],
         feedIdStr];
    }];
    
    NSInteger location = [self locationOfStoryId:[story objectForKey:@"id"]];
    [self.recentlyReadStories removeObjectForKey:[story objectForKey:@"story_hash"]];
    [self.recentlyReadStoryLocations removeObject:[NSNumber numberWithInteger:location]];
}

#pragma mark -
#pragma mark Mark as read

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
    NSMutableDictionary *unreadCounts = [NSMutableDictionary dictionary];
    
    [unreadCounts setValue:[NSNumber numberWithInt:0] forKey:@"ps"];
    [unreadCounts setValue:[NSNumber numberWithInt:0] forKey:@"nt"];
    [unreadCounts setValue:[NSNumber numberWithInt:0] forKey:@"ng"];
    
    [self.dictUnreadCounts setObject:unreadCounts forKey:feedIdStr];
}

- (void)markFeedReadInCache:(NSArray *)feedIds {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^{
        [self.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            [db executeUpdate:[NSString
                               stringWithFormat:@"UPDATE unread_counts SET ps = 0, nt = 0, ng = 0 "
                               "WHERE feed_id IN (\"%@\")",
                               [feedIds componentsJoinedByString:@"\",\""]]];
            [db executeUpdate:[NSString
                               stringWithFormat:@"DELETE FROM unread_hashes "
                               "WHERE story_feed_id IN (\"%@\")",
                               [feedIds componentsJoinedByString:@"\",\""]]];
        }];
    });
}

- (void)markFeedReadInCache:(NSArray *)feedIds cutoffTimestamp:(NSInteger)cutoff {
    for (NSString *feedId in feedIds) {
        NSDictionary *unreadCounts = [self.dictUnreadCounts objectForKey:feedId];
        NSMutableDictionary *newUnreadCounts = [unreadCounts mutableCopy];
        NSMutableArray *stories = [NSMutableArray array];
        
        [self.database inDatabase:^(FMDatabase *db) {
            NSString *sql = [NSString stringWithFormat:@"SELECT * FROM stories s "
                             "INNER JOIN unread_hashes uh ON s.story_hash = uh.story_hash "
                             "WHERE s.story_feed_id = %@ AND s.story_timestamp < %ld",
                             feedId, (long)cutoff];
            FMResultSet *cursor = [db executeQuery:sql];
            
            while ([cursor next]) {
                NSDictionary *story = [cursor resultDictionary];
                [stories addObject:[NSJSONSerialization
                                    JSONObjectWithData:[[story objectForKey:@"story_json"]
                                                        dataUsingEncoding:NSUTF8StringEncoding]
                                    options:nil error:nil]];
            }
            
            [cursor close];
        }];
        
        for (NSDictionary *story in stories) {
            NSInteger score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
            if (score > 0) {
                int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ps"] intValue] - 1);
                [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ps"];
            } else if (score == 0) {
                int unreads = MAX(0, [[newUnreadCounts objectForKey:@"nt"] intValue] - 1);
                [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"nt"];
            } else if (score < 0) {
                int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ng"] intValue] - 1);
                [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ng"];
            }
            [self.dictUnreadCounts setObject:newUnreadCounts forKey:feedId];
        }
        
        [self.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            for (NSDictionary *story in stories) {
                NSMutableDictionary *newStory = [story mutableCopy];
                [newStory setObject:[NSNumber numberWithInt:1] forKey:@"read_status"];
                NSString *storyHash = [newStory objectForKey:@"story_hash"];
                [db executeUpdate:@"UPDATE stories SET story_json = ? WHERE story_hash = ?",
                 [newStory JSONRepresentation],
                 storyHash];
            }
            NSString *deleteSql = [NSString
                                   stringWithFormat:@"DELETE FROM unread_hashes "
                                   "WHERE story_feed_id = \"%@\" "
                                   "AND story_timestamp < %ld",
                                   feedId, (long)cutoff];
            [db executeUpdate:deleteSql];
            [db executeUpdate:@"UPDATE unread_counts SET ps = ?, nt = ?, ng = ? WHERE feed_id = ?",
             [newUnreadCounts objectForKey:@"ps"],
             [newUnreadCounts objectForKey:@"nt"],
             [newUnreadCounts objectForKey:@"ng"],
             feedId];
        }];
    }
}

- (void)markStoriesRead:(NSDictionary *)stories inFeeds:(NSArray *)feeds cutoffTimestamp:(NSInteger)cutoff {
    // Must be offline and marking all as read, so load all stories.

    if (stories && [[stories allKeys] count]) {
        [self queueReadStories:stories];
    }
    
    if ([feeds count]) {
        NSMutableDictionary *feedsStories = [NSMutableDictionary dictionary];
        
        [self.database inDatabase:^(FMDatabase *db) {
            NSString *sql = [NSString stringWithFormat:@"SELECT u.story_feed_id, u.story_hash "
                             "FROM unread_hashes u WHERE u.story_feed_id IN (\"%@\")",
                             [feeds componentsJoinedByString:@"\",\""]];
            if (cutoff) {
                sql = [NSString stringWithFormat:@"%@ AND u.story_timestamp < %ld", sql, (long)cutoff];
            }
            FMResultSet *cursor = [db executeQuery:sql];
            
            while ([cursor next]) {
                NSDictionary *story = [cursor resultDictionary];
                NSString *feedIdStr = [story objectForKey:@"story_feed_id"];
                NSString *storyHash = [story objectForKey:@"story_hash"];
                
                if (![feedsStories objectForKey:feedIdStr]) {
                    [feedsStories setObject:[NSMutableArray array] forKey:feedIdStr];
                }
                
                NSMutableArray *stories = [feedsStories objectForKey:feedIdStr];
                [stories addObject:storyHash];
            }
            
            [cursor close];
        }];
        [self queueReadStories:feedsStories];
        if (cutoff) {
            [self markFeedReadInCache:[feedsStories allKeys] cutoffTimestamp:cutoff];
        } else {
            for (NSString *feedId in [feedsStories allKeys]) {
                [self markFeedAllRead:feedId];
            }
            [self markFeedReadInCache:[feedsStories allKeys]];
        }
    }
}

- (void)requestFailedMarkStoryRead:(ASIFormDataRequest *)request {
    //    [self informError:@"Failed to mark story as read"];
    NSArray *feedIds = [request.userInfo objectForKey:@"feeds"];
    NSDictionary *stories = [request.userInfo objectForKey:@"stories"];
    
    [self markStoriesRead:stories inFeeds:feedIds cutoffTimestamp:nil];
}

- (void)finishMarkAllAsRead:(ASIFormDataRequest *)request {
    if (request.responseStatusCode != 200) {
        [self requestFailedMarkStoryRead:request];
    }
}

#pragma mark -
#pragma mark Story Saving

- (void)markStory:story asSaved:(BOOL)saved {
    NSMutableDictionary *newStory = [story mutableCopy];
    [newStory setValue:[NSNumber numberWithBool:saved] forKey:@"starred"];
    if (saved) {
        [newStory setValue:[Utilities formatLongDateFromTimestamp:nil] forKey:@"starred_date"];
    } else {
        [newStory removeObjectForKey:@"starred_date"];
    }
    
    if ([[newStory objectForKey:@"story_hash"]
         isEqualToString:[self.activeStory objectForKey:@"story_hash"]]) {
        self.activeStory = newStory;
    }
    
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

#pragma mark -
#pragma mark Story functions

- (void)calculateStoryLocations {
    self.visibleUnreadCount = 0;
    self.activeFeedStoryLocations = [NSMutableArray array];
    self.activeFeedStoryLocationIds = [NSMutableArray array];
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [self.activeFeedStories objectAtIndex:i];
        NSInteger score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
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

+ (NSInteger)computeStoryScore:(NSDictionary *)intelligence {
    NSInteger score = 0;
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

#pragma mark - Feed Management

- (NSString *)extractParentFolderName:(NSString *)folderName {
    if ([folderName containsString:@"Top Level"] ||
        [folderName isEqual:@"everything"]) {
        folderName = @"";
    }
    
    if ([folderName containsString:@" - "]) {
        NSInteger lastFolderLoc = [folderName rangeOfString:@" - "
                                                    options:NSBackwardsSearch].location;
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
        NSInteger folder_loc = [folderName rangeOfString:@" - "
                                                 options:NSBackwardsSearch].location;
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
    titleLabel.textColor = UIColorFromRGB(0x4D4C4A);
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.numberOfLines = 1;
    titleLabel.shadowColor = UIColorFromRGB(0xF0F0F0);
    titleLabel.shadowOffset = CGSizeMake(0, 1);
    titleLabel.center = CGPointMake(0, -2);
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
    [titleLabel sizeToFit];

    return titleLabel;
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
    if (!feedClassifiers) feedClassifiers = [NSMutableDictionary dictionary];
    NSMutableDictionary *authors = [[feedClassifiers objectForKey:@"authors"] mutableCopy];
    if (!authors) authors = [NSMutableDictionary dictionary];
    [authors setObject:[NSNumber numberWithInt:authorScore] forKey:author];
    [feedClassifiers setObject:authors forKey:@"authors"];
    [self.activeClassifiers setObject:feedClassifiers forKey:feedId];
    [self.storyPageControl refreshHeaders];
    [self.trainerViewController refresh];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/classifier/save",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    __weak ASIFormDataRequest *_request = request;
    [request setPostValue:author
                   forKey:authorScore >= 1 ? @"like_author" :
                          authorScore <= -1 ? @"dislike_author" :
                          @"remove_like_author"];
    [request setPostValue:feedId forKey:@"feed_id"];
    [request setCompletionBlock:^{
        [self requestClassifierResponse:_request withFeed:feedId];
    }];
    [request setFailedBlock:^{
        [self requestClassifierResponse:_request withFeed:feedId];
    }];
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
    if (!feedClassifiers) feedClassifiers = [NSMutableDictionary dictionary];
    NSMutableDictionary *tags = [[feedClassifiers objectForKey:@"tags"] mutableCopy];
    if (!tags) tags = [NSMutableDictionary dictionary];
    [tags setObject:[NSNumber numberWithInt:tagScore] forKey:tag];
    [feedClassifiers setObject:tags forKey:@"tags"];
    [self.activeClassifiers setObject:feedClassifiers forKey:feedId];
    [self.storyPageControl refreshHeaders];
    [self.trainerViewController refresh];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/classifier/save",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    __weak ASIFormDataRequest *_request = request;
    [request setPostValue:tag
                   forKey:tagScore >= 1 ? @"like_tag" :
                          tagScore <= -1 ? @"dislike_tag" :
                          @"remove_like_tag"];
    [request setPostValue:feedId forKey:@"feed_id"];
    [request setCompletionBlock:^{
        [self requestClassifierResponse:_request withFeed:feedId];
    }];
    [request setFailedBlock:^{
        [self requestClassifierResponse:_request withFeed:feedId];
    }];
    [request setDelegate:self];
    [request startAsynchronous];
    
    [self recalculateIntelligenceScores:feedId];
    [self.feedDetailViewController.storyTitlesTable reloadData];
}

- (void)toggleTitleClassifier:(NSString *)title feedId:(NSString *)feedId score:(NSInteger)score {
    NSLog(@"toggle Title: %@ (%@) / %ld", title, feedId, (long)score);
    NSInteger titleScore = [[[[self.activeClassifiers objectForKey:feedId]
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
    if (!feedClassifiers) feedClassifiers = [NSMutableDictionary dictionary];
    NSMutableDictionary *titles = [[feedClassifiers objectForKey:@"titles"] mutableCopy];
    if (!titles) titles = [NSMutableDictionary dictionary];
    [titles setObject:[NSNumber numberWithInteger:titleScore] forKey:title];
    [feedClassifiers setObject:titles forKey:@"titles"];
    [self.activeClassifiers setObject:feedClassifiers forKey:feedId];
    [self.storyPageControl refreshHeaders];
    [self.trainerViewController refresh];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/classifier/save",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    __weak ASIFormDataRequest *_request = request;
    [request setPostValue:title
                   forKey:titleScore >= 1 ? @"like_title" :
                          titleScore <= -1 ? @"dislike_title" :
                          @"remove_like_title"];
    [request setPostValue:feedId forKey:@"feed_id"];
    [request setCompletionBlock:^{
        [self requestClassifierResponse:_request withFeed:feedId];
    }];
    [request setFailedBlock:^{
        [self requestClassifierResponse:_request withFeed:feedId];
    }];
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
    if (!feedClassifiers) feedClassifiers = [NSMutableDictionary dictionary];
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
    __weak ASIFormDataRequest *_request = request;
    [request setPostValue:feedId
                   forKey:feedScore >= 1 ? @"like_feed" :
                          feedScore <= -1 ? @"dislike_feed" :
                          @"remove_like_feed"];
    [request setPostValue:feedId forKey:@"feed_id"];
    [request setCompletionBlock:^{
        [self requestClassifierResponse:_request withFeed:feedId];
    }];
    [request setFailedBlock:^{
        [self requestClassifierResponse:_request withFeed:feedId];
    }];
    [request setDelegate:self];
    [request startAsynchronous];
    
    [self recalculateIntelligenceScores:feedId];
    [self.feedDetailViewController.storyTitlesTable reloadData];
}

- (void)requestClassifierResponse:(ASIHTTPRequest *)request withFeed:(NSString *)feedId {
    BaseViewController *view;
    if (self.trainerViewController.isViewLoaded && self.trainerViewController.view.window) {
        view = self.trainerViewController;
    } else {
        view = self.storyPageControl.currentPage;
    }
    if ([request responseStatusCode] == 503) {
        return [view informError:@"In maintenance mode"];
    } else if ([request responseStatusCode] != 200) {
        return [view informError:@"The server barfed!"];
    }
    
    [self.feedsViewController refreshFeedList:feedId];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
    [self informError:error];
}

#pragma mark -
#pragma mark Storing Stories for Offline

- (NSInteger)databaseSchemaVersion:(FMDatabase *)db {
    int version = 0;
    FMResultSet *resultSet = [db executeQuery:@"PRAGMA user_version"];
    if ([resultSet next]) {
        version = [resultSet intForColumnIndex:0];
    }
    [resultSet close];
    return version;
}

- (void)createDatabaseConnection {
    NSError *error;
    
    // Remove the deletion of old sqlite dbs past version 3.1, once everybody's
    // upgraded and removed the old files.
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *oldDBPath = [documentPaths objectAtIndex:0];
    NSArray *directoryContents = [fileManager contentsOfDirectoryAtPath:oldDBPath error:&error];
    int removed = 0;
    
    if (error == nil) {
        for (NSString *path in directoryContents) {
            NSString *fullPath = [oldDBPath stringByAppendingPathComponent:path];
            if ([fullPath hasSuffix:@".sqlite"]) {
                [fileManager removeItemAtPath:fullPath error:&error];
                removed++;
            }
        }
    }
    if (removed) {
        NSLog(@"Deleted %d sql dbs.", removed);
    }
    
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *dbPath = [cachePaths objectAtIndex:0];
    NSString *dbName = [NSString stringWithFormat:@"%@.sqlite", NEWSBLUR_HOST];
    NSString *path = [dbPath stringByAppendingPathComponent:dbName];
    
    database = [FMDatabaseQueue databaseQueueWithPath:path];
    [database inDatabase:^(FMDatabase *db) {
        [self setupDatabase:db];
    }];
}

- (void)setupDatabase:(FMDatabase *)db {
    if ([self databaseSchemaVersion:db] < CURRENT_DB_VERSION) {
        // FMDB cannot execute this query because FMDB tries to use prepared statements
        [db closeOpenResultSets];
        [db executeUpdate:@"drop table if exists `stories`"];
        [db executeUpdate:@"drop table if exists `unread_hashes`"];
        [db executeUpdate:@"drop table if exists `accounts`"];
        [db executeUpdate:@"drop table if exists `unread_counts`"];
        [db executeUpdate:@"drop table if exists `cached_images`"];
        [db executeUpdate:@"drop table if exists `users`"];
        //        [db executeUpdate:@"drop table if exists `queued_read_hashes`"]; // Nope, don't clear this.
        //        [db executeUpdate:@"drop table if exists `queued_saved_hashes`"]; // Nope, don't clear this.
        NSLog(@"Dropped db: %@", [db lastErrorMessage]);
        sqlite3_exec(db.sqliteHandle, [[NSString stringWithFormat:@"PRAGMA user_version = %d", CURRENT_DB_VERSION] UTF8String], NULL, NULL, NULL);
    }
    NSString *createAccountsTable = [NSString stringWithFormat:@"create table if not exists accounts "
                                  "("
                                  " username varchar(36),"
                                  " download_date date,"
                                  " feeds_json text,"
                                  " UNIQUE(username) ON CONFLICT REPLACE"
                                  ")"];
    [db executeUpdate:createAccountsTable];
    
    NSString *createCountsTable = [NSString stringWithFormat:@"create table if not exists unread_counts "
                                  "("
                                  " feed_id varchar(20),"
                                  " ps number,"
                                  " nt number,"
                                  " ng number,"
                                  " UNIQUE(feed_id) ON CONFLICT REPLACE"
                                  ")"];
    [db executeUpdate:createCountsTable];
    
    NSString *createStoryTable = [NSString stringWithFormat:@"create table if not exists stories "
                                  "("
                                  " story_feed_id varchar(20),"
                                  " story_hash varchar(24),"
                                  " story_timestamp number,"
                                  " story_json text,"
                                  " UNIQUE(story_hash) ON CONFLICT REPLACE"
                                  ")"];
    [db executeUpdate:createStoryTable];
    NSString *indexStoriesFeed = @"CREATE INDEX IF NOT EXISTS stories_story_feed_id ON stories (story_feed_id)";
    [db executeUpdate:indexStoriesFeed];
    
    NSString *createUnreadHashTable = [NSString stringWithFormat:@"create table if not exists unread_hashes "
                                       "("
                                       " story_feed_id varchar(20),"
                                       " story_hash varchar(24),"
                                       " story_timestamp number,"
                                       " UNIQUE(story_hash) ON CONFLICT IGNORE"
                                       ")"];
    [db executeUpdate:createUnreadHashTable];
    NSString *indexUnreadHashes = @"CREATE INDEX IF NOT EXISTS unread_hashes_story_feed_id ON unread_hashes (story_feed_id)";
    [db executeUpdate:indexUnreadHashes];
    NSString *indexUnreadTimestamp = @"CREATE INDEX IF NOT EXISTS unread_hashes_timestamp ON stories (story_timestamp)";
    [db executeUpdate:indexUnreadTimestamp];
    
    NSString *createReadTable = [NSString stringWithFormat:@"create table if not exists queued_read_hashes "
                                 "("
                                 " story_feed_id varchar(20),"
                                 " story_hash varchar(24),"
                                 " UNIQUE(story_hash) ON CONFLICT IGNORE"
                                 ")"];
    [db executeUpdate:createReadTable];
    
    NSString *createSavedTable = [NSString stringWithFormat:@"create table if not exists queued_saved_hashes "
                                 "("
                                 " story_feed_id varchar(20),"
                                 " story_hash varchar(24),"
                                 " UNIQUE(story_hash) ON CONFLICT IGNORE"
                                 ")"];
    [db executeUpdate:createSavedTable];
    
    NSString *createImagesTable = [NSString stringWithFormat:@"create table if not exists cached_images "
                                   "("
                                   " story_feed_id varchar(20),"
                                   " story_hash varchar(24),"
                                   " image_url varchar(1024),"
                                   " image_cached boolean,"
                                   " failed boolean"
                                   ")"];
    [db executeUpdate:createImagesTable];
    NSString *indexImagesFeedId = @"CREATE INDEX IF NOT EXISTS cached_images_story_feed_id ON cached_images (story_feed_id)";
    [db executeUpdate:indexImagesFeedId];
    NSString *indexImagesStoryHash = @"CREATE INDEX IF NOT EXISTS cached_images_story_hash ON cached_images (story_hash)";
    [db executeUpdate:indexImagesStoryHash];
    
    
    NSString *createUsersTable = [NSString stringWithFormat:@"create table if not exists users "
                                  "("
                                  " user_id number,"
                                  " username varchar(64),"
                                  " location varchar(128),"
                                  " image_url varchar(1024),"
                                  " image_cached boolean,"
                                  " user_json text,"
                                  " UNIQUE(user_id) ON CONFLICT REPLACE"
                                  ")"];
    [db executeUpdate:createUsersTable];
    NSString *indexUsersUserId = @"CREATE INDEX IF NOT EXISTS users_user_id ON users (user_id)";
    [db executeUpdate:indexUsersUserId];
    
    NSError *error;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *storyImagesDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"story_images"];
    NSString *faviconsDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"favicons"];
    NSString *avatarsDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"avatars"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:storyImagesDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:storyImagesDirectory withIntermediateDirectories:NO attributes:nil error:&error];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:faviconsDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:faviconsDirectory withIntermediateDirectories:NO attributes:nil error:&error];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:avatarsDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:avatarsDirectory withIntermediateDirectories:NO attributes:nil error:&error];
    }
    
    NSLog(@"Create db %d: %@", [db lastErrorCode], [db lastErrorMessage]);
}

- (void)cancelOfflineQueue {
    if (offlineQueue) {
        [offlineQueue cancelAllOperations];
    }
    if (offlineCleaningQueue) {
        [offlineCleaningQueue cancelAllOperations];
    }
}

- (void)startOfflineQueue {
    if (!offlineQueue) {
        offlineQueue = [NSOperationQueue new];
    }
    offlineQueue.name = @"Offline Queue";
    NSLog(@"Operation queue: %lu", (unsigned long)offlineQueue.operationCount);
    [offlineQueue cancelAllOperations];
    [offlineQueue setMaxConcurrentOperationCount:1];
    OfflineSyncUnreads *operationSyncUnreads = [[OfflineSyncUnreads alloc] init];
    
    [offlineQueue addOperation:operationSyncUnreads];
}

- (void)startOfflineFetchStories {
    OfflineFetchStories *operationFetchStories = [[OfflineFetchStories alloc] init];
    
    [offlineQueue addOperation:operationFetchStories];
    
    NSLog(@"Done start offline fetch stories");
}

- (void)startOfflineFetchImages {
    OfflineFetchImages *operationFetchImages = [[OfflineFetchImages alloc] init];
    
    [offlineQueue addOperation:operationFetchImages];
}

- (BOOL)isReachabileForOffline {
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus remoteHostStatus = [reachability currentReachabilityStatus];
    
    NSString *connection = [[NSUserDefaults standardUserDefaults]
                            stringForKey:@"offline_download_connection"];
    
//    NSLog(@"Reachable via: %d / %d", remoteHostStatus == ReachableViaWWAN, remoteHostStatus == ReachableViaWiFi);
    if ([connection isEqualToString:@"wifi"] && remoteHostStatus != ReachableViaWiFi) {
        return NO;
    }
    
    return YES;
}

- (void)storeUserProfiles:(NSArray *)userProfiles {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [self.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            for (NSDictionary *user in userProfiles) {
                [db executeUpdate:@"INSERT INTO users "
                 "(user_id, username, location, image_url, user_json) VALUES "
                 "(?, ?, ?, ?, ?)",
                 [user objectForKey:@"user_id"],
                 [user objectForKey:@"username"],
                 [user objectForKey:@"location"],
                 [user objectForKey:@"photo_url"],
                 [user JSONRepresentation]
                 ];
            }
        }];
    });
}

- (void)queueReadStories:(NSDictionary *)feedsStories {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [self.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            for (NSString *feedIdStr in [feedsStories allKeys]) {
                for (NSString *storyHash in [feedsStories objectForKey:feedIdStr]) {
                    [db executeUpdate:@"INSERT INTO queued_read_hashes "
                     "(story_feed_id, story_hash) VALUES "
                     "(?, ?)", feedIdStr, storyHash];
                }
            }
        }];
    });
    self.hasQueuedReadStories = YES;
}

- (BOOL)dequeueReadStoryHash:(NSString *)storyHash inFeed:(NSString *)storyFeedId {
    __block BOOL storyQueued = NO;
    
    [self.database inDatabase:^(FMDatabase *db) {
        FMResultSet *stories = [db executeQuery:@"SELECT * FROM queued_read_hashes "
                                "WHERE story_hash = ? AND story_feed_id = ? LIMIT 1",
                                storyHash, storyFeedId];
        while ([stories next]) {
            storyQueued = YES;
            break;
        }
        [stories close];
        if (storyQueued) {
            [db executeUpdate:@"DELETE FROM queued_read_hashes "
             "WHERE story_hash = ? AND story_feed_id = ?",
             storyHash, storyFeedId];
        }
    }];
    
    return storyQueued;
}

- (void)flushQueuedReadStories:(BOOL)forceCheck withCallback:(void(^)())callback {
    if (self.hasQueuedReadStories || forceCheck) {
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
                    self.hasQueuedReadStories = NO;
                    [self syncQueuedReadStories:db withStories:hashes withCallback:callback];
                } else {
                    if (callback) callback();
                }
                [stories close];
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
    __weak ASIHTTPRequest *_request = request;
    [request setPostValue:[hashes JSONRepresentation] forKey:@"feeds_stories"];
    [request setDelegate:self];
    [request setCompletionBlock:^{
        if ([_request responseStatusCode] == 200) {
            NSLog(@"Completed clearing %@ hashes", completedHashesStr);
            [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM queued_read_hashes "
                               "WHERE story_hash in (\"%@\")", completedHashesStr]];
        } else {
            NSLog(@"Failed mark read queued.");
            self.hasQueuedReadStories = YES;
        }
        if (callback) callback();
    }];
    [request setFailedBlock:^{
        NSLog(@"Failed mark read queued.");
        self.hasQueuedReadStories = YES;
        if (callback) callback();
    }];
    [request startAsynchronous];
}

- (void)prepareActiveCachedImages:(FMDatabase *)db {
    activeCachedImages = [NSMutableDictionary dictionary];
    NSArray *feedIds;
    int cached = 0;
    
    if (isRiverView) {
        feedIds = activeFolderFeeds;
    } else if (activeFeed) {
        feedIds = @[[activeFeed objectForKey:@"id"]];
    }
    NSString *sql = [NSString stringWithFormat:@"SELECT c.image_url, c.story_hash FROM cached_images c "
                     "WHERE c.image_cached = 1 AND c.failed is null AND c.story_feed_id in (\"%@\")",
                     [feedIds componentsJoinedByString:@"\",\""]];
    FMResultSet *cursor = [db executeQuery:sql];
    
    while ([cursor next]) {
        NSString *storyHash = [cursor objectForColumnName:@"story_hash"];
        NSMutableArray *imageUrls;
        if (![activeCachedImages objectForKey:storyHash]) {
            imageUrls = [NSMutableArray array];
            [activeCachedImages setObject:imageUrls forKey:storyHash];
        } else {
            imageUrls = [activeCachedImages objectForKey:storyHash];
        }
        [imageUrls addObject:[cursor objectForColumnName:@"image_url"]];
        [activeCachedImages setObject:imageUrls forKey:storyHash];
        cached++;
    }
    
    NSLog(@"Pre-cached %d images", cached);
}

- (void)cleanImageCache {
    OfflineCleanImages *operationCleanImages = [[OfflineCleanImages alloc] init];
    if (!offlineCleaningQueue) {
        offlineCleaningQueue = [NSOperationQueue new];
    }
    [offlineCleaningQueue addOperation:operationCleanImages];
}

- (void)deleteAllCachedImages {
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"story_images"];
    NSArray *directoryContents = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:&error];
    int removed = 0;
    
    if (error == nil) {
        for (NSString *path in directoryContents) {
            NSString *fullPath = [cacheDirectory stringByAppendingPathComponent:path];
            BOOL removeSuccess = [fileManager removeItemAtPath:fullPath error:&error];
            removed++;
            if (!removeSuccess) {
                continue;
            }
        }
    }
    
    NSLog(@"Deleted %d images.", removed);
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

- (NSString *)description {
    return [NSString stringWithFormat:@"PS: %d, NT: %d, NG: %d", ps, nt, ng];
}

@end