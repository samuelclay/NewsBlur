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
#import "FeedDetailViewController.h"
#import "UserProfileViewController.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "MBProgressHUD.h"
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
#import "UISearchBar+Field.h"
#import "StoriesCollection.h"
#import "PremiumManager.h"

static const CGFloat kPhoneTableViewRowHeight = 6.0f;
static const CGFloat kTableViewRowHeight = 6.0f;
static const CGFloat kBlurblogTableViewRowHeight = 7.0f;
static const CGFloat kPhoneBlurblogTableViewRowHeight = 7.0f;
static const CGFloat kFolderTitleHeight = 10.0f;
static UIFont *userLabelFont;

static NSArray<NSString *> *NewsBlurTopSectionNames;

@interface NewsBlurViewController () 

@property (nonatomic, strong) NSMutableDictionary *updatedDictSocialFeeds_;
@property (nonatomic, strong) NSMutableDictionary *updatedDictFeeds_;
@property (readwrite) BOOL inPullToRefresh_;
@property (nonatomic, strong) NSMutableDictionary<NSIndexPath *, NSNumber *> *rowHeights;

@end

@implementation NewsBlurViewController

@synthesize appDelegate;
@synthesize feedTitlesTable;
@synthesize feedViewToolbar;
@synthesize feedScoreSlider;
@synthesize homeButton;
@synthesize intelligenceControl;
@synthesize activeFeedLocations;
@synthesize stillVisibleFeeds;
@synthesize visibleFolders;
@synthesize viewShowingAllFeeds;
@synthesize lastUpdate;
@synthesize imageCache;
@synthesize currentRowAtIndexPath;
@synthesize currentSection;
@synthesize noFocusMessage;
@synthesize noFocusLabel;
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
@synthesize yellowIcon;
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

+ (void)initialize {
    // keep in sync with NewsBlurTopSections
    NewsBlurTopSectionNames = @[/* 0 */ @"river_global",
                                /* 1 */ @"river_blurblogs",
                                /* 2 */ @"infrequent",
                                /* 3 */ @"everything"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.rowHeights = [NSMutableDictionary dictionary];
    
    self.refreshControl = [UIRefreshControl new];
    self.refreshControl.tintColor = UIColorFromLightDarkRGB(0x0, 0xffffff);
    self.refreshControl.backgroundColor = UIColorFromRGB(0xE3E6E0);
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    self.feedTitlesTable.refreshControl = self.refreshControl;
    self.feedViewToolbar.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.searchBar = [[UISearchBar alloc]
                      initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.feedTitlesTable.frame), 44.)];
    self.searchBar.delegate = self;
    [self.searchBar setReturnKeyType:UIReturnKeySearch];
    self.searchBar.backgroundColor = UIColorFromRGB(0xE3E6E0);
    self.searchBar.tintColor = UIColorFromRGB(0x0);
    self.searchBar.nb_searchField.textColor = UIColorFromRGB(0x0);
    [self.searchBar setSearchBarStyle:UISearchBarStyleMinimal];
    [self.searchBar setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    self.feedTitlesTable.tableHeaderView = self.searchBar;
    
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
    self.view.backgroundColor = UIColorFromRGB(0xf4f4f4);
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
                                           withOffset:CGPointMake(0, 0)];
    [self.view insertSubview:self.notifier belowSubview:self.feedViewToolbar];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:NOTIFIER_HEIGHT]];
    self.notifier.topOffsetConstraint = [NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.feedViewToolbar attribute:NSLayoutAttributeTop multiplier:1.0 constant:0];
    [self.view addConstraint:self.notifier.topOffsetConstraint];
    
    self.feedTitlesTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.feedTitlesTable.separatorColor = [UIColor clearColor];
    self.feedTitlesTable.translatesAutoresizingMaskIntoConstraints = NO;
    self.feedTitlesTable.estimatedRowHeight = 0;
    
    userAvatarButton.customView.hidden = YES;
    userInfoBarButton.customView.hidden = YES;
    self.noFocusMessage.hidden = YES;

    [self.navigationController.interactivePopGestureRecognizer addTarget:self action:@selector(handleGesture:)];
    
    [self addKeyCommandWithInput:@"e" modifierFlags:UIKeyModifierCommand action:@selector(selectEverything:) discoverabilityTitle:@"Open All Stories"];
    [self addKeyCommandWithInput:UIKeyInputLeftArrow modifierFlags:0 action:@selector(selectPreviousIntelligence:) discoverabilityTitle:@"Switch Views"];
    [self addKeyCommandWithInput:UIKeyInputRightArrow modifierFlags:0 action:@selector(selectNextIntelligence:) discoverabilityTitle:@"Switch Views"];
    [self addKeyCommandWithInput:@"a" modifierFlags:UIKeyModifierCommand action:@selector(tapAddSite:) discoverabilityTitle:@"Add Site"];
}

- (void)viewWillAppear:(BOOL)animated {
//    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    [self resetRowHeights];
    
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
//        [self reloadFeedTitlesTable];
//        [self refreshHeaderCounts];
        [self redrawUnreadCounts];
//        [self.feedTitlesTable selectRowAtIndexPath:self.currentRowAtIndexPath
//                                          animated:NO 
//                                    scrollPosition:UITableViewScrollPositionNone];
        [self.notifier setNeedsLayout];
    }
    
    if (self.searchFeedIds) {
//        [self.feedTitlesTable setContentOffset:CGPointMake(0, 0)];
        [self.searchBar becomeFirstResponder];
    } else {
        [self.searchBar setText:@""];
//        [self.feedTitlesTable setContentOffset:CGPointMake(0, CGRectGetHeight(self.searchBar.frame))];
    }
    
    [self.searchBar setShowsCancelButton:self.searchBar.text.length > 0 animated:YES];
    
