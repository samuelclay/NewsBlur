//
//  NBContainerViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/24/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "NBContainerViewController.h"
#import "NewsBlurViewController.h"
#import "FeedDetailViewController.h"
#import "DashboardViewController.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "OriginalStoryViewController.h"
#import "ShareViewController.h"
#import "UserProfileViewController.h"
#import "InteractionCell.h"
#import "ActivityCell.h"
#import "FeedTableCell.h"
#import "FeedDetailTableCell.h"
#import "FeedsMenuViewController.h"
#import "FeedDetailMenuViewController.h"
#import "FontSettingsViewController.h"
#import "AddSiteViewController.h"
#import "TrainerViewController.h"
#import "StoriesCollection.h"
#import "UserTagsViewController.h"

#define NB_DEFAULT_MASTER_WIDTH 270
#define NB_DEFAULT_MASTER_WIDTH_LANDSCAPE 370
#define NB_DEFAULT_STORY_TITLE_HEIGHT 1004
#define NB_DEFAULT_SLIDER_INTERVAL 0.3
#define NB_DEFAULT_SLIDER_INTERVAL_OUT 0.3
#define NB_DEFAULT_SHARE_HEIGHT 144
#define NB_DEFAULT_STORY_TITLE_SNAP_THRESHOLD 60

@interface NBContainerViewController ()

@property (nonatomic, strong) UINavigationController *masterNavigationController;
@property (nonatomic, strong) UINavigationController *storyNavigationController;
@property (nonatomic, strong) UINavigationController *shareNavigationController;
@property (nonatomic, strong) UINavigationController *originalNavigationController;
@property (nonatomic, strong) NewsBlurViewController *feedsViewController;
@property (nonatomic, strong) FeedDetailViewController *feedDetailViewController;
@property (nonatomic, strong) DashboardViewController *dashboardViewController;
@property (nonatomic, strong) StoryDetailViewController *storyDetailViewController;
@property (nonatomic, strong) OriginalStoryViewController *originalViewController;
@property (nonatomic, strong) StoryPageControl *storyPageControl;
@property (nonatomic, strong) ShareViewController *shareViewController;
@property (nonatomic, strong) UIView *storyTitlesStub;
@property (readwrite) BOOL storyTitlesOnLeft;
@property (readwrite) int storyTitlesYCoordinate;

@property (readwrite) BOOL isSharingStory;
@property (readwrite) BOOL isHidingStory;
@property (readwrite) BOOL feedDetailIsVisible;
@property (readwrite) BOOL keyboardIsShown;
@property (readwrite) UIDeviceOrientation rotatingToOrientation;
@property (nonatomic) UIBackgroundTaskIdentifier reorientBackgroundTask;

@end

@implementation NBContainerViewController

@synthesize appDelegate;
@synthesize masterNavigationController;
@synthesize shareNavigationController;
@synthesize originalNavigationController;
@synthesize feedsViewController;
@synthesize feedDetailViewController;
@synthesize dashboardViewController;
@synthesize storyDetailViewController;
@synthesize originalViewController;
@synthesize storyPageControl;
@synthesize shareViewController;
@synthesize feedDetailIsVisible;
@synthesize originalViewIsVisible;
@synthesize keyboardIsShown;
@synthesize storyNavigationController;
@synthesize storyTitlesYCoordinate;
@synthesize storyTitlesOnLeft;
@synthesize storyTitlesStub;
@synthesize isSharingStory;
@synthesize isHidingStory;
@synthesize leftBorder;
@synthesize rightBorder;
@synthesize interactiveOriginalTransition;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShowOrHide:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShowOrHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    self.navigationController.navigationBar.translucent = NO;
    self.masterNavigationController.navigationBar.translucent = NO;
    
    self.masterNavigationController = appDelegate.navigationController;
    self.feedsViewController = appDelegate.feedsViewController;
    self.dashboardViewController = appDelegate.dashboardViewController;
    self.feedDetailViewController = appDelegate.feedDetailViewController;
    self.storyDetailViewController = appDelegate.storyDetailViewController;
    self.originalViewController = appDelegate.originalStoryViewController;
    self.storyPageControl = appDelegate.storyPageControl;
    self.shareViewController = appDelegate.shareViewController;
    
    // adding dashboardViewController 
    [self addChildViewController:self.dashboardViewController];
    [self.view addSubview:self.dashboardViewController.view];
    [self.dashboardViewController didMoveToParentViewController:self];
    
    // adding master navigation controller
    [self addChildViewController:self.masterNavigationController];
    [self.view addSubview:self.masterNavigationController.view];
    [self.masterNavigationController didMoveToParentViewController:self];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self.storyPageControl];
    self.storyNavigationController = nav;
    self.storyNavigationController.navigationBar.translucent = NO;
    self.storyNavigationController.view.layer.masksToBounds = NO;
    self.storyNavigationController.view.layer.shadowRadius = 5;
    self.storyNavigationController.view.layer.shadowOpacity = 0.5;
    self.storyNavigationController.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.view.bounds].CGPath;
    
    UINavigationController *shareNav = [[UINavigationController alloc] initWithRootViewController:self.shareViewController];
    self.shareNavigationController = shareNav;
    self.shareNavigationController.navigationBar.translucent = NO;

    UINavigationController *originalNav = [[UINavigationController alloc]
                                           initWithRootViewController:originalViewController];
    self.originalNavigationController = originalNav;
    self.originalNavigationController.navigationBar.translucent = NO;
    [self.originalNavigationController.interactivePopGestureRecognizer
     addTarget:self
     action:@selector(handleOriginalNavGesture:)];
    
    // set up story titles stub
    UIView * storyTitlesPlaceholder = [[UIView alloc] initWithFrame:CGRectZero];
    storyTitlesPlaceholder.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    storyTitlesPlaceholder.autoresizesSubviews = YES;
    storyTitlesPlaceholder.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
        
    self.storyTitlesStub = storyTitlesPlaceholder;
    
    leftBorder = [CALayer layer];
    leftBorder.frame = CGRectMake(0, 0, 1, CGRectGetHeight(self.view.bounds));
    leftBorder.backgroundColor = UIColorFromRGB(0xC2C5BE).CGColor;
    [self.storyNavigationController.view.layer addSublayer:leftBorder];

    rightBorder = [CALayer layer];
    rightBorder.frame = CGRectMake(self.masterWidth-1, 0, 1, CGRectGetHeight(self.view.bounds));
    rightBorder.backgroundColor = UIColorFromRGB(0xC2C5BE).CGColor;
    [self.masterNavigationController.view.layer addSublayer:rightBorder];
    
    [self setupStoryTitlesPosition];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self checkSize:self.view.bounds.size];
    }
    
    [self layoutDashboardScreen];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self checkSize:size];
    }
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        self.rotatingToOrientation = orientation;
        //    leftBorder.frame = CGRectMake(0, 0, 1, CGRectGetHeight(self.view.bounds));
        
        if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
            leftBorder.hidden = YES;
        } else {
            leftBorder.hidden = NO;
        }
        
        [self adjustLayout];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        //    leftBorder.frame = CGRectMake(0, 0, 1, CGRectGetHeight(self.view.bounds));
        
        [self adjustLayout];
        
        if (self.feedDetailIsVisible) {
            // Defer this in the background, to avoid misaligning the detail views
            if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
                self.reorientBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                    [[UIApplication sharedApplication] endBackgroundTask:self.reorientBackgroundTask];
                    self.reorientBackgroundTask = UIBackgroundTaskInvalid;
                }];
                [self performSelector:@selector(delayedReorientPages) withObject:nil afterDelay:0.5];
            } else {
                [self.storyPageControl reorientPages];
            }
        }
    }];
}

