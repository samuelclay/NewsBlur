
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
#import "MarkReadMenuViewController.h"
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
#import "UserTagsViewController.h"
#import "OriginalStoryViewController.h"
#import "ShareViewController.h"
#import "FontSettingsViewController.h"
#import "FeedChooserViewController.h"
#import "UserProfileViewController.h"
#import "AFHTTPRequestOperation.h"
#import "ASINetworkQueue.h"
#import "InteractionsModule.h"
#import "ActivityModule.h"
#import "FirstTimeUserViewController.h"
#import "FirstTimeUserAddSitesViewController.h"
#import "FirstTimeUserAddFriendsViewController.h"
#import "FirstTimeUserAddNewsBlurViewController.h"
#import "TUSafariActivity.h"
#import "ARChromeActivity.h"
#import "NBCopyLinkActivity.h"
#import "MBProgressHUD.h"
#import "Utilities.h"
#import "StringHelper.h"
#import "AuthorizeServicesViewController.h"
#import "Reachability.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "FMDatabaseAdditions.h"
#import "SBJson4.h"
#import "NSObject+SBJSON.h"
#import "IASKAppSettingsViewController.h"
#import "OfflineSyncUnreads.h"
#import "OfflineFetchStories.h"
#import "OfflineFetchImages.h"
#import "OfflineCleanImages.h"
#import "NBBarButtonItem.h"
#import "TMCache.h"
#import "StoriesCollection.h"
#import "NSString+HTML.h"
#import "UIView+ViewController.h"
#import "NBURLCache.h"
#import "NBActivityItemSource.h"
#import "NSNull+JSON.h"
#import "UISearchBar+Field.h"
#import "UIViewController+HidePopover.h"
#import <float.h>

@interface NewsBlurAppDelegate () <UIViewControllerTransitioningDelegate>

@property (nonatomic, strong) NSString *cachedURL;
@property (nonatomic, strong) UIApplicationShortcutItem *launchedShortcutItem;
@property (nonatomic, strong) SFSafariViewController *safariViewController;

@end

@implementation NewsBlurAppDelegate

#define CURRENT_DB_VERSION 35

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
@synthesize friendsListViewController;
@synthesize fontSettingsViewController;
@synthesize storyDetailViewController;
@synthesize storyPageControl;
@synthesize shareViewController;
@synthesize loginViewController;
@synthesize addSiteViewController;
@synthesize moveSiteViewController;
@synthesize trainerViewController;
@synthesize userTagsViewController;
@synthesize originalStoryViewController;
@synthesize originalStoryViewNavController;
@synthesize userProfileViewController;
@synthesize preferencesViewController;

@synthesize firstTimeUserViewController;
@synthesize firstTimeUserAddSitesViewController;
@synthesize firstTimeUserAddFriendsViewController;
@synthesize firstTimeUserAddNewsBlurViewController;

@synthesize feedDetailPortraitYCoordinate;
@synthesize cachedFavicons;
@synthesize cachedStoryImages;
@synthesize activeUsername;
@synthesize activeUserProfileId;
@synthesize activeUserProfileName;
@synthesize hasNoSites;
@synthesize isTryFeedView;

@synthesize inFindingStoryMode;
@synthesize hasLoadedFeedDetail;
@synthesize tryFeedStoryId;
@synthesize tryFeedCategory;
@synthesize popoverHasFeedView;
@synthesize inFeedDetail;
@synthesize inStoryDetail;
@synthesize isPresentingActivities;
@synthesize activeComment;
@synthesize activeShareType;

@synthesize storiesCollection;

@synthesize activeStory;
@synthesize savedStoriesCount;
@synthesize originalStoryCount;
@synthesize selectedIntelligence;
@synthesize activeOriginalStoryURL;
@synthesize recentlyReadStories;
@synthesize recentlyReadFeeds;
@synthesize readStories;
@synthesize unreadStoryHashes;
@synthesize folderCountCache;
@synthesize collapsedFolders;
@synthesize fontDescriptorTitleSize;

@synthesize dictFolders;
@synthesize dictFeeds;
@synthesize dictActiveFeeds;
@synthesize dictSocialFeeds;
@synthesize dictSavedStoryTags;
@synthesize dictSocialProfile;
@synthesize dictUserProfile;
@synthesize dictSocialServices;
@synthesize dictUnreadCounts;
@synthesize dictTextFeeds;
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
@synthesize backgroundCompletionHandler;
@synthesize cacheImagesOperationQueue;

@synthesize totalUnfetchedStoryCount;
@synthesize remainingUnfetchedStoryCount;
@synthesize latestFetchedStoryDate;
@synthesize latestCachedImageDate;
@synthesize totalUncachedImagesCount;
@synthesize remainingUncachedImagesCount;

+ (NewsBlurAppDelegate*) sharedAppDelegate {
	return (NewsBlurAppDelegate*) [UIApplication sharedApplication].delegate;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSString *currentiPhoneVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];

    [self registerDefaultsFromSettingsBundle];
    
    self.navigationController.delegate = self;
    self.navigationController.viewControllers = [NSArray arrayWithObject:self.feedsViewController];
    self.storiesCollection = [StoriesCollection new];
    
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
    
    [[ThemeManager themeManager] prepareForWindow:self.window];
    
    [self createDatabaseConnection];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [self.cachedStoryImages removeAllObjects:^(TMCache *cache) {}];
        [feedsViewController loadOfflineFeeds:NO];
        [self setupReachability];
        cacheImagesOperationQueue = [NSOperationQueue new];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            cacheImagesOperationQueue.maxConcurrentOperationCount = 2;
        } else {
            cacheImagesOperationQueue.maxConcurrentOperationCount = 1;
        }
    });

//    [self showFirstTimeUser];
    
    cachedFavicons = [[TMCache alloc] initWithName:@"NBFavicons"];
    cachedStoryImages = [[TMCache alloc] initWithName:@"NBStoryImages"];
    
    NBURLCache *urlCache = [[NBURLCache alloc] init];
    [NSURLCache setSharedURLCache:urlCache];
    // Uncomment below line to test image caching
//    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    if ([UIApplicationShortcutItem class] && launchOptions[UIApplicationLaunchOptionsShortcutItemKey]) {
        self.launchedShortcutItem = launchOptions[UIApplicationLaunchOptionsShortcutItemKey];
        return NO;
    }
    
	return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (self.launchedShortcutItem) {
        [self handleShortcutItem:self.launchedShortcutItem];
        self.launchedShortcutItem = nil;
    }
}

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    completionHandler([self handleShortcutItem:shortcutItem]);
}

- (BOOL)handleShortcutItem:(UIApplicationShortcutItem *)shortcutItem {
    NSString *type = shortcutItem.type;
    NSString *prefix = [[NSBundle mainBundle].bundleIdentifier stringByAppendingString:@"."];
    BOOL handled = YES;
    
    if (!self.activeUsername) {
        handled = NO;
    } else if ([type startsWith:prefix]) {
        type = [type substringFromIndex:[prefix length]];
        if ([type isEqualToString:@"AddFeed"]) {
            [self.navigationController popToRootViewControllerAnimated:NO];
            [self performSelector:@selector(delayedAddSite) withObject:nil afterDelay:0.0];
        } else if ([type isEqualToString:@"AllStories"]) {
            [self.navigationController popToRootViewControllerAnimated:NO];
            [self.feedsViewController didSelectSectionHeaderWithTag:2];
        } else if ([type isEqualToString:@"Search"]) {
            [self.navigationController popToRootViewControllerAnimated:NO];
            [self.feedsViewController didSelectSectionHeaderWithTag:2];
            self.feedDetailViewController.storiesCollection.searchQuery = @"";
            self.feedDetailViewController.storiesCollection.inSearch = YES;
        } else {
            handled = NO;
        }
    } else {
        handled = NO;
    }
    
    return handled;
}

- (void)delayedAddSite {
    [self.feedsViewController tapAddSite:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = @"All";
}

- (void)application:(UIApplication *)application
    performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    [self createDatabaseConnection];
    [self.feedsViewController fetchFeedList:NO];
    backgroundCompletionHandler = completionHandler;
}

- (void)finishBackground {
    if (!backgroundCompletionHandler) return;
    
    NSLog(@"Background fetch complete. Found data: %d/%d = %d",
          self.totalUnfetchedStoryCount, self.totalUncachedImagesCount,
          self.totalUnfetchedStoryCount || self.totalUncachedImagesCount);
    if (self.totalUnfetchedStoryCount || self.totalUncachedImagesCount) {
        backgroundCompletionHandler(UIBackgroundFetchResultNewData);
    } else {
        backgroundCompletionHandler(UIBackgroundFetchResultNoData);
    }
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

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    return NO;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
	// Release any cached data, images, etc that aren't in use.
    [cachedStoryImages removeAllObjects];
}

- (void)setupReachability {
    Reachability* reach = [Reachability reachabilityWithHostname:self.host];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    reach.reachableBlock = ^(Reachability *reach) {
        NSLog(@"Reachable: %@", reach);
    };
    reach.unreachableBlock = ^(Reachability *reach) {
        NSLog(@"Un-Reachable: %@", reach);
        [feedsViewController loadOfflineFeeds:NO];
    };
    [reach startNotifier];
}

- (void)reachabilityChanged:(id)something {
    NSLog(@"Reachability changed: %@", something);
//    Reachability* reach = [Reachability reachabilityWithHostname:self.host];

//    if (reach.isReachable && feedsViewController.isOffline) {
//        [feedsViewController loadOfflineFeeds:NO];
////    } else {
////        [feedsViewController loadOfflineFeeds:NO];
//    }
}

- (NSString *)url {
    if (!self.cachedURL) {
        NSString *url = [[NSUserDefaults standardUserDefaults] objectForKey:@"custom_domain"];
        
        if (url.length) {
            if ([url rangeOfString:@"://"].location == NSNotFound) {
                url = [@"http://" stringByAppendingString:url];
            }
        } else {
            url = DEFAULT_NEWSBLUR_URL;
        }
        
        self.cachedURL = url;
    }
    
    return self.cachedURL;
}

- (NSString *)host {
    NSString *url = self.url;
    NSString *host = nil;
    NSRange range = [url rangeOfString:@"://"];
    
    if (url.length && range.location != NSNotFound) {
        host = [url substringFromIndex:range.location + range.length];
    }
    
    return host;
}

