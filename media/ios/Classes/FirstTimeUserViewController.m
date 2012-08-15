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
#import <QuartzCore/QuartzCore.h>

#define WELCOME_BUTTON_TITLE @"LET'S GET STARTED"
#define ADD_SITES_SKIP_BUTTON_TITLE @"SKIP THIS STEP"
#define ADD_SITES_BUTTON_TITLE @"NEXT"
#define ADD_FRIENDS_BUTTON_TITLE @"SKIP THIS STEP"
#define ADD_NEWSBLUR_BUTTON_TITLE @"FINISH"

@interface FirstTimeUserViewController ()

@property (readwrite) float angle_;
@property (readwrite) float timerInterval_;
@property (nonatomic) NSTimer *timer_;
@end

@implementation FirstTimeUserViewController

@synthesize appDelegate;
@synthesize nextButton;
@synthesize logo;
@synthesize header;
@synthesize footer;
@synthesize angle_;
@synthesize timerInterval_;
@synthesize timer_;

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

//
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Get Started" style:UIBarButtonSystemItemDone target:self action:@selector(tapNextButton)];
    self.nextButton = next;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"Welcome";
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        logo.frame = CGRectMake(80, 90, 160, 160);
        header.font = [UIFont systemFontOfSize:22];
        footer.font = [UIFont systemFontOfSize:16];
    }
    
    UITapGestureRecognizer *singleFingerTap = 
    [[UITapGestureRecognizer alloc] initWithTarget:self 
                                            action:@selector(tapNextButton)];
    [self.view addGestureRecognizer:singleFingerTap];

}

- (void)viewDidUnload
{
    [self setNextButton:nil];
    [self setLogo:nil];
    [self setHeader:nil];
    [self setFooter:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [self.navigationItem.rightBarButtonItem setStyle:UIBarButtonItemStyleDone];
    
    UIImage *logoImg = [UIImage imageNamed:@"logo_512"];
    UIImageView *logoView = [[UIImageView alloc] initWithImage:logoImg];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        logoView.frame = CGRectMake(80, 90, 160, 160);
    } else {
        logoView.frame = CGRectMake(150, 99, 240, 240);
    }
    
    self.logo = logoView;
    [self.view addSubview:self.logo];
    [self rotateLogo];
}

- (void)viewDidAppear:(BOOL)animated {
    
}

- (void)viewDidDisappear:(BOOL)animated {
    self.logo = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
        return YES;
    }
    
    return NO;
}


- (IBAction)tapNextButton {
    [appDelegate.ftuxNavigationController pushViewController:appDelegate.firstTimeUserAddSitesViewController animated:YES];
}

- (void)rotateLogo {
    angle_ = 0;
    timerInterval_ = 0.01;
    
    [UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDuration:1];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
	
	timer_ = [NSTimer scheduledTimerWithTimeInterval: timerInterval_ target: self selector:@selector(handleTimer:) userInfo: nil repeats: YES];
	[UIView commitAnimations];
}

-(void)handleTimer:(NSTimer *)timer
{
    timerInterval_ += .01;
	angle_ += 0.001;
	if (angle_ > 6.283) { 
		angle_ = 0;
	}
	
	CGAffineTransform transform = CGAffineTransformMakeRotation(angle_);
	self.logo.transform = transform;
}

@end
