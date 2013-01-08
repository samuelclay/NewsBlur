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
#import "ShareViewController.h"
#import "UserProfileViewController.h"
#import "InteractionCell.h"
#import "ActivityCell.h"
#import "FeedsMenuViewController.h"
#import "FeedDetailMenuViewController.h"
#import "FontSettingsViewController.h"
#import "AddSiteViewController.h"
#import "TrainerViewController.h"

#define NB_DEFAULT_MASTER_WIDTH 270
#define NB_DEFAULT_STORY_TITLE_HEIGHT 1004
#define NB_DEFAULT_SLIDER_INTERVAL 0.35
#define NB_DEFAULT_SLIDER_INTERVAL_OUT 0.35
#define NB_DEFAULT_SHARE_HEIGHT 144
#define NB_DEFAULT_STORY_TITLE_SNAP_THRESHOLD 60

@interface NBContainerViewController ()

@property (nonatomic, strong) UINavigationController *masterNavigationController;
@property (nonatomic, strong) UINavigationController *storyNavigationController;
@property (nonatomic, strong) UINavigationController *shareNavigationController;
@property (nonatomic, strong) NewsBlurViewController *feedsViewController;
@property (nonatomic, strong) FeedDetailViewController *feedDetailViewController;
@property (nonatomic, strong) DashboardViewController *dashboardViewController;
@property (nonatomic, strong) StoryDetailViewController *storyDetailViewController;
@property (nonatomic, strong) StoryPageControl *storyPageControl;
@property (nonatomic, strong) ShareViewController *shareViewController;
@property (nonatomic, strong) UIView *storyTitlesStub;
@property (readwrite) BOOL storyTitlesOnLeft;
@property (readwrite) int storyTitlesYCoordinate;

@property (readwrite) BOOL isSharingStory;
@property (readwrite) BOOL isHidingStory;
@property (readwrite) BOOL feedDetailIsVisible;

@property (nonatomic, strong) UIPopoverController *popoverController;

@end

@implementation NBContainerViewController

@synthesize appDelegate;
@synthesize masterNavigationController;
@synthesize shareNavigationController;
@synthesize feedsViewController;
@synthesize feedDetailViewController;
@synthesize dashboardViewController;
@synthesize storyDetailViewController;
@synthesize storyPageControl;
@synthesize shareViewController;
@synthesize feedDetailIsVisible;
@synthesize storyNavigationController;
@synthesize storyTitlesYCoordinate;
@synthesize storyTitlesOnLeft;
@synthesize popoverController;
@synthesize storyTitlesStub;
@synthesize isSharingStory;
@synthesize isHidingStory;

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
    
    self.view.backgroundColor = [UIColor blackColor]; 
    
    self.masterNavigationController = appDelegate.navigationController;
    self.feedsViewController = appDelegate.feedsViewController;
    self.dashboardViewController = appDelegate.dashboardViewController;
    self.feedDetailViewController = appDelegate.feedDetailViewController;
    self.storyDetailViewController = appDelegate.storyDetailViewController;
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
    
    UINavigationController *shareNav = [[UINavigationController alloc] initWithRootViewController:self.shareViewController];
    self.shareNavigationController = shareNav;
    
    // set default y coordinate for feedDetailY from saved preferences
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSInteger savedStoryTitlesYCoordinate = [userPreferences integerForKey:@"storyTitlesYCoordinate"];
    if (savedStoryTitlesYCoordinate == 1004) {
        self.storyTitlesYCoordinate = savedStoryTitlesYCoordinate;
        self.storyTitlesOnLeft = YES;
    } else if (savedStoryTitlesYCoordinate) {
        self.storyTitlesYCoordinate = savedStoryTitlesYCoordinate;
        self.storyTitlesOnLeft = NO;
    } else {
        self.storyTitlesYCoordinate = NB_DEFAULT_STORY_TITLE_HEIGHT;
        self.storyTitlesOnLeft = YES;
    }
    
    // set up story titles stub
    UIView * storyTitlesPlaceholder = [[UIView alloc] initWithFrame:CGRectZero];
    storyTitlesPlaceholder.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;;
    storyTitlesPlaceholder.autoresizesSubviews = YES;
    storyTitlesPlaceholder.backgroundColor = [UIColor whiteColor];
        
    self.storyTitlesStub = storyTitlesPlaceholder;
    [self.view addSubview:self.storyTitlesStub];
}