- (void)adjustLayout {
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        return;
    }
    
    if (!self.feedDetailIsVisible) {
        [self layoutDashboardScreen];
    } else if (!self.originalViewIsVisible) {
        [self layoutFeedDetailScreen];
    }
}

- (void)delayedReorientPages {
    [self.storyPageControl reorientPages];
    [[UIApplication sharedApplication] endBackgroundTask:self.reorientBackgroundTask];
    self.reorientBackgroundTask = UIBackgroundTaskInvalid;
}

- (void)checkSize:(CGSize)size {
    BOOL wasCompact = self.appDelegate.isCompactWidth;
    BOOL isCompact = size.width < 700.0;
    
    if (!isCompact && wasCompact == isCompact) {
        return;
    }
    
    self.appDelegate.compactWidth = isCompact ? size.width : 0.0;
    
    self.masterNavigationController.view.frame = CGRectMake(0, 0, self.masterWidth, self.view.bounds.size.height);
    
    if (!isCompact) {
        if (self.masterNavigationController.topViewController == self.storyPageControl) {
            [self.masterNavigationController popToViewController:self.feedDetailViewController animated:NO];
        }
        
        if (self.storyNavigationController.topViewController != self.storyPageControl) {
            [self.storyNavigationController pushViewController:self.storyPageControl animated:NO];
            self.storyPageControl.isAnimatedIntoPlace = NO;
        }
        
        [self.storyPageControl hidePages];
    }
}

- (NSInteger)masterWidth {
    if (self.appDelegate.isCompactWidth) {
        return self.appDelegate.compactWidth;
    }
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsLandscape(orientation)) {
        return NB_DEFAULT_MASTER_WIDTH_LANDSCAPE;
    }
    return NB_DEFAULT_MASTER_WIDTH;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if ([ThemeManager themeManager].isDarkTheme) {
        return UIStatusBarStyleLightContent;
    } else {
        return UIStatusBarStyleDefault;
    }
}

- (void)updateTheme {
    self.leftBorder.backgroundColor = UIColorFromRGB(0xC2C5BE).CGColor;
    self.rightBorder.backgroundColor = UIColorFromRGB(0xC2C5BE).CGColor;
    
    self.masterNavigationController.navigationBar.tintColor = UIColorFromRGB(0x8F918B);
    self.masterNavigationController.navigationBar.barTintColor = UIColorFromRGB(0xE3E6E0);
    
    self.storyNavigationController.navigationBar.tintColor = UIColorFromRGB(0x8F918B);
    self.storyNavigationController.navigationBar.barTintColor = UIColorFromRGB(0xE3E6E0);
    
    self.originalNavigationController.navigationBar.tintColor = UIColorFromRGB(0x8F918B);
    self.originalNavigationController.navigationBar.barTintColor = UIColorFromRGB(0xE3E6E0);
    
    UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.storiesCollection.activeFeed];
    self.storyPageControl.navigationItem.titleView = titleLabel;
}

# pragma mark Modals and Popovers

- (void)showUserProfilePopover:(id)sender {
    if ([sender class] == [InteractionCell class] ||
        [sender class] == [ActivityCell class]) {
        InteractionCell *cell = (InteractionCell *)sender;
        
        [self.appDelegate showPopoverWithViewController:self.appDelegate.userProfileNavigationController contentSize:CGSizeMake(320, 454) sourceView:cell sourceRect:cell.bounds];
    } else if ([sender class] == [FeedTableCell class]) {
        FeedTableCell *cell = (FeedTableCell *)sender;
        
        [self.appDelegate showPopoverWithViewController:self.appDelegate.userProfileNavigationController contentSize:CGSizeMake(320, 454) sourceView:cell sourceRect:cell.bounds];
    } else if ([sender class] == [UIBarButtonItem class]) {
        [self.appDelegate showPopoverWithViewController:self.appDelegate.userProfileNavigationController contentSize:CGSizeMake(320, 454) barButtonItem:sender];
    } else {
        CGRect frame = [sender CGRectValue];
        [self.appDelegate showPopoverWithViewController:self.appDelegate.userProfileNavigationController contentSize:CGSizeMake(320, 454) sourceView:self.storyPageControl.view sourceRect:frame];
    }
}

