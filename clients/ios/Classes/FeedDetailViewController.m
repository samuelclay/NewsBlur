//
//  FeedDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "FeedDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NBContainerViewController.h"
#import "NewsBlurViewController.h"
#import "FeedDetailTableCell.h"
#import "UserProfileViewController.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "NSString+HTML.h"
#import "MBProgressHUD.h"
#import "SBJson4.h"
#import "NSObject+SBJSON.h"
#import "StringHelper.h"
#import "Utilities.h"
#import "UIBarButtonItem+Image.h"
#import "FeedDetailMenuViewController.h"
#import "MarkReadMenuViewController.h"
#import "NBNotifier.h"
#import "NBLoadingCell.h"
#import "FMDatabase.h"
#import "NBBarButtonItem.h"
#import "UIImage+Resize.h"
#import "PINCache.h"
#import "DashboardViewController.h"
#import "StoriesCollection.h"
#import "NSNull+JSON.h"
#import "UISearchBar+Field.h"
#import "MenuViewController.h"
#import "StoryTitleAttributedString.h"

#define kTableViewRowHeight 46;
#define kTableViewRiverRowHeight 68;
#define kTableViewShortRowDifference 17;

@interface FeedDetailViewController ()

@property (nonatomic) NSUInteger scrollingMarkReadRow;

@end

@implementation FeedDetailViewController

@synthesize storyTitlesTable, feedMarkReadButton;
@synthesize settingsBarButton;
@synthesize separatorBarButton;
@synthesize titleImageBarButton;
@synthesize spacerBarButton, spacer2BarButton;
@synthesize appDelegate;
@synthesize pageFetching;
@synthesize pageFinished;
@synthesize finishedAnimatingIn;
@synthesize notifier;
@synthesize searchBar;
@synthesize isOnline;
@synthesize isShowingFetching;
@synthesize isDashboardModule;
@synthesize storiesCollection;
@synthesize showContentPreview;
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

    self.storyTitlesTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.storyTitlesTable.separatorColor = UIColorFromRGB(0xE9E8E4);
    if (@available(iOS 11.0, *)) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.storyTitlesTable.dragDelegate = self;
            self.storyTitlesTable.dragInteractionEnabled = YES;
        }
    }
    self.view.backgroundColor = UIColorFromRGB(0xf4f4f4);

    spacerBarButton = [[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spacerBarButton.width = 0;
    spacer2BarButton = [[UIBarButtonItem alloc]
                        initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spacer2BarButton.width = 0;
    
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
    
    UIImage *separatorImage = [UIImage imageNamed:@"bar-separator.png"];
    if ([ThemeManager themeManager].isDarkTheme) {
        separatorImage = [UIImage imageNamed:@"bar_separator_dark"];
    }
    separatorBarButton = [UIBarButtonItem barItemWithImage:separatorImage target:nil action:nil];
    [separatorBarButton setEnabled:NO];
    separatorBarButton.isAccessibilityElement = NO;
    
    UIImage *settingsImage = [UIImage imageNamed:@"nav_icn_settings.png"];
    settingsBarButton = [UIBarButtonItem barItemWithImage:settingsImage target:self action:@selector(doOpenSettingsMenu:)];
    settingsBarButton.accessibilityLabel = @"Settings";
    
    UIImage *markreadImage = [UIImage imageNamed:@"markread.png"];
    feedMarkReadButton = [UIBarButtonItem barItemWithImage:markreadImage target:self action:@selector(doOpenMarkReadMenu:)];
    feedMarkReadButton.accessibilityLabel = @"Mark all as read";
    
    UIView *view = [feedMarkReadButton valueForKey:@"view"];
    UILongPressGestureRecognizer *markReadLongPress = [[UILongPressGestureRecognizer alloc]
                                               initWithTarget:self action:@selector(handleMarkReadLongPress:)];
    markReadLongPress.minimumPressDuration = 1.0;
    markReadLongPress.delegate = self;
    [view addGestureRecognizer:markReadLongPress];
    
    titleImageBarButton = [UIBarButtonItem alloc];

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
    
    [[ThemeManager themeManager] addThemeGestureRecognizerToView:self.storyTitlesTable];
    
    self.notifier = [[NBNotifier alloc] initWithTitle:@"Fetching stories..."];
    [self.view addSubview:self.notifier];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:NOTIFIER_HEIGHT]];
    self.notifier.topOffsetConstraint = [NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];
    [self.view addConstraint:self.notifier.topOffsetConstraint];
}


- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    //    NSLog(@"Gesture double tap: %ld - %ld", touch.tapCount, gestureRecognizer.state);
    inDoubleTap = (touch.tapCount == 2);
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    //    NSLog(@"Gesture should multiple? %ld (%ld) - %d", gestureRecognizer.state, UIGestureRecognizerStateEnded, inDoubleTap);
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded && inDoubleTap) {
        CGPoint p = [gestureRecognizer locationInView:self.storyTitlesTable];
        NSIndexPath *indexPath = [self.storyTitlesTable indexPathForRowAtPoint:p];
        NSDictionary *story = [self getStoryAtRow:indexPath.row];
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
        } else {
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
            [self reloadData];
        } else if (saveStory) {
            [storiesCollection toggleStorySaved:story];
            [self reloadData];
        }
        inDoubleTap = NO;
    }
    return YES;
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
        [self reloadStories];
    } else {
        storiesCollection.inSearch = NO;
        storiesCollection.searchQuery = nil;
        [self reloadStories];
    }
}

- (void)preferredContentSizeChanged:(NSNotification *)aNotification {
    appDelegate.fontDescriptorTitleSize = nil;

    [self.storyTitlesTable reloadData];
}