- (void)viewWillLayoutSubviews {
    [self adjustDashboardScreen];
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    if (!self.feedDetailIsVisible) {
        [self adjustDashboardScreen];
    } else {
        [self adjustFeedDetailScreen];
    }
}

# pragma mark Modals and Popovers

- (void)showUserProfilePopover:(id)sender {
    if (popoverController.isPopoverVisible) {
        [popoverController dismissPopoverAnimated:NO];
        popoverController = nil;
        return;
    }
    
    popoverController = [[UIPopoverController alloc]
                         initWithContentViewController:appDelegate.userProfileNavigationController];
    
    popoverController.delegate = self;
    
    [popoverController setPopoverContentSize:CGSizeMake(320, 454)];

    if ([sender class] == [InteractionCell class] ||
        [sender class] == [ActivityCell class]) {
        InteractionCell *cell = (InteractionCell *)sender;
        
        [popoverController presentPopoverFromRect:cell.bounds 
                                                inView:cell
                              permittedArrowDirections:UIPopoverArrowDirectionAny 
                                              animated:YES];
    } else if ([sender class] == [UIBarButtonItem class]) {
        [popoverController presentPopoverFromBarButtonItem:sender 
                                  permittedArrowDirections:UIPopoverArrowDirectionAny 
                                                  animated:YES];  
    } else {
        CGRect frame = [sender CGRectValue];
        [popoverController presentPopoverFromRect:frame 
                                           inView:self.storyPageControl.view
                         permittedArrowDirections:UIPopoverArrowDirectionAny 
                                         animated:YES];
    } 
}

- (void)showSitePopover:(id)sender {
    if (popoverController.isPopoverVisible) {
        [popoverController dismissPopoverAnimated:NO];
        popoverController = nil;
        return;
    }
    
    popoverController = [[UIPopoverController alloc]
                         initWithContentViewController:appDelegate.addSiteViewController];
    
    popoverController.delegate = self;
    
    [popoverController setPopoverContentSize:CGSizeMake(320, 454)];
    
    if ([sender class] == [InteractionCell class] ||
        [sender class] == [ActivityCell class]) {
        InteractionCell *cell = (InteractionCell *)sender;
        
        [popoverController presentPopoverFromRect:cell.bounds 
                                           inView:cell
                         permittedArrowDirections:UIPopoverArrowDirectionAny 
                                         animated:YES];
    } else if ([sender class] == [UIBarButtonItem class]) {
        [popoverController presentPopoverFromBarButtonItem:sender 
                                  permittedArrowDirections:UIPopoverArrowDirectionAny 
                                                  animated:YES];  
    } else {
        CGRect frame = [sender CGRectValue];
        [popoverController presentPopoverFromRect:frame 
                                           inView:self.feedsViewController.view
                         permittedArrowDirections:UIPopoverArrowDirectionAny 
                                         animated:YES];
    } 
}


- (void)showFeedMenuPopover:(id)sender {
    if (popoverController.isPopoverVisible) {
        [popoverController dismissPopoverAnimated:NO];
        popoverController = nil;
        return;
    }
    
    popoverController = [[UIPopoverController alloc]
                         initWithContentViewController:appDelegate.feedsMenuViewController];
    
    popoverController.delegate = self;
    
    
    [popoverController setPopoverContentSize:CGSizeMake(200, 76)];
    //    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc]
    //                                       initWithCustomView:sender];
    [popoverController presentPopoverFromBarButtonItem:sender
                              permittedArrowDirections:UIPopoverArrowDirectionAny
                                              animated:YES];
}

- (void)showFeedDetailMenuPopover:(id)sender {
    if (popoverController.isPopoverVisible) {
        [popoverController dismissPopoverAnimated:NO];
        popoverController = nil;
        return;
    }
    
    popoverController = [[UIPopoverController alloc]
                         initWithContentViewController:appDelegate.feedDetailMenuViewController];
    
    popoverController.delegate = self;
    
    
    [popoverController setPopoverContentSize:CGSizeMake(260, appDelegate.isRiverView ? 38*4 : 38*6)];
    [popoverController presentPopoverFromBarButtonItem:sender
                              permittedArrowDirections:UIPopoverArrowDirectionAny
                                              animated:YES];
}