//    NSLog(@"Feed List timing 2: %f", [NSDate timeIntervalSinceReferenceDate] - start);
}

- (void)viewDidAppear:(BOOL)animated {
//    [self.feedTitlesTable selectRowAtIndexPath:self.currentRowAtIndexPath 
//                                      animated:NO 
//                                scrollPosition:UITableViewScrollPositionNone];
    
    [super viewDidAppear:animated];
    [self performSelector:@selector(fadeSelectedCell) withObject:self afterDelay:0.2];
//    self.navigationController.navigationBar.backItem.title = @"All Sites";
    [self layoutHeaderCounts:0];
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

- (void)viewWillDisappear:(BOOL)animated {
    [self.appDelegate hidePopoverAnimated:YES];
    [super viewWillDisappear:animated];
    [self.searchBar resignFirstResponder];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self.searchBar resignFirstResponder];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        [self layoutForInterfaceOrientation:orientation];
        [self.notifier setNeedsLayout];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self reloadFeedTitlesTable];
    }];
}

- (void)layoutForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//    CGSize toolbarSize = [self.feedViewToolbar sizeThatFits:self.view.frame.size];
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
//        self.feedViewToolbar.frame = CGRectMake(-10.0f,
//                                                CGRectGetHeight(self.view.frame) - toolbarSize.height,
//                                                toolbarSize.width + 20, toolbarSize.height);
//    } else {
//        self.feedViewToolbar.frame = (CGRect){CGPointMake(0.f, CGRectGetHeight(self.view.frame) - toolbarSize.height), toolbarSize};
//    }
//    self.innerView.frame = (CGRect){CGPointZero, CGSizeMake(CGRectGetWidth(self.view.frame), CGRectGetMinY(self.feedViewToolbar.frame))};
    self.notifier.offset = CGPointMake(0, 0);
    
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
        
        [self.intelligenceControl setWidth:40 forSegmentAtIndex:0];
        [self.intelligenceControl setWidth:68 forSegmentAtIndex:1];
        [self.intelligenceControl setWidth:62 forSegmentAtIndex:2];
        [self.intelligenceControl setWidth:60 forSegmentAtIndex:3];
    }
    
    [self.intelligenceControl sizeToFit];
    
//    NSInteger height = 16;
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && UIInterfaceOrientationIsLandscape(orientation)) {
//        height = 8;
//    }
//
//    CGRect intelFrame = self.intelligenceControl.frame;
//    intelFrame.origin.x = (self.feedViewToolbar.frame.size.width / 2) - (intelFrame.size.width / 2) + 20;
//    intelFrame.size.height = self.feedViewToolbar.frame.size.height - height;
//    self.intelligenceControl.frame = intelFrame;
}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

#pragma mark -
#pragma mark State Restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
}

#pragma mark -
#pragma mark Initialization

- (void)returnToApp {
    NSDate *decayDate = [[NSDate alloc] initWithTimeIntervalSinceNow:(-1 * BACKGROUND_REFRESH_SECONDS)];
    NSLog(@"Last Update: %@ - %f", self.lastUpdate, [self.lastUpdate timeIntervalSinceDate:decayDate]);
    if ([self.lastUpdate timeIntervalSinceDate:decayDate] < 0) {
        [appDelegate reloadFeedsView:YES];
    }
    
}

-(void)fetchFeedList:(BOOL)showLoader {
    NSString *urlFeedList;
    NSLog(@"Fetching feed list");
    [appDelegate cancelOfflineQueue];
    
    if (self.inPullToRefresh_) {
        urlFeedList = [NSString stringWithFormat:@"%@/reader/feeds?flat=true&update_counts=true",
                      self.appDelegate.url];
    } else {
        urlFeedList = [NSString stringWithFormat:@"%@/reader/feeds?flat=true&update_counts=false",
                        self.appDelegate.url];
    }
    
    if (appDelegate.backgroundCompletionHandler) {
        urlFeedList = [urlFeedList stringByAppendingString:@"&background_ios=true"];
    }
    
    [appDelegate.networkManager GET:urlFeedList parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishLoadingFeedList:responseObject];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        [self finishedWithError:error statusCode:httpResponse.statusCode];
    }];

    self.lastUpdate = [NSDate date];
    if (showLoader) {
//        [self.notifier hide];
    }
    [self showRefreshNotifier];
}

- (void)finishedWithError:(NSError *)error statusCode:(NSInteger)statusCode {
    [self finishRefresh];
    
    if (statusCode == 403) {
        NSLog(@"Showing login");
        return [appDelegate showLogin];
    } else if (statusCode >= 400) {
        if (statusCode == 429) {
            [self informError:@"Slow down. You're rate-limited."];
        } else if (statusCode == 503) {
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

    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    // User clicking on another link before the page loads is OK.
    [self informError:error];
    
    self.isOffline = YES;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.dashboardViewController refreshStories];
    }

    [self showOfflineNotifier];
    [self loadNotificationStory];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FinishedLoadingFeedsNotification" object:nil];
}

