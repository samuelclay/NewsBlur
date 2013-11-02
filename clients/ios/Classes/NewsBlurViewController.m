//
//  NewsBlurViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import "NewsBlurViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NBContainerViewController.h"
#import "DashboardViewController.h"
#import "InteractionsModule.h"
#import "ActivityModule.h"
#import "FeedTableCell.h"
#import "FeedsMenuViewController.h"
#import "FeedDetailMenuViewController.h"
#import "UserProfileViewController.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "ASIHTTPRequest.h"
#import "PullToRefreshView.h"
#import "MBProgressHUD.h"
#import "Base64.h"
#import "JSON.h"
#import "NBNotifier.h"
#import "Utilities.h"
#import "UIBarButtonItem+WEPopover.h"
#import "UIBarButtonItem+Image.h"
#import "AddSiteViewController.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "IASKAppSettingsViewController.h"
#import "IASKSettingsReader.h"
#import "UIImageView+AFNetworking.h"
#import "NBBarButtonItem.h"

static const CGFloat kPhoneTableViewRowHeight = 31.0f;
static const CGFloat kTableViewRowHeight = 31.0f;
static const CGFloat kBlurblogTableViewRowHeight = 32.0f;
static const CGFloat kPhoneBlurblogTableViewRowHeight = 32.0f;
static const CGFloat kFolderTitleHeight = 28.0f;

@interface NewsBlurViewController () 

@property (nonatomic, strong) NSMutableDictionary *updatedDictSocialFeeds_;
@property (nonatomic, strong) NSMutableDictionary *updatedDictFeeds_;
@property (readwrite) BOOL inPullToRefresh_;

@end

@implementation NewsBlurViewController

@synthesize appDelegate;
@synthesize innerView;
@synthesize feedTitlesTable;
@synthesize feedViewToolbar;
@synthesize feedScoreSlider;
@synthesize homeButton;
@synthesize intelligenceControl;
@synthesize activeFeedLocations;
@synthesize stillVisibleFeeds;
@synthesize visibleFolders;
@synthesize viewShowingAllFeeds;
@synthesize pull;
@synthesize lastUpdate;
@synthesize imageCache;
@synthesize popoverController;
@synthesize currentRowAtIndexPath;
@synthesize currentSection;
@synthesize noFocusMessage;
@synthesize toolbarLeftMargin;
@synthesize updatedDictFeeds_;
@synthesize updatedDictSocialFeeds_;
@synthesize inPullToRefresh_;
@synthesize addBarButton;
@synthesize settingsBarButton;
@synthesize activitiesButton;
@synthesize userAvatarButton;
@synthesize userInfoBarButton;
@synthesize neutralCount;
@synthesize positiveCount;
@synthesize userLabel;
@synthesize greenIcon;
@synthesize notifier;
@synthesize isOffline;

#pragma mark -
#pragma mark Globals

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    popoverClass = [WEPopoverController class];

    pull = [[PullToRefreshView alloc] initWithScrollView:self.feedTitlesTable];
    [pull setDelegate:self];
    [self.feedTitlesTable addSubview:pull];
    
    imageCache = [[NSCache alloc] init];
    [imageCache setDelegate:self];
    
    [[NSNotificationCenter defaultCenter] 
     addObserver:self
     selector:@selector(returnToApp)
     name:UIApplicationWillEnterForegroundNotification
     object:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(settingDidChange:)
     name:kIASKAppSettingChanged
     object:nil];
    
    [self.intelligenceControl setWidth:52 forSegmentAtIndex:0];
    [self.intelligenceControl setWidth:68 forSegmentAtIndex:1];
    [self.intelligenceControl setWidth:62 forSegmentAtIndex:2];
    [self.intelligenceControl sizeToFit];
    CGRect intelFrame = self.intelligenceControl.frame;
    intelFrame.origin.x = (self.feedViewToolbar.frame.size.width / 2) -
                          (intelFrame.size.width / 2) + 20;
    self.intelligenceControl.frame = intelFrame;
    self.intelligenceControl.hidden = YES;
    
    [[UIBarButtonItem appearance] setTintColor:UIColorFromRGB(0x8F918B)];
    [[UIBarButtonItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName:
                                                               UIColorFromRGB(0x8F918B)}
                                                forState:UIControlStateNormal];
    [[UIBarButtonItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName:
                                                               UIColorFromRGB(0x4C4D4A)}
                                                forState:UIControlStateHighlighted];
    self.navigationController.navigationBar.tintColor = UIColorFromRGB(0x8F918B);
    self.navigationController.navigationBar.translucent = NO;
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    [self layoutForInterfaceOrientation:orientation];

    appDelegate.activeClassifiers = [NSMutableDictionary dictionary];
    
    UILongPressGestureRecognizer *longpress = [[UILongPressGestureRecognizer alloc]
                                               initWithTarget:self action:@selector(handleLongPress:)];
    longpress.minimumPressDuration = 1.0;
    longpress.delegate = self;
    [self.feedTitlesTable addGestureRecognizer:longpress];
    
    self.notifier = [[NBNotifier alloc] initWithTitle:@"Fetching stories..."
                                               inView:self.view
                                           withOffset:CGPointMake(0, self.feedViewToolbar.frame.size.height)];
    [self.view insertSubview:self.notifier belowSubview:self.feedViewToolbar];
    
    UIColor *bgColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    self.feedTitlesTable.backgroundColor = bgColor;
    self.feedTitlesTable.separatorColor = [UIColor clearColor];
    
    [self layoutHeaderCounts:nil];
    
    userAvatarButton.customView.hidden = YES;
    userInfoBarButton.customView.hidden = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController transitionFromFeedDetail];
    } 
    NSDate *start = [NSDate date];
    NSLog(@"Feed List timing 0: %f", (double)[start timeIntervalSinceNow] * -1000.0);
    [super viewWillAppear:animated];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if ([userPreferences integerForKey:@"selectedIntelligence"] == 1) {
        self.viewShowingAllFeeds = NO;
        [self.intelligenceControl setSelectedSegmentIndex:2];
        [appDelegate setSelectedIntelligence:1];
    } else if ([userPreferences integerForKey:@"selectedIntelligence"] == 0) {
        self.viewShowingAllFeeds = NO;
        [self.intelligenceControl setSelectedSegmentIndex:1];
        [appDelegate setSelectedIntelligence:0];
    } else {
        // default state, ALL BLURBLOG STORIES
        self.viewShowingAllFeeds = YES;
        [self.intelligenceControl setSelectedSegmentIndex:0];
        [appDelegate setSelectedIntelligence:0];
    }
    
    [MBProgressHUD hideHUDForView:appDelegate.storyPageControl.view animated:NO];
    
    NSLog(@"Feed List timing 1: %f", (double)[start timeIntervalSinceNow] * -1000.0);
    // perform these only if coming from the feed detail view
    if (appDelegate.inFeedDetail) {
        appDelegate.inFeedDetail = NO;
        // reload the data and then set the highlight again
//        [self.feedTitlesTable reloadData];
        NSLog(@"Feed List timing 1a: %f", (double)[start timeIntervalSinceNow] * -1000.0);
        [self refreshHeaderCounts];
        NSLog(@"Feed List timing 1b: %f", (double)[start timeIntervalSinceNow] * -1000.0);
        [self redrawUnreadCounts];
        NSLog(@"Feed List timing 1c: %f", (double)[start timeIntervalSinceNow] * -1000.0);
//        [self.feedTitlesTable selectRowAtIndexPath:self.currentRowAtIndexPath
//                                          animated:NO 
//                                    scrollPosition:UITableViewScrollPositionNone];
        NSLog(@"Feed List timing 1d: %f", (double)[start timeIntervalSinceNow] * -1000.0);
        [self.notifier setNeedsLayout];
        NSLog(@"Feed List timing 1e: %f", (double)[start timeIntervalSinceNow] * -1000.0);
    }
    
    NSLog(@"Feed List timing 2: %f", (double)[start timeIntervalSinceNow] * -1000.0);
}

- (void)viewDidAppear:(BOOL)animated {
//    [self.feedTitlesTable selectRowAtIndexPath:self.currentRowAtIndexPath 
//                                      animated:NO 
//                                scrollPosition:UITableViewScrollPositionNone];
    
    [super viewDidAppear:animated];
    [self performSelector:@selector(fadeSelectedCell) withObject:self afterDelay:0.2];
    self.navigationController.navigationBar.backItem.title = @"All Sites";
    
    // reset all feed detail specific data
    appDelegate.activeFeed = nil;
    appDelegate.isSocialView = NO;
    appDelegate.isRiverView = NO;
    appDelegate.inFindingStoryMode = NO;
}

- (void)fadeSelectedCell {
    [self.feedTitlesTable deselectRowAtIndexPath:[self.feedTitlesTable indexPathForSelectedRow]
                                        animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.popoverController dismissPopoverAnimated:YES];
    self.popoverController = nil;
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration {
    [self layoutForInterfaceOrientation:toInterfaceOrientation];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self.feedTitlesTable reloadData];
    [self.notifier setNeedsLayout];
}

- (void)viewDidUnload {
    [self setToolbarLeftMargin:nil];
    [self setNoFocusMessage:nil];
    [self setInnerView:nil];
}