- (void)showFontSettingsPopover:(id)sender {
    if (popoverController.isPopoverVisible) {
        [popoverController dismissPopoverAnimated:NO];
        popoverController = nil;
        return;
    }
    
    popoverController = [[UIPopoverController alloc]
                         initWithContentViewController:appDelegate.fontSettingsViewController];
    
    popoverController.delegate = self;
    
    
    [popoverController setPopoverContentSize:CGSizeMake(240, 38*7)];
    //    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc]
    //                                       initWithCustomView:sender];
    [popoverController presentPopoverFromBarButtonItem:sender
                              permittedArrowDirections:UIPopoverArrowDirectionAny
                                              animated:YES];
}

- (void)showTrainingPopover:(id)sender {
    if (popoverController.isPopoverVisible) {
        [popoverController dismissPopoverAnimated:NO];
//        popoverController = nil;
//        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .001 * NSEC_PER_SEC),
                   dispatch_get_current_queue(), ^{
        popoverController = [[UIPopoverController alloc]
                             initWithContentViewController:appDelegate.trainerViewController];
        popoverController.delegate = self;
        
        [popoverController setPopoverContentSize:CGSizeMake(420, 382)];
        if ([sender class] == [UIBarButtonItem class]) {
           [popoverController presentPopoverFromBarButtonItem:sender
                                     permittedArrowDirections:UIPopoverArrowDirectionAny
                                                     animated:NO];
        } else {
           CGRect frame = [sender CGRectValue];
           [popoverController presentPopoverFromRect:frame
                                              inView:self.storyPageControl.view
                            permittedArrowDirections:UIPopoverArrowDirectionAny
                                            animated:YES];
        }
                   });
}

- (void)hidePopover {
    if (popoverController.isPopoverVisible) {
        [popoverController dismissPopoverAnimated:YES];
    }
    popoverController = nil;
    [appDelegate.modalNavigationController dismissModalViewControllerAnimated:YES];
}


- (void)syncNextPreviousButtons {
    [self.storyPageControl setNextPreviousButtons];
}

# pragma mark Screen Transitions and Layout

- (void)adjustDashboardScreen {
    CGRect vb = [self.view bounds];
    self.masterNavigationController.view.frame = CGRectMake(0, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
    self.dashboardViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 0, vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1, vb.size.height);
}

- (void)adjustFeedDetailScreen {
    CGRect vb = [self.view bounds];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
        // add the back button
        self.storyPageControl.navigationItem.leftBarButtonItem = self.storyPageControl.buttonBack;
        
        // set center title
        UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.activeFeed];
        self.storyPageControl.navigationItem.titleView = titleLabel;
        
        if ([[self.masterNavigationController viewControllers] containsObject:self.feedDetailViewController]) {
            [self.masterNavigationController popViewControllerAnimated:NO];
        }
        self.storyNavigationController.view.frame = CGRectMake(0, 0, vb.size.width, self.storyTitlesYCoordinate);
        self.feedDetailViewController.view.frame = CGRectMake(0, self.storyTitlesYCoordinate, vb.size.width, vb.size.height - self.storyTitlesYCoordinate);
        [self.view insertSubview:self.feedDetailViewController.view atIndex:0];
        [self.masterNavigationController.view removeFromSuperview];
    } else {
        // remove the back button
        self.storyPageControl.navigationItem.leftBarButtonItem = nil;
        
        // remove center title
        self.storyPageControl.navigationItem.titleView = nil;
        
        if (![[self.masterNavigationController viewControllers] containsObject:self.feedDetailViewController]) {
            [self.masterNavigationController pushViewController:self.feedDetailViewController animated:NO];        
        }
        [self.view addSubview:self.masterNavigationController.view];
        self.masterNavigationController.view.frame = CGRectMake(0, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
        self.storyNavigationController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 0, vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1, vb.size.height);
    }
}

