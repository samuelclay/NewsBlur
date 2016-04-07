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
#import "DashboardViewController.h"
#import "FeedsMenuViewController.h"
#import "FeedDetailMenuViewController.h"
#import "FeedDetailViewController.h"
#import "UserProfileViewController.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "ASIHTTPRequest.h"
#import "AFHTTPRequestOperation.h"
#import "PullToRefreshView.h"
#import "MBProgressHUD.h"
#import "Base64.h"
#import "SBJson4.h"
#import "NSObject+SBJSON.h"
#import "NBNotifier.h"
#import "Utilities.h"
#import "UIBarButtonItem+Image.h"
#import "AddSiteViewController.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "IASKAppSettingsViewController.h"
#import "IASKSettingsReader.h"
#import "UIImageView+AFNetworking.h"
#import "NBBarButtonItem.h"
#import "StoriesCollection.h"

static const CGFloat kPhoneTableViewRowHeight = 31.0f;
static const CGFloat kTableViewRowHeight = 31.0f;
static const CGFloat kBlurblogTableViewRowHeight = 32.0f;
static const CGFloat kPhoneBlurblogTableViewRowHeight = 32.0f;
static const CGFloat kFolderTitleHeight = 28.0f;
static UIFont *userLabelFont;

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
@synthesize interactiveFeedDetailTransition;
@synthesize avatarImageView;

#pragma mark -
#pragma mark Globals

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    pull = [[PullToRefreshView alloc] initWithScrollView:self.feedTitlesTable];
    self.pull.tintColor = UIColorFromLightDarkRGB(0x0, 0xffffff);
    self.pull.backgroundColor = UIColorFromRGB(0xE3E6E0);
    [pull setDelegate:self];
    [self.feedTitlesTable addSubview:pull];

    userLabelFont = [UIFont fontWithName:@"Helvetica-Bold" size:14.0];
    
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
    
    [self updateIntelligenceControlForOrientation:UIInterfaceOrientationUnknown];
    
    self.intelligenceControl.hidden = YES;
    [self.intelligenceControl.subviews objectAtIndex:3].accessibilityLabel = @"All";
    [self.intelligenceControl.subviews objectAtIndex:2].accessibilityLabel = @"Unread";
    [self.intelligenceControl.subviews objectAtIndex:1].accessibilityLabel = @"Focus";
    [self.intelligenceControl.subviews objectAtIndex:0].accessibilityLabel = @"Saved";
    
    [[UIBarButtonItem appearance] setTintColor:UIColorFromRGB(0x8F918B)];
    [[UIBarButtonItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName:
                                                               UIColorFromFixedRGB(0x8F918B)}
                                                forState:UIControlStateNormal];
    [[UIBarButtonItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName:
                                                               UIColorFromFixedRGB(0x4C4D4A)}
                                                forState:UIControlStateHighlighted];
    self.navigationController.navigationBar.tintColor = UIColorFromRGB(0x8F918B);
    self.navigationController.navigationBar.translucent = NO;
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    [self layoutForInterfaceOrientation:orientation];
    
    UILongPressGestureRecognizer *longpress = [[UILongPressGestureRecognizer alloc]
                                               initWithTarget:self action:@selector(handleLongPress:)];
    longpress.minimumPressDuration = 1.0;
    longpress.delegate = self;
    [self.feedTitlesTable addGestureRecognizer:longpress];
    
    [[ThemeManager themeManager] addThemeGestureRecognizerToView:self.feedTitlesTable];
    
    self.notifier = [[NBNotifier alloc] initWithTitle:@"Fetching stories..."
                                               inView:self.view
                                           withOffset:CGPointMake(0, self.feedViewToolbar.frame.size.height)];
    [self.view insertSubview:self.notifier belowSubview:self.feedViewToolbar];
    
    self.feedTitlesTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.feedTitlesTable.separatorColor = [UIColor clearColor];
    
    userAvatarButton.customView.hidden = YES;
    userInfoBarButton.customView.hidden = YES;
    
    [self.navigationController.interactivePopGestureRecognizer addTarget:self action:@selector(handleGesture:)];
    
    [self addKeyCommandWithInput:@"e" modifierFlags:UIKeyModifierShift action:@selector(selectEverything:) discoverabilityTitle:@"Open All Stories"];
    [self addKeyCommandWithInput:UIKeyInputLeftArrow modifierFlags:0 action:@selector(selectPreviousIntelligence:) discoverabilityTitle:@"Switch Views"];
    [self addKeyCommandWithInput:UIKeyInputRightArrow modifierFlags:0 action:@selector(selectNextIntelligence:) discoverabilityTitle:@"Switch Views"];
    [self addKeyCommandWithInput:@"a" modifierFlags:0 action:@selector(tapAddSite:) discoverabilityTitle:@"Add Site"];
}

- (void)viewWillAppear:(BOOL)animated {
//    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
        !self.interactiveFeedDetailTransition) {
        
        [appDelegate.masterContainerViewController transitionFromFeedDetail];
    }
//    NSLog(@"Feed List timing 0: %f", [NSDate timeIntervalSinceReferenceDate] - start);
    [super viewWillAppear:animated];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSInteger intelligenceLevel = [userPreferences integerForKey:@"selectedIntelligence"];
    
    if (intelligenceLevel == 2) {
        self.viewShowingAllFeeds = NO;
        [self.intelligenceControl setSelectedSegmentIndex:3];
        [appDelegate setSelectedIntelligence:2];
    } else if (intelligenceLevel == 1) {
        self.viewShowingAllFeeds = NO;
        [self.intelligenceControl setSelectedSegmentIndex:2];
        [appDelegate setSelectedIntelligence:1];
    } else if (intelligenceLevel == 0) {
        self.viewShowingAllFeeds = NO;
        [self.intelligenceControl setSelectedSegmentIndex:1];
        [appDelegate setSelectedIntelligence:0];
    } else {
        // default state, ALL BLURBLOG STORIES
        self.viewShowingAllFeeds = YES;
        [self.intelligenceControl setSelectedSegmentIndex:0];
        [appDelegate setSelectedIntelligence:0];
    }
    
