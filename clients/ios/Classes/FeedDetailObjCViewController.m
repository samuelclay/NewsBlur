//
//  FeedDetailObjCViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "FeedDetailObjCViewController.h"
#import "NewsBlurAppDelegate.h"
#import "FeedDetailTableCell.h"
#import "UserProfileViewController.h"
#import "NSString+HTML.h"
#import "MBProgressHUD.h"
#import "SBJson4.h"
#import "NSObject+SBJSON.h"
#import "StringHelper.h"
#import "Utilities.h"
#import "UIBarButtonItem+Image.h"
#import "MarkReadMenuViewController.h"
#import "NBNotifier.h"
#import "NBLoadingCell.h"
#import "FMDatabase.h"
#import "NBBarButtonItem.h"
#import "UIImage+Resize.h"
#import "PINCache.h"
#import "StoriesCollection.h"
#import "NSNull+JSON.h"
#import "UISearchBar+Field.h"
#import "MenuViewController.h"
#import "StoryTitleAttributedString.h"
#import "NewsBlur-Swift.h"

#define kTableViewRowHeight 60;
#define kTableViewRiverRowHeight 90;
#define kTableViewShortRowDifference 14;

typedef NS_ENUM(NSUInteger, MarkReadShowMenu)
{
    MarkReadShowMenuNever = 0,
    MarkReadShowMenuBasedOnPref,
    MarkReadShowMenuAlways
};

typedef NS_ENUM(NSUInteger, FeedSection)
{
    FeedSectionBefore = 0,
    FeedSectionSelected,
    FeedSectionAfter,
    FeedSectionLoading
};

@interface FeedDetailObjCViewController ()

@property (nonatomic) NSInteger oldLocation;
@property (nonatomic) NSUInteger scrollingMarkReadRow;
@property (readwrite) BOOL inPullToRefresh_;
@property (nonatomic) BOOL isFadingTable;
@property (nonatomic, strong) NSString *restoringFolder;
@property (nonatomic, strong) NSString *restoringFeedID;
@property (nonatomic) NSUInteger deferredLoadStoryCount;
@property (nonatomic, strong) NSTimer *markStoryReadTimer;
@property (nonatomic, strong) UIView *notifierContainer;
@property (nonatomic, strong) UIPanGestureRecognizer *feedListSwipeGesture;
@property (nonatomic, strong) UIPanGestureRecognizer *fullScreenPopGesture;
@property (nonatomic) CGFloat feedListRevealWidth;
@property (nonatomic) BOOL feedListRevealActive;
@property (nonatomic) BOOL feedListRevealBouncing;
@property (nonatomic, strong) UIView *feedListRevealContainer;
@property (nonatomic, strong) UIBarButtonItem *sidebarBarButton;

@end

@implementation FeedDetailObjCViewController

@synthesize storyTitlesTable, feedMarkReadButton;
@synthesize settingsBarButton;
@synthesize titleImageBarButton;
@synthesize pageFetching;
@synthesize pageFinished;
@synthesize finishedAnimatingIn;
@synthesize notifier;
@synthesize searchBar;
@synthesize isOnline;
@synthesize isShowingFetching;
@synthesize storiesCollection;
@synthesize showImagePreview;
@synthesize invalidateFontCache;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}
 
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(preferredContentSizeChanged:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishedLoadingFeedsNotification:) name:@"FinishedLoadingFeedsNotification" object:nil];
    
    self.dashboardIndex = -1;
    self.dashboardSingleMode = NO;
    
    self.storyTitlesTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.storyTitlesTable.separatorColor = UIColorFromRGB(0xE9E8E4);
    if (@available(iOS 15.0, *)) {
        self.storyTitlesTable.allowsFocus = NO;
    }
    if (!self.isPhone) {
        self.storyTitlesTable.dragDelegate = self;
        self.storyTitlesTable.dragInteractionEnabled = YES;
    }
    self.view.backgroundColor = UIColorFromRGB(0xf4f4f4);

#if !TARGET_OS_MACCATALYST
    self.refreshControl = [UIRefreshControl new];
    self.refreshControl.tintColor = UIColorFromLightDarkRGB(0x0, 0xffffff);
    self.refreshControl.backgroundColor = UIColorFromRGB(0xE3E6E0);
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
#endif
    
    self.searchBar = [[UISearchBar alloc]
                 initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.storyTitlesTable.frame), 44.)];
    self.searchBar.delegate = self;
    [self.searchBar setReturnKeyType:UIReturnKeySearch];
    self.searchBar.backgroundColor = UIColorFromRGB(0xE3E6E0);
    self.searchBar.tintColor = UIColorFromRGB(0x0);
    self.searchBar.nb_searchField.textColor = UIColorFromRGB(0x0);
    [self.searchBar setSearchBarStyle:UISearchBarStyleMinimal];
    [self.searchBar setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    self.storyTitlesTable.tableHeaderView = self.searchBar;
    self.storyTitlesTable.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.storyTitlesTable.translatesAutoresizingMaskIntoConstraints = NO;
    self.messageView.translatesAutoresizingMaskIntoConstraints = NO;
//    self.view.translatesAutoresizingMaskIntoConstraints = NO; // No autolayout until UISplitViewController is built
    
    self.feedsBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Sites" style:UIBarButtonItemStylePlain target:self action:@selector(doShowFeeds:)];
    self.feedsBarButton.accessibilityLabel = @"Show Sites";
    
    UIImage *settingsImage = [Utilities imageNamed:@"settings" sized:self.isMac ? 24 : 30];
    settingsImage = [settingsImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    settingsBarButton = [UIBarButtonItem barItemWithImage:settingsImage target:self action:@selector(doOpenSettingsMenu:)];
    settingsBarButton.accessibilityLabel = @"Settings";
    
    UIImage *markreadImage = [Utilities imageNamed:@"mark-read" sized:self.isMac ? 24 : 30];
    markreadImage = [markreadImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    feedMarkReadButton = [UIBarButtonItem barItemWithImage:markreadImage target:self action:@selector(doOpenMarkReadMenu:)];
    feedMarkReadButton.accessibilityLabel = @"Mark all as read";
    
    UIView *view = [feedMarkReadButton valueForKey:@"view"];
    UILongPressGestureRecognizer *markReadLongPress = [[UILongPressGestureRecognizer alloc]
                                               initWithTarget:self action:@selector(handleMarkReadLongPress:)];
    markReadLongPress.minimumPressDuration = 1.0;
    markReadLongPress.delegate = self;
    [view addGestureRecognizer:markReadLongPress];
    
    titleImageBarButton = [UIBarButtonItem alloc];

    [self updateTheme];
    
#if TARGET_OS_MACCATALYST
    if (@available(macCatalyst 16.0, *)) {
        settingsBarButton.hidden = YES;
        feedMarkReadButton.hidden = YES;
    }
#else
    UILongPressGestureRecognizer *tableLongPress = [[UILongPressGestureRecognizer alloc]
                                               initWithTarget:self action:@selector(handleTableLongPress:)];
    tableLongPress.minimumPressDuration = 1.0;
    tableLongPress.delegate = self;
    [self.storyTitlesTable addGestureRecognizer:tableLongPress];
    
    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc]
                                                initWithTarget:self action:nil];
    doubleTapGesture.numberOfTapsRequired = 2;
    [self.storyTitlesTable addGestureRecognizer:doubleTapGesture];
    doubleTapGesture.delegate = self;
#endif
    
    [[ThemeManager themeManager] addThemeGestureRecognizerToView:self.storyTitlesTable];
    
    self.notifierContainer = [[UIView alloc] init];
    self.notifierContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.notifierContainer.clipsToBounds = YES;
    self.notifierContainer.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.notifierContainer];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifierContainer attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view.safeAreaLayoutGuide attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifierContainer attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifierContainer attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0]];
    [self.notifierContainer addConstraint:[NSLayoutConstraint constraintWithItem:self.notifierContainer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:NOTIFIER_HEIGHT]];

    self.notifier = [[NBNotifier alloc] initWithTitle:@"Fetching stories..."];
    [self.notifierContainer addSubview:self.notifier];
    [self.notifierContainer addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.notifierContainer attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0]];
    [self.notifierContainer addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.notifierContainer attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
    [self.notifierContainer addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:NOTIFIER_HEIGHT]];
    self.notifier.topOffsetConstraint = [NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.notifierContainer attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];
    [self.notifierContainer addConstraint:self.notifier.topOffsetConstraint];
    [self.view bringSubviewToFront:self.notifierContainer];
    
    [self addKeyCommandWithInput:@"a" modifierFlags:UIKeyModifierShift action:@selector(doMarkAllRead:) discoverabilityTitle:@"Mark All as Read"];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    //    NSLog(@"Gesture double tap: %ld - %ld", touch.tapCount, gestureRecognizer.state);
    inDoubleTap = (touch.tapCount == 2);
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    //    NSLog(@"Gesture should multiple? %ld (%ld) - %d", gestureRecognizer.state, UIGestureRecognizerStateEnded, inDoubleTap);
    if (self.feedListSwipeGesture &&
        ((gestureRecognizer == self.feedListSwipeGesture && otherGestureRecognizer == self.storyTitlesTable.panGestureRecognizer) ||
         (otherGestureRecognizer == self.feedListSwipeGesture && gestureRecognizer == self.storyTitlesTable.panGestureRecognizer))) {
        return YES;
    }

    if (gestureRecognizer == self.feedListSwipeGesture || gestureRecognizer == self.fullScreenPopGesture) {
        return NO;
    }

    if (gestureRecognizer.state == UIGestureRecognizerStateEnded && inDoubleTap) {
        CGPoint p = [gestureRecognizer locationInView:self.storyTitlesTable];
        NSIndexPath *indexPath = [self.storyTitlesTable indexPathForRowAtPoint:p];
        NSDictionary *story = [self getStoryAtLocation:indexPath.row];
        if (!story) return YES;
        NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
        BOOL openOriginal = NO;
        BOOL showText = NO;
        BOOL markUnread = NO;
        BOOL saveStory = NO;
        if (gestureRecognizer.numberOfTouches == 2) {
            NSString *twoFingerTap = [preferences stringForKey:@"two_finger_double_tap"];
            if ([twoFingerTap isEqualToString:@"open_original_story"]) {
                openOriginal = YES;
            } else if ([twoFingerTap isEqualToString:@"show_original_text"]) {
                showText = YES;
            } else if ([twoFingerTap isEqualToString:@"mark_unread"]) {
                markUnread = YES;
            } else if ([twoFingerTap isEqualToString:@"save_story"]) {
                saveStory = YES;
            }
        } else if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPhone) {
            NSString *doubleTap = [preferences stringForKey:@"double_tap_story"];
            if ([doubleTap isEqualToString:@"open_original_story"]) {
                openOriginal = YES;
            } else if ([doubleTap isEqualToString:@"show_original_text"]) {
                showText = YES;
            } else if ([doubleTap isEqualToString:@"mark_unread"]) {
                markUnread = YES;
            } else if ([doubleTap isEqualToString:@"save_story"]) {
                saveStory = YES;
            }
        }
        if (openOriginal) {
            [appDelegate
             showOriginalStory:[NSURL URLWithString:[story objectForKey:@"story_permalink"]]];
        } else if (showText) {
            [appDelegate.storyDetailViewController fetchTextView];
        } else if (markUnread) {
            [storiesCollection toggleStoryUnread:story];
            [self reload];
        } else if (saveStory) {
            [storiesCollection toggleStorySaved:story];
            [self reload];
        }
        inDoubleTap = NO;
    }
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.feedListSwipeGesture || gestureRecognizer == self.fullScreenPopGesture) {
        if (gestureRecognizer == self.feedListSwipeGesture) {
            for (UITableViewCell *cell in self.storyTitlesTable.visibleCells) {
                if (cell.isEditing) {
                    return NO;
                }
            }
            UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
            CGPoint velocity = [pan velocityInView:self.view];
            if (velocity.x <= 0 || fabs(velocity.x) <= fabs(velocity.y)) {
                return NO;
            }
            return YES;
        }

        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint velocity = [pan velocityInView:self.view];
        if (velocity.x <= 0 || fabs(velocity.x) <= fabs(velocity.y)) {
            return NO;
        }

        UINavigationController *navController = self.navigationController ?: appDelegate.feedsNavigationController;
        return navController.viewControllers.count > 1;
    }

    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.feedListSwipeGesture) {
        NSString *className = NSStringFromClass([otherGestureRecognizer class]);
        if ([otherGestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]] ||
            [className containsString:@"Split"] ||
            [className containsString:@"Sidebar"] ||
            [className containsString:@"Reveal"]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (otherGestureRecognizer == self.feedListSwipeGesture) {
        return NO;
    }
    return NO;
}

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
    storiesCollection.inSearch = NO;
    storiesCollection.searchQuery = nil;
    storiesCollection.savedSearchQuery = nil;
    [self reloadStories];
}

- (void)searchBarSearchButtonClicked:(UISearchBar*) theSearchBar {
    [self.searchBar resignFirstResponder];
}

- (BOOL)disablesAutomaticKeyboardDismissal {
    return NO;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([searchText length]) {
        storiesCollection.inSearch = YES;
        storiesCollection.searchQuery = searchText;
        
        if (![searchText isEqualToString:storiesCollection.savedSearchQuery]) {
            storiesCollection.savedSearchQuery = nil;
        }
    } else {
        storiesCollection.inSearch = NO;
        storiesCollection.searchQuery = nil;
        storiesCollection.savedSearchQuery = nil;
    }
    
    [FeedDetailViewController cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadStories) object:nil];
    [self performSelector:@selector(reloadStories) withObject:nil afterDelay:1.0];
}

- (void)preferredContentSizeChanged:(NSNotification *)aNotification {
    appDelegate.fontDescriptorTitleSize = nil;

    [self reload];
}

- (void)updateTextSize {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *textSizePref = [userPreferences stringForKey:@"story_list_preview_text_size"];
    
    if ([textSizePref isEqualToString:@"short"]) {
        self.textSize = FeedDetailTextSizeShort;
    } else if ([textSizePref isEqualToString:@"medium"]) {
        self.textSize = FeedDetailTextSizeMedium;
    } else if ([textSizePref isEqualToString:@"long"]) {
        self.textSize = FeedDetailTextSizeLong;
    } else {
        self.textSize = FeedDetailTextSizeTitleOnly;
    }
}

//- (void)changedStoryHeight:(CGFloat)storyHeight {
//    @throw [NSException exceptionWithName:@"Missing changedStoryHeight implementation" reason:@"This is implemented in the Swift subclass, so should never reach here." userInfo:nil];
//}

- (void)loadingFeed {
    @throw [NSException exceptionWithName:@"Missing loadingFeed implementation" reason:@"This is implemented in the Swift subclass, so should never reach here." userInfo:nil];
}

- (void)changedLayout {
    @throw [NSException exceptionWithName:@"Missing changedLayout implementation" reason:@"This is implemented in the Swift subclass, so should never reach here." userInfo:nil];
}

- (void)reload {
    @throw [NSException exceptionWithName:@"Missing reload implementation" reason:@"This is implemented in the Swift subclass, so should never reach here." userInfo:nil];
}

- (void)reloadImmediately {
    @throw [NSException exceptionWithName:@"Missing reloadImmediately implementation" reason:@"This is implemented in the Swift subclass, so should never reach here." userInfo:nil];
}

- (void)reloadIndexPath:(NSIndexPath *)indexPath withRowAnimation:(UITableViewRowAnimation)rowAnimation {
    @throw [NSException exceptionWithName:@"Missing reloadIndexPath implementation" reason:@"This is implemented in the Swift subclass, so should never reach here." userInfo:nil];
}

- (void)doneDashboardChooseSite:(NSString *)riverId {
    @throw [NSException exceptionWithName:@"Missing doneDashboardChooseSite implementation" reason:@"This is implemented in the Swift subclass, so should never reach here." userInfo:nil];
}

- (void)reloadTable {
    if (self.isFadingTable) {
        return;
    }
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    [self updateTextSize];
    self.showImagePreview = ![[userPreferences stringForKey:@"story_list_preview_images_size"] isEqualToString:@"none"];
    
    appDelegate.fontDescriptorTitleSize = nil;
    self.scrollingMarkReadRow = NSNotFound;
    
    [self.storyTitlesTable reloadData];
    
    NSInteger location = storiesCollection.locationOfActiveStory;
    NSIndexPath *indexPath = [self indexPathForStoryLocation:location];
    
    if (indexPath && location >= 0 && self.view.window != nil) {
        [self tableView:self.storyTitlesTable selectRowAtIndexPath:indexPath animated:NO];
    }
}

- (void)reloadWithSizing {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    [self updateTextSize];
    self.showImagePreview = ![[userPreferences stringForKey:@"story_list_preview_images_size"] isEqualToString:@"none"];
    
    appDelegate.fontDescriptorTitleSize = nil;
    self.scrollingMarkReadRow = NSNotFound;
    
    [self reload];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [self reload];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
        [self setUserAvatarLayout:orientation];
        [self.notifier setNeedsLayout];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self checkScroll];
        NSLog(@"Feed detail did re-orient.");
    }];
}