- (void)adjustFeedDetailScreenForStoryTitles {
    CGRect vb = [self.view bounds];
    if (!self.storyTitlesOnLeft) {
        if (self.storyTitlesYCoordinate > 890) {
            NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];   
            // save coordinate
            [userPreferences setInteger:1004 forKey:@"storyTitlesYCoordinate"];
            [userPreferences synchronize];
            self.storyTitlesYCoordinate = 1004;
            // slide to the left
            
            self.storyTitlesOnLeft = YES;
            
            // remove the back button
            self.storyPageControl.navigationItem.leftBarButtonItem = nil;
            
            // remove center title
            self.storyPageControl.navigationItem.titleView = nil;
            
            if (![[self.masterNavigationController viewControllers] containsObject:self.feedDetailViewController]) {
                [self.masterNavigationController pushViewController:self.feedDetailViewController animated:NO];        
            }
            
            [self.view addSubview:self.masterNavigationController.view];
            self.masterNavigationController.view.frame = CGRectMake(-NB_DEFAULT_MASTER_WIDTH, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
            [UIView animateWithDuration:NB_DEFAULT_SLIDER_INTERVAL delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                self.masterNavigationController.view.frame = CGRectMake(0, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
                self.storyNavigationController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 0, vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1, vb.size.height);
            } completion:^(BOOL finished) {
                [self.feedDetailViewController checkScroll];
                [appDelegate.storyPageControl refreshPages];
                [appDelegate adjustStoryDetailWebView];
                [self.feedDetailViewController.storyTitlesTable reloadData];
            }];
        } 
    } else if (self.storyTitlesOnLeft) {
        if (self.storyTitlesYCoordinate == 1004) {
            return;
        } else if (self.storyTitlesYCoordinate > 890) {
            NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];   
            // save coordinate
            [userPreferences setInteger:890 forKey:@"storyTitlesYCoordinate"];
            [userPreferences synchronize];
            self.storyTitlesYCoordinate = 890;
        }
        self.storyTitlesOnLeft = NO;
        
        // add the back button
        self.storyPageControl.navigationItem.leftBarButtonItem = self.storyPageControl.buttonBack;
        
        // set center title
        UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.activeFeed];
        self.storyPageControl.navigationItem.titleView = titleLabel;
        
        [UIView animateWithDuration:NB_DEFAULT_SLIDER_INTERVAL delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
//            self.masterNavigationController.view.frame = CGRectMake(-NB_DEFAULT_MASTER_WIDTH, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
            
            [self.masterNavigationController.view removeFromSuperview];
            self.storyNavigationController.view.frame = CGRectMake(0, 0, vb.size.width, storyTitlesYCoordinate);
            
            self.storyTitlesStub.frame = CGRectMake(0, storyTitlesYCoordinate, vb.size.width, vb.size.height - storyTitlesYCoordinate - 44 - 20);
        } completion:^(BOOL finished) {
            if ([[self.masterNavigationController viewControllers] containsObject:self.feedDetailViewController]) {
                [self.masterNavigationController popViewControllerAnimated:NO];
            }
            [self.view insertSubview:self.feedDetailViewController.view aboveSubview:self.storyTitlesStub];
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
    [self hidePopover];
    self.feedDetailIsVisible = YES;
    CGRect vb = [self.view bounds];
        
    // adding feedDetailViewController 
    [self addChildViewController:self.feedDetailViewController];
    [self.view addSubview:self.feedDetailViewController.view];
    [self.feedDetailViewController didMoveToParentViewController:self];
    
    // adding storyDetailViewController
    [self addChildViewController:self.storyNavigationController];
    [self.view addSubview:self.storyNavigationController.view];
    [self.storyNavigationController didMoveToParentViewController:self];
    
    // reset the storyDetailViewController components
    self.storyPageControl.currentPage.webView.hidden = YES;
    self.storyPageControl.nextPage.webView.hidden = YES;
    self.storyPageControl.bottomPlaceholderToolbar.hidden = NO;
    self.storyPageControl.progressViewContainer.hidden = YES;
    self.storyPageControl.navigationItem.rightBarButtonItems = nil;
    [self.storyPageControl resetPages];
    int unreadCount = appDelegate.unreadCount;
    if (unreadCount == 0) {
        self.storyPageControl.progressView.progress = 1;
    } else {
        self.storyPageControl.progressView.progress = 0;
    }
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
        // CASE: story titles on bottom
        self.storyPageControl.navigationItem.leftBarButtonItem = self.storyPageControl.buttonBack;
        
        self.storyNavigationController.view.frame = CGRectMake(vb.size.width, 0, vb.size.width, storyTitlesYCoordinate);
        self.feedDetailViewController.view.frame = CGRectMake(vb.size.width, 
                                                              self.storyTitlesYCoordinate, 
                                                              vb.size.width, 
                                                              vb.size.height - storyTitlesYCoordinate);
        float largeTimeInterval = NB_DEFAULT_SLIDER_INTERVAL * ( vb.size.width - NB_DEFAULT_MASTER_WIDTH) / vb.size.width;
        float smallTimeInterval = NB_DEFAULT_SLIDER_INTERVAL * NB_DEFAULT_MASTER_WIDTH / vb.size.width;
        
        [UIView animateWithDuration:largeTimeInterval delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.storyNavigationController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 0, vb.size.width, self.storyTitlesYCoordinate);
            self.feedDetailViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 
                                                                  self.storyTitlesYCoordinate, 
                                                                  vb.size.width, 
                                                                  vb.size.height - storyTitlesYCoordinate);
        } completion:^(BOOL finished) {
            
            [UIView animateWithDuration:smallTimeInterval delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.storyNavigationController.view.frame = CGRectMake(0, 0, vb.size.width, self.storyTitlesYCoordinate);
                self.feedDetailViewController.view.frame = CGRectMake(0, self.storyTitlesYCoordinate, vb.size.width, vb.size.height - storyTitlesYCoordinate);
                self.masterNavigationController.view.frame = CGRectMake(-NB_DEFAULT_MASTER_WIDTH, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
            } completion:^(BOOL finished) {
                [self.dashboardViewController.view removeFromSuperview];
                [self.masterNavigationController.view removeFromSuperview];
            }];
        }];
        
        
        // set center title
        UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.activeFeed];
        self.storyPageControl.navigationItem.titleView = titleLabel;
    } else {
        // CASE: story titles on left
        self.storyPageControl.navigationItem.leftBarButtonItem = nil;
        
        [self.masterNavigationController pushViewController:self.feedDetailViewController animated:YES];
        self.storyNavigationController.view.frame = CGRectMake(vb.size.width, 0,
                                                               vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1,
                                                               vb.size.height);
        
        [UIView animateWithDuration:.35 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.storyNavigationController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 
                                                                   0, 
                                                                   vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1, 
                                                                   vb.size.height);
        } completion:^(BOOL finished) {
            [self.dashboardViewController.view removeFromSuperview];
        }];

        // remove center title
        self.storyPageControl.navigationItem.titleView = nil;
    }
}