#pragma mark -
#pragma mark Social Views

- (NSDictionary *)getUser:(NSInteger)userId {
    for (int i = 0; i < storiesCollection.activeFeedUserProfiles.count; i++) {
        if ([[[storiesCollection.activeFeedUserProfiles objectAtIndex:i] objectForKey:@"user_id"] intValue] == userId) {
            return [storiesCollection.activeFeedUserProfiles objectAtIndex:i];
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
    [self hidePopoverAnimated:NO];
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
        [self hidePopover];
    } else {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)showPreferences {
    if (!preferencesViewController) {
        preferencesViewController = [[IASKAppSettingsViewController alloc] init];
        [[ThemeManager themeManager] addThemeGestureRecognizerToView:self.preferencesViewController.view];
    }
    
    [self hidePopover];

    preferencesViewController.delegate = self.feedsViewController;
    preferencesViewController.showDoneButton = YES;
    preferencesViewController.showCreditsFooter = NO;
    preferencesViewController.title = @"Preferences";
    NSMutableSet *hiddenSet = [NSMutableSet set];
    BOOL offline_enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"offline_allowed"];
    if (!offline_enabled) {
        [hiddenSet addObjectsFromArray:@[@"offline_image_download",
                                         @"offline_download_connection",
                                         @"offline_store_limit"]];
    }
    BOOL system_font_enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"use_system_font_size"];
    if (system_font_enabled) {
        [hiddenSet addObjectsFromArray:@[@"feed_list_font_size"]];
    }
    BOOL theme_auto_toggle = [[NSUserDefaults standardUserDefaults] boolForKey:@"theme_auto_toggle"];
    if (theme_auto_toggle) {
        [hiddenSet addObjectsFromArray:@[@"theme_style", @"theme_gesture"]];
    } else {
        [hiddenSet addObjectsFromArray:@[@"theme_auto_brightness"]];
    }
    preferencesViewController.hiddenKeys = hiddenSet;
    [[NSUserDefaults standardUserDefaults] setObject:@"Delete offline stories..."
                                              forKey:@"offline_cache_empty_stories"];
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:preferencesViewController];
    self.modalNavigationController = navController;
    self.modalNavigationController.navigationBar.translucent = NO;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [masterContainerViewController dismissViewControllerAnimated:NO completion:nil];
        self.modalNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
        [masterContainerViewController presentViewController:modalNavigationController animated:YES completion:nil];
    } else {
        [navigationController presentViewController:modalNavigationController animated:YES completion:nil];
    }
}

- (void)showFeedChooserForOperation:(FeedChooserOperation)operation {
    [self hidePopover];
    
    self.feedChooserViewController = [FeedChooserViewController new];
    self.feedChooserViewController.operation = operation;
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self.feedChooserViewController];
    
    self.modalNavigationController = nav;
    self.modalNavigationController.navigationBar.translucent = NO;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.modalNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
        [masterContainerViewController presentViewController:modalNavigationController animated:YES completion:nil];
    } else {
        [navigationController presentViewController:modalNavigationController animated:YES completion:nil];
    }
}


- (void)showMuteSites {
    [self showFeedChooserForOperation:FeedChooserOperationMuteSites];
}

- (void)showOrganizeSites {
    [self showFeedChooserForOperation:FeedChooserOperationOrganizeSites];
}

- (void)showFindFriends {
    [self hidePopover];
    
    FriendsListViewController *friendsBVC = [[FriendsListViewController alloc] init];
    UINavigationController *friendsNav = [[UINavigationController alloc] initWithRootViewController:friendsListViewController];
    
    self.friendsListViewController = friendsBVC;
    self.modalNavigationController = friendsNav;
    self.modalNavigationController.navigationBar.translucent = NO;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [masterContainerViewController dismissViewControllerAnimated:NO completion:nil];
        self.modalNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
        [masterContainerViewController presentViewController:modalNavigationController animated:YES completion:nil];
    } else {
        [navigationController presentViewController:modalNavigationController animated:YES completion:nil];
    }
    [self.friendsListViewController loadSuggestedFriendsList];
}

- (void)showSendTo:(UIViewController *)vc sender:(id)sender {
    NSString *authorName = [activeStory objectForKey:@"story_authors"];
    NSString *text = [activeStory objectForKey:@"story_content"];
    NSString *title = [[activeStory objectForKey:@"story_title"] stringByDecodingHTMLEntities];
    NSArray *images = [activeStory objectForKey:@"image_urls"];
    NSURL *url = [NSURL URLWithString:[activeStory objectForKey:@"story_permalink"]];
    NSString *feedId = [NSString stringWithFormat:@"%@", [activeStory objectForKey:@"story_feed_id"]];
    NSDictionary *feed = [self getFeed:feedId];
    NSString *feedTitle = [feed objectForKey:@"feed_title"];
    
    if ([activeStory objectForKey:@"original_text"]) {
        text = [activeStory objectForKey:@"original_text"];
    }
    
    return [self showSendTo:vc
                     sender:sender
                    withUrl:url
                 authorName:authorName
                       text:text
                      title:title
                  feedTitle:feedTitle
                     images:images];
}

- (void)showSendTo:(UIViewController *)vc sender:(id)sender
           withUrl:(NSURL *)url
        authorName:(NSString *)authorName
              text:(NSString *)text
             title:(NSString *)title
         feedTitle:(NSString *)feedTitle
            images:(NSArray *)images {
    
    // iOS 8+
    if (text) {
        NSString *maybeFeedTitle = feedTitle ? [NSString stringWithFormat:@" via %@", feedTitle] : @"";
        text = [NSString stringWithFormat:@"<html><body><br><br><hr style=\"border: none; overflow: hidden; height: 1px;width: 100%%;background-color: #C0C0C0;\"><br><a href=\"%@\">%@</a>%@<br>%@</body></html>", [url absoluteString], title, maybeFeedTitle, text];
    }

    NBActivityItemSource *activityItemSource = [[NBActivityItemSource alloc] initWithUrl:url authorName:authorName text:text title:title feedTitle:feedTitle];
    NSArray *activityItems = @[activityItemSource, url];

    NSMutableArray *appActivities = [[NSMutableArray alloc] init];
    if (url) [appActivities addObject:[[TUSafariActivity alloc] init]];
    if (url) [appActivities addObject:[[ARChromeActivity alloc]
                                       initWithCallbackURL:[NSURL URLWithString:@"newsblur://"]]];
    if (url) [appActivities addObject:[[NBCopyLinkActivity alloc] init]];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc]
                                                        initWithActivityItems:activityItems
                                                        applicationActivities:appActivities];
    [activityViewController setTitle:title];
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        self.isPresentingActivities = NO;
        
        NSString *_completedString;
        NSLog(@"activityType: %@", activityType);
        if (!activityType) return;
        
        if ([activityType isEqualToString:UIActivityTypePostToTwitter]) {
            _completedString = @"Posted";
        } else if ([activityType isEqualToString:UIActivityTypePostToFacebook]) {
            _completedString = @"Posted";
        } else if ([activityType isEqualToString:UIActivityTypeMail]) {
            _completedString = @"Sent";
        } else if ([activityType isEqualToString:UIActivityTypeMessage]) {
            _completedString = @"Sent";
        } else if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
            _completedString = @"Copied";
        } else if ([activityType isEqualToString:UIActivityTypeAirDrop]) {
            _completedString = @"Airdropped";
        } else if ([activityType isEqualToString:@"com.ideashower.ReadItLaterPro.AddToPocketExtension"]) {
            return;
        } else if ([activityType isEqualToString:@"TUSafariActivity"]) {
            return;
        } else if ([activityType isEqualToString:@"ARChromeActivity"]) {
            return;
        } else if ([activityType isEqualToString:@"NBCopyLinkActivity"]) {
            _completedString = @"Copied Link";
        } else {
            _completedString = @"Saved";
        }
        [MBProgressHUD hideHUDForView:vc.view animated:NO];
        if (completed) {
            MBProgressHUD *storyHUD = [MBProgressHUD showHUDAddedTo:vc.view animated:YES];
            storyHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
            storyHUD.mode = MBProgressHUDModeCustomView;
            storyHUD.removeFromSuperViewOnHide = YES;
            storyHUD.labelText = _completedString;
            [storyHUD hide:YES afterDelay:1];
        }
    }];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        BOOL fromPopover = [self hidePopoverAnimated:NO];
        [self.masterContainerViewController presentViewController:activityViewController animated:!fromPopover completion:nil];
        activityViewController.modalPresentationStyle = UIModalPresentationPopover;
        // iOS 8+
        UIPopoverPresentationController *popPC = activityViewController.popoverPresentationController;
        popPC.permittedArrowDirections = UIPopoverArrowDirectionAny;
        popPC.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
        
        if ([sender isKindOfClass:[UIBarButtonItem class]]) {
            popPC.barButtonItem = sender;
        } else if ([sender isKindOfClass:[NSValue class]]) {
            //            // Uncomment below to show share popover from linked text. Problem is
            //            // that on finger up the link will open.
            CGPoint pt = [(NSValue *)sender CGPointValue];
            CGRect rect = CGRectMake(pt.x, pt.y, 1, 1);
            ////            [[OSKPresentationManager sharedInstance] presentActivitySheetForContent:content presentingViewController:vc popoverFromRect:rect inView:self.storyPageControl.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES options:options];
            
            //            [[OSKPresentationManager sharedInstance] presentActivitySheetForContent:content
            //                                                           presentingViewController:vc options:options];
            popPC.sourceRect = rect;
            popPC.sourceView = self.storyPageControl.view;
        } else {
            popPC.sourceRect = [sender frame];
            popPC.sourceView = [sender superview];
            
            //            [[OSKPresentationManager sharedInstance] presentActivitySheetForContent:content presentingViewController:vc popoverFromRect:[sender frame] inView:[sender superview] permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES options:options];
        }
    } else {
        [self.navigationController presentViewController:activityViewController animated:YES completion:^{}];
    }
    self.isPresentingActivities = YES;
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
        [self.storyPageControl becomeFirstResponder];
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
    self.dictSavedStoryTags = nil;
    self.dictSavedStoryFeedCounts = nil;
    self.dictFolders = nil;
    self.dictFoldersArray = nil;
    self.userActivitiesArray = nil;
    self.userInteractionsArray = nil;
    self.dictUnreadCounts = nil;
    self.dictTextFeeds = nil;
    
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
        if (navigationController.isViewLoaded && navigationController.view.window) {
            if ([self.navigationController visibleViewController] == loginViewController) {
                NSLog(@"Already showing login!");
                return;
            }
            [self.navigationController presentViewController:loginViewController animated:NO completion:nil];
        }
    }
}