- (void)layoutForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    CGSize toolbarSize = [self.feedViewToolbar sizeThatFits:self.view.frame.size];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.feedViewToolbar.frame = CGRectMake(-10.0f,
                                                CGRectGetHeight(self.view.frame) - toolbarSize.height,
                                                toolbarSize.width + 20, toolbarSize.height);
    } else {
        self.feedViewToolbar.frame = (CGRect){CGPointMake(0.f, CGRectGetHeight(self.view.frame) - toolbarSize.height), toolbarSize};
    }
    self.innerView.frame = (CGRect){CGPointZero, CGSizeMake(CGRectGetWidth(self.view.frame), CGRectGetMinY(self.feedViewToolbar.frame))};
    self.notifier.offset = CGPointMake(0, self.feedViewToolbar.frame.size.height);
    
    int height = 16;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone &&
        UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
        height = 8;
    }

    self.intelligenceControl.frame = CGRectMake(self.intelligenceControl.frame.origin.x,
                                                self.intelligenceControl.frame.origin.y,
                                                self.intelligenceControl.frame.size.width,
                                                self.feedViewToolbar.frame.size.height -
                                                height);
    [self layoutHeaderCounts:interfaceOrientation];
    [self refreshHeaderCounts];
}


#pragma mark -
#pragma mark Initialization

- (void)returnToApp {
    NSDate *decayDate = [[NSDate alloc] initWithTimeIntervalSinceNow:(BACKGROUND_REFRESH_SECONDS)];
    NSLog(@"Last Update: %@ - %f", self.lastUpdate, [self.lastUpdate timeIntervalSinceDate:decayDate]);
    if ([self.lastUpdate timeIntervalSinceDate:decayDate] < 0) {
        [appDelegate reloadFeedsView:YES];
    }
    
}

-(void)fetchFeedList:(BOOL)showLoader {
    NSURL *urlFeedList;
    
    [appDelegate cancelOfflineQueue];
    
    if (self.inPullToRefresh_) {
        urlFeedList = [NSURL URLWithString:
                      [NSString stringWithFormat:@"%@/reader/feeds?flat=true&update_counts=true",
                      NEWSBLUR_URL]];
    } else {
        urlFeedList = [NSURL URLWithString:
                       [NSString stringWithFormat:@"%@/reader/feeds?flat=true&update_counts=false",
                        NEWSBLUR_URL]];
    }
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:urlFeedList];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    [request setDelegate:self];
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    [request setDidFinishSelector:@selector(finishLoadingFeedList:)];
    [request setDidFailSelector:@selector(finishedWithError:)];
    [request setTimeOutSeconds:15];
    [request startAsynchronous];

    self.lastUpdate = [NSDate date];
    if (showLoader) {
        [self.notifier hide];
    }
    [self showRefreshNotifier];
}

- (void)finishedWithError:(ASIHTTPRequest *)request {    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [pull finishedLoading];
    
    // User clicking on another link before the page loads is OK.
    [self informError:[request error]];
    self.inPullToRefresh_ = NO;
    
    [self showOfflineNotifier];
}

- (void)finishLoadingFeedList:(ASIHTTPRequest *)request {
    if ([request responseStatusCode] == 403) {
        return [appDelegate showLogin];
    } else if ([request responseStatusCode] >= 400) {
        [pull finishedLoading];
        if ([request responseStatusCode] == 429) {
            [self informError:@"Slow down. You're rate-limited."];
        } else if ([request responseStatusCode] == 503) {
            [pull finishedLoading];
            [self informError:@"In maintenance mode"];
        } else {
            [self informError:@"The server barfed!"];
        }
        
        [self showOfflineNotifier];
        return;
    }
    
    appDelegate.hasNoSites = NO;
    self.isOffline = NO;
    NSString *responseString = [request responseString];   
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions
                             error:&error];

    appDelegate.activeUsername = [results objectForKey:@"user"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            [db executeUpdate:@"DELETE FROM accounts WHERE username = ?", appDelegate.activeUsername];
            [db executeUpdate:@"INSERT INTO accounts"
             "(username, download_date, feeds_json) VALUES "
             "(?, ?, ?)",
             appDelegate.activeUsername,
             [NSDate date],
             [results JSONRepresentation]
             ];
            for (NSDictionary *feed in [results objectForKey:@"social_feeds"]) {
                [db executeUpdate:@"INSERT INTO unread_counts (feed_id, ps, nt, ng) VALUES "
                 "(?, ?, ?, ?)",
                 [feed objectForKey:@"id"],
                 [feed objectForKey:@"ps"],
                 [feed objectForKey:@"nt"],
                 [feed objectForKey:@"ng"]];
            }
            for (NSString *feedId in [results objectForKey:@"feeds"]) {
                NSDictionary *feed = [[results objectForKey:@"feeds"] objectForKey:feedId];
                [db executeUpdate:@"INSERT INTO unread_counts (feed_id, ps, nt, ng) VALUES "
                 "(?, ?, ?, ?)",
                 [feed objectForKey:@"id"],
                 [feed objectForKey:@"ps"],
                 [feed objectForKey:@"nt"],
                 [feed objectForKey:@"ng"]];
            }
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishLoadingFeedListWithDict:results];
        });
    });

}