- (void)showTrainingPopover:(id)sender {
    if ([sender class] == [UIBarButtonItem class]) {
        [self.appDelegate showPopoverWithViewController:self.appDelegate.trainerViewController contentSize:CGSizeMake(420, 382) barButtonItem:sender];
    } else if ([sender class] == [FeedTableCell class]) {
        FeedTableCell *cell = (FeedTableCell *)sender;
        [self.appDelegate showPopoverWithViewController:self.appDelegate.trainerViewController contentSize:CGSizeMake(420, 382) sourceView:cell sourceRect:cell.bounds];
    } else if ([sender class] == [FeedDetailTableCell class]) {
        FeedDetailTableCell *cell = (FeedDetailTableCell *)sender;
        [self.appDelegate showPopoverWithViewController:self.appDelegate.trainerViewController contentSize:CGSizeMake(420, 382) sourceView:cell sourceRect:cell.bounds];
    } else {
        CGRect frame = [sender CGRectValue];
        [self.appDelegate showPopoverWithViewController:self.appDelegate.trainerViewController contentSize:CGSizeMake(420, 382) sourceView:self.storyPageControl.view sourceRect:frame];
    }
}

- (void)syncNextPreviousButtons {
    [self.storyPageControl setNextPreviousButtons];
}

#pragma mark - UIPopoverPresentationControllerDelegate

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

#pragma mark - Screen Transitions and Layout

- (void)setupStoryTitlesPosition {
    // set default y coordinate for feedDetailY from saved preferences
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    int savedStoryTitlesYCoordinate = (int)[userPreferences integerForKey:@"storyTitlesYCoordinate"];
    NSString *storyTitlesPosition = [userPreferences stringForKey:@"story_titles_position"];
    if ([storyTitlesPosition isEqualToString:@"titles_on_bottom"]) {
        if (!savedStoryTitlesYCoordinate || savedStoryTitlesYCoordinate > 920) {
            savedStoryTitlesYCoordinate = 920;
        }
        self.storyTitlesYCoordinate = savedStoryTitlesYCoordinate;
        self.storyTitlesOnLeft = NO;
    } else {
        self.storyTitlesYCoordinate = NB_DEFAULT_STORY_TITLE_HEIGHT;
        self.storyTitlesOnLeft = YES;
    }
}

- (void)layoutDashboardScreen {
    CGRect vb = [self.view bounds];
    self.masterNavigationController.view.frame = CGRectMake(0, 0, self.masterWidth, vb.size.height);
    self.dashboardViewController.view.frame = CGRectMake(self.masterWidth, 0, vb.size.width - self.masterWidth, vb.size.height);
    rightBorder.frame = CGRectMake(self.masterWidth-1, 0, 1, CGRectGetHeight(self.view.bounds));
    self.storyPageControl.navigationItem.leftBarButtonItem = self.storyPageControl.buttonBack;
}

- (void)layoutFeedDetailScreen {
    CGRect vb = [self.view bounds];
    rightBorder.frame = CGRectMake(self.masterWidth-1, 0, 1, CGRectGetHeight(self.view.bounds));

    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
        // add the back button
        self.storyPageControl.navigationItem.leftBarButtonItem = self.storyPageControl.buttonBack;
        
        // set center title
        UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.storiesCollection.activeFeed];
        self.storyPageControl.navigationItem.titleView = titleLabel;
        
        if ([[self.masterNavigationController viewControllers] containsObject:self.feedDetailViewController]) {
            [self.masterNavigationController popViewControllerAnimated:NO];
        }
        self.storyNavigationController.view.frame = CGRectMake(0, 0,
                                                               vb.size.width,
                                                               self.storyTitlesYCoordinate);
        self.feedDetailViewController.view.frame = CGRectMake(0, self.storyTitlesYCoordinate,
                                                              vb.size.width,
                                                              vb.size.height -
                                                              self.storyTitlesYCoordinate);
        [self.view insertSubview:self.feedDetailViewController.view
                    aboveSubview:self.storyNavigationController.view];
        [self.masterNavigationController.view removeFromSuperview];
        [self.dashboardViewController.view removeFromSuperview];
        self.originalNavigationController.view.frame = CGRectMake(vb.size.width, 0,
                                                                  vb.size.width, vb.size.height);
    } else {
        // remove the back button
        self.storyPageControl.navigationItem.leftBarButtonItem = nil;

        if (![[self.masterNavigationController viewControllers] containsObject:self.feedDetailViewController]) {
            [self.masterNavigationController pushViewController:self.feedDetailViewController animated:NO];        
        }
        [self.view addSubview:self.masterNavigationController.view];
        self.masterNavigationController.view.frame = CGRectMake(0, 0, self.masterWidth, vb.size.height);
        self.storyNavigationController.view.frame = CGRectMake(self.masterWidth-1, 0, vb.size.width - self.masterWidth + 1, vb.size.height);
        [self.dashboardViewController.view removeFromSuperview];
        self.originalNavigationController.view.frame = CGRectMake(vb.size.width, 0, vb.size.width, vb.size.height);
//        leftBorder.frame = CGRectMake(0, 0, 1, CGRectGetHeight(self.view.bounds));
//        NSLog(@"Transitioning back to feed detail, original frame: %@", NSStringFromCGRect(self.originalNavigationController.view.frame));
    }
}