- (void)updateSidebarButtonForDisplayMode:(UISplitViewControllerDisplayMode)displayMode {
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];

    UIBarButtonItem *sidebarButton = nil;
    BOOL shouldShowSidebarButton = (displayMode == UISplitViewControllerDisplayModeSecondaryOnly ||
                                    displayMode == UISplitViewControllerDisplayModeOneOverSecondary);
    if (!appDelegate.isPhone && !self.isMac && shouldShowSidebarButton) {
        if (!self.sidebarBarButton) {
            UIImage *sidebarImage = [UIImage systemImageNamed:@"sidebar.leading"];
            if (!sidebarImage) {
                sidebarImage = [UIImage systemImageNamed:@"sidebar.left"];
            }
            if (!sidebarImage) {
                sidebarImage = [UIImage imageNamed:@"columns_double.png"];
            }
            sidebarImage = [sidebarImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            self.sidebarBarButton = [[UIBarButtonItem alloc] initWithImage:sidebarImage
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(toggleFeeds:)];
            self.sidebarBarButton.accessibilityLabel = @"Sidebar";
        } else {
            self.sidebarBarButton.target = self;
            self.sidebarBarButton.action = @selector(toggleFeeds:);
        }
        sidebarButton = self.sidebarBarButton;
    }

    NSArray *items = sidebarButton ? @[sidebarButton, settingsBarButton, feedMarkReadButton]
                                   : @[settingsBarButton, feedMarkReadButton];

    if (appDelegate.isPhone) {
        appDelegate.detailViewController.feedDetailNavigationItem.rightBarButtonItems = items;
    } else {
        appDelegate.detailViewController.feedDetailNavigationItem.leftItemsSupplementBackButton = YES;
        appDelegate.detailViewController.feedDetailNavigationItem.leftBarButtonItems = items;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
#if TARGET_OS_MACCATALYST
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
#endif
    
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if (self.standardInteractivePopGestureDelegate == nil) {
        UINavigationController *navController = self.navigationController ?: appDelegate.feedsNavigationController;
        self.standardInteractivePopGestureDelegate = navController.interactivePopGestureRecognizer.delegate;
    }
    [self configureInteractivePopGesture];
    
    UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
    [self setUserAvatarLayout:orientation];
    self.finishedAnimatingIn = NO;
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    self.messageView.hidden = YES;
    
    [self updateTextSize];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    self.showImagePreview = ![[userPreferences stringForKey:@"story_list_preview_images_size"] isEqualToString:@"none"];
    
    if (storiesCollection == nil) {
        NSString *appOpening = [userPreferences stringForKey:@"app_opening"];
        
        if ([appOpening isEqualToString:@"feeds"] && !self.isPhone) {
            self.messageLabel.text = @"Select a feed to read";
            self.messageView.hidden = NO;
        }
    }

    [self updateTheme];
    
    [self updateSidebarButtonForDisplayMode:self.appDelegate.splitViewController.displayMode];
    
    // set center title
    if (self.isPhoneOrCompact &&
        !self.navigationItem.titleView) {
        self.navigationItem.titleView = [appDelegate makeFeedTitle:storiesCollection.activeFeed];
    }
    
    if ([storiesCollection.activeFeedStories count]) {
        [self reload];
    }
    
    appDelegate.originalStoryCount = (int)[appDelegate unreadCount];
    self.scrollingMarkReadRow = NSNotFound;
    
    if ((storiesCollection.isSocialRiverView ||
         storiesCollection.isSocialView)) {
        settingsBarButton.enabled = NO;
    } else {
        settingsBarButton.enabled = YES;
    }
    
    if (self.isDashboard ||
        storiesCollection.isSocialRiverView ||
        storiesCollection.isSavedView ||
        storiesCollection.isReadView) {
        feedMarkReadButton.enabled = NO;
    } else {
        feedMarkReadButton.enabled = YES;
    }
    
    [self cancelMarkStoryReadTimer];
    
    [self.notifier setNeedsLayout];
    
    if (storiesCollection.inSearch && storiesCollection.searchQuery) {
        [self.searchBar setText:storiesCollection.searchQuery];
        [self.storyTitlesTable setContentOffset:CGPointMake(0, 0)];
        if (storiesCollection.savedSearchQuery == nil) {
            [self.searchBar becomeFirstResponder];
        }
    } else {
        [self.searchBar setText:@""];
    }
    if ([self.searchBar.text length]) {
        [self.searchBar setShowsCancelButton:YES animated:YES];
    } else {
        [self.searchBar setShowsCancelButton:NO animated:YES];
    }
    
#if !TARGET_OS_MACCATALYST
    if (self.canPullToRefresh) {
        self.storyTitlesTable.refreshControl = self.refreshControl;
    } else {
        self.storyTitlesTable.refreshControl = nil;
    }
#endif
    
    [self updateTheme];
    
    if (self.isPhoneOrCompact) {
        // Async to let the view be added to the view hierarchy.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fadeSelectedCell:NO];
        });
    }
    
    if (storiesCollection.activeFeed != nil) {
        [appDelegate donateFeed];
    } else if (storiesCollection.activeFolder != nil) {
        [appDelegate donateFolder];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self configureInteractivePopGesture];
    [self setupStoryTitlesSwipeGestures];
    
    if (appDelegate.inStoryDetail && self.isPhoneOrCompact) {
        appDelegate.inStoryDetail = NO;
        [self checkScroll];
    }
    
    if (invalidateFontCache) {
        invalidateFontCache = NO;
        [self reloadWithSizing];
    }
    
    self.finishedAnimatingIn = YES;
    if ([storiesCollection.activeFeedStories count]) {
        [self reload];
    }
    
    if (self.isPhoneOrCompact) {
        [self fadeSelectedCell:YES];
    }
    
    [self.notifier setNeedsLayout];
    
    [self testForTryFeed];
}

- (void)configureInteractivePopGesture {
    if (!self.isPhoneOrCompact) {
        return;
    }

    UINavigationController *navController = self.navigationController ?: appDelegate.feedsNavigationController;
    if (!navController || !navController.interactivePopGestureRecognizer) {
        return;
    }

    if (self.standardInteractivePopGestureDelegate == nil) {
        self.standardInteractivePopGestureDelegate = navController.interactivePopGestureRecognizer.delegate;
    }

    navController.interactivePopGestureRecognizer.enabled = YES;
    navController.interactivePopGestureRecognizer.delegate = self.standardInteractivePopGestureDelegate;

    if (self.storyTitlesTable.panGestureRecognizer) {
        [self.storyTitlesTable.panGestureRecognizer requireGestureRecognizerToFail:navController.interactivePopGestureRecognizer];
    }
}

- (void)setupStoryTitlesSwipeGestures {
    if (self.storyTitlesTable) {
        self.storyTitlesTable.alwaysBounceHorizontal = NO;
    }

    if (self.isPhoneOrCompact) {
        [self configureFullScreenPopGesture];
        return;
    }

    if (appDelegate.splitViewController &&
        [appDelegate.splitViewController respondsToSelector:@selector(setPresentsWithGesture:)]) {
        appDelegate.splitViewController.presentsWithGesture = NO;
    }
    
    if (appDelegate.splitViewController) {
        UIView *splitView = appDelegate.splitViewController.view;
        for (UIGestureRecognizer *gesture in splitView.gestureRecognizers) {
            NSString *className = NSStringFromClass([gesture class]);
            if ([gesture isKindOfClass:[UIScreenEdgePanGestureRecognizer class]] ||
                [className containsString:@"Split"] ||
                [className containsString:@"Sidebar"] ||
                [className containsString:@"Reveal"]) {
                gesture.enabled = NO;
            }
        }
        UIView *splitSuperview = splitView.superview;
        if (splitSuperview) {
            for (UIGestureRecognizer *gesture in splitSuperview.gestureRecognizers) {
                NSString *className = NSStringFromClass([gesture class]);
                if ([gesture isKindOfClass:[UIScreenEdgePanGestureRecognizer class]] ||
                    [className containsString:@"Split"] ||
                    [className containsString:@"Sidebar"] ||
                    [className containsString:@"Reveal"]) {
                    gesture.enabled = NO;
                }
            }
        }
    }

    if (self.feedListSwipeGesture != nil) {
        return;
    }

    self.feedListSwipeGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleFeedListSwipe:)];
    self.feedListSwipeGesture.delegate = self;
    self.feedListSwipeGesture.maximumNumberOfTouches = 1;
#if TARGET_OS_MACCATALYST
    // On Mac, trackpad two-finger swipes generate scroll events, not direct touch events.
    // Allow the pan gesture to respond to trackpad scroll gestures.
    self.feedListSwipeGesture.allowedScrollTypesMask = UIScrollTypeMaskAll;
#endif
    [self.view addGestureRecognizer:self.feedListSwipeGesture];
}

- (void)configureFullScreenPopGesture {
    if (self.fullScreenPopGesture != nil) {
        return;
    }

    UINavigationController *navController = self.navigationController ?: appDelegate.feedsNavigationController;
    if (!navController || !navController.interactivePopGestureRecognizer) {
        return;
    }

    NSArray *targets = [navController.interactivePopGestureRecognizer valueForKey:@"_targets"];
    id internalTarget = [targets firstObject];
    id target = [internalTarget valueForKey:@"target"];
    SEL action = NSSelectorFromString(@"handleNavigationTransition:");
    if (!target || ![target respondsToSelector:action]) {
        return;
    }

    self.fullScreenPopGesture = [[UIPanGestureRecognizer alloc] initWithTarget:target action:action];
    self.fullScreenPopGesture.delegate = self;
    [self.view addGestureRecognizer:self.fullScreenPopGesture];

    navController.interactivePopGestureRecognizer.enabled = NO;

    if (self.storyTitlesTable.panGestureRecognizer) {
        [self.storyTitlesTable.panGestureRecognizer requireGestureRecognizerToFail:self.fullScreenPopGesture];
    }
}

- (UIView *)feedListRevealContainerForSplitView:(SplitViewController *)splitViewController {
    if (!splitViewController || !appDelegate.feedsNavigationController) {
        return nil;
    }

    UIView *feedsView = appDelegate.feedsNavigationController.view;
    if (!feedsView) {
        return nil;
    }

    CGFloat splitWidth = CGRectGetWidth(splitViewController.view.bounds);
    UIView *candidate = feedsView;
    UIView *bestMatch = feedsView;

    while (candidate) {
        CGFloat width = CGRectGetWidth(candidate.bounds);
        if (width > 1.0f && splitWidth > 1.0f && width < splitWidth - 1.0f) {
            bestMatch = candidate;
        }

        if (candidate.superview == nil || candidate.superview == splitViewController.view) {
            break;
        }

        candidate = candidate.superview;
    }

    return bestMatch ?: feedsView;
}

- (void)handleFeedListSwipe:(UIPanGestureRecognizer *)gestureRecognizer {
    SplitViewController *splitViewController = appDelegate.splitViewController;
    if (!splitViewController || !appDelegate.feedsNavigationController) {
        return;
    }

    UIView *feedsView = appDelegate.feedsNavigationController.view;
    UIView *primaryContainer = feedsView.superview ?: feedsView;
    CGFloat revealWidth = self.feedListRevealWidth;
    if (revealWidth <= 0) {
        if (splitViewController.isFeedsListHidden) {
            revealWidth = [[NSUserDefaults standardUserDefaults] floatForKey:@"split_primary_width"];
        } else {
            revealWidth = splitViewController.primaryColumnWidth;
        }
    }
    if (revealWidth <= 0) {
        revealWidth = CGRectGetWidth(primaryContainer.bounds);
    }
    if (revealWidth <= 0) {
        revealWidth = 320.0;
    }

    CGPoint translation = [gestureRecognizer translationInView:self.view];
    BOOL isHorizontal = fabs(translation.x) > fabs(translation.y);

    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan: {
            self.feedListRevealActive = NO;
            self.feedListRevealBouncing = NO;
            self.feedListRevealWidth = revealWidth;
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (!self.feedListRevealActive) {
                if (!isHorizontal || translation.x <= 0) {
                    break;
                }

                self.feedListRevealActive = YES;
                self.feedListRevealWidth = revealWidth;
                self.storyTitlesTable.scrollEnabled = NO;

                if (splitViewController &&
                    [splitViewController respondsToSelector:@selector(setPresentsWithGesture:)]) {
                    splitViewController.presentsWithGesture = NO;
                }

                if (splitViewController) {
                    UIView *splitView = splitViewController.view;
                    for (UIGestureRecognizer *gesture in splitView.gestureRecognizers) {
                        NSString *className = NSStringFromClass([gesture class]);
                        if ([gesture isKindOfClass:[UIScreenEdgePanGestureRecognizer class]] ||
                            [className containsString:@"Split"] ||
                            [className containsString:@"Sidebar"] ||
                            [className containsString:@"Reveal"]) {
                            gesture.enabled = NO;
                        }
                    }
                }

                if (splitViewController.isFeedsListHidden) {
                    [UIView performWithoutAnimation:^{
                        splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeOneOverSecondary;
                        [splitViewController showColumn:UISplitViewControllerColumnPrimary];
                        [splitViewController.view layoutIfNeeded];
                    }];

                    UIView *container = [self feedListRevealContainerForSplitView:splitViewController];
                    if (!container) {
                        container = primaryContainer;
                    }

                    CGFloat targetWidth = CGRectGetMaxX(container.frame);
                    if (targetWidth <= 0) {
                        targetWidth = CGRectGetWidth(container.bounds);
                    }
                    if (targetWidth <= 0) {
                        targetWidth = revealWidth;
                    }
                    if (targetWidth <= 0) {
                        targetWidth = 320.0;
                    }

                    self.feedListRevealWidth = targetWidth;
                    self.feedListRevealContainer = container;
                    container.transform = CGAffineTransformMakeTranslation(-targetWidth, 0);
                } else {
                    self.feedListRevealBouncing = YES;
                }
            }

            if (self.feedListRevealActive) {
                CGFloat effectiveRevealWidth = self.feedListRevealWidth > 0 ? self.feedListRevealWidth : revealWidth;
                CGFloat clampedTranslation = MAX(0.0, MIN(translation.x, effectiveRevealWidth));
                if (self.feedListRevealBouncing) {
                    CGFloat bounceTranslation = MIN(clampedTranslation, 60.0) * 0.2;
                    self.view.transform = CGAffineTransformMakeTranslation(bounceTranslation, 0);
                } else {
                    UIView *container = self.feedListRevealContainer ?: primaryContainer;
                    container.transform = CGAffineTransformMakeTranslation(-effectiveRevealWidth + clampedTranslation, 0);
                }
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (!self.feedListRevealActive) {
                break;
            }

            if (self.feedListRevealBouncing) {
                [UIView animateWithDuration:0.2
                                      delay:0
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:^{
                    self.view.transform = CGAffineTransformIdentity;
                } completion:^(__unused BOOL finished) {
                    self.feedListRevealActive = NO;
                    self.feedListRevealBouncing = NO;
                    self.storyTitlesTable.scrollEnabled = YES;
                }];
                break;
            }

            CGFloat effectiveRevealWidth = self.feedListRevealWidth > 0 ? self.feedListRevealWidth : revealWidth;
            CGFloat clampedTranslation = MAX(0.0, MIN(translation.x, effectiveRevealWidth));
            CGPoint velocity = [gestureRecognizer velocityInView:self.view];
            BOOL shouldOpen = (clampedTranslation > effectiveRevealWidth * 0.33f) || (velocity.x > 800.0f);

            UIView *container = self.feedListRevealContainer ?: primaryContainer;

            [UIView animateWithDuration:0.2
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                container.transform = shouldOpen ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(-effectiveRevealWidth, 0);
            } completion:^(__unused BOOL finished) {
                if (shouldOpen) {
                    [UIView performWithoutAnimation:^{
                        splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeOneOverSecondary;
                        [splitViewController showColumn:UISplitViewControllerColumnPrimary];
                        [splitViewController.view layoutIfNeeded];
                    }];
                } else {
                    [UIView performWithoutAnimation:^{
                        [splitViewController showColumn:UISplitViewControllerColumnSecondary];
                        [splitViewController.view layoutIfNeeded];
                    }];
                }
                container.transform = CGAffineTransformIdentity;
                self.feedListRevealContainer = nil;
                self.feedListRevealActive = NO;
                self.feedListRevealBouncing = NO;
                self.storyTitlesTable.scrollEnabled = YES;
            }];
            break;
        }
        default:
            break;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.searchBar resignFirstResponder];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self.searchBar resignFirstResponder];
    [self.appDelegate hidePopoverAnimated:YES];
    
    if (self.isMovingToParentViewController) {
        appDelegate.inFindingStoryMode = NO;
        appDelegate.findingStoryStartDate = nil;
        appDelegate.findingStoryDictionary = nil;
        appDelegate.tryFeedStoryId = nil;
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }
}

- (void)fadeSelectedCell {
    [self fadeSelectedCell:YES];
}

- (void)fadeSelectedCell:(BOOL)deselect {
    if (self.isLegacyTable) {
        [self reloadTable];
        
        NSInteger location = storiesCollection.locationOfActiveStory;
        NSIndexPath *indexPath = [self indexPathForStoryLocation:location];
        
        if (indexPath && location >= 0 && self.view.window != nil) {
            [self tableView:self.storyTitlesTable selectRowAtIndexPath:indexPath animated:NO];
            if (deselect) {
                self.isFadingTable = YES;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,  0.1 * NSEC_PER_SEC),
                               dispatch_get_main_queue(), ^(void) {
                    [self tableView:self.storyTitlesTable deselectRowAtIndexPath:indexPath animated:YES];
                    self.isFadingTable = NO;
                });
            }
        }
    } else {
        [self reload];
    }
    
    if (deselect) {
        appDelegate.activeStory = nil;
    }
}

- (void)setUserAvatarLayout:(UIInterfaceOrientation)orientation {
    if (self.isPhoneOrCompact && storiesCollection.isSocialView) {
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            NBBarButtonItem *avatar = (NBBarButtonItem *)titleImageBarButton.customView;
            CGRect buttonFrame = avatar.frame;
            buttonFrame.size = CGSizeMake(32, 32);
            avatar.frame = buttonFrame;
        } else {
            NBBarButtonItem *avatar = (NBBarButtonItem *)titleImageBarButton.customView;
            CGRect buttonFrame = avatar.frame;
            buttonFrame.size = CGSizeMake(28, 28);
            avatar.frame = buttonFrame;
        }
    }
}

- (BOOL)isPhoneOrCompact {
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone || self.appDelegate.isCompactWidth;
}

#pragma mark -
#pragma mark State Restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    
    [coder encodeObject:appDelegate.storiesCollection.activeFolder forKey:@"folder"];
    
    if (appDelegate.storiesCollection.activeFeed != nil) {
        [coder encodeObject:[NSString stringWithFormat:@"%@", appDelegate.storiesCollection.activeFeed[@"id"]] forKey:@"feed_id"];
    }
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    
    NSString *folder = [coder decodeObjectOfClass:[NSString class] forKey:@"folder"];
    NSString *feedID = [coder decodeObjectOfClass:[NSString class] forKey:@"feed_id"];
    
    if (folder != nil || feedID != nil) {
        self.restoringFolder = folder;
        self.restoringFeedID = feedID;
    }
}

- (void)finishedLoadingFeedsNotification:(NSNotification *)notification {
    if (self.restoringFeedID.length > 0) {
        NSDictionary *feed = [appDelegate getFeed:self.restoringFeedID];
        BOOL isSocial = [appDelegate isSocialFeed:self.restoringFeedID];
        
        if (feed != nil) {
            appDelegate.storiesCollection.isSocialView = isSocial;
            appDelegate.storiesCollection.activeFeed = feed;
            [appDelegate loadFeedDetailView:NO];
            [self viewWillAppear:NO];
        }
    } else if (self.restoringFolder.length > 0) {
        NSString *folder = self.restoringFolder;
        NSInteger index = [appDelegate.dictFoldersArray indexOfObject:folder];
        
        if (index != NSNotFound && index > NewsBlurTopSectionAllStories) {
            folder = [NSString stringWithFormat:@"%@", @(index)];
        }
        
        [appDelegate loadRiverFeedDetailView:(FeedDetailViewController *)self withFolder:folder];
        [self viewWillAppear:NO];
    }
    
    self.restoringFolder = nil;
    self.restoringFeedID = 0;
}

#pragma mark -
#pragma mark Siri Shortcuts

- (void)gotoFolder:(NSString *)folder feedID:(NSString *)feedID {
    self.restoringFolder = folder;
    self.restoringFeedID = feedID;
}

#pragma mark -
#pragma mark Initialization

- (void)resetFeedDetail {
    appDelegate.hasLoadedFeedDetail = NO;
    self.navigationItem.titleView = nil;
    self.pageFetching = NO;
    self.pageFinished = NO;
    self.dashboardAwaitingFinish = YES;
    self.isOnline = YES;
    self.isShowingFetching = NO;
    self.cameFromFeedsList = YES;
    self.scrollingMarkReadRow = NSNotFound;
    appDelegate.activeStory = nil;
    [storiesCollection setStories:nil];
    [storiesCollection setFeedUserProfiles:nil];
    storiesCollection.storyCount = 0;
    [appDelegate.storyPagesViewController resetPages];
    [appDelegate.storyPagesViewController hidePages];
    
    if (appDelegate.isDashboard) {
        storiesCollection.inSearch = appDelegate.storiesCollection.inSearch;
        storiesCollection.searchQuery = appDelegate.storiesCollection.searchQuery;
        storiesCollection.savedSearchQuery = appDelegate.storiesCollection.savedSearchQuery;
        [self.searchBar setText:storiesCollection.searchQuery ?: @""];
    } else {
        storiesCollection.inSearch = NO;
        storiesCollection.searchQuery = nil;
        storiesCollection.savedSearchQuery = nil;
        [self.searchBar setText:@""];
    }
    [self.notifier hideIn:0];
    [self beginOfflineTimer];
    [appDelegate.cacheImagesOperationQueue cancelAllOperations];
//    [self reload];
}

