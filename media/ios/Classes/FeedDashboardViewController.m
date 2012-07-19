//
//  FeedDashboardViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/20/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FeedDashboardViewController.h"
#import "NewsBlurAppDelegate.h"


@implementation FeedDashboardViewController

@synthesize appDelegate;
@synthesize storyLabel;

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
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.navigationItem.hidesBackButton = YES;
    }        
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)viewWillAppear:(BOOL)animated {
    self.storyLabel.hidden = YES;
}

@end