//    [MBProgressHUD hideHUDForView:appDelegate.storyPageControl.view animated:NO];
    
    // perform these only if coming from the feed detail view
    if (appDelegate.inFeedDetail) {
        appDelegate.inFeedDetail = NO;
        // reload the data and then set the highlight again
//        [self.feedTitlesTable reloadData];
//        [self refreshHeaderCounts];
        [self redrawUnreadCounts];
//        [self.feedTitlesTable selectRowAtIndexPath:self.currentRowAtIndexPath
//                                          animated:NO 
//                                    scrollPosition:UITableViewScrollPositionNone];
        [self.notifier setNeedsLayout];
    }
    
//    NSLog(@"Feed List timing 2: %f", [NSDate timeIntervalSinceReferenceDate] - start);
}

- (void)viewDidAppear:(BOOL)animated {
//    [self.feedTitlesTable selectRowAtIndexPath:self.currentRowAtIndexPath 
//                                      animated:NO 
//                                scrollPosition:UITableViewScrollPositionNone];
    
    [super viewDidAppear:animated];
    [self performSelector:@selector(fadeSelectedCell) withObject:self afterDelay:0.2];
//    self.navigationController.navigationBar.backItem.title = @"All Sites";
    [self layoutHeaderCounts:nil];
    [self refreshHeaderCounts];

    self.interactiveFeedDetailTransition = NO;

    [self becomeFirstResponder];
}

- (void)handleGesture:(UIScreenEdgePanGestureRecognizer *)gesture {
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) return;
    
    self.interactiveFeedDetailTransition = YES;
    
    CGPoint point = [gesture locationInView:self.view];
    CGFloat viewWidth = CGRectGetWidth(self.view.frame);
    CGFloat percentage = MIN(point.x, viewWidth) / viewWidth;
//    NSLog(@"back gesture: %d, %f - %f/%f", (int)gesture.state, percentage, point.x, viewWidth);
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        if (appDelegate.storiesCollection.transferredFromDashboard) {
            [appDelegate.dashboardViewController.storiesModule.storiesCollection
             transferStoriesFromCollection:appDelegate.storiesCollection];
            [appDelegate.dashboardViewController.storiesModule fadeSelectedCell:NO];
        }
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        [appDelegate.masterContainerViewController interactiveTransitionFromFeedDetail:percentage];
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        CGPoint velocity = [gesture velocityInView:self.view];
        if (velocity.x > 0) {
            [appDelegate.masterContainerViewController transitionFromFeedDetail];
        } else {
//            // Returning back to view, cancelling pop animation.
//            [appDelegate.masterContainerViewController transitionToFeedDetail:NO];
        }

        self.interactiveFeedDetailTransition = NO;
    }
}

- (void)fadeSelectedCell {
    NSIndexPath *indexPath = [self.feedTitlesTable indexPathForSelectedRow];
    if (!indexPath) return;
    [self.feedTitlesTable deselectRowAtIndexPath:indexPath
                                        animated:YES];

    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    id feedId = [[appDelegate.dictFolders objectForKey:folderName] objectAtIndex:indexPath.row];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];

    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
//    NSLog(@"Show feeds after being read (%@): %d / %@ -> %@", feedIdStr, [preferences boolForKey:@"show_feeds_after_being_read"], [self.stillVisibleFeeds objectForKey:feedIdStr], self.stillVisibleFeeds);
    NSIndexPath *visiblePath = [self.stillVisibleFeeds objectForKey:feedIdStr];
    if (visiblePath) {
        [self.feedTitlesTable beginUpdates];
        NSMutableArray *paths = (indexPath.section == visiblePath.section &&
                                 indexPath.row == visiblePath.row)
        ? @[indexPath].mutableCopy
        : @[indexPath, visiblePath].mutableCopy;
        if (![preferences boolForKey:@"show_feeds_after_being_read"]) {
            [self.stillVisibleFeeds removeObjectForKey:feedIdStr];
            for (NSString *feedId in [self.stillVisibleFeeds allKeys]) {
                NSLog(@"Found inadvertantly still visible feed: %@", feedId);
                [paths addObject:[self.stillVisibleFeeds objectForKey:feedId]];
            }
        }
        [self.feedTitlesTable reloadRowsAtIndexPaths:paths
                                    withRowAnimation:UITableViewRowAnimationFade];
        [self.feedTitlesTable endUpdates];
        if (![preferences boolForKey:@"show_feeds_after_being_read"]) {
            [self.stillVisibleFeeds removeAllObjects];
        }
    }
}

- (void)fadeFeed:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
    [self.feedTitlesTable deselectRowAtIndexPath:[self.feedTitlesTable indexPathForSelectedRow]
                                        animated:YES];
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    if (![preferences boolForKey:@"show_feeds_after_being_read"]) {
        for (NSIndexPath *indexPath in [self.feedTitlesTable indexPathsForVisibleRows]) {
            NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
            id cellFeedId = [[appDelegate.dictFolders objectForKey:folderName] objectAtIndex:indexPath.row];
            if ([feedIdStr isEqualToString:[NSString stringWithFormat:@"%@", cellFeedId]]) {
                [self.feedTitlesTable beginUpdates];
                [self.feedTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                            withRowAnimation:UITableViewRowAnimationFade];
                [self.feedTitlesTable endUpdates];
                break;
            }
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.appDelegate hidePopoverAnimated:YES];
    [super viewWillDisappear:animated];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        [self layoutForInterfaceOrientation:orientation];
        [self.notifier setNeedsLayout];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self.feedTitlesTable reloadData];
    }];
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
    
    [self updateIntelligenceControlForOrientation:interfaceOrientation];
    [self layoutHeaderCounts:interfaceOrientation];
    [self refreshHeaderCounts];
}

