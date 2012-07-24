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
#import "ShareViewController.h"

#define NB_DEFAULT_MASTER_WIDTH 270
#define NB_DEFAULT_STORY_TITLE_HEIGHT 250
#define NB_DEFAULT_SLIDER_INTERVAL 0.4

@interface NBContainerViewController ()

@property (nonatomic, strong) UINavigationController *masterNavigationController;
@property (nonatomic, strong) NewsBlurViewController *feedsViewController;
@property (nonatomic, strong) FeedDetailViewController *feedDetailViewController;
@property (nonatomic, strong) DashboardViewController *dashboardViewController;
@property (nonatomic, strong) StoryDetailViewController *storyDetailViewController;
@property (nonatomic, strong) ShareViewController *shareViewController;

@property (readwrite) BOOL feedDetailIsVisible;

@end

@implementation NBContainerViewController

@synthesize appDelegate;
@synthesize masterNavigationController;
@synthesize feedsViewController;
@synthesize feedDetailViewController;
@synthesize dashboardViewController;
@synthesize storyDetailViewController;
@synthesize shareViewController;
@synthesize feedDetailIsVisible;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        

    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor blackColor]; 
    
    self.masterNavigationController = appDelegate.navigationController;
    self.feedsViewController = appDelegate.feedsViewController;
    self.dashboardViewController = appDelegate.dashboardViewController;
    self.feedDetailViewController = appDelegate.feedDetailViewController;
    self.storyDetailViewController = appDelegate.storyDetailViewController;
    
    // adding dashboardViewController 
    [self addChildViewController:self.dashboardViewController];
    [self.view addSubview:self.dashboardViewController.view];
    [self.dashboardViewController didMoveToParentViewController:self];
    
    // adding master navigation controller
    [self addChildViewController:self.masterNavigationController];
    [self.view addSubview:self.masterNavigationController.view];
    [self.masterNavigationController didMoveToParentViewController:self];
    
    // set default x coordinate for feedDetailY from saved preferences
//    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
//    NSInteger savedFeedDetailPortraitYCoordinate = [userPreferences integerForKey:@"feedDetailPortraitYCoordinate"];
//    if (savedFeedDetailPortraitYCoordinate) {
//        self.feedDetailPortraitYCoordinate = savedFeedDetailPortraitYCoordinate;
//    } else {
//        self.feedDetailPortraitYCoordinate = 960;
//    }
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

# pragma mark Screen Transitions and Layout

- (void)adjustDashboardScreen {
    CGRect vb = [self.view bounds];
    self.masterNavigationController.view.frame = CGRectMake(0, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
    self.dashboardViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 0, vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1, vb.size.height);
}

- (void)adjustFeedDetailScreen {
    CGRect vb = [self.view bounds];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsPortrait(orientation)) {
        if ([[self.masterNavigationController viewControllers] containsObject:self.feedDetailViewController]) {
            [self.masterNavigationController popViewControllerAnimated:NO];
        }
        self.storyDetailViewController.view.frame = CGRectMake(0, 0, vb.size.width, vb.size.height - NB_DEFAULT_STORY_TITLE_HEIGHT);
        self.feedDetailViewController.view.frame = CGRectMake(0, vb.size.height - NB_DEFAULT_STORY_TITLE_HEIGHT, vb.size.width, NB_DEFAULT_STORY_TITLE_HEIGHT);
        [self.view addSubview:self.feedDetailViewController.view];
        [self.masterNavigationController.view removeFromSuperview];
    } else {
        if (![[self.masterNavigationController viewControllers] containsObject:self.feedDetailViewController]) {
            [self.masterNavigationController pushViewController:self.feedDetailViewController animated:NO];        
        }
        [self.view addSubview:self.masterNavigationController.view];
        self.masterNavigationController.view.frame = CGRectMake(0, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
        self.storyDetailViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 0, vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1, vb.size.height);
    }

}