- (void)finishLoadingFeedListWithDict:(NSDictionary *)results {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    appDelegate.savedStoriesCount = [[results objectForKey:@"starred_count"] intValue];
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    self.stillVisibleFeeds = [NSMutableDictionary dictionary];
    [pull finishedLoading];
    [self loadFavicons];

    appDelegate.activeUsername = [results objectForKey:@"user"];
    if (appDelegate.activeUsername) {
        [userPreferences setObject:appDelegate.activeUsername forKey:@"active_username"];
        [userPreferences synchronize];
    }
    
    // Bottom toolbar
    UIImage *addImage = [UIImage imageNamed:@"nav_icn_add.png"];
    UIImage *settingsImage = [UIImage imageNamed:@"nav_icn_settings.png"];
    addBarButton.enabled = YES;
    settingsBarButton.enabled = YES;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [addBarButton setImage:addImage];
        [settingsBarButton setImage:settingsImage];
    } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NBBarButtonItem *addButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
        [addButton setImage:addImage forState:UIControlStateNormal];
        [addButton sizeToFit];
        [addButton addTarget:self action:@selector(tapAddSite:)
            forControlEvents:UIControlEventTouchUpInside];
        [addBarButton setCustomView:addButton];

        NBBarButtonItem *settingsButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
        settingsButton.onRightSide = YES;
        [settingsButton setImage:settingsImage forState:UIControlStateNormal];
        [settingsButton sizeToFit];
        [settingsButton addTarget:self action:@selector(showSettingsPopover:)
                 forControlEvents:UIControlEventTouchUpInside];
        [settingsBarButton setCustomView:settingsButton];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        UIImage *activityImage = [UIImage imageNamed:@"nav_icn_activity_hover.png"];
        NBBarButtonItem *activityButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
        [activityButton setImage:activityImage forState:UIControlStateNormal];
        [activityButton sizeToFit];
        [activityButton setContentEdgeInsets:UIEdgeInsetsMake(0, 0, 0, 10)];
        [activityButton setFrame:CGRectInset(activityButton.frame, -6, -6)];
        [activityButton addTarget:self
                           action:@selector(showInteractionsPopover:)
                 forControlEvents:UIControlEventTouchUpInside];
        activitiesButton = [[UIBarButtonItem alloc]
                            initWithCustomView:activityButton];
        self.navigationItem.rightBarButtonItem = activitiesButton;
    }
    
    NSMutableDictionary *sortedFolders = [[NSMutableDictionary alloc] init];
    NSArray *sortedArray;
    
    // Set up dictSocialProfile and userActivitiesArray
    appDelegate.dictSocialProfile = [results objectForKey:@"social_profile"];
    appDelegate.dictUserProfile = [results objectForKey:@"user_profile"];
    appDelegate.dictSocialServices = [results objectForKey:@"social_services"];
    appDelegate.userActivitiesArray = [results objectForKey:@"activities"];
    
    // Only update the dashboard if there is a social profile
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.dashboardViewController refreshInteractions];
        [appDelegate.dashboardViewController refreshActivity];
    }
    
    // Set up dictSocialFeeds
    NSArray *socialFeedsArray = [results objectForKey:@"social_feeds"];
    NSMutableArray *socialFolder = [[NSMutableArray alloc] init];
    NSMutableDictionary *socialDict = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *tempActiveFeeds = [[NSMutableDictionary alloc] init];
    appDelegate.dictActiveFeeds = tempActiveFeeds;
    
    for (int i = 0; i < socialFeedsArray.count; i++) {
        NSString *userKey = [NSString stringWithFormat:@"%@", 
                             [[socialFeedsArray objectAtIndex:i] objectForKey:@"id"]];
        [socialFolder addObject: [[socialFeedsArray objectAtIndex:i] objectForKey:@"id"]];
        [socialDict setObject:[socialFeedsArray objectAtIndex:i] 
                       forKey:userKey];
    }
    
    NSLog(@"Setting dictSocialFeeds");
    appDelegate.dictSocialFeeds = socialDict;
    [self loadAvatars];
    
    // set up dictFolders
    NSMutableDictionary * allFolders = [[NSMutableDictionary alloc] init];
    
    if (![[results objectForKey:@"flat_folders"] isKindOfClass:[NSArray class]]) {
        allFolders = [[results objectForKey:@"flat_folders"] mutableCopy];
    }

    [allFolders setValue:socialFolder forKey:@"river_blurblogs"];
    [allFolders setValue:[[NSMutableArray alloc] init] forKey:@"river_global"];
    
    if (appDelegate.savedStoriesCount) {
        [allFolders setValue:[[NSArray alloc] init] forKey:@"saved_stories"];
    }
    
    appDelegate.dictFolders = allFolders;
    
    // set up dictFeeds
    appDelegate.dictFeeds = [[results objectForKey:@"feeds"] mutableCopy];
    [appDelegate populateDictUnreadCounts];
    
    // sort all the folders
    appDelegate.dictFoldersArray = [NSMutableArray array];
    for (id f in appDelegate.dictFolders) {
        NSArray *folder = [appDelegate.dictFolders objectForKey:f];
        NSString *folderTitle;
        if ([f isEqualToString:@" "]) {
            folderTitle = @"everything";
        } else {
            folderTitle = f;
        }
        [appDelegate.dictFoldersArray addObject:folderTitle];
        sortedArray = [folder sortedArrayUsingComparator:^NSComparisonResult(id id1, id id2) {
            NSString *feedTitleA;
            NSString *feedTitleB;
            
            if ([appDelegate isSocialFeed:[NSString stringWithFormat:@"%@", id1]]) {
                feedTitleA = [[appDelegate.dictSocialFeeds 
                               objectForKey:[NSString stringWithFormat:@"%@", id1]] 
                              objectForKey:@"feed_title"];
                feedTitleB = [[appDelegate.dictSocialFeeds 
                               objectForKey:[NSString stringWithFormat:@"%@", id2]] 
                              objectForKey:@"feed_title"];
            } else {
                feedTitleA = [[appDelegate.dictFeeds 
                                         objectForKey:[NSString stringWithFormat:@"%@", id1]] 
                                        objectForKey:@"feed_title"];
                feedTitleB = [[appDelegate.dictFeeds 
                                         objectForKey:[NSString stringWithFormat:@"%@", id2]] 
                                        objectForKey:@"feed_title"];
            }
            return [feedTitleA caseInsensitiveCompare:feedTitleB];
        }];
        [sortedFolders setValue:sortedArray forKey:folderTitle];
    }
    appDelegate.dictFolders = sortedFolders;
    [appDelegate.dictFoldersArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
    
    
    // Move River Blurblog and Everything to the top
    if ([appDelegate.dictFoldersArray containsObject:@"river_global"]) {
        [appDelegate.dictFoldersArray removeObject:@"river_global"];
        [appDelegate.dictFoldersArray insertObject:@"river_global" atIndex:0];
    }
    if ([appDelegate.dictFoldersArray containsObject:@"river_blurblogs"]) {
        [appDelegate.dictFoldersArray removeObject:@"river_blurblogs"];
        [appDelegate.dictFoldersArray insertObject:@"river_blurblogs" atIndex:1];
    }
    if ([appDelegate.dictFoldersArray containsObject:@"everything"]) {
        [appDelegate.dictFoldersArray removeObject:@"everything"];
        [appDelegate.dictFoldersArray insertObject:@"everything" atIndex:2];
    }
    
    // Add Saved Stories folder
    if (appDelegate.savedStoriesCount) {
        [appDelegate.dictFoldersArray removeObject:@"saved_stories"];
        [appDelegate.dictFoldersArray insertObject:@"saved_stories" atIndex:appDelegate.dictFoldersArray.count];
    }
    
    // test for empty    
    if ([[appDelegate.dictFeeds allKeys] count] == 0 &&
        [[appDelegate.dictSocialFeeds allKeys] count] == 0) {
        appDelegate.hasNoSites = YES;
    }
    
    [self calculateFeedLocations];
    [self.feedTitlesTable reloadData];
    [self refreshHeaderCounts];

    // assign categories for FTUX    
    if (![[results objectForKey:@"categories"] isKindOfClass:[NSNull class]]){
        appDelegate.categories = [[results objectForKey:@"categories"] objectForKey:@"categories"];
        appDelegate.categoryFeeds = [[results objectForKey:@"categories"] objectForKey:@"feeds"];
    }
    
    // test for latest version of app
    NSString *serveriPhoneVersion = [results objectForKey:@"iphone_version"];  
    NSString *currentiPhoneVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    float serveriPhoneVersionFloat = [serveriPhoneVersion floatValue];
    float currentiPhoneVersionFloat = [currentiPhoneVersion floatValue];

    if (currentiPhoneVersionFloat < serveriPhoneVersionFloat) {
        NSLog(@"Version: %f - %f", serveriPhoneVersionFloat, currentiPhoneVersionFloat);
        NSString *title = [NSString stringWithFormat:@
                           "You should download the new version of NewsBlur.\n\nNew version: v%@\nYou have: v%@", 
                           serveriPhoneVersion, 
                           currentiPhoneVersion];
        UIAlertView *upgradeConfirm = [[UIAlertView alloc] initWithTitle:title 
                                                                 message:nil 
                                                                delegate:self 
                                                       cancelButtonTitle:@"Cancel" 
                                                       otherButtonTitles:@"Upgrade!", nil];
        [upgradeConfirm show];
        [upgradeConfirm setTag:2];
    }
    
    if (!self.isOffline) {
        // start up the first time user experience
        if ([[results objectForKey:@"social_feeds"] count] == 0 &&
            [[[results objectForKey:@"feeds"] allKeys] count] == 0) {
            [appDelegate showFirstTimeUser];
            return;
        }
        
        if (self.inPullToRefresh_) {
            self.inPullToRefresh_ = NO;
            [self showSyncingNotifier];
            [self.appDelegate flushQueuedReadStories:YES withCallback:^{
                [self refreshFeedList];
//                [self.appDelegate startOfflineQueue];
            }];
        } else {
            [self showSyncingNotifier];
            [self.appDelegate flushQueuedReadStories:YES withCallback:^{
                [self refreshFeedList];
            }];
        }
    }
    
    self.intelligenceControl.hidden = NO;
    
    [self showExplainerOnEmptyFeedlist];
    [self layoutHeaderCounts:nil];
    [self refreshHeaderCounts];
}


- (void)loadOfflineFeeds:(BOOL)failed {
    __block __typeof__(self) _self = self;
    self.isOffline = YES;

    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if (!appDelegate.activeUsername) {
        appDelegate.activeUsername = [userPreferences stringForKey:@"active_username"];
        if (!appDelegate.activeUsername) {
            if (failed) {
                return;
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self fetchFeedList:YES];
                });
                return;
            }
        }
    }

    [self showRefreshNotifier];

    [appDelegate.database inDatabase:^(FMDatabase *db) {
        NSDictionary *results;

        
        FMResultSet *cursor = [db executeQuery:@"SELECT * FROM accounts WHERE username = ? LIMIT 1",
                               appDelegate.activeUsername];
        
        while ([cursor next]) {
            NSDictionary *feedsCache = [cursor resultDictionary];
            results = [NSJSONSerialization
                       JSONObjectWithData:[[feedsCache objectForKey:@"feeds_json"]
                                           dataUsingEncoding:NSUTF8StringEncoding]
                       options:nil error:nil];
            break;
        }
        
        [cursor close];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_self finishLoadingFeedListWithDict:results];
            [_self fetchFeedList:NO];
        });
    }];
}

- (void)showUserProfile {
    appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [appDelegate.dictSocialProfile objectForKey:@"user_id"]];
    appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@", [appDelegate.dictSocialProfile objectForKey:@"username"]];
//    appDelegate.activeUserProfileName = @"You";
    [appDelegate showUserProfileModal:[self.navigationItem.leftBarButtonItems
                                       objectAtIndex:1]];
}

- (IBAction)tapAddSite:(id)sender {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController showSitePopover:self.addBarButton];
    } else {
        if (self.popoverController == nil) {
            self.popoverController = [[WEPopoverController alloc]
                                      initWithContentViewController:appDelegate.addSiteViewController];
            
            self.popoverController.delegate = self;
        } else {
            [self.popoverController dismissPopoverAnimated:YES];
            self.popoverController = nil;
        }
        
        if ([self.popoverController respondsToSelector:@selector(setContainerViewProperties:)]) {
            [self.popoverController setContainerViewProperties:[self improvedContainerViewProperties]];
        }
        [self.popoverController setPopoverContentSize:CGSizeMake(self.view.frame.size.width - 36,
                                                                 self.view.frame.size.height - 28)];
        [self.popoverController presentPopoverFromBarButtonItem:self.addBarButton
                                       permittedArrowDirections:UIPopoverArrowDirectionDown
                                                       animated:YES];
    }
    
    [appDelegate.addSiteViewController reload];
}