- (void)transitionFromFeedDetail {
    if (!self.feedDetailIsVisible) {
        return;
    }
    
    [self hidePopover];
    
     if (self.isSharingStory) {
        [self transitionFromShareView];
    }
    
    self.feedDetailIsVisible = NO;
    CGRect vb = [self.view bounds];
    
    // adding dashboardViewController and masterNavigationController
    [self.view insertSubview:self.dashboardViewController.view atIndex:0];
    [self.view addSubview:self.masterNavigationController.view];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsPortrait(orientation) && !self.storyTitlesOnLeft) {
        // CASE: story titles on bottom
        self.dashboardViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 0, vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1, vb.size.height);
        self.masterNavigationController.view.frame = CGRectMake(-NB_DEFAULT_MASTER_WIDTH, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
        
        float smallTimeInterval = NB_DEFAULT_SLIDER_INTERVAL_OUT * NB_DEFAULT_MASTER_WIDTH / vb.size.width;
        float largeTimeInterval = NB_DEFAULT_SLIDER_INTERVAL_OUT * ( vb.size.width - NB_DEFAULT_MASTER_WIDTH) / vb.size.width;

        [UIView animateWithDuration:smallTimeInterval delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.masterNavigationController.view.frame = CGRectMake(0, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
            self.storyNavigationController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH, 
                                                                   0, 
                                                                   vb.size.width, 
                                                                   self.storyTitlesYCoordinate);
            self.feedDetailViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH, 
                                                                  self.storyTitlesYCoordinate, 
                                                                  vb.size.width, 
                                                                  vb.size.height - storyTitlesYCoordinate);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:largeTimeInterval delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.storyNavigationController.view.frame = CGRectMake(vb.size.width, 0, vb.size.width, self.storyTitlesYCoordinate);
                self.feedDetailViewController.view.frame = CGRectMake(vb.size.width, 
                                                                      self.storyTitlesYCoordinate, 
                                                                      vb.size.width, 
                                                                      vb.size.height - storyTitlesYCoordinate);
            } completion:^(BOOL finished) {
                [self.storyNavigationController.view removeFromSuperview];
                [self.feedDetailViewController.view removeFromSuperview];
            }];
        }]; 
    } else {
        // CASE: story titles on left
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.storyNavigationController.view.frame = CGRectMake(vb.size.width, 
                                                                   0, 
                                                                   self.storyNavigationController.view.frame.size.width, 
                                                                   self.storyNavigationController.view.frame.size.height);
            self.dashboardViewController.view.frame = CGRectMake(0, 
                                                                 0, 
                                                                 vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1, 
                                                                 vb.size.height);
        } completion:^(BOOL finished) {
            [self.storyNavigationController.view removeFromSuperview];
            [self.feedDetailViewController.view removeFromSuperview];
        }];
    }
}