- (void)updateIntelligenceControlForOrientation:(UIInterfaceOrientation)orientation {
    if (orientation == UIInterfaceOrientationUnknown) {
        orientation = [UIApplication sharedApplication].statusBarOrientation;
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && !UIInterfaceOrientationIsLandscape(orientation)) {
        [self.intelligenceControl setImage:[UIImage imageNamed:@"unread_yellow_icn.png"] forSegmentAtIndex:1];
        [self.intelligenceControl setImage:[UIImage imageNamed:@"unread_green_icn.png"] forSegmentAtIndex:2];
        [self.intelligenceControl setImage:[UIImage imageNamed:@"unread_blue_icn.png"] forSegmentAtIndex:3];
        
        [self.intelligenceControl setWidth:45 forSegmentAtIndex:0];
        [self.intelligenceControl setWidth:40 forSegmentAtIndex:1];
        [self.intelligenceControl setWidth:40 forSegmentAtIndex:2];
        [self.intelligenceControl setWidth:40 forSegmentAtIndex:3];
    } else {
        [self.intelligenceControl setImage:[UIImage imageNamed:@"unread_yellow.png"] forSegmentAtIndex:1];
        [self.intelligenceControl setImage:[UIImage imageNamed:@"unread_green.png"] forSegmentAtIndex:2];
        [self.intelligenceControl setImage:[UIImage imageNamed:@"unread_blue.png"] forSegmentAtIndex:3];
        
        [self.intelligenceControl setWidth:52 forSegmentAtIndex:0];
        [self.intelligenceControl setWidth:68 forSegmentAtIndex:1];
        [self.intelligenceControl setWidth:62 forSegmentAtIndex:2];
        [self.intelligenceControl setWidth:62 forSegmentAtIndex:3];
    }
    
    [self.intelligenceControl sizeToFit];
    
    NSInteger height = 16;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && UIInterfaceOrientationIsLandscape(orientation)) {
        height = 8;
    }
    
    CGRect intelFrame = self.intelligenceControl.frame;
    intelFrame.origin.x = (self.feedViewToolbar.frame.size.width / 2) - (intelFrame.size.width / 2) + 20;
    intelFrame.size.height = self.feedViewToolbar.frame.size.height - height;
    self.intelligenceControl.frame = intelFrame;
}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
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
    NSLog(@"Fetching feed list");
    [appDelegate cancelOfflineQueue];
    
    if (self.inPullToRefresh_) {
        urlFeedList = [NSURL URLWithString:
                      [NSString stringWithFormat:@"%@/reader/feeds?flat=true&update_counts=true",
                      self.appDelegate.url]];
    } else {
        urlFeedList = [NSURL URLWithString:
                       [NSString stringWithFormat:@"%@/reader/feeds?flat=true&update_counts=false",
                        self.appDelegate.url]];
    }
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:urlFeedList];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    [request setValidatesSecureCertificate:NO];
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
    
    self.isOffline = YES;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.dashboardViewController refreshStories];
    }

    [self showOfflineNotifier];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FinishedLoadingFeedsNotification" object:nil];
}

- (void)finishLoadingFeedList:(ASIHTTPRequest *)request {
    if ([request responseStatusCode] == 403) {
        NSLog(@"Showing login");
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
        
        self.isOffline = YES;
        [self showOfflineNotifier];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [appDelegate.dashboardViewController refreshStories];
        }
        return;
    }
    
    appDelegate.hasNoSites = NO;
    appDelegate.recentlyReadStories = [NSMutableDictionary dictionary];
    appDelegate.unreadStoryHashes = [NSMutableDictionary dictionary];

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
            [self finishLoadingFeedListWithDict:results finished:YES];
        });
    });

}