- (void)reloadStories {
    appDelegate.hasLoadedFeedDetail = NO;
    appDelegate.activeStory = nil;
    [storiesCollection setStories:nil];
    [storiesCollection setFeedUserProfiles:nil];
    storiesCollection.storyCount = 0;
    storiesCollection.activeClassifiers = [NSMutableDictionary dictionary];
    storiesCollection.activePopularAuthors = [NSArray array];
    storiesCollection.activePopularTags = [NSArray array];
    self.pageFetching = NO;
    self.pageFinished = NO;
    self.dashboardAwaitingFinish = YES;
    self.isOnline = YES;
    self.isShowingFetching = NO;
    
    if (storiesCollection.isRiverView) {
        [self fetchRiverPage:1 withCallback:nil];
    } else {
        [self fetchFeedDetail:1 withCallback:nil];
    }
    
    [self reload];
    
    if (self.isLegacyTable) {
        [storyTitlesTable scrollRectToVisible:CGRectMake(0, CGRectGetHeight(self.searchBar.frame), 1, 1) animated:YES];
    }
}

- (void)beginOfflineTimer {
    if (self.storiesCollection.isInfrequent) {
        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!self.storiesCollection.storyLocationsCount && !self.pageFinished &&
            self.storiesCollection.feedPage == 1 && self.isOnline) {
            self.isShowingFetching = YES;
            self.isOnline = NO;
            [self showLoadingNotifier];
            [self loadOfflineStories];
        }
    });
}

- (void)cacheImagesForStories:(NSArray *)stories {
    NSBlockOperation *cacheImagesOperation = [NSBlockOperation blockOperationWithBlock:^{
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        [manager.requestSerializer setTimeoutInterval:5];
        manager.responseSerializer = [AFImageResponseSerializer serializer];
        
        for (NSDictionary *story in stories) {
            NSString *storyHash = story[@"story_hash"];
            NSArray *imageURLs = story[@"image_urls"];
            [self.appDelegate cacheStoryImagePlaceholder:storyHash];
            [self getFirstImage:imageURLs forStoryHash:storyHash withManager:manager];
        }
    }];
    [cacheImagesOperation setQualityOfService:NSQualityOfServiceBackground];
    [cacheImagesOperation setQueuePriority:NSOperationQueuePriorityVeryLow];
    [appDelegate.cacheImagesOperationQueue addOperation:cacheImagesOperation];
}

- (void)getFirstImage:(NSArray *)storyImageUrls forStoryHash:(NSString *)storyHash withManager:(AFHTTPSessionManager *)manager {
    NSString *storyImageUrl = [[storyImageUrls firstObject] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    if (storyImageUrl == nil) {
        return;
    }
    
    if ([storyImageUrl hasPrefix:@"http://data:image"]) {
        return;
    }
    
    [manager GET:storyImageUrl parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0ul);
        dispatch_async(queue, ^{
            UIImage *image = (UIImage *)responseObject;
            
            if (!image || image.size.height < 50 || image.size.width < 50) {
                if (storyImageUrls.count > 1) {
                    NSArray *remainingImageUrls = [storyImageUrls subarrayWithRange:NSMakeRange(1, storyImageUrls.count - 1)];
                    [self getFirstImage:remainingImageUrls forStoryHash:storyHash withManager:manager];
                }
                return;
            }
            
            CGSize maxImageSize = CGSizeMake(300, 300);
            image = [image imageByScalingAndCroppingForSize:maxImageSize];
            [self.appDelegate cacheStoryImage:image forStoryHash:storyHash];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showImageForStoryHash:storyHash];
            });
        });
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"getFirstImage for %@ error: %@", storyHash, error);  // log
        
        if (storyImageUrls.count > 1) {
            NSArray *remainingImageUrls = [storyImageUrls subarrayWithRange:NSMakeRange(1, storyImageUrls.count - 1)];
            [self getFirstImage:remainingImageUrls forStoryHash:storyHash withManager:manager];
        }
    }];
}

- (void)showImageForStoryHash:(NSString *)storyHash {
    if (!self.isLegacyTable) {
        return;
    }
    
    if (self.view.window == nil) {
        NSLog(@"showImageForStoryHash when not in a window: %@", storyHash);  // log
        return;
    }
    
    for (FeedDetailTableCell *cell in [self.storyTitlesTable visibleCells]) {
        if (![cell isKindOfClass:[FeedDetailTableCell class]]) return;
        if ([cell.storyHash isEqualToString:storyHash]) {
            NSIndexPath *indexPath = [self.storyTitlesTable indexPathForCell:cell];
            NSInteger numberOfRows = [self.storyTitlesTable numberOfRowsInSection:0];
            
            NSLog(@"showImageForStoryHash for row %@ of %@", @(indexPath.row), @(numberOfRows));  // log
            
            if (indexPath.row >= numberOfRows) {
                NSLog(@"⚠️ row %@ is greater than the number of rows: %@", @(indexPath.row), @(numberOfRows));  // log
                continue;
            }
            
            if (indexPath.row > storiesCollection.storyLocationsCount) {
                NSLog(@"⚠️ row %@ is greater than the story locations count: %@", @(indexPath.row), @(storiesCollection.storyLocationsCount));  // log
                continue;
            }
            
            [self reloadIndexPath:indexPath withRowAnimation:UITableViewRowAnimationNone];
            break;
        }
    }
}

- (void)flashInfrequentStories {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSInteger infrequent = [prefs integerForKey:@"infrequent_stories_per_month"];
    [MBProgressHUD hideHUDForView:self.storyTitlesTable animated:NO];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.removeFromSuperViewOnHide = YES;
    
    hud.labelText = [NSString stringWithFormat:@"< %ld stories/month", (long)infrequent];;
    
    [hud hide:YES afterDelay:0.5];
}

#pragma mark -
#pragma mark Regular and Social Feeds

- (void)fetchNextPage:(void(^)(void))callback {
    if (storiesCollection.isRiverView) {
        [self fetchRiverPage:storiesCollection.feedPage+1 withCallback:callback];
    } else {
        [self fetchFeedDetail:storiesCollection.feedPage+1 withCallback:callback];
    }
}

- (void)fetchFeedDetail:(int)page withCallback:(void(^)(void))callback {
    NSString *theFeedDetailURL;
    
    if (!storiesCollection.activeFeed) return;
    
    if (!callback && (self.pageFetching || self.pageFinished)) return;
    
    storiesCollection.feedPage = page;
    self.pageFetching = YES;
    NSInteger storyCount = storiesCollection.storyCount;
    if (storyCount == 0) {
        [self reload];
        if (self.isLegacyTable) {
            [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
        }
    }
    if (storiesCollection.feedPage == 1) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                 (unsigned long)NULL), ^(void) {
            [self.appDelegate.database inDatabase:^(FMDatabase *db) {
                [self.appDelegate prepareActiveCachedImages:db];
            }];
        });
    }
    if (self.isLegacyTable && !storiesCollection.inSearch && storiesCollection.feedPage == 1) {
        [self.storyTitlesTable setContentOffset:CGPointMake(0, CGRectGetHeight(self.searchBar.frame))];
    }
    
    if (!self.isOnline) {
        [self loadOfflineStories];
        if (!self.isShowingFetching) {
            [self showOfflineNotifier];
        }
        return;
    } else {
        [self.notifier hide];
    }
    
    if (storiesCollection.isSocialView) {
        theFeedDetailURL = [NSString stringWithFormat:@"%@/social/stories/%@/?page=%d",
                            self.appDelegate.url,
                            [storiesCollection.activeFeed objectForKey:@"user_id"],
                            storiesCollection.feedPage];
    } else if (storiesCollection.isSavedView) {
        theFeedDetailURL = [NSString stringWithFormat:
                            @"%@/reader/starred_stories/?page=%d&v=2&tag=%@",
                            self.appDelegate.url,
                            storiesCollection.feedPage,
                            [storiesCollection.activeSavedStoryTag urlEncode]];
    } else if (storiesCollection.isReadView) {
        theFeedDetailURL = [NSString stringWithFormat:
                            @"%@/reader/read_stories/?page=%d&v=2",
                            self.appDelegate.url,
                            storiesCollection.feedPage];
    } else {
        theFeedDetailURL = [NSString stringWithFormat:@"%@/reader/feed/%@/?include_hidden=true&page=%d",
                            self.appDelegate.url,
                            [storiesCollection.activeFeed objectForKey:@"id"],
                            storiesCollection.feedPage];
    }
    
    theFeedDetailURL = [NSString stringWithFormat:@"%@&order=%@",
                        theFeedDetailURL,
                        [storiesCollection activeOrder]];
    theFeedDetailURL = [NSString stringWithFormat:@"%@&read_filter=%@",
                        theFeedDetailURL,
                        [storiesCollection activeReadFilter]];
    if (storiesCollection.inSearch && storiesCollection.searchQuery) {
        theFeedDetailURL = [NSString stringWithFormat:@"%@&query=%@",
                            theFeedDetailURL,
                            [storiesCollection.searchQuery stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]];
    }
    
    NSString *feedId = [NSString stringWithFormat:@"%@", [[storiesCollection activeFeed] objectForKey:@"id"]];
    NSInteger feedPage = storiesCollection.feedPage;
    NSLog(@" ---> Loading feed url: %@", theFeedDetailURL);
    [appDelegate GET:theFeedDetailURL parameters:nil success:^(NSURLSessionTask *task, id responseObject) {
        NSLog(@"success");  // log
        if (!self.storiesCollection.activeFeed) return;
        [self finishedLoadingFeed:responseObject feedPage:feedPage feedId:feedId];
        if (callback) {
            callback();
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)operation.response;
        NSLog(@"in failed block %@", operation);
        self.isOnline = NO;
        self.isShowingFetching = NO;
        //            storiesCollection.feedPage = 1;
        [self loadOfflineStories];
        [self showOfflineNotifier];
        if (httpResponse.statusCode == 503) {
            [self informError:@"In maintenance mode"];
            self.pageFinished = YES;
        } else if (httpResponse.statusCode >= 500) {
            [self informError:@"The server barfed."];
        }
        
        [self reload];
    }];
}

- (void)loadOfflineStories {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [self.appDelegate.database inDatabase:^(FMDatabase *db) {
            NSArray *feedIds;
            NSInteger limit = 12;
            NSInteger offset = (self.storiesCollection.feedPage - 1) * limit;
            
            if (self.storiesCollection.isRiverView) {
                feedIds = self.storiesCollection.activeFolderFeeds;
            } else if (self.storiesCollection.activeFeed) {
                feedIds = @[[self.storiesCollection.activeFeed objectForKey:@"id"]];
            } else {
                return;
            }
            
            NSString *orderSql;
            if ([self.storiesCollection.activeOrder isEqualToString:@"oldest"]) {
                orderSql = @"ASC";
            } else {
                orderSql = @"DESC";
            }
            NSString *readFilterSql;
            if ([self.storiesCollection.activeReadFilter isEqualToString:@"unread"]) {
                readFilterSql = @"INNER JOIN unread_hashes uh ON s.story_hash = uh.story_hash";
            } else {
                readFilterSql = @"";
            }
            NSString *sql = [NSString stringWithFormat:@"SELECT * FROM stories s %@ WHERE s.story_feed_id IN (%@) ORDER BY s.story_timestamp %@ LIMIT %ld OFFSET %ld",
                             readFilterSql,
                             [feedIds componentsJoinedByString:@","],
                             orderSql,
                             (long)limit, (long)offset];
            FMResultSet *cursor = [db executeQuery:sql];
            NSMutableArray *offlineStories = [NSMutableArray array];
            
            while ([cursor next]) {
                NSDictionary *story = [cursor resultDictionary];
                [offlineStories addObject:[NSJSONSerialization
                                           JSONObjectWithData:[[story objectForKey:@"story_json"]
                                                               dataUsingEncoding:NSUTF8StringEncoding]
                                           options:0 error:nil]];
            }
            [cursor close];
            
            if ([self.storiesCollection.activeReadFilter isEqualToString:@"all"]) {
                NSString *unreadHashSql = [NSString stringWithFormat:@"SELECT s.story_hash FROM stories s INNER JOIN unread_hashes uh ON s.story_hash = uh.story_hash WHERE s.story_feed_id IN (%@)",
                                           [feedIds componentsJoinedByString:@","]];
                FMResultSet *unreadHashCursor = [db executeQuery:unreadHashSql];
                NSMutableDictionary *unreadStoryHashes;
                if (self.storiesCollection.feedPage == 1) {
                    unreadStoryHashes = [NSMutableDictionary dictionary];
                } else {
                    unreadStoryHashes = self.appDelegate.unreadStoryHashes;
                }
                while ([unreadHashCursor next]) {
                    [unreadStoryHashes setObject:[NSNumber numberWithBool:YES] forKey:[unreadHashCursor objectForColumnName:@"story_hash"]];
                }
                self.appDelegate.unreadStoryHashes = unreadStoryHashes;
                [unreadHashCursor close];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.isOnline) {
                    NSLog(@"Online before offline rendered. Tossing offline stories.");
                    return;
                }
                if (![offlineStories count]) {
                    self.pageFinished = YES;
                    [self reload];
                } else {
                    [self renderStories:offlineStories];
                }
                if (!self.isShowingFetching) {
                    [self showOfflineNotifier];
                }
            });
        }];
    });
}

- (void)showOfflineNotifier {
    self.notifier.style = NBOfflineStyle;
    self.notifier.title = @"Offline";
    [self.notifier show];
}

- (void)showLoadingNotifier {
    self.notifier.style = NBLoadingStyle;
    self.notifier.title = @"Fetching recent stories...";
    [self.notifier show];
}

#pragma mark -
#pragma mark River of News

- (void)fetchRiver {
    [self fetchRiverPage:storiesCollection.feedPage withCallback:nil];
}

- (void)fetchRiverPage:(int)page withCallback:(void(^)(void))callback {
    if (self.pageFetching || self.pageFinished) return;
    //    NSLog(@"Fetching River in storiesCollection (pg. %ld): %@", (long)page, storiesCollection);
    
    [self loadingFeed];
    
    if ([storiesCollection.activeFolder isEqualToString:@"dashboard"]) {
        NSLog(@"⚠️ Called fetchRiverPage with dashboard; this should never occur");  // log
        return;
    }
    
    storiesCollection.feedPage = page;
    self.pageFetching = YES;
    NSInteger storyCount = storiesCollection.storyCount;
    if (storyCount == 0) {
        self.messageView.hidden = YES;
        [self reload];
        if (self.isLegacyTable) {
            [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, CGRectGetHeight(self.searchBar.frame), 1) animated:YES];
        }
    }
    
    if (self.isLegacyTable && !storiesCollection.inSearch && storiesCollection.feedPage == 1) {
        [self.storyTitlesTable setContentOffset:CGPointMake(0, CGRectGetHeight(self.searchBar.frame))];
    }
    
    if (storiesCollection.feedPage == 1) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                 (unsigned long)NULL), ^(void) {
            [self.appDelegate.database inDatabase:^(FMDatabase *db) {
                [self.appDelegate prepareActiveCachedImages:db];
            }];
        });
    }
    
    if (!self.isOnline) {
        [self.notifier hide];
        [self loadOfflineStories];
        return;
    } else {
        [self.notifier hide];
    }
    
    NSString *theFeedDetailURL;
    
    if (storiesCollection.isSocialRiverView) {
        if ([storiesCollection.activeFolder isEqualToString:@"river_global"]) {
            theFeedDetailURL = [NSString stringWithFormat:
                                @"%@/social/river_stories/?global_feed=true&page=%d",
                                self.appDelegate.url,
                                storiesCollection.feedPage];
            
        } else {
            theFeedDetailURL = [NSString stringWithFormat:
                                @"%@/social/river_stories/?page=%d",
                                self.appDelegate.url,
                                storiesCollection.feedPage];
        }
    } else if (storiesCollection.isSavedView) {
        theFeedDetailURL = [NSString stringWithFormat:
                            @"%@/reader/starred_stories/?page=%d&v=2",
                            self.appDelegate.url,
                            storiesCollection.feedPage];
    } else if (storiesCollection.isReadView) {
        theFeedDetailURL = [NSString stringWithFormat:
                            @"%@/reader/read_stories/?page=%d&v=2",
                            self.appDelegate.url,
                            storiesCollection.feedPage];
    } else {
        NSString *feeds = @"";
        if (storiesCollection.activeFolderFeeds.count) {
            feeds = [[storiesCollection.activeFolderFeeds
                      subarrayWithRange:NSMakeRange(0, MIN(storiesCollection.activeFolderFeeds.count, 800))]
                     componentsJoinedByString:@"&f="];
        }
        NSString *infrequent = @"false";
        if ([storiesCollection.activeFolder isEqualToString:@"infrequent"]) {
            NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
            infrequent = [NSString stringWithFormat:@"%ld", (long)[prefs integerForKey:@"infrequent_stories_per_month"]];
        }
        theFeedDetailURL = [NSString stringWithFormat:
                            @"%@/reader/river_stories/?include_hidden=true&f=%@&page=%d&infrequent=%@",
                            self.appDelegate.url,
                            feeds,
                            storiesCollection.feedPage,
                            infrequent];
    }
    
    
    theFeedDetailURL = [NSString stringWithFormat:@"%@&order=%@",
                        theFeedDetailURL,
                        [storiesCollection activeOrder]];
    theFeedDetailURL = [NSString stringWithFormat:@"%@&read_filter=%@",
                        theFeedDetailURL,
                        [storiesCollection activeReadFilter]];
    if (storiesCollection.inSearch && storiesCollection.searchQuery) {
        theFeedDetailURL = [NSString stringWithFormat:@"%@&query=%@",
                            theFeedDetailURL,
                            [storiesCollection.searchQuery stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]];
    }
    
    [appDelegate GET:theFeedDetailURL parameters:nil success:^(NSURLSessionTask *task, id responseObject) {
        [self finishedLoadingFeed:responseObject feedPage:self.storiesCollection.feedPage feedId:nil];
        if (callback) {
            callback();
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)operation.response;
        self.isOnline = NO;
        self.isShowingFetching = NO;
        if (self.appDelegate.inFindingStoryMode) {
            [self informError:@"Can't find the story."];
        }
        self.appDelegate.tryFeedStoryId = nil;
        self.appDelegate.inFindingStoryMode = NO;
        self.appDelegate.findingStoryStartDate = nil;
        self.appDelegate.findingStoryDictionary = nil;
        //            storiesCollection.feedPage = 1;
        [self loadOfflineStories];
        [self showOfflineNotifier];
        if (httpResponse.statusCode == 503) {
            [self informError:@"In maintenance mode"];
            self.pageFinished = YES;
        } else if (httpResponse.statusCode >= 500) {
            [self informError:@"The server barfed."];
        }
    }];
}

#pragma mark -
#pragma mark Processing Stories