- (void)finishLoadingFeedList:(NSDictionary *)results {
    appDelegate.hasNoSites = NO;
    appDelegate.recentlyReadStories = [NSMutableDictionary dictionary];
    appDelegate.unreadStoryHashes = [NSMutableDictionary dictionary];
    appDelegate.unsavedStoryHashes = [NSMutableDictionary dictionary];
    
    self.isOffline = NO;

    appDelegate.activeUsername = [results objectForKey:@"user"];
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.newsblur.NewsBlur-Group"];
    [defaults setObject:[results objectForKey:@"share_ext_token"] forKey:@"share:token"];
    [defaults setObject:DEFAULT_NEWSBLUR_URL forKey:@"share:host"];
    [defaults synchronize];

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
    
    // Doing this here avoids the search bar from appearing on initial load, but doesn't help when only a few rows visible.
//    if (!self.searchFeedIds && self.feedTitlesTable.contentOffset.y == 0) {
//        self.feedTitlesTable.contentOffset = CGPointMake(0, CGRectGetHeight(self.searchBar.frame));
//    }
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    self.stillVisibleFeeds = [NSMutableDictionary dictionary];

    appDelegate.activeUsername = [results objectForKey:@"user"];
    if (appDelegate.activeUsername) {
        [userPreferences setObject:appDelegate.activeUsername forKey:@"active_username"];
        [userPreferences synchronize];
    }
    
    // Bottom toolbar
//    UIImage *addImage = [UIImage imageNamed:@"nav_icn_add.png"];
//    UIImage *settingsImage = [UIImage imageNamed:@"nav_icn_settings.png"];
//    addBarButton.enabled = YES;
    addBarButton.accessibilityLabel = @"Add site";
//    settingsBarButton.enabled = YES;
    settingsBarButton.accessibilityLabel = @"Settings";
//    NBBarButtonItem *addButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
//    [addButton setImage:[[ThemeManager themeManager] themedImage:addImage] forState:UIControlStateNormal];
//    [addButton sizeToFit];
//    [addButton addTarget:self action:@selector(tapAddSite:)
//        forControlEvents:UIControlEventTouchUpInside];
//    addButton.accessibilityLabel = @"Add feed";
//    [addBarButton setCustomView:addButton];

//    NBBarButtonItem *settingsButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
//    settingsButton.onRightSide = YES;
//    [settingsButton setImage:[[ThemeManager themeManager] themedImage:settingsImage] forState:UIControlStateNormal];
//    [settingsButton sizeToFit];
//    [settingsButton addTarget:self action:@selector(showSettingsPopover:)
//             forControlEvents:UIControlEventTouchUpInside];
//    settingsButton.accessibilityLabel = @"Settings";
//    [settingsBarButton setCustomView:settingsButton];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        UIImage *activityImage = [UIImage imageNamed:@"nav_icn_activity_hover.png"];
        NBBarButtonItem *activityButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
        activityButton.accessibilityLabel = @"Activities";
        [activityButton setImage:activityImage forState:UIControlStateNormal];
//        [activityButton sizeToFit];
//        [activityButton setContentEdgeInsets:UIEdgeInsetsMake(0, -6, -0, -6)];
//        [activityButton setFrame:CGRectInset(activityButton.frame, 0, -6)];
        [activityButton setImageEdgeInsets:UIEdgeInsetsMake(4, 4, 4, 4)];
        [activityButton addTarget:self
                           action:@selector(showInteractionsPopover:)
                 forControlEvents:UIControlEventTouchUpInside];
        activitiesButton = [[UIBarButtonItem alloc]
                            initWithCustomView:activityButton];
        activitiesButton.width = 32;
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
    
    appDelegate.isPremium = [[appDelegate.dictUserProfile objectForKey:@"is_premium"] integerValue] == 1;
    id premiumExpire = [appDelegate.dictUserProfile objectForKey:@"premium_expire"];
    if (premiumExpire && ![premiumExpire isKindOfClass:[NSNull class]] && premiumExpire != 0) {
        appDelegate.premiumExpire = [premiumExpire integerValue];
    }
    
    if (!appDelegate.premiumManager) {
        appDelegate.premiumManager = [PremiumManager new];
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

    // Add global shared stories, etc. to top
    [NewsBlurTopSectionNames enumerateObjectsUsingBlock:^(NSString * _Nonnull sectionName, NSUInteger sectionIndex, BOOL * _Nonnull stop) {
        [appDelegate.dictFoldersArray removeObject:sectionName];
        [appDelegate.dictFoldersArray insertObject:sectionName atIndex:sectionIndex];
    }];

    // Add Read Stories folder to bottom
    [appDelegate.dictFoldersArray removeObject:@"read_stories"];
    [appDelegate.dictFoldersArray insertObject:@"read_stories" atIndex:appDelegate.dictFoldersArray.count];

    // Add Saved Stories folder to bottom
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
    [self reloadFeedTitlesTable];
    [self refreshHeaderCounts];

    // assign categories for FTUX    
    if (![[results objectForKey:@"categories"] isKindOfClass:[NSNull class]]){
        appDelegate.categories = [[results objectForKey:@"categories"] objectForKey:@"categories"];
        appDelegate.categoryFeeds = [[results objectForKey:@"categories"] objectForKey:@"feeds"];
    }
    
    if (!self.isOffline) {
        // start up the first time user experience
        if ([[results objectForKey:@"social_feeds"] count] == 0 &&
            [[[results objectForKey:@"feeds"] allKeys] count] == 0) {
            [appDelegate showFirstTimeUser];
            return;
        }
        
        [self showSyncingNotifier];
        [self.appDelegate flushQueuedReadStories:YES withCallback:^{
            [self refreshFeedList];
        }];
    }
    
    self.intelligenceControl.hidden = NO;
    
    [self showExplainerOnEmptyFeedlist];
    [self layoutHeaderCounts:0];
    [self refreshHeaderCounts];
    [appDelegate checkForFeedNotifications];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && finished) {
        [appDelegate.dashboardViewController refreshStories];
        [self cacheFeedRowLocations];
    }
    [self loadNotificationStory];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"FinishedLoadingFeedsNotification" object:nil];
}