- (void)adjustFeedDetailScreenForStoryTitles {
    CGRect vb = [self.view bounds];
    
    if (!self.storyTitlesOnLeft) {
        if (self.storyTitlesYCoordinate > 920) {
            NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];   
            // save coordinate
            [userPreferences setInteger:1004 forKey:@"storyTitlesYCoordinate"];
            [userPreferences setValue:@"titles_on_left" forKey:@"story_titles_position"];
            [userPreferences synchronize];
            self.storyTitlesYCoordinate = 1004;
            // slide to the left
            
            self.storyTitlesOnLeft = YES;
            self.leftBorder.hidden = NO;
            
            // remove the back button
            self.storyPageControl.navigationItem.leftBarButtonItem = nil;
            
            // remove center title
            self.storyPageControl.navigationItem.titleView = nil;
            
            [self.masterNavigationController popToRootViewControllerAnimated:NO];
            if (![[self.masterNavigationController viewControllers] containsObject:self.feedDetailViewController]) {
                [self.masterNavigationController pushViewController:self.feedDetailViewController animated:NO];
            }
            [self.view addSubview:self.masterNavigationController.view];

            self.masterNavigationController.view.frame = CGRectMake(-1 * self.masterWidth, 0, self.masterWidth, vb.size.height);
            [UIView animateWithDuration:NB_DEFAULT_SLIDER_INTERVAL delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                self.masterNavigationController.view.frame = CGRectMake(0, 0, self.masterWidth, vb.size.height);
                self.storyNavigationController.view.frame = CGRectMake(self.masterWidth-1, 0, vb.size.width - self.masterWidth + 1, vb.size.height);
            } completion:^(BOOL finished) {
                [self.feedDetailViewController checkScroll];
                [appDelegate.storyPageControl refreshPages];
                [appDelegate adjustStoryDetailWebView];
                [self.feedDetailViewController.storyTitlesTable reloadData];
            }];
        }
    } else if (self.storyTitlesOnLeft) {
        NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];

        if (self.storyTitlesYCoordinate == 1004) {
            return;
        } else if (self.storyTitlesYCoordinate > 920) {
            // save coordinate
            [userPreferences setInteger:920 forKey:@"storyTitlesYCoordinate"];
            [userPreferences synchronize];
            self.storyTitlesYCoordinate = 920;
        }

        [userPreferences setValue:@"titles_on_bottom" forKey:@"story_titles_position"];
        [userPreferences synchronize];

        self.storyTitlesOnLeft = NO;
        self.leftBorder.hidden = YES;
        
        // add the back button
        self.storyPageControl.navigationItem.leftBarButtonItem = self.storyPageControl.buttonBack;
        
        // set center title
        UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.storiesCollection.activeFeed];
        self.storyPageControl.navigationItem.titleView = titleLabel;
        
        [UIView animateWithDuration:NB_DEFAULT_SLIDER_INTERVAL delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.masterNavigationController.view.frame = CGRectMake(-1 * self.masterWidth, 0, self.masterWidth, vb.size.height);
            
            self.storyNavigationController.view.frame = CGRectMake(0, 0, vb.size.width, storyTitlesYCoordinate);
            
            self.storyTitlesStub.frame = CGRectMake(0, storyTitlesYCoordinate, vb.size.width, vb.size.height - storyTitlesYCoordinate - 44 - 20);
        } completion:^(BOOL finished) {
            [self.view insertSubview:self.feedDetailViewController.view
                        aboveSubview:self.storyTitlesStub];
            self.feedDetailViewController.view.frame = CGRectMake(0, storyTitlesYCoordinate, vb.size.width, vb.size.height - storyTitlesYCoordinate);
            self.storyTitlesStub.hidden = YES;
            [self.feedDetailViewController checkScroll];
            [appDelegate.storyPageControl refreshPages];
            [appDelegate adjustStoryDetailWebView];
            [self.feedDetailViewController.storyTitlesTable reloadData];
        }];    
    }
}

