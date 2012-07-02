//
//  DetailViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/9/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "SplitStoryDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "MGSplitViewController.h"
#import "ShareViewController.h"

@implementation SplitStoryDetailViewController

@synthesize scrollView;
@synthesize appDelegate;
@synthesize popoverController;
@synthesize bottomToolbar;

- (void)dealloc 
{
    [bottomToolbar release];
    [scrollView release];
    [super dealloc];
}

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
    // Add swipeGestures
    UISwipeGestureRecognizer *onFingerSwipeLeft = [[[UISwipeGestureRecognizer alloc] 
                                                     initWithTarget:self 
                                                     action:@selector(onFingerSwipeLeft)] autorelease];
    [onFingerSwipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
    [[self view] addGestureRecognizer:onFingerSwipeLeft];
    
    UISwipeGestureRecognizer *onFingerSwipeRight = [[[UISwipeGestureRecognizer alloc] 
                                                     initWithTarget:self 
                                                     action:@selector(onFingerSwipeRight)] autorelease];
    [onFingerSwipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
    [[self view] addGestureRecognizer:onFingerSwipeRight];
}

- (void)viewWillAppear:(BOOL)animated {
    self.bottomToolbar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    self.scrollView.contentSize = CGSizeMake(self.view.frame.size.width, self.view.frame.size.height);
}



- (void)viewDidUnload {
    [self setBottomToolbar:nil];
    [self setScrollView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

#pragma mark -
#pragma mark Rotation support


// Ensure that the view controller supports rotation and that the split view can therefore show in both portrait and landscape.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    appDelegate.shareViewController.view.hidden = YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[appDelegate adjustStoryDetailWebView]; 
    self.scrollView.contentSize = CGSizeMake(self.view.frame.size.width, self.view.frame.size.height);
    
    // copy the title from the master view to detail view
    if (appDelegate.splitStoryController.isShowingMaster) {
        self.navigationItem.titleView = nil;
    } else {
        UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.activeFeed];
        self.navigationItem.titleView = titleLabel;
    }
}


#pragma mark -
#pragma mark Gestures

- (void)onFingerSwipeLeft {
    if (appDelegate.inStoryDetail){ 
        [appDelegate adjustStoryDetailWebView];
        [appDelegate animateHidingMasterView];
    }
}

- (void)onFingerSwipeRight {
    if (appDelegate.inStoryDetail){  
        [appDelegate animateShowingMasterView];
    }
}

- (IBAction)doLogoutButton:(id)sender {
    [appDelegate confirmLogout];
}

@end