- (void)cacheFeedRowLocations {
    indexPathsForFeedIds = [NSMutableDictionary dictionary];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0ul);

    dispatch_async(queue, ^{
        for (NSString *folderName in appDelegate.dictFoldersArray) {
            NSInteger section = [appDelegate.dictFoldersArray indexOfObject:folderName];
            NSArray *folder = [appDelegate.dictFolders objectForKey:folderName];
            for (NSInteger row=0; row < folder.count; row++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                [indexPathsForFeedIds setObject:indexPath forKey:[folder objectAtIndex:row]];
            }
        }
    });
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
                       options:0 error:nil];
            break;
        }
        
        [cursor close];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_self finishLoadingFeedListWithDict:results finished:failed];
            [_self fetchFeedList:NO];
        });
    }];
}

- (void)loadNotificationStory {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (appDelegate.tryFeedFeedId && !appDelegate.isTryFeedView) {
            [appDelegate loadFeed:appDelegate.tryFeedFeedId withStory:appDelegate.tryFeedStoryId animated:NO];
        }
    });
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
    [self.appDelegate showPopoverWithViewController:self.appDelegate.addSiteNavigationController contentSize:CGSizeMake(320, 96) barButtonItem:self.addBarButton];
//        [self.appDelegate showPopoverWithViewController:self.appDelegate.addSiteNavigationController contentSize:CGSizeMake(320, 96) sourceView:self.addBarButton sourceRect:CGRectMake(35.0, 0.0, 0.0, 0.0) permittedArrowDirections:UIPopoverArrowDirectionDown];
//    } else {
//        [self.appDelegate showPopoverWithViewController:self.appDelegate.addSiteNavigationController contentSize:CGSizeMake(320, 96) barButtonItem:self.addBarButton];
//    }
    
    [self.appDelegate.addSiteViewController reload];
}

- (IBAction)showSettingsPopover:(id)sender {
    [self.appDelegate.feedsMenuViewController rebuildOptions];

    [self.appDelegate.feedsMenuViewController view];
    NSInteger menuCount = [self.appDelegate.feedsMenuViewController.menuOptions count];
    
    [self.appDelegate showPopoverWithViewController:self.appDelegate.feedsMenuViewController contentSize:CGSizeMake(250, 38 * (menuCount + 2)) barButtonItem:self.settingsBarButton];
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
        
        [self.appDelegate showMarkReadMenuWithFeedIds:@[feedIdStr] collectionTitle:@"site" sourceView:self.feedTitlesTable sourceRect:cell.frame completionHandler:^(BOOL marked){
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
    [self resetupGestures];
}

- (void)resizePreviewSize {
    [self reloadFeedTitlesTable];
    
    [appDelegate.feedDetailViewController reloadData];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.dashboardViewController.storiesModule reloadData];
    }
}

- (void)resizeFontSize {
    appDelegate.fontDescriptorTitleSize = nil;
    [self reloadFeedTitlesTable];
    
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
    self.refreshControl.tintColor = UIColorFromLightDarkRGB(0x0, 0xffffff);
    self.refreshControl.backgroundColor = UIColorFromRGB(0xE3E6E0);
    self.view.backgroundColor = UIColorFromRGB(0xf4f4f4);
    
    NBBarButtonItem *barButton = self.addBarButton.customView;
    [barButton setImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"nav_icn_add.png"]] forState:UIControlStateNormal];
    
    barButton = self.settingsBarButton.customView;
    [barButton setImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"nav_icn_settings.png"]] forState:UIControlStateNormal];
    
    [self layoutHeaderCounts:0];
    [self refreshHeaderCounts];
    
    self.searchBar.backgroundColor = UIColorFromRGB(0xE3E6E0);
    self.searchBar.tintColor = UIColorFromRGB(0xffffff);
    self.searchBar.nb_searchField.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    self.searchBar.nb_searchField.tintColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    
    if ([ThemeManager themeManager].isDarkTheme) {
        self.searchBar.keyboardAppearance = UIKeyboardAppearanceDark;
    } else {
        self.searchBar.keyboardAppearance = UIKeyboardAppearanceDefault;
    }
    
    self.feedTitlesTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    [self reloadFeedTitlesTable];
    
    [self resetupGestures];
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
    } else if ([identifier isEqual:@"story_list_preview_images_size"]) {
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
            [appDelegate.database inDatabase:^(FMDatabase *db) {
                [db executeUpdate:@"VACUUM"];
                [appDelegate setupDatabase:db force:YES];
                [appDelegate deleteAllCachedImages];
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [[NSUserDefaults standardUserDefaults] setObject:@"Cleared all stories and images!"
                                                              forKey:specifier.key];
                });
            }];
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
    BOOL isOmitted = false;
    NSString *CellIdentifier;
    
    if (self.searchFeedIds && !isSaved) {
        isOmitted = ![self.searchFeedIds containsObject:feedIdStr];
    } else {
        isOmitted = [appDelegate isFolderCollapsed:folderName] || ![self isFeedVisible:feedIdStr];
    }
    
    if (isOmitted) {
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
    BOOL newCell = cell == nil;
    if (newCell) {
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
    
    if (newCell) {
        [cell setupGestures];
    }
    
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
    self.currentSection = 0;
    
    NSString *folderName = appDelegate.dictFoldersArray[indexPath.section];
    id feedId = [[appDelegate.dictFolders objectForKey:folderName] objectAtIndex:indexPath.row];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    
    // If all feeds are already showing, no need to remember this one.
//    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    if (!self.viewShowingAllFeeds) {
//        [preferences boolForKey:@"show_feeds_after_being_read"]) {
        [self.stillVisibleFeeds setObject:indexPath forKey:feedIdStr];
    }
    
    [appDelegate loadFolder:folderName feedID:feedIdStr];
}