- (void)finishedLoadingFeed:(NSDictionary *)results feedPage:(NSInteger)feedPage feedId:(NSString *)sentFeedId {
    if (self.dashboardIndex >= 0 && !self.isDashboard) {
        return;
    }
    
    appDelegate.hasLoadedFeedDetail = YES;
    self.isOnline = YES;
    self.isShowingFetching = NO;
    NSString *receivedFeedId = [NSString stringWithFormat:@"%@", [results objectForKey:@"feed_id"]];
    
    if (!(storiesCollection.isRiverView ||
          storiesCollection.isSavedView ||
          storiesCollection.isReadView ||
          storiesCollection.isWidgetView ||
          storiesCollection.isSocialView ||
          storiesCollection.isSocialRiverView)
        && ![receivedFeedId isEqualToString:sentFeedId]) {
        return;
    }
    if (storiesCollection.isSocialView ||
        storiesCollection.isSocialRiverView ||
        storiesCollection.isSavedView ||
        storiesCollection.isWidgetView ||
        storiesCollection.isReadView) {
        NSArray *newFeeds = [results objectForKey:@"feeds"];
        for (int i = 0; i < newFeeds.count; i++){
            NSString *feedKey = [NSString stringWithFormat:@"%@", [[newFeeds objectAtIndex:i] objectForKey:@"id"]];
            [appDelegate.dictActiveFeeds setObject:[newFeeds objectAtIndex:i]
                                            forKey:feedKey];
        }
        [self loadFaviconsFromActiveFeed];
    }
    
    NSMutableDictionary *newClassifiers = [[results objectForKey:@"classifiers"] mutableCopy];
    if (storiesCollection.isRiverView ||
        storiesCollection.isSavedView ||
        storiesCollection.isReadView ||
        storiesCollection.isWidgetView ||
        storiesCollection.isSocialView ||
        storiesCollection.isSocialRiverView) {
        for (id key in [newClassifiers allKeys]) {
            [storiesCollection.activeClassifiers setObject:[newClassifiers objectForKey:key] forKey:key];
        }
    } else if (newClassifiers) {
        [storiesCollection.activeClassifiers setObject:newClassifiers forKey:receivedFeedId];
    }
    storiesCollection.activePopularAuthors = [results objectForKey:@"feed_authors"];
    storiesCollection.activePopularTags = [results objectForKey:@"feed_tags"];
    
    NSArray *newStories = [results objectForKey:@"stories"];
    NSMutableArray *confirmedNewStories = [[NSMutableArray alloc] init];
    if (storiesCollection.feedPage == 1) {
        confirmedNewStories = [newStories copy];
    } else {
        NSMutableSet *storyIds = [NSMutableSet set];
        for (id story in storiesCollection.activeFeedStories) {
            [storyIds addObject:[story objectForKey:@"story_hash"]];
        }
        for (id story in newStories) {
            if (![storyIds containsObject:[story objectForKey:@"story_hash"]]) {
                [confirmedNewStories addObject:story];
            }
        }
    }
    
    // Adding new user profiles to appDelegate.activeFeedUserProfiles
    
    NSArray *newUserProfiles = [[NSArray alloc] init];
    if ([results objectForKey:@"user_profiles"] != nil) {
        newUserProfiles = [results objectForKey:@"user_profiles"];
    }
    // add self to user profiles
    if (storiesCollection.feedPage == 1 && appDelegate.dictSocialProfile != nil) {
        newUserProfiles = [newUserProfiles arrayByAddingObject:appDelegate.dictSocialProfile];
    }
    
    if ([newUserProfiles count]){
        NSMutableArray *confirmedNewUserProfiles = [NSMutableArray array];
        if ([storiesCollection.activeFeedUserProfiles count]) {
            NSMutableSet *userProfileIds = [NSMutableSet set];
            for (id userProfile in storiesCollection.activeFeedUserProfiles) {
                [userProfileIds addObject:[userProfile objectForKey:@"id"]];
            }
            for (id userProfile in newUserProfiles) {
                if (![userProfileIds containsObject:[userProfile objectForKey:@"id"]]) {
                    [confirmedNewUserProfiles addObject:userProfile];
                }
            }
        } else {
            confirmedNewUserProfiles = [newUserProfiles copy];
        }
        
        
        if (storiesCollection.feedPage == 1) {
            [storiesCollection setFeedUserProfiles:confirmedNewUserProfiles];
        } else if (newUserProfiles.count > 0) {
            [storiesCollection addFeedUserProfiles:confirmedNewUserProfiles];
        }
    }
    
    NSLog(@"finishedLoadingFeed: %@", receivedFeedId);  // log
    
#if TARGET_OS_MACCATALYST
    if (@available(macCatalyst 16.0, *)) {
        settingsBarButton.hidden = NO;
        feedMarkReadButton.hidden = NO;
    }
#endif
    
    self.pageFinished = NO;
    [self renderStories:confirmedNewStories];
    
    NSLog(@"...rendered");  // log
    
    if (self.dashboardIndex >= 0) {
        self.pageFinished = YES;
        [appDelegate.feedsViewController loadDashboard];
        return;
    }
    
    if (!self.isPhoneOrCompact) {
        [appDelegate.storyPagesViewController resizeScrollView];
        [appDelegate.storyPagesViewController setStoryFromScroll:YES];
    }
    [appDelegate.storyPagesViewController advanceToNextUnread];
    
    NSLog(@"...advanced to next unread");  // log
    
    if (!storiesCollection.storyCount) {
        if ([results objectForKey:@"message"] && ![[results objectForKey:@"message"] isKindOfClass:[NSNull class]]) {
            if (!appDelegate.isPremium && storiesCollection.searchQuery != nil) {
                NSString *premiumText = @"Search is only available to\npremium subscribers";
                NSDictionary *attribs = @{NSForegroundColorAttributeName: UIColorFromRGB(0x808080),
                                          NSFontAttributeName: [UIFont systemFontOfSize:18],
                };
                NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc]
                                                             initWithString:premiumText attributes:attribs];
                
                NSRange blueRange = [premiumText rangeOfString:@"premium subscribers"];
                [attributedText setAttributes:@{NSForegroundColorAttributeName: UIColorFromRGB(0x2030C0),
                                                NSFontAttributeName: [UIFont systemFontOfSize:18],
                                              }
                                        range:blueRange];
                
                self.messageLabel.attributedText = attributedText;
                
                UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc]
                                                                initWithTarget:self action:@selector(openPremiumDialog:)];
                tapGestureRecognizer.numberOfTapsRequired = 1;
                for (UIGestureRecognizer *recognizer in self.messageLabel.gestureRecognizers) {
                    [self.messageLabel removeGestureRecognizer:recognizer];
                }
                [self.messageLabel addGestureRecognizer:tapGestureRecognizer];
                self.messageLabel.userInteractionEnabled = YES;
            } else {
                self.messageLabel.text = [results objectForKey:@"message"];
            }
            self.messageView.hidden = NO;
        } else {
            self.messageView.hidden = YES;
        }
        if (self.isLegacyTable) {
            [storyTitlesTable setContentOffset:CGPointZero animated:YES];
        }
    } else {
        self.messageView.hidden = YES;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        BOOL offlineEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"offline_allowed"];
        if (!offlineEnabled) {
            NSLog(@"Not saved stories in db, offline not supported.");
            return;
        }
        [self.appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            for (NSDictionary *story in confirmedNewStories) {
                [db executeUpdate:@"INSERT into stories"
                 "(story_feed_id, story_hash, story_timestamp, story_json) VALUES "
                 "(?, ?, ?, ?)",
                 [story objectForKey:@"story_feed_id"],
                 [story objectForKey:@"story_hash"],
                 [story objectForKey:@"story_timestamp"],
                 [story JSONRepresentation]
                ];
            }
            //    NSLog(@"Inserting %d stories: %@", [confirmedNewStories count], [db lastErrorMessage]);
        }];
    });
    
    [self.notifier hide];
    
}

- (IBAction)openPremiumDialog:(id)sender {
    [appDelegate showPremiumDialog];
}

#pragma mark -
#pragma mark Stories

- (void)renderStories:(NSArray *)newStories {
    NSInteger newStoriesCount = [newStories count];
    BOOL premiumRestriction = !appDelegate.isPremium &&
    storiesCollection.isRiverView &&
    !storiesCollection.isReadView &&
    !storiesCollection.isWidgetView &&
    !storiesCollection.isSocialView &&
    !storiesCollection.isSavedView;
    
    if (newStoriesCount > 0) {
        if (storiesCollection.feedPage == 1) {
            if (premiumRestriction) {
                newStories = [newStories subarrayWithRange:NSMakeRange(0, MIN(newStoriesCount, 3))];
            }
            [storiesCollection setStories:newStories];
        } else {
            if (premiumRestriction) {
                self.pageFinished = YES;
            } else {
                [storiesCollection addStories:newStories];
            }
        }
    } else {
        self.pageFinished = YES;
    }
    
    [self reload];
    
    if (self.view.window && self.finishedAnimatingIn) {
        [self testForTryFeed];
    }
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0ul);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,  0.1 * NSEC_PER_SEC),
                   queue, ^(void) {
        [self cacheImagesForStories:newStories];
    });
    
    self.pageFetching = NO;
}

- (void)testForTryFeed {
    if (!appDelegate.inFindingStoryMode ||
        !appDelegate.tryFeedStoryId) {
        if (appDelegate.activeStory == nil && self.cameFromFeedsList && ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone || appDelegate.splitViewController.splitBehavior != UISplitViewControllerSplitBehaviorOverlay)) {
            NSInteger storyIndex = [storiesCollection indexFromLocation:0];
            
            if (storyIndex == -1 || self.deferredLoadStoryCount > 0) {
                return;
            }
            
            NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
            NSString *feedOpening = [preferences stringForKey:@"feed_opening"];
            
            if (!self.isPhone && feedOpening == nil) {
                feedOpening = @"story";
            }
            
            if ([feedOpening isEqualToString:@"story"] && !self.isDashboard) {
                appDelegate.activeStory = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];
                [appDelegate loadStoryDetailView];
            }
        }
        return;
    }
    
    if (-appDelegate.findingStoryStartDate.timeIntervalSinceNow > 15) {
        NSLog(@"No longer looking for try feed.");
        if (appDelegate.inFindingStoryMode) {
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        }
        appDelegate.inFindingStoryMode = NO;
        appDelegate.findingStoryStartDate = nil;
        appDelegate.findingStoryDictionary = nil;
        appDelegate.tryFeedStoryId = nil;
        return;
    }
    
    if (appDelegate.findingStoryDictionary != nil) {
        NSLog(@"Got a finding story dictionary, so showing that while we look");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.appDelegate.detailViewController.storyPagesViewController refreshPages];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.appDelegate.detailViewController.currentStoryController.activeStory = [self.appDelegate.findingStoryDictionary mutableCopy];
                [self.appDelegate.detailViewController.currentStoryController drawStory];
                
                self.appDelegate.findingStoryDictionary = nil;
            });
        });
    }
    
    if (!self.view.window || [storiesCollection.activeFeedStories count] == 0) {
        NSLog(@"Want to test for try feed, but no stories loaded yet; deferring");  // log
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self testForTryFeed];
        });
        return;
    }
    
    NSLog(@"Test for try feed");
    
    if (![[MBProgressHUD HUDForView:self.view].labelText isEqualToString:@"Finding story..."]) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        HUD.labelText = @"Finding story...";
    }
    
    for (int i = 0; i < [storiesCollection.activeFeedStories count]; i++) {
        NSString *storyIdStr = [[storiesCollection.activeFeedStories
                                 objectAtIndex:i] objectForKey:@"id"];
        NSString *storyHashStr = [[storiesCollection.activeFeedStories
                                   objectAtIndex:i] objectForKey:@"story_hash"];
        if ([storyHashStr isEqualToString:appDelegate.tryFeedStoryId] ||
            [storyIdStr isEqualToString:appDelegate.tryFeedStoryId]) {
            NSDictionary *feed = [storiesCollection.activeFeedStories objectAtIndex:i];
            
            NSInteger score = [NewsBlurAppDelegate computeStoryScore:[feed objectForKey:@"intelligence"]];
            
            if (score < appDelegate.selectedIntelligence) {
                [self changeIntelligence:score];
            }
            NSInteger locationOfStoryId = [storiesCollection locationOfStoryId:storyHashStr];
            if (locationOfStoryId == -1) {
                NSLog(@"---> Could not find story: %@", storyHashStr);
                return;
            }
//            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:locationOfStoryId inSection:0];
            NSIndexPath *indexPath = [self indexPathForStoryLocation:locationOfStoryId];
            
            if (self.isLegacyTable && self.storyTitlesTable.window != nil && indexPath.row < [self.storyTitlesTable numberOfRowsInSection:0]) {
                [self tableView:self.storyTitlesTable selectRowAtIndexPath:indexPath
                       animated:NO
                 scrollPosition:UITableViewScrollPositionMiddle];
                [[self.storyTitlesTable cellForRowAtIndexPath:indexPath] setNeedsDisplay];
            }
            
            self.deferredLoadStoryCount = 1;
            [self deferredLoadStoryAtRow:indexPath];
            
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            // found the story, reset the two flags.
            appDelegate.tryFeedStoryId = nil;
            appDelegate.inFindingStoryMode = NO;
            appDelegate.findingStoryStartDate = nil;
            appDelegate.findingStoryDictionary = nil;
        }
    }
}

- (void)deferredLoadStoryAtRow:(NSIndexPath *)indexPath {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.deferredLoadStoryCount * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.deferredLoadStoryCount < 10 && self.isLegacyTable && indexPath.row >= [self.storyTitlesTable numberOfRowsInSection:0]) {
            NSLog(@"⚠️ deferredLoadStoryAtRow %@ is out of range; probably still loading; will retry in %@ seconds", @(indexPath.row), @(self.deferredLoadStoryCount));  // log
            self.deferredLoadStoryCount += 1;
            [self deferredLoadStoryAtRow:indexPath];
        } else {
            [self loadStoryAtRow:[self storyLocationForIndexPath:indexPath]];
            self.deferredLoadStoryCount = 0;
        }
    });
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    // inform the user
    NSLog(@"Connection failed! Error - %@",
          [error localizedDescription]);
    
    self.pageFetching = NO;
    
	// User clicking on another link before the page loads is OK.
	if ([error code] != NSURLErrorCancelled) {
		[self informError:error];
	}
}

- (UITableViewCell *)makeLoadingCell {
    NSInteger height = 41;
    UITableViewCell *cell = [[UITableViewCell alloc]
                             initWithStyle:UITableViewCellStyleSubtitle
                             reuseIdentifier:@"NoReuse"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (self.pageFinished) {
        BOOL premiumRestriction = !appDelegate.isPremium &&
        storiesCollection.isRiverView &&
        !storiesCollection.isReadView &&
        !storiesCollection.isWidgetView &&
        !storiesCollection.isSocialView &&
        !storiesCollection.isSavedView;
        
        UIImage *img = [UIImage imageNamed:@"fleuron.png"];
        UIImageView *fleuron = [[UIImageView alloc] initWithImage:img];
        
        UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
        if (!self.isPhoneOrCompact
            && !appDelegate.detailViewController.storyTitlesOnLeft
            && UIInterfaceOrientationIsPortrait(orientation)) {
            height = height - kTableViewShortRowDifference;
        }

        fleuron.translatesAutoresizingMaskIntoConstraints = NO;
        fleuron.contentMode = UIViewContentModeCenter;
        fleuron.tag = 99;
        [cell.contentView addSubview:fleuron];
        [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:fleuron
                                                                     attribute:NSLayoutAttributeHeight
                                                                     relatedBy:NSLayoutRelationEqual toItem:nil
                                                                     attribute:NSLayoutAttributeNotAnAttribute
                                                                    multiplier:1.0 constant:height]];
        [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:fleuron
                                                                     attribute:NSLayoutAttributeCenterX
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:cell.contentView
                                                                     attribute:NSLayoutAttributeCenterX
                                                                    multiplier:1.0 constant:0]];
        [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:fleuron
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:cell.contentView
                                                                     attribute:NSLayoutAttributeTop
                                                                    multiplier:1.0 constant:height/2]];
        cell.backgroundColor = [UIColor clearColor];
        
        if (premiumRestriction) {
            UILabel *premiumLabel = [[UILabel alloc] init];
            premiumLabel.translatesAutoresizingMaskIntoConstraints = NO;
            NSString *premiumText = @"Reading by folder is only available to\npremium subscribers";
            NSDictionary *attribs = @{NSForegroundColorAttributeName: UIColorFromRGB(0x0c0c0c),
                                      NSFontAttributeName: [UIFont systemFontOfSize:14],
                                      };
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc]
                                                         initWithString:premiumText attributes:attribs];
            
            NSRange blueRange = [premiumText rangeOfString:@"premium subscribers"];
            [attributedText setAttributes:@{NSForegroundColorAttributeName: UIColorFromRGB(0x2030C0),
                                            NSFontAttributeName: [UIFont systemFontOfSize:14],
                                            }
                                    range:blueRange];
            
            premiumLabel.attributedText = attributedText;
            premiumLabel.numberOfLines = 2;
            premiumLabel.textAlignment = NSTextAlignmentCenter;
            premiumLabel.userInteractionEnabled = YES;

            UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc]
                                                            initWithTarget:self action:@selector(openPremiumDialog:)];
            tapGestureRecognizer.numberOfTapsRequired = 1;
            [premiumLabel addGestureRecognizer:tapGestureRecognizer];

            [cell.contentView addSubview:premiumLabel];
            [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:premiumLabel
                                                                         attribute:NSLayoutAttributeCenterX
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:cell.contentView
                                                                         attribute:NSLayoutAttributeCenterX
                                                                        multiplier:1.0 constant:0]];
            [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:premiumLabel
                                                                         attribute:NSLayoutAttributeLeading
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:cell.contentView
                                                                         attribute:NSLayoutAttributeLeading
                                                                        multiplier:1.0 constant:24]];
            [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:premiumLabel
                                                                         attribute:NSLayoutAttributeTrailing
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:cell.contentView
                                                                         attribute:NSLayoutAttributeTrailing
                                                                        multiplier:1.0 constant:-24]];
            [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:premiumLabel
                                                                         attribute:NSLayoutAttributeTop
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:fleuron
                                                                         attribute:NSLayoutAttributeBottom
                                                                        multiplier:1.0 constant:height/2]];
        } else if (!self.isMarkReadOnScroll) {
            UIButton *markReadButton = [UIButton buttonWithType:UIButtonTypeCustom];
            
            markReadButton.titleLabel.font = [UIFont systemFontOfSize:14];
            [markReadButton setTitle:@"   Mark All Stories as Read   " forState:UIControlStateNormal];
            
            [markReadButton addTarget:self action:@selector(doMarkAllRead:) forControlEvents:UIControlEventTouchUpInside];
            
            markReadButton.tintColor = UIColor.whiteColor;
            markReadButton.backgroundColor = UIColorFromFixedRGB(0x939EAF);
            markReadButton.layer.cornerRadius = 10;
            
            [markReadButton sizeToFit];
            
            markReadButton.translatesAutoresizingMaskIntoConstraints = NO;
            
            [cell.contentView addSubview:markReadButton];
            [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:markReadButton
                                                                         attribute:NSLayoutAttributeCenterX
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:cell.contentView
                                                                         attribute:NSLayoutAttributeCenterX
                                                                        multiplier:1.0 constant:0]];
            [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:markReadButton
                                                                         attribute:NSLayoutAttributeTop
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:fleuron
                                                                         attribute:NSLayoutAttributeBottom
                                                                        multiplier:1.0 constant:height/2]];
        }
        
        return cell;
    } else {
        NBLoadingCell *loadingCell = [[NBLoadingCell alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, height)];
        return loadingCell;
    }
    
    return cell;
}

