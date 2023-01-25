//
//  FeedsObjCViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import "FeedsObjCViewController.h"
#import "NewsBlurAppDelegate.h"
#import "DashboardViewController.h"
#import "InteractionsModule.h"
#import "ActivityModule.h"
#import "FeedTableCell.h"
#import "DashboardViewController.h"
#import "UserProfileViewController.h"
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
#import "MenuViewController.h"
#import "NewsBlur-Swift.h"

static const CGFloat kPhoneTableViewRowHeight = 8.0f;
static const CGFloat kTableViewRowHeight = 8.0f;
static const CGFloat kBlurblogTableViewRowHeight = 9.0f;
static const CGFloat kPhoneBlurblogTableViewRowHeight = 9.0f;
static const CGFloat kFolderTitleHeight = 12.0f;
static UIFont *userLabelFont;

static NSArray<NSString *> *NewsBlurTopSectionNames;

@interface FeedsObjCViewController ()

@property (nonatomic, strong) NSMutableDictionary *updatedDictSocialFeeds_;
@property (nonatomic, strong) NSMutableDictionary *updatedDictFeeds_;
@property (readwrite) BOOL inPullToRefresh_;
@property (nonatomic) NSDate *leftAppDate;
@property (nonatomic, strong) NSMutableDictionary<NSIndexPath *, NSNumber *> *rowHeights;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, FolderTitleView *> *folderTitleViews;
@property (nonatomic, strong) NSIndexPath *lastRowAtIndexPath;
@property (nonatomic) NSInteger lastSection;

@end

@implementation FeedsObjCViewController

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
    // keep in sync with NewsBlurTopSection
    NewsBlurTopSectionNames = @[/* 0 */ @"infrequent",
                                /* 1 */ @"everything"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    self.rowHeights = [NSMutableDictionary dictionary];
    self.folderTitleViews = [NSMutableDictionary dictionary];
    
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
    
    userLabelFont = [UIFont fontWithName:@"WhitneySSm-Medium" size:15.0];
    
    imageCache = [[NSCache alloc] init];
    [imageCache setDelegate:self];
    
    [[NSNotificationCenter defaultCenter] 
     addObserver:self
     selector:@selector(returnToApp)
     name:UIApplicationWillEnterForegroundNotification
     object:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(leavingApp)
     name:UIApplicationWillResignActiveNotification
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
    UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
    [self layoutForInterfaceOrientation:orientation];
    
    UILongPressGestureRecognizer *longpress = [[UILongPressGestureRecognizer alloc]
                                               initWithTarget:self action:@selector(handleLongPress:)];
    longpress.minimumPressDuration = 1.0;
    longpress.delegate = self;
    [self.feedTitlesTable addGestureRecognizer:longpress];
    
    [[ThemeManager themeManager] addThemeGestureRecognizerToView:self.feedTitlesTable];
    
    [self updateTheme];
    
    self.notifier = [[NBNotifier alloc] initWithTitle:@"Fetching stories..."
                                           withOffset:CGPointMake(0, 0)];
    [self.view insertSubview:self.notifier belowSubview:self.feedViewToolbar];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.innerView attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.innerView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:NOTIFIER_HEIGHT]];
    self.notifier.topOffsetConstraint = [NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.feedViewToolbar attribute:NSLayoutAttributeTop multiplier:1.0 constant:0];
    [self.view addConstraint:self.notifier.topOffsetConstraint];
    
    self.feedTitlesTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.feedTitlesTable.separatorColor = [UIColor clearColor];
    self.feedTitlesTable.translatesAutoresizingMaskIntoConstraints = NO;
    self.feedTitlesTable.estimatedRowHeight = 0;
    
    if (@available(iOS 15.0, *)) {
        self.feedTitlesTable.sectionHeaderTopPadding = 0;
    }
    
    self.currentRowAtIndexPath = nil;
    self.currentSection = NewsBlurTopSectionAllStories;
    self.lastRowAtIndexPath = nil;
    self.lastSection = NewsBlurTopSectionAllStories;
    
    userAvatarButton.hidden = YES;
    self.noFocusMessage.hidden = YES;

//    [self.navigationController.interactivePopGestureRecognizer addTarget:self action:@selector(handleGesture:)];
    
    [self addKeyCommandWithInput:UIKeyInputDownArrow modifierFlags:UIKeyModifierAlternate action:@selector(selectNextFeed:) discoverabilityTitle:@"Next Site" wantPriority:YES];
    [self addKeyCommandWithInput:UIKeyInputUpArrow modifierFlags:UIKeyModifierAlternate action:@selector(selectPreviousFeed:) discoverabilityTitle:@"Previous Site" wantPriority:YES];
    [self addKeyCommandWithInput:UIKeyInputDownArrow modifierFlags:UIKeyModifierShift action:@selector(selectNextFolder:) discoverabilityTitle:@"Next Folder" wantPriority:YES];
    [self addKeyCommandWithInput:UIKeyInputUpArrow modifierFlags:UIKeyModifierShift action:@selector(selectPreviousFolder:) discoverabilityTitle:@"Previous Folder" wantPriority:YES];
    [self addKeyCommandWithInput:@"e" modifierFlags:UIKeyModifierCommand action:@selector(selectEverything:) discoverabilityTitle:@"Open All Stories"];
    [self addKeyCommandWithInput:UIKeyInputLeftArrow modifierFlags:0 action:@selector(selectPreviousIntelligence:) discoverabilityTitle:@"Switch Views"];
    [self addKeyCommandWithInput:UIKeyInputRightArrow modifierFlags:0 action:@selector(selectNextIntelligence:) discoverabilityTitle:@"Switch Views"];
    [self addKeyCommandWithInput:@"a" modifierFlags:UIKeyModifierCommand action:@selector(tapAddSite:) discoverabilityTitle:@"Add Site"];
}

- (void)viewWillAppear:(BOOL)animated {
//    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    [self resetRowHeights];
    
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad &&
//        !self.interactiveFeedDetailTransition) {
//
//        [appDelegate.masterContainerViewController transitionFromFeedDetail];
//    }
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
    
//    [MBProgressHUD hideHUDForView:appDelegate.detailViewController.view animated:NO];
    
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
        
        if (self.notifier.pendingHide) {
            [self hideNotifier];
        }
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
    [super viewDidAppear:animated];
//    self.navigationController.navigationBar.backItem.title = @"All Sites";
    [self layoutHeaderCounts:0];
    [self refreshHeaderCounts];
    
    if (self.appDelegate.isCompactWidth) {
        [self performSelector:@selector(fadeSelectedCell) withObject:self afterDelay:0.2];
        [self performSelector:@selector(fadeSelectedHeader) withObject:nil afterDelay:0.2];
        self.currentRowAtIndexPath = nil;
    } else {
        [self highlightSelection];
    }
    
    self.interactiveFeedDetailTransition = NO;

    [self becomeFirstResponder];
}

//- (void)handleGesture:(UIScreenEdgePanGestureRecognizer *)gesture {
//    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPad) return;
//
//    self.interactiveFeedDetailTransition = YES;
//
//    CGPoint point = [gesture locationInView:self.view];
//    CGFloat viewWidth = CGRectGetWidth(self.view.frame);
//    CGFloat percentage = MIN(point.x, viewWidth) / viewWidth;
////    NSLog(@"back gesture: %d, %f - %f/%f", (int)gesture.state, percentage, point.x, viewWidth);
//
//    if (gesture.state == UIGestureRecognizerStateBegan) {
////        if (appDelegate.storiesCollection.transferredFromDashboard) {
////            [appDelegate.dashboardViewController.storiesModule.storiesCollection
////             transferStoriesFromCollection:appDelegate.storiesCollection];
////            [appDelegate.dashboardViewController.storiesModule fadeSelectedCell:NO];
////        }
//    } else if (gesture.state == UIGestureRecognizerStateChanged) {
//        [appDelegate.masterContainerViewController interactiveTransitionFromFeedDetail:percentage];
//    } else if (gesture.state == UIGestureRecognizerStateEnded) {
//        CGPoint velocity = [gesture velocityInView:self.view];
//        if (velocity.x > 0) {
//            [appDelegate.masterContainerViewController transitionFromFeedDetail];
//        } else {
////            // Returning back to view, cancelling pop animation.
////            [appDelegate.masterContainerViewController transitionToFeedDetail:NO];
//        }
//
//        self.interactiveFeedDetailTransition = NO;
//    }
//}