- (CGFloat)tableView:(UITableView *)tableView
           heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSNumber *cachedHeight = self.rowHeights[indexPath];

    if (cachedHeight != nil) {
//        NSLog(@"Got cached height: %@", cachedHeight);  // log

        return cachedHeight.floatValue;
    }

    CGFloat height = [self calculateHeightForRowAtIndexPath:indexPath];
    
    self.rowHeights[indexPath] = @(height);
    
//    NSLog(@"Calculated height: %@", @(height));  // log
    
    return height;
}

- (CGFloat)calculateHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (appDelegate.hasNoSites) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            return kBlurblogTableViewRowHeight;            
        } else {
            return kPhoneBlurblogTableViewRowHeight;
        }
    }
    
    NSString *folderName = appDelegate.dictFoldersArray[indexPath.section];
    id feedId = [[appDelegate.dictFolders objectForKey:folderName] objectAtIndex:indexPath.row];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
    
    if (self.searchFeedIds && ![appDelegate isSavedFeed:feedIdStr]) {
        if (![self.searchFeedIds containsObject:feedIdStr]) {
            return 0;
        }
    } else {
        BOOL isFolderCollapsed = [appDelegate isFolderCollapsed:folderName];
        if (isFolderCollapsed) {
            return 0;
        }
        
        if (![self isFeedVisible:feedId]) {
            return 0;
        }
    }
    
    NSInteger height;
    
    if ([folderName isEqualToString:@"river_blurblogs"] ||
        [folderName isEqualToString:@"river_global"]) { // blurblogs
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            height = kBlurblogTableViewRowHeight;
        } else {
            height = kPhoneBlurblogTableViewRowHeight;
        }
    } else {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            height = kTableViewRowHeight;
        } else {
            height = kPhoneTableViewRowHeight;
        }
    }
    
    UIFontDescriptor *fontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
    UIFont *font = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
    return height + font.pointSize*2;
}

- (void)resetRowHeights {
    [self.rowHeights removeAllObjects];
}

- (void)reloadFeedTitlesTable {
    [self resetRowHeights];
    [self.feedTitlesTable reloadData];
}

- (UIFontDescriptor *)fontDescriptorUsingPreferredSize:(NSString *)textStyle {
    UIFontDescriptor *fontDescriptor = appDelegate.fontDescriptorTitleSize;
    if (fontDescriptor) return fontDescriptor;
    
    fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:textStyle];
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if (![userPreferences boolForKey:@"use_system_font_size"]) {
        if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xs"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:10.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"small"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:11.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"medium"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:12.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"large"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:15.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xl"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:17.0f];
        }
    }
    return fontDescriptor;
}

- (UIView *)tableView:(UITableView *)tableView 
            viewForHeaderInSection:(NSInteger)section {
    UIFontDescriptor *fontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
    UIFont *font = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
    NSInteger height = kFolderTitleHeight;
    
    CGRect rect = CGRectMake(0.0, 0.0, tableView.frame.size.width, height + font.pointSize*2);
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
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    if ([appDelegate.dictFoldersArray count] == 0) return 0;
    
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:section];
    
    BOOL visibleFeeds = [[self.visibleFolders objectForKey:folderName] boolValue];
    if (!visibleFeeds && section != NewsBlurTopSectionInfrequentSiteStories && section != NewsBlurTopSectionAllStories && section != NewsBlurTopSectionGlobalSharedStories &&
        ![folderName isEqualToString:@"saved_stories"] &&
        ![folderName isEqualToString:@"read_stories"]) {
        return 0;
    }
    
    if (section == NewsBlurTopSectionInfrequentSiteStories &&
        ![prefs boolForKey:@"show_infrequent_site_stories"]) {
        return 0;
    }

    if (section == NewsBlurTopSectionGlobalSharedStories &&
        ![prefs boolForKey:@"show_global_shared_stories"]) {
        return 0;
    }

    UIFontDescriptor *fontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
    UIFont *font = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
    NSInteger height = kFolderTitleHeight;
    
    return height + font.pointSize*2;
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
    if (tag >= 0 && tag < [NewsBlurTopSectionNames count]) {
        folder = NewsBlurTopSectionNames[tag];
    } else {
        folder = [NSString stringWithFormat:@"%ld", (long)tag];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.dashboardViewController.storiesModule.view endEditing:YES];
    }
    
    [appDelegate loadRiverFeedDetailView:appDelegate.feedDetailViewController withFolder:folder];
}

- (void)selectEverything:(id)sender {
    [self didSelectSectionHeaderWithTag:NewsBlurTopSectionAllStories];
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
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
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
        } else if ([[preferences stringForKey:@"feed_swipe_left"] isEqualToString:@"notifications"]) {
            [appDelegate openNotificationsWithFeed:feedId sender:cell];
        } else {
            // Train
            appDelegate.storiesCollection.activeFeed = [appDelegate.dictFeeds objectForKey:feedId];
            [appDelegate openTrainSiteWithFeedLoaded:NO from:cell];
        }
    } else if (state == MCSwipeTableViewCellState3) {
        // Mark read
        [self markFeedRead:feedId cutoffDays:0];
        if ([preferences boolForKey:@"show_feeds_after_being_read"]) {
            [self.stillVisibleFeeds setObject:indexPath forKey:feedId];
        }
        [self.feedTitlesTable beginUpdates];
        [self.feedTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                    withRowAnimation:UITableViewRowAnimationFade];
        [self.feedTitlesTable endUpdates];
        
        [self refreshHeaderCounts];
    }
}

#pragma mark -
#pragma mark Mark Feeds as read

- (void)markFeedRead:(NSString *)feedId cutoffDays:(NSInteger)days {
    [self markFeedsRead:@[feedId] cutoffDays:days];
}

