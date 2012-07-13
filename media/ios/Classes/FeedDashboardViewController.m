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
@synthesize toolbar;

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
    [self setToolbar:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

#pragma mark -
#pragma mark Interactions

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *theTouch = [touches anyObject];
    
    if ([theTouch view] == toolbar) {
        CGPoint touchLocation = [theTouch locationInView:self.view];
        CGFloat y = touchLocation.y;
        [appDelegate dragFeedDetailView:y];        
    }
}

- (void)dealloc {
    [toolbar release];
    [super dealloc];
}
@end
