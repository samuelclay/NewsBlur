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

@implementation SplitStoryDetailViewController

@synthesize appDelegate;
@synthesize popoverController;

- (void)dealloc 
{
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



- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

#pragma mark -
#pragma mark Rotation support


// Ensure that the view controller supports rotation and that the split view can therefore show in both portrait and landscape.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[appDelegate adjustStoryDetailWebView:NO shouldCheckLayout:YES]; 
}


#pragma mark -
#pragma mark Gestures

- (void)onFingerSwipeLeft {
    if (appDelegate.splitStoryController.isShowingMaster && appDelegate.inStoryDetail){
        [appDelegate.splitStoryController toggleMasterView:nil];
        [appDelegate adjustStoryDetailWebView:YES shouldCheckLayout:YES];
        [self configureView];  
        [appDelegate animateHidingMasterView];
    }
}

- (void)onFingerSwipeRight {
    if (!appDelegate.splitStoryController.isShowingMaster && appDelegate.inStoryDetail){
        [appDelegate.splitStoryController toggleMasterView:nil];
        [appDelegate adjustStoryDetailWebView:YES shouldCheckLayout:YES];
        [self configureView]; 
        [appDelegate animateShowingMasterView];
    }
}

- (void)configureView
{
//    // Update the user interface for the detail item.
//    detailDescriptionLabel.text = [detailItem description];
//	toggleItem.title = ([splitController isShowingMaster]) ? @"Hide Sites" : @"Show Sites"; // "I... AM... THE MASTER!" Derek Jacobi. Gave me chills.
//	verticalItem.title = (splitController.vertical) ? @"Horizontal Split" : @"Vertical Split";
//	dividerStyleItem.title = (splitController.dividerStyle == MGSplitViewDividerStyleThin) ? @"Enable Dragging" : @"Disable Dragging";
//	masterBeforeDetailItem.title = (splitController.masterBeforeDetail) ? @"Detail First" : @"Master First";
}

@end