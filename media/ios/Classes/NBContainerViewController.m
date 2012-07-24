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

@interface NBContainerViewController ()

@property (nonatomic, strong) UINavigationController *masterNavigationController;
@property (nonatomic, strong) NewsBlurViewController *feedsViewController;
@property (nonatomic, strong) FeedDetailViewController *feedDetailViewController;
@property (nonatomic, strong) DashboardViewController *dashboardViewController;
@property (nonatomic, strong) StoryDetailViewController *storyDetailViewController;
@property (nonatomic, strong) ShareViewController *shareViewController;

@end

@implementation NBContainerViewController

@synthesize appDelegate;
@synthesize masterNavigationController;
@synthesize feedsViewController;
@synthesize feedDetailViewController;
@synthesize dashboardViewController;
@synthesize storyDetailViewController;
@synthesize shareViewController;

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
    
    // adding master navigation controller
    [self addChildViewController:self.masterNavigationController];
    [self.view addSubview:self.masterNavigationController.view];
    [self.masterNavigationController didMoveToParentViewController:self];
    
    // adding dashboardViewController 
    [self addChildViewController:self.dashboardViewController];
    [self.view addSubview:self.dashboardViewController.view];
    [self.dashboardViewController didMoveToParentViewController:self];
}

- (void)viewWillLayoutSubviews {
    [self adjustDashboardFrame];
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
    [self adjustDashboardFrame];
}

# pragma mark Screen Transitions and Layout

- (void)adjustDashboardFrame {
    CGRect vb = [self.view bounds];
    self.masterNavigationController.view.frame = CGRectMake(0, 0, NB_DEFAULT_MASTER_WIDTH, vb.size.height);
    self.dashboardViewController.view.frame = CGRectMake(NB_DEFAULT_MASTER_WIDTH + 1, 0, vb.size.width - NB_DEFAULT_MASTER_WIDTH - 1, vb.size.height);
}

- (void)transitionToFeedDetail {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	if (UIInterfaceOrientationIsPortrait(orientation)) {
        
    }
    
}

@end