- (void)transitionToFeedDetail {
    [self transitionToFeedDetail:YES];
}
- (void)transitionToFeedDetail:(BOOL)resetLayout {
    [self.appDelegate hidePopover];
    if (self.feedDetailIsVisible) resetLayout = NO;
    self.feedDetailIsVisible = YES;
    
    if (resetLayout) {
        // adding storyDetailViewController
        [self addChildViewController:self.storyNavigationController];
        [self.view addSubview:self.storyNavigationController.view];
        [self.storyNavigationController didMoveToParentViewController:self];
        
        // adding feedDetailViewController
//        [self addChildViewController:self.feedDetailViewController];
//        [self.view insertSubview:self.feedDetailViewController.view
//                    aboveSubview:self.storyNavigationController.view];
//        [self.feedDetailViewController didMoveToParentViewController:self];
        
        [self.view insertSubview:self.storyTitlesStub
                    aboveSubview:self.storyNavigationController.view];

        // reset the storyDetailViewController components
        self.storyPageControl.currentPage.webView.hidden = YES;
        self.storyPageControl.nextPage.webView.hidden = YES;
        self.storyPageControl.navigationItem.rightBarButtonItems = nil;
        [self.storyPageControl hidePages];
        NSInteger unreadCount = appDelegate.unreadCount;
        if (unreadCount == 0) {
            self.storyPageControl.circularProgressView.percentage = 1;
        } else {
            self.storyPageControl.circularProgressView.percentage = 0;
        }

        UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.storiesCollection.activeFeed];
        self.storyPageControl.navigationItem.titleView = titleLabel;
        
        [self setupStoryTitlesPosition];
    }
    
    CGRect vb = [self.view bounds];
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
        // CASE: story titles on bottom
        if (resetLayout) {
            self.storyPageControl.navigationItem.leftBarButtonItem = self.storyPageControl.buttonBack;
            self.storyPageControl.navigationItem.rightBarButtonItems = self.feedDetailViewController.navigationItem.rightBarButtonItems;

        [self.view insertSubview:self.feedDetailViewController.view
                    aboveSubview:self.storyNavigationController.view];

            self.storyNavigationController.view.frame = CGRectMake(vb.size.width, 0, vb.size.width, storyTitlesYCoordinate);
            self.feedDetailViewController.view.frame = CGRectMake(vb.size.width, 
                                                                  self.storyTitlesYCoordinate, 
                                                                  vb.size.width, 
                                                                  vb.size.height - storyTitlesYCoordinate);
        }
        float largeTimeInterval = NB_DEFAULT_SLIDER_INTERVAL * ( vb.size.width - self.masterWidth) / vb.size.width;
        float smallTimeInterval = NB_DEFAULT_SLIDER_INTERVAL * self.masterWidth / vb.size.width;
        
        [UIView animateWithDuration:largeTimeInterval delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.storyNavigationController.view.frame = CGRectMake(self.masterWidth, 0, vb.size.width, self.storyTitlesYCoordinate);
            self.feedDetailViewController.view.frame = CGRectMake(self.masterWidth,
                                                                  self.storyTitlesYCoordinate, 
                                                                  vb.size.width, 
                                                                  vb.size.height - storyTitlesYCoordinate);
        } completion:^(BOOL finished) {
            self.leftBorder.hidden = YES;
            [UIView animateWithDuration:smallTimeInterval delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.storyNavigationController.view.frame = CGRectMake(0, 0, vb.size.width, self.storyTitlesYCoordinate);
                self.feedDetailViewController.view.frame = CGRectMake(0, self.storyTitlesYCoordinate, vb.size.width, vb.size.height - storyTitlesYCoordinate);
                self.masterNavigationController.view.frame = CGRectMake(-1 * self.masterWidth, 0, self.masterWidth, vb.size.height);
            } completion:^(BOOL finished) {
                self.feedDetailIsVisible = YES;

                [self.dashboardViewController.view removeFromSuperview];
                [self.masterNavigationController.view removeFromSuperview];
            }];
        }];
    } else {
        // CASE: story titles on left
        if (resetLayout) {
            self.storyNavigationController.view.frame = CGRectMake(vb.size.width, 0,
                                                                   vb.size.width - (self.masterWidth-1),
                                                                   vb.size.height);
            [self.masterNavigationController
             pushViewController:self.feedDetailViewController
             animated:YES];
            [self interactiveTransitionFromFeedDetail:1];

            UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.storiesCollection.activeFeed];
            self.storyPageControl.navigationItem.titleView = titleLabel;
        }
        self.leftBorder.hidden = NO;

        [UIView animateWithDuration:.35 delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            [self interactiveTransitionFromFeedDetail:0];
        } completion:^(BOOL finished) {
            self.feedDetailIsVisible = YES;
//            NSLog(@"Finished hiding dashboard: %d", finished);
//            [self.dashboardViewController.view removeFromSuperview];
        }];
    }
}

- (void)handleOriginalNavGesture:(UIScreenEdgePanGestureRecognizer *)gesture {
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) return;
    
    self.interactiveOriginalTransition = YES;
    
    CGPoint point = [gesture locationInView:self.view];
    CGFloat viewWidth = CGRectGetWidth(self.view.bounds);
    CGFloat percentage = MIN(point.x, viewWidth) / viewWidth;
//    NSLog(@"back gesture: %d, %f - %f/%f", (int)gesture.state, percentage, point.x, viewWidth);
    
    if (gesture.state == UIGestureRecognizerStateChanged) {
        [appDelegate.masterContainerViewController interactiveTransitionFromOriginalView:percentage];
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        CGPoint velocity = [gesture velocityInView:self.view];
        if (velocity.x > 0) {
            [appDelegate.masterContainerViewController transitionFromOriginalView];
        } else {
            // Returning back to view, cancelling pop animation.
            [appDelegate.masterContainerViewController transitionToOriginalView:NO];
        }
    }
}

- (void)transitionToOriginalView {
    [self transitionToOriginalView:YES];
}

- (void)transitionToOriginalView:(BOOL)resetLayout {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    CGRect vb = [self.view bounds];
    
    self.originalViewIsVisible = YES;
    self.originalViewController = appDelegate.originalStoryViewController;

    if (resetLayout) {
        [self addChildViewController:self.originalNavigationController];
        [self.originalNavigationController.view setHidden:NO];
        if (![[self.originalNavigationController viewControllers]
              containsObject:self.originalViewController]) {
            [self.originalNavigationController pushViewController:self.originalViewController
                                                         animated:NO];
        } else {
            [self.originalViewController viewWillAppear:YES];
        }

        [self.view insertSubview:self.originalNavigationController.view
                    aboveSubview:self.masterNavigationController.view];
        [self.originalNavigationController didMoveToParentViewController:self];
        
        self.originalNavigationController.view.frame = CGRectMake(CGRectGetMaxX(vb),
                                                                  0,
                                                                  CGRectGetWidth(vb),
                                                                  CGRectGetHeight(vb));
        [self.originalViewController view]; // Force viewDidLoad
        [self.originalViewController loadInitialStory];
    }

    self.originalViewController.navigationItem.titleView.alpha = 1;
    self.originalViewController.navigationItem.leftBarButtonItem.customView.alpha = 1;
    [self.originalViewController becomeFirstResponder];
    
    [UIView animateWithDuration:.35 delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^
     {
         if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
             self.storyNavigationController.view.frame = CGRectMake(-100, 0, vb.size.width, self.storyTitlesYCoordinate);
             self.feedDetailViewController.view.frame = CGRectMake(-100, self.storyTitlesYCoordinate, vb.size.width, vb.size.height - storyTitlesYCoordinate);
             self.masterNavigationController.view.frame = CGRectMake(-1 * self.masterWidth, 0, self.masterWidth, vb.size.height);
         } else {
             self.masterNavigationController.view.frame = CGRectMake(-100, 0, self.masterWidth, vb.size.height);
             self.storyNavigationController.view.frame = CGRectMake(-100 + self.masterWidth - 1, 0, vb.size.width - self.masterWidth + 1, vb.size.height);
         }
         
         self.originalNavigationController.view.frame = CGRectMake(0, 0,
                                                                   CGRectGetWidth(vb),
                                                                   CGRectGetHeight(vb));
         CGRect frame = self.originalViewController.view.frame;
         frame.origin.x = 0;
         self.originalViewController.view.frame = frame;
     } completion:^(BOOL finished) {
         self.interactiveOriginalTransition = NO;
     }];
}