- (void)markFeedsRead:(NSArray *)feedIds cutoffDays:(NSInteger)days {
    if (feedIds.count == 1 && ([feedIds.firstObject isEqual:@"everything"] || [feedIds.firstObject isEqual:@"infrequent"])) {
        [self markEverythingReadWithDays:days infrequent:[feedIds.firstObject isEqual:@"infrequent"]];
        return;
    }
    
    NSTimeInterval cutoffTimestamp = [[NSDate date] timeIntervalSince1970];
    cutoffTimestamp -= (days * 60*60*24);
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_as_read",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:feedIds forKey:@"feed_id"];
    if (days) {
        [params setObject:[NSNumber numberWithInteger:cutoffTimestamp]
                       forKey:@"cutoff_timestamp"];
    }
    
    [appDelegate.networkManager POST:urlString parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishMarkAllAsRead:params];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailedMarkStoryRead:error withParams:params];
    }];
    
    if (!days) {
        for (NSString *feedId in feedIds) {
            [appDelegate markFeedAllRead:feedId];
        }
    } else {
        //        [self showRefreshNotifier];
    }
    
    [self resetRowHeights];
}

- (void)markEverythingReadWithDays:(NSInteger)days {
    [self markEverythingReadWithDays:days infrequent:NO];
}

- (void)markEverythingReadWithDays:(NSInteger)days infrequent:(BOOL)infrequent {
    NSArray *feedIds = [appDelegate allFeedIds];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_all_as_read",
                           self.appDelegate.url];

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[NSNumber numberWithInteger:days]
               forKey:@"days"];

    if (infrequent || [appDelegate.storiesCollection.activeFolder isEqualToString:@"infrequent"]) {
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        NSString *infrequent = [NSString stringWithFormat:@"%ld", (long)[prefs integerForKey:@"infrequent_stories_per_month"]];
        [params setObject:infrequent forKey:@"infrequent"];
    }

    [appDelegate.networkManager POST:urlString parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishMarkAllAsRead:params];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailedMarkStoryRead:error withParams:params];
    }];
    
    if (!days) {
        for (NSString *feedId in feedIds) {
            [appDelegate markFeedAllRead:feedId];
        }
        [self reloadFeedTitlesTable];
    } else {
        [self resetRowHeights];
        //        [self showRefreshNotifier];
    }
}

- (void)markVisibleStoriesRead {
    NSDictionary *feedsStories = [appDelegate markVisibleStoriesRead];
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_stories_as_read",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[feedsStories JSONRepresentation] forKey:@"feeds_stories"];
    
    [appDelegate.networkManager POST:urlString parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishMarkAllAsRead:params];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailedMarkStoryRead:error withParams:params];
    }];
}

- (void)requestFailedMarkStoryRead:(NSError *)error withParams:(NSDictionary *)params {
    [appDelegate markStoriesRead:[params objectForKey:@"stories"]
                         inFeeds:[params objectForKey:@"feed_id"]
                 cutoffTimestamp:[[params objectForKey:@"cutoff_timestamp"] integerValue]];
    [self showOfflineNotifier];
    self.isOffline = YES;
    [self reloadFeedTitlesTable];
}

- (void)finishMarkAllAsRead:(NSDictionary *)params {
    // This seems fishy post-ASI rewrite. This needs to know about a cutoff timestamp which it is never given.
    self.isOffline = NO;
    
    if ([[params objectForKey:@"cutoff_timestamp"] integerValue]) {
        id feed;
        if ([[params objectForKey:@"feed_id"] count] == 1) {
            feed = [[params objectForKey:@"feed_id"] objectAtIndex:0];
        }
        [self refreshFeedList:feed];
    } else if ([params objectForKey:@"feed_id"]) {
        [appDelegate markFeedReadInCache:[params objectForKey:@"feed_id"]];
    }
}

#pragma mark - Table Actions

- (void)didCollapseFolder:(UIButton *)button {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];

    NSString *folderName = appDelegate.dictFoldersArray[button.tag];
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
    
    [self resetRowHeights];
    [self.feedTitlesTable beginUpdates];
    [self.feedTitlesTable reloadSections:[NSIndexSet indexSetWithIndex:button.tag]
                        withRowAnimation:UITableViewRowAnimationFade];
    [self.feedTitlesTable endUpdates];
    
//    // Scroll to section header if collapse causes it to scroll far off screen
//    NSArray *indexPathsVisibleCells = [self.feedTitlesTable indexPathsForVisibleRows];
//    BOOL firstFeedInFolderVisible = NO;
//    for (NSIndexPath *indexPath in indexPathsVisibleCells) {
//        if (indexPath.row == 0 && indexPath.section == button.tag) {
//            firstFeedInFolderVisible = YES;
//        }
//    }
//    if (!firstFeedInFolderVisible) {
//        CGRect headerRect = [self.feedTitlesTable rectForHeaderInSection:button.tag];
//        CGPoint headerPoint = CGPointMake(headerRect.origin.x, headerRect.origin.y);
////        [self.feedTitlesTable setContentOffset:headerPoint animated:YES];
//    }
    
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
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
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
    [self reloadFeedTitlesTable];

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
    
    if (appDelegate.isSavedStoriesIntelligenceMode) {
        self.noFocusLabel.text = @"You have no saved stories.";
    } else {
        self.noFocusLabel.text = @"You have no unread stories in Focus mode.";
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
        [self reloadFeedTitlesTable];
    }
}

- (void)resetupGestures {
    while ([self.feedTitlesTable dequeueReusableCellWithIdentifier:@"FeedCellIdentifier"]) {}
    [self reloadFeedTitlesTable];
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

    [appDelegate.networkManager GET:urlString parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self saveAndDrawFavicons:responseObject];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
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
            [self reloadFeedTitlesTable];
        });
    });
}