#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { 
    NSInteger storyCount = storiesCollection.storyLocationsCount;
    
    if (!self.messageView.hidden) {
        return 0;
    }
    
    // The +1 is for the finished/loading bar.
    return storyCount + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *cellIdentifier;
    NSDictionary *feed ;
    
    if (indexPath.row >= storiesCollection.storyLocationsCount) {
        return [self makeLoadingCell];
    }
    
    
    if (storiesCollection.isRiverView ||
        storiesCollection.isSocialView ||
        storiesCollection.isSavedView ||
        storiesCollection.isReadView ||
        storiesCollection.isReadView) {
        cellIdentifier = @"FeedRiverDetailCellIdentifier";
    } else {
        cellIdentifier = @"FeedDetailCellIdentifier";
    }
    
    FeedDetailTableCell *cell = (FeedDetailTableCell *)[tableView
                                                        dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[FeedDetailTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:cellIdentifier];
    }
    
    for (UIView *view in cell.contentView.subviews) {
        if ([view isKindOfClass:[UIImageView class]] && ((UIImageView *)view).tag == 99) {
            [view removeFromSuperview];
            break;
        }
    }
    NSDictionary *story = [self getStoryAtLocation:indexPath.row];
    
    id feedId = [story objectForKey:@"story_feed_id"];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
    feedIdStr = [appDelegate feedIdWithoutSearchQuery:feedIdStr];
    
    if (storiesCollection.isSocialView ||
        storiesCollection.isSocialRiverView) {
        feed = [appDelegate.dictActiveFeeds objectForKey:feedIdStr];
        // this is to catch when a user is already subscribed
        if (!feed) {
            feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        }
    } else {
        feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
    }
    
    NSString *siteTitle = [feed objectForKey:@"feed_title"];
    cell.siteTitle = siteTitle; 

    NSString *title = [story objectForKey:@"story_title"];
    cell.storyTitle = [title stringByDecodingHTMLEntities];
    
    cell.storyDate = [story objectForKey:@"short_parsed_date"];
    cell.storyTimestamp = [[story objectForKey:@"story_timestamp"] integerValue];
    cell.isSaved = [[story objectForKey:@"starred"] boolValue];
    cell.isShared = [[story objectForKey:@"shared"] boolValue];
    cell.storyHash = story[@"story_hash"];
    
    if ([[story objectForKey:@"story_authors"] class] != [NSNull class]) {
        cell.storyAuthor = [[story objectForKey:@"story_authors"] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    } else {
        cell.storyAuthor = @"";
    }
    
    cell.storyContent = nil;
    if (self.textSize != FeedDetailTextSizeTitleOnly) {
        NSString *content = [[[[story objectForKey:@"story_content"] convertHTML] stringByDecodingXMLEntities] stringByDecodingHTMLEntities];
        if ([content length] > 500) {
            content = [content substringToIndex:500];
        }
        cell.storyContent = [content stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    }
    
    // feed color bar border
    unsigned int colorBorder = 0;
    NSString *faviconColor = [feed valueForKey:@"favicon_fade"];

    if ([faviconColor class] == [NSNull class] || !faviconColor) {
        faviconColor = @"707070";
    }    
    NSScanner *scannerBorder = [NSScanner scannerWithString:faviconColor];
    [scannerBorder scanHexInt:&colorBorder];

    cell.feedColorBar = UIColorFromFixedRGB(colorBorder);
    
    // feed color bar border
    NSString *faviconFade = [feed valueForKey:@"favicon_color"];
    if ([faviconFade class] == [NSNull class] || !faviconFade) {
        faviconFade = @"505050";
    }    
    scannerBorder = [NSScanner scannerWithString:faviconFade];
    [scannerBorder scanHexInt:&colorBorder];
    cell.feedColorBarTopBorder =  UIColorFromFixedRGB(colorBorder);
    
    // favicon
    cell.siteFavicon = [appDelegate getFavicon:feedIdStr];
    cell.hasAlpha = NO;
    
    // undread indicator
    
    int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    cell.storyScore = score;
    
    cell.isRead = ![storiesCollection isStoryUnread:story];
    cell.isReadAvailable = ![storiesCollection.activeFolder isEqualToString:@"saved_stories"];
    cell.textSize = self.textSize;
    cell.isShort = NO;
    
    UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
    if (!self.isPhoneOrCompact &&
        !appDelegate.detailViewController.storyTitlesOnLeft &&
        UIInterfaceOrientationIsPortrait(orientation)) {
        cell.isShort = YES;
    }
    
    cell.isRiverOrSocial = NO;
    if (storiesCollection.isRiverView ||
        storiesCollection.isSavedView ||
        storiesCollection.isReadView ||
        storiesCollection.isWidgetView ||
        storiesCollection.isSocialView ||
        storiesCollection.isSocialRiverView) {
        cell.isRiverOrSocial = YES;
    }

    if (!self.isPhoneOrCompact) {
        NSInteger rowIndex = [storiesCollection locationOfActiveStory];
        if (rowIndex == indexPath.row) {
            [self tableView:tableView selectRowAtIndexPath:indexPath animated:NO];
        }
    }
    
    [cell setupGestures];
    
    [cell setNeedsDisplay];
    
    return cell;
}

- (void)loadStoryAtRow:(NSInteger)row {
    // Harvest read time for the previous story before switching
    NSDictionary *previousStory = appDelegate.activeStory;
    if (previousStory) {
        NSString *prevHash = previousStory[@"story_hash"];
        if (prevHash) {
            NSInteger readTime = [[ReadTimeTracker shared] getAndResetReadTimeWithStoryHash:prevHash];
            if (readTime > 0) {
                [[ReadTimeTracker shared] queueReadTimeWithStoryHash:prevHash seconds:readTime];
            }
        }
    }

    NSInteger storyIndex = [storiesCollection indexFromLocation:row];
    appDelegate.activeStory = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];
    [self markStoryReadIfNeeded:appDelegate.activeStory isScrolling:NO];
    [self setTitleForBackButton];
    [appDelegate loadStoryDetailView];
    [self redrawUnreadStory];

    NSString *storyHash = [appDelegate.activeStory objectForKey:@"story_hash"];
    if (storyHash) {
        [[ReadTimeTracker shared] startTrackingWithStoryHash:storyHash];
    }
}

- (void)setTitleForBackButton {
    if (self.isPhoneOrCompact) {
        NSString *feedTitle;
        if (storiesCollection.isRiverView) {
            if ([storiesCollection.activeFolder isEqualToString:@"river_blurblogs"]) {
                feedTitle = @"All Shared Stories";
            } else if ([storiesCollection.activeFolder isEqualToString:@"river_global"]) {
                feedTitle = @"Global Shared Stories";
            } else if ([storiesCollection.activeFolder isEqualToString:@"dashboard"]) {
                feedTitle = @"NewsBlur Dashboard";
            } else if ([storiesCollection.activeFolder isEqualToString:@"everything"]) {
                feedTitle = @"All Stories";
            } else if ([storiesCollection.activeFolder isEqualToString:@"infrequent"]) {
                feedTitle = @"Infrequent Site Stories";
            } else if (storiesCollection.isSavedView && storiesCollection.activeSavedStoryTag) {
                feedTitle = storiesCollection.activeSavedStoryTag;
            } else if ([storiesCollection.activeFolder isEqualToString:@"widget_stories"]) {
                feedTitle = @"Widget Site Stories";
            } else if ([storiesCollection.activeFolder isEqualToString:@"read_stories"]) {
                feedTitle = @"Read Stories";
            } else if ([storiesCollection.activeFolder isEqualToString:@"saved_stories"]) {
                feedTitle = @"Saved Stories";
            } else if ([storiesCollection.activeFolder isEqualToString:@"saved_searches"]) {
                feedTitle = @"Saved Searches";
            } else {
                feedTitle = storiesCollection.activeFolder;
            }
        } else {
            feedTitle = [storiesCollection.activeFeed objectForKey:@"feed_title"];
        }
        
        if ([feedTitle length] >= 12) {
            feedTitle = [NSString stringWithFormat:@"%@...", [feedTitle substringToIndex:MIN(9, [feedTitle length])]];
        }
        UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle:feedTitle style: UIBarButtonItemStylePlain target: nil action: nil];
        [self.navigationItem setBackBarButtonItem: newBackButton];
    }
}

- (void)redrawUnreadStory {
    [MBProgressHUD hideHUDForView:self.view animated:YES];

    NSInteger rowIndex = [storiesCollection locationOfActiveStory];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    FeedDetailTableCell *cell = (FeedDetailTableCell*) [self.storyTitlesTable cellForRowAtIndexPath:indexPath];
    
    if (![cell isKindOfClass:[FeedDetailTableCell class]]) {
        return;
    }
    
    cell.isRead = ![storiesCollection isStoryUnread:appDelegate.activeStory];
    cell.isShared = [[appDelegate.activeStory objectForKey:@"shared"] boolValue];
    cell.isSaved = [[appDelegate.activeStory objectForKey:@"starred"] boolValue];
    [cell setNeedsDisplay];
}

- (void)changeActiveStoryTitleCellLayout {
    NSInteger rowIndex = [storiesCollection locationOfActiveStory];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    FeedDetailTableCell *cell = (FeedDetailTableCell*) [self.storyTitlesTable cellForRowAtIndexPath:indexPath];
    cell.isRead = YES;
    [cell setNeedsLayout];
}

//- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
//    // obsolete; will remove
//}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < storiesCollection.storyLocationsCount) {
        // mark the cell as read
        //        appDelegate.feedsViewController.currentRowAtIndexPath = nil;
        
        NSInteger location = storiesCollection.locationOfActiveStory;
        NSIndexPath *oldIndexPath = [NSIndexPath indexPathForRow:location inSection:0];
        
        if (location >= 0 && ![oldIndexPath isEqual:indexPath]) {
            [self tableView:tableView deselectRowAtIndexPath:oldIndexPath animated:YES];
        }
        
        [self tableView:tableView redisplayCellAtIndexPath:indexPath];
        
        [self didSelectItemAtIndexPath:indexPath];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView != self.storyTitlesTable) {
        return NO;
    }
    if (indexPath.section == FeedSectionLoading) {
        return NO;
    }
    
    NSInteger location = [self storyLocationForIndexPath:indexPath];
    NSDictionary *story = [self getStoryAtLocation:location];
    return story != nil;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView != self.storyTitlesTable) {
        return nil;
    }
    if (indexPath.section == FeedSectionLoading) {
        return nil;
    }
    
    NSInteger location = [self storyLocationForIndexPath:indexPath];
    NSDictionary *story = [self getStoryAtLocation:location];
    if (!story) {
        return nil;
    }
    
    BOOL isUnread = [storiesCollection isStoryUnread:story];
    BOOL isSaved = [[story objectForKey:@"starred"] boolValue];
    
    NSString *readTitle = isUnread ? @"Mark Read" : @"Mark Unread";
    UIImage *readImage = [Utilities templateImageNamed:(isUnread ? @"indicator-read" : @"indicator-unread") sized:18];
    UIColor *readColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return isUnread ? [UIColor colorWithRed:0x4C/255.0 green:0xAF/255.0 blue:0x50/255.0 alpha:1.0]
                            : [UIColor colorWithRed:0xD4/255.0 green:0xA0/255.0 blue:0x20/255.0 alpha:1.0];
        }
        return isUnread ? [UIColor colorWithRed:0x4C/255.0 green:0xAF/255.0 blue:0x50/255.0 alpha:1.0]
                        : [UIColor colorWithRed:0xD4/255.0 green:0xA0/255.0 blue:0x20/255.0 alpha:1.0];
    }];

    UIContextualAction *readAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:readTitle
                                                                           handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        [storiesCollection toggleStoryUnread:story];
        [self reloadIndexPath:indexPath withRowAnimation:UITableViewRowAnimationFade];
        completionHandler(YES);
    }];
    readAction.backgroundColor = readColor;
    readAction.image = readImage;

    NSString *saveTitle = isSaved ? @"Unsave" : @"Save";
    UIImage *saveImage = [Utilities templateImageNamed:@"saved-stories" sized:18];
    UIColor *saveColor = isSaved
        ? UIColorFromLightSepiaMediumDarkRGB(0x00838F, 0x007A86, 0x00636E, 0x004A52)
        : UIColorFromLightSepiaMediumDarkRGB(0x26C6DA, 0x1FB5C8, 0x0FA3B5, 0x0B8FA0);

    UIContextualAction *saveAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:saveTitle
                                                                           handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        [storiesCollection toggleStorySaved:story];
        [self reloadIndexPath:indexPath withRowAnimation:UITableViewRowAnimationFade];
        completionHandler(YES);
    }];
    saveAction.backgroundColor = saveColor;
    saveAction.image = saveImage;

    UIImage *shareImage = [Utilities templateImageNamed:@"email" sized:18];
    UIColor *shareColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0x8E/255.0 green:0x8E/255.0 blue:0x93/255.0 alpha:1.0];
        }
        return [UIColor colorWithRed:0x8E/255.0 green:0x8E/255.0 blue:0x93/255.0 alpha:1.0];
    }];

    UIContextualAction *shareAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                              title:@"Share"
                                                                            handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        appDelegate.activeStory = story;
        FeedDetailTableCell *cell = (FeedDetailTableCell *)[tableView cellForRowAtIndexPath:indexPath];
        [appDelegate showSendTo:self sender:cell ?: self.view];
        completionHandler(YES);
    }];
    shareAction.backgroundColor = shareColor;
    shareAction.image = shareImage;

    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[readAction, saveAction, shareAction]];
    config.performsFirstActionWithFullSwipe = YES;
    return config;
}