- (void)transitionToFeedDetail {
    self.feedDetailIsVisible = YES;
    CGRect vb = [self.view bounds];
        
    // adding feedDetailViewController 
    [self addChildViewController:self.feedDetailViewController];
    [self.view addSubview:self.feedDetailViewController.view];
    [self.feedDetailViewController didMoveToParentViewController:self];
    
    // adding storyDetailViewController 
    [self addChildViewController:self.storyDetailViewController];
    [self.view addSubview:self.storyDetailViewController.view];
    [self.storyDetailViewController didMoveToParentViewController:self];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsPortrait(orientation)) {
        self.storyDetailViewController.view.frame = CGRectMake(vb.size.width, 0, vb.size.width, vb.size.height - NB_DEFAULT_STORY_TITLE_HEIGHT);
        self.feedDetailViewController.view.frame = CGRectMake(vb.size.width, vb.size.height - NB_DEFAULT_STORY_TITLE_HEIGHT, vb.size.width, NB_DEFAULT_STORY_TITLE_HEIGHT);
        float largeTimeInterval = NB_DEFAULT_SLIDER_INTERVAL * ( vb.size.width - NB_DEFAULT_MASTER_WIDTH) / vb.size.width;
        float smallTimeInterval = NB_DEFAULT_SLIDER_INTERVAL * NB_DEFAULT_MASTER_WIDTH / vb.size.width;
        
        [UIView animateWithDuration:largeTimeInterval delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.storyDetailViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 0, vb.size.width, vb.size.height - NB_DEFAULT_STORY_TITLE_HEIGHT);
            self.feedDetailViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, vb.size.height - NB_DEFAULT_STORY_TITLE_HEIGHT, vb.size.width, NB_DEFAULT_STORY_TITLE_HEIGHT);
        } completion:^(BOOL finished) {
            
            [UIView animateWithDuration:smallTimeInterval delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.storyDetailViewController.view.frame = CGRectMake(0, 0, vb.size.width, vb.size.height - NB_DEFAULT_STORY_TITLE_HEIGHT);
                self.feedDetailViewController.view.frame = CGRectMake(0, vb.size.height - NB_DEFAULT_STORY_TITLE_HEIGHT, vb.size.width, NB_DEFAULT_STORY_TITLE_HEIGHT);
                self.masterNavigationController.view.frame = CGRectMake( -NB_DEFAULT_MASTER_WIDTH, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
            } completion:^(BOOL finished) {
                
                [self.dashboardViewController.view removeFromSuperview];
                [self.masterNavigationController.view removeFromSuperview];
            }];
        }]; 
        
    } else {
        [self.masterNavigationController pushViewController:self.feedDetailViewController animated:YES];
        self.storyDetailViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 0, vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1, vb.size.height);
        [self.dashboardViewController.view removeFromSuperview];
    }
}

- (void)transitionFromFeedDetail {
    self.feedDetailIsVisible = NO;
    CGRect vb = [self.view bounds];
    
    // adding dashboardViewController and masterNavigationController
    [self.view insertSubview:self.dashboardViewController.view atIndex:0];
    [self.view addSubview:self.masterNavigationController.view];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsPortrait(orientation)) {
        self.dashboardViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 0, vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1, vb.size.height);
        self.masterNavigationController.view.frame = CGRectMake(-NB_DEFAULT_MASTER_WIDTH, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
        
        float largeTimeInterval = NB_DEFAULT_SLIDER_INTERVAL * ( vb.size.width - NB_DEFAULT_MASTER_WIDTH) / vb.size.width;
        float smallTimeInterval = NB_DEFAULT_SLIDER_INTERVAL * NB_DEFAULT_MASTER_WIDTH / vb.size.width;
        
        [UIView animateWithDuration:largeTimeInterval delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.masterNavigationController.view.frame = CGRectMake(0, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
            self.storyDetailViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH, 0, vb.size.width, vb.size.height - NB_DEFAULT_STORY_TITLE_HEIGHT);
            self.feedDetailViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH, vb.size.height - NB_DEFAULT_STORY_TITLE_HEIGHT, vb.size.width, NB_DEFAULT_STORY_TITLE_HEIGHT);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:smallTimeInterval delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.storyDetailViewController.view.frame = CGRectMake(vb.size.width, 0, vb.size.width, vb.size.height - NB_DEFAULT_STORY_TITLE_HEIGHT);
                self.feedDetailViewController.view.frame = CGRectMake(vb.size.width, vb.size.height - NB_DEFAULT_STORY_TITLE_HEIGHT, vb.size.width, NB_DEFAULT_STORY_TITLE_HEIGHT);
            } completion:^(BOOL finished) {
                [self.storyDetailViewController.view removeFromSuperview];
                [self.feedDetailViewController.view removeFromSuperview];
            }];
        }]; 
    } else {
//        [self.masterNavigationController pushViewController:self.feedDetailViewController animated:YES];
//        self.storyDetailViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 0, vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1, vb.size.height);
//        [self.dashboardViewController.view removeFromSuperview];
    }
}


@end