- (void)transitionFromOriginalView {
//    NSLog(@"Transition from Original View");
    
    [self.originalViewController viewWillDisappear:YES];
    self.originalViewIsVisible = NO;

    [self.storyPageControl becomeFirstResponder];
    
    [UIView animateWithDuration:0.35 delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^
     {
         [self layoutFeedDetailScreen];
     } completion:^(BOOL finished) {
         self.interactiveOriginalTransition = NO;
         [self.originalNavigationController removeFromParentViewController];
         [self.originalNavigationController.view setHidden:YES];
         [self.originalViewController viewDidDisappear:YES];
     }];
}

- (void)interactiveTransitionFromOriginalView:(CGFloat)percentage {
    CGRect vb = [self.view bounds];
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
//        CGRect originalNavFrame = self.originalNavigationController.view.frame;
//        originalNavFrame.origin.x = vb.size.width * percentage;
//        self.originalNavigationController.view.frame = originalNavFrame;
//        self.originalViewController.view.frame = originalNavFrame;
//        NSLog(@"Original frame: %@", NSStringFromCGRect(self.originalViewController.view.frame));
        
        CGRect feedDetailFrame = self.feedDetailViewController.view.frame;
        feedDetailFrame.origin.x = -1 * (1-percentage) * 100;
        self.feedDetailViewController.view.frame = feedDetailFrame;
        
        CGRect storyNavFrame = self.storyNavigationController.view.frame;
        storyNavFrame.origin.x = -1 * (1-percentage) * 100;
        self.storyNavigationController.view.frame = storyNavFrame;
    } else {
        CGRect originalNavFrame = self.originalNavigationController.view.frame;
        originalNavFrame.origin.x = vb.size.width * percentage * 0;
//        self.originalNavigationController.view.frame = originalNavFrame;
//        self.originalViewController.view.frame = originalNavFrame;
//        NSLog(@"Original frame: %@", NSStringFromCGRect([[[[self.originalNavigationController viewControllers] objectAtIndex:0] view] frame]));
        
        CGRect feedDetailFrame = self.masterNavigationController.view.frame;
        feedDetailFrame.origin.x = -1 * (1-percentage) * 100;
        self.masterNavigationController.view.frame = feedDetailFrame;
        
        CGRect storyNavFrame = self.storyNavigationController.view.frame;
        storyNavFrame.origin.x = self.masterWidth - 1 + -1 * (1-percentage) * 100;
        self.storyNavigationController.view.frame = storyNavFrame;
    }
    
//    self.originalNavigationController.navigationBar.alpha = 1 - percentage;
//    NSLog(@"Original subviews; %@", self.originalNavigationController.view.subviews);
    self.originalViewController.navigationItem.titleView.alpha = 1 - percentage;
    self.originalViewController.navigationItem.leftBarButtonItem.customView.alpha = 1 - percentage;
//    CGRect leftBorderFrame = leftBorder.frame;
//    leftBorderFrame.origin.x = storyNavFrame.origin.x - 1;
//    leftBorder.frame = leftBorderFrame;
}

- (void)interactiveTransitionFromFeedDetail:(CGFloat)percentage {
    [self.view insertSubview:self.dashboardViewController.view atIndex:0];
    [self.view addSubview:self.masterNavigationController.view];

    CGRect storyNavFrame = self.storyNavigationController.view.frame;
    storyNavFrame.origin.x = self.masterWidth - 1 + storyNavFrame.size.width * percentage;
    self.storyNavigationController.view.frame = storyNavFrame;
    
    CGRect dashboardFrame = self.dashboardViewController.view.frame;
    dashboardFrame.origin.x = self.masterWidth + -1 * (1-percentage) * dashboardFrame.size.width/6;
    self.dashboardViewController.view.frame = dashboardFrame;
}

- (void)transitionFromFeedDetail {
    [self transitionFromFeedDetail:YES];
}