- (void)fadeSelectedCell {
    [self fadeCellWithIndexPath:[self.feedTitlesTable indexPathForSelectedRow]];
}

- (void)fadeCellWithIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) return;
    [self tableView:self.feedTitlesTable deselectRowAtIndexPath:indexPath animated:YES];
    
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
    [self tableView:self.feedTitlesTable deselectRowAtIndexPath:[self.feedTitlesTable indexPathForSelectedRow] animated:YES];
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
        UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
        [self layoutForInterfaceOrientation:orientation];
        [self.notifier setNeedsLayout];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self reloadFeedTitlesTable];
    }];
}

- (void)layoutForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//    CGSize toolbarSize = [self.feedViewToolbar sizeThatFits:self.view.frame.size];
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        self.feedViewToolbar.frame = CGRectMake(-10.0f,
//                                                CGRectGetHeight(self.view.frame) - toolbarSize.height,
//                                                toolbarSize.width + 20, toolbarSize.height);
//    } else {
//        self.feedViewToolbar.frame = (CGRect){CGPointMake(0.f, CGRectGetHeight(self.view.frame) - toolbarSize.height), toolbarSize};
//    }
//    self.innerView.frame = (CGRect){CGPointZero, CGSizeMake(CGRectGetWidth(self.view.frame), CGRectGetMinY(self.feedViewToolbar.frame))};
    
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && !appDelegate.isCompactWidth) {
//        CGRect navFrame = appDelegate.navigationController.view.frame;
//        CGFloat limit = appDelegate.masterContainerViewController.rightBorder.frame.origin.x + 1;
//
//        if (navFrame.size.width > limit) {
//            navFrame.size.width = limit;
//            appDelegate.navigationController.view.frame = navFrame;
//        }
//    }
    
    self.notifier.offset = CGPointMake(0, 0);
    
    [self updateIntelligenceControlForOrientation:interfaceOrientation];
    [self layoutHeaderCounts:interfaceOrientation];
    [self refreshHeaderCounts];
}

- (void)updateIntelligenceControlForOrientation:(UIInterfaceOrientation)orientation {
    if (orientation == UIInterfaceOrientationUnknown) {
        orientation = self.view.window.windowScene.interfaceOrientation;
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && !UIInterfaceOrientationIsLandscape(orientation)) {
        [self.intelligenceControl setImage:[UIImage imageNamed:@"unread_yellow_icn.png"] forSegmentAtIndex:1];
        [self.intelligenceControl setImage:[Utilities imageNamed:@"indicator-focus" sized:14] forSegmentAtIndex:2];
        [self.intelligenceControl setImage:[Utilities imageNamed:@"unread_blue_icn.png" sized:14] forSegmentAtIndex:3];
        
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
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && UIInterfaceOrientationIsLandscape(orientation)) {
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

- (void)leavingApp {
    self.leftAppDate = [NSDate date];
}

- (void)returnToApp {
    NSDate *decayDate = [[NSDate alloc] initWithTimeIntervalSinceNow:(-1 * BACKGROUND_REFRESH_SECONDS)];
    NSLog(@"Left app: %@ - %f", self.leftAppDate, [self.leftAppDate timeIntervalSinceDate:decayDate]);
    if ([self.leftAppDate timeIntervalSinceDate:decayDate] < 0) {
        [appDelegate reloadFeedsView:YES];
    }
}

-(void)fetchFeedList:(BOOL)showLoader {
    NSString *urlFeedList;
    NSLog(@"Fetching feed list");
    [appDelegate cancelOfflineQueue];
    
    if (self.inPullToRefresh_) {
        urlFeedList = [NSString stringWithFormat:@"%@/reader/feeds?flat=true&update_counts=true&include_inactive=true",
                       self.appDelegate.url];
    } else {
        urlFeedList = [NSString stringWithFormat:@"%@/reader/feeds?flat=true&update_counts=false&include_inactive=true",
                       self.appDelegate.url];
    }
    
    if (appDelegate.backgroundCompletionHandler) {
        urlFeedList = [urlFeedList stringByAppendingString:@"&background_ios=true"];
    }
    
    [appDelegate GET:urlFeedList parameters:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishLoadingFeedList:responseObject];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        [self finishedWithError:error statusCode:httpResponse.statusCode];
    }];

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
        appDelegate.tryFeedStoryId = nil;
        appDelegate.inFindingStoryMode = NO;
        appDelegate.findingStoryStartDate = nil;
        
        [self showOfflineNotifier];
        
        return;
    }

    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    // User clicking on another link before the page loads is OK.
    [self informError:error];
    
    self.isOffline = YES;

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
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *preview = [userPreferences stringForKey:@"story_list_preview_images_size"];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.newsblur.NewsBlur-Group"];
    [defaults setObject:[results objectForKey:@"share_ext_token"] forKey:@"share:token"];
    [defaults setObject:self.appDelegate.url forKey:@"share:host"];
    [defaults setObject:appDelegate.dictSavedStoryTags forKey:@"share:tags"];
    [defaults setObject:appDelegate.dictFoldersArray forKey:@"share:folders"];
    [defaults setObject:preview forKey:@"widget:preview_images_size"];
    [self validateWidgetFeedsForGroupDefaults:defaults usingResults:results];
    [defaults synchronize];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [self.appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            [db executeUpdate:@"DELETE FROM accounts WHERE username = ?", self.appDelegate.activeUsername];
            [db executeUpdate:@"INSERT INTO accounts"
             "(username, download_date, feeds_json) VALUES "
             "(?, ?, ?)",
             self.appDelegate.activeUsername,
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
    
    UIImage *activityImage = [Utilities templateImageNamed:@"dialog-notifications" sized:32];
    NBBarButtonItem *activityButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
    activityButton.accessibilityLabel = @"Activities";
    [activityButton setImage:activityImage forState:UIControlStateNormal];
    activityButton.tintColor = UIColorFromRGB(0x8F918B);
    [activityButton setImageEdgeInsets:UIEdgeInsetsMake(4, 0, 4, 0)];
    [activityButton addTarget:self
                       action:@selector(showInteractionsPopover:)
             forControlEvents:UIControlEventTouchUpInside];
    activitiesButton = [[UIBarButtonItem alloc]
                        initWithCustomView:activityButton];
    activitiesButton.width = 32;
//    activityButton.backgroundColor = UIColor.redColor;
    self.navigationItem.rightBarButtonItem = activitiesButton;
    
    NSMutableDictionary *sortedFolders = [[NSMutableDictionary alloc] init];
    NSArray *sortedArray;
    
    // Set up dictSocialProfile and userActivitiesArray
    appDelegate.dictUnreadCounts = [NSMutableDictionary dictionary];
    appDelegate.dictSocialProfile = [results objectForKey:@"social_profile"];
    appDelegate.dictUserProfile = [results objectForKey:@"user_profile"];
    appDelegate.dictSocialServices = [results objectForKey:@"social_services"];
    appDelegate.userActivitiesArray = [results objectForKey:@"activities"];
    
    appDelegate.isPremium = [[appDelegate.dictUserProfile objectForKey:@"is_premium"] integerValue] == 1;
    appDelegate.isPremiumArchive = [[appDelegate.dictUserProfile objectForKey:@"is_archive"] integerValue] == 1;
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
    
    if (![[results objectForKey:@"flat_folders_with_inactive"] isKindOfClass:[NSArray class]]) {
        allFolders = [[results objectForKey:@"flat_folders_with_inactive"] mutableCopy];
    }
    
    [self fixFolderNames:allFolders];
    
    [allFolders setValue:socialFolder forKey:@"river_blurblogs"];
    [allFolders setValue:[[NSMutableArray alloc] init] forKey:@"river_global"];
    
    NSArray *savedSearches = [appDelegate updateSavedSearches:results];
    [allFolders setValue:savedSearches forKey:@"saved_searches"];
    
    NSArray *savedStories = [appDelegate updateStarredStoryCounts:results];
    [allFolders setValue:savedStories forKey:@"saved_stories"];

    appDelegate.dictFolders = allFolders;
    
    appDelegate.dictInactiveFeeds = [results[@"inactive_feeds"] mutableCopy];
    
    // set up dictFeeds
    appDelegate.dictFeeds = [[results objectForKey:@"feeds"] mutableCopy];
    [appDelegate.dictFeeds addEntriesFromDictionary:appDelegate.dictInactiveFeeds];
    [appDelegate populateDictUnreadCounts];
    [appDelegate populateDictTextFeeds];
    
    NSString *sortOrder = [userPreferences stringForKey:@"feed_list_sort_order"];
    BOOL sortByMostUsed = [sortOrder isEqualToString:@"usage"];
    
    NSMutableArray *sortDescriptors = [NSMutableArray array];
    
    if (sortByMostUsed) {
        [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"feed_opens" ascending:NO]];
    }
    
    NSSortDescriptor *titleDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"feed_title" ascending:YES comparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [[self sortableString:obj1] localizedStandardCompare:[self sortableString:obj2]];
    }];
    
    [sortDescriptors addObject:titleDescriptor];
    
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
        
        NSMutableArray *feeds = [NSMutableArray array];
        
        for (id feedId in folder) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
            NSDictionary *feed = nil;
            
            if ([appDelegate isSavedSearch:feedIdStr] || [appDelegate isSavedFeed:feedIdStr]) {
                feed = @{@"id" : feedId};
            } else if ([appDelegate isSocialFeed:feedIdStr]) {
                feed = appDelegate.dictSocialFeeds[feedIdStr];
            } else {
                feed = appDelegate.dictFeeds[feedIdStr];
            }
            
            if (feed != nil) {
                [feeds addObject:feed];
            }
        }
        
        NSArray *sortedFeeds = [feeds sortedArrayUsingDescriptors:sortDescriptors];
        
        sortedArray = [sortedFeeds valueForKey:@"id"];
        
        [sortedFolders setValue:sortedArray forKey:folderTitle];
    }
    
    appDelegate.dictFolders = sortedFolders;
    [appDelegate.dictFoldersArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
    appDelegate.dictSubfolders = [NSMutableDictionary dictionary];
    
    // Add feeds from subfolders
    [self addSubfolderFeeds];
    
    // Add all stories etc. to top
    [NewsBlurTopSectionNames enumerateObjectsUsingBlock:^(NSString * _Nonnull sectionName, NSUInteger sectionIndex, BOOL * _Nonnull stop) {
        [appDelegate.dictFoldersArray removeObject:sectionName];
        [appDelegate.dictFoldersArray insertObject:sectionName atIndex:sectionIndex];
    }];
    
    // Add Widget Site Stories folder to bottom
//    [appDelegate.dictFoldersArray removeObject:@"widget_stories"];
//    NSUserDefaults *groupDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.newsblur.NewsBlur-Group"];
//    NSMutableArray *feeds = [groupDefaults objectForKey:@"widget:feeds_array"];
//    if (feeds.count) {
//        [appDelegate.dictFoldersArray insertObject:@"widget_stories" atIndex:appDelegate.dictFoldersArray.count];
//    }
    
    // Add Read Stories folder to bottom
    [appDelegate.dictFoldersArray removeObject:@"read_stories"];
    [appDelegate.dictFoldersArray addObject:@"read_stories"];
    
    // Add Global Shared Stories folder to bottom
    [appDelegate.dictFoldersArray removeObject:@"river_global"];
    [appDelegate.dictFoldersArray addObject:@"river_global"];
    
    // Add All Shared Stories folder to bottom
    [appDelegate.dictFoldersArray removeObject:@"river_blurblogs"];
    [appDelegate.dictFoldersArray addObject:@"river_blurblogs"];
    
    // Add Saved Searches folder to bottom
    [appDelegate.dictFoldersArray removeObject:@"saved_searches"];
    if (appDelegate.savedSearchesCount) {
        [appDelegate.dictFoldersArray addObject:@"saved_searches"];
    }
    
    // Add Saved Stories folder to bottom
    [appDelegate.dictFoldersArray removeObject:@"saved_stories"];
    if (appDelegate.savedStoriesCount) {
        [appDelegate.dictFoldersArray addObject:@"saved_stories"];
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

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && finished) {
        [self cacheFeedRowLocations];
    }
    [self loadNotificationStory];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"FinishedLoadingFeedsNotification" object:nil];
}

