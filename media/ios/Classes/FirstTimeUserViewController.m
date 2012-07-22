//
//  FirstTimeUserViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FirstTimeUserViewController.h"
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"
#import "FirstTimeUserAddSitesViewController.h"

#define WELCOME_BUTTON_TITLE @"LET'S GET STARTED"
#define ADD_SITES_SKIP_BUTTON_TITLE @"SKIP THIS STEP"
#define ADD_SITES_BUTTON_TITLE @"NEXT"
#define ADD_FRIENDS_BUTTON_TITLE @"SKIP THIS STEP"
#define ADD_NEWSBLUR_BUTTON_TITLE @"FINISH"

@implementation FirstTimeUserViewController

@synthesize appDelegate;
@synthesize nextButton;
@synthesize logo;

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
    // Do any additional setup after loading the view from its nib.


    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Let's get started" style:UIBarButtonSystemItemDone target:self action:@selector(tapNextButton)];
    self.nextButton = next;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"Step 1 of 4";

}

- (void)viewDidUnload
{
    [self setNextButton:nil];
    [self setLogo:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [self rotateLogo];
}

- (void)viewDidAppear:(BOOL)animated {

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}


- (IBAction)tapNextButton {
    [appDelegate.ftuxNavigationController pushViewController:appDelegate.firstTimeUserAddSitesViewController animated:YES];
}

- (void)rotateLogo {
    // Setup the animation
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:(NSTimeInterval)60.0];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear];
    [UIView setAnimationBeginsFromCurrentState:YES];
    
    NSLog(@"%f", M_PI);
    
    // The transform matrix
    CGAffineTransform transform = CGAffineTransformMakeRotation(3.14);
    self.logo.transform = transform;
    
    // Commit the changes
    [UIView commitAnimations];
}

@end