- (void)didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger location = [self storyLocationForIndexPath:indexPath];
    
    if (location < storiesCollection.storyLocationsCount) {
        // mark the cell as read
        //        appDelegate.feedsViewController.currentRowAtIndexPath = nil;
        
        self.oldLocation = storiesCollection.locationOfActiveStory;
//        NSIndexPath *oldIndexPath = self.selectedIndexPath;
        
//        if (![oldIndexPath isEqual:indexPath]) {
//            [self collectionView:collectionView deselectItemAtIndexPath:oldIndexPath animated:YES];
//        }
//
//        [self collectionView:collectionView redisplayCellAtIndexPath:indexPath];
        
//        FeedDetailCollectionCell *cell = (FeedDetailCollectionCell*) [collectionView cellForItemAtIndexPath:indexPath];
        NSInteger storyIndex = [storiesCollection indexFromLocation:location];
        NSDictionary *story = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];
        BOOL isGridView = appDelegate.detailViewController.storyTitlesInGridView;
        
        if (!self.isPhoneOrCompact &&
            appDelegate.activeStory &&
            [[story objectForKey:@"story_hash"]
             isEqualToString:[appDelegate.activeStory objectForKey:@"story_hash"]]) {
            if ([self markStoryReadIfNeeded:story isScrolling:NO] && !isGridView) {
                [self reloadIndexPath:indexPath withRowAnimation:UITableViewRowAnimationFade];
            }
            
            [appDelegate showColumn:UISplitViewControllerColumnSecondary debugInfo:@"tap selected row" animated:YES];
            
            if (!appDelegate.isPhone) {
                [appDelegate.storyPagesViewController viewWillAppear:NO];
                [appDelegate.storyPagesViewController viewDidAppear:NO];
            }
            
            if (!isGridView) {
                return;
            }
        }
        
        [self loadStoryAtRow:location];
        [self reload];
        //[collectionView selectItemAtIndexPath:self.selectedIndexPath animated:YES scrollPosition:UICollectionViewScrollPositionTop];
    } else if (location == storiesCollection.storyLocationsCount) {
        if (!appDelegate.isPremium && storiesCollection.isRiverView) {
            [appDelegate showPremiumDialog];
        }
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell class] == [NBLoadingCell class]) {
        [(NBLoadingCell *)cell endAnimation];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell class] == [NBLoadingCell class]) {
        [(NBLoadingCell *)cell animate];
    }
    if ([indexPath row] == ((NSIndexPath*)[[tableView indexPathsForVisibleRows] lastObject]).row) {
        [self performSelector:@selector(checkScroll)
                   withObject:nil
                   afterDelay:0.1];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger storyCount = storiesCollection.storyLocationsCount;
    
    if (storyCount && [self storyLocationForIndexPath:indexPath] == storyCount) {
        if (!self.pageFinished) return 40;
        
        BOOL markReadOnScroll = self.isMarkReadOnScroll;
        if (markReadOnScroll) {
            return CGRectGetHeight(self.view.frame) - 40;
        }
        return 120;
    } else {
        NSInteger height = kTableViewRowHeight;
        if (storiesCollection.isRiverView ||
            storiesCollection.isSavedView ||
            storiesCollection.isReadView ||
            storiesCollection.isWidgetView ||
            storiesCollection.isSocialView ||
            storiesCollection.isSocialRiverView) {
            height = kTableViewRiverRowHeight;
        }
        if ([self isShortTitles]) {
            height = height - kTableViewShortRowDifference;
        }
        NSString *spacing = [[NSUserDefaults standardUserDefaults] objectForKey:@"feed_list_spacing"];
        if ([spacing isEqualToString:@"compact"]) {
            height -= kTableViewShortRowDifference;
        } else {
            height += kTableViewShortRowDifference;
        }
        
        UIFontDescriptor *fontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
        UIFont *font = [UIFont fontWithName:@"WhitneySSm-Medium" size:fontDescriptor.pointSize + 1];
        if ([self isShortTitles] && self.textSize != FeedDetailTextSizeTitleOnly) {
            return height + font.pointSize * 3.25;
        } else if (self.textSize != FeedDetailTextSizeTitleOnly) {
            if (self.textSize == FeedDetailTextSizeMedium || self.textSize == FeedDetailTextSizeLong) {
                NSDictionary *story = [self getStoryAtLocation:[self storyLocationForIndexPath:indexPath]];
                NSString *content = [story[@"story_content"] convertHTML];
                
                if (content.length < 10 && [story[@"story_title"] length] < 30) {
                    return height;
                } else if (content.length < 50 && [story[@"story_title"] length] < 30) {
                    return height + font.pointSize * 2;
                } else if (content.length < 50 && [story[@"story_title"] length] < 40) {
                    return height + font.pointSize * 3;
                } else if (content.length < 50 && [story[@"story_title"] length] >= 30) {
                    return height + font.pointSize * 5;
                } else if (content.length < 100) {
                    return height + font.pointSize * 5;
                } else if (self.textSize == FeedDetailTextSizeMedium) {
                    return height + font.pointSize * 7;
                } else {
                    return height + font.pointSize * 9;
                }
            } else {
                NSDictionary *story = [self getStoryAtLocation:[self storyLocationForIndexPath:indexPath]];
                
                if ([story[@"story_title"] length] < 30) {
                    return height + font.pointSize * 3;
                } else if ([story[@"story_title"] length] < 50) {
                    return height + font.pointSize * 4;
                } else {
                    return height + font.pointSize * 5;
                }
            }
        } else {
            return height + font.pointSize * 2;
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scroll {
    [self checkScroll];
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

- (BOOL)isLegacyTable {
    return appDelegate.detailViewController.storyTitlesInLegacyTable;
}

- (BOOL)isShortTitles {
    UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
    
    return !self.isPhoneOrCompact &&
        !appDelegate.detailViewController.storyTitlesOnLeft &&
        UIInterfaceOrientationIsPortrait(orientation);
}

- (NSString *)markReadValue {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if ([userPreferences boolForKey:@"override_mark_read_filter"]) {
        NSString *markRead = [userPreferences objectForKey:appDelegate.storiesCollection.markReadFilterKey];
        
        if (markRead != nil) {
            return markRead;
        }
    }
    
    NSString *markRead = [userPreferences stringForKey:@"default_mark_read_filter"];
    
    return markRead;
}

- (void)cancelMarkStoryReadTimer {
    [self.markStoryReadTimer invalidate];
    self.markStoryReadTimer = nil;
}

- (BOOL)markStoryReadIfNeeded:(NSDictionary *)story isScrolling:(BOOL)isScrolling {
    if (!isScrolling) {
        [self cancelMarkStoryReadTimer];
    }
    
    if (![storiesCollection isStoryUnread:story]) {
        return NO;
    }
    
    NSTimeInterval interval = self.markReadAfterInterval;
    
    if (interval > 0) {
        if (isScrolling && self.markStoryReadTimer != nil) {
            return NO;
        }
        
        self.markStoryReadTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:NO block:^(NSTimer * _Nonnull timer) {
            [self.storiesCollection markStoryRead:story];
            [self.storiesCollection syncStoryAsRead:story];
            
            [self reload];
            [self.appDelegate.storyPagesViewController.currentPage setActiveStoryAtIndex:-1];
            [self.appDelegate.storyPagesViewController.currentPage refreshHeader];
        }];
        
        return NO;
    } else if (self.isMarkReadManually) {
        return NO;
    } else {
        [storiesCollection markStoryRead:story];
        [storiesCollection syncStoryAsRead:story];
        
        return YES;
    }
}

- (BOOL)isMarkReadOnScroll {
    return [[self markReadValue] isEqualToString:@"scroll"];
}

- (BOOL)isMarkReadOnScrollOrSelection {
    return [[self markReadValue] isEqualToString:@"scroll"] || [[self markReadValue] isEqualToString:@"selection"];
}

- (NSTimeInterval)markReadAfterInterval {
    NSString *markRead = [self markReadValue];
    if ([markRead hasPrefix:@"after"]) {
        return [[markRead substringFromIndex:5] integerValue];
    } else {
        return 0;
    }
}

- (BOOL)isMarkReadManually {
    return [[self markReadValue] isEqualToString:@"manually"];
}

- (void)checkScroll {
    if (!self.isLegacyTable) {
        return;
    }
    
    NSInteger currentOffset = self.storyTitlesTable.contentOffset.y;
    NSInteger maximumOffset = self.storyTitlesTable.contentSize.height - self.storyTitlesTable.frame.size.height;
    
    if (![storiesCollection.activeFeedStories count]) return;
    
    if (!self.pageFetching && (maximumOffset - currentOffset <= 500.0 ||
        (appDelegate.inFindingStoryMode))) {
        if (storiesCollection.isRiverView && storiesCollection.activeFolder) {
            [self fetchRiverPage:storiesCollection.feedPage+1 withCallback:nil];
        } else {
            [self fetchFeedDetail:storiesCollection.feedPage+1 withCallback:nil];
        }
    }
    
    CGPoint topRowPoint = self.storyTitlesTable.contentOffset;
    topRowPoint.y = topRowPoint.y + (self.textSize != FeedDetailTextSizeTitleOnly ? 80.f : 60.f);
    NSIndexPath *indexPath = [self.storyTitlesTable indexPathForRowAtPoint:topRowPoint];
    BOOL markReadOnScroll = self.isMarkReadOnScroll;
    
    if (indexPath && markReadOnScroll) {
        NSUInteger topRow = indexPath.row;
        
        if (self.scrollingMarkReadRow == NSNotFound) {
            self.scrollingMarkReadRow = topRow;
        } else if (topRow > self.scrollingMarkReadRow) {
            for (NSUInteger thisRow = self.scrollingMarkReadRow; thisRow < topRow; thisRow++) {
                NSInteger storyIndex = [storiesCollection indexFromLocation:thisRow];
                NSDictionary *story = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];
                
                if ([self markStoryReadIfNeeded:story isScrolling:YES]) {
                    NSIndexPath *reloadIndexPath = [NSIndexPath indexPathForRow:thisRow inSection:0];
                    NSLog(@" --> Reloading indexPath: %@", reloadIndexPath);
                    [self reloadIndexPath:reloadIndexPath withRowAnimation:UITableViewRowAnimationFade];
                }
            }
            
            self.scrollingMarkReadRow = topRow;
        }
    }
}

- (void)changeIntelligence:(NSInteger)newLevel {
    NSInteger previousLevel = [appDelegate selectedIntelligence];
    
    if (newLevel == previousLevel) return;
    
    if (newLevel < previousLevel) {
        [appDelegate setSelectedIntelligence:newLevel];
        NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
        [userPreferences setInteger:(newLevel + 1) forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        [storiesCollection calculateStoryLocations];
    }
    
    [self reload];
}

- (NSDictionary *)getStoryAtLocation:(NSInteger)storyLocation {
    if (storyLocation >= [[storiesCollection activeFeedStoryLocations] count]) return nil;
    id location = [[storiesCollection activeFeedStoryLocations] objectAtIndex:storyLocation];
    if (!location) return nil;
    NSInteger row = [location intValue];
    return [storiesCollection.activeFeedStories objectAtIndex:row];
}

- (NSInteger)storyLocationForIndexPath:(NSIndexPath *)indexPath {
    if (self.isLegacyTable || indexPath.section == FeedSectionBefore) {
        return indexPath.row;
    } else if (indexPath.section == FeedSectionSelected) {
        return storiesCollection.indexOfActiveStory;
    } else {
        return storiesCollection.indexOfActiveStory + indexPath.row + 1;
    }
}

- (NSIndexPath *)indexPathForStoryLocation:(NSInteger)location {
    NSInteger active = storiesCollection.indexOfActiveStory;
    
    if (self.isLegacyTable || active < 0 || location < active) {
        return [NSIndexPath indexPathForRow:location inSection:FeedSectionBefore];
    } else if (location == active) {
        return [NSIndexPath indexPathForRow:0 inSection:FeedSectionSelected];
    } else {
        return [NSIndexPath indexPathForRow:location - active - 1 inSection:FeedSectionAfter];
    }
}

//- (NSIndexPath *)selectedIndexPath {
//    if (feedCollectionView.indexPathsForSelectedItems.count > 0) {
//        return [NSIndexPath indexPathForRow:0 inSection:FeedSectionSelected];
//    } else {
//        return nil;
//    }
//}


#pragma mark - MCSwipeTableViewCellDelegate

// When the user starts swiping the cell this method is called
- (void)swipeTableViewCellDidStartSwiping:(MCSwipeTableViewCell *)cell {
    //    NSLog(@"Did start swiping the cell!");
    NSIndexPath *indexPath = [self.storyTitlesTable indexPathForCell:cell];
    FeedDetailTableCell *feedCell = (FeedDetailTableCell *)cell;
    
    self.swipingIndexPath = indexPath;
    self.swipingStoryHash = feedCell.storyHash;
}

// When the user is dragging, this method is called and return the dragged percentage from the border
- (void)swipeTableViewCell:(MCSwipeTableViewCell *)cell didSwipWithPercentage:(CGFloat)percentage {
//    NSLog(@"Did swipe with percentage : %f", percentage);
}

- (void)swipeTableViewCell:(MCSwipeTableViewCell *)cell
didEndSwipingSwipingWithState:(MCSwipeTableViewCellState)state
                      mode:(MCSwipeTableViewCellMode)mode {
    NSIndexPath *endedOnIndexPath = [self.storyTitlesTable indexPathForCell:cell];
    NSInteger storyIndex = [storiesCollection indexFromLocation:self.swipingIndexPath.row];
    NSDictionary *story = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];
    
    if (endedOnIndexPath != self.swipingIndexPath || story[@"story_hash"] != self.swipingStoryHash) {
        NSLog(@"Swipe started at row %@ (%@) but ended at %@ (%@) for %@", @(self.swipingIndexPath.row), self.swipingStoryHash, @(endedOnIndexPath.row), story[@"story_hash"], story[@"story_title"]);  // log
        
        self.swipingIndexPath = nil;
        self.swipingStoryHash = nil;
        
        return;
    }
    
    self.swipingIndexPath = nil;
    self.swipingStoryHash = nil;
    
    if (state == MCSwipeTableViewCellState1) {
        // Saved
        [storiesCollection toggleStorySaved:story];
        [self reloadIndexPath:endedOnIndexPath withRowAnimation:UITableViewRowAnimationFade];
    } else if (state == MCSwipeTableViewCellState3) {
        // Read
        [storiesCollection toggleStoryUnread:story];
        [self reloadIndexPath:endedOnIndexPath withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark -
#pragma mark Feed Actions

- (void)handleTableLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    CGPoint p = [gestureRecognizer locationInView:self.storyTitlesTable];
    NSIndexPath *indexPath = [self.storyTitlesTable indexPathForRowAtPoint:p];
    FeedDetailTableCell *cell = (FeedDetailTableCell *)[self.storyTitlesTable cellForRowAtIndexPath:indexPath];
    
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) return;
    if (indexPath == nil) return;
    
    NSDictionary *story = [self getStoryAtLocation:indexPath.row];
    
    if (!story) return;

    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSString *longPressStoryTitle = [preferences stringForKey:@"long_press_story_title"];
    
    if ([longPressStoryTitle isEqualToString:@"ask"]) {
        appDelegate.activeStory = story;
        [self showMarkOlderNewerOptionsForStory:story indexPath:indexPath cell:cell];
    } else if ([longPressStoryTitle isEqualToString:@"open_send_to"]) {
        appDelegate.activeStory = story;
        [appDelegate showSendTo:self sender:cell];
    } else if ([longPressStoryTitle isEqualToString:@"mark_unread"]) {
        [storiesCollection toggleStoryUnread:story];
        [self reloadIndexPath:indexPath withRowAnimation:UITableViewRowAnimationFade];
    } else if ([longPressStoryTitle isEqualToString:@"save_story"]) {
        [storiesCollection toggleStorySaved:story];
        [self reloadIndexPath:indexPath withRowAnimation:UITableViewRowAnimationFade];
    } else if ([longPressStoryTitle isEqualToString:@"train_story"]) {
        appDelegate.activeStory = story;
        [appDelegate openTrainStory:cell];
    }
}

- (void)handleMarkReadLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) return;
    
    [self markReadShowMenu:MarkReadShowMenuAlways sender:nil];
}

- (void)showMarkOlderNewerOptionsForStory:(NSDictionary *)story indexPath:(NSIndexPath *)indexPath cell:(FeedDetailTableCell *)cell {
    CGRect rect = [self.storyTitlesTable rectForRowAtIndexPath:indexPath];
    
    NSMutableArray *items = [NSMutableArray array];
    BOOL isSaved = [[story objectForKey:@"starred"] boolValue];
    
    [items addObject:[self itemWithTitle:isSaved ? @"Unsave This Story" : @"Save This Story" iconName:@"saved-stories" iconColor:UIColorFromRGB(0xD58B4F) handler:^{
        [self.storiesCollection toggleStorySaved:story];
    }]];
    
    [items addObject:[self itemWithTitle:@"Send This Story To..." iconName:@"menu_icn_mail.png" handler:^{
        [self.appDelegate showSendTo:self sender:cell];
    }]];
    
    [items addObject:[self itemWithTitle:@"Train This Story" iconName:@"menu_icn_train.png" handler:^{
        [self.appDelegate openTrainStory:cell];
    }]];
    
    [self.appDelegate showMarkOlderNewerReadMenuWithStoriesCollection:self.storiesCollection story:story sourceView:self.storyTitlesTable sourceRect:rect extraItems:items completionHandler:^(BOOL marked) {
        [self.storyTitlesTable reloadData];
    }];
}

- (NSDictionary *)itemWithTitle:(NSString *)title iconName:(NSString *)iconName handler:(void (^)(void))handler {
    return @{@"title" : title, @"icon" : iconName, @"handler" : handler};
}

- (NSDictionary *)itemWithTitle:(NSString *)title iconName:(NSString *)iconName iconColor:(UIColor *)iconColor handler:(void (^)(void))handler {
    return @{@"title" : title, @"icon" : iconName, @"iconColor" : iconColor, @"handler" : handler};
}

- (void)markFeedsReadFromTimestamp:(NSInteger)cutoffTimestamp andOlder:(BOOL)older {
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_as_read",
                           self.appDelegate.url];
    NSMutableArray *feedIds = [NSMutableArray array];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    if (storiesCollection.isRiverView) {
        if ([storiesCollection.activeFolder isEqual:@"dashboard"] || [storiesCollection.activeFolder isEqual:@"everything"] || [storiesCollection.activeFolder isEqual:@"infrequent"]) {
            for (NSString *folderName in appDelegate.dictFoldersArray) {
                for (id feedId in [appDelegate.dictFolders objectForKey:folderName]) {
                    if (![feedId isKindOfClass:[NSString class]] || ![feedId startsWith:@"saved:"]) {
                        [feedIds addObject:feedId];
                    }
                }
            }
        } else {
            for (id feedId in [appDelegate.dictFolders objectForKey:storiesCollection.activeFolder]) {
                [feedIds addObject:feedId];
            }
        }
    } else {
        [feedIds addObject:[storiesCollection.activeFeed objectForKey:@"id"]];
    }
    
    [params setObject:feedIds forKey:@"feed_id"];
    [params setObject:@(cutoffTimestamp) forKey:@"cutoff_timestamp"];
    NSString *direction = older ? @"older" : @"newest";
    [params setObject:direction forKey:@"direction"];
    
    if ([storiesCollection.activeFolder isEqualToString:@"infrequent"]) {
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        NSString *infrequent = [NSString stringWithFormat:@"%ld", (long)[prefs integerForKey:@"infrequent_stories_per_month"]];
        [params setObject:infrequent forKey:@"infrequent"];
    }
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionTask *task, id responseObject) {
        [self.appDelegate markFeedReadInCache:feedIds cutoffTimestamp:cutoffTimestamp older:older];
        // is there a better way to refresh the detail view?
        [self reloadStories];
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        [self requestFailed:error];
    }];
}

- (void)markReadShowMenu:(MarkReadShowMenu)showMenu sender:(id)sender {
    [self.appDelegate hidePopoverAnimated:YES];
    
    void (^pop)(void) = ^{
        if (!self.isPhoneOrCompact) {
            [self reloadStories];
        }
        // Don't do this, as it causes a race condition with the marking read call
//        [self.appDelegate.feedsViewController refreshFeedList];
        [self.appDelegate.feedsViewController reloadFeedTitlesTable];
        [self.appDelegate showFeedsListAnimated:YES];
        
        NSString *loadNextPref = [[NSUserDefaults standardUserDefaults] stringForKey:@"after_mark_read"];
        
        if (![loadNextPref isEqualToString:@"stay"]) {
            [self.appDelegate.feedsViewController selectNextFolderOrFeed];
        }
    };
    
    [storiesCollection calculateStoryLocations];
    NSArray *feedIds = storiesCollection.isRiverView ? [self.appDelegate feedIdsForFolderTitle:storiesCollection.activeFolder] : @[storiesCollection.activeFeed[@"id"]];
    NSString *confirmPref = [[NSUserDefaults standardUserDefaults] stringForKey:@"default_confirm_read_filter"];
    
    if (showMenu == MarkReadShowMenuNever) {
        [self.appDelegate.feedsViewController markFeedsRead:feedIds cutoffDays:0];
        pop();
        return;
    } else if (showMenu == MarkReadShowMenuBasedOnPref && ([confirmPref isEqualToString:@"never"] || ([confirmPref isEqualToString:@"folders"] && !storiesCollection.isRiverView))) {
        [self.appDelegate.feedsViewController markFeedsRead:feedIds cutoffDays:0];
        pop();
        return;
    }
    
    NSString *collectionTitle = storiesCollection.isRiverView ? [storiesCollection.activeFolder isEqualToString:@"everything"] ? @"everything" : @"entire folder" : @"this site";
    NSInteger totalUnreadCount = [self.appDelegate unreadCount];
    NSInteger visibleUnreadCount = storiesCollection.visibleUnreadCount;
    
    if (feedIds.count == 1 && ![feedIds.firstObject isKindOfClass:[NSString class]]) {
        collectionTitle = @"this site";
    }
    
    if (visibleUnreadCount >= totalUnreadCount) {
        visibleUnreadCount = 0;
    }
    
#if TARGET_OS_MACCATALYST
    UINavigationController *feedDetailNavController = appDelegate.feedDetailViewController.navigationController;
    UIView *sourceView = feedDetailNavController.view;
    CGRect sourceRect = CGRectMake(120, 10, 20, 20);
    
    if (appDelegate.splitViewController.isFeedsListHidden) {
        sourceRect = CGRectMake(-130, 10, 20, 20);
    }
    
    [self.appDelegate showMarkReadMenuWithFeedIds:feedIds collectionTitle:collectionTitle visibleUnreadCount:visibleUnreadCount sourceView:sourceView sourceRect:sourceRect completionHandler:^(BOOL marked){
        if (marked) {
            pop();
        }
    }];
#else
    UIBarButtonItem *barButton = self.feedMarkReadButton;
    if (sender && [sender isKindOfClass:[UIBarButtonItem class]]) barButton = sender;
    
    [self.appDelegate showMarkReadMenuWithFeedIds:feedIds collectionTitle:collectionTitle visibleUnreadCount:visibleUnreadCount barButtonItem:barButton completionHandler:^(BOOL marked){
        if (marked) {
            pop();
        }
    }];
#endif
}

- (IBAction)doOpenMarkReadMenu:(id)sender {
    if (feedMarkReadButton.isEnabled) {
        [self markReadShowMenu:MarkReadShowMenuBasedOnPref sender:sender];
    }
}

- (IBAction)doMarkAllRead:(id)sender {
    [self markReadShowMenu:MarkReadShowMenuNever sender:nil];
}

- (BOOL)isRiver {
    return appDelegate.storiesCollection.isSocialRiverView ||
    appDelegate.storiesCollection.isSocialView ||
    appDelegate.storiesCollection.isSavedView ||
    appDelegate.storiesCollection.isWidgetView ||
    appDelegate.storiesCollection.isReadView;
}

- (IBAction)doShowFeeds:(id)sender {
    [self.appDelegate showColumn:UISplitViewControllerColumnPrimary debugInfo:@"showFeeds" animated:YES];
}