- (NSString *)sortableString:(NSString *)original {
    NSString *string = original.lowercaseString;
    
    string = [self stripPrefix:@"the " fromString:string];
    string = [self stripPrefix:@"a " fromString:string];
    string = [self stripPrefix:@"an " fromString:string];
    
    return string;
}

- (NSString *)stripPrefix:(NSString *)prefix fromString:(NSString *)original {
    if ([original hasPrefix:prefix]) {
        return [original substringFromIndex:prefix.length];
    } else {
        return original;
    }
}

- (void)fixFolderNames:(NSMutableDictionary *)folders {
    for (NSString *folderName in folders.copy) {
        if ([folderName containsString:@" - "]) {
            NSDictionary *folder = folders[folderName];
            NSArray *components = [folderName componentsSeparatedByString:@" - "];
            NSMutableArray *parentComponents = [components mutableCopy];
            [parentComponents removeLastObject];
            NSString *rawParentName = [parentComponents componentsJoinedByString:@" - "];
            NSString *tidyParentName = [parentComponents componentsJoinedByString:@" ▸ "];
            NSString *tidyName = [components componentsJoinedByString:@" ▸ "];
            
            if (folders[rawParentName] != nil || folders[tidyParentName] != nil) {
                folders[folderName] = nil;
                folders[tidyName] = folder;
            }
        }
    }
}