- (void)finishLoadingFeedListWithDict:(NSDictionary *)results finished:(BOOL)finished {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    self.stillVisibleFeeds = [NSMutableDictionary dictionary];
    [pull finishedLoading];

    appDelegate.activeUsername = [results objectForKey:@"user"];
    if (appDelegate.activeUsername) {
        [userPreferences setObject:appDelegate.activeUsername forKey:@"active_username"];
        [userPreferences synchronize];
    }
    
    // Bottom toolbar
    UIImage *addImage = [UIImage imageNamed:@"nav_icn_add.png"];
    UIImage *settingsImage = [UIImage imageNamed:@"nav_icn_settings.png"];
    addBarButton.enabled = YES;
    addBarButton.accessibilityLabel = @"Add site";
    settingsBarButton.enabled = YES;
    settingsBarButton.accessibilityLabel = @"Settings";
    NBBarButtonItem *addButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
    [addButton setImage:[[ThemeManager themeManager] themedImage:addImage] forState:UIControlStateNormal];
    [addButton sizeToFit];
    [addButton addTarget:self action:@selector(tapAddSite:)
        forControlEvents:UIControlEventTouchUpInside];
    addButton.accessibilityLabel = @"Add feed";
    [addBarButton setCustomView:addButton];

    NBBarButtonItem *settingsButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
    settingsButton.onRightSide = YES;
    [settingsButton setImage:[[ThemeManager themeManager] themedImage:settingsImage] forState:UIControlStateNormal];
    [settingsButton sizeToFit];
    [settingsButton addTarget:self action:@selector(showSettingsPopover:)
             forControlEvents:UIControlEventTouchUpInside];
    settingsButton.accessibilityLabel = @"Settings";
    [settingsBarButton setCustomView:settingsButton];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        UIImage *activityImage = [UIImage imageNamed:@"nav_icn_activity_hover.png"];
        NBBarButtonItem *activityButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
        [activityButton setImage:activityImage forState:UIControlStateNormal];
        [activityButton sizeToFit];
        [activityButton setContentEdgeInsets:UIEdgeInsetsMake(0, -6, -0, -6)];
        [activityButton setFrame:CGRectInset(activityButton.frame, 0, -6)];
        [activityButton setImageEdgeInsets:UIEdgeInsetsMake(12, 12, 12, 12)];
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
    appDelegate.dictUnreadCounts = [NSMutableDictionary dictionary];
    appDelegate.dictSocialProfile = [results objectForKey:@"social_profile"];
    appDelegate.dictUserProfile = [results objectForKey:@"user_profile"];
    appDelegate.dictSocialServices = [results objectForKey:@"social_services"];
    appDelegate.userActivitiesArray = [results objectForKey:@"activities"];
    
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
    
    appDelegate.dictSocialFeeds = socialDict;
    
    // set up dictFolders
    NSMutableDictionary * allFolders = [[NSMutableDictionary alloc] init];
    
    if (![[results objectForKey:@"flat_folders"] isKindOfClass:[NSArray class]]) {
        allFolders = [[results objectForKey:@"flat_folders"] mutableCopy];
    }

    [allFolders setValue:socialFolder forKey:@"river_blurblogs"];
    [allFolders setValue:[[NSMutableArray alloc] init] forKey:@"river_global"];
    
    NSArray *savedStories = [appDelegate updateStarredStoryCounts:results];
    [allFolders setValue:savedStories forKey:@"saved_stories"];

    appDelegate.dictFolders = allFolders;
    
    // set up dictFeeds
    appDelegate.dictFeeds = [[results objectForKey:@"feeds"] mutableCopy];
    [appDelegate populateDictUnreadCounts];
    [appDelegate populateDictTextFeeds];
    
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
    
    // Add Read Stories folder
    [appDelegate.dictFoldersArray removeObject:@"read_stories"];
    [appDelegate.dictFoldersArray insertObject:@"read_stories" atIndex:appDelegate.dictFoldersArray.count];

    // Add Saved Stories folder
    [appDelegate.dictFoldersArray removeObject:@"saved_stories"];
    if (appDelegate.savedStoriesCount) {
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
    NSString *serveriPhoneBuild = [results objectForKey:@"latest_ios_build"];
    NSString *currentiPhoneBuild = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
    NSString *serveriPhoneVersion = [results objectForKey:@"latest_ios_version"];
    NSString *currentiPhoneVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    BOOL unseenBuild = [serveriPhoneBuild integerValue] > [userPreferences integerForKey:@"last_seen_latest_ios_build"];

    if ([currentiPhoneBuild integerValue] < [serveriPhoneBuild integerValue] && unseenBuild) {
        NSLog(@"Build: %ld - %@ (seen: %ld)", (long)[serveriPhoneBuild integerValue], currentiPhoneBuild, (long)[userPreferences integerForKey:@"last_seen_latest_ios_build"]);
        [userPreferences setInteger:[serveriPhoneBuild integerValue] forKey:@"last_seen_latest_ios_build"];
        [userPreferences setObject:serveriPhoneVersion forKey:@"last_seen_latest_ios_version"];
        [userPreferences synchronize];
        
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

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && finished) {
        [appDelegate.dashboardViewController refreshStories];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FinishedLoadingFeedsNotification" object:nil];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 2) {
        if (buttonIndex == 0) {
            return;
        } else {
            NSURL *url;
            NSString *currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
            NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
            NSString *serverVersion = [userPreferences stringForKey:@"last_seen_latest_ios_version"];

            if ([currentVersion containsString:@"b"] && [serverVersion containsString:@"b"]) {
                url = [NSURL URLWithString:@"https://www.newsblur.com/ios/download"];
            } else {
                //  this doesn't work in simulator!!! because simulator has no app store
                url = [NSURL URLWithString:@"itms://itunes.apple.com/us/app/mensa-essen/id463981119?ls=1&mt=8"];
            }
            [[UIApplication sharedApplication] openURL:url];
        }
    }
}

- (void)loadOfflineFeeds:(BOOL)failed {
    __block __typeof__(self) _self = self;
    self.isOffline = YES;
    NSLog(@"Loading offline feeds: %d", failed);
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
            [_self finishLoadingFeedListWithDict:results finished:failed];
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
    [self.appDelegate.addSiteNavigationController popToRootViewControllerAnimated:NO];
    
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.appDelegate showPopoverWithViewController:self.appDelegate.addSiteNavigationController contentSize:CGSizeMake(320, 96) sourceView:self.addBarButton.customView sourceRect:CGRectMake(35.0, 0.0, 0.0, 0.0) permittedArrowDirections:UIPopoverArrowDirectionDown];
//    } else {
//        [self.appDelegate showPopoverWithViewController:self.appDelegate.addSiteNavigationController contentSize:CGSizeMake(320, 96) barButtonItem:self.addBarButton];
//    }
    
    [self.appDelegate.addSiteViewController reload];
}

- (IBAction)showSettingsPopover:(id)sender {
    [self.appDelegate.feedsMenuViewController view];
    NSInteger menuCount = [self.appDelegate.feedsMenuViewController.menuOptions count];
    
    [self.appDelegate showPopoverWithViewController:self.appDelegate.feedsMenuViewController contentSize:CGSizeMake(220, 38 * (menuCount + 1)) barButtonItem:self.settingsBarButton];
}