- (void)saveAndDrawFavicons:(NSDictionary *)results {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0ul);
    dispatch_async(queue, ^{
        for (id feed_id in results) {
//            NSMutableDictionary *feed = [[appDelegate.dictFeeds objectForKey:feed_id] mutableCopy]; 
//            [feed setValue:[results objectForKey:feed_id] forKey:@"favicon"];
//            [appDelegate.dictFeeds setValue:feed forKey:feed_id];
            
            if (![appDelegate.dictFeeds objectForKey:feed_id]) continue;
            NSString *favicon = [results objectForKey:feed_id];
            if ((NSNull *)favicon != [NSNull null] && [favicon length] > 0) {
                NSData *imageData = [[NSData alloc] initWithBase64EncodedString:favicon options:NSDataBase64DecodingIgnoreUnknownCharacters];
//                NSData *imageData = [NSData dataWithBase64EncodedString:favicon];
                UIImage *faviconImage = [UIImage imageWithData:imageData];
                [appDelegate saveFavicon:faviconImage feedId:feed_id];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadFeedTitlesTable];
            [self loadAvatars];
        });
    });
}

- (void)requestFailed:(NSError *)error {
    NSLog(@"Error: %@", error);
    [appDelegate informError:error];
}

#pragma mark -
#pragma mark Search

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    [self updateTheme];
    
    return YES;
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [self.searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    if ([self.searchBar.text length]) {
        [self.searchBar setShowsCancelButton:YES animated:YES];
    } else {
        [self.searchBar setShowsCancelButton:NO animated:YES];
    }
    [self.searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [self.searchBar setText:@""];
    [self.searchBar resignFirstResponder];
    self.searchFeedIds = nil;
    [self reloadFeedTitlesTable];
}

- (void)searchBarSearchButtonClicked:(UISearchBar*) theSearchBar {
    [self.searchBar resignFirstResponder];
}

- (BOOL)disablesAutomaticKeyboardDismissal {
    return NO;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length) {
        NSMutableArray *array = [NSMutableArray array];
        
        for (NSString *folderName in appDelegate.dictFoldersArray) {
            NSArray *folder = [appDelegate.dictFolders objectForKey:folderName];
            
            for (id feedId in folder) {
                NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
                NSDictionary *feed = [appDelegate getFeed:feedIdStr];
                NSString *title = [feed objectForKey:@"feed_title"];
                
                if ([title localizedStandardContainsString:searchText]) {
                    [array addObject:feedIdStr];
                }
            }
        }
        
        NSLog(@"search: '%@' matches %@ feeds", searchText, @(array.count));  // log
        
        if (array.count) {
            self.searchFeedIds = array;
            [self reloadFeedTitlesTable];
        }
    } else {
        self.searchFeedIds = nil;
        [self reloadFeedTitlesTable];
    }
}

#pragma mark -
#pragma mark PullToRefresh

- (void)refresh:(UIRefreshControl *)refreshControl {
    self.inPullToRefresh_ = YES;
    [appDelegate reloadFeedsView:NO];
    [appDelegate donateRefresh];
}

- (void)finishRefresh {
    self.inPullToRefresh_ = NO;
    [self.refreshControl endRefreshing];
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
    
    if (!feedId) {
        [self.appDelegate cancelOfflineQueue];
    }
    
    [appDelegate.networkManager GET:urlString parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishRefreshingFeedList:responseObject feedId:feedId];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;

        [self finishRefresh];

        if ([httpResponse statusCode] == 403) {
            NSLog(@"Showing login after refresh");
            return [appDelegate showLogin];
        } else if ([httpResponse statusCode] == 503) {
            return [self informError:@"In maintenance mode"];
        } else if ([httpResponse statusCode] >= 500) {
            return [self informError:@"The server barfed!"];
        }

        [self requestFailed:error];
    }];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!feedId) {
            [self showCountingNotifier];
        }
    });
    
}