- (IBAction)doOpenSettingsMenu:(id)sender {
    if (self.presentedViewController) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    MenuViewController *viewController = [MenuViewController new];
    __weak MenuViewController *weakViewController = viewController;
    
    BOOL dashboard = self.isDashboard;
    BOOL everything = appDelegate.storiesCollection.isEverything;
    BOOL infrequent = appDelegate.storiesCollection.isInfrequent;
    BOOL river = [self isRiver];
    BOOL read = appDelegate.storiesCollection.isReadView;
    BOOL widget = appDelegate.storiesCollection.isWidgetView;
    BOOL social = appDelegate.storiesCollection.isSocialRiverView;
    BOOL saved = appDelegate.storiesCollection.isSavedView;
    
    if (storiesCollection.inSearch) {
        if (storiesCollection.savedSearchQuery == nil) {
            [viewController addTitle:@"Save search" iconName:@"g_icn_search.png" selectionShouldDismiss:YES handler:^{
                [self saveSearch];
            }];
        } else {
            [viewController addTitle:@"Delete saved search" iconName:@"g_icn_search.png" selectionShouldDismiss:YES handler:^{
                [self deleteSavedSearch];
            }];
        }
    }
    
    if ((!everything || !appDelegate.storiesCollection.isRiverView) && !infrequent && !saved && !read && !social && !widget && !dashboard) {
        NSString *manageText = [NSString stringWithFormat:@"Manage this %@…", appDelegate.storiesCollection.isRiverView ? @"folder" : @"site"];
        
        [viewController addTitle:manageText iconName:@"menu_icn_move.png" selectionShouldDismiss:NO handler:^{
            [self manageSite:weakViewController.navigationController manageText:manageText everything:everything];
        }];
    }
    
    if (!appDelegate.storiesCollection.isRiverView && !infrequent && !saved && !read && !social && !widget && !dashboard) {
        [viewController addTitle:@"Train this site" iconName:@"menu_icn_train.png" selectionShouldDismiss:YES handler:^{
            [self openTrainSite];
        }];
        
        if ([appDelegate.storiesCollection.activeFeed[@"ng"] integerValue] > 0) {
            NSString *title =  appDelegate.storiesCollection.showHiddenStories ? @"Hide hidden stories" : @"Show hidden stories";
            
            [viewController addTitle:title iconName:@"menu_icn_all.png" selectionShouldDismiss:YES handler:^{
                [self toggleHiddenStories];
            }];
        }
        
        [viewController addTitle:@"Notifications" iconName:@"dialog-notifications" iconColor:UIColorFromRGB(0xD58B4F) selectionShouldDismiss:YES handler:^{
            [self
             openNotificationsWithFeed:[NSString stringWithFormat:@"%@", [self.appDelegate.storiesCollection.activeFeed objectForKey:@"id"]]];
        }];
        
        [viewController addTitle:@"Statistics" iconName:@"menu_icn_statistics.png" selectionShouldDismiss:YES handler:^{
            [self
             openStatisticsWithFeed:[NSString stringWithFormat:@"%@", [self.appDelegate.storiesCollection.activeFeed objectForKey:@"id"]]];
        }];
        
        [viewController addTitle:@"Insta-fetch stories" iconName:@"menu_icn_fetch.png" selectionShouldDismiss:YES handler:^{
            [self instafetchFeed];
        }];
    }
    
    if (!dashboard) {
        NSString *preferenceKey = self.appDelegate.storiesCollection.markReadFilterKey;
        NSArray *titles = @[@"On scroll or selection", @"Only on selection", @"After 1 second", @"After 2 seconds", @"After 3 seconds", @"After 4 seconds", @"After 5 seconds", @"After 10 seconds", @"After 15 seconds", @"After 30 seconds", @"After 45 seconds", @"After 60 seconds", @"Manually"];
        NSArray *values = @[ @"scroll", @"selection", @"after1", @"after2", @"after3", @"after4", @"after5", @"after10", @"after15", @"after30", @"after45", @"after60", @"manually"];
        
        [viewController addTitle:@"Mark story read…" iconName:@"indicator-unread" iconColor:UIColorFromRGB(0xD58B4F) submenuTitles:titles values:values overrideSelectedValue:self.markReadValue defaultValue:@"scroll" preferenceKey:preferenceKey selectionShouldDismiss:YES handler:^(id selectedValue) {
            // Nothing to do.
        }];
        
        [viewController addSegmentedControlWithTitles:@[@"Newest first", @"Oldest"] selectIndex:[appDelegate.storiesCollection.activeOrder isEqualToString:@"newest"] ? 0 : 1 selectionShouldDismiss:YES handler:^(NSUInteger selectedIndex) {
            if (selectedIndex == 0) {
                [userPreferences setObject:@"newest" forKey:[self.appDelegate.storiesCollection orderKey]];
            } else {
                [userPreferences setObject:@"oldest" forKey:[self.appDelegate.storiesCollection orderKey]];
            }
            
            [self reloadStories];
        }];
        
        if (!dashboard || infrequent || !river) {
            [viewController addSegmentedControlWithTitles:@[@"All stories", @"Unread only"] selectIndex:[appDelegate.storiesCollection.activeReadFilter isEqualToString:@"all"] ? 0 : 1 selectionShouldDismiss:YES handler:^(NSUInteger selectedIndex) {
                if (selectedIndex == 0) {
                    [userPreferences setObject:@"all" forKey:self.appDelegate.storiesCollection.readFilterKey];
                } else {
                    [userPreferences setObject:@"unread" forKey:self.appDelegate.storiesCollection.readFilterKey];
                }
                
                [self reloadStories];
            }];
        }
    }
    
    [appDelegate addSplitControlToMenuController:viewController];
    
    if (dashboard) {
        NSString *preferenceKey = @"dashboard_layout";
        NSArray *titles = @[@"Single", @"Columns", @"Rows"];
        NSArray *values = @[@"single", @"vertical", @"horizontal"];
        
        [viewController addSegmentedControlWithTitles:titles values:values preferenceKey:preferenceKey selectionShouldDismiss:NO handler:^(NSUInteger selectedIndex) {
            [self reload];
        }];
    }
    
    if (!dashboard) {
        NSString *preferenceKey = self.appDelegate.storiesCollection.storyTitlesPositionKey;
        NSArray *titles;
        NSArray *values;
        
        if (appDelegate.detailViewController.isPhone) {
            titles = @[@"List", @"Grid"];
            values = @[@"titles_on_left", @"titles_in_grid"];
        } else {
            titles = @[@"layout-split.png", @"layout-top2.png", @"layout-full.png", @"layout-list.png", @"layout-magazine.png", @"layout-grid.png"];
            values = @[@"titles_on_left", @"titles_on_top", @"titles_on_bottom", @"titles_in_list", @"titles_in_magazine", @"titles_in_grid"];
        }
        
        [viewController addSegmentedControlWithTitles:titles values:values defaultValue:@"titles_on_left" selectValue:self.appDelegate.storiesCollection.activeStoryTitlesPosition preferenceKey:preferenceKey selectionShouldDismiss:YES handler:^(NSUInteger selectedIndex) {
            [self.appDelegate.detailViewController updateLayoutWithReload:YES fetchFeeds:YES];
        }];
        
        if (self.appDelegate.detailViewController.storyTitlesInGrid) {
            preferenceKey = @"grid_columns";
            
            if (appDelegate.detailViewController.isPhone) {
                titles = @[@"Auto Cols", @"1", @"2"];
                values = @[@"auto", @"1", @"2"];
            } else {
                titles = @[@"Auto Cols", @"1", @"2", @"3", @"4"];
                values = @[@"auto", @"1", @"2", @"3", @"4"];
            }
            
            [viewController addSegmentedControlWithTitles:titles values:values defaultValue:@"auto" preferenceKey:preferenceKey selectionShouldDismiss:NO handler:^(NSUInteger selectedIndex) {
                [self.appDelegate.detailViewController updateLayoutWithReload:YES fetchFeeds:YES];
            }];
            
            preferenceKey = @"grid_height";
            titles = @[@"XS", @"Short", @"Medium", @"Tall", @"XL"];
            values = @[@"xs", @"short", @"medium", @"tall", @"xl"];
            
            [viewController addSegmentedControlWithTitles:titles values:values defaultValue:@"medium" preferenceKey:preferenceKey selectionShouldDismiss:NO handler:^(NSUInteger selectedIndex) {
                [self.appDelegate.detailViewController updateLayoutWithReload:YES fetchFeeds:YES];
            }];
        }
    }
    
    if (!self.appDelegate.detailViewController.storyTitlesInGrid) {
        NSString *preferenceKey = @"story_list_preview_text_size";
        NSArray *titles = @[@"Title", @"content_preview_small.png", @"content_preview_medium.png", @"content_preview_large.png"];
        NSArray *values = @[@"title", @"short", @"medium", @"long"];
        
        [viewController addSegmentedControlWithTitles:titles values:values preferenceKey:preferenceKey selectionShouldDismiss:NO handler:^(NSUInteger selectedIndex) {
            [self.appDelegate resizePreviewSize];
        }];
        
        // Upgrade the prefs; can remove these lines eventually, once most existing users are likely on version 11 or later.
        NSString *preview = [[NSUserDefaults standardUserDefaults] stringForKey:@"story_list_preview_images_size"];
        
        if ([preview isEqualToString:@"small"]) {
            [[NSUserDefaults standardUserDefaults] setObject:@"small_right" forKey:@"story_list_preview_images_size"];
        } else if ([preview isEqualToString:@"large"]) {
            [[NSUserDefaults standardUserDefaults] setObject:@"large_right" forKey:@"story_list_preview_images_size"];
        }
        
        preferenceKey = @"story_list_preview_images_size";
        titles = @[@"No image", @"image_preview_small_left.png", @"image_preview_large_left.png", @"image_preview_large_right.png", @"image_preview_small_right.png"];
        values = @[@"none", @"small_left", @"large_left", @"large_right", @"small_right"];
        
        [viewController addSegmentedControlWithTitles:titles values:values preferenceKey:preferenceKey selectionShouldDismiss:NO handler:^(NSUInteger selectedIndex) {
            [self.appDelegate resizePreviewSize];
        }];
    }
    
    NSString *preferenceKey = @"feed_list_font_size";
    NSArray *titles = @[@"XS", @"S", @"M", @"L", @"XL"];
    NSArray *values = @[@"xs", @"small", @"medium", @"large", @"xl"];
    
    [viewController addSegmentedControlWithTitles:titles values:values preferenceKey:preferenceKey selectionShouldDismiss:NO handler:^(NSUInteger selectedIndex) {
        [self.appDelegate resizeFontSize];
    }];
    
    if (infrequent) {
        preferenceKey = @"infrequent_stories_per_month";
        titles = @[@"5", @"15", @"30", @"60", @"90"];
        values = @[@5, @15, @30, @60, @90];
        
        [viewController addSegmentedControlWithTitles:titles values:values preferenceKey:preferenceKey selectionShouldDismiss:YES handler:^(NSUInteger selectedIndex) {
            [self.appDelegate.feedDetailViewController reloadStories];
            [self.appDelegate.feedDetailViewController flashInfrequentStories];
        }];
    }
    
    preferenceKey = @"feed_list_spacing";
    titles = @[@"Compact", @"Comfortable"];
    values = @[@"compact", @"comfortable"];
    
    [viewController addSegmentedControlWithTitles:titles values:values defaultValue:@"comfortable" preferenceKey:preferenceKey selectionShouldDismiss:NO handler:^(NSUInteger selectedIndex) {
        [self.appDelegate.feedsViewController reloadFeedTitlesTable];
        [self reloadWithSizing];
    }];
    
    [viewController addThemeSegmentedControl];
    
    UINavigationController *navController = self.navigationController ?: appDelegate.storyPagesViewController.navigationController;
    
#if TARGET_OS_MACCATALYST
    UIView *sourceView = navController.view;
    CGRect sourceRect = CGRectMake(430, 0, 20, 20);

    if (appDelegate.splitViewController.isFeedsListHidden) {
        sourceRect = CGRectMake(270, 0, 20, 20);
    }

    UINavigationController *menuNavController = [[UINavigationController alloc] initWithRootViewController:viewController];
    menuNavController.navigationBarHidden = YES;
    menuNavController.delegate = viewController;
    [appDelegate showPopoverWithViewController:menuNavController contentSize:CGSizeZero sourceView:sourceView sourceRect:sourceRect];
#else
    [viewController showFromNavigationController:navController barButtonItem:self.settingsBarButton];
#endif
}

- (NSString *)feedIdForSearch {
    if (storiesCollection.activeFeed != nil) {
        return [NSString stringWithFormat:@"feed:%@", [storiesCollection.activeFeed objectForKey:@"id"]];
    } else if ([storiesCollection.activeFolder isEqualToString:@"everything"]) {
        return @"river:";
    } else {
        return [NSString stringWithFormat:@"river:%@", storiesCollection.activeFolder];
    }
}