- (IBAction)showInteractionsPopover:(id)sender {
    if (self.presentedViewController) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    CGSize size = CGSizeMake(self.view.frame.size.width - 36,
                             self.view.frame.size.height - 60);
    
    [self.appDelegate showPopoverWithViewController:self.appDelegate.dashboardViewController contentSize:size barButtonItem:self.activitiesButton];
    
    [appDelegate.dashboardViewController refreshInteractions];
    [appDelegate.dashboardViewController refreshActivity];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    CGPoint p = [gestureRecognizer locationInView:self.feedTitlesTable];
    NSIndexPath *indexPath = [self.feedTitlesTable indexPathForRowAtPoint:p];
    
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) return;
    if (indexPath == nil) return;

    FeedTableCell *cell = (FeedTableCell *)[self.feedTitlesTable cellForRowAtIndexPath:indexPath];
    if (!cell.highlighted) return;

    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSString *longPressTitle = [preferences stringForKey:@"long_press_feed_title"];
    
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    id feedId = [[appDelegate.dictFolders objectForKey:folderName] objectAtIndex:indexPath.row];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
//    BOOL isSocial = [appDelegate isSocialFeed:feedIdStr];
    BOOL isSaved = [appDelegate isSavedFeed:feedIdStr] || self.appDelegate.isSavedStoriesIntelligenceMode;
    
    if (isSaved) return;
    
    [self performSelector:@selector(highlightCell:) withObject:cell afterDelay:0.0];

    if ([longPressTitle isEqualToString:@"mark_read_choose_days"]) {
//        NSDictionary *feed = isSocial ?
//                            [appDelegate.dictSocialFeeds objectForKey:feedIdStr] :
//                            [appDelegate.dictFeeds objectForKey:feedIdStr];
        
        [self.appDelegate showMarkReadMenuWithFeedIds:@[feedIdStr] collectionTitle:@"site" sourceView:self.view sourceRect:cell.frame completionHandler:^(BOOL marked){
            for (FeedTableCell *cell in [self.feedTitlesTable visibleCells]) {
                if (cell.highlighted) {
                    [self performSelector:@selector(unhighlightCell:) withObject:cell afterDelay:0.0];
                    break;
                }
            }
        }];
        
    } else if ([longPressTitle isEqualToString:@"mark_read_immediate"]) {
        [self markFeedRead:feedId cutoffDays:0];
        
//        if ([preferences boolForKey:@"show_feeds_after_being_read"]) {
            [self.stillVisibleFeeds setObject:indexPath forKey:feedIdStr];
//        }
        [self.feedTitlesTable beginUpdates];
        [self.feedTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                    withRowAnimation:UITableViewRowAnimationFade];
        [self.feedTitlesTable endUpdates];
    }
    
}

- (void)highlightCell:(FeedTableCell *)cell {
    [cell setHighlighted:YES];
}
- (void)unhighlightCell:(FeedTableCell *)cell {
    [cell setHighlighted:NO];
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSLog(@"unhighlight cell");
    if (![preferences boolForKey:@"show_feeds_after_being_read"]) {
        NSIndexPath *indexPath = [self.feedTitlesTable indexPathForCell:cell];
        [self.feedTitlesTable beginUpdates];
        [self.feedTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                    withRowAnimation:UITableViewRowAnimationFade];
        [self.feedTitlesTable endUpdates];
    }
}

#pragma mark -
#pragma mark Preferences

- (void)settingsViewControllerWillAppear:(IASKAppSettingsViewController *)sender {
    [[ThemeManager themeManager] updatePreferencesTheme];
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [appDelegate.navigationController dismissViewControllerAnimated:YES completion:nil];
    }
    
    [self resizeFontSize];
}

- (void)resizeFontSize {
    appDelegate.fontDescriptorTitleSize = nil;
    [self.feedTitlesTable reloadData];
    
    appDelegate.feedDetailViewController.invalidateFontCache = YES;
    [appDelegate.feedDetailViewController reloadData];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.dashboardViewController.storiesModule reloadData];
    }
}

- (void)updateTheme {
    [super updateTheme];
    
    if (![self.presentedViewController isKindOfClass:[UINavigationController class]] || (((UINavigationController *)self.presentedViewController).topViewController != (UIViewController *)self.appDelegate.fontSettingsViewController && ![((UINavigationController *)self.presentedViewController).topViewController conformsToProtocol:@protocol(IASKViewController)])) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    }
    
    [self.appDelegate hidePopoverAnimated:YES];
    
    self.navigationController.navigationBar.tintColor = [UINavigationBar appearance].tintColor;
    self.navigationController.navigationBar.barTintColor = [UINavigationBar appearance].barTintColor;
    self.navigationController.toolbar.tintColor = [UIToolbar appearance].tintColor;
    self.navigationController.toolbar.barTintColor = [UIToolbar appearance].barTintColor;
    self.feedViewToolbar.tintColor = [UINavigationBar appearance].tintColor;
    self.feedViewToolbar.barTintColor = [UINavigationBar appearance].barTintColor;
    self.addBarButton.tintColor = UIColorFromRGB(0x8F918B);
    self.intelligenceControl.tintColor = UIColorFromRGB(0x8F918B);
    self.settingsBarButton.tintColor = UIColorFromRGB(0x8F918B);
    self.pull.tintColor = UIColorFromLightDarkRGB(0x0, 0xffffff);
    self.pull.backgroundColor = UIColorFromRGB(0xE3E6E0);
    
    NBBarButtonItem *barButton = self.addBarButton.customView;
    [barButton setImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"nav_icn_add.png"]] forState:UIControlStateNormal];
    
    barButton = self.settingsBarButton.customView;
    [barButton setImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"nav_icn_settings.png"]] forState:UIControlStateNormal];
    
    [self layoutHeaderCounts:nil];
    [self refreshHeaderCounts];
    
    self.feedTitlesTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    [self.feedTitlesTable reloadData];
}

- (void)updateThemeBrightness {
    if ([[ThemeManager themeManager] autoChangeTheme]) {
        [[ThemeManager themeManager] updateTheme];
    }
}

- (void)updateThemeStyle {
    [[ThemeManager themeManager] updateTheme];
}