- (void)cacheFeedRowLocations {
    indexPathsForFeedIds = [NSMutableDictionary dictionary];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0ul);

    dispatch_async(queue, ^{
        for (NSString *folderName in self.appDelegate.dictFoldersArray) {
            NSInteger section = [self.appDelegate.dictFoldersArray indexOfObject:folderName];
            NSArray *folder = [self.appDelegate.dictFolders objectForKey:folderName];
            for (NSInteger row=0; row < folder.count; row++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                [self->indexPathsForFeedIds setObject:indexPath forKey:[folder objectAtIndex:row]];
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
                               self.appDelegate.activeUsername];
        
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
    @throw [NSException exceptionWithName:@"Missing loadNotificationStory implementation" reason:@"This is implemented in the Swift subclass, so should never reach here." userInfo:nil];
}

- (void)addSubfolderFeeds {
    @throw [NSException exceptionWithName:@"Missing addSubfolderFeeds implementation" reason:@"This is implemented in the Swift subclass, so should never reach here." userInfo:nil];
}

- (NSString *)parentTitleForFolderTitle:(NSString *)folderTitle {
    @throw [NSException exceptionWithName:@"Missing parentTitleForFolderTitle: implementation" reason:@"This is implemented in the Swift subclass, so should never reach here." userInfo:nil];
}

- (NSArray<NSString *> *)parentTitlesForFolderTitle:(NSString *)folderTitle {
    @throw [NSException exceptionWithName:@"Missing parentsTitlesForFolderTitle: implementation" reason:@"This is implemented in the Swift subclass, so should never reach here." userInfo:nil];
}

- (void)showUserProfile {
    appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [appDelegate.dictSocialProfile objectForKey:@"user_id"]];
    appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@", [appDelegate.dictSocialProfile objectForKey:@"username"]];
//    appDelegate.activeUserProfileName = @"You";
    [appDelegate showUserProfileModal:self.navigationItem.titleView];
}

- (IBAction)tapAddSite:(id)sender {
//    [self.appDelegate.addSiteNavigationController popToRootViewControllerAnimated:NO];
//    [self.splitViewController showColumn:UISplitViewControllerColumnPrimary];
    [self.appDelegate showFeedsListAnimated:NO];
    
    [self.appDelegate showPopoverWithViewController:self.appDelegate.addSiteNavigationController contentSize:CGSizeMake(320, 96) barButtonItem:self.addBarButton];
    
    [self.appDelegate.addSiteViewController reload];
}

- (IBAction)showSettingsPopover:(id)sender {
    if (self.presentedViewController) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    MenuViewController *viewController = [MenuViewController new];
    
    [viewController addTitle:@"Preferences" iconName:@"dialog-preferences" iconColor:UIColorFromRGB(0xDF8566) selectionShouldDismiss:YES handler:^{
        [self.appDelegate showPreferences];
    }];
    
    [viewController addTitle:@"Mute Sites" iconName:@"menu_icn_mute.png" selectionShouldDismiss:YES handler:^{
        [self.appDelegate showMuteSites];
    }];
    
    [viewController addTitle:@"Organize Sites" iconName:@"dialog-organize" iconColor:UIColorFromRGB(0xDF8566) selectionShouldDismiss:YES handler:^{
        [self.appDelegate showOrganizeSites];
    }];
    
    [viewController addTitle:@"Widget Sites" iconName:@"calendar.png" selectionShouldDismiss:YES handler:^{
        [self.appDelegate showWidgetSites];
    }];
    
    [viewController addTitle:@"Notifications" iconName:@"dialog-notifications" iconColor:UIColorFromRGB(0xD58B4F) selectionShouldDismiss:YES handler:^{
        [self.appDelegate openNotificationsWithFeed:nil];
    }];
    
    [viewController addTitle:@"Find Friends" iconName:@"followers" iconColor:UIColorFromRGB(0x5FA1E7) selectionShouldDismiss:YES handler:^{
        [self.appDelegate showFindFriends];
    }];
    
    if (appDelegate.isPremium && appDelegate.isPremiumArchive) {
        [viewController addTitle:@"Premium Archive" iconName:@"g_icn_greensun.png" selectionShouldDismiss:YES handler:^{
            [self.appDelegate showPremiumDialog];
        }];
    } else if (appDelegate.isPremium) {
        [viewController addTitle:@"Upgrade to Archive" iconName:@"g_icn_greensun.png" selectionShouldDismiss:YES handler:^{
            [self.appDelegate showPremiumDialog];
        }];
    } else {
        [viewController addTitle:@"Upgrade to Premium" iconName:@"g_icn_greensun.png" selectionShouldDismiss:YES handler:^{
            [self.appDelegate showPremiumDialog];
        }];
    }
    
    [viewController addTitle:@"Support Forum" iconName:@"discourse.png" selectionShouldDismiss:YES handler:^{
        NSURL *url = [NSURL URLWithString:@"https://forum.newsblur.com"];
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }];
    
    [viewController addTitle:@"Logout" iconName:@"menu_icn_fetch_subscribers.png" selectionShouldDismiss:YES handler:^{
        [self.appDelegate confirmLogout];
    }];
    
    if ([appDelegate.activeUsername isEqualToString:@"samuel"] || [appDelegate.activeUsername isEqualToString:@"Dejal"]) {
        [viewController addTitle:@"Login as…" iconName:@"barbutton_sendto.png" selectionShouldDismiss:YES handler:^{
            [self showLoginAsDialog];
        }];
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPhone) {
        [appDelegate addSplitControlToMenuController:viewController];
    }
    
    NSString *preferenceKey = @"feed_list_font_size";
    NSArray *titles = @[@"XS", @"S", @"M", @"L", @"XL"];
    NSArray *values = @[@"xs", @"small", @"medium", @"large", @"xl"];
    
    [viewController addSegmentedControlWithTitles:titles values:values preferenceKey:preferenceKey selectionShouldDismiss:NO handler:^(NSUInteger selectedIndex) {
        [self.appDelegate resizeFontSize];
    }];
    
    preferenceKey = @"feed_list_spacing";
    titles = @[@"Compact", @"Comfortable"];
    values = @[@"compact", @"comfortable"];
    
    [viewController addSegmentedControlWithTitles:titles values:values defaultValue:@"comfortable" preferenceKey:preferenceKey selectionShouldDismiss:NO handler:^(NSUInteger selectedIndex) {
        [self reloadFeedTitlesTable];
        [self.appDelegate.feedDetailViewController reloadData];
    }];
    
    [viewController addThemeSegmentedControl];
    
    UINavigationController *navController = self.navigationController;
    
    [viewController showFromNavigationController:navController barButtonItem:self.settingsBarButton permittedArrowDirections:UIPopoverArrowDirectionDown];
}

- (void)showLoginAsDialog {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Login as..." message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:nil];
    [alertController addAction:[UIAlertAction actionWithTitle: @"Login" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        NSString *username = alertController.textFields[0].text;
        NSString *urlString = [NSString stringWithFormat:@"%@/reader/login_as?user=%@",
                               self.appDelegate.url, username];
        
        [self.appDelegate GET:urlString parameters:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            NSLog(@"Login as %@ successful", username);
            [MBProgressHUD hideHUDForView:self.appDelegate.feedsViewController.view animated:YES];
            [self.appDelegate reloadFeedsView:YES];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"Login as %@ gave error, but probably worked: %@", username, error);
            [MBProgressHUD hideHUDForView:self.appDelegate.feedsViewController.view animated:YES];
            [self.appDelegate reloadFeedsView:YES];
        }];
        
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.appDelegate.feedsViewController.view animated:YES];
        HUD.labelText = [NSString stringWithFormat:@"Login: %@", username];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel handler:nil]];
    [appDelegate.feedsViewController presentViewController:alertController animated:YES completion:nil];
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
        
        if ([preferences boolForKey:@"show_feeds_after_being_read"]) {
            [self.stillVisibleFeeds setObject:indexPath forKey:feedIdStr];
        }
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
    [appDelegate.feedsNavigationController dismissViewControllerAnimated:YES completion:nil];
    
    [self resizeFontSize];
    [self resetupGestures];
}

- (void)resizePreviewSize {
    [self reloadFeedTitlesTable];
    
    [appDelegate.feedDetailViewController reloadData];
}

- (void)resizeFontSize {
    appDelegate.fontDescriptorTitleSize = nil;
    [self reloadFeedTitlesTable];
    
    appDelegate.feedDetailViewController.invalidateFontCache = YES;
    [appDelegate.feedDetailViewController reloadData];
}