- (void)reloadData {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    self.showContentPreview = [userPreferences boolForKey:@"story_list_preview_description"];
    self.showImagePreview = [userPreferences boolForKey:@"story_list_preview_images"];
    
    appDelegate.fontDescriptorTitleSize = nil;
    self.scrollingMarkReadRow = NSNotFound;
    
    [self.storyTitlesTable reloadData];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [self.storyTitlesTable reloadData];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        [self setUserAvatarLayout:orientation];
        [self.notifier setNeedsLayout];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self checkScroll];
        NSLog(@"Feed detail did re-orient.");
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    [self setUserAvatarLayout:orientation];
    self.finishedAnimatingIn = NO;
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    self.messageView.hidden = YES;
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    self.showContentPreview = [userPreferences boolForKey:@"story_list_preview_description"];
    self.showImagePreview = [userPreferences boolForKey:@"story_list_preview_images"];
    
    // set right avatar title image
    spacerBarButton.width = 0;
    spacer2BarButton.width = 0;
    if (!self.isPhoneOrCompact) {
        spacerBarButton.width = -6;
        spacer2BarButton.width = 10;
    }
    if (storiesCollection.isSocialView) {
        spacerBarButton.width = -6;
        NSString *feedIdStr = [NSString stringWithFormat:@"%@", [storiesCollection.activeFeed objectForKey:@"id"]];
        UIImage *titleImage  = [appDelegate getFavicon:feedIdStr isSocial:YES];
        titleImage = [Utilities roundCorneredImage:titleImage radius:6];
        [((UIButton *)titleImageBarButton.customView).imageView removeFromSuperview];
        titleImageBarButton = [UIBarButtonItem barItemWithImage:titleImage
                                                         target:self
                                                         action:@selector(showUserProfile)];
        titleImageBarButton.customView.frame = CGRectMake(0, 0, 32, 32);
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:
                                                   spacerBarButton,
                                                   titleImageBarButton,
                                                   spacer2BarButton,
                                                   separatorBarButton,
                                                   feedMarkReadButton, nil];
    } else {
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:
                                                   spacerBarButton,
                                                   settingsBarButton,
                                                   spacer2BarButton,
                                                   separatorBarButton,
                                                   feedMarkReadButton,
                                                   nil];
    }
    
    // set center title
    if (self.isPhoneOrCompact &&
        !self.navigationItem.titleView) {
        self.navigationItem.titleView = [appDelegate makeFeedTitle:storiesCollection.activeFeed];
    }
    
    if ([storiesCollection.activeFeedStories count]) {
        [self.storyTitlesTable reloadData];
    }
    
    appDelegate.originalStoryCount = (int)[appDelegate unreadCount];
    self.scrollingMarkReadRow = NSNotFound;
    
    if ((storiesCollection.isSocialRiverView ||
         storiesCollection.isSocialView)) {
        settingsBarButton.enabled = NO;
    } else {
        settingsBarButton.enabled = YES;
    }
    
    if (storiesCollection.isSocialRiverView ||
        storiesCollection.isSavedView ||
        storiesCollection.isReadView) {
        feedMarkReadButton.enabled = NO;
    } else {
        feedMarkReadButton.enabled = YES;
    }
        
    if (self.isPhoneOrCompact) {
        [self fadeSelectedCell:NO];
    }
    
    [self.notifier setNeedsLayout];
    [appDelegate hideShareView:YES];
    
    if (!isDashboardModule &&
        !self.isPhoneOrCompact &&
        (appDelegate.masterContainerViewController.storyTitlesOnLeft ||
         !UIInterfaceOrientationIsPortrait(orientation)) &&
        !self.isMovingFromParentViewController &&
        !appDelegate.masterContainerViewController.interactiveOriginalTransition) {
        [appDelegate.masterContainerViewController transitionToFeedDetail:NO];
    }
    
    if (!storiesCollection.inSearch && storiesCollection.feedPage == 1) {
        [self.storyTitlesTable setContentOffset:CGPointMake(0, CGRectGetHeight(self.searchBar.frame))];
    }
    if (storiesCollection.inSearch && storiesCollection.searchQuery) {
        [self.searchBar setText:storiesCollection.searchQuery];
        [self.storyTitlesTable setContentOffset:CGPointMake(0, 0)];
        [self.searchBar becomeFirstResponder];
    } else {
        [self.searchBar setText:@""];
    }
    if ([self.searchBar.text length]) {
        [self.searchBar setShowsCancelButton:YES animated:YES];
    } else {
        [self.searchBar setShowsCancelButton:NO animated:YES];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (appDelegate.inStoryDetail && self.isPhoneOrCompact) {
        appDelegate.inStoryDetail = NO;
//        [appDelegate.storyPageControl resetPages];
        [self checkScroll];
    }
    
    if (invalidateFontCache) {
        invalidateFontCache = NO;
        [self reloadData];
    }
    
    self.finishedAnimatingIn = YES;
    if ([storiesCollection.activeFeedStories count] ||
        self.isDashboardModule) {
        [self.storyTitlesTable reloadData];
    }
    
    if (self.isPhoneOrCompact) {
        [self fadeSelectedCell:YES];
    }

    [self.notifier setNeedsLayout];
    
    [self testForTryFeed];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.searchBar resignFirstResponder];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self.searchBar resignFirstResponder];
    [self.appDelegate hidePopoverAnimated:YES];
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    if (self.isMovingToParentViewController) {
        appDelegate.inFindingStoryMode = NO;
        appDelegate.tryFeedStoryId = nil;
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }
    
    if (!self.isPhoneOrCompact &&
        self.isMovingToParentViewController &&
        (appDelegate.masterContainerViewController.storyTitlesOnLeft ||
         !UIInterfaceOrientationIsPortrait(orientation))) {
        [appDelegate.masterContainerViewController transitionFromFeedDetail:NO];
    }
}

- (void)fadeSelectedCell {
    [self fadeSelectedCell:YES];
}

- (void)fadeSelectedCell:(BOOL)deselect {
    [self.storyTitlesTable reloadData];
    NSInteger location = storiesCollection.locationOfActiveStory;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:location inSection:0];
    
    if (indexPath && location >= 0) {
        [self.storyTitlesTable selectRowAtIndexPath:indexPath
                                           animated:NO
                                     scrollPosition:UITableViewScrollPositionNone];
        if (deselect) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,  0.1 * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^(void) {
                [self.storyTitlesTable deselectRowAtIndexPath:indexPath
                                                     animated:YES];
            });
        }
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
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone || self.appDelegate.isCompactWidth;
}

#pragma mark -
#pragma mark Initialization