- (void)finishRefreshingFeedList:(NSDictionary *)results feedId:(NSString *)feedId {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
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
            [self reloadFeedTitlesTable];
            [self refreshHeaderCounts];
            if (!feedId) {
                [self.appDelegate startOfflineQueue];
            }
            [self loadFavicons];
//            if (!self.searchFeedIds && self.feedTitlesTable.contentOffset.y == 0) {
//                [UIView animateWithDuration:0.2 animations:^{
//                    self.feedTitlesTable.contentOffset = CGPointMake(0, CGRectGetHeight(self.searchBar.frame));
//                }];
//
//            }
        });
    });
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
    userAvatarButton.customView.frame = CGRectMake(0, yOffset + 1, 32, 32);
    userAvatarButton.width = 32;
    userAvatarButton.accessibilityLabel = @"User info";
    userAvatarButton.accessibilityHint = @"Double-tap for information about your account.";

    NSMutableURLRequest *avatarRequest = [NSMutableURLRequest requestWithURL:imageURL];
    [avatarRequest addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    [avatarRequest setTimeoutInterval:30.0];
    avatarImageView = [[UIImageView alloc] initWithFrame:userAvatarButton.customView.frame];
    typeof(self) __weak weakSelf = self;
    [avatarImageView setImageWithURLRequest:avatarRequest placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        typeof(weakSelf) __strong strongSelf = weakSelf;
        image = [Utilities roundCorneredImage:image radius:6 convertToSize:CGSizeMake(32, 32)];
        [(UIButton *)strongSelf.userAvatarButton.customView setImage:image forState:UIControlStateNormal];
        
    } failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nonnull response, NSError * _Nonnull error) {
        NSLog(@"Could not fetch user avatar: %@", error);
    }];
    
    
    //    self.navigationItem.leftBarButtonItem = userInfoBarButton;
    
    //    [userInfoView addSubview:userAvatarButton];
    
    userLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, yOffset, userInfoView.frame.size.width, 16)];
    userLabel.text = appDelegate.activeUsername;
    userLabel.font = userLabelFont;
    userLabel.textColor = UIColorFromRGB(0x404040);
    userLabel.backgroundColor = [UIColor clearColor];
    userLabel.accessibilityLabel = [NSString stringWithFormat:@"Logged in as %@", appDelegate.activeUsername];
    [userLabel sizeToFit];
    [userInfoView addSubview:userLabel];
    
    [appDelegate.folderCountCache removeObjectForKey:@"everything"];
    yellowIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"g_icn_unread"]];
    [userInfoView addSubview:yellowIcon];
    
    neutralCount = [[UILabel alloc] init];
    neutralCount.font = [UIFont fontWithName:@"Helvetica" size:11];
    neutralCount.textColor = UIColorFromRGB(0x707070);
    neutralCount.backgroundColor = [UIColor clearColor];
    [userInfoView addSubview:neutralCount];
    
    greenIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"g_icn_focus"]];
    [userInfoView addSubview:greenIcon];
    
    positiveCount = [[UILabel alloc] init];
    positiveCount.font = [UIFont fontWithName:@"Helvetica" size:11];
    positiveCount.textColor = UIColorFromRGB(0x707070);
    positiveCount.backgroundColor = [UIColor clearColor];
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
    
    neutralCount.text = [formatter stringFromNumber:[NSNumber numberWithInt:counts.nt]];
    neutralCount.accessibilityLabel = [NSString stringWithFormat:@"%@ unread stories", neutralCount.text];

    yellowIcon.frame = CGRectMake(CGRectGetMinX(userLabel.frame), CGRectGetMaxY(userLabel.frame) + 4, 8, 8);

    neutralCount.frame = CGRectMake(CGRectGetMaxX(yellowIcon.frame) + 2,
                                    CGRectGetMinY(yellowIcon.frame) - 2, 100, 16);
    [neutralCount sizeToFit];
    
    greenIcon.frame = CGRectMake(CGRectGetMaxX(neutralCount.frame) + 8,
                                 CGRectGetMinY(yellowIcon.frame), 8, 8);
    positiveCount.frame = CGRectMake(CGRectGetMaxX(greenIcon.frame) + 2,
                                     CGRectGetMinY(greenIcon.frame) - 2, 100, 16);
    [positiveCount sizeToFit];
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *appUnreadBadge = [prefs stringForKey:@"app_unread_badge"];
    if ([appUnreadBadge isEqualToString:@"unread"]) {
        [appDelegate registerForBadgeNotifications];
        [UIApplication sharedApplication].applicationIconBadgeNumber = counts.ps + counts.nt;
    } else if ([appUnreadBadge isEqualToString:@"focus"]) {
        [appDelegate registerForBadgeNotifications];
        [UIApplication sharedApplication].applicationIconBadgeNumber = counts.ps;
    } else {
        [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    }
}

- (void)redrawFeedCounts:(id)feedId {
    NSIndexPath *indexPath = [indexPathsForFeedIds objectForKey:feedId];
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    BOOL isFolderCollapsed = [appDelegate isFolderCollapsed:folderName];

    if (indexPath) {
        [self resetRowHeights];
        [self.feedTitlesTable beginUpdates];
        if (isFolderCollapsed) {
            [appDelegate.folderCountCache removeObjectForKey:folderName];
            NSIndexSet *indexSet = [[NSIndexSet alloc] initWithIndex:indexPath.section];
            [self.feedTitlesTable reloadSections:indexSet withRowAnimation:UITableViewRowAnimationNone];
        } else {
            [self.feedTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                        withRowAnimation:UITableViewRowAnimationNone];
        }
        [self.feedTitlesTable endUpdates];
    }
    
    [self refreshHeaderCounts];
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
    [self finishRefresh];
}

- (void)showSyncingNotifier {
    self.notifier.style = NBSyncingStyle;
    self.notifier.title = @"Syncing stories...";
    [self.notifier setProgress:0];
    [self.notifier show];
    [self finishRefresh];
}

- (void)showDoneNotifier {
    self.notifier.style = NBDoneStyle;
    self.notifier.title = @"All done";
    [self.notifier setProgress:0];
    [self.notifier show];
    [self finishRefresh];
}

- (void)showSyncingNotifier:(float)progress hoursBack:(NSInteger)hours {
//    [self.notifier hide];
    self.notifier.style = NBSyncingProgressStyle;
    if (hours < 2) {
        self.notifier.title = @"Storing past hour";
    } else if (hours < 24) {
        self.notifier.title = [NSString stringWithFormat:@"Storing past %ld hours", (long)hours];
    } else if (hours < 48) {
        self.notifier.title = @"Storing yesterday";
    } else {
        self.notifier.title = [NSString stringWithFormat:@"Storing past %d days", (int)round(hours / 24.f)];
    }
    [self.notifier setProgress:progress];
    [self.notifier show];
}

- (void)showCachingNotifier:(float)progress hoursBack:(NSInteger)hours {
    //    [self.notifier hide];
    self.notifier.style = NBSyncingProgressStyle;
    if (hours < 2) {
        self.notifier.title = @"Images from last hour";
    } else if (hours < 24) {
        self.notifier.title = [NSString stringWithFormat:@"Images from %ld hours ago", (long)hours];
    } else if (hours < 48) {
        self.notifier.title = @"Images from yesterday";
    } else {
        self.notifier.title = [NSString stringWithFormat:@"Images from %d days ago", (int)round(hours / 24.f)];
    }
    [self.notifier setProgress:progress];
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