- (IBAction)showSettingsPopover:(id)sender {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController showFeedMenuPopover:self.settingsBarButton];
    } else {
        if (self.popoverController == nil) {
            self.popoverController = [[WEPopoverController alloc]
                                      initWithContentViewController:appDelegate.feedsMenuViewController];
            
            self.popoverController.delegate = self;
        } else {
            [self.popoverController dismissPopoverAnimated:YES];
            self.popoverController = nil;
        }
        
        if ([self.popoverController respondsToSelector:@selector(setContainerViewProperties:)]) {
            [self.popoverController setContainerViewProperties:[self improvedContainerViewProperties]];
        }
        [self.popoverController setPopoverContentSize:CGSizeMake(200, 114)];
        [self.popoverController presentPopoverFromBarButtonItem:self.settingsBarButton
                                       permittedArrowDirections:UIPopoverArrowDirectionDown
                                                       animated:YES];
    }
}

- (IBAction)showInteractionsPopover:(id)sender {    
    if (self.popoverController == nil) {
        self.popoverController = [[WEPopoverController alloc]
                                  initWithContentViewController:appDelegate.dashboardViewController];
        
        self.popoverController.delegate = self;
    } else {
        [self.popoverController dismissPopoverAnimated:YES];
        self.popoverController = nil;
    }
    
    if ([self.popoverController respondsToSelector:@selector(setContainerViewProperties:)]) {
        [self.popoverController setContainerViewProperties:[self improvedContainerViewProperties]];
    }
    [self.popoverController setPopoverContentSize:CGSizeMake(self.view.frame.size.width - 36,
                                                             self.view.frame.size.height - 60)];
    [self.popoverController presentPopoverFromBarButtonItem:self.activitiesButton
                                   permittedArrowDirections:UIPopoverArrowDirectionUp
                                                   animated:YES];
    
    [appDelegate.dashboardViewController refreshInteractions];
    [appDelegate.dashboardViewController refreshActivity];
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 2) {
        if (buttonIndex == 0) {
            return;
        } else {
            //  this doesn't work in simulator!!! because simulator has no app store
            NSURL *url = [NSURL URLWithString:@"http://phobos.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=463981119&mt=8"];
            [[UIApplication sharedApplication] openURL:url];
        }
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    CGPoint p = [gestureRecognizer locationInView:self.feedTitlesTable];
    NSIndexPath *indexPath = [self.feedTitlesTable indexPathForRowAtPoint:p];
    
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) return;
    if (indexPath == nil) return;

    FeedTableCell *cell = (FeedTableCell *)[self.feedTitlesTable cellForRowAtIndexPath:indexPath];
    if (!cell.highlighted) return;
    
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    id feedId = [[appDelegate.dictFolders objectForKey:folderName] objectAtIndex:indexPath.row];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    BOOL isSocial = [appDelegate isSocialFeed:feedIdStr];
    NSDictionary *feed = isSocial ?
                        [appDelegate.dictSocialFeeds objectForKey:feedIdStr] :
                        [appDelegate.dictFeeds objectForKey:feedIdStr];

    UIActionSheet *markReadSheet = [[UIActionSheet alloc] initWithTitle:[feed objectForKey:@"feed_title"]
                                                               delegate:self
                                                      cancelButtonTitle:@"Cancel"
                                                 destructiveButtonTitle:@"Mark site as read"
                                                      otherButtonTitles:@"1 day", @"3 days", @"7 days", @"14 days", nil];
    markReadSheet.accessibilityValue = feedIdStr;
    [markReadSheet showInView:self.view];
    
    [self performSelector:@selector(highlightCell:) withObject:cell afterDelay:0.0];
}

- (void)highlightCell:(FeedTableCell *)cell {
    [cell setHighlighted:YES];
}
- (void)unhighlightCell:(FeedTableCell *)cell {
    [cell setHighlighted:NO];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *feedId = actionSheet.accessibilityValue;
    
    switch (buttonIndex) {
        case 0:
            [self markFeedRead:feedId cutoffDays:0];
            break;
        case 1:
            [self markFeedRead:feedId cutoffDays:1];
            break;
        case 2:
            [self markFeedRead:feedId cutoffDays:3];
            break;
        case 3:
            [self markFeedRead:feedId cutoffDays:7];
            break;
        case 4:
            [self markFeedRead:feedId cutoffDays:14];
            break;
    }
    
    for (FeedTableCell *cell in [self.feedTitlesTable visibleCells]) {
        if (cell.highlighted) {
            [self performSelector:@selector(unhighlightCell:) withObject:cell afterDelay:0.0];
            break;
        }
    }
}

#pragma mark -
#pragma mark Preferences

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [appDelegate.navigationController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)settingDidChange:(NSNotification*)notification {
	if ([notification.object isEqual:@"offline_allowed"]) {
		BOOL enabled = (BOOL)[[notification.userInfo objectForKey:@"offline_allowed"] intValue];
		[appDelegate.preferencesViewController setHiddenKeys:enabled ? nil :
         [NSSet setWithObjects:@"offline_image_download",
          @"offline_download_connection",
          @"offline_store_limit",
          nil] animated:YES];
	} else if ([notification.object isEqual:@"enable_instapaper"]) {
		BOOL enabled = (BOOL)[[notification.userInfo objectForKey:@"enable_instapaper"] intValue];
		[appDelegate.preferencesViewController setHiddenKeys:enabled ? nil :
         [NSSet setWithObjects:@"instapaper_username",
          @"instapaper_password",
          nil] animated:YES];
	}
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier {
	if ([specifier.key isEqualToString:@"offline_cache_empty_stories"]) {
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
        dispatch_async(queue, ^{
            dispatch_sync(dispatch_get_main_queue(), ^{
                [[NSUserDefaults standardUserDefaults] setObject:@"Deleting..." forKey:specifier.key];
            });
            [appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
                [db executeUpdate:@"DROP TABLE unread_hashes"];
                [db executeUpdate:@"DROP TABLE unread_counts"];
                [db executeUpdate:@"DROP TABLE accounts"];
                [db executeUpdate:@"DROP TABLE stories"];
                [db executeUpdate:@"DROP TABLE cached_images"];
                [appDelegate setupDatabase:db];
            }];
            [appDelegate deleteAllCachedImages];
            dispatch_sync(dispatch_get_main_queue(), ^{
                [[NSUserDefaults standardUserDefaults] setObject:@"Cleared all stories and images!"
                                                          forKey:specifier.key];
            });
        });
	}
}

#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (appDelegate.hasNoSites) {
        return 0;
    }
    return [appDelegate.dictFoldersArray count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [appDelegate.dictFoldersArray objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (appDelegate.hasNoSites) {
        return 1;
    }

    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:section];
    
    return [[appDelegate.dictFolders objectForKey:folderName] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
                     cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    id feedId = [[appDelegate.dictFolders objectForKey:folderName] objectAtIndex:indexPath.row];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    BOOL isSocial = [appDelegate isSocialFeed:feedIdStr];
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *collapseKey = [NSString stringWithFormat:@"folderCollapsed:%@", folderName];
    bool isFolderCollapsed = [userPreferences boolForKey:collapseKey];
    
    NSString *CellIdentifier;
    if (isFolderCollapsed || ![self isFeedVisible:feedIdStr]) {
        CellIdentifier = @"BlankCellIdentifier";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
        return cell;
    } else if (indexPath.section == 0 || indexPath.section == 1) {
        CellIdentifier = @"BlurblogCellIdentifier";
    } else {
        CellIdentifier = @"FeedCellIdentifier";
    }
    
    FeedTableCell *cell = (FeedTableCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];    
    if (cell == nil) {
        cell = [[FeedTableCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:CellIdentifier];
        cell.appDelegate = appDelegate;
    }
    
    NSDictionary *feed = isSocial ?
                         [appDelegate.dictSocialFeeds objectForKey:feedIdStr] :
                         [appDelegate.dictFeeds objectForKey:feedIdStr];
    NSDictionary *unreadCounts = [appDelegate.dictUnreadCounts objectForKey:feedIdStr];
    cell.feedFavicon = [Utilities getImage:feedIdStr isSocial:isSocial];
    cell.feedTitle     = [feed objectForKey:@"feed_title"];
    cell.positiveCount = [[unreadCounts objectForKey:@"ps"] intValue];
    cell.neutralCount  = [[unreadCounts objectForKey:@"nt"] intValue];
    cell.negativeCount = [[unreadCounts objectForKey:@"ng"] intValue];
    cell.isSocial      = isSocial;
    
    [cell setNeedsDisplay];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView 
        didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (appDelegate.hasNoSites) {
        return;
    }
    
    // set the current row pointer
    self.currentRowAtIndexPath = indexPath;
    self.currentSection = nil;
    
    NSString *folderName;
    if (indexPath.section == 0) {
        folderName = @"river_global";
    } else if (indexPath.section == 1) {
            folderName = @"river_blurblogs";
    } else if (indexPath.section == 2) {
        folderName = @"everything";
    } else {
        folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    }
    id feedId = [[appDelegate.dictFolders objectForKey:folderName] objectAtIndex:indexPath.row];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed;
    if ([appDelegate isSocialFeed:feedIdStr]) {
        feed = [appDelegate.dictSocialFeeds objectForKey:feedIdStr];
        appDelegate.isSocialView = YES;
    } else {
        feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        appDelegate.isSocialView = NO;
    }

    // If all feeds are already showing, no need to remember this one.
    if (!self.viewShowingAllFeeds) {
        [self.stillVisibleFeeds setObject:indexPath forKey:feedIdStr];
    }
    
    [appDelegate setActiveFeed:feed];
    [appDelegate setActiveFolder:folderName];
    appDelegate.readStories = [NSMutableArray array];
    appDelegate.isRiverView = NO;
    appDelegate.isSocialRiverView = NO;
    [appDelegate.folderCountCache removeObjectForKey:folderName];
    appDelegate.activeClassifiers = [NSMutableDictionary dictionary];

    [appDelegate loadFeedDetailView];
}

- (CGFloat)tableView:(UITableView *)tableView
           heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (appDelegate.hasNoSites) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            return kBlurblogTableViewRowHeight;            
        } else {
            return kPhoneBlurblogTableViewRowHeight;
        }
    }
    
    NSString *folderName;
    if (indexPath.section == 0) {
        folderName = @"river_global";
    } else if (indexPath.section == 1) {
            folderName = @"river_blurblogs";
    } else {
        folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    }
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *collapseKey = [NSString stringWithFormat:@"folderCollapsed:%@", folderName];
    bool isFolderCollapsed = [userPreferences boolForKey:collapseKey];
    
    if (isFolderCollapsed) {
        return 0;
    }
    
    id feedId = [[appDelegate.dictFolders objectForKey:folderName] objectAtIndex:indexPath.row];
    if (![self isFeedVisible:feedId]) {
        return 0;
    }
    
    if ([folderName isEqualToString:@"river_blurblogs"] ||
        [folderName isEqualToString:@"river_global"]) { // blurblogs
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            return kBlurblogTableViewRowHeight;
        } else {
            return kPhoneBlurblogTableViewRowHeight;
        }
    } else {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            return kTableViewRowHeight;            
        } else {
            return kPhoneTableViewRowHeight;
        }
    }
}