- (void)transitionFromFeedDetail:(BOOL)resetLayout {
    if (!self.feedDetailIsVisible) {
        return;
    }
    
    [self.appDelegate hidePopover];
    
    if (self.isSharingStory) {
        [self transitionFromShareView];
    }
    
    self.feedDetailIsVisible = NO;
    CGRect vb = [self.view bounds];
    
    [appDelegate.dashboardViewController.storiesModule reloadData];
    
    // adding dashboardViewController and masterNavigationController
    [self.view insertSubview:self.dashboardViewController.view atIndex:0];
    [self.view addSubview:self.masterNavigationController.view];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
        // CASE: story titles on bottom
        if (resetLayout) {
            self.dashboardViewController.view.frame = CGRectMake(self.masterWidth, 0, vb.size.width - self.masterWidth, vb.size.height);
            self.masterNavigationController.view.frame = CGRectMake(-1 * self.masterWidth, 0, self.masterWidth, vb.size.height);
        }
        float smallTimeInterval = NB_DEFAULT_SLIDER_INTERVAL_OUT * self.masterWidth / vb.size.width;
        float largeTimeInterval = NB_DEFAULT_SLIDER_INTERVAL_OUT * ( vb.size.width - self.masterWidth) / vb.size.width;
        [self.masterNavigationController popViewControllerAnimated:NO];

        [UIView animateWithDuration:smallTimeInterval delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.masterNavigationController.view.frame = CGRectMake(0, 0, self.masterWidth, vb.size.height);
            self.storyNavigationController.view.frame = CGRectMake(self.masterWidth - 1,
                                                                   0, 
                                                                   vb.size.width, 
                                                                   self.storyTitlesYCoordinate);
            self.feedDetailViewController.view.frame = CGRectMake(self.masterWidth,
                                                                  self.storyTitlesYCoordinate, 
                                                                  vb.size.width, 
                                                                  vb.size.height - storyTitlesYCoordinate);
        } completion:^(BOOL finished) {
            if (self.feedDetailIsVisible) return;
            
            self.leftBorder.hidden = NO;
            [UIView animateWithDuration:largeTimeInterval delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.storyNavigationController.view.frame = CGRectMake(vb.size.width, 0, vb.size.width, self.storyTitlesYCoordinate);
                self.feedDetailViewController.view.frame = CGRectMake(vb.size.width, 
                                                                      self.storyTitlesYCoordinate, 
                                                                      vb.size.width, 
                                                                      vb.size.height - storyTitlesYCoordinate);
            } completion:^(BOOL finished) {
                if (self.feedDetailIsVisible) return;
                [self.storyNavigationController.view removeFromSuperview];
            }];
        }]; 
    } else {
        // CASE: story titles on left
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.storyNavigationController.view.frame = CGRectMake(vb.size.width, 
                                                                   0, 
                                                                   self.storyNavigationController.view.frame.size.width, 
                                                                   self.storyNavigationController.view.frame.size.height);
            self.dashboardViewController.view.frame = CGRectMake(self.masterWidth,
                                                                 0, 
                                                                 vb.size.width - self.masterWidth,
                                                                 vb.size.height);
        } completion:^(BOOL finished) {
            if (self.feedDetailIsVisible) return;
            [self.storyNavigationController.view removeFromSuperview];
        }];
    }
    
    if (feedDetailViewController.storiesCollection.transferredFromDashboard) {
        [dashboardViewController.storiesModule.storiesCollection
         transferStoriesFromCollection:feedDetailViewController.storiesCollection];
        [dashboardViewController.storiesModule fadeSelectedCell];
    }
}

- (void)transitionToShareView {
    if (isSharingStory) {
        return;
    } 
    
    [self.appDelegate hidePopover];
    CGRect vb = [self.view bounds];
    self.isSharingStory = YES;
    self.storyPageControl.traverseView.hidden = YES;
    
    // adding shareViewController
    [self.shareNavigationController removeFromParentViewController];
    [self addChildViewController:self.shareNavigationController];
    [self.view insertSubview:self.shareNavigationController.view
                aboveSubview:self.storyNavigationController.view];
    [self.shareNavigationController didMoveToParentViewController:self];

    self.shareNavigationController.view.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x, 
                                                           vb.size.height,
                                                           self.storyPageControl.view.frame.size.width,
                                                           NB_DEFAULT_SHARE_HEIGHT);
    [self.storyPageControl resizeScrollView];
    
    self.shareViewController.view.frame = CGRectMake(0,
                                           0, 
                                           self.shareNavigationController.view.frame.size.width, 
                                           self.shareNavigationController.view.frame.size.height - 44);
    [self.shareNavigationController.view setNeedsDisplay];
    [self.shareViewController.commentField becomeFirstResponder];

//    if (!self.keyboardIsShown)
//        [self keyboardWillShowOrHide:nil];
}

- (void)transitionFromShareView {
    if (!isSharingStory) {
        return;
    } 
    
    [self.appDelegate hidePopover];
    CGRect vb = [self.view bounds];
    self.isSharingStory = NO;
    self.storyPageControl.traverseView.hidden = NO;
    
    if ([self.shareViewController.commentField isFirstResponder] && self.keyboardIsShown) {
        self.isHidingStory = YES; // the flag allows the keyboard animation to also slide down the share view
        [self.shareViewController.commentField resignFirstResponder];
    } else {
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
            self.storyNavigationController.view.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x,
                                                                   0,
                                                                   self.storyNavigationController.view.frame.size.width,
                                                                   storyTitlesYCoordinate);
        } else {
            self.storyNavigationController.view.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x,
                                                                   0,
                                                                   self.storyNavigationController.view.frame.size.width,
                                                                   vb.size.height);
        }
        
        [UIView animateWithDuration:NB_DEFAULT_SLIDER_INTERVAL animations:^{
            self.shareNavigationController.view.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x,
                                                             vb.size.height,
                                                             self.storyNavigationController.view.frame.size.width,
                                                             NB_DEFAULT_SHARE_HEIGHT);
        } completion:^(BOOL finished) {
            [self.shareNavigationController.view removeFromSuperview];
        }];
    }
    
}