- (void)resetFeedDetail {
    appDelegate.hasLoadedFeedDetail = NO;
    self.navigationItem.titleView = nil;
    self.pageFetching = NO;
    self.pageFinished = NO;
    self.isOnline = YES;
    self.isShowingFetching = NO;
//    self.feedPage = 1;
    appDelegate.activeStory = nil;
    [storiesCollection setStories:nil];
    [storiesCollection setFeedUserProfiles:nil];
    storiesCollection.storyCount = 0;
    if (!self.isDashboardModule) {
        [appDelegate.storyPageControl resetPages];
    }
    storiesCollection.inSearch = NO;
    storiesCollection.searchQuery = nil;
    [self.searchBar setText:@""];
    [self.notifier hideIn:0];
//    [self cancelRequests];
    [self beginOfflineTimer];
    [appDelegate.cacheImagesOperationQueue cancelAllOperations];
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
    self.isOnline = YES;
    self.isShowingFetching = NO;
    
    if (storiesCollection.isRiverView) {
        [self fetchRiverPage:1 withCallback:nil];
    } else {
        [self fetchFeedDetail:1 withCallback:nil];
    }

    [self.storyTitlesTable reloadData];
    [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
}

- (void)beginOfflineTimer {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (self.isDashboardModule ? 3 : 1) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!storiesCollection.storyLocationsCount && !self.pageFinished &&
            storiesCollection.feedPage == 1 && self.isOnline) {
            self.isShowingFetching = YES;
            self.isOnline = NO;
            [self showLoadingNotifier];
            [self loadOfflineStories];
        }
    });
}

- (void)cacheStoryImages:(NSArray *)storyImageUrls {
    NSBlockOperation *cacheImagesOperation = [NSBlockOperation blockOperationWithBlock:^{
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        [manager.requestSerializer setTimeoutInterval:5];
        manager.responseSerializer = [AFImageResponseSerializer serializer];

        for (NSString *storyImageUrl in storyImageUrls) {
//            NSLog(@"Fetching image: %@", storyImageUrl);
            [manager GET:storyImageUrl parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                UIImage *image = (UIImage *)responseObject;
                
                if (!image || image.size.height < 50 || image.size.width < 50) {
                    [appDelegate.cachedStoryImages setObject:[NSNull null]
                                                      forKey:storyImageUrl];
                    return;
                }
                
                CGSize maxImageSize = CGSizeMake(300, 300);
                image = [image imageByScalingAndCroppingForSize:maxImageSize];
                [appDelegate.cachedStoryImages setObject:image
                                                  forKey:storyImageUrl];
                if (self.isDashboardModule) {
                    [appDelegate.dashboardViewController.storiesModule
                     showStoryImage:storyImageUrl];
                } else {
                    [appDelegate.feedDetailViewController
                     showStoryImage:storyImageUrl];
                }
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                
            }];
        }
    }];
    [cacheImagesOperation setQualityOfService:NSQualityOfServiceBackground];
    [cacheImagesOperation setQueuePriority:NSOperationQueuePriorityVeryLow];
    [appDelegate.cacheImagesOperationQueue addOperation:cacheImagesOperation];
}

- (void)showStoryImage:(NSString *)imageUrl {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isDashboardModule &&
            appDelegate.navigationController.visibleViewController == appDelegate.feedDetailViewController) {
            return;
        }
        
        for (FeedDetailTableCell *cell in [self.storyTitlesTable visibleCells]) {
            if (![cell isKindOfClass:[FeedDetailTableCell class]]) return;
            if ([cell.storyImageUrl isEqualToString:imageUrl]) {
                NSIndexPath *indexPath = [self.storyTitlesTable indexPathForCell:cell];
//                NSLog(@"Reloading cell (dashboard? %d): %@ (%ld)", self.isDashboardModule, cell.storyTitle, (long)indexPath.row);
                [self.storyTitlesTable beginUpdates];
                [self.storyTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                             withRowAnimation:UITableViewRowAnimationNone];
                [self.storyTitlesTable endUpdates];
                break;
            }
        }
    });
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
        [self.storyTitlesTable reloadData];
        [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    }
    if (storiesCollection.feedPage == 1) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                 (unsigned long)NULL), ^(void) {
            [appDelegate.database inDatabase:^(FMDatabase *db) {
                [appDelegate prepareActiveCachedImages:db];
            }];
        });
    }
    if (!storiesCollection.inSearch && storiesCollection.feedPage == 1) {
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
//    [self cancelRequests];
    NSString *feedId = [NSString stringWithFormat:@"%@", [[storiesCollection activeFeed] objectForKey:@"id"]];
    NSInteger feedPage = storiesCollection.feedPage;
    NSLog(@" ---> Loading feed url: %@", theFeedDetailURL);
    [appDelegate.networkManager GET:theFeedDetailURL parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        if (!storiesCollection.activeFeed) return;
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
        
        [self.storyTitlesTable reloadData];
    }];
}