- (UIView *)tableView:(UITableView *)tableView 
            viewForHeaderInSection:(NSInteger)section {
    CGRect rect = CGRectMake(0.0, 0.0, tableView.frame.size.width, kFolderTitleHeight);
    FolderTitleView *folderTitle = [[FolderTitleView alloc] initWithFrame:rect];
    folderTitle.section = section;
    
    return folderTitle;
}

- (IBAction)sectionTapped:(UIButton *)button {
    button.backgroundColor = UIColorFromRGB(0x214607);
}

- (IBAction)sectionUntapped:(UIButton *)button {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.15 * NSEC_PER_SEC), 
                   dispatch_get_main_queue(), ^{
        button.backgroundColor = [UIColor clearColor];
   });
}

- (IBAction)sectionUntappedOutside:(UIButton *)button {
    button.backgroundColor = [UIColor clearColor];
}

- (CGFloat)tableView:(UITableView *)tableView
heightForHeaderInSection:(NSInteger)section {
    if ([appDelegate.dictFoldersArray count] == 0) return 0;
    
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:section];
    
    BOOL visibleFeeds = [[self.visibleFolders objectForKey:folderName] boolValue];
    if (!visibleFeeds && section != 2 && section != 0 && ![folderName isEqual:@"saved_stories"]) {
        return 0;
    }
    
    return 32;
}

- (void)didSelectSectionHeader:(UIButton *)button {
    // reset pointer to the cells
    self.currentRowAtIndexPath = nil;
    self.currentSection = button.tag;
    
    appDelegate.readStories = [NSMutableArray array];
    
    NSMutableArray *feeds = [NSMutableArray array];

    if (button.tag == 0) {
        appDelegate.isSocialRiverView = YES;
        appDelegate.isRiverView = YES;
        [appDelegate setActiveFolder:@"river_global"];
    } else if (button.tag == 1) {
        appDelegate.isSocialRiverView = YES;
        appDelegate.isRiverView = YES;
        // add all the feeds from every NON blurblog folder
        [appDelegate setActiveFolder:@"river_blurblogs"];
        for (NSString *folderName in self.activeFeedLocations) {
            if ([folderName isEqualToString:@"river_blurblogs"]) { // remove all blurblugs which is a blank folder name
                NSArray *originalFolder = [appDelegate.dictFolders objectForKey:folderName];
                NSArray *folderFeeds = [self.activeFeedLocations objectForKey:folderName];
                for (int l=0; l < [folderFeeds count]; l++) {
                    [feeds addObject:[originalFolder objectAtIndex:[[folderFeeds objectAtIndex:l] intValue]]];
                }
            }
        }
    } else if (button.tag == 2) {
        appDelegate.isSocialRiverView = NO;
        appDelegate.isRiverView = YES;
        // add all the feeds from every NON blurblog folder
        [appDelegate setActiveFolder:@"everything"];
        for (NSString *folderName in self.activeFeedLocations) {
            if (![folderName isEqualToString:@"river_blurblogs"]) {
                NSArray *originalFolder = [appDelegate.dictFolders objectForKey:folderName];
                NSArray *folderFeeds = [self.activeFeedLocations objectForKey:folderName];
                for (int l=0; l < [folderFeeds count]; l++) {
                    [feeds addObject:[originalFolder objectAtIndex:[[folderFeeds objectAtIndex:l] intValue]]];
                }
            }
        }
        [appDelegate.folderCountCache removeAllObjects];
    } else {
        appDelegate.isSocialRiverView = NO;
        appDelegate.isRiverView = YES;
        NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:button.tag];
        
        [appDelegate setActiveFolder:folderName];
        NSArray *originalFolder = [appDelegate.dictFolders objectForKey:folderName];
        NSArray *activeFolderFeeds = [self.activeFeedLocations objectForKey:folderName];
        for (int l=0; l < [activeFolderFeeds count]; l++) {
            [feeds addObject:[originalFolder objectAtIndex:[[activeFolderFeeds objectAtIndex:l] intValue]]];
        }

    }
    appDelegate.activeFolderFeeds = feeds;
    if (!self.viewShowingAllFeeds) {
        for (id feedId in feeds) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
            [self.stillVisibleFeeds setObject:[NSNumber numberWithBool:YES] forKey:feedIdStr];
        }
    }
    [appDelegate.folderCountCache removeObjectForKey:appDelegate.activeFolder];
    
    [appDelegate loadRiverFeedDetailView];
}



#pragma mark - MCSwipeTableViewCellDelegate

// When the user starts swiping the cell this method is called
- (void)swipeTableViewCellDidStartSwiping:(MCSwipeTableViewCell *)cell {
//    NSLog(@"Did start swiping the cell!");
}

// When the user is dragging, this method is called and return the dragged percentage from the border
- (void)swipeTableViewCell:(MCSwipeTableViewCell *)cell didSwipWithPercentage:(CGFloat)percentage {
//    NSLog(@"Did swipe with percentage : %f", percentage);
}

- (void)swipeTableViewCell:(MCSwipeTableViewCell *)cell didEndSwipingSwipingWithState:(MCSwipeTableViewCellState)state mode:(MCSwipeTableViewCellMode)mode {
    NSIndexPath *indexPath = [self.feedTitlesTable indexPathForCell:cell];
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    NSString *feedId = [NSString stringWithFormat:@"%@",
                        [[appDelegate.dictFolders objectForKey:folderName]
                         objectAtIndex:indexPath.row]];

    if (state == MCSwipeTableViewCellState1) {
        if (indexPath.section == 1) {
            // Profile
            NSDictionary *feed = [appDelegate.dictSocialFeeds objectForKey:feedId];
            appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [feed objectForKey:@"user_id"]];
            appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@", [feed objectForKey:@"username"]];
            [appDelegate showUserProfileModal:cell];
        } else {
            // Train
            appDelegate.activeFeed = [appDelegate.dictFeeds objectForKey:feedId];
            [appDelegate openTrainSiteWithFeedLoaded:NO from:cell];
        }
    } else if (state == MCSwipeTableViewCellState3) {
        // Mark read
        [self markFeedRead:feedId cutoffDays:0];
        
        [self.stillVisibleFeeds setObject:indexPath forKey:feedId];
        [self.feedTitlesTable beginUpdates];
        [self.feedTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                    withRowAnimation:UITableViewRowAnimationFade];
        [self.feedTitlesTable endUpdates];
    }
}

#pragma mark -
#pragma mark Mark Feeds as read

- (void)markFeedRead:(NSString *)feedId cutoffDays:(NSInteger)days {
    [self markFeedsRead:@[feedId] cutoffDays:days];
}

- (void)markFeedsRead:(NSArray *)feedIds cutoffDays:(NSInteger)days {
    NSTimeInterval cutoffTimestamp = [[NSDate date] timeIntervalSince1970];
    cutoffTimestamp -= (days * 60*60*24);
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_as_read",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    for (NSString *feedId in feedIds) {
        [request addPostValue:feedId forKey:@"feed_id"];
    }
    if (days) {
        [request setPostValue:[NSNumber numberWithInteger:cutoffTimestamp]
                       forKey:@"cutoff_timestamp"];
    }
    [request setDidFinishSelector:@selector(finishMarkAllAsRead:)];
    [request setDidFailSelector:@selector(requestFailedMarkStoryRead:)];
    [request setUserInfo:@{@"feeds": feedIds,
                           @"cutoffTimestamp": [NSNumber numberWithInteger:cutoffTimestamp]}];
    [request setDelegate:self];
    [request startAsynchronous];
    
    if (!days) {
        for (NSString *feedId in feedIds) {
            [appDelegate markFeedAllRead:feedId];
        }
    } else {
        //        [self showRefreshNotifier];
    }
}