- (void)settingDidChange:(NSNotification*)notification {
    NSString *identifier = notification.object;
    
	if ([identifier isEqual:@"offline_allowed"]) {
		BOOL enabled = [[notification.userInfo objectForKey:@"offline_allowed"] boolValue];
		[appDelegate.preferencesViewController setHiddenKeys:enabled ? nil :
         [NSSet setWithObjects:@"offline_image_download",
          @"offline_download_connection",
          @"offline_store_limit",
          nil] animated:YES];
	} else if ([identifier isEqual:@"use_system_font_size"]) {
		BOOL enabled = [[notification.userInfo objectForKey:@"use_system_font_size"] boolValue];
		[appDelegate.preferencesViewController setHiddenKeys:!enabled ? nil :
         [NSSet setWithObjects:@"feed_list_font_size",
          nil] animated:YES];
    } else if ([identifier isEqual:@"feed_list_font_size"]) {
        [self resizeFontSize];
    } else if ([identifier isEqual:@"theme_auto_toggle"]) {
        BOOL enabled = [[notification.userInfo objectForKey:@"theme_auto_toggle"] boolValue];
        [appDelegate.preferencesViewController setHiddenKeys:!enabled ? [NSSet setWithObject:@"theme_auto_brightness"] : [NSSet setWithObjects:@"theme_style", @"theme_gesture", nil] animated:YES];
    } else if ([identifier isEqual:@"theme_auto_brightness"]) {
        [self updateThemeBrightness];
    } else if ([identifier isEqual:@"theme_style"]) {
        [self updateThemeStyle];
    } else if ([identifier isEqual:@"story_list_preview_images"]) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [appDelegate.dashboardViewController.storiesModule reloadData];
        }
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
    BOOL isSaved = [appDelegate isSavedFeed:feedIdStr];
    BOOL isSavedStoriesFeed = self.appDelegate.isSavedStoriesIntelligenceMode && [self.appDelegate savedStoriesCountForFeed:feedIdStr] > 0;
    BOOL isFolderCollapsed = [appDelegate isFolderCollapsed:folderName];
    
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
    } else if (isSaved) {
        CellIdentifier = @"SavedCellIdentifier";
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
                         isSaved ?
                         [appDelegate.dictSavedStoryTags objectForKey:feedIdStr] :
                         [appDelegate.dictFeeds objectForKey:feedIdStr];
    NSDictionary *unreadCounts = [appDelegate.dictUnreadCounts objectForKey:feedIdStr];
    cell.feedFavicon = [appDelegate getFavicon:feedIdStr isSocial:isSocial isSaved:isSaved];
    cell.feedTitle     = [feed objectForKey:@"feed_title"];
    cell.isSocial      = isSocial;
    cell.isSaved       = isSaved;
    
    if (isSavedStoriesFeed) {
        cell.positiveCount = 0;
        cell.neutralCount = 0;
        cell.negativeCount = 0;
        cell.savedStoriesCount = (int)[self.appDelegate savedStoriesCountForFeed:feedIdStr];
    } else {
        cell.positiveCount = [[unreadCounts objectForKey:@"ps"] intValue];
        cell.neutralCount  = [[unreadCounts objectForKey:@"nt"] intValue];
        cell.negativeCount = [[unreadCounts objectForKey:@"ng"] intValue];
        cell.savedStoriesCount = 0;
    }
    
    if (cell.neutralCount) {
        cell.accessibilityLabel = [NSString stringWithFormat:@"%@ feed, %@ unread stories", cell.feedTitle, @(cell.neutralCount)];
    } else {
        cell.accessibilityLabel = [NSString stringWithFormat:@"%@ feed", cell.feedTitle];
    }
    
    [cell setNeedsDisplay];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView 
        didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (appDelegate.hasNoSites) {
        return;
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.dashboardViewController.storiesModule.view endEditing:YES];
    }

    [appDelegate.storiesCollection reset];
    
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
    appDelegate.storiesCollection.isReadView = NO;
    if ([appDelegate isSocialFeed:feedIdStr]) {
        feed = [appDelegate.dictSocialFeeds objectForKey:feedIdStr];
        appDelegate.storiesCollection.isSocialView = YES;
        appDelegate.storiesCollection.isSavedView = NO;
    } else if ([appDelegate isSavedFeed:feedIdStr]) {
        feed = [appDelegate.dictSavedStoryTags objectForKey:feedIdStr];
        appDelegate.storiesCollection.isSocialView = NO;
        appDelegate.storiesCollection.isSavedView = YES;
        appDelegate.storiesCollection.activeSavedStoryTag = [feed objectForKey:@"tag"];
    } else {
        feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        appDelegate.storiesCollection.isSocialView = NO;
        appDelegate.storiesCollection.isSavedView = NO;
    }

    // If all feeds are already showing, no need to remember this one.
//    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    if (!self.viewShowingAllFeeds) {
//        [preferences boolForKey:@"show_feeds_after_being_read"]) {
        [self.stillVisibleFeeds setObject:indexPath forKey:feedIdStr];
    }
    
    [appDelegate.storiesCollection setActiveFeed:feed];
    [appDelegate.storiesCollection setActiveFolder:folderName];
    appDelegate.readStories = [NSMutableArray array];
    [appDelegate.folderCountCache removeObjectForKey:folderName];
    appDelegate.storiesCollection.activeClassifiers = [NSMutableDictionary dictionary];

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

    bool isFolderCollapsed = [appDelegate isFolderCollapsed:folderName];
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
    folderTitle.section = (int)section;
    
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
    if (!visibleFeeds && section != 2 && section != 0 &&
        ![folderName isEqualToString:@"saved_stories"] &&
        ![folderName isEqualToString:@"read_stories"]) {
        return 0;
    }
    
    return 36;
}

- (void)didSelectSectionHeader:(UIButton *)button {
    [self didSelectSectionHeaderWithTag:button.tag];
}

- (void)didSelectSectionHeaderWithTag:(NSInteger)tag {
    if (self.appDelegate.inFeedDetail) {
        return;
    }
    
    // reset pointer to the cells
    self.currentRowAtIndexPath = nil;
    self.currentSection = tag;
    
    NSString *folder;
    if (tag == 0) {
        folder = @"river_global";
    } else if (tag == 1) {
        folder = @"river_blurblogs";
    } else if (tag == 2) {
        folder = @"everything";
    } else {
        folder = [NSString stringWithFormat:@"%ld", (long)tag];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.dashboardViewController.storiesModule.view endEditing:YES];
    }
    
    [appDelegate loadRiverFeedDetailView:appDelegate.feedDetailViewController withFolder:folder];
}