- (void)saveSearch {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Saving search...";
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/save_search",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[self feedIdForSearch] forKey:@"feed_id"];
    [params setObject:storiesCollection.searchQuery forKey:@"query"];
    
    [self.appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        self.storiesCollection.savedSearchQuery = self.storiesCollection.searchQuery;
        [self.appDelegate reloadFeedsView:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (void)deleteSavedSearch {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Deleting saved search...";
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/delete_search",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[self feedIdForSearch] forKey:@"feed_id"];
    [params setObject:storiesCollection.searchQuery forKey:@"query"];
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        self.storiesCollection.savedSearchQuery = nil;
        [self.appDelegate reloadFeedsView:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (void)manageSite:(UINavigationController *)menuNavigationController manageText:(NSString *)manageText everything:(BOOL)everything {
    MenuViewController *viewController = [MenuViewController new];
    __weak MenuViewController *weakViewController = viewController;
    viewController.title = manageText;
    
    if (!everything || !appDelegate.storiesCollection.isRiverView) {
        NSString *deleteText = [NSString stringWithFormat:@"Delete %@",
                                appDelegate.storiesCollection.isRiverView ?
                                @"this entire folder" :
                                @"this site"];
        
        [viewController addTitle:deleteText iconName:@"menu_icn_delete.png" selectionShouldDismiss:NO handler:^{
            [self confirmDeleteSite:weakViewController.navigationController];
        }];
        
        [viewController addTitle:@"Move to another folder" iconName:@"menu_icn_move.png" selectionShouldDismiss:NO handler:^{
            [self openMoveView:weakViewController.navigationController];
        }];
    }
    
    NSString *renameText = [NSString stringWithFormat:@"Rename this %@", appDelegate.storiesCollection.isRiverView ? @"folder" : @"site"];
    
    [viewController addTitle:renameText iconName:@"menu_icn_rename.png" selectionShouldDismiss:YES handler:^{
        [self openRenameSite];
    }];
    
    if (!appDelegate.storiesCollection.isRiverView) {
        BOOL isMuted = ![[storiesCollection.activeFeed objectForKey:@"active"] boolValue];
        if (isMuted) {
            [viewController addTitle:@"Unmute this site" iconName:@"menu_icn_mute.png" selectionShouldDismiss:YES handler:^{
                [self unmuteSite];
            }];
        } else {
            [viewController addTitle:@"Mute this site" iconName:@"menu_icn_mute.png" selectionShouldDismiss:NO handler:^{
                [self confirmMuteSite:weakViewController.navigationController];
            }];
        }
    }
    
    [menuNavigationController showViewController:viewController sender:self];
}

- (void)confirmDeleteSite:(UINavigationController *)menuNavigationController {
    MenuViewController *viewController = [MenuViewController new];
    viewController.title = @"Positive?";
    NSString *title = storiesCollection.isRiverView ? @"Delete Folder" : @"Delete Site";
    
    [viewController addTitle:title iconName:@"menu_icn_delete.png" destructive:YES selectionShouldDismiss:YES handler:^{
        if (self.storiesCollection.isRiverView) {
            [self deleteFolder];
        } else {
            [self deleteSite];
        }
    }];
    
    [menuNavigationController showViewController:viewController sender:self];
}

- (void)confirmMuteSite:(UINavigationController *)menuNavigationController {
    MenuViewController *viewController = [MenuViewController new];
    viewController.title = @"Positive?";
    
    [viewController addTitle:@"Mute Site" iconName:@"menu_icn_mute.png" selectionShouldDismiss:YES handler:^{
        [self muteSite];
    }];
    
    [menuNavigationController showViewController:viewController sender:self];
}

- (void)renameTo:(NSString *)newTitle {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Renaming...";
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/rename_feed", self.appDelegate.url];
    if (storiesCollection.isRiverView) {
        urlString = [NSString stringWithFormat:@"%@/reader/rename_folder", self.appDelegate.url];
    }
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (storiesCollection.isRiverView) {
        [params setObject:[appDelegate extractFolderName:storiesCollection.activeFolder] forKey:@"folder_name"];
        [params setObject:[appDelegate extractParentFolderName:storiesCollection.activeFolder] forKey:@"in_folder"];
        [params setObject:newTitle forKey:@"new_folder_name"];
    } else {
        [params setObject:[storiesCollection.activeFeed objectForKey:@"id"] forKey:@"feed_id"];
        [params setObject:newTitle forKey:@"feed_title"];
    }
    
    [self.appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self.appDelegate reloadFeedsView:YES];
        if (self.storiesCollection.isRiverView) {
            [self.appDelegate renameFolder:newTitle];
        } else {
            [self.appDelegate renameFeed:newTitle];
        }
        [self.view setNeedsDisplay];
        if (!self.isPhoneOrCompact) {
            self.appDelegate.detailViewController.navigationItem.titleView = [self.appDelegate makeFeedTitle:self.storiesCollection.activeFeed];
        } else {
            self.navigationItem.titleView = [self.appDelegate makeFeedTitle:self.storiesCollection.activeFeed];
        }
        [self.navigationController.view setNeedsDisplay];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (void)deleteSite {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Deleting...";
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/delete_feed",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[storiesCollection.activeFeed objectForKey:@"id"] forKey:@"feed_id"];
    [params setObject:[appDelegate extractFolderName:storiesCollection.activeFolder] forKey:@"in_folder"];
    
    [self.appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self.appDelegate reloadFeedsView:YES];
        [self.appDelegate showColumn:UISplitViewControllerColumnPrimary debugInfo:@"deleteSite" animated:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (void)deleteFolder {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Deleting...";
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/delete_folder",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[appDelegate extractFolderName:storiesCollection.activeFolder]
               forKey:@"folder_to_delete"];
    [params setObject:[appDelegate extractFolderName:[appDelegate
                                                      extractParentFolderName:storiesCollection.activeFolder]]
               forKey:@"in_folder"];
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self.appDelegate reloadFeedsView:YES];
        [self.appDelegate showColumn:UISplitViewControllerColumnPrimary debugInfo:@"deleteFolder" animated:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (IBAction)muteSite {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Muting...";

    NSString *feedId = [NSString stringWithFormat:@"%@", storiesCollection.activeFeed[@"id"]];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/set_feed_mute", self.appDelegate.url];

    [params setObject:feedId forKey:@"feed_id"];
    [params setObject:@"true" forKey:@"mute"];
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self.appDelegate reloadFeedsView:YES];
        [self.appDelegate showColumn:UISplitViewControllerColumnPrimary debugInfo:@"muteSite" animated:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (IBAction)unmuteSite {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Unmuting...";

    NSString *feedId = [NSString stringWithFormat:@"%@", storiesCollection.activeFeed[@"id"]];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/set_feed_mute", self.appDelegate.url];

    [params setObject:feedId forKey:@"feed_id"];
    [params setObject:@"false" forKey:@"mute"];
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self.appDelegate reloadFeedsView:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (void)performNewFolder {
    NSString *title = @"Move to New Folder";
    NSString *subtitle = @"Enter the name of the new folder.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:subtitle preferredStyle:UIAlertControllerStyleAlert];
    [alert setModalPresentationStyle:UIModalPresentationPopover];
    UIAlertAction *move = [UIAlertAction actionWithTitle:@"Move" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *name = alert.textFields.firstObject.text;
        [self addNewFolderWithName:name];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    [alert addAction:move];
    [alert addAction:cancel];
    
    if (self.presentedViewController) {
        [self.presentedViewController dismissViewControllerAnimated:NO completion:^{
            [self presentViewController:alert animated:YES completion:nil];
        }];
    } else {
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)addNewFolderWithName:(NSString *)folderName {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSString *urlString;
    
    HUD.labelText = @"Adding folder...";
    urlString = [NSString stringWithFormat:@"%@/reader/add_folder", self.appDelegate.url];
    [params setObject:folderName forKey:@"folder"];
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        
        int code = [[responseObject valueForKey:@"code"] intValue];
        if (code != -1) {
            [self performMoveToFolder:folderName];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (void)performMoveToFolder:(id)toFolder {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSString *urlString;
    
    if (self.appDelegate.storiesCollection.isRiverView) {
        HUD.labelText = @"Moving folder...";
        urlString = [NSString stringWithFormat:@"%@/reader/move_folder_to_folder", self.appDelegate.url];
        NSString *activeFolder = self.appDelegate.storiesCollection.activeFolder;
        NSString *parentFolderName = [self.appDelegate extractParentFolderName:activeFolder];
        NSString *fromFolder = [self.appDelegate extractFolderName:parentFolderName];
        NSString *toFolderIdentifier = [self.appDelegate extractFolderName:toFolder];
        NSString *folderName = [self.appDelegate extractFolderName:activeFolder];
        [params setObject:fromFolder forKey:@"in_folder"];
        [params setObject:toFolderIdentifier forKey:@"to_folder"];
        [params setObject:folderName forKey:@"folder_name"];
    } else {
        HUD.labelText = @"Moving site...";
        urlString = [NSString stringWithFormat:@"%@/reader/move_feed_to_folder", self.appDelegate.url];
        NSString *fromFolder = [self.appDelegate extractFolderName:self.appDelegate.storiesCollection.activeFolder];
        NSString *toFolderIdentifier = [self.appDelegate extractFolderName:toFolder];
        NSString *feedIdentifier = [self.appDelegate.storiesCollection.activeFeed objectForKey:@"id"];
        [params setObject:fromFolder forKey:@"in_folder"];
        [params setObject:toFolderIdentifier forKey:@"to_folder"];
        [params setObject:feedIdentifier forKey:@"feed_id"];
    }
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        
        int code = [[responseObject valueForKey:@"code"] intValue];
        if (code != -1) {
            self.appDelegate.storiesCollection.activeFolder = toFolder;
            [self.appDelegate reloadFeedsView:NO];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (void)openMoveView:(UINavigationController *)menuNavigationController {
    MenuViewController *viewController = [MenuViewController new];
    viewController.title = @"Move To";
    
    __weak __typeof(&*self)weakSelf = self;
    
    [viewController addTitle:@"New Folder" iconName:@"add_tag.png" selectionShouldDismiss:YES handler:^{
        [weakSelf performNewFolder];
    }];
    
    for (NSString *folder in self.appDelegate.dictFoldersArray) {
        NSString *title = folder;
        NSString *iconName = @"menu_icn_move.png";
        
        if (![title hasPrefix:@"river_"] && ![title hasSuffix:@"_stories"] && ![title hasPrefix:@"saved_"]) {
            if ([title isEqualToString:@"everything"]) {
                title = @"Top Level";
                iconName = @"menu_icn_all.png";
            } else if ([title isEqualToString:@"dashboard"] || [title isEqualToString:@"infrequent"]) {
                continue;
            } else {
                NSArray *components = [title componentsSeparatedByString:@" ▸ "];
                title = components.lastObject;
                for (NSUInteger idx = 0; idx < components.count; idx++) {
                    title = [@"\t\t" stringByAppendingString:title];
                }
            }
            
            [viewController addTitle:title iconName:iconName selectionShouldDismiss:YES handler:^{
                [weakSelf performMoveToFolder:folder];
            }];
        }
    }
    
    [menuNavigationController showViewController:viewController sender:self];
}

- (IBAction)openTrainSite {
    [appDelegate openTrainSite];
}

- (void)toggleHiddenStories {
    appDelegate.storiesCollection.showHiddenStories = !appDelegate.storiesCollection.showHiddenStories;
    [appDelegate.storiesCollection calculateStoryLocations];
    [self reload];
}

- (IBAction)openNotifications:(id)sender {
    NSString *feedIdStr = storiesCollection.activeFeedIdStr;
    
    [appDelegate openNotificationsWithFeed:feedIdStr];
}

- (void)openNotificationsWithFeed:(NSString *)feedId {
    [appDelegate openNotificationsWithFeed:feedId];
}

- (IBAction)openStatistics:(id)sender {
    NSString *feedIdStr = storiesCollection.activeFeedIdStr;
    
    [appDelegate openStatisticsWithFeed:feedIdStr sender:settingsBarButton];
}

- (void)openStatisticsWithFeed:(NSString *)feedId {
    [appDelegate openStatisticsWithFeed:feedId sender:settingsBarButton];
}

- (IBAction)openRenameSite {
    NSString *title = [NSString stringWithFormat:@"Rename \"%@\"", appDelegate.storiesCollection.isRiverView ?
                       [appDelegate extractFolderName:appDelegate.storiesCollection.activeFolder] : [appDelegate.storiesCollection.activeFeed objectForKey:@"feed_title"]];
    NSString *subtitle = (appDelegate.storiesCollection.isRiverView ?
                          nil : [appDelegate.storiesCollection.activeFeed objectForKey:@"feed_address"]);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:subtitle preferredStyle:UIAlertControllerStyleAlert];
    [alert setModalPresentationStyle:UIModalPresentationPopover];
    UIAlertAction *rename = [UIAlertAction actionWithTitle:@"Rename" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *newTitle = alert.textFields[0].text;
        [self renameTo:newTitle];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = self.appDelegate.storiesCollection.isRiverView ?
        [self.appDelegate extractFolderName:self.appDelegate.storiesCollection.activeFolder] :
        [self.appDelegate.storiesCollection.activeFeed objectForKey:@"feed_title"];
    }];
    [alert addAction:rename];
    [alert addAction:cancel];
    
    if (self.presentedViewController) {
        [self.presentedViewController dismissViewControllerAnimated:NO completion:^{
            [self presentViewController:alert animated:YES completion:nil];
        }];
    } else {
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)showUserProfile {
    appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@",
                                       [storiesCollection.activeFeed objectForKey:@"user_id"]];
    appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@",
                                         [storiesCollection.activeFeed objectForKey:@"username"]];
    [appDelegate showUserProfileModal:titleImageBarButton];
}

- (void)changeActiveFeedDetailRow {
    if (!self.isLegacyTable) {
        [self reload];
        return;
    }
    
    NSInteger rowIndex = [storiesCollection locationOfActiveStory];
    NSInteger offset = 1;
    if ([[self.storyTitlesTable visibleCells] count] <= 4) {
        offset = 0;
    }
    if (offset > rowIndex) offset = rowIndex;
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    NSIndexPath *offsetIndexPath = [NSIndexPath indexPathForRow:(rowIndex - offset) inSection:0];
    NSIndexPath *oldIndexPath = storyTitlesTable.indexPathForSelectedRow;
    
    if (indexPath.row >= [self.storyTitlesTable numberOfRowsInSection:0]) {
        NSLog(@"⚠️ Tried to access row %@ when there are only %@ currently", @(indexPath.row), @([self.storyTitlesTable numberOfRowsInSection:0]));  // log
        return;
    }
    
    if (![indexPath isEqual:oldIndexPath]) {
        [self tableView:storyTitlesTable deselectRowAtIndexPath:oldIndexPath animated:YES];
        [self tableView:storyTitlesTable selectRowAtIndexPath:indexPath animated:YES];
    }
    
    // check to see if the cell is completely visible
    CGRect cellRect = [storyTitlesTable rectForRowAtIndexPath:indexPath];
    
    cellRect = [storyTitlesTable convertRect:cellRect toView:storyTitlesTable.superview];
    
    BOOL completelyVisible = CGRectContainsRect(storyTitlesTable.frame, cellRect);
    if (!completelyVisible && [storyTitlesTable numberOfRowsInSection:0] > 0) {
        [storyTitlesTable scrollToRowAtIndexPath:offsetIndexPath 
                                atScrollPosition:UITableViewScrollPositionTop 
                                        animated:YES];
    }
}

- (void)updateTheme {
    [super updateTheme];

    [self applyToolbarButtonTint];
    
    UIColor *toolbarButtonTint = UIColorFromLightSepiaMediumDarkRGB(0x8F918B, 0x8B7B6B, 0x404040, 0x6F6F75);
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] initWithIdiom:[[UIDevice currentDevice] userInterfaceIdiom]];
    appearance.backgroundColor = [UINavigationBar appearance].barTintColor;
    appearance.titleTextAttributes = [UINavigationBar appearance].titleTextAttributes;
    if (@available(iOS 13.0, *)) {
        UIBarButtonItemAppearance *buttonAppearance = [[UIBarButtonItemAppearance alloc] init];
        NSDictionary *textAttributes = @{NSForegroundColorAttributeName: toolbarButtonTint};
        [buttonAppearance.normal setTitleTextAttributes:textAttributes];
        [buttonAppearance.highlighted setTitleTextAttributes:textAttributes];
        [buttonAppearance.disabled setTitleTextAttributes:textAttributes];
        appearance.buttonAppearance = buttonAppearance;
        appearance.backButtonAppearance = buttonAppearance;
        appearance.doneButtonAppearance = buttonAppearance;
    }
    
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.compactAppearance = appearance;
    self.navigationController.navigationBar.tintColor = toolbarButtonTint;
    self.navigationController.navigationBar.barTintColor = [UINavigationBar appearance].barTintColor;
    self.navigationController.navigationBar.barStyle = ThemeManager.shared.isDarkTheme ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.toolbar.barTintColor = [UINavigationBar appearance].barTintColor;
    
    if (self.isPhoneOrCompact) {
        self.navigationItem.titleView = [appDelegate makeFeedTitle:storiesCollection.activeFeed];
    }
    
#if !TARGET_OS_MACCATALYST
    self.refreshControl.tintColor = UIColorFromLightDarkRGB(0x0, 0xffffff);
    self.refreshControl.backgroundColor = UIColorFromRGB(0xE3E6E0);
#endif
    
    self.searchBar.backgroundColor = UIColorFromRGB(0xE3E6E0);
    self.searchBar.tintColor = UIColorFromRGB(0xffffff);
    self.searchBar.nb_searchField.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    self.searchBar.nb_searchField.tintColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    
    self.appDelegate.detailViewController.navigationItem.titleView = [appDelegate makeFeedTitle:storiesCollection.activeFeed];
    
    if ([ThemeManager themeManager].isDarkTheme) {
        self.storyTitlesTable.indicatorStyle = UIScrollViewIndicatorStyleWhite;
        self.searchBar.keyboardAppearance = UIKeyboardAppearanceDark;
    } else {
        self.storyTitlesTable.indicatorStyle = UIScrollViewIndicatorStyleBlack;
        self.searchBar.keyboardAppearance = UIKeyboardAppearanceDefault;
    }
    
    self.view.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.storyTitlesTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.storyTitlesTable.separatorColor = UIColorFromRGB(0xE9E8E4);
    if (@available(iOS 13.0, *)) {
        self.storyTitlesTable.overrideUserInterfaceStyle = ThemeManager.shared.isDarkTheme ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    }

    [self reload];
}

- (void)applyToolbarButtonTint {
    UIColor *toolbarButtonTint = UIColorFromLightSepiaMediumDarkRGB(0x8F918B, 0x8B7B6B, 0x404040, 0x6F6F75);

    self.feedsBarButton.tintColor = toolbarButtonTint;
    if (self.sidebarBarButton) {
        self.sidebarBarButton.tintColor = toolbarButtonTint;
    }
    self.settingsBarButton.tintColor = toolbarButtonTint;
    self.feedMarkReadButton.tintColor = toolbarButtonTint;
    UIButton *settingsButton = (UIButton *)self.settingsBarButton.customView;
    if ([settingsButton isKindOfClass:[UIButton class]]) {
        settingsButton.tintColor = toolbarButtonTint;
    }
    UIButton *markReadButton = (UIButton *)self.feedMarkReadButton.customView;
    if ([markReadButton isKindOfClass:[UIButton class]]) {
        markReadButton.tintColor = toolbarButtonTint;
    }
    self.navigationController.navigationBar.tintColor = toolbarButtonTint;
    self.navigationController.toolbar.tintColor = toolbarButtonTint;
}

//- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
//    NSLog(@"canPerformAction: %@ withSender: %@", NSStringFromSelector(action), sender);  // log
//    
//    if (action == @selector(deleteSite:)) {
//        return NO;
//    }
//
//    return YES;
//}

#pragma mark -
#pragma mark Story Actions - save

- (void)finishMarkAsSaved:(NSDictionary *)params {
    
}

- (void)failedMarkAsSaved:(NSDictionary *)params {
    [self informError:@"Failed to save story"];
    
    [self reload];
}

- (void)finishMarkAsUnsaved:(NSDictionary *)params {
    
}

- (void)failedMarkAsUnsaved:(NSDictionary *)params {
    [self informError:@"Failed to unsave story"];
    
    [self reload];
}

- (void)failedMarkAsUnread:(NSDictionary *)params {
    [self informError:@"Failed to unread story"];
    
    [self reload];
}

#pragma mark -
#pragma mark instafetchFeed

// called when the user taps refresh button

- (IBAction)instafetchFeed {
    NSString *urlString = [NSString
                           stringWithFormat:@"%@/reader/refresh_feed/%@",
                           self.appDelegate.url,
                           [storiesCollection.activeFeed objectForKey:@"id"]];
    [appDelegate GET:urlString parameters:nil success:^(NSURLSessionTask *task, id responseObject) {
        [self renderStories:[responseObject objectForKey:@"stories"]];
        [self finishRefresh];
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSLog(@"Fail: %@", error);
        [self informError:[operation error]];
        [self fetchFeedDetail:1 withCallback:nil];
        [self finishRefresh];
    }];
    
    [storiesCollection setStories:nil];
    storiesCollection.feedPage = 1;
    self.pageFetching = YES;
    [self reload];
    
    if (self.isLegacyTable) {
        [storyTitlesTable scrollRectToVisible:CGRectMake(0, CGRectGetHeight(self.searchBar.frame), 1, 1) animated:YES];
    }
}

- (IBAction)deleteSite:(id)sender {
    //TODO
}

#pragma mark -
#pragma mark PullToRefresh

- (BOOL)canPullToRefresh {
    BOOL river = appDelegate.storiesCollection.isRiverView;
    BOOL infrequent = appDelegate.storiesCollection.isInfrequent;
    BOOL read = appDelegate.storiesCollection.isReadView;
    BOOL widget = appDelegate.storiesCollection.isWidgetView;
    BOOL saved = appDelegate.storiesCollection.isSavedView;
    
    return appDelegate.storiesCollection.activeFeed != nil && !river && !infrequent && !saved && !read && !widget;
}

#if !TARGET_OS_MACCATALYST
- (void)refresh:(UIRefreshControl *)refreshControl {
    if (self.canPullToRefresh) {
        self.inPullToRefresh_ = YES;
        [self instafetchFeed];
    } else {
        [self finishRefresh];
    }
}
#endif

- (void)finishRefresh {
    self.inPullToRefresh_ = NO;
#if !TARGET_OS_MACCATALYST
    [self.refreshControl endRefreshing];
#endif
}

#pragma mark -
#pragma mark loadSocial Feeds

- (void)loadFaviconsFromActiveFeed {
    NSArray * keys = [appDelegate.dictActiveFeeds allKeys];
    
    if (![keys count]) {
        // if no new favicons, return
        return;
    }
    
    NSString *feedIdsQuery = [NSString stringWithFormat:@"?feed_ids=%@",
                              [[keys valueForKey:@"description"] componentsJoinedByString:@"&feed_ids="]];
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/favicons%@",
                           self.appDelegate.url,
                           feedIdsQuery];
    
    [appDelegate GET:urlString parameters:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self saveAndDrawFavicons:responseObject];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (void)saveAndDrawFavicons:(NSDictionary *)results {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0ul);
    dispatch_async(queue, ^{
        for (id feed_id in results) {
            NSMutableDictionary *feed = [[self.appDelegate.dictActiveFeeds objectForKey:feed_id] mutableCopy];
            [feed setValue:[results objectForKey:feed_id] forKey:@"favicon"];
            [self.appDelegate.dictActiveFeeds setValue:feed forKey:feed_id];
            
            NSString *favicon = [feed objectForKey:@"favicon"];
            if ((NSNull *)favicon != [NSNull null] && [favicon length] > 0) {
                NSData *imageData = [[NSData alloc] initWithBase64EncodedString:favicon options:NSDataBase64DecodingIgnoreUnknownCharacters];
                UIImage *faviconImage = [UIImage imageWithData:imageData];
                [self.appDelegate saveFavicon:faviconImage feedId:feed_id];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reload];
        });
    });
    
}

- (void)requestFailed:(NSError *)error {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSLog(@"Error: %@", error);
    [appDelegate informError:error];
}

#pragma mark - Drag Delegate

- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    NSDictionary *story = [self getStoryAtLocation:indexPath.row];
    
    if (!story) return @[];

    NSString *storyTitle = story[@"story_title"];
    NSString *storyPermalink = story[@"story_permalink"];
    UIImage *storyImage = nil;

    FeedDetailTableCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell.storyHash) {
        id cachedImage = appDelegate.cachedStoryImages[cell.storyHash];
        if (cachedImage && cachedImage != [NSNull null])
            storyImage = cachedImage;
    }

    NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:storyTitle
                                                                                        attributes:@{NSLinkAttributeName: storyPermalink}];
    if (storyImage) {
        NSTextAttachment *imageAttachment = [[NSTextAttachment alloc] init];
        imageAttachment.image = storyImage;
        NSAttributedString *imageString = [NSAttributedString attributedStringWithAttachment:imageAttachment];
        [attributedTitle insertAttributedString:imageString atIndex:0];
    }
    NSString *titleURLString = [NSString stringWithFormat:@"%@ <%@>", storyTitle, storyPermalink];
    NSItemProvider *itemProviderStory = [[NSItemProvider alloc] initWithObject:
                                         [[StoryTitleAttributedString alloc] initWithAttributedString:attributedTitle plainString:titleURLString]];
    [itemProviderStory registerObject:[NSURL URLWithString:storyPermalink] visibility:NSItemProviderRepresentationVisibilityAll];

    return @[[[UIDragItem alloc] initWithItemProvider:itemProviderStory]];
}

- (void)tableView:(UITableView *)tableView dragSessionWillBegin:(id<UIDragSession>)session API_AVAILABLE(ios(11.0)) {
    
}

- (void)tableView:(UITableView *)tableView dragSessionDidEnd:(id<UIDragSession>)session API_AVAILABLE(ios(11.0)) {
    
}

@end