- (void)showFirstTimeUser {
//    [self.feedsViewController changeToAllMode];
    
    UINavigationController *ftux = [[UINavigationController alloc] initWithRootViewController:self.firstTimeUserViewController];
    
    self.ftuxNavigationController = ftux;
    self.ftuxNavigationController.navigationBar.translucent = NO;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [masterContainerViewController dismissViewControllerAnimated:NO completion:nil];
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
        [masterContainerViewController dismissViewControllerAnimated:NO completion:nil];
        moveSiteViewController.modalPresentationStyle=UIModalPresentationFormSheet;
        [navController presentViewController:moveSiteViewController animated:YES completion:nil];
    } else {
        [self hidePopover];
        [navController presentViewController:moveSiteViewController animated:YES completion:nil];
    }
}

- (void)openTrainSite {
    [self hidePopover];
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
    trainerViewController.feedLoaded = YES;
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

- (void)openUserTagsStory:(id)sender {
    if (!self.userTagsViewController) {
        self.userTagsViewController = [[UserTagsViewController alloc] init];
    }
    
    [self.userTagsViewController view]; // Force viewDidLoad
    CGRect frame = [sender CGRectValue];
    [self showPopoverWithViewController:self.userTagsViewController contentSize:CGSizeMake(220, 382) sourceView:self.storyPageControl.view sourceRect:frame];
}

#pragma mark - UIPopoverPresentationControllerDelegate

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    [self.navigationController.topViewController becomeFirstResponder];
}

#pragma mark -

- (void)reloadFeedsView:(BOOL)showLoader {
    [feedsViewController fetchFeedList:showLoader];
}

- (void)loadFeedDetailView {
    [self loadFeedDetailView:YES];
}

- (void)loadFeedDetailView:(BOOL)transition {
    self.inFeedDetail = YES;
    popoverHasFeedView = YES;

    [feedDetailViewController resetFeedDetail];
    if (feedDetailViewController == dashboardViewController.storiesModule) {
        feedDetailViewController.storiesCollection = dashboardViewController.storiesModule.storiesCollection;
    } else {
        feedDetailViewController.storiesCollection = storiesCollection;
    }
    
    if (transition) {
        UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc]
                                          initWithTitle: @"All"
                                          style: UIBarButtonItemStylePlain
                                          target: nil
                                          action: nil];
        [feedsViewController.navigationItem setBackBarButtonItem:newBackButton];

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.masterContainerViewController transitionToFeedDetail];
        } else {
            [navigationController pushViewController:feedDetailViewController
                                            animated:YES];
        }
    }
    
    [self flushQueuedReadStories:NO withCallback:^{
        [feedDetailViewController fetchFeedDetail:1 withCallback:nil];
    }];
    
}

- (void)loadTryFeedDetailView:(NSString *)feedId
                    withStory:(NSString *)contentId
                     isSocial:(BOOL)social
                     withUser:(NSDictionary *)user
             showFindingStory:(BOOL)showHUD {
    NSDictionary *feed = [self getFeed:feedId];
    
    if (social) {
        storiesCollection.isSocialView = YES;
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
        storiesCollection.isSocialView = NO;
        [self setInFindingStoryMode:NO];
    }
            
    self.tryFeedStoryId = contentId;
    storiesCollection.activeFeed = feed;
    storiesCollection.activeFolder = nil;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self loadFeedDetailView];
    } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.navigationController popToRootViewControllerAnimated:NO];
        [self hidePopoverAnimated:YES completion:^{
            if (self.navigationController.presentedViewController) {
                [self.navigationController dismissViewControllerAnimated:YES completion:^{
                    [self loadFeedDetailView];
                }];
            } else {
                [self loadFeedDetailView];
            }
        }];
    }
}

- (void)loadStarredDetailViewWithStory:(NSString *)contentId
                      showFindingStory:(BOOL)showHUD {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.navigationController popToRootViewControllerAnimated:NO];
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        [self hidePopoverAnimated:NO];
    }

    self.inFindingStoryMode = YES;
    [storiesCollection reset];
    storiesCollection.isRiverView = YES;
    
    self.tryFeedStoryId = contentId;
    storiesCollection.activeFolder = @"saved_stories";
    
    [self loadRiverFeedDetailView:feedDetailViewController withFolder:@"saved_stories"];
    
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

- (BOOL)isSavedFeed:(NSString *)feedIdStr {
    return [feedIdStr startsWith:@"saved:"];
}

- (NSInteger)savedStoriesCountForFeed:(NSString *)feedIdStr {
    return [self.dictSavedStoryFeedCounts[feedIdStr] integerValue];
}

- (BOOL)isSavedStoriesIntelligenceMode {
    return self.selectedIntelligence == 2;
}

- (NSArray *)allFeedIds {
    NSMutableArray *mutableFeedIds = [NSMutableArray array];
    
    for (NSString *folderName in self.dictFoldersArray) {
        for (id feedId in self.dictFolders[folderName]) {
            if (![feedId isKindOfClass:[NSString class]] || ![self isSavedFeed:feedId]) {
                [mutableFeedIds addObject:feedId];
            }
        }
    }
    
    return mutableFeedIds;
}

- (NSArray *)feedIdsForFolderTitle:(NSString *)folderTitle {
    if ([folderTitle isEqualToString:@"everything"]) {
        return @[folderTitle];
    } else {
        return self.dictFolders[folderTitle];
    }
}

- (BOOL)isPortrait {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;        
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isCompactWidth {
    return self.compactWidth > 0.0;
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
        [masterContainerViewController dismissViewControllerAnimated:NO completion:nil];
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
                                       self.url]];
    ASIHTTPRequest *_request = [ASIHTTPRequest requestWithURL:url];
    __weak ASIHTTPRequest *request = _request;
    [request setValidatesSecureCertificate:NO];
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

- (void)refreshFeedCount:(id)feedId {
    [feedsViewController fadeFeed:feedId];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 1) { // this is logout
        if (buttonIndex == 0) {
            return;
        } else {
            NSLog(@"Logging out...");
            NSString *urlS = [NSString stringWithFormat:@"%@/reader/logout?api=1",
                              self.url];
            NSURL *url = [NSURL URLWithString:urlS];
            
            __block ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
            [request setValidatesSecureCertificate:NO];
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

- (void)loadRiverFeedDetailView:(FeedDetailViewController *)feedDetailView withFolder:(NSString *)folder {
    self.readStories = [NSMutableArray array];
    NSMutableArray *feeds = [NSMutableArray array];
    BOOL transferFromDashboard = [folder isEqualToString:@"river_dashboard"];
    
    self.inFeedDetail = YES;
    [feedDetailView resetFeedDetail];
    if (feedDetailView == dashboardViewController.storiesModule) {
        feedDetailView.storiesCollection = dashboardViewController.storiesModule.storiesCollection;
    } else if (feedDetailView == feedDetailViewController) {
        feedDetailView.storiesCollection = storiesCollection;
    }

    [feedDetailView.storiesCollection reset];

    if (transferFromDashboard) {
        StoriesCollection *dashboardCollection = dashboardViewController.storiesModule.storiesCollection;
        [feedDetailView.storiesCollection transferStoriesFromCollection:dashboardCollection];
        feedDetailView.storiesCollection.isRiverView = YES;
        feedDetailView.storiesCollection.transferredFromDashboard = YES;
        [feedDetailView.storiesCollection setActiveFolder:@"everything"];
    } else {
        if ([folder isEqualToString:@"river_global"]) {
            feedDetailView.storiesCollection.isSocialRiverView = YES;
            feedDetailView.storiesCollection.isRiverView = YES;
            [feedDetailView.storiesCollection setActiveFolder:@"river_global"];
        } else if ([folder isEqualToString:@"river_blurblogs"]) {
            feedDetailView.storiesCollection.isSocialRiverView = YES;
            feedDetailView.storiesCollection.isRiverView = YES;
            // add all the feeds from every NON blurblog folder
            [feedDetailView.storiesCollection setActiveFolder:@"river_blurblogs"];
            for (NSString *folderName in self.feedsViewController.activeFeedLocations) {
                if ([folderName isEqualToString:@"river_blurblogs"]) { // remove all blurblugs which is a blank folder name
                    NSArray *originalFolder = [self.dictFolders objectForKey:folderName];
                    NSArray *folderFeeds = [self.feedsViewController.activeFeedLocations objectForKey:folderName];
                    for (int l=0; l < [folderFeeds count]; l++) {
                        [feeds addObject:[originalFolder objectAtIndex:[[folderFeeds objectAtIndex:l] intValue]]];
                    }
                }
            }
        } else if ([folder isEqualToString:@"everything"]) {
            feedDetailView.storiesCollection.isRiverView = YES;
            // add all the feeds from every NON blurblog folder
            [feedDetailView.storiesCollection setActiveFolder:@"everything"];
            for (NSString *folderName in self.feedsViewController.activeFeedLocations) {
                if ([folderName isEqualToString:@"river_blurblogs"]) continue;
                if ([folderName isEqualToString:@"read_stories"]) continue;
                if ([folderName isEqualToString:@"saved_stories"]) continue;
                NSArray *originalFolder = [self.dictFolders objectForKey:folderName];
                NSArray *folderFeeds = [self.feedsViewController.activeFeedLocations objectForKey:folderName];
                for (int l=0; l < [folderFeeds count]; l++) {
                    [feeds addObject:[originalFolder objectAtIndex:[[folderFeeds objectAtIndex:l] intValue]]];
                }
            }
            [self.folderCountCache removeAllObjects];
        } else {
            feedDetailView.storiesCollection.isRiverView = YES;
            NSString *folderName = [self.dictFoldersArray objectAtIndex:[folder intValue]];
            
            if ([folder isEqualToString:@"saved_stories"] || [folderName isEqualToString:@"saved_stories"]) {
                feedDetailView.storiesCollection.isSavedView = YES;
                [feedDetailView.storiesCollection setActiveFolder:@"saved_stories"];
            } else if ([folder isEqualToString:@"read_stories"] || [folderName isEqualToString:@"read_stories"]) {
                feedDetailView.storiesCollection.isReadView = YES;
                [feedDetailView.storiesCollection setActiveFolder:@"read_stories"];
            } else {
                [feedDetailView.storiesCollection setActiveFolder:folderName];
            }
            NSArray *originalFolder = [self.dictFolders objectForKey:folderName];
            NSArray *activeFeedLocations = [self.feedsViewController.activeFeedLocations objectForKey:folderName];
            for (int l=0; l < [activeFeedLocations count]; l++) {
                [feeds addObject:[originalFolder objectAtIndex:[[activeFeedLocations objectAtIndex:l] intValue]]];
            }
            
        }
        feedDetailView.storiesCollection.activeFolderFeeds = feeds;
        NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
        if (!self.feedsViewController.viewShowingAllFeeds &&
            [preferences boolForKey:@"show_feeds_after_being_read"]) {
            for (id feedId in feeds) {
                NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
                [self.feedsViewController.stillVisibleFeeds setObject:[NSNumber numberWithBool:YES] forKey:feedIdStr];
            }
        }
    }
    
    if (feedDetailView.storiesCollection.activeFolder) {
        [self.folderCountCache removeObjectForKey:feedDetailView.storiesCollection.activeFolder];
    }
    
    if (feedDetailView == feedDetailViewController) {
        UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle: @"All"
                                                                          style: UIBarButtonItemStylePlain
                                                                         target: nil
                                                                         action: nil];
        [feedsViewController.navigationItem setBackBarButtonItem: newBackButton];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.masterContainerViewController transitionToFeedDetail];
        } else {
            UINavigationController *navController = self.navigationController;
            [navController pushViewController:feedDetailViewController animated:YES];
        }
    }
    
    if (!transferFromDashboard) {
        [self flushQueuedReadStories:NO withCallback:^{
            [feedDetailView fetchRiver];
        }];
    } else {
        [feedDetailView reloadData];
    }
}