- (void)requestFailedMarkStoryRead:(ASIFormDataRequest *)request {
    [appDelegate markStoriesRead:nil
                         inFeeds:[request.userInfo objectForKey:@"feeds"]
                 cutoffTimestamp:[[request.userInfo objectForKey:@"cutoffTimestamp"] integerValue]];
    [self showOfflineNotifier];
    [self.feedTitlesTable reloadData];
}

- (void)finishMarkAllAsRead:(ASIFormDataRequest *)request {
    if (request.responseStatusCode != 200) {
        [self requestFailedMarkStoryRead:request];
        return;
    }
    
    if ([[request.userInfo objectForKey:@"cutoffTimestamp"] integerValue]) {
        id feed;
        if ([[request.userInfo objectForKey:@"feeds"] count] == 1) {
            feed = [[request.userInfo objectForKey:@"feeds"] objectAtIndex:0];
        }
        [self refreshFeedList:feed];
    } else {
        [appDelegate markFeedReadInCache:[request.userInfo objectForKey:@"feeds"]];
    }
}

#pragma mark - Table Actions

- (void)didCollapseFolder:(UIButton *)button {
    NSString *folderName;
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if (button.tag == 0) {
        folderName = @"river_global";
    } else if (button.tag == 1) {
        folderName = @"river_blurblogs";
    } else {
        folderName = [appDelegate.dictFoldersArray objectAtIndex:button.tag];
    }
    
    NSString *collapseKey = [NSString stringWithFormat:@"folderCollapsed:%@", folderName];
    bool isFolderCollapsed = [userPreferences boolForKey:collapseKey];
    
    if (isFolderCollapsed) {
        // Expand folder
        [userPreferences setBool:NO forKey:collapseKey];
    } else {
        // Collapse folder
        [userPreferences setBool:YES forKey:collapseKey];
    }
    [userPreferences synchronize];
    
    [self.feedTitlesTable beginUpdates];
    [self.feedTitlesTable reloadSections:[NSIndexSet indexSetWithIndex:button.tag]
                        withRowAnimation:UITableViewRowAnimationFade];
    [self.feedTitlesTable endUpdates];
    
    // Scroll to section header if collapse causes it to scroll far off screen
    NSArray *indexPathsVisibleCells = [self.feedTitlesTable indexPathsForVisibleRows];
    BOOL firstFeedInFolderVisible = NO;
    for (NSIndexPath *indexPath in indexPathsVisibleCells) {
        if (indexPath.row == 0 && indexPath.section == button.tag) {
            firstFeedInFolderVisible = YES;
        }
    }
    if (!firstFeedInFolderVisible) {
        CGRect headerRect = [self.feedTitlesTable rectForHeaderInSection:button.tag];
        CGPoint headerPoint = CGPointMake(headerRect.origin.x, headerRect.origin.y);
        [self.feedTitlesTable setContentOffset:headerPoint animated:YES];
    }
    
}

- (BOOL)isFeedVisible:(id)feedId {
    if (![feedId isKindOfClass:[NSString class]]) {
        feedId = [NSString stringWithFormat:@"%@",feedId];
    }
    NSDictionary *unreadCounts = [appDelegate.dictUnreadCounts objectForKey:feedId];

    NSIndexPath *stillVisible = [self.stillVisibleFeeds objectForKey:feedId];
    if (!stillVisible &&
        appDelegate.selectedIntelligence >= 1 &&
        [[unreadCounts objectForKey:@"ps"] intValue] <= 0) {
        return NO;
    } else if (!stillVisible &&
               !self.viewShowingAllFeeds &&
               ([[unreadCounts objectForKey:@"ps"] intValue] <= 0 &&
                [[unreadCounts objectForKey:@"nt"] intValue] <= 0)) {
        return NO;
    }

    return YES;
}

- (void)changeToAllMode {
    [self.intelligenceControl setSelectedSegmentIndex:0];
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    [userPreferences setInteger:-1 forKey:@"selectedIntelligence"];
    [userPreferences synchronize];
}

- (IBAction)selectIntelligence {
    [MBProgressHUD hideHUDForView:self.feedTitlesTable animated:NO];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.innerView animated:YES];
	hud.mode = MBProgressHUDModeText;
	hud.removeFromSuperViewOnHide = YES;
    
    NSIndexPath *topRow;
    if ([[self.feedTitlesTable indexPathsForVisibleRows] count]) {
        topRow = [[self.feedTitlesTable indexPathsForVisibleRows] objectAtIndex:0];
    }
    NSInteger selectedSegmentIndex = [self.intelligenceControl selectedSegmentIndex];
    self.stillVisibleFeeds = [NSMutableDictionary dictionary];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    int direction;
    if (selectedSegmentIndex == 0) {
        hud.labelText = @"All Stories";
        [userPreferences setInteger:-1 forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        direction = -1;
        self.viewShowingAllFeeds = YES;
        [appDelegate setSelectedIntelligence:0];
    } else if(selectedSegmentIndex == 1) {
        hud.labelText = @"Unread Stories";
        [userPreferences setInteger:0 forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        direction = self.viewShowingAllFeeds ? 1 : -1;
        self.viewShowingAllFeeds = NO;
        [appDelegate setSelectedIntelligence:0];
    } else {
        hud.labelText = @"Focus Stories";
        [userPreferences setInteger:1 forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        direction = 1;
        self.viewShowingAllFeeds = NO;
        [appDelegate setSelectedIntelligence:1];
    }

    [self calculateFeedLocations];
    [self.feedTitlesTable reloadData];

    NSIndexPath *newMiddleRow;
    if (topRow && [self.feedTitlesTable numberOfRowsInSection:topRow.section] == 0) {
        newMiddleRow = [[self.feedTitlesTable indexPathsForVisibleRows] objectAtIndex:0];
    } else if (topRow) {
        newMiddleRow = [NSIndexPath indexPathForRow:0 inSection:topRow.section];
    }
    if (newMiddleRow) {
        [self.feedTitlesTable scrollToRowAtIndexPath:newMiddleRow
                                    atScrollPosition:UITableViewScrollPositionTop
                                            animated:NO];
    }
    [self.feedTitlesTable
     reloadRowsAtIndexPaths:[self.feedTitlesTable indexPathsForVisibleRows]
     withRowAnimation:direction == 1 ? UITableViewRowAnimationLeft : UITableViewRowAnimationRight];
    for (UITableViewCell *cell in self.feedTitlesTable.visibleCells) {
        [cell setNeedsDisplay];
    }
	[hud hide:YES afterDelay:0.5];
    [self showExplainerOnEmptyFeedlist];
}

- (void)showExplainerOnEmptyFeedlist {
    NSInteger intelligenceLevel = [appDelegate selectedIntelligence];
    if (intelligenceLevel > 0) {
        BOOL hasFocusStory = NO;
        for (id feedId in appDelegate.dictUnreadCounts) {
            NSDictionary *unreadCounts = [appDelegate.dictUnreadCounts objectForKey:feedId];
            if ([[unreadCounts objectForKey:@"ps"] intValue] > 0) {
                hasFocusStory = YES;
                break;
            }
        }
        if (!hasFocusStory) {
            self.noFocusMessage.hidden = NO;
        } else {
            self.noFocusMessage.hidden = YES;
        }
    } else {
        self.noFocusMessage.hidden = YES;
    }
}

- (void)redrawUnreadCounts {
    FeedTableCell *cell = (FeedTableCell *)[self.feedTitlesTable
                           cellForRowAtIndexPath:self.currentRowAtIndexPath];
    if (cell) {
        NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:self.currentRowAtIndexPath.section];
        id feedId = [[appDelegate.dictFolders objectForKey:folderName] objectAtIndex:self.currentRowAtIndexPath.row];
        NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
        NSDictionary *unreadCounts = [appDelegate.dictUnreadCounts objectForKey:feedIdStr];
        cell.positiveCount = [[unreadCounts objectForKey:@"ps"] intValue];
        cell.neutralCount  = [[unreadCounts objectForKey:@"nt"] intValue];
        cell.negativeCount  = [[unreadCounts objectForKey:@"ng"] intValue];
    } else {
        [self.feedTitlesTable reloadData];
    }
}

- (void)calculateFeedLocations {
    self.activeFeedLocations = [NSMutableDictionary dictionary];
    self.visibleFolders = [NSMutableDictionary dictionary];
    
    for (NSString *folderName in appDelegate.dictFoldersArray) {
        if ([folderName isEqualToString:@"river_global"]) continue;
        NSArray *folder = [appDelegate.dictFolders objectForKey:folderName];
        NSMutableArray *feedLocations = [NSMutableArray array];
        for (int f = 0; f < [folder count]; f++) {
            id feedId = [folder objectAtIndex:f];
            if ([self isFeedVisible:feedId]) {
                NSNumber *location = [NSNumber numberWithInt:f];
                [feedLocations addObject:location];
                if (![[self.visibleFolders objectForKey:folderName] boolValue]) {
                    [self.visibleFolders setObject:[NSNumber numberWithBool:YES] forKey:folderName];
                }
            }
        }
        [self.activeFeedLocations setObject:feedLocations forKey:folderName];
    }
}

+ (int)computeMaxScoreForFeed:(NSDictionary *)feed {
    int maxScore = -2;
    if ([[feed objectForKey:@"ng"] intValue] > 0) maxScore = -1;
    if ([[feed objectForKey:@"nt"] intValue] > 0) maxScore = 0;
    if ([[feed objectForKey:@"ps"] intValue] > 0) maxScore = 1;
    return maxScore;
}

#pragma mark -
#pragma mark Favicons


- (void)loadFavicons {
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/favicons",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIHTTPRequest  *request = [ASIHTTPRequest  requestWithURL:url];
    
    [request setDidFinishSelector:@selector(saveAndDrawFavicons:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)loadAvatars {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^{
        for (NSString *feed_id in [appDelegate.dictSocialFeeds allKeys]) {
            NSDictionary *feed = [appDelegate.dictSocialFeeds objectForKey:feed_id];
            NSURL *imageURL = [NSURL URLWithString:[feed objectForKey:@"photo_url"]];
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
            UIImage *faviconImage = [UIImage imageWithData:imageData];
            faviconImage = [Utilities roundCorneredImage:faviconImage radius:6];
            
            [Utilities saveImage:faviconImage feedId:feed_id];
        }
        
        [Utilities saveimagesToDisk];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.feedTitlesTable reloadData];
        });
    });
}



- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^{
        for (id feed_id in results) {
            NSMutableDictionary *feed = [[appDelegate.dictFeeds objectForKey:feed_id] mutableCopy]; 
            [feed setValue:[results objectForKey:feed_id] forKey:@"favicon"];
            [appDelegate.dictFeeds setValue:feed forKey:feed_id];
            
            NSString *favicon = [feed objectForKey:@"favicon"];
            if ((NSNull *)favicon != [NSNull null] && [favicon length] > 0) {
                NSData *imageData = [NSData dataWithBase64EncodedString:favicon];
                UIImage *faviconImage = [UIImage imageWithData:imageData];
                [Utilities saveImage:faviconImage feedId:feed_id];
            }
        }
        [Utilities saveimagesToDisk];

        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.feedTitlesTable reloadData];
        });
    });
    
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
    [appDelegate informError:error];
}

#pragma mark -
#pragma mark PullToRefresh

// called when the user pulls-to-refresh
- (void)pullToRefreshViewShouldRefresh:(PullToRefreshView *)view {
    self.inPullToRefresh_ = YES;
    [appDelegate reloadFeedsView:NO];
}

- (void)refreshFeedList {
    [self refreshFeedList:nil];
}

- (void)refreshFeedList:(id)feedId {
    // refresh the feed
    NSString *urlString;
    if (feedId) {
        urlString = [NSString stringWithFormat:@"%@/reader/feed_unread_count?feed_id=%@",
                     NEWSBLUR_URL, feedId];
    } else {
        urlString = [NSString stringWithFormat:@"%@/reader/refresh_feeds",
                     NEWSBLUR_URL];
    }
    NSURL *urlFeedList = [NSURL URLWithString:urlString];
    
    if (!feedId) {
        [self.appDelegate cancelOfflineQueue];
    }
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:urlFeedList];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    [request setDelegate:self];
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    if (feedId) {
        [request setUserInfo:@{@"feedId": [NSString stringWithFormat:@"%@", feedId]}];
    }
    [request setDidFinishSelector:@selector(finishRefreshingFeedList:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!feedId) {
            [self showCountingNotifier];
        }
    });
    
}

- (void)finishRefreshingFeedList:(ASIHTTPRequest *)request {
    if ([request responseStatusCode] == 403) {
        return [appDelegate showLogin];
    } else if ([request responseStatusCode] == 503) {
        [pull finishedLoading];
        return [self informError:@"In maintenance mode"];
    } else if ([request responseStatusCode] >= 500) {
        [pull finishedLoading];
        return [self informError:@"The server barfed!"];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        NSString *responseString = [request responseString];
        NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
        NSError *error;
        NSDictionary *results = [NSJSONSerialization
                                 JSONObjectWithData:responseData
                                 options:kNilOptions 
                                 error:&error];
        
        NSDictionary *newFeedCounts = [results objectForKey:@"feeds"];
        NSInteger intelligenceLevel = [appDelegate selectedIntelligence];
        for (id feed in newFeedCounts) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", feed];
            NSMutableDictionary *unreadCount = [[appDelegate.dictUnreadCounts objectForKey:feedIdStr] mutableCopy];
            NSMutableDictionary *newFeedCount = [newFeedCounts objectForKey:feed];

            if (![unreadCount isKindOfClass:[NSDictionary class]]) continue;

            // Check if a feed goes from visible to hidden, but doesn't disappear.
            if ((intelligenceLevel > 0 &&
                 [[unreadCount objectForKey:@"ps"] intValue] > 0 &&
                 [[newFeedCount objectForKey:@"ps"] intValue] == 0) ||
                (intelligenceLevel == 0 &&
                 ([[unreadCount objectForKey:@"ps"] intValue] > 0 ||
                  [[unreadCount objectForKey:@"nt"] intValue] > 0) &&
                 [[newFeedCount objectForKey:@"ps"] intValue] == 0 &&
                 [[newFeedCount objectForKey:@"nt"] intValue] == 0)) {
                NSIndexPath *indexPath;
                for (int s=0; s < [appDelegate.dictFoldersArray count]; s++) {
                    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:s];
                    NSArray *activeFolderFeeds = [self.activeFeedLocations objectForKey:folderName];
                    NSArray *originalFolder = [appDelegate.dictFolders objectForKey:folderName];
                    for (int l=0; l < [activeFolderFeeds count]; l++) {
                        if ([[originalFolder objectAtIndex:[[activeFolderFeeds objectAtIndex:l] intValue]] intValue] == [feed intValue]) {
                            indexPath = [NSIndexPath indexPathForRow:l inSection:s];
                            break;
                        }
                    }
                    if (indexPath) break;
                }
                if (indexPath) {
                    [self.stillVisibleFeeds setObject:indexPath forKey:feedIdStr];
                }
            }
            [unreadCount setObject:[newFeedCount objectForKey:@"ng"] forKey:@"ng"];
            [unreadCount setObject:[newFeedCount objectForKey:@"nt"] forKey:@"nt"];
            [unreadCount setObject:[newFeedCount objectForKey:@"ps"] forKey:@"ps"];
            [appDelegate.dictUnreadCounts setObject:unreadCount forKey:feedIdStr];
        }
        
        NSDictionary *newSocialFeedCounts = [results objectForKey:@"social_feeds"];
        for (id feed in newSocialFeedCounts) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", feed];
            NSMutableDictionary *unreadCount = [[appDelegate.dictUnreadCounts objectForKey:feedIdStr] mutableCopy];
            NSMutableDictionary *newFeedCount = [newSocialFeedCounts objectForKey:feed];

            if (![unreadCount isKindOfClass:[NSDictionary class]]) continue;
            [unreadCount setObject:[newFeedCount objectForKey:@"ng"] forKey:@"ng"];
            [unreadCount setObject:[newFeedCount objectForKey:@"nt"] forKey:@"nt"];
            [unreadCount setObject:[newFeedCount objectForKey:@"ps"] forKey:@"ps"];
            [appDelegate.dictUnreadCounts setObject:unreadCount forKey:feedIdStr];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [appDelegate.folderCountCache removeAllObjects];
            [self.feedTitlesTable reloadData];
            [self refreshHeaderCounts];
            if (![request.userInfo objectForKey:@"feedId"]) {
                [self.appDelegate startOfflineQueue];
            }
        });
    });
}

// called when the date shown needs to be updated, optional
- (NSDate *)pullToRefreshViewLastUpdated:(PullToRefreshView *)view {
    return self.lastUpdate;
}

#pragma mark -
#pragma mark WEPopoverControllerDelegate implementation

- (void)popoverControllerDidDismissPopover:(WEPopoverController *)thePopoverController {
	//Safe to release the popover here
	self.popoverController = nil;
}

- (BOOL)popoverControllerShouldDismissPopover:(WEPopoverController *)thePopoverController {
	//The popover is automatically dismissed if you click outside it, unless you return NO here
	return YES;
}


/**
 Thanks to Paul Solt for supplying these background images and container view properties
 */