- (void)dragStoryToolbar:(int)yCoordinate {

    CGRect vb = [self.view bounds];
    // account for top toolbar and status bar
    yCoordinate = yCoordinate + 64 + 20;
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];   
    
    if (yCoordinate <= (vb.size.height)) {
        yCoordinate = MAX(yCoordinate, 384);
        self.storyTitlesYCoordinate = yCoordinate;
        [userPreferences setInteger:yCoordinate forKey:@"storyTitlesYCoordinate"];
        [userPreferences synchronize];

        self.storyNavigationController.view.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x, 
                                                               0, 
                                                               self.storyNavigationController.view.frame.size.width, 
                                                               yCoordinate);
        if (self.storyTitlesOnLeft) {
            self.storyTitlesStub.hidden = NO;
            self.storyTitlesStub.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x, 
                                                    yCoordinate, 
                                                    self.storyNavigationController.view.frame.size.width, 
                                                    vb.size.height - yCoordinate);
        } else {
            self.feedDetailViewController.view.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x, 
                                                                  yCoordinate, 
                                                                  self.storyNavigationController.view.frame.size.width, 
                                                                  vb.size.height - yCoordinate);
            [self.feedDetailViewController checkScroll];
        }
    } else if (yCoordinate >= (vb.size.height)){
        [userPreferences setInteger:1004 forKey:@"storyTitlesYCoordinate"];
        [userPreferences synchronize];
        self.storyTitlesYCoordinate = 1004;
        self.storyNavigationController.view.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x, 
                                                               0, 
                                                               self.storyNavigationController.view.frame.size.width, 
                                                               vb.size.height);
        if (self.storyTitlesOnLeft) {
            self.storyTitlesStub.hidden = NO;
            self.storyTitlesStub.frame = CGRectMake(self.feedDetailViewController.view.frame.origin.x, 
                                                    0, 
                                                    self.feedDetailViewController.view.frame.size.width, 
                                                    0);
        }
    }

    UITableView *stories = appDelegate.feedDetailViewController.storyTitlesTable;
    NSInteger location = appDelegate.storiesCollection.locationOfActiveStory;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:location inSection:0];
    NSArray *visible = [stories visibleCells];
    for (UITableViewCell *cell in visible) {
        if ([stories indexPathForCell:cell].row == indexPath.row) {
            indexPath = nil;
            break;
        }
    }
    if (indexPath && location >= 0) {
        [stories selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
    }
    
    [appDelegate.feedDetailViewController.notifier setNeedsLayout];

}

-(void)keyboardWillShowOrHide:(NSNotification*)notification {
    if (notification.name == UIKeyboardWillShowNotification) {
        self.keyboardIsShown = YES;
    } else if (notification.name == UIKeyboardWillHideNotification) {
        self.keyboardIsShown = NO;
    }

    if (self.keyboardIsShown && !self.isSharingStory) {
        return;
    }

    NSDictionary *userInfo = notification.userInfo;
    NSTimeInterval duration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    CGRect vb = [self.view bounds];
    CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect storyNavigationFrame = self.storyNavigationController.view.frame;

    self.shareNavigationController.view.frame = CGRectMake(storyNavigationFrame.origin.x,
                                                           vb.size.height,
                                                           storyNavigationFrame.size.width,
                                                           NB_DEFAULT_SHARE_HEIGHT);
    CGRect shareViewFrame = self.shareNavigationController.view.frame;
    
    if (self.keyboardIsShown && self.isSharingStory) {
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            storyNavigationFrame.size.height = vb.size.height - NB_DEFAULT_SHARE_HEIGHT - keyboardFrame.size.height + 44;
            shareViewFrame.origin.y = vb.size.height - NB_DEFAULT_SHARE_HEIGHT - keyboardFrame.size.height;
        } else {
            storyNavigationFrame.size.height = vb.size.height - NB_DEFAULT_SHARE_HEIGHT - keyboardFrame.size.height + 44;
            shareViewFrame.origin.y = vb.size.height - NB_DEFAULT_SHARE_HEIGHT - keyboardFrame.size.height;
        }
    } else if (self.isSharingStory) {
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            storyNavigationFrame.size.height = vb.size.height - NB_DEFAULT_SHARE_HEIGHT + 64;
            shareViewFrame.origin.y = vb.size.height - NB_DEFAULT_SHARE_HEIGHT;
        } else {
            storyNavigationFrame.size.height = vb.size.height - NB_DEFAULT_SHARE_HEIGHT + 64;
            shareViewFrame.origin.y = vb.size.height - NB_DEFAULT_SHARE_HEIGHT;
        }
    }

    // CASE: when dismissing the keyboard but not dismissing the share view
    if (!self.keyboardIsShown && !self.isHidingStory) {
        self.storyNavigationController.view.frame = storyNavigationFrame;
    // CASE: when dismissing the keyboard AND dismissing the share view
    } else if (!self.keyboardIsShown && self.isHidingStory) {
        if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
            self.storyNavigationController.view.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x,
                                                                   0,
                                                                   self.storyNavigationController.view.frame.size.width,
                                                                   vb.size.height);
        } else {
            self.storyNavigationController.view.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x,
                                                                   0,
                                                                   self.storyNavigationController.view.frame.size.width,
                                                                   vb.size.height);
        }
    }
    
    int newStoryNavigationFrameHeight = vb.size.height - NB_DEFAULT_SHARE_HEIGHT - keyboardFrame.size.height + 44;


    [UIView animateWithDuration:duration 
                          delay:0 
                        options:UIViewAnimationOptionBeginFromCurrentState | curve 
                     animations:^{
         if (self.isHidingStory) {
             self.shareNavigationController.view.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x,
                                                              vb.size.height,
                                                              self.storyNavigationController.view.frame.size.width,
                                                              NB_DEFAULT_SHARE_HEIGHT);
             if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
                 self.storyNavigationController.view.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x,
                                                                        0,
                                                                        self.storyNavigationController.view.frame.size.width,
                                                                        storyTitlesYCoordinate);
             } else {
                 self.storyNavigationController.view.frame = CGRectMake(self.storyNavigationController.view.frame.origin.x,
                                                                        0,
                                                                        self.storyNavigationController.view.frame.size.width,
                                                                        vb.size.height);
             }
         } else {
             self.shareNavigationController.view.frame = shareViewFrame;
             // if the toolbar is higher, animate
             if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
                 if (self.storyNavigationController.view.frame.size.height < newStoryNavigationFrameHeight) {
                     self.storyNavigationController.view.frame = storyNavigationFrame;
                 }
             }
         }
         
     } completion:^(BOOL finished) {
         if (self.keyboardIsShown) {
             self.storyNavigationController.view.frame = storyNavigationFrame;
             [self.storyPageControl.currentPage scrolltoComment];
             [self.storyPageControl resizeScrollView];
         } else {
             // remove the shareNavigationController after keyboard slides down
             if (self.isHidingStory) {
                 self.isHidingStory = NO;
                 [self.shareNavigationController.view removeFromSuperview];
             }
         }
     }];
}
    
@end