- (void)selectEverything:(id)sender {
    [self didSelectSectionHeaderWithTag:2];
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
            appDelegate.storiesCollection.activeFeed = [appDelegate.dictFeeds objectForKey:feedId];
            [appDelegate openTrainSiteWithFeedLoaded:NO from:cell];
        }
    } else if (state == MCSwipeTableViewCellState3) {
        // Mark read
        [self markFeedRead:feedId cutoffDays:0];
        NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
        if ([preferences boolForKey:@"show_feeds_after_being_read"]) {
            [self.stillVisibleFeeds setObject:indexPath forKey:feedId];
        }
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
    if (feedIds.count == 1 && [feedIds.firstObject isEqual:@"everything"]) {
        [self markEverythingReadWithDays:days];
        return;
    }
    
    NSTimeInterval cutoffTimestamp = [[NSDate date] timeIntervalSince1970];
    cutoffTimestamp -= (days * 60*60*24);
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_as_read",
                           self.appDelegate.url];
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

- (void)markEverythingReadWithDays:(NSInteger)days {
    NSTimeInterval cutoffTimestamp = [[NSDate date] timeIntervalSince1970];
    cutoffTimestamp -= (days * 60*60*24);
    NSArray *feedIds = [appDelegate allFeedIds];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_all_as_read",
                           self.appDelegate.url];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:[NSNumber numberWithInteger:days]
                   forKey:@"days"];
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

- (void)markVisibleStoriesRead {
    NSDictionary *feedsStories = [appDelegate markVisibleStoriesRead];
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_stories_as_read",
                           self.appDelegate.url];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:[feedsStories JSONRepresentation] forKey:@"feeds_stories"];
    [request setDelegate:self];
    [request setUserInfo:@{@"stories": feedsStories}];
    [request setDidFinishSelector:@selector(finishMarkAllAsRead:)];
    [request setDidFailSelector:@selector(requestFailedMarkStoryRead:)];
    [request startAsynchronous];
}

- (void)requestFailedMarkStoryRead:(ASIFormDataRequest *)request {
    [appDelegate markStoriesRead:[request.userInfo objectForKey:@"stories"]
                         inFeeds:[request.userInfo objectForKey:@"feeds"]
                 cutoffTimestamp:[[request.userInfo objectForKey:@"cutoffTimestamp"] integerValue]];
    [self showOfflineNotifier];
    self.isOffline = YES;
    [self.feedTitlesTable reloadData];
}

- (void)finishMarkAllAsRead:(ASIFormDataRequest *)request {
    if (request.responseStatusCode != 200) {
        [self requestFailedMarkStoryRead:request];
        return;
    }
    
    self.isOffline = NO;
    
    if ([[request.userInfo objectForKey:@"cutoffTimestamp"] integerValue]) {
        id feed;
        if ([[request.userInfo objectForKey:@"feeds"] count] == 1) {
            feed = [[request.userInfo objectForKey:@"feeds"] objectAtIndex:0];
        }
        [self refreshFeedList:feed];
    } else if ([request.userInfo objectForKey:@"feeds"]) {
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
    appDelegate.collapsedFolders = nil;
    
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
    NSDictionary *unreadCounts = self.appDelegate.dictUnreadCounts[feedId];
    NSIndexPath *stillVisible = self.stillVisibleFeeds[feedId];
    if (!stillVisible && self.appDelegate.isSavedStoriesIntelligenceMode) {
        return [self.appDelegate savedStoriesCountForFeed:feedId] > 0 || [self.appDelegate isSavedFeed:feedId];
    } else if (!stillVisible &&
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

- (void)selectPreviousIntelligence:(id)sender {
    NSInteger selectedSegmentIndex = intelligenceControl.selectedSegmentIndex;
    if (selectedSegmentIndex <= 0)
        return;
    [intelligenceControl setSelectedSegmentIndex:selectedSegmentIndex - 1];
    [self selectIntelligence];
}

- (void)selectNextIntelligence:(id)sender {
    NSInteger selectedSegmentIndex = intelligenceControl.selectedSegmentIndex;
    if (selectedSegmentIndex >= intelligenceControl.numberOfSegments - 1)
        return;
    [intelligenceControl setSelectedSegmentIndex:selectedSegmentIndex + 1];
    [self selectIntelligence];
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
    } else if (selectedSegmentIndex == 1) {
        hud.labelText = @"Unread Stories";
        [userPreferences setInteger:0 forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        direction = self.viewShowingAllFeeds ? 1 : -1;
        self.viewShowingAllFeeds = NO;
        [appDelegate setSelectedIntelligence:0];
    } else if (selectedSegmentIndex == 2) {
        hud.labelText = @"Focus Stories";
        [userPreferences setInteger:1 forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        direction = 1;
        self.viewShowingAllFeeds = NO;
        [appDelegate setSelectedIntelligence:1];
    } else {
        hud.labelText = @"Saved Stories";
        [userPreferences setInteger:2 forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        direction = 1;
        self.viewShowingAllFeeds = NO;
        [appDelegate setSelectedIntelligence:2];
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
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        FeedDetailViewController *storiesModule = self.appDelegate.dashboardViewController.storiesModule;
        
        storiesModule.storiesCollection.feedPage = 0;
        storiesModule.storiesCollection.storyCount = 0;
        storiesModule.pageFinished = NO;
        [storiesModule.storiesCollection calculateStoryLocations];
        [storiesModule reloadData];
    }
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
        if (![cell respondsToSelector:@selector(setPositiveCount:)]) return;
        [cell setPositiveCount:[[unreadCounts objectForKey:@"ps"] intValue]];
        [cell setNeutralCount:[[unreadCounts objectForKey:@"nt"] intValue]];
        [cell setNegativeCount:[[unreadCounts objectForKey:@"ng"] intValue]];
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
                           self.appDelegate.url];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIHTTPRequest  *request = [ASIHTTPRequest  requestWithURL:url];
    
    [request setDidFinishSelector:@selector(saveAndDrawFavicons:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)loadAvatars {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0ul);
    dispatch_async(queue, ^{
        for (NSString *feed_id in [appDelegate.dictSocialFeeds allKeys]) {
            NSDictionary *feed = [appDelegate.dictSocialFeeds objectForKey:feed_id];
            NSURL *imageURL = [NSURL URLWithString:[feed objectForKey:@"photo_url"]];
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
            if (!imageData) continue;
            UIImage *faviconImage = [UIImage imageWithData:imageData];
            if (!faviconImage) continue;
            faviconImage = [Utilities roundCorneredImage:faviconImage radius:6];
            
            [appDelegate saveFavicon:faviconImage feedId:feed_id];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.feedTitlesTable reloadData];
        });
    });
}



- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request {
    __block NSString *responseString = [request responseString];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0ul);
    dispatch_async(queue, ^{
        NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error;
        NSDictionary *results = [NSJSONSerialization
                                 JSONObjectWithData:responseData
                                 options:kNilOptions
                                 error:&error];
        
        for (id feed_id in results) {
//            NSMutableDictionary *feed = [[appDelegate.dictFeeds objectForKey:feed_id] mutableCopy]; 
//            [feed setValue:[results objectForKey:feed_id] forKey:@"favicon"];
//            [appDelegate.dictFeeds setValue:feed forKey:feed_id];
            
            if (![appDelegate.dictFeeds objectForKey:feed_id]) continue;
            NSString *favicon = [results objectForKey:feed_id];
            if ((NSNull *)favicon != [NSNull null] && [favicon length] > 0) {
                NSData *imageData = [NSData dataWithBase64EncodedString:favicon];
                UIImage *faviconImage = [UIImage imageWithData:imageData];
                [appDelegate saveFavicon:faviconImage feedId:feed_id];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.feedTitlesTable reloadData];
            [self loadAvatars];
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
                     self.appDelegate.url, feedId];
    } else {
        urlString = [NSString stringWithFormat:@"%@/reader/refresh_feeds",
                     self.appDelegate.url];
    }
    NSURL *urlFeedList = [NSURL URLWithString:urlString];
    
    if (!feedId) {
        [self.appDelegate cancelOfflineQueue];
    }
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:urlFeedList];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    [request setValidatesSecureCertificate:NO];
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
        NSLog(@"Showing login after refresh");
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
            [self loadFavicons];
        });
    });
}