- (void)openDashboardRiverForStory:(NSString *)contentId
                  showFindingStory:(BOOL)showHUD {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.navigationController popToRootViewControllerAnimated:NO];
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        [self hidePopoverAnimated:NO];
    }
    
    self.inFindingStoryMode = YES;
    [storiesCollection reset];
    storiesCollection.isRiverView = YES;
    
    self.tryFeedStoryId = contentId;
    storiesCollection.activeFolder = @"everything";
    
    [self loadRiverFeedDetailView:feedDetailViewController withFolder:@"river_dashboard"];
    
    if (showHUD) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.storyPageControl showShareHUD:@"Finding story..."];
        } else {
            MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.feedDetailViewController.view animated:YES];
            HUD.labelText = @"Finding story...";
        }
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
    
    for (NSDictionary *story in storiesCollection.activeFeedStories) {
        NSString *storyFeedId = [NSString stringWithFormat:@"%@",
                                 [story objectForKey:@"story_feed_id"]];
        if (![storyFeedId isEqualToString:feedIdStr]) {
            [newFeedStories addObject:story];
            continue;
        }

        NSMutableDictionary *newStory = [story mutableCopy];

        // If the story is visible, mark it as sticky so it doesn't go away on page loads.
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
        NSDictionary *classifiers = [storiesCollection.activeClassifiers objectForKey:feedIdStr];
        
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
    
    storiesCollection.activeFeedStories = newFeedStories;
}

- (void)changeActiveFeedDetailRow {
    [feedDetailViewController changeActiveFeedDetailRow];
}

- (void)loadStoryDetailView {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone || self.isCompactWidth) {
        [navigationController pushViewController:storyPageControl animated:YES];
        navigationController.navigationItem.hidesBackButton = YES;
    }

    NSInteger activeStoryLocation = [storiesCollection locationOfActiveStory];
    if (activeStoryLocation >= 0) {
        BOOL animated = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
                         !self.tryFeedCategory);
        [self.storyPageControl view];
        [self.storyPageControl.view setNeedsLayout];
        [self.storyPageControl.view layoutIfNeeded];
        
        NSDictionary *params = @{@"location" : @(activeStoryLocation), @"animated" : @(animated)};
        
        if (self.isCompactWidth) {
            [self performSelector:@selector(deferredChangePage:) withObject:params afterDelay:0.0];
        } else {
            [self deferredChangePage:params];
        }
    }

    [MBProgressHUD hideHUDForView:self.storyPageControl.view animated:YES];
}

- (void)deferredChangePage:(NSDictionary *)params {
    [self.storyPageControl changePage:[params[@"location"] integerValue] animated:[params[@"animated"] boolValue]];
    [self.storyPageControl animateIntoPlace:YES];
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
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    if ([[preferences stringForKey:@"story_browser"] isEqualToString:@"safari"]) {
        [[UIApplication sharedApplication] openURL:url];
        return;
    } else if ([[preferences stringForKey:@"story_browser"] isEqualToString:@"chrome"] &&
               [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"googlechrome-x-callback://"]]) {
        NSString *openingURL = [url.absoluteString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSURL *callbackURL = [NSURL URLWithString:@"newsblur://"];
        NSString *callback = [callbackURL.absoluteString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *sourceName = [[[NSBundle mainBundle]objectForInfoDictionaryKey:@"CFBundleName"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSURL *activityURL = [NSURL URLWithString:
                              [NSString stringWithFormat:@"googlechrome-x-callback://x-callback-url/open/?url=%@&x-success=%@&x-source=%@",
                               openingURL,
                               callback,
                               sourceName]];
        
        [[UIApplication sharedApplication] openURL:activityURL];
        return;
    } else if ([[preferences stringForKey:@"story_browser"] isEqualToString:@"opera_mini"] &&
               [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"opera-http://"]]) {

                   
        NSString *operaURL;
        NSRange prefix = [[url absoluteString] rangeOfString: @"http"];
        if (NSNotFound != prefix.location) {
            operaURL = [[url absoluteString]
                        stringByReplacingCharactersInRange: prefix
                        withString:                         @"opera-http"];
        }
                   
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:operaURL]];
        return;
    } else if ([[preferences stringForKey:@"story_browser"] isEqualToString:@"inappsafari"]) {
        self.safariViewController = [[SFSafariViewController alloc] initWithURL:url
                                                        entersReaderIfAvailable:NO];
        self.safariViewController.delegate = self;
        [navigationController presentViewController:self.safariViewController animated:YES completion:nil];
    } else {
        if (!originalStoryViewController) {
            originalStoryViewController = [[OriginalStoryViewController alloc] init];
        }
        
        self.activeOriginalStoryURL = url;
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.masterContainerViewController transitionToOriginalView];
        } else {
            if ([[navigationController viewControllers]
                 containsObject:originalStoryViewController]) {
                return;
            }
            [navigationController pushViewController:originalStoryViewController
                                            animated:YES];
            [originalStoryViewController view]; // Force viewDidLoad
            [originalStoryViewController loadInitialStory];
        }
    }
}

- (BOOL)showingSafariViewController {
    return self.safariViewController.delegate != nil;
}

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    // You'd think doing this in the dismiss completion block would work... but nope.
    [self performSelector:@selector(deferredSafariCleanup) withObject:nil afterDelay:0.2];
    controller.delegate = nil;
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)deferredSafariCleanup {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.navigationController.view.frame = CGRectMake(self.navigationController.view.frame.origin.x, self.navigationController.view.frame.origin.y, self.isPortrait ? 270.0 : 370.0, self.navigationController.view.frame.size.height);
    }
    
    [self.storyPageControl reorientPages];
}

- (void)navigationController:(UINavigationController *)_navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ([viewController isKindOfClass:[SFSafariViewController class]] || [viewController isKindOfClass:[FontSettingsViewController class]] || [viewController isKindOfClass:[feedDetailMenuViewController class]]) {
        [_navigationController setNavigationBarHidden:YES animated:YES];
    } else {
        [_navigationController setNavigationBarHidden:NO animated:YES];
    }
}

- (UINavigationController *)addSiteNavigationController {
    if (!_addSiteNavigationController) {
        self.addSiteNavigationController = [[UINavigationController alloc] initWithRootViewController:self.addSiteViewController];
        self.addSiteNavigationController.delegate = self;
    }
    
    return _addSiteNavigationController;
}

- (UINavigationController *)fontSettingsNavigationController {
    if (!_fontSettingsNavigationController) {
        self.fontSettingsNavigationController = [[UINavigationController alloc] initWithRootViewController:self.fontSettingsViewController];
        self.fontSettingsNavigationController.delegate = self;
    }
    
    return _fontSettingsNavigationController;
}

- (UINavigationController *)feedDetailMenuNavigationController {
    if (!_feedDetailMenuNavigationController) {
        self.feedDetailMenuNavigationController = [[UINavigationController alloc] initWithRootViewController:self.feedDetailMenuViewController];
        self.feedDetailMenuNavigationController.delegate = self;
    }
    
    return _feedDetailMenuNavigationController;
}

- (void)closeOriginalStory {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController transitionFromOriginalView];
    } else {
        if ([[navigationController viewControllers] containsObject:originalStoryViewController]) {
            [navigationController popToViewController:storyPageControl animated:YES];
        }
    }
}

- (void)hideStoryDetailView {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.masterContainerViewController transitionFromFeedDetail];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Text View

- (void)populateDictTextFeeds {
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSDictionary *textFeeds = [preferences dictionaryForKey:@"feeds:text"];
    if (!textFeeds) {
        self.dictTextFeeds = [[NSMutableDictionary alloc] init];
    } else {
        self.dictTextFeeds = [textFeeds mutableCopy];
    }
    
}

- (BOOL)isFeedInTextView:(id)feedId {
    return [self.dictTextFeeds objectForKey:feedId];
}

- (void)toggleFeedTextView:(id)feedId {
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    if ([self.dictTextFeeds objectForKey:feedId]) {
        [self.dictTextFeeds removeObjectForKey:feedId];
    } else {
        [self.dictTextFeeds setObject:[NSNumber numberWithBool:YES] forKey:feedId];
    }
    
    [preferences setObject:self.dictTextFeeds forKey:@"feeds:text"];
    [preferences synchronize];
}

#pragma mark - Unread Counts