- (void)updateTheme {
    [super updateTheme];
   
    // CATALYST: This prematurely dismisses the login view controller; is it really appropriate?
//    if (![self.presentedViewController isKindOfClass:[UINavigationController class]] || (((UINavigationController *)self.presentedViewController).topViewController != (UIViewController *)self.appDelegate.fontSettingsViewController && ![((UINavigationController *)self.presentedViewController).topViewController conformsToProtocol:@protocol(IASKViewController)])) {
//        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
//    }
    
    [self.appDelegate hidePopoverAnimated:YES];
    
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] initWithIdiom:[[UIDevice currentDevice] userInterfaceIdiom]];
    appearance.backgroundColor = [UINavigationBar appearance].barTintColor;
    
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.tintColor = [UINavigationBar appearance].tintColor;
    self.navigationController.navigationBar.barTintColor = [UINavigationBar appearance].barTintColor;
    self.navigationController.navigationBar.barStyle = ThemeManager.shared.isDarkTheme ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.toolbar.tintColor = [UIToolbar appearance].tintColor;
    self.navigationController.toolbar.barTintColor = [UIToolbar appearance].barTintColor;
    self.feedViewToolbar.tintColor = [UINavigationBar appearance].tintColor;
    self.feedViewToolbar.barTintColor = [UINavigationBar appearance].barTintColor;
    self.addBarButton.tintColor = UIColorFromRGB(0x8F918B);
    self.settingsBarButton.tintColor = UIColorFromRGB(0x8F918B);
    self.refreshControl.tintColor = UIColorFromLightDarkRGB(0x0, 0xffffff);
    self.refreshControl.backgroundColor = UIColorFromRGB(0xE3E6E0);
    self.view.backgroundColor = UIColorFromRGB(0xf4f4f4);
    
    [[ThemeManager themeManager] updateSegmentedControl:self.intelligenceControl];
    
    NBBarButtonItem *barButton = self.addBarButton.customView;
    [barButton setImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"nav_icn_add.png"]] forState:UIControlStateNormal];
    
    self.settingsBarButton.image = [Utilities imageNamed:@"settings" sized:30];
    
    [self layoutHeaderCounts:0];
    [self refreshHeaderCounts];
    
    self.searchBar.backgroundColor = UIColorFromRGB(0xE3E6E0);
    self.searchBar.tintColor = UIColorFromRGB(0xffffff);
    self.searchBar.nb_searchField.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    self.searchBar.nb_searchField.tintColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    
    if ([ThemeManager themeManager].isDarkTheme) {
        self.feedTitlesTable.indicatorStyle = UIScrollViewIndicatorStyleWhite;
        self.searchBar.keyboardAppearance = UIKeyboardAppearanceDark;
    } else {
        self.feedTitlesTable.indicatorStyle = UIScrollViewIndicatorStyleBlack;
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

- (void)settingsUpdateSpecifierDictionary:(NSMutableDictionary *)dictionary {
    NSMutableArray *titles = dictionary[@"Titles"];
    NSMutableArray *values = dictionary[@"Values"];
    
    [titles removeAllObjects];
    [values removeAllObjects];
    
    [titles addObject:@"Show feed list"];
    [titles addObject:@"Open All Site Stories"];
    
    [values addObject:@"feeds"];
    [values addObject:@"everything"];
    
    for (NSString *folder in self.appDelegate.dictFoldersArray) {
        if ([folder hasPrefix:@"river_"] || [folder isEqualToString:@"everything"] || [folder isEqualToString:@"infrequent"] || [folder isEqualToString:@"widget"] || [folder isEqualToString:@"read_stories"] || [folder hasPrefix:@"saved_"]) {
            continue;
        }
        
        [titles addObject:[NSString stringWithFormat:@"Open %@", folder]];
        [values addObject:folder];
    }
}

- (void)settingDidChange:(NSNotification*)notification {
    NSString *identifier = notification.object;
    
    if (![identifier isKindOfClass:[NSString class]]) {
        identifier = notification.userInfo.allKeys.firstObject;
    }
    
    if ([identifier isEqualToString:@"split_behavior"]) {
        [self.appDelegate updateSplitBehavior];
    } else if ([identifier isEqualToString:@"feed_list_sort_order"]) {
        [self.appDelegate reloadFeedsView:YES];
    } else if ([identifier isEqual:@"feed_list_font_size"]) {
        [self resizeFontSize];
    } else if ([identifier isEqual:@"theme_auto_brightness"]) {
        [self updateThemeBrightness];
    } else if ([identifier isEqual:@"theme_style"]) {
        [self updateThemeStyle];
    } else if ([identifier isEqual:@"story_titles_position"]) {
        [self.appDelegate.detailViewController updateLayoutWithReload:YES];
    } else if ([identifier isEqual:@"story_list_preview_images_size"]) {
        NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
        NSString *preview = [userPreferences stringForKey:@"story_list_preview_images_size"];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.newsblur.NewsBlur-Group"];
        [defaults setObject:preview forKey:@"widget:preview_images_size"];
        [self.appDelegate.storyPagesViewController reloadWidget];
    }
    
    [appDelegate setHiddenPreferencesAnimated:YES];
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier {
	if ([specifier.key isEqualToString:@"offline_cache_empty_stories"]) {
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
        dispatch_async(queue, ^{
            dispatch_sync(dispatch_get_main_queue(), ^{
                [[NSUserDefaults standardUserDefaults] setObject:@"Deleting..." forKey:specifier.key];
            });
            [self.appDelegate.database inDatabase:^(FMDatabase *db) {
                [db executeUpdate:@"VACUUM"];
                [self.appDelegate setupDatabase:db force:YES];
                [db executeUpdate:@"DELETE FROM stories"];
                [db executeUpdate:@"DELETE FROM text"];
                [db executeUpdate:@"DELETE FROM cached_images"];
                [self.appDelegate deleteAllCachedImages];
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [[NSUserDefaults standardUserDefaults] setObject:@"Cleared all stories and images!"
                                                              forKey:specifier.key];
                });
            }];
        });
	} else if ([specifier.key isEqualToString:@"import_prefs"]) {
        [ImportExportPreferences importFromController:sender];
    } else if ([specifier.key isEqualToString:@"export_prefs"]) {
        [ImportExportPreferences exportFromController:sender];
    } else if ([specifier.key isEqualToString:@"delete_account"]) {
        [sender dismiss:nil];
        
        NSString *urlString = [NSString stringWithFormat:@"%@/profile/delete_account",
                               self.appDelegate.url];
        
        [self.appDelegate showInAppBrowser:[NSURL URLWithString:urlString] withCustomTitle:@"Delete Account" fromSender:nil];
    }
}

- (void)validateWidgetFeedsForGroupDefaults:(NSUserDefaults *)groupDefaults usingResults:(NSDictionary *)results {
    NSMutableArray *feeds = [groupDefaults objectForKey:@"widget:feeds_array"];
    
    if (feeds == nil) {
        feeds = [NSMutableArray array];
        
        NSDictionary *resultsFeeds = results[@"feeds"];
        
        [resultsFeeds enumerateKeysAndObjectsUsingBlock:^(id key, NSDictionary *obj, BOOL *stop) {
            NSMutableDictionary *feed = [NSMutableDictionary dictionary];
            NSString *fade = obj[@"favicon_fade"];
            NSString *color = obj[@"favicon_color"];
            
            feed[@"id"] = [NSString stringWithFormat:@"%@", key];
            feed[@"feed_title"] = [NSString stringWithFormat:@"%@", obj[@"feed_title"]];
            
            if (fade != nil && ![fade isKindOfClass:[NSNull class]]) {
                feed[@"favicon_fade"] = fade;
            }
            
            if (color != nil && ![color isKindOfClass:[NSNull class]]) {
                feed[@"favicon_color"] = color;
            }
            
            [feeds addObject:feed];
        }];
        
        [groupDefaults setObject:feeds forKey:@"widget:feeds_array"];
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

    NSInteger count = [[appDelegate.dictFolders objectForKey:folderName] count];
    NSInteger limit = 5000;
    
    if (count > limit) {
        NSLog(@"Folder %@ contains %@ feeds; limiting to %@", folderName, @(count), @(limit));  // log
        
        count = limit;
    }
    
//    NSLog(@"Folder %@ contains %@ feeds", folderName, @(count));  // log
    
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
                     cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    NSArray *folder = [appDelegate.dictFolders objectForKey:folderName];
    
    if (indexPath.row >= folder.count) {
        NSLog(@"Detected attempt to access row %@ of %@ when there are only %@; this will crash!", @(indexPath.row), folderName, @(folder.count));  // log
    }
    
    id feedId = [folder objectAtIndex:indexPath.row];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    BOOL isSavedSearch = [appDelegate isSavedSearch:feedIdStr];
    NSString *searchQuery = [appDelegate searchQueryForFeedId:feedIdStr];
    NSString *searchFolder = [appDelegate searchFolderForFeedId:feedIdStr];
    feedIdStr = [appDelegate feedIdWithoutSearchQuery:feedIdStr];
    BOOL isSocial = [appDelegate isSocialFeed:feedIdStr];
    BOOL isSaved = [appDelegate isSavedFeed:feedIdStr];
    BOOL isSavedStoriesFeed = self.appDelegate.isSavedStoriesIntelligenceMode && [self.appDelegate savedStoriesCountForFeed:feedIdStr] > 0;
    BOOL isInactive = appDelegate.dictInactiveFeeds[feedIdStr] != nil;
    BOOL isOmitted = false;
    NSString *CellIdentifier;
    
    if (self.searchFeedIds && !isSaved) {
        isOmitted = ![self.searchFeedIds containsObject:feedIdStr];
    } else {
        isOmitted = [appDelegate isFolderCollapsed:folderName] || !([self isFeedVisible:feedIdStr] || isSavedSearch);
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
    cell.isSearch      = isSavedSearch;
    cell.isSaved       = isSaved;
    cell.isInactive    = isInactive;
    cell.searchQuery   = searchQuery;
    
    NSArray *folderComponents = [folderName componentsSeparatedByString:@" ▸ "];
    BOOL isTopLevel = [folderName isEqualToString:@"everything"] || [folderName isEqualToString:@"widget_stories"] || [folderName isEqualToString:@"saved_searches"] || [folderName isEqualToString:@"saved_stories"];
    
    cell.indentationLevel = isTopLevel ? 0 : folderComponents.count;
    cell.indentationWidth = 28;
    
    if (newCell) {
        [cell setupGestures];
    }
    
    if (searchQuery != nil) {
        cell.positiveCount = 0;
        cell.neutralCount = 0;
        cell.negativeCount = 0;
        cell.savedStoriesCount = 0;
        cell.feedTitle = [NSString stringWithFormat:@"\"%@\" in %@", cell.searchQuery, cell.feedTitle];
        
        if (searchFolder != nil) {
            cell.feedFavicon = [appDelegate folderIcon:searchFolder];
            cell.feedTitle = [NSString stringWithFormat:@"\"%@\" in %@", cell.searchQuery, [appDelegate folderTitle:searchFolder]];
        }
    } else if (isInactive) {
        cell.positiveCount = 0;
        cell.neutralCount = 0;
        cell.negativeCount = 0;
        cell.savedStoriesCount = 0;
    } else if (isSavedStoriesFeed) {
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
    
    [appDelegate.storiesCollection reset];
    
    [self clearSelectedHeader];
    
    if (self.currentRowAtIndexPath != nil && self.currentRowAtIndexPath != indexPath) {
        [self fadeCellWithIndexPath:self.currentRowAtIndexPath];
    }
    
    // set the current row pointer
    self.currentRowAtIndexPath = indexPath;
    self.currentSection = -1;
    self.lastRowAtIndexPath = indexPath;
    self.lastSection = -1;
    
    NSString *folderName = appDelegate.dictFoldersArray[indexPath.section];
    id feedId = [[appDelegate.dictFolders objectForKey:folderName] objectAtIndex:indexPath.row];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSString *searchQuery = [appDelegate searchQueryForFeedId:feedIdStr];
    NSString *searchFolder = [appDelegate searchFolderForFeedId:feedIdStr];
    feedIdStr = [appDelegate feedIdWithoutSearchQuery:feedIdStr];
    
    // If all feeds are already showing, no need to remember this one.
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    if (!self.viewShowingAllFeeds && [preferences boolForKey:@"show_feeds_after_being_read"]) {
        [self.stillVisibleFeeds setObject:indexPath forKey:feedIdStr];
    }
    
    [[tableView cellForRowAtIndexPath:indexPath] setNeedsDisplay];
    
    if (searchFolder != nil) {
        [appDelegate loadRiverFeedDetailView:appDelegate.feedDetailViewController withFolder:searchFolder];
    } else {
        [appDelegate loadFolder:folderName feedID:feedIdStr];
    }
    
    if (searchQuery != nil) {
        appDelegate.storiesCollection.inSearch = YES;
        appDelegate.storiesCollection.searchQuery = searchQuery;
        appDelegate.storiesCollection.savedSearchQuery = searchQuery;
    }
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
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
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
        
        for (NSString *parentName in [self parentTitlesForFolderTitle:folderName]) {
            if ([appDelegate isFolderCollapsed:parentName]) {
                return 0;
            }
        }
        
        if (![self isFeedVisible:feedId]) {
            return 0;
        }
    }
    
    NSArray *subfolderFeeds = appDelegate.dictSubfolders[folderName];
    
    for (id subFeedId in subfolderFeeds) {
        if ([subFeedId isEqual:feedId]) {
            return 0;
        }
    }
    
    NSInteger height;
    
    if ([folderName isEqualToString:@"river_blurblogs"] ||
        [folderName isEqualToString:@"river_global"]) { // blurblogs
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            height = kBlurblogTableViewRowHeight;
        } else {
            height = kPhoneBlurblogTableViewRowHeight;
        }
    } else {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            height = kTableViewRowHeight;
        } else {
            height = kPhoneTableViewRowHeight;
        }
    }
    
    UIFontDescriptor *fontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
    UIFont *font = [UIFont fontWithName:@"WhitneySSm-Medium" size:fontDescriptor.pointSize];
    NSString *spacing = [[NSUserDefaults standardUserDefaults] objectForKey:@"feed_list_spacing"];
    NSInteger offset = [spacing isEqualToString:@"compact"] ? 6 : 0;
    
    return height + (font.pointSize * 2) - offset;
}