// called when the date shown needs to be updated, optional
- (NSDate *)pullToRefreshViewLastUpdated:(PullToRefreshView *)view {
    return self.lastUpdate;
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
                                             objectForKey:@"large_photo_url"]]];
    userAvatarButton = [UIBarButtonItem barItemWithImage:[UIImage alloc]
                                                  target:self
                                                  action:@selector(showUserProfile)];
    userAvatarButton.customView.frame = CGRectMake(0, yOffset + 1, isShort ? 28 : 32, isShort ? 28 : 32);
    userAvatarButton.accessibilityLabel = @"User info";
    userAvatarButton.accessibilityHint = @"Double-tap for information about your account.";

    NSMutableURLRequest *avatarRequest = [NSMutableURLRequest requestWithURL:imageURL];
    [avatarRequest addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    [avatarRequest setTimeoutInterval:30.0];
    avatarImageView = [[UIImageView alloc] initWithFrame:userAvatarButton.customView.frame];
    CGSize avatarSize = avatarImageView.frame.size;
    typeof(self) __weak weakSelf = self;
    [avatarImageView setImageWithURLRequest:avatarRequest placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        typeof(weakSelf) __strong strongSelf = weakSelf;
        image = [Utilities imageWithImage:image convertToSize:CGSizeMake(avatarSize.width*2, avatarSize.height*2)];
        image = [Utilities roundCorneredImage:image radius:6];
        [(UIButton *)strongSelf.userAvatarButton.customView setImage:image forState:UIControlStateNormal];
    } failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nonnull response, NSError * _Nonnull error) {
        NSLog(@"Could not fetch user avatar: %@", error);
    }];
    
    
    //    self.navigationItem.leftBarButtonItem = userInfoBarButton;
    
    //    [userInfoView addSubview:userAvatarButton];
    
    userLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, yOffset, userInfoView.frame.size.width, 16)];
    userLabel.text = appDelegate.activeUsername;
    userLabel.font = userLabelFont;
    userLabel.textColor = UIColorFromRGB(0x404040);
    userLabel.backgroundColor = [UIColor clearColor];
    userLabel.accessibilityLabel = [NSString stringWithFormat:@"Logged in as %@", appDelegate.activeUsername];
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
    positiveCount.accessibilityLabel = [NSString stringWithFormat:@"%@ focused stories", positiveCount.text];
    
    CGRect yellow = CGRectMake(0, userLabel.frame.origin.y + userLabel.frame.size.height + 4, 8, 8);
    neutralCount.text = [formatter stringFromNumber:[NSNumber numberWithInt:counts.nt]];
    neutralCount.accessibilityLabel = [NSString stringWithFormat:@"%@ unread stories", neutralCount.text];
    neutralCount.frame = CGRectMake(yellow.size.width + yellow.origin.x + 2,
                                    yellow.origin.y - 3, 100, 16);
    [neutralCount sizeToFit];
    
    greenIcon.frame = CGRectMake(neutralCount.frame.origin.x + neutralCount.frame.size.width + 8,
                                 yellow.origin.y, 8, 8);
    positiveCount.frame = CGRectMake(greenIcon.frame.size.width + greenIcon.frame.origin.x + 2,
                                     greenIcon.frame.origin.y - 3, 100, 16);
    [positiveCount sizeToFit];
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