//
//  FirstTimeUserViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FirstTimeUserViewController.h"
#import "NewsBlurAppDelegate.h"
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
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Get Started" style:UIBarButtonItemStylePlain target:self action:@selector(tapNextButton)];
    self.nextButton = next;
    self.navigationItem.rightBarButtonItem = next;
        
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        header.font = [UIFont systemFontOfSize:22];
        footer.font = [UIFont systemFontOfSize:22];
    }
    
    UITapGestureRecognizer *singleFingerTap = 
    [[UITapGestureRecognizer alloc] initWithTarget:self 
                                            action:@selector(tapNextButton)];
    [self.view addGestureRecognizer:singleFingerTap];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationItem.rightBarButtonItem setStyle:UIBarButtonItemStyleDone];
    
    UIImage *logoImg = [UIImage imageNamed:@"logo_512"];
    UIImageView *logoView = [[UIImageView alloc] initWithImage:logoImg];
    CGFloat width = CGRectGetWidth(self.view.frame);
    CGFloat height = CGRectGetHeight(self.view.frame);
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        logoView.frame = CGRectMake((width-220)/2, (height-220)/2-50, 220, 220);
    } else {
        logoView.frame = CGRectMake((width-240)/2, (height-240)/2-50, 240, 240);
    }
    
    self.logo = logoView;
    [self.view addSubview:self.logo];
    [self rotateLogo];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    self.logo = nil;
}

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//    // Return YES for supported orientations
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        return YES;
//    } else if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
//        return YES;
//    }
//
//    return NO;
//}


- (IBAction)tapNextButton {
    [appDelegate.ftuxNavigationController showViewController:appDelegate.firstTimeUserAddSitesViewController sender:self];
}

- (void)rotateLogo {
    angle_ = 0;
    timerInterval_ = 0.01;
    
    [UIView animateWithDuration:1 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.timer_ = [NSTimer scheduledTimerWithTimeInterval: self.timerInterval_ target: self selector:@selector(handleTimer:) userInfo: nil repeats: YES];
    } completion:nil];
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