- (void)loadOfflineStories {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
    [appDelegate.database inDatabase:^(FMDatabase *db) {
        NSArray *feedIds;
        NSInteger limit = 12;
        NSInteger offset = (storiesCollection.feedPage - 1) * limit;
        
        if (storiesCollection.isRiverView) {
            feedIds = storiesCollection.activeFolderFeeds;
        } else if (storiesCollection.activeFeed) {
            feedIds = @[[storiesCollection.activeFeed objectForKey:@"id"]];
        } else {
            return;
        }
        
        NSString *orderSql;
        if ([storiesCollection.activeOrder isEqualToString:@"oldest"]) {
            orderSql = @"ASC";
        } else {
            orderSql = @"DESC";
        }
        NSString *readFilterSql;
        if ([storiesCollection.activeReadFilter isEqualToString:@"unread"]) {
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
        
        if ([storiesCollection.activeReadFilter isEqualToString:@"all"]) {
            NSString *unreadHashSql = [NSString stringWithFormat:@"SELECT s.story_hash FROM stories s INNER JOIN unread_hashes uh ON s.story_hash = uh.story_hash WHERE s.story_feed_id IN (%@)",
                             [feedIds componentsJoinedByString:@","]];
            FMResultSet *unreadHashCursor = [db executeQuery:unreadHashSql];
            NSMutableDictionary *unreadStoryHashes;
            if (storiesCollection.feedPage == 1) {
                unreadStoryHashes = [NSMutableDictionary dictionary];
            } else {
                unreadStoryHashes = appDelegate.unreadStoryHashes;
            }
            while ([unreadHashCursor next]) {
                [unreadStoryHashes setObject:[NSNumber numberWithBool:YES] forKey:[unreadHashCursor objectForColumnName:@"story_hash"]];
            }
            appDelegate.unreadStoryHashes = unreadStoryHashes;
            [unreadHashCursor close];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.isOnline) {
                NSLog(@"Online before offline rendered. Tossing offline stories.");
                return;
            }
            if (![offlineStories count]) {
                self.pageFinished = YES;
                [self.storyTitlesTable reloadData];
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

    storiesCollection.feedPage = page;
    self.pageFetching = YES;
    NSInteger storyCount = storiesCollection.storyCount;
    if (storyCount == 0) {
        [self.storyTitlesTable reloadData];
        [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
//            [self.notifier initWithTitle:@"Loading more..." inView:self.view];

    }
    
    if (!storiesCollection.inSearch && storiesCollection.feedPage == 1) {
        [self.storyTitlesTable setContentOffset:CGPointMake(0, CGRectGetHeight(self.searchBar.frame))];
    }
    if (storiesCollection.feedPage == 1) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                 (unsigned long)NULL), ^(void) {
            [appDelegate.database inDatabase:^(FMDatabase *db) {
                [appDelegate prepareActiveCachedImages:db];
            }];
        });
    }
    
    if (!self.isOnline) {
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

//    [self cancelRequests];
    
    
    [appDelegate.networkManager GET:theFeedDetailURL parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        [self finishedLoadingFeed:responseObject feedPage:storiesCollection.feedPage feedId:nil];
        if (callback) {
            callback();
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)operation.response;
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
    }];
}

#pragma mark -
#pragma mark Processing Stories

- (void)finishedLoadingFeed:(NSDictionary *)results feedPage:(NSInteger)feedPage feedId:(NSString *)sentFeedId {
    appDelegate.hasLoadedFeedDetail = YES;
    self.isOnline = YES;
    self.isShowingFetching = NO;
    // storiesCollection.feedPage = [[request.userInfo objectForKey:@"feedPage"] intValue];
    
//    if (storiesCollection.isSavedView &&
//        ![[results objectForKey:@"stories"] count] &&
//        storiesCollection.feedPage == 1 &&
//        [results objectForKey:@"message"]) {
//        [self informError:nil details:[results objectForKey:@"message"]];
//    }
    NSString *receivedFeedId = [NSString stringWithFormat:@"%@", [results objectForKey:@"feed_id"]];
    
    if (!(storiesCollection.isRiverView ||
          storiesCollection.isSavedView ||
          storiesCollection.isReadView ||
          storiesCollection.isSocialView ||
          storiesCollection.isSocialRiverView)
        && ![receivedFeedId isEqualToString:sentFeedId]) {
        return;
    }
    if (storiesCollection.isSocialView ||
        storiesCollection.isSocialRiverView ||
        storiesCollection.isSavedView ||
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
    if (storiesCollection.feedPage == 1) {
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

    self.pageFinished = NO;
    [self renderStories:confirmedNewStories];
    
    if (!self.isPhoneOrCompact && !self.isDashboardModule) {
        [appDelegate.storyPageControl resizeScrollView];
        [appDelegate.storyPageControl setStoryFromScroll:YES];
    }
    [appDelegate.storyPageControl advanceToNextUnread];
    
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
        [storyTitlesTable setContentOffset:CGPointZero animated:YES];
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
        [appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
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

    [self.storyTitlesTable reloadData];
    
    
    if (self.finishedAnimatingIn) {
        [self testForTryFeed];
    }
    
    if (!self.isPhoneOrCompact) {
        [appDelegate.masterContainerViewController syncNextPreviousButtons];
    }
    
    NSMutableArray *storyImageUrls = [NSMutableArray array];
    for (NSDictionary *story in newStories) {
        if ([story objectForKey:@"image_urls"] && [[story objectForKey:@"image_urls"] count]) {
            [storyImageUrls addObject:[[[story objectForKey:@"image_urls"] objectAtIndex:0]
                                       stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        }
    }
    [self performSelector:@selector(cacheStoryImages:) withObject:storyImageUrls afterDelay:0.2];

    self.pageFetching = NO;
}

- (void)testForTryFeed {
    if (self.isDashboardModule ||
        !appDelegate.inFindingStoryMode ||
        !appDelegate.tryFeedStoryId) return;
    
    if (!self.view.window) {
        NSLog(@"No longer looking for try feed.");
        appDelegate.inFindingStoryMode = NO;
        appDelegate.tryFeedStoryId = nil;
        return;
    }
    NSLog(@"Test for try feed");
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Finding story...";

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
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:locationOfStoryId inSection:0];
            
            [self.storyTitlesTable selectRowAtIndexPath:indexPath
                                               animated:NO
                                         scrollPosition:UITableViewScrollPositionMiddle];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                FeedDetailTableCell *cell = (FeedDetailTableCell *)[self.storyTitlesTable cellForRowAtIndexPath:indexPath];
                [self loadStory:cell atRow:indexPath.row];
            });
            
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            // found the story, reset the two flags.
            appDelegate.tryFeedStoryId = nil;
            appDelegate.inFindingStoryMode = NO;
        }
    }
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
    NSInteger height = 40;
    UITableViewCell *cell = [[UITableViewCell alloc]
                             initWithStyle:UITableViewCellStyleSubtitle
                             reuseIdentifier:@"NoReuse"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (self.pageFinished) {
        BOOL premiumRestriction = !appDelegate.isPremium &&
        storiesCollection.isRiverView &&
        !storiesCollection.isReadView &&
        !storiesCollection.isSocialView &&
        !storiesCollection.isSavedView;
        
        UIImage *img = [UIImage imageNamed:@"fleuron.png"];
        UIImageView *fleuron = [[UIImageView alloc] initWithImage:img];
        
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if (!self.isPhoneOrCompact
            && !appDelegate.masterContainerViewController.storyTitlesOnLeft
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
        }
        
        return cell;
    } else {//if ([appDelegate.storyLocationsCount]) {
        NBLoadingCell *loadingCell = [[NBLoadingCell alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, height)];
        return loadingCell;
    }
    
    return cell;
}

#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { 
    NSInteger storyCount = storiesCollection.storyLocationsCount;

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
    NSDictionary *story = [self getStoryAtRow:indexPath.row];
    
    id feedId = [story objectForKey:@"story_feed_id"];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
    
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
    
    cell.inDashboard = self.isDashboardModule;
    
    NSString *siteTitle = [feed objectForKey:@"feed_title"];
    cell.siteTitle = siteTitle; 

    NSString *title = [story objectForKey:@"story_title"];
    cell.storyTitle = [title stringByDecodingHTMLEntities];
    
    cell.storyDate = [story objectForKey:@"short_parsed_date"];
    cell.storyTimestamp = [[story objectForKey:@"story_timestamp"] integerValue];
    cell.isSaved = [[story objectForKey:@"starred"] boolValue];
    cell.isShared = [[story objectForKey:@"shared"] boolValue];
    cell.storyImageUrl = nil;
    if (self.showImagePreview &&
        [story objectForKey:@"image_urls"] && [[story objectForKey:@"image_urls"] count]) {
        cell.storyImageUrl = [[story objectForKey:@"image_urls"] objectAtIndex:0];
    }
    
    if ([[story objectForKey:@"story_authors"] class] != [NSNull class]) {
        cell.storyAuthor = [[[story objectForKey:@"story_authors"] uppercaseString] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    } else {
        cell.storyAuthor = @"";
    }
    
    cell.storyContent = nil;
    if (self.isDashboardModule || self.showContentPreview) {
        cell.storyContent = [[[story objectForKey:@"story_content"] convertHTML] stringByDecodingXMLEntities];
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
    
    cell.isShort = NO;
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (!self.isPhoneOrCompact &&
        !self.isDashboardModule &&
        !appDelegate.masterContainerViewController.storyTitlesOnLeft &&
        UIInterfaceOrientationIsPortrait(orientation)) {
        cell.isShort = YES;
    }
    
    cell.isRiverOrSocial = NO;
    if (storiesCollection.isRiverView ||
        storiesCollection.isSavedView ||
        storiesCollection.isReadView ||
        storiesCollection.isSocialView ||
        storiesCollection.isSocialRiverView) {
        cell.isRiverOrSocial = YES;
    }

    if (!self.isPhoneOrCompact && !self.isDashboardModule) {
        NSInteger rowIndex = [storiesCollection locationOfActiveStory];
        if (rowIndex == indexPath.row) {
            [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        } 
    }
    
    [cell setupGestures];
    
    [cell setNeedsDisplay];
    
    return cell;
}

- (void)loadStory:(FeedDetailTableCell *)cell atRow:(NSInteger)row {
    NSInteger storyIndex = [storiesCollection indexFromLocation:row];
    appDelegate.activeStory = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];
    if ([storiesCollection isStoryUnread:appDelegate.activeStory]) {
        [storiesCollection markStoryRead:appDelegate.activeStory];
        [storiesCollection syncStoryAsRead:appDelegate.activeStory];
    }
    [self setTitleForBackButton];
    [appDelegate loadStoryDetailView];
    [self redrawUnreadStory];
}

- (void)setTitleForBackButton {
    if (self.isPhoneOrCompact) {
        NSString *feedTitle;
        if (storiesCollection.isRiverView) {
            if ([storiesCollection.activeFolder isEqualToString:@"river_blurblogs"]) {
                feedTitle = @"All Shared Stories";
            } else if ([storiesCollection.activeFolder isEqualToString:@"river_global"]) {
                feedTitle = @"Global Shared Stories";
            } else if ([storiesCollection.activeFolder isEqualToString:@"everything"]) {
                feedTitle = @"All Stories";
            } else if ([storiesCollection.activeFolder isEqualToString:@"infrequent"]) {
                feedTitle = @"Infrequent Site Stories";
            } else if (storiesCollection.isSavedView && storiesCollection.activeSavedStoryTag) {
                feedTitle = storiesCollection.activeSavedStoryTag;
            } else if ([storiesCollection.activeFolder isEqualToString:@"read_stories"]) {
                feedTitle = @"Read Stories";
            } else if ([storiesCollection.activeFolder isEqualToString:@"saved_stories"]) {
                feedTitle = @"Saved Stories";
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < storiesCollection.storyLocationsCount) {
        // mark the cell as read
        appDelegate.feedsViewController.currentRowAtIndexPath = nil;
        
        if (self.isDashboardModule) {
            NSInteger storyIndex = [storiesCollection indexFromLocation:indexPath.row];
            NSDictionary *activeStory = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];
            appDelegate.activeStory = activeStory;
            [appDelegate openDashboardRiverForStory:[activeStory objectForKey:@"story_hash"] showFindingStory:NO];
            
        } else {
            FeedDetailTableCell *cell = (FeedDetailTableCell*) [tableView cellForRowAtIndexPath:indexPath];
            NSInteger storyIndex = [storiesCollection indexFromLocation:indexPath.row];
            NSDictionary *story = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];
            if (!self.isPhoneOrCompact &&
                appDelegate.activeStory &&
                [[story objectForKey:@"story_hash"]
                 isEqualToString:[appDelegate.activeStory objectForKey:@"story_hash"]]) {
                return;
            }
            [self loadStory:cell atRow:indexPath.row];
        }
        if (!self.isPhoneOrCompact) {
            [appDelegate.dashboardViewController.storiesModule.view endEditing:YES];
        }
    } else if (indexPath.row == storiesCollection.storyLocationsCount) {
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

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger storyCount = storiesCollection.storyLocationsCount;
    
    if (storyCount && indexPath.row == storyCount) {
        if (!self.pageFinished) return 40;
        
        BOOL markReadOnScroll = [[NSUserDefaults standardUserDefaults] boolForKey:@"default_scroll_read_filter"];
        if (markReadOnScroll) {
            return CGRectGetHeight(self.view.frame) - 40;
        }
        return 120;
    } else if (storiesCollection.isRiverView ||
               storiesCollection.isSavedView ||
               storiesCollection.isReadView ||
               storiesCollection.isSocialView ||
               storiesCollection.isSocialRiverView) {
        NSInteger height = kTableViewRiverRowHeight;
        if ([self isShortTitles]) {
            height = height - kTableViewShortRowDifference;
        }
        UIFontDescriptor *fontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
        UIFont *font = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
        if ([self isShortTitles] && self.showContentPreview) {
            return height + font.pointSize*3.25;
        } else if (self.isDashboardModule || self.showContentPreview) {
            return height + font.pointSize*5;
        } else {
            return height + font.pointSize*2;
        }
    } else {
        NSInteger height = kTableViewRowHeight;
        if ([self isShortTitles]) {
            height = height - kTableViewShortRowDifference;
        }
        UIFontDescriptor *fontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
        UIFont *font = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
        if ([self isShortTitles] && self.showContentPreview) {
            return height + font.pointSize*3.25;
        } else if (self.isDashboardModule || self.showContentPreview) {
            return height + font.pointSize*5;
        } else {
            return height + font.pointSize*2;
        }
    }
}
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    // This will create a "invisible" footer
    return 0.01f;
}
- (void)scrollViewDidScroll: (UIScrollView *)scroll {
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

- (BOOL)isShortTitles {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    return !self.isPhoneOrCompact &&
        !appDelegate.masterContainerViewController.storyTitlesOnLeft &&
        UIInterfaceOrientationIsPortrait(orientation) &&
        !self.isDashboardModule;
}

- (void)checkScroll {
    NSInteger currentOffset = self.storyTitlesTable.contentOffset.y;
    NSInteger maximumOffset = self.storyTitlesTable.contentSize.height - self.storyTitlesTable.frame.size.height;
    
    if (self.pageFetching) {
        return;
    }
    if (![storiesCollection.activeFeedStories count]) return;
    
    if (maximumOffset - currentOffset <= 500.0 ||
        (appDelegate.inFindingStoryMode)) {
        if (storiesCollection.isRiverView && storiesCollection.activeFolder) {
            [self fetchRiverPage:storiesCollection.feedPage+1 withCallback:nil];
        } else {
            [self fetchFeedDetail:storiesCollection.feedPage+1 withCallback:nil];
        }
    }
    
    CGPoint topRowPoint = self.storyTitlesTable.contentOffset;
    topRowPoint.y = topRowPoint.y + 80.f;
    NSIndexPath *indexPath = [self.storyTitlesTable indexPathForRowAtPoint:topRowPoint];
    BOOL markReadOnScroll = [[NSUserDefaults standardUserDefaults] boolForKey:@"default_scroll_read_filter"];
    
    if (indexPath && markReadOnScroll) {
        NSUInteger topRow = indexPath.row;
        
        if (self.scrollingMarkReadRow == NSNotFound) {
            self.scrollingMarkReadRow = topRow;
        } else if (topRow > self.scrollingMarkReadRow) {
            for (NSUInteger thisRow = self.scrollingMarkReadRow; thisRow < topRow; thisRow++) {
                NSInteger storyIndex = [storiesCollection indexFromLocation:thisRow];
                NSDictionary *story = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];
                
                if ([storiesCollection isStoryUnread:story]) {
                    [storiesCollection markStoryRead:story];
                    [storiesCollection syncStoryAsRead:story];
                    NSIndexPath *reloadIndexPath = [NSIndexPath indexPathForRow:thisRow inSection:0];
                    NSLog(@" --> Reloading indexPath: %@", reloadIndexPath);
                    [self.storyTitlesTable reloadRowsAtIndexPaths:@[reloadIndexPath]
                                                 withRowAnimation:UITableViewRowAnimationFade];
                    
                    if (self.isDashboardModule) {
                        id feedId = [story objectForKey:@"story_feed_id"];
                        [appDelegate refreshFeedCount:feedId];
                    }
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
    
    [self.storyTitlesTable reloadData];
}

- (NSDictionary *)getStoryAtRow:(NSInteger)indexPathRow {
    if (indexPathRow >= [[storiesCollection activeFeedStoryLocations] count]) return nil;
    id location = [[storiesCollection activeFeedStoryLocations] objectAtIndex:indexPathRow];
    if (!location) return nil;
    NSInteger row = [location intValue];
    return [storiesCollection.activeFeedStories objectAtIndex:row];
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

- (void)swipeTableViewCell:(MCSwipeTableViewCell *)cell
didEndSwipingSwipingWithState:(MCSwipeTableViewCellState)state
                      mode:(MCSwipeTableViewCellMode)mode {
    NSIndexPath *indexPath = [self.storyTitlesTable indexPathForCell:cell];
    if (!indexPath) {
        // This can happen if the user swipes on a cell that is being refreshed.
        return;
    }
    
    NSInteger storyIndex = [storiesCollection indexFromLocation:indexPath.row];
    NSDictionary *story = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];

    if (state == MCSwipeTableViewCellState1) {
        // Saved
        [storiesCollection toggleStorySaved:story];
        [self.storyTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                     withRowAnimation:UITableViewRowAnimationFade];
    } else if (state == MCSwipeTableViewCellState3) {
        // Read
        [storiesCollection toggleStoryUnread:story];
        [self.storyTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                     withRowAnimation:UITableViewRowAnimationFade];
        if (self.isDashboardModule) {
            [appDelegate refreshFeedCount:[story objectForKey:@"story_feed_id"]];
        }
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
    
    NSDictionary *story = [self getStoryAtRow:indexPath.row];
    
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
        [self.storyTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                     withRowAnimation:UITableViewRowAnimationFade];
    } else if ([longPressStoryTitle isEqualToString:@"save_story"]) {
        [storiesCollection toggleStorySaved:story];
        [self.storyTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                     withRowAnimation:UITableViewRowAnimationFade];
    } else if ([longPressStoryTitle isEqualToString:@"train_story"]) {
        appDelegate.activeStory = story;
        [appDelegate openTrainStory:cell];
    }
}

- (void)handleMarkReadLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) return;
    
    [self doOpenMarkReadMenu:nil];
}

- (void)showMarkOlderNewerOptionsForStory:(NSDictionary *)story indexPath:(NSIndexPath *)indexPath cell:(FeedDetailTableCell *)cell {
    CGRect rect = [self.storyTitlesTable rectForRowAtIndexPath:indexPath];
    
    NSMutableArray *items = [NSMutableArray array];
    BOOL isSaved = [[story objectForKey:@"starred"] boolValue];
    
    [items addObject:[self itemWithTitle:isSaved ? @"Unsave This Story" : @"Save This Story" iconName:@"clock.png" handler:^{
        [storiesCollection toggleStorySaved:story];
    }]];
    
    [items addObject:[self itemWithTitle:@"Send This Story To..." iconName:@"menu_icn_mail.png" handler:^{
        [appDelegate showSendTo:self sender:cell];
    }]];
    
    [items addObject:[self itemWithTitle:@"Train This Story" iconName:@"menu_icn_train.png" handler:^{
        [appDelegate openTrainStory:cell];
    }]];
    
    [self.appDelegate showMarkOlderNewerReadMenuWithStoriesCollection:self.storiesCollection story:story sourceView:self.storyTitlesTable sourceRect:rect extraItems:items completionHandler:^(BOOL marked) {
        [self.storyTitlesTable reloadData];
    }];
}

- (NSDictionary *)itemWithTitle:(NSString *)title iconName:(NSString *)iconName handler:(void (^)(void))handler {
    return @{@"title" : title, @"icon" : iconName, @"handler" : handler};
}

- (void)markFeedsReadFromTimestamp:(NSInteger)cutoffTimestamp andOlder:(BOOL)older {
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_as_read",
                           self.appDelegate.url];
    NSMutableArray *feedIds = [NSMutableArray array];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    if (storiesCollection.isRiverView) {
        if ([storiesCollection.activeFolder isEqual:@"everything"] || [storiesCollection.activeFolder isEqual:@"infrequent"]) {
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

    [appDelegate.networkManager POST:urlString parameters:params progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        [appDelegate markFeedReadInCache:feedIds cutoffTimestamp:cutoffTimestamp older:older];
        // is there a better way to refresh the detail view?
        [self reloadStories];
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        [self requestFailed:error];
    }];
}

- (IBAction)doOpenMarkReadMenu:(id)sender {
    [self.appDelegate hidePopoverAnimated:YES];
    
    void (^pop)(void) = ^{
        if (!self.isPhoneOrCompact) {
            [appDelegate.navigationController popToRootViewControllerAnimated:YES];
            [appDelegate.masterContainerViewController transitionFromFeedDetail];
        } else {
            [appDelegate.navigationController popToViewController:[appDelegate.navigationController.viewControllers objectAtIndex:0] animated:YES];
        }
    };
    
    [storiesCollection calculateStoryLocations];
    NSArray *feedIds = storiesCollection.isRiverView ? [self.appDelegate feedIdsForFolderTitle:storiesCollection.activeFolder] : @[storiesCollection.activeFeed[@"id"]];
    NSString *confirmPref = [[NSUserDefaults standardUserDefaults] stringForKey:@"default_confirm_read_filter"];
    
    if (sender && ([confirmPref isEqualToString:@"never"] || ([confirmPref isEqualToString:@"folders"] && !storiesCollection.isRiverView))) {
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
    
    UIBarButtonItem *barButton = self.feedMarkReadButton;
    if (sender && [sender isKindOfClass:[UIBarButtonItem class]]) barButton = sender;
    
    [self.appDelegate showMarkReadMenuWithFeedIds:feedIds collectionTitle:collectionTitle visibleUnreadCount:visibleUnreadCount barButtonItem:barButton completionHandler:^(BOOL marked){
        if (marked) {
            pop();
        }
    }];
}

- (IBAction)doOpenSettingsMenu:(id)sender {
    if (self.presentedViewController) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    [self.appDelegate.feedDetailMenuViewController buildMenuOptions];
    [self.appDelegate.feedDetailMenuViewController view];
    NSInteger menuCount = [self.appDelegate.feedDetailMenuViewController.menuOptions count] + 4;
    
    [self.appDelegate.feedDetailMenuNavigationController popToRootViewControllerAnimated:NO];
    [self.appDelegate showPopoverWithViewController:self.appDelegate.feedDetailMenuNavigationController contentSize:CGSizeMake(260, 38 * menuCount) barButtonItem:self.settingsBarButton];
}

- (void)confirmDeleteSite {
    MenuViewController *viewController = [MenuViewController new];
    viewController.title = @"Positive?";
    NSString *title = storiesCollection.isRiverView ? @"Delete Folder" : @"Delete Site";
    
    [viewController addTitle:title iconName:@"menu_icn_delete.png" selectionShouldDismiss:YES handler:^{
        if (storiesCollection.isRiverView) {
            [self deleteFolder];
        } else {
            [self deleteSite];
        }
    }];
    
    [self.appDelegate.feedDetailMenuNavigationController pushViewController:viewController animated:YES];
}

- (void)confirmMuteSite {
    MenuViewController *viewController = [MenuViewController new];
    viewController.title = @"Positive?";
    
    [viewController addTitle:@"Mute Site" iconName:@"menu_icn_mute.png" selectionShouldDismiss:YES handler:^{
        [self muteSite];
    }];
    
    [self.appDelegate.feedDetailMenuNavigationController pushViewController:viewController animated:YES];
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

    [appDelegate.networkManager POST:urlString parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [appDelegate reloadFeedsView:YES];
        if (storiesCollection.isRiverView) {
            [appDelegate renameFolder:newTitle];
        } else {
            [appDelegate renameFeed:newTitle];
        }
        [self.view setNeedsDisplay];
        if (!self.isPhoneOrCompact) {
            appDelegate.storyPageControl.navigationItem.titleView = [appDelegate makeFeedTitle:storiesCollection.activeFeed];
        } else {
            self.navigationItem.titleView = [appDelegate makeFeedTitle:storiesCollection.activeFeed];
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

    [appDelegate.networkManager POST:urlString parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [appDelegate reloadFeedsView:YES];
        [appDelegate.navigationController
         popToViewController:[appDelegate.navigationController.viewControllers
                              objectAtIndex:0]
         animated:YES];
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
    
    [appDelegate.networkManager POST:urlString parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [appDelegate reloadFeedsView:YES];
        [appDelegate.navigationController
         popToViewController:[appDelegate.navigationController.viewControllers
                              objectAtIndex:0]
         animated:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (void)muteSite {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Muting...";
    
    NSMutableArray *activeIdentifiers = [self.appDelegate.dictFeeds.allKeys mutableCopy];
    NSString *thisIdentifier = [NSString stringWithFormat:@"%@", storiesCollection.activeFeed[@"id"]];
    [activeIdentifiers removeObject:thisIdentifier];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/save_feed_chooser", self.appDelegate.url];

    [params setObject:activeIdentifiers forKey:@"approved_feeds"];
    [appDelegate.networkManager POST:urlString parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self.appDelegate reloadFeedsView:YES];
        [self.appDelegate.navigationController popToViewController:[appDelegate.navigationController.viewControllers objectAtIndex:0]
                                                          animated:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
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
    
    [appDelegate.networkManager POST:urlString parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
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

- (void)openMoveView {
    MenuViewController *viewController = [MenuViewController new];
    viewController.title = @"Move To";
    
    __weak __typeof(&*self)weakSelf = self;
    
    for (NSString *folder in self.appDelegate.dictFoldersArray) {
        NSString *title = folder;
        NSString *iconName = @"menu_icn_move.png";
        
        if (![title hasPrefix:@"river_"] && ![title hasSuffix:@"_stories"]) {
            if ([title isEqualToString:@"everything"]) {
                title = @"Top Level";
                iconName = @"menu_icn_all.png";
            } else {
                NSArray *components = [title componentsSeparatedByString:@" - "];
                title = components.lastObject;
                for (NSUInteger idx = 0; idx < components.count; idx++) {
                    title = [@"\t" stringByAppendingString:title];
                }
            }
            
            [viewController addTitle:title iconName:iconName selectionShouldDismiss:YES handler:^{
                [weakSelf performMoveToFolder:folder];
            }];
        }
    }
    
    [self.appDelegate.feedDetailMenuNavigationController pushViewController:viewController animated:YES];
}

//- (void)openMoveView {
//    [appDelegate showMoveSite];
//}

- (void)openTrainSite {
    [appDelegate openTrainSite];
}

- (void)openNotificationsWithFeed:(NSString *)feedId {
    [appDelegate openNotificationsWithFeed:feedId];
}

- (void)openRenameSite {
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
        textField.text = appDelegate.storiesCollection.isRiverView ?
        [appDelegate extractFolderName:appDelegate.storiesCollection.activeFolder] :
        [appDelegate.storiesCollection.activeFeed objectForKey:@"feed_title"];
    }];
    [alert addAction:rename];
    [alert addAction:cancel];
    
    if (self.presentedViewController) {
        [self.presentedViewController dismissViewControllerAnimated:NO completion:^{
            [self presentViewController:alert animated:YES completion:nil];
        }];
    }
//    [self.appDelegate showAlert:alert withViewController:self];
}

- (void)showUserProfile {
    appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@",
                                       [storiesCollection.activeFeed objectForKey:@"user_id"]];
    appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@",
                                         [storiesCollection.activeFeed objectForKey:@"username"]];
    [appDelegate showUserProfileModal:titleImageBarButton];
}

- (void)changeActiveFeedDetailRow {
    NSInteger rowIndex = [storiesCollection locationOfActiveStory];
    NSInteger offset = 1;
    if ([[self.storyTitlesTable visibleCells] count] <= 4) {
        offset = 0;
    }
    if (offset > rowIndex) offset = rowIndex;
                    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    NSIndexPath *offsetIndexPath = [NSIndexPath indexPathForRow:(rowIndex - offset) inSection:0];

    [storyTitlesTable selectRowAtIndexPath:indexPath 
                                  animated:YES 
                            scrollPosition:UITableViewScrollPositionNone];
    
    // check to see if the cell is completely visible
    CGRect cellRect = [storyTitlesTable rectForRowAtIndexPath:indexPath];
    
    cellRect = [storyTitlesTable convertRect:cellRect toView:storyTitlesTable.superview];
    
    BOOL completelyVisible = CGRectContainsRect(storyTitlesTable.frame, cellRect);
    if (!completelyVisible) {
        [storyTitlesTable scrollToRowAtIndexPath:offsetIndexPath 
                                atScrollPosition:UITableViewScrollPositionTop 
                                        animated:YES];
    }
}

- (void)updateTheme {
    [super updateTheme];
    
    self.navigationController.navigationBar.tintColor = UIColorFromRGB(0x8F918B);
    self.navigationController.navigationBar.backItem.backBarButtonItem.tintColor = UIColorFromRGB(0x8F918B);
    self.navigationController.navigationBar.barTintColor = UIColorFromRGB(0xE3E6E0);
    self.navigationController.toolbar.barTintColor = UIColorFromRGB(0xE3E6E0);
    
    self.searchBar.backgroundColor = UIColorFromRGB(0xE3E6E0);
    self.searchBar.tintColor = UIColorFromRGB(0xffffff);
    self.searchBar.nb_searchField.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    self.searchBar.nb_searchField.tintColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    
    if (self.isPhoneOrCompact) {
        self.navigationItem.titleView = [appDelegate makeFeedTitle:storiesCollection.activeFeed];
    }
    
    if ([ThemeManager themeManager].isDarkTheme) {
        self.searchBar.keyboardAppearance = UIKeyboardAppearanceDark;
    } else {
        self.searchBar.keyboardAppearance = UIKeyboardAppearanceDefault;
    }
    
    self.view.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.storyTitlesTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.storyTitlesTable.separatorColor = UIColorFromRGB(0xE9E8E4);
    [self.storyTitlesTable reloadData];
}

#pragma mark -
#pragma mark Story Actions - save

- (void)finishMarkAsSaved:(NSDictionary *)params {

}

- (void)failedMarkAsSaved:(NSDictionary *)params {
    [self informError:@"Failed to save story"];
    
    [self.storyTitlesTable reloadData];
}

- (void)finishMarkAsUnsaved:(NSDictionary *)params {

}

- (void)failedMarkAsUnsaved:(NSDictionary *)params {
    [self informError:@"Failed to unsave story"];

    [self.storyTitlesTable reloadData];
}

- (void)failedMarkAsUnread:(NSDictionary *)params {
    [self informError:@"Failed to unread story"];
    
    [self.storyTitlesTable reloadData];
}

#pragma mark -
#pragma mark instafetchFeed

// called when the user taps refresh button

- (void)instafetchFeed {
    NSString *urlString = [NSString
                           stringWithFormat:@"%@/reader/refresh_feed/%@", 
                           self.appDelegate.url,
                           [storiesCollection.activeFeed objectForKey:@"id"]];
//    [self cancelRequests];
    [appDelegate.networkManager GET:urlString parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        [self renderStories:[responseObject objectForKey:@"stories"]];
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSLog(@"Fail: %@", error);
        [self informError:[operation error]];
        [self fetchFeedDetail:1 withCallback:nil];
    }];
    
    [storiesCollection setStories:nil];
    storiesCollection.feedPage = 1;
    self.pageFetching = YES;
    [self.storyTitlesTable reloadData];
    [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
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

    [appDelegate.networkManager GET:urlString parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self saveAndDrawFavicons:responseObject];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (void)saveAndDrawFavicons:(NSDictionary *)results {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0ul);
    dispatch_async(queue, ^{
        for (id feed_id in results) {
            NSMutableDictionary *feed = [[appDelegate.dictActiveFeeds objectForKey:feed_id] mutableCopy];
            [feed setValue:[results objectForKey:feed_id] forKey:@"favicon"];
            [appDelegate.dictActiveFeeds setValue:feed forKey:feed_id];
            
            NSString *favicon = [feed objectForKey:@"favicon"];
            if ((NSNull *)favicon != [NSNull null] && [favicon length] > 0) {
                NSData *imageData = [[NSData alloc] initWithBase64EncodedString:favicon options:NSDataBase64DecodingIgnoreUnknownCharacters];
                UIImage *faviconImage = [UIImage imageWithData:imageData];
                [appDelegate saveFavicon:faviconImage feedId:feed_id];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.storyTitlesTable reloadData];
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
    NSDictionary *story = [self getStoryAtRow:indexPath.row];
    
    if (!story) return @[];

    NSString *storyTitle = story[@"story_title"];
    NSString *storyPermalink = story[@"story_permalink"];
    UIImage *storyImage = nil;

    FeedDetailTableCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell.storyImageUrl) {
        id cachedImage = appDelegate.cachedStoryImages[cell.storyImageUrl];
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
