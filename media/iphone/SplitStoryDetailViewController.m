//
//  DetailViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/9/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "SplitStoryDetailViewController.h"
#import "NewsBlurAppDelegate.h"

@implementation SplitStoryDetailViewController

@synthesize masterPopoverController = _masterPopoverController;
@synthesize appDelegate;

- (void)dealloc 
{
    [_masterPopoverController release];
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
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidAppear:(BOOL)animated 
{
    // messes up on FTUX, must put in a state test
//    if (self.masterPopoverController) {
//        [self.masterPopoverController presentPopoverFromRect:CGRectMake(0, 0, 1, 1) 
//                                                      inView:self.view 
//                                    permittedArrowDirections:UIPopoverArrowDirectionAny 
//                                                    animated:YES];
//    }
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation 
                                         duration:(NSTimeInterval)duration {
    [appDelegate adjustStoryDetailWebView:NO shouldCheckLayout:YES]; 
}

- (void)showPopover {
    if (self.masterPopoverController) {
        [self.masterPopoverController presentPopoverFromRect:CGRectMake(0, 0, 1, 1) 
                                                      inView:self.view
                                    permittedArrowDirections:UIPopoverArrowDirectionAny
                                                    animated:YES];
    }
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController 
     willHideViewController:(UIViewController *)viewController 
          withBarButtonItem:(UIBarButtonItem *)barButtonItem 
       forPopoverController:(UIPopoverController *)popoverController {
    barButtonItem.title = NSLocalizedString(@"All Sites", @"All Sites");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;   
}

- (void)splitViewController:(UISplitViewController *)splitController 
     willShowViewController:(UIViewController *)viewController 
  invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem {
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

@end