- (void)resetRowHeights {
    [self.rowHeights removeAllObjects];
}

- (void)reloadFeedTitlesTable {
    [self resetRowHeights];
    [self.feedTitlesTable reloadData];
    [self highlightSelection];
}

- (void)updateFeedTitlesTable {
    [self.feedTitlesTable reloadData];
    [self highlightSelection];
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
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:12.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"medium"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:13.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"large"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:16.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xl"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:18.0f];
        }
    }
    return fontDescriptor;
}

- (UIView *)tableView:(UITableView *)tableView 
            viewForHeaderInSection:(NSInteger)section {
    UIFontDescriptor *fontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
    UIFont *font = [UIFont fontWithName:@"WhitneySSm-Medium" size:fontDescriptor.pointSize];
    NSInteger height = kFolderTitleHeight;
    
    CGRect rect = CGRectMake(0.0, 0.0, tableView.frame.size.width, height + font.pointSize*2);
    FolderTitleView *folderTitle = [[FolderTitleView alloc] initWithFrame:rect];
    folderTitle.section = (int)section;
    
    self.folderTitleViews[@(section)] = folderTitle;
    
    if (self.currentSection == section) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self highlightSelection];
        });
    }
    
    return folderTitle;
}

- (IBAction)sectionTapped:(UIButton *)button {
    [self clearSelectedHeader];
    
    button.backgroundColor = UIColorFromRGB(0x214607);
}

- (IBAction)sectionUntapped:(UIButton *)button {
}

- (IBAction)sectionUntappedOutside:(UIButton *)button {
    button.backgroundColor = [UIColor clearColor];
    
    [self highlightSelection];
}

- (void)fadeSelectedHeader {
    if (self.currentSection >= 0) {
        FolderTitleView *title = self.folderTitleViews[@(self.currentSection)];
        
        [UIView animateWithDuration:0.2 animations:^{
            title.invisibleHeaderButton.layer.backgroundColor = [UIColor clearColor].CGColor;
        } completion:NULL];
        
        self.currentSection = -1;
    }
}

- (void)clearSelectedHeader {
    if (self.currentSection >= 0) {
        FolderTitleView *title = self.folderTitleViews[@(self.currentSection)];
        
        title.invisibleHeaderButton.backgroundColor = UIColor.clearColor;
        
        self.currentSection = -1;
    }
}

- (void)highlightSelection {
    if (self.currentRowAtIndexPath != nil) {
        [self.feedTitlesTable selectRowAtIndexPath:self.currentRowAtIndexPath
                                          animated:NO
                                    scrollPosition:UITableViewScrollPositionNone];
    } else if (self.currentSection >= 0) {
        FolderTitleView *title = self.folderTitleViews[@(self.currentSection)];
        UIColor *color = UIColorFromLightSepiaMediumDarkRGB(0xFFFFD2, 0xFFFFD2, 0x304050, 0x000022);
        CGFloat hue;
        CGFloat saturation;
        CGFloat brightness;
        CGFloat alpha;
        [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
        color = [UIColor colorWithHue:hue saturation:1 brightness:1 alpha:alpha];
        
        title.invisibleHeaderButton.backgroundColor = color;
        [title.invisibleHeaderButton setNeedsDisplay];
    }
}

- (CGFloat)tableView:(UITableView *)tableView
heightForHeaderInSection:(NSInteger)section {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    if ([appDelegate.dictFoldersArray count] == 0) return 0;
    
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:section];
    
    BOOL visibleFeeds = [[self.visibleFolders objectForKey:folderName] boolValue];
    if (!visibleFeeds && section != NewsBlurTopSectionInfrequentSiteStories && section != NewsBlurTopSectionAllStories &&
        ![folderName isEqualToString:@"river_global"] &&
        ![folderName isEqualToString:@"river_blurblogs"] &&
        ![folderName isEqualToString:@"saved_searches"] &&
        ![folderName isEqualToString:@"saved_stories"] &&
        ![folderName isEqualToString:@"read_stories"] &&
        ![folderName isEqualToString:@"widget_stories"]) {
        return 0;
    }
    
    if (section == NewsBlurTopSectionInfrequentSiteStories &&
        ![prefs boolForKey:@"show_infrequent_site_stories"]) {
        return 0;
    }

    if ([folderName isEqual:@"river_global"] &&
        ![prefs boolForKey:@"show_global_shared_stories"]) {
        return 0;
    }
    
    for (NSString *parentName in [self parentTitlesForFolderTitle:folderName]) {
        if ([appDelegate isFolderCollapsed:parentName]) {
            return 0;
        }
    }
    
    UIFontDescriptor *fontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
    UIFont *font = [UIFont fontWithName:@"WhitneySSm-Medium" size:fontDescriptor.pointSize];
    NSInteger height = kFolderTitleHeight;
    
    return height + font.pointSize*2;
}