- (void)populateDictUnreadCounts {    
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
    if (storiesCollection.isRiverView || storiesCollection.isSocialRiverView) {
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
        NSString *feedIdStr = [NSString stringWithFormat:@"%@", [storiesCollection.activeFeed objectForKey:@"id"]];
        feed = [self.dictUnreadCounts objectForKey:feedIdStr];
    }
    
    total += [[feed objectForKey:@"ps"] intValue];
    if (self.isSavedStoriesIntelligenceMode) {
        NSInteger savedCount = [self.dictSavedStoryFeedCounts[feedId] integerValue];
        total += savedCount;
    }
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
        (!folderName && [storiesCollection.activeFolder isEqual:@"river_blurblogs"])) {
        for (id feedId in self.dictSocialFeeds) {
            total += [self unreadCountForFeed:feedId];
        }
    } else if ([folderName isEqual:@"river_global"] ||
               (!folderName && [storiesCollection.activeFolder isEqual:@"river_global"])) {
        total = 0;
    } else if ([folderName isEqual:@"everything"] ||
               (!folderName && [storiesCollection.activeFolder isEqual:@"everything"])) {
        // TODO: Fix race condition where self.dictUnreadCounts can be changed while being updated.
        for (id feedId in self.dictUnreadCounts) {
            total += [self unreadCountForFeed:feedId];
        }
    } else {
        if (!folderName) {
            folder = [self.dictFolders objectForKey:storiesCollection.activeFolder];
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
        feedId = [storiesCollection.activeFeed objectForKey:@"id"];
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
        (!folderName && [storiesCollection.activeFolder isEqual:@"river_blurblogs"])) {
        for (id feedId in self.dictSocialFeeds) {
            [counts addCounts:[self splitUnreadCountForFeed:feedId]];
        }
    } else if ([folderName isEqual:@"river_global"] ||
            (!folderName && [storiesCollection.activeFolder isEqual:@"river_global"])) {
        // Nothing for global
    } else if ([folderName isEqual:@"everything"] ||
               (!folderName && [storiesCollection.activeFolder isEqual:@"everything"])) {
        for (NSArray *folder in [self.dictFolders allValues]) {
            for (id feedId in folder) {
                if ([feedId isKindOfClass:[NSString class]] && [feedId startsWith:@"saved:"]) {
                    // Skip saved feeds which have fake unread counts.
                    continue;
                }
                [counts addCounts:[self splitUnreadCountForFeed:feedId]];
            }
        }
    } else {
        if (!folderName) {
            folder = [self.dictFolders objectForKey:storiesCollection.activeFolder];
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

- (BOOL)isFolderCollapsed:(NSString *)folderName {
    if (!self.collapsedFolders) {
        self.collapsedFolders = [[NSMutableDictionary alloc] init];
        NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
        for (NSString *folderName in self.dictFoldersArray) {
            NSString *collapseKey = [NSString stringWithFormat:@"folderCollapsed:%@",
                                     folderName];
            if ([userPreferences boolForKey:collapseKey]) {
                [self.collapsedFolders setObject:folderName forKey:folderName];
            }
        }
    }
    return !![self.collapsedFolders objectForKey:folderName];
}

#pragma mark - Story Management

- (NSDictionary *)markVisibleStoriesRead {
    NSMutableDictionary *feedsStories = [NSMutableDictionary dictionary];
    for (NSDictionary *story in storiesCollection.activeFeedStories) {
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
        [storiesCollection markStoryRead:story feed:feed];
    }   
    return feedsStories;
}

#pragma mark -
#pragma mark Mark as read

- (void)markActiveFolderAllRead {
    if ([storiesCollection.activeFolder isEqual:@"everything"]) {
        for (NSString *folderName in self.dictFoldersArray) {
            for (id feedId in [self.dictFolders objectForKey:folderName]) {
                [self markFeedAllRead:feedId];
            }        
        }
    } else {
        for (id feedId in [self.dictFolders objectForKey:storiesCollection.activeFolder]) {
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
    [self markFeedReadInCache:feedIds cutoffTimestamp:cutoff older:YES];
}

- (void)markFeedReadInCache:(NSArray *)feedIds cutoffTimestamp:(NSInteger)cutoff older:(BOOL)older {
    for (NSString *feedId in feedIds) {
        NSString *feedIdString = [NSString stringWithFormat:@"%@", feedId];
        NSDictionary *unreadCounts = [self.dictUnreadCounts objectForKey:feedIdString];
        NSMutableDictionary *newUnreadCounts = [unreadCounts mutableCopy];
        NSMutableArray *stories = [NSMutableArray array];
        NSString *direction = older ? @"<" : @">";
        
        [self.database inDatabase:^(FMDatabase *db) {
            NSString *sql = [NSString stringWithFormat:@"SELECT * FROM stories s "
                             "INNER JOIN unread_hashes uh ON s.story_hash = uh.story_hash "
                             "WHERE s.story_feed_id = %@ AND s.story_timestamp %@ %ld",
                             feedIdString, direction, (long)cutoff];
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
            [self.dictUnreadCounts setObject:newUnreadCounts forKey:feedIdString];
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
                                   feedIdString, (long)cutoff];
            [db executeUpdate:deleteSql];
            [db executeUpdate:@"UPDATE unread_counts SET ps = ?, nt = ?, ng = ? WHERE feed_id = ?",
             [newUnreadCounts objectForKey:@"ps"],
             [newUnreadCounts objectForKey:@"nt"],
             [newUnreadCounts objectForKey:@"ng"],
             feedIdString];
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

- (void)finishMarkAsRead:(NSDictionary *)story {
    if (!storyPageControl.previousPage || !storyPageControl.currentPage || !storyPageControl.nextPage) return;
    for (StoryDetailViewController *page in @[storyPageControl.previousPage,
                                              storyPageControl.currentPage,
                                              storyPageControl.nextPage]) {
        if ([[page.activeStory objectForKey:@"story_hash"]
             isEqualToString:[story objectForKey:@"story_hash"]] && page.isRecentlyUnread) {
            page.isRecentlyUnread = NO;
            [storyPageControl refreshHeaders];
        }
    }
}

- (void)finishMarkAsUnread:(NSDictionary *)story {
    if (!storyPageControl.previousPage || !storyPageControl.currentPage || !storyPageControl.nextPage) return;
    for (StoryDetailViewController *page in @[storyPageControl.previousPage,
                                              storyPageControl.currentPage,
                                              storyPageControl.nextPage]) {
        if ([[page.activeStory objectForKey:@"story_hash"]
             isEqualToString:[story objectForKey:@"story_hash"]]) {
            page.isRecentlyUnread = YES;
            [storyPageControl refreshHeaders];
        }
    }
    [storyPageControl setNextPreviousButtons];
    originalStoryCount += 1;
}

- (void)failedMarkAsUnread:(ASIFormDataRequest *)request {
    if (![storyPageControl failedMarkAsUnread:request]) {
        [feedDetailViewController failedMarkAsUnread:request];
        [dashboardViewController.storiesModule failedMarkAsUnread:request];
    }
    [feedDetailViewController reloadData];
    [dashboardViewController.storiesModule reloadData];
}

- (void)finishMarkAsSaved:(ASIFormDataRequest *)request {
    [storyPageControl finishMarkAsSaved:request];
    [feedDetailViewController finishMarkAsSaved:request];
}

- (void)failedMarkAsSaved:(ASIFormDataRequest *)request {
    if (![storyPageControl failedMarkAsSaved:request]) {
        [feedDetailViewController failedMarkAsSaved:request];
        [dashboardViewController.storiesModule failedMarkAsSaved:request];
    }
    [feedDetailViewController reloadData];
    [dashboardViewController.storiesModule reloadData];
}

- (void)finishMarkAsUnsaved:(ASIFormDataRequest *)request {
    [storyPageControl finishMarkAsUnsaved:request];
    [feedDetailViewController finishMarkAsUnsaved:request];
}

- (void)failedMarkAsUnsaved:(ASIFormDataRequest *)request {
    if (![storyPageControl failedMarkAsUnsaved:request]) {
        [feedDetailViewController failedMarkAsUnsaved:request];
        [dashboardViewController.storiesModule failedMarkAsUnsaved:request];
    }
    [feedDetailViewController reloadData];
    [dashboardViewController.storiesModule reloadData];
}


- (NSInteger)adjustSavedStoryCount:(NSString *)tagName direction:(NSInteger)direction {
    NSString *savedTagId = [NSString stringWithFormat:@"saved:%@", tagName];
    NSMutableDictionary *newTag = [[self.dictSavedStoryTags objectForKey:savedTagId] mutableCopy];
    if (!newTag) {
        newTag = [@{@"ps": [NSNumber numberWithInt:0],
                    @"feed_title": tagName
                    } mutableCopy];
    }
    NSInteger newCount = [[newTag objectForKey:@"ps"] integerValue] + direction;
    [newTag setObject:[NSNumber numberWithInteger:newCount] forKey:@"ps"];
    NSMutableDictionary *savedStoryDict = [[NSMutableDictionary alloc] init];
    for (NSString *tagId in [self.dictSavedStoryTags allKeys]) {
        if ([tagId isEqualToString:savedTagId]) {
            if (newCount > 0) {
                [savedStoryDict setObject:newTag forKey:tagId];
            }
        } else {
            [savedStoryDict setObject:[self.dictSavedStoryTags objectForKey:tagId]
                               forKey:tagId];
        }
    }
    
    // If adding a tag, it won't already be in dictSavedStoryTags
    if (![self.dictSavedStoryTags objectForKey:savedStoryDict] && newCount > 0) {
        [savedStoryDict setObject:newTag forKey:savedTagId];
    }
    self.dictSavedStoryTags = savedStoryDict;
    
    return newCount;
}

- (NSArray *)updateStarredStoryCounts:(NSDictionary *)results {
    if ([results objectForKey:@"starred_count"]) {
        self.savedStoriesCount = [[results objectForKey:@"starred_count"] intValue];
    }
    
    if (!self.savedStoriesCount) return [[NSArray alloc] init];
    
    NSMutableDictionary *savedStoryDict = [NSMutableDictionary dictionary];
    NSMutableDictionary *savedStoryFeedCounts = [NSMutableDictionary dictionary];
    NSMutableArray *savedStories = [NSMutableArray array];
    
    if (![results objectForKey:@"starred_counts"] ||
        [[results objectForKey:@"starred_counts"] isKindOfClass:[NSNull class]]) {
        return savedStories;
    }
    
    for (NSDictionary *userTag in [results objectForKey:@"starred_counts"]) {
        id feedId = [userTag objectForKey:@"feed_id"];
        
        if (![feedId isKindOfClass:[NSNull class]]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
            savedStoryFeedCounts[feedIdStr] = userTag[@"count"];
            
            continue;
        }
        
        if ([[userTag objectForKey:@"tag"] isKindOfClass:[NSNull class]] ||
            [[userTag objectForKey:@"tag"] isEqualToString:@""]) continue;
        NSString *savedTagId = [NSString stringWithFormat:@"saved:%@", [userTag objectForKey:@"tag"]];
        NSDictionary *savedTag = @{@"ps": [userTag objectForKey:@"count"],
                                   @"feed_title": [userTag objectForKey:@"tag"],
                                   @"id": [userTag objectForKey:@"tag"],
                                   @"tag": [userTag objectForKey:@"tag"]};
        [savedStories addObject:savedTagId];
        [savedStoryDict setObject:savedTag forKey:savedTagId];
        [self.dictUnreadCounts setObject:@{@"ps": [userTag objectForKey:@"count"],
                                                  @"nt": [NSNumber numberWithInt:0],
                                                  @"ng": [NSNumber numberWithInt:0]}
                                         forKey:savedTagId];
    }

    self.dictSavedStoryTags = savedStoryDict;
    self.dictSavedStoryFeedCounts = savedStoryFeedCounts;
    
    return savedStories;
}

- (void)renameFeed:(NSString *)newTitle {
    NSMutableDictionary *newActiveFeed = [storiesCollection.activeFeed mutableCopy];
    [newActiveFeed setObject:newTitle forKey:@"feed_title"];
    storiesCollection.activeFeed = newActiveFeed;
}

- (void)renameFolder:(NSString *)newTitle {
    storiesCollection.activeFolder = newTitle;
}

- (void)showMarkReadMenuWithFeedIds:(NSArray *)feedIds collectionTitle:(NSString *)collectionTitle visibleUnreadCount:(NSInteger)visibleUnreadCount barButtonItem:(UIBarButtonItem *)barButtonItem completionHandler:(void (^)(BOOL marked))completionHandler {
    [self showMarkReadMenuWithFeedIds:feedIds collectionTitle:collectionTitle visibleUnreadCount:visibleUnreadCount olderNewerCollection:nil olderNewerStory:nil barButtonItem:barButtonItem sourceView:nil sourceRect:CGRectZero extraItems:nil completionHandler:completionHandler];
}

- (void)showMarkReadMenuWithFeedIds:(NSArray *)feedIds collectionTitle:(NSString *)collectionTitle sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect completionHandler:(void (^)(BOOL marked))completionHandler {
    [self showMarkReadMenuWithFeedIds:feedIds collectionTitle:collectionTitle visibleUnreadCount:0 olderNewerCollection:nil olderNewerStory:nil barButtonItem:nil sourceView:sourceView sourceRect:sourceRect extraItems:nil completionHandler:completionHandler];
}

- (void)showMarkOlderNewerReadMenuWithStoriesCollection:(StoriesCollection *)olderNewerCollection story:(NSDictionary *)olderNewerStory sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect extraItems:(NSArray *)extraItems completionHandler:(void (^)(BOOL marked))completionHandler {
    [self showMarkReadMenuWithFeedIds:nil collectionTitle:nil visibleUnreadCount:0 olderNewerCollection:storiesCollection olderNewerStory:olderNewerStory barButtonItem:nil sourceView:sourceView sourceRect:sourceRect extraItems:extraItems completionHandler:completionHandler];
}

- (void)showMarkReadMenuWithFeedIds:(NSArray *)feedIds collectionTitle:(NSString *)collectionTitle visibleUnreadCount:(NSInteger)visibleUnreadCount olderNewerCollection:(StoriesCollection *)olderNewerCollection olderNewerStory:(NSDictionary *)olderNewerStory barButtonItem:(UIBarButtonItem *)barButtonItem sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect extraItems:(NSArray *)extraItems completionHandler:(void (^)(BOOL marked))completionHandler {
    if (!self.markReadMenuViewController) {
        self.markReadMenuViewController = [MarkReadMenuViewController new];
        self.markReadMenuViewController.modalPresentationStyle = UIModalPresentationPopover;
    }
    
    self.markReadMenuViewController.collectionTitle = collectionTitle;
    self.markReadMenuViewController.feedIds = feedIds;
    self.markReadMenuViewController.visibleUnreadCount = visibleUnreadCount;
    self.markReadMenuViewController.olderNewerStoriesCollection = olderNewerCollection;
    self.markReadMenuViewController.olderNewerStory = olderNewerStory;
    self.markReadMenuViewController.extraItems = extraItems;
    self.markReadMenuViewController.completionHandler = completionHandler;

    [self showPopoverWithViewController:self.markReadMenuViewController contentSize:CGSizeZero barButtonItem:barButtonItem sourceView:sourceView sourceRect:sourceRect permittedArrowDirections:UIPopoverArrowDirectionAny];
}

- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize barButtonItem:(UIBarButtonItem *)barButtonItem {
    [self showPopoverWithViewController:viewController contentSize:contentSize barButtonItem:barButtonItem sourceView:nil sourceRect:CGRectZero permittedArrowDirections:UIPopoverArrowDirectionAny];
}

- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect {
    [self showPopoverWithViewController:viewController contentSize:contentSize barButtonItem:nil sourceView:sourceView sourceRect:sourceRect permittedArrowDirections:UIPopoverArrowDirectionAny];
}

- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect permittedArrowDirections:(UIPopoverArrowDirection)permittedArrowDirections {
    [self showPopoverWithViewController:viewController contentSize:contentSize barButtonItem:nil sourceView:sourceView sourceRect:sourceRect permittedArrowDirections:permittedArrowDirections];
}

- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize barButtonItem:(UIBarButtonItem *)barButtonItem sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect permittedArrowDirections:(UIPopoverArrowDirection)permittedArrowDirections {
    if (viewController == self.navigationControllerForPopover.presentedViewController) {
        return; // nothing to do, already showing this controller
    }
    
    [self hidePopoverAnimated:YES];
    
    viewController.modalPresentationStyle = UIModalPresentationPopover;
    viewController.preferredContentSize = contentSize;
    
    if ([viewController respondsToSelector:@selector(addKeyCommand:)]) {
        [viewController addKeyCommand:[UIKeyCommand keyCommandWithInput:@"." modifierFlags:UIKeyModifierCommand action:@selector(hidePopover)]];
        [viewController addKeyCommand:[UIKeyCommand keyCommandWithInput:UIKeyInputEscape modifierFlags:0 action:@selector(hidePopover)]];
    }
    
    UIPopoverPresentationController *popoverPresentationController = viewController.popoverPresentationController;
    popoverPresentationController.delegate = self;
    popoverPresentationController.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    popoverPresentationController.permittedArrowDirections = permittedArrowDirections;
    
    if (barButtonItem) {
        popoverPresentationController.barButtonItem = barButtonItem;
    } else {
        popoverPresentationController.sourceView = sourceView;
        popoverPresentationController.sourceRect = sourceRect;
    }
    
    [self.navigationControllerForPopover presentViewController:viewController animated:YES completion:^{
        popoverPresentationController.passthroughViews = nil;
        // NSLog(@"%@ canBecomeFirstResponder? %d", viewController, viewController.canBecomeFirstResponder);
        [viewController becomeFirstResponder];
    }];
}

- (void)hidePopoverAnimated:(BOOL)animated completion:(void (^)(void))completion {
    UIViewController *presentedViewController = self.navigationControllerForPopover.presentedViewController;
    if (!presentedViewController || presentedViewController.presentationController.presentationStyle != UIModalPresentationPopover) {
        if (completion) {
            completion();
        }
        return;
    }
    
    [presentedViewController dismissViewControllerAnimated:animated completion:completion];
    [self.navigationController.topViewController becomeFirstResponder];
}

- (BOOL)hidePopoverAnimated:(BOOL)animated {
    UIViewController *presentedViewController = self.navigationControllerForPopover.presentedViewController;
    if (!presentedViewController || presentedViewController.presentationController.presentationStyle != UIModalPresentationPopover)
        return NO;
    
    [presentedViewController dismissViewControllerAnimated:animated completion:nil];
    [self.navigationController.topViewController becomeFirstResponder];
    return YES;
}

- (void)hidePopover {
    [self hidePopoverAnimated:YES];
    [self.modalNavigationController dismissViewControllerAnimated:YES completion:nil];
}

- (UINavigationController *)navigationControllerForPopover {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return self.masterContainerViewController.masterNavigationController;
    } else {
        return self.navigationController;
    }
}

#pragma mark -
#pragma mark Story functions

+ (int)computeStoryScore:(NSDictionary *)intelligence {
    int score = 0;
    int title = [[intelligence objectForKey:@"title"] intValue];
    int author = [[intelligence objectForKey:@"author"] intValue];
    int tags = [[intelligence objectForKey:@"tags"] intValue];

    int score_max = MAX(title, MAX(author, tags));
    int score_min = MIN(title, MIN(author, tags));

    if (score_max > 0)      score = score_max;
    else if (score_min < 0) score = score_min;
    
    if (score == 0) score = [[intelligence objectForKey:@"feed"] intValue];

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

- (NSArray *)parentFoldersForFeed:(NSString *)feedId {
    NSMutableArray *folderNames = [[NSMutableArray alloc] init];
    
    for (NSString *folderName in self.dictFoldersArray) {
        NSArray *folder = [self.dictFolders objectForKey:folderName];
        if ([folder containsObject:feedId]) {
            [folderNames addObject:[self extractFolderName:folderName]];
            [folderNames addObject:[self extractParentFolderName:folderName]];
        }
    }
    NSMutableArray *uniqueFolderNames = [[NSMutableArray alloc] init];
    for (NSString *folderName in folderNames) {
        if ([uniqueFolderNames containsObject:folderName]) continue;
        if ([folderName containsString:@"Top Level"]) continue;
        if ([folderName length] < 1) continue;
        
        [uniqueFolderNames addObject:folderName];
    }
    
    return uniqueFolderNames;
}

- (NSDictionary *)getFeed:(NSString *)feedId {
    NSDictionary *feed;
    if (storiesCollection.isSocialView ||
        storiesCollection.isSocialRiverView ||
        [feedId startsWith:@"social:"]) {
        feed = [self.dictActiveFeeds objectForKey:feedId];
        // this is to catch when a user is already subscribed
        if (!feed) {
            feed = [self.dictSocialFeeds objectForKey:feedId];
        }
        if (!feed) {
            feed = [self.dictFeeds objectForKey:feedId];
        }
    } else {
        feed = [self.dictFeeds objectForKey:feedId];
    }
    
    return feed;
}

- (NSDictionary *)getStory:(NSString *)storyHash {
    for (NSDictionary *story in storiesCollection.activeFeedStories) {
        if ([[story objectForKey:@"story_hash"] isEqualToString:storyHash]) {
            return story;
        }
    }
    return nil;
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

+ (UIColor *)faviconColor:(NSString *)colorString {
    if ([colorString class] == [NSNull class] || !colorString) {
        colorString = @"505050";
    }
    unsigned int color = 0;
    NSScanner *scanner = [NSScanner scannerWithString:colorString];
    [scanner scanHexInt:&color];

    return UIColorFromFixedRGB(color);
}

+ (UIView *)makeGradientView:(CGRect)rect startColor:(NSString *)start endColor:(NSString *)end borderColor:(NSString *)borderColor {
    UIView *gradientView = [[UIView alloc] initWithFrame:rect];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0, 1, rect.size.width, rect.size.height-1);
    gradient.opacity = 0.7;
    if ([start class] == [NSNull class] || !start) {
        start = @"505050";
    }
    if ([end class] == [NSNull class] || !end) {
        end = @"303030";
    }
    gradient.colors = [NSArray arrayWithObjects:(id)[[self faviconColor:start] CGColor], (id)[[self faviconColor:end] CGColor], nil];
    
    CALayer *whiteBackground = [CALayer layer];
    whiteBackground.frame = CGRectMake(0, 1, rect.size.width, rect.size.height-1);
    whiteBackground.backgroundColor = [UIColorFromRGB(NEWSBLUR_WHITE_COLOR) colorWithAlphaComponent:0.7].CGColor;
    [gradientView.layer addSublayer:whiteBackground];
    
    [gradientView.layer addSublayer:gradient];
    
    CALayer *topBorder = [CALayer layer];
    topBorder.frame = CGRectMake(0, 1, rect.size.width, 1);
    topBorder.backgroundColor = [[self faviconColor:borderColor] colorWithAlphaComponent:0.7].CGColor;
    topBorder.opacity = 1;
    [gradientView.layer addSublayer:topBorder];
    
    CALayer *bottomBorder = [CALayer layer];
    bottomBorder.frame = CGRectMake(0, rect.size.height-1, rect.size.width, 1);
    bottomBorder.backgroundColor = [[self faviconColor:borderColor] colorWithAlphaComponent:0.7].CGColor;
    bottomBorder.opacity = 1;
    [gradientView.layer addSublayer:bottomBorder];
    
    return gradientView;
}

- (UIView *)makeFeedTitleGradient:(NSDictionary *)feed withRect:(CGRect)rect {
    UIView *gradientView;
    if (storiesCollection.isRiverView ||
        storiesCollection.isSocialView ||
        storiesCollection.isSocialRiverView ||
        storiesCollection.isSavedView ||
        storiesCollection.isReadView) {
        gradientView = [NewsBlurAppDelegate 
                        makeGradientView:rect
                        startColor:[feed objectForKey:@"favicon_fade"] 
                        endColor:[feed objectForKey:@"favicon_color"]
                        borderColor:[feed objectForKey:@"favicon_border"]];

        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = [feed objectForKey:@"feed_title"];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textAlignment = NSTextAlignmentLeft;
        titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        titleLabel.numberOfLines = 1;
        titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:11.0];
        titleLabel.shadowOffset = CGSizeMake(0, 1);
        if ([[feed objectForKey:@"favicon_text_color"] class] != [NSNull class]) {
            BOOL lightText = [[feed objectForKey:@"favicon_text_color"]
                              isEqualToString:@"white"];
            UIColor *fadeColor = [NewsBlurAppDelegate faviconColor:[feed objectForKey:@"favicon_fade"]];
            UIColor *borderColor = [NewsBlurAppDelegate faviconColor:[feed objectForKey:@"favicon_border"]];

            titleLabel.textColor = lightText ?
            UIColorFromFixedRGB(NEWSBLUR_WHITE_COLOR) :
            UIColorFromFixedRGB(NEWSBLUR_BLACK_COLOR);
            titleLabel.shadowColor = lightText ? borderColor : fadeColor;
        } else {
            titleLabel.textColor = UIColorFromFixedRGB(NEWSBLUR_WHITE_COLOR);
            titleLabel.shadowColor = UIColorFromFixedRGB(NEWSBLUR_BLACK_COLOR);
        }
        titleLabel.frame = CGRectMake(32, 1, rect.size.width-32, 20);
        
        NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
        UIImage *titleImage = [self getFavicon:feedIdStr];
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
                        endColor:[feed objectForKey:@"favicon_color"]
                        borderColor:[feed objectForKey:@"favicon_border"]];
    }
    
    gradientView.opaque = YES;
    
    return gradientView;
}

- (UIView *)makeFeedTitle:(NSDictionary *)feed {
    UILabel *titleLabel = [[UILabel alloc] init];
    if (storiesCollection.isSocialRiverView &&
        [storiesCollection.activeFolder isEqualToString:@"river_blurblogs"]) {
        titleLabel.text = [NSString stringWithFormat:@"     All Shared Stories"];
    } else if (storiesCollection.isSocialRiverView &&
               [storiesCollection.activeFolder isEqualToString:@"river_global"]) {
            titleLabel.text = [NSString stringWithFormat:@"     Global Shared Stories"];
    } else if (storiesCollection.isRiverView &&
               [storiesCollection.activeFolder isEqualToString:@"everything"]) {
        titleLabel.text = [NSString stringWithFormat:@"     All Stories"];
    } else if (storiesCollection.isSavedView && storiesCollection.activeSavedStoryTag) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            titleLabel.text = [NSString stringWithFormat:@"     %@", storiesCollection.activeSavedStoryTag];
        } else {
            titleLabel.text = [NSString stringWithFormat:@"     Saved Stories - %@", storiesCollection.activeSavedStoryTag];
        }
    } else if ([storiesCollection.activeFolder isEqualToString:@"read_stories"]) {
        titleLabel.text = [NSString stringWithFormat:@"     Read Stories"];
    } else if ([storiesCollection.activeFolder isEqualToString:@"saved_stories"]) {
        titleLabel.text = [NSString stringWithFormat:@"     Saved Stories"];
    } else if (storiesCollection.isSocialView) {
        titleLabel.text = [NSString stringWithFormat:@"     %@", [feed objectForKey:@"feed_title"]];
    } else if (storiesCollection.isRiverView) {
        titleLabel.text = [NSString stringWithFormat:@"     %@", storiesCollection.activeFolder];
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
    if (!storiesCollection.isSocialView) {
        titleLabel.center = CGPointMake(28, -2);
        NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
        UIImage *titleImage;
        if (storiesCollection.isSocialRiverView &&
            [storiesCollection.activeFolder isEqualToString:@"river_global"]) {
            titleImage = [UIImage imageNamed:@"ak-icon-global.png"];
        } else if (storiesCollection.isSocialRiverView &&
                   [storiesCollection.activeFolder isEqualToString:@"river_blurblogs"]) {
            titleImage = [UIImage imageNamed:@"ak-icon-blurblogs.png"];
        } else if (storiesCollection.isRiverView &&
                   [storiesCollection.activeFolder isEqualToString:@"everything"]) {
            titleImage = [UIImage imageNamed:@"ak-icon-allstories.png"];
        } else if (storiesCollection.isSavedView && storiesCollection.activeSavedStoryTag) {
            titleImage = [UIImage imageNamed:@"tag.png"];
        } else if ([storiesCollection.activeFolder isEqualToString:@"read_stories"]) {
            titleImage = [UIImage imageNamed:@"g_icn_folder_read.png"];
        } else if ([storiesCollection.activeFolder isEqualToString:@"saved_stories"]) {
            titleImage = [UIImage imageNamed:@"clock.png"];
        } else if (storiesCollection.isRiverView) {
            titleImage = [UIImage imageNamed:@"g_icn_folder.png"];
        } else {
            titleImage = [self getFavicon:feedIdStr];
        }
        UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
        titleImageView.frame = CGRectMake(0.0, 2.0, 16.0, 16.0);
        [titleLabel addSubview:titleImageView];
    }
    [titleLabel sizeToFit];

    return titleLabel;
}

- (void)saveFavicon:(UIImage *)image feedId:(NSString *)filename {
    if (image && filename && ![image isKindOfClass:[NSNull class]] &&
        [filename class] != [NSNull class]) {
        [self.cachedFavicons setObject:image forKey:filename];
    }
}

- (UIImage *)getFavicon:(NSString *)filename {
    return [self getFavicon:filename isSocial:NO];
}

- (UIImage *)getFavicon:(NSString *)filename isSocial:(BOOL)isSocial {
    return [self getFavicon:filename isSocial:isSocial isSaved:NO];
}

- (UIImage *)getFavicon:(NSString *)filename isSocial:(BOOL)isSocial isSaved:(BOOL)isSaved {
    UIImage *image = [self.cachedFavicons objectForKey:filename];
    
    if (image) {
        return image;
    } else {
        if (isSocial) {
            //            return [UIImage imageNamed:@"user_light.png"];
            return nil;
        } else if (isSaved) {
            return [UIImage imageNamed:@"tag.png"];            
        } else {
            return [UIImage imageNamed:@"world.png"];
        }
    }
}

#pragma mark -
#pragma mark Classifiers

- (void)toggleAuthorClassifier:(NSString *)author feedId:(NSString *)feedId {
    int authorScore = [[[[storiesCollection.activeClassifiers objectForKey:feedId]
                         objectForKey:@"authors"]
                        objectForKey:author] intValue];
    if (authorScore > 0) {
        authorScore = -1;
    } else if (authorScore < 0) {
        authorScore = 0;
    } else {
        authorScore = 1;
    }
    NSMutableDictionary *feedClassifiers = [[storiesCollection.activeClassifiers objectForKey:feedId]
                                            mutableCopy];
    if (!feedClassifiers) feedClassifiers = [NSMutableDictionary dictionary];
    NSMutableDictionary *authors = [[feedClassifiers objectForKey:@"authors"] mutableCopy];
    if (!authors) authors = [NSMutableDictionary dictionary];
    [authors setObject:[NSNumber numberWithInt:authorScore] forKey:author];
    [feedClassifiers setObject:authors forKey:@"authors"];
    [storiesCollection.activeClassifiers setObject:feedClassifiers forKey:feedId];
    [self.storyPageControl refreshHeaders];
    [self.trainerViewController refresh];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/classifier/save",
                           self.url];
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
    int tagScore = [[[[storiesCollection.activeClassifiers objectForKey:feedId]
                      objectForKey:@"tags"]
                     objectForKey:tag] intValue];
    
    if (tagScore > 0) {
        tagScore = -1;
    } else if (tagScore < 0) {
        tagScore = 0;
    } else {
        tagScore = 1;
    }
    
    NSMutableDictionary *feedClassifiers = [[storiesCollection.activeClassifiers objectForKey:feedId]
                                            mutableCopy];
    if (!feedClassifiers) feedClassifiers = [NSMutableDictionary dictionary];
    NSMutableDictionary *tags = [[feedClassifiers objectForKey:@"tags"] mutableCopy];
    if (!tags) tags = [NSMutableDictionary dictionary];
    [tags setObject:[NSNumber numberWithInt:tagScore] forKey:tag];
    [feedClassifiers setObject:tags forKey:@"tags"];
    [storiesCollection.activeClassifiers setObject:feedClassifiers forKey:feedId];
    [self.storyPageControl refreshHeaders];
    [self.trainerViewController refresh];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/classifier/save",
                           self.url];
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
    NSInteger titleScore = [[[[storiesCollection.activeClassifiers objectForKey:feedId]
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
    
    NSMutableDictionary *feedClassifiers = [[storiesCollection.activeClassifiers objectForKey:feedId]
                                            mutableCopy];
    if (!feedClassifiers) feedClassifiers = [NSMutableDictionary dictionary];
    NSMutableDictionary *titles = [[feedClassifiers objectForKey:@"titles"] mutableCopy];
    if (!titles) titles = [NSMutableDictionary dictionary];
    [titles setObject:[NSNumber numberWithInteger:titleScore] forKey:title];
    [feedClassifiers setObject:titles forKey:@"titles"];
    [storiesCollection.activeClassifiers setObject:feedClassifiers forKey:feedId];
    [self.storyPageControl refreshHeaders];
    [self.trainerViewController refresh];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/classifier/save",
                           self.url];
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
    int feedScore = [[[[storiesCollection.activeClassifiers objectForKey:feedId]
                       objectForKey:@"feeds"]
                      objectForKey:feedId] intValue];
    
    if (feedScore > 0) {
        feedScore = -1;
    } else if (feedScore < 0) {
        feedScore = 0;
    } else {
        feedScore = 1;
    }
    
    NSMutableDictionary *feedClassifiers = [[storiesCollection.activeClassifiers objectForKey:feedId]
                                            mutableCopy];
    if (!feedClassifiers) feedClassifiers = [NSMutableDictionary dictionary];
    NSMutableDictionary *feeds = [[feedClassifiers objectForKey:@"feeds"] mutableCopy];
    [feeds setObject:[NSNumber numberWithInt:feedScore] forKey:feedId];
    [feedClassifiers setObject:feeds forKey:@"feeds"];
    [storiesCollection.activeClassifiers setObject:feedClassifiers forKey:feedId];
    [self.storyPageControl refreshHeaders];
    [self.trainerViewController refresh];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/classifier/save",
                           self.url];
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

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    NSLog(@" ---> DB dir: %@",[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory  inDomains:NSUserDomainMask] lastObject]);
    
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

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
    NSString *dbName = [NSString stringWithFormat:@"%@.sqlite", self.host];
    NSString *path = [dbPath stringByAppendingPathComponent:dbName];
    [self applicationDocumentsDirectory];
    
    database = [FMDatabaseQueue databaseQueueWithPath:path];
    [database inDatabase:^(FMDatabase *db) {
//        db.traceExecution = YES;
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
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"story_images"];
        NSError *error = nil;
        BOOL success = [fileManager removeItemAtPath:cacheDirectory error:&error];
        if (!success || error) {
            // something went wrong
        }
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
                                  " scroll number,"
                                  " UNIQUE(story_hash) ON CONFLICT REPLACE"
                                  ")"];
    [db executeUpdate:createStoryTable];
    NSString *indexStoriesFeed = @"CREATE INDEX IF NOT EXISTS stories_story_feed_id ON stories (story_feed_id)";
    [db executeUpdate:indexStoriesFeed];
    
    
    NSString *createStoryScrollsTable = [NSString stringWithFormat:@"create table if not exists story_scrolls "
                                  "("
                                  " story_feed_id varchar(20),"
                                  " story_hash varchar(24),"
                                  " story_timestamp number,"
                                  " scroll number,"
                                  " UNIQUE(story_hash) ON CONFLICT REPLACE"
                                  ")"];
    [db executeUpdate:createStoryScrollsTable];
    NSString *indexStoriesHash = @"CREATE INDEX IF NOT EXISTS story_scrolls_story_hash ON story_scrolls (story_hash)";
    [db executeUpdate:indexStoriesHash];
    
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
    if (![[NSFileManager defaultManager] fileExistsAtPath:storyImagesDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:storyImagesDirectory
                                  withIntermediateDirectories:NO
                                                   attributes:nil
                                                        error:&error];
    }

//    NSLog(@"Create db %d: %@", [db lastErrorCode], [db lastErrorMessage]);
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
//    NSLog(@"Operation queue: %lu", (unsigned long)offlineQueue.operationCount);
    [offlineQueue cancelAllOperations];
    [offlineQueue setMaxConcurrentOperationCount:1];
    OfflineSyncUnreads *operationSyncUnreads = [[OfflineSyncUnreads alloc] init];
    
    [offlineQueue addOperation:operationSyncUnreads];
}

- (void)startOfflineFetchStories {
    OfflineFetchStories *operationFetchStories = [[OfflineFetchStories alloc] init];
    
    [offlineQueue addOperation:operationFetchStories];
    
//    NSLog(@"Done start offline fetch stories");
}

- (void)startOfflineFetchImages {
    OfflineFetchImages *operationFetchImages = [[OfflineFetchImages alloc] init];
    
    [offlineQueue addOperation:operationFetchImages];
}

- (BOOL)isReachableForOffline {
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

- (void)markScrollPosition:(NSInteger)position inStory:(NSDictionary *)story {
    if (position < 0) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,
                                             (unsigned long)NULL), ^(void) {
        [self.database inDatabase:^(FMDatabase *db) {
//            NSLog(@"Saving scroll %ld in %@-%@", position, [story objectForKey:@"story_hash"], [story objectForKey:@"story_title"]);
            [db executeUpdate:@"INSERT INTO story_scrolls (story_feed_id, story_hash, story_timestamp, scroll) VALUES (?, ?, ?, ?)",
             [story objectForKey:@"story_feed_id"],
             [story objectForKey:@"story_hash"],
             [story objectForKey:@"story_timestamp"],
             [NSNumber numberWithInteger:position]];
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
    if (self.feedsViewController.isOffline) {
        if (callback) callback();
        return;
    }
    
    if (self.hasQueuedReadStories || forceCheck) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,
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
                           self.url];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableArray *completedHashes = [NSMutableArray array];
    for (NSArray *storyHashes in [hashes allValues]) {
        [completedHashes addObjectsFromArray:storyHashes];
    }
    NSLog(@"Marking %lu queued read stories as read...", (unsigned long)[completedHashes count]);
    NSString *completedHashesStr = [completedHashes componentsJoinedByString:@"\",\""];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    __weak ASIHTTPRequest *_request = request;
    [request setPostValue:[hashes JSONRepresentation] forKey:@"feeds_stories"];
    [request setDelegate:self];
    [request setValidatesSecureCertificate:NO];
    [request setCompletionBlock:^{
        if ([_request responseStatusCode] == 200) {
            NSLog(@"Completed clearing %@ hashes", completedHashesStr);
            [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM queued_read_hashes "
                               "WHERE story_hash in (\"%@\")", completedHashesStr]];
            [self pruneQueuedReadHashes];
        } else {
            NSLog(@"Failed mark read queued.");
            self.hasQueuedReadStories = YES;
            [self pruneQueuedReadHashes];
        }
        if (callback) callback();
    }];
    [request setFailedBlock:^{
        NSLog(@"Failed mark read queued.");
        self.hasQueuedReadStories = YES;
        [self pruneQueuedReadHashes];
        if (callback) callback();
    }];
    [request startAsynchronous];
}

- (void)pruneQueuedReadHashes {
    [self.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSString *unreadSql = [NSString stringWithFormat:@"SELECT qrh.story_hash FROM queued_read_hashes qrh "
                               "INNER JOIN unread_hashes uh ON qrh.story_hash = uh.story_hash"];
        FMResultSet *cursor = [db executeQuery:unreadSql];
        while ([cursor next]) {
            NSLog(@"Story: %@", [cursor objectForColumnName:@"story_hash"]);
        }
//        NSLog(@"Found %lu stories queued to be read but already read", (unsigned long)[[cursor.resultDictionary allKeys] count]);
        NSString *deleteSql = [NSString stringWithFormat:@"DELETE FROM queued_read_hashes "
                               "WHERE story_hash not in (%@)", unreadSql];
        [db executeUpdate:deleteSql];
    }];
}

- (void)prepareActiveCachedImages:(FMDatabase *)db {
    activeCachedImages = [NSMutableDictionary dictionary];
    NSArray *feedIds;
    int cached = 0;
    
    if (storiesCollection.isRiverView) {
        feedIds = storiesCollection.activeFolderFeeds;
    } else if (storiesCollection.activeFeed) {
        feedIds = @[[storiesCollection.activeFeed objectForKey:@"id"]];
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
    
//    NSLog(@"Pre-cached %d images", cached);
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