- (WEPopoverContainerViewProperties *)improvedContainerViewProperties {
	
	WEPopoverContainerViewProperties *props = [WEPopoverContainerViewProperties alloc];
	NSString *bgImageName = nil;
	CGFloat bgMargin = 0.0;
	CGFloat bgCapSize = 0.0;
	CGFloat contentMargin = 5.0;
	
	bgImageName = @"popoverBg.png";
	
	// These constants are determined by the popoverBg.png image file and are image dependent
	bgMargin = 13; // margin width of 13 pixels on all sides popoverBg.png (62 pixels wide - 36 pixel background) / 2 == 26 / 2 == 13 
	bgCapSize = 31; // ImageSize/2  == 62 / 2 == 31 pixels
	
	props.leftBgMargin = bgMargin;
	props.rightBgMargin = bgMargin;
	props.topBgMargin = bgMargin;
	props.bottomBgMargin = bgMargin;
	props.leftBgCapSize = bgCapSize;
	props.topBgCapSize = bgCapSize;
	props.bgImageName = bgImageName;
	props.leftContentMargin = contentMargin;
	props.rightContentMargin = contentMargin - 1; // Need to shift one pixel for border to look correct
	props.topContentMargin = contentMargin; 
	props.bottomContentMargin = contentMargin;
	
	props.arrowMargin = 4.0;
	
	props.upArrowImageName = @"popoverArrowUp.png";
	props.downArrowImageName = @"popoverArrowDown.png";
	props.leftArrowImageName = @"popoverArrowLeft.png";
	props.rightArrowImageName = @"popoverArrowRight.png";
	return props;	
}

- (void)resetToolbar {
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.rightBarButtonItem = nil;
}

- (void)layoutHeaderCounts:(UIInterfaceOrientation)orientation {
    if (!orientation) {
        orientation = [UIApplication sharedApplication].statusBarOrientation;
    }
    
    BOOL isShort = NO;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone &&
        UIInterfaceOrientationIsLandscape(orientation)) {
        isShort = YES;
    }
    
    int yOffset = isShort ? 0 : 6;
    UIView *userInfoView = [[UIView alloc]
                            initWithFrame:CGRectMake(0, 0,
                                                     self.navigationController.toolbar.frame.size.width,
                                                     self.navigationController.toolbar.frame.size.height)];
    // adding user avatar to left
    NSURL *imageURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@",
                                            [appDelegate.dictSocialProfile
                                             objectForKey:@"photo_url"]]];
    userAvatarButton = [UIBarButtonItem barItemWithImage:[UIImage alloc]
                                                  target:self
                                                  action:@selector(showUserProfile)];
    userAvatarButton.customView.frame = CGRectMake(0, yOffset + 1, isShort ? 28 : 32, isShort ? 28 : 32);
    
    NSMutableURLRequest *avatarRequest = [NSMutableURLRequest requestWithURL:imageURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    [avatarRequest setHTTPShouldHandleCookies:NO];
    [avatarRequest setHTTPShouldUsePipelining:YES];
    UIImageView *avatarImageView = [[UIImageView alloc] initWithFrame:userAvatarButton.customView.frame];
    [avatarImageView setImageWithURLRequest:avatarRequest placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        image = [Utilities roundCorneredImage:image radius:3];
        [(UIButton *)userAvatarButton.customView setImage:image forState:UIControlStateNormal];
    } failure:nil];
    //    self.navigationItem.leftBarButtonItem = userInfoBarButton;
    
    //    [userInfoView addSubview:userAvatarButton];
    
    userLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, yOffset, userInfoView.frame.size.width, 16)];
    userLabel.text = appDelegate.activeUsername;
    userLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14.0];
    userLabel.textColor = UIColorFromRGB(0x404040);
    userLabel.backgroundColor = [UIColor clearColor];
    userLabel.shadowColor = UIColorFromRGB(0xFAFAFA);
    [userLabel sizeToFit];
    [userInfoView addSubview:userLabel];
    
    [appDelegate.folderCountCache removeObjectForKey:@"everything"];
    UIImageView *yellow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"g_icn_unread"]];
    yellow.frame = CGRectMake(0, userLabel.frame.origin.y + userLabel.frame.size.height + 4, 8, 8);
    [userInfoView addSubview:yellow];
    
    neutralCount = [[UILabel alloc] init];
    neutralCount.frame = CGRectMake(yellow.frame.size.width + yellow.frame.origin.x + 2,
                                    yellow.frame.origin.y - 3, 100, 16);
    neutralCount.font = [UIFont fontWithName:@"Helvetica" size:11];
    neutralCount.textColor = UIColorFromRGB(0x707070);
    neutralCount.backgroundColor = [UIColor clearColor];
    [neutralCount sizeToFit];
    [userInfoView addSubview:neutralCount];
    
    greenIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"g_icn_focus"]];
    greenIcon.frame = CGRectMake(neutralCount.frame.origin.x + neutralCount.frame.size.width + 8,
                             yellow.frame.origin.y, 8, 8);
    [userInfoView addSubview:greenIcon];
    
    positiveCount = [[UILabel alloc] init];
    positiveCount.frame = CGRectMake(greenIcon.frame.size.width + greenIcon.frame.origin.x + 2,
                                     greenIcon.frame.origin.y - 3, 100, 16);
    positiveCount.font = [UIFont fontWithName:@"Helvetica" size:11];
    positiveCount.textColor = UIColorFromRGB(0x707070);
    positiveCount.backgroundColor = [UIColor clearColor];
    [positiveCount sizeToFit];
    [userInfoView addSubview:positiveCount];
    
    [userInfoView sizeToFit];
    
    userInfoBarButton = [[UIBarButtonItem alloc]
                         initWithCustomView:userInfoView];
    UIBarButtonItem *spacer = [[UIBarButtonItem alloc]
                               initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                               target:nil
                               action:nil];
    spacer.width = -8;
    self.navigationItem.leftBarButtonItems = [NSArray arrayWithObjects:
                                              spacer,
                                              userAvatarButton,
                                              userInfoBarButton, nil];
}

- (void)refreshHeaderCounts {
    if (!appDelegate.activeUsername) {
        userAvatarButton.customView.hidden = YES;
        userInfoBarButton.customView.hidden = YES;
        return;
    }
    
    userAvatarButton.customView.hidden = NO;
    userInfoBarButton.customView.hidden = NO;
    [appDelegate.folderCountCache removeObjectForKey:@"everything"];

    NSNumberFormatter *formatter = [NSNumberFormatter new];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    UnreadCounts *counts = [appDelegate splitUnreadCountForFolder:@"everything"];
    
    positiveCount.text = [formatter stringFromNumber:[NSNumber numberWithInt:counts.ps]];
    
    CGRect yellow = CGRectMake(0, userLabel.frame.origin.y + userLabel.frame.size.height + 4, 8, 8);
    neutralCount.text = [formatter stringFromNumber:[NSNumber numberWithInt:counts.nt]];
    neutralCount.frame = CGRectMake(yellow.size.width + yellow.origin.x + 2,
                                    yellow.origin.y - 3, 100, 16);
    [neutralCount sizeToFit];
    
    greenIcon.frame = CGRectMake(neutralCount.frame.origin.x + neutralCount.frame.size.width + 8,
                                 yellow.origin.y, 8, 8);
    positiveCount.frame = CGRectMake(greenIcon.frame.size.width + greenIcon.frame.origin.x + 2,
                                     greenIcon.frame.origin.y - 3, 100, 16);
    [positiveCount sizeToFit];
    
    [userInfoBarButton.customView sizeToFit];
}

- (void)showRefreshNotifier {
    self.notifier.style = NBSyncingStyle;
    self.notifier.title = @"On its way...";
    [self.notifier setProgress:0];
    [self.notifier show];
}

- (void)showCountingNotifier {
    self.notifier.style = NBSyncingStyle;
    self.notifier.title = @"Counting is difficult...";
    [self.notifier setProgress:0];
    [self.notifier show];
}

- (void)showSyncingNotifier {
    self.notifier.style = NBSyncingStyle;
    self.notifier.title = @"Syncing stories...";
    [self.notifier setProgress:0];
    [self.notifier show];
}

- (void)showDoneNotifier {
    self.notifier.style = NBDoneStyle;
    self.notifier.title = @"All done";
    [self.notifier setProgress:0];
    [self.notifier show];
}

- (void)showSyncingNotifier:(float)progress hoursBack:(int)hours {
//    [self.notifier hide];
    self.notifier.style = NBSyncingProgressStyle;
    if (hours < 2) {
        self.notifier.title = @"Storing past hour";
    } else if (hours < 24) {
        self.notifier.title = [NSString stringWithFormat:@"Storing past %d hours", hours];
    } else if (hours < 48) {
        self.notifier.title = @"Storing yesterday";
    } else {
        self.notifier.title = [NSString stringWithFormat:@"Storing past %d days", (int)round(hours / 24.f)];
    }
    [self.notifier setProgress:progress];
    [self.notifier setNeedsDisplay];
    [self.notifier show];
}

- (void)showCachingNotifier:(float)progress hoursBack:(int)hours {
    //    [self.notifier hide];
    self.notifier.style = NBSyncingProgressStyle;
    if (hours < 2) {
        self.notifier.title = @"Images from last hour";
    } else if (hours < 24) {
        self.notifier.title = [NSString stringWithFormat:@"Images from %d hours ago", hours];
    } else if (hours < 48) {
        self.notifier.title = @"Images from yesterday";
    } else {
        self.notifier.title = [NSString stringWithFormat:@"Images from %d days ago", (int)round(hours / 24.f)];
    }
    [self.notifier setProgress:progress];
    [self.notifier setNeedsDisplay];
    [self.notifier show];
}

- (void)showOfflineNotifier {
    self.notifier.style = NBOfflineStyle;
    self.notifier.title = @"Offline";
    [self.notifier show];
}

- (void)hideNotifier {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [self.notifier hide];
    });
}

@end