- (void)didSelectSectionHeader:(UIButton *)button {
    [self didSelectSectionHeaderWithTag:button.tag];
}

- (void)didSelectSectionHeaderWithTag:(NSInteger)tag {
    if (self.currentRowAtIndexPath != nil) {
        [self fadeCellWithIndexPath:self.currentRowAtIndexPath];
    }
    
    [self clearSelectedHeader];
    
    // reset pointer to the cells
    self.currentRowAtIndexPath = nil;
    self.currentSection = tag;
    self.lastRowAtIndexPath = nil;
    self.lastSection = tag;
    
    [self highlightSelection];
    
    NSString *folder = [appDelegate.dictFoldersArray objectAtIndex:tag];
    
    if (tag >= 0 && tag < [NewsBlurTopSectionNames count]) {
        folder = NewsBlurTopSectionNames[tag];
    } else if (![folder isEqualToString:@"river_global"] && ![folder isEqualToString:@"river_blurblogs"]) {
        folder = [NSString stringWithFormat:@"%ld", (long)tag];
    }
    
    [appDelegate loadRiverFeedDetailView:appDelegate.feedDetailViewController withFolder:folder];
}

- (NSArray *)allIndexPaths {
    NSMutableArray *array = [NSMutableArray array];
    
    for (NSInteger section = 0; section < self.feedTitlesTable.numberOfSections; section++) {
        for (NSInteger row = 0; row < [self.feedTitlesTable numberOfRowsInSection:section]; row++) {
            [array addObject:[NSIndexPath indexPathForRow:row inSection:section]];
        }
    }
    
    return array;
}

- (void)selectNextFolderOrFeed {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (self.lastRowAtIndexPath != nil) {
            [self selectNextFeed:nil];
        } else {
            [self selectNextFolder:nil];
        }
    });
}