- (void)transitionToShareView {
    if (isSharingStory) {
        return;
    } 
    
    [self hidePopover];
    CGRect vb = [self.view bounds];
    self.isSharingStory = YES;
    
    // adding shareViewController
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
}

- (void)transitionFromShareView {
    if (!isSharingStory) {
        return;
    } 
    
    [self hidePopover];
    CGRect vb = [self.view bounds];
    self.isSharingStory = NO;
    
    if ([self.shareViewController.commentField isFirstResponder]) {
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
    yCoordinate = yCoordinate + 44 + 20;
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];   
    
    if (yCoordinate > 344 && yCoordinate <= (vb.size.height)) {
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
    
}

-(void)keyboardWillShowOrHide:(NSNotification*)notification {
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
    
    
    if ([notification.name isEqualToString:@"UIKeyboardWillShowNotification"]) {
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            storyNavigationFrame.size.height = vb.size.height - NB_DEFAULT_SHARE_HEIGHT - keyboardFrame.size.height + 44;
            shareViewFrame.origin.y = vb.size.height - NB_DEFAULT_SHARE_HEIGHT - keyboardFrame.size.height;
        } else {
            storyNavigationFrame.size.height = vb.size.height - NB_DEFAULT_SHARE_HEIGHT - keyboardFrame.size.width + 44;
            shareViewFrame.origin.y = vb.size.height - NB_DEFAULT_SHARE_HEIGHT - keyboardFrame.size.width;
        }
    } else {
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            storyNavigationFrame.size.height = vb.size.height - NB_DEFAULT_SHARE_HEIGHT + 44;
            shareViewFrame.origin.y = vb.size.height - NB_DEFAULT_SHARE_HEIGHT;
        } else {
            storyNavigationFrame.size.height = vb.size.height - NB_DEFAULT_SHARE_HEIGHT + 44;
            shareViewFrame.origin.y = vb.size.height - NB_DEFAULT_SHARE_HEIGHT;
        }
    }

    // CASE: when dismissing the keyboard but not dismissing the share view
    if ([notification.name isEqualToString:@"UIKeyboardWillHideNotification"] && !self.isHidingStory) {
        self.storyNavigationController.view.frame = storyNavigationFrame;
    // CASE: when dismissing the keyboard AND dismissing the share view
    } else if ([notification.name isEqualToString:@"UIKeyboardWillHideNotification"] && self.isHidingStory) {
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
             if (UIInterfaceOrientationIsPortrait(orientation)) {
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
         if ([notification.name isEqualToString:@"UIKeyboardWillShowNotification"]) {
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