- (void)selectNextFeed:(id)sender {
    NSArray *indexPaths = [self allIndexPaths];
    NSIndexPath *indexPath = self.lastRowAtIndexPath;
    NSIndexPath *stopAtIndexPath = indexPath;
    BOOL foundNext;
    
    do {
        foundNext = YES;
        
        if (indexPath == nil) {
            if (self.lastSection < 0) {
                indexPath = indexPaths.firstObject;
            } else {
                indexPath = [NSIndexPath indexPathForRow:0 inSection:self.lastSection];
            }
            
            stopAtIndexPath = indexPath;
        } else {
            NSInteger index = [indexPaths indexOfObject:indexPath];
            
            if (index == NSNotFound) {
                index = -1;
            }
            
            index += 1;
            
            if (index >= indexPaths.count) {
                index = 0;
            }
            
            indexPath = indexPaths[index];
        }
        
        if (sender == nil) {
            NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
            id feedId = [[appDelegate.dictFolders objectForKey:folderName] objectAtIndex:indexPath.row];
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
            BOOL isInactive = appDelegate.dictInactiveFeeds[feedIdStr] != nil;
            
            if (isInactive || [appDelegate isFolderOrParentCollapsed:folderName]) {
                foundNext = NO;
            } else {
                FeedTableCell *cell = (FeedTableCell *)[self tableView:feedTitlesTable cellForRowAtIndexPath:indexPath];
                
                if ([cell.reuseIdentifier isEqualToString:@"BlankCellIdentifier"]) {
                    foundNext = NO;
                } else {
                    BOOL hasUnread = cell.positiveCount > 0 || cell.neutralCount > 0 || cell.negativeCount > 0;
                    
                    if (!hasUnread) {
                        foundNext = NO;
                    }
                }
            }
        }
    } while (!foundNext && ![indexPath isEqual:stopAtIndexPath]);
    
    [self.feedTitlesTable selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
    [self tableView:self.feedTitlesTable didSelectRowAtIndexPath:indexPath];
}

- (void)selectPreviousFeed:(id)sender {
    NSArray *indexPaths = [self allIndexPaths];
    NSIndexPath *indexPath = self.lastRowAtIndexPath;
    
    if (indexPath == nil) {
        if (self.lastSection < 0) {
            indexPath = indexPaths.firstObject;
        } else {
            indexPath = [NSIndexPath indexPathForRow:0 inSection:self.lastSection];
        }
    }
    
    NSInteger index = [indexPaths indexOfObject:indexPath];
    
    if (index == NSNotFound) {
        index = 0;
    }
    
    index -= 1;
    
    if (index < 0) {
        index = indexPaths.count - 1;
    }
    
    indexPath = indexPaths[index];
    
    [self.feedTitlesTable selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
    [self tableView:self.feedTitlesTable didSelectRowAtIndexPath:indexPath];
}

- (void)selectNextFolder:(id)sender {
    NSInteger section = self.lastSection;
    NSInteger stopAtSection = section;
    BOOL foundNext;
    
    do {
        foundNext = YES;
        
        if (section < self.feedTitlesTable.numberOfSections - 1) {
            section += 1;
        } else {
            section = 0;
        }
        
        if (sender == nil) {
            NSString *folderName = appDelegate.dictFoldersArray[section];
            UnreadCounts *counts = [appDelegate splitUnreadCountForFolder:folderName];
            BOOL hasUnread = counts.ps > 0 || counts.nt > 0;
            
            if (!hasUnread) {
                foundNext = NO;
            }
        }
    } while (!foundNext && section != stopAtSection);
    
    [self didSelectSectionHeaderWithTag:section];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:section];
    
    if ([self.feedTitlesTable numberOfRowsInSection:section] > 0) {
        [self.feedTitlesTable scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

- (void)selectPreviousFolder:(id)sender {
    NSInteger section = self.lastSection;
    
    if (section > 0) {
        section -= 1;
    } else {
        section = self.feedTitlesTable.numberOfSections - 1;
    }
    
    [self didSelectSectionHeaderWithTag:section];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:section];
    
    if ([self.feedTitlesTable numberOfRowsInSection:section] > 0) {
        [self.feedTitlesTable scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

- (void)selectEverything:(id)sender {
    [self didSelectSectionHeaderWithTag:NewsBlurTopSectionAllStories];
}

- (void)selectWidgetStories {
    NSInteger tag = [appDelegate.dictFoldersArray indexOfObject:self.appDelegate.widgetFolder];
    
    if (tag != NSNotFound) {
        [self didSelectSectionHeaderWithTag:tag];
    }
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
    feedId = [appDelegate feedIdWithoutSearchQuery:feedId];
    
    if (state == MCSwipeTableViewCellState1) {
        
        if (indexPath.section == 1) {
            // Profile
            NSDictionary *feed = [appDelegate.dictSocialFeeds objectForKey:feedId];
            appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [feed objectForKey:@"user_id"]];
            appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@", [feed objectForKey:@"username"]];
            [appDelegate showUserProfileModal:cell];
        } else {
            NSString *swipe = [preferences stringForKey:@"feed_swipe_left"];
            
            if ([swipe isEqualToString:@"notifications"]) {
                [appDelegate openNotificationsWithFeed:feedId sender:cell];
            } else if ([swipe isEqualToString:@"statistics"]) {
                [appDelegate openStatisticsWithFeed:feedId sender:cell];
            } else {
                // Train
                appDelegate.storiesCollection.activeFeed = [appDelegate.dictFeeds objectForKey:feedId];
                [appDelegate openTrainSiteWithFeedLoaded:NO from:cell];
            }
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
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
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

    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
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
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
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
    
    [appDelegate.storyPagesViewController reloadWidget];
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
        return [self.appDelegate savedStoriesCountForFeed:feedId] > 0 || [self.appDelegate isSavedFeed:feedId] || [self.appDelegate isSavedSearch:feedId];
    } else if (!stillVisible && [self.appDelegate isSavedSearch:feedId]) {
        return YES;
    } else if (!stillVisible &&
        appDelegate.selectedIntelligence >= 1 &&
        [[unreadCounts objectForKey:@"ps"] intValue] <= 0) {
        return NO;
    } else if (!stillVisible &&
               !self.viewShowingAllFeeds &&
               ([[unreadCounts objectForKey:@"ps"] intValue] <= 0 &&
                [[unreadCounts objectForKey:@"nt"] intValue] <= 0)) {
        return NO;
    } else if (!stillVisible &&
               !self.viewShowingAllFeeds &&
               appDelegate.dictInactiveFeeds[feedId] != nil) {
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
        hud.labelText = @"All Site Stories";
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
    
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        FeedDetailViewController *storiesModule = self.appDelegate.dashboardViewController.storiesModule;
//
//        storiesModule.storiesCollection.feedPage = 0;
//        storiesModule.storiesCollection.storyCount = 0;
//        storiesModule.pageFinished = NO;
//        [storiesModule.storiesCollection calculateStoryLocations];
//        [storiesModule reloadData];
//    }
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
        
        if ([folderName isEqualToString:@"saved_searches"]) {
            return;
        }
        
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

    [appDelegate GET:urlString parameters:nil target:self success:@selector(saveAndDrawFavicons:) failure:@selector(requestFailed:)];
}

- (void)loadAvatars {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0ul);
    dispatch_async(queue, ^{
        for (NSString *feed_id in [self.appDelegate.dictSocialFeeds allKeys]) {
            NSDictionary *feed = [self.appDelegate.dictSocialFeeds objectForKey:feed_id];
            NSURL *imageURL = [NSURL URLWithString:[feed objectForKey:@"photo_url"]];
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
            if (!imageData) continue;
            UIImage *faviconImage = [UIImage imageWithData:imageData];
            if (!faviconImage) continue;
            faviconImage = [Utilities roundCorneredImage:faviconImage radius:6];
            
            [self.appDelegate saveFavicon:faviconImage feedId:feed_id];
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
            
            if (![self.appDelegate.dictFeeds objectForKey:feed_id]) continue;
            NSString *favicon = [results objectForKey:feed_id];
            if ((NSNull *)favicon != [NSNull null] && [favicon length] > 0) {
                NSData *imageData = [[NSData alloc] initWithBase64EncodedString:favicon options:NSDataBase64DecodingIgnoreUnknownCharacters];
//                NSData *imageData = [NSData dataWithBase64EncodedString:favicon];
                UIImage *faviconImage = [UIImage imageWithData:imageData];
                [self.appDelegate saveFavicon:faviconImage feedId:feed_id];
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
    
    [appDelegate GET:urlString parameters:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishRefreshingFeedList:responseObject feedId:feedId];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;

        [self finishRefresh];

        if ([httpResponse statusCode] == 403) {
            NSLog(@"Showing login after refresh");
            return [self.appDelegate showLogin];
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
        NSInteger intelligenceLevel = [self.appDelegate selectedIntelligence];
        for (id feed in newFeedCounts) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", feed];
            NSMutableDictionary *unreadCount = [[self.appDelegate.dictUnreadCounts objectForKey:feedIdStr] mutableCopy];
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
                for (int s=0; s < [self.appDelegate.dictFoldersArray count]; s++) {
                    NSString *folderName = [self.appDelegate.dictFoldersArray objectAtIndex:s];
                    NSArray *activeFolderFeeds = [self.activeFeedLocations objectForKey:folderName];
                    NSArray *originalFolder = [self.appDelegate.dictFolders objectForKey:folderName];
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
            [self.appDelegate.dictUnreadCounts setObject:unreadCount forKey:feedIdStr];
        }
        
        NSDictionary *newSocialFeedCounts = [results objectForKey:@"social_feeds"];
        for (id feed in newSocialFeedCounts) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", feed];
            NSMutableDictionary *unreadCount = [[self.appDelegate.dictUnreadCounts objectForKey:feedIdStr] mutableCopy];
            NSMutableDictionary *newFeedCount = [newSocialFeedCounts objectForKey:feed];

            if (![unreadCount isKindOfClass:[NSDictionary class]]) continue;
            [unreadCount setObject:[newFeedCount objectForKey:@"ng"] forKey:@"ng"];
            [unreadCount setObject:[newFeedCount objectForKey:@"nt"] forKey:@"nt"];
            [unreadCount setObject:[newFeedCount objectForKey:@"ps"] forKey:@"ps"];
            [self.appDelegate.dictUnreadCounts setObject:unreadCount forKey:feedIdStr];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.appDelegate.folderCountCache removeAllObjects];
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
//    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.rightBarButtonItem = nil;
}

- (void)layoutHeaderCounts:(UIInterfaceOrientation)orientation {
    if (!orientation) {
        orientation = self.view.window.windowScene.interfaceOrientation;
    }
    
    BOOL isShort = NO;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone &&
        UIInterfaceOrientationIsLandscape(orientation)) {
        isShort = YES;
    }
    
    int yOffset = isShort ? 0 : 6;
    UIView *userInfoView = [[UIView alloc]
                            initWithFrame:CGRectMake(0, 0,
                                                     self.navigationController.navigationBar.frame.size.width,
                                                     self.navigationController.navigationBar.frame.size.height)];
    // adding user avatar to left
    NSURL *imageURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@",
                                            [appDelegate.dictSocialProfile
                                             objectForKey:@"large_photo_url"]]];
    userAvatarButton = [UIButton systemButtonWithImage:[UIImage imageNamed:@"user"]
                                                target:self action:@selector((showUserProfile))];
    userAvatarButton.pointerInteractionEnabled = YES;
    userAvatarButton.accessibilityLabel = @"User info";
    userAvatarButton.accessibilityHint = @"Double-tap for information about your account.";
    UIEdgeInsets insets = UIEdgeInsetsMake(0, -10, 10, 0);
    userAvatarButton.contentEdgeInsets = insets;
    
    NSMutableURLRequest *avatarRequest = [NSMutableURLRequest requestWithURL:imageURL];
    [avatarRequest addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    [avatarRequest setTimeoutInterval:30.0];
    avatarImageView = [[UIImageView alloc] initWithFrame:userAvatarButton.frame];
    typeof(self) __weak weakSelf = self;
    [avatarImageView setImageWithURLRequest:avatarRequest placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        typeof(weakSelf) __strong strongSelf = weakSelf;
        image = [Utilities roundCorneredImage:image radius:6 convertToSize:CGSizeMake(38, 38)];
        image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        [(UIButton *)strongSelf.userAvatarButton setImage:image forState:UIControlStateNormal];
        
    } failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nonnull response, NSError * _Nonnull error) {
        NSLog(@"Could not fetch user avatar: %@", error);
    }];
    
    [userInfoView addSubview:userAvatarButton];
    
    userLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, yOffset, userInfoView.frame.size.width, 16)];
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
    yellowIcon.hidden = YES;
    
    neutralCount = [[UILabel alloc] init];
    neutralCount.font = [UIFont fontWithName:@"WhitneySSm-Book" size:12];
    neutralCount.textColor = UIColorFromRGB(0x707070);
    neutralCount.backgroundColor = [UIColor clearColor];
    [userInfoView addSubview:neutralCount];
    
    greenIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"g_icn_focus"]];
    [userInfoView addSubview:greenIcon];
    greenIcon.hidden = YES;
    
    positiveCount = [[UILabel alloc] init];
    positiveCount.font = [UIFont fontWithName:@"WhitneySSm-Book" size:12];
    positiveCount.textColor = UIColorFromRGB(0x707070);
    positiveCount.backgroundColor = [UIColor clearColor];
    [userInfoView addSubview:positiveCount];
    
    [userInfoView sizeToFit];
    
//    userInfoView.backgroundColor = UIColor.blueColor;
    
    self.navigationItem.titleView = userInfoView;
}

- (void)refreshHeaderCounts {
    if (!appDelegate.activeUsername) {
        userAvatarButton.hidden = YES;
        return;
    }
    
    userAvatarButton.hidden = NO;
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
    
    yellowIcon.hidden = NO;
    greenIcon.hidden = NO;
    
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

- (void)showCachingNotifier:(NSString *)prefix progress:(float)progress hoursBack:(NSInteger)hours {
    //    [self.notifier hide];
    self.notifier.style = NBSyncingProgressStyle;
    if (hours < 2) {
        self.notifier.title = [NSString stringWithFormat:@"%@ from last hour", prefix];
    } else if (hours < 24) {
        self.notifier.title = [NSString stringWithFormat:@"%@ from %ld hours ago", prefix, (long)hours];
    } else if (hours < 48) {
        self.notifier.title = [NSString stringWithFormat:@"%@ from yesterday", prefix];
    } else {
        self.notifier.title = [NSString stringWithFormat:@"%@ from %d days ago", prefix, (int)round(hours / 24.f)];
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
