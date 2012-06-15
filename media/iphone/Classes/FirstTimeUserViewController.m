//
//  FirstTimeUserViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FirstTimeUserViewController.h"
#import "NewsBlurAppDelegate.h"

#define WELCOME_BUTTON_TITLE @"LET'S GET STARTED"
#define ADD_SITES_BUTTON_TITLE @"SKIP THIS STEP"
#define ADD_FRIENDS_BUTTON_TITLE @"SKIP THIS STEP"
#define ADD_NEWSBLUR_BUTTON_TITLE @"FINISH"

@implementation FirstTimeUserViewController

@synthesize appDelegate;
@synthesize googleReaderButton;
@synthesize welcomeView;
@synthesize addSitesView;
@synthesize addFriendsView;
@synthesize addNewsBlurView;

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
    currentStep = 0;
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [self setGoogleReaderButton:nil];
    [self setWelcomeView:nil];
    [self setAddSitesView:nil];
    [self setAddFriendsView:nil];
    [self setAddNewsBlurView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}



- (void)dealloc {
    [googleReaderButton release];
    [welcomeView release];
    [addSitesView release];
    [addFriendsView release];
    [addNewsBlurView release];
    [super dealloc];
}

- (IBAction)tapNextButton:(id)sender {
    currentStep++;
    UIBarButtonItem *nextButton = (UIBarButtonItem *)sender;
    if (currentStep == 1) {
        nextButton.title = ADD_SITES_BUTTON_TITLE;
        self.addSitesView.frame = CGRectMake(768, 44, 768, 960);
        [self.view addSubview:addSitesView];
        [UIView animateWithDuration:0.35 
                         animations:^{
                            self.welcomeView.frame = CGRectMake(-768, 44, 768, 960);   
                            self.addSitesView.frame = CGRectMake(0, 44, 768, 960); 
                         }];
        
    } else if (currentStep == 2) {
        nextButton.title = ADD_FRIENDS_BUTTON_TITLE;
        self.addFriendsView.frame = CGRectMake(768, 44, 768, 960);
        [self.view addSubview:addFriendsView];
        [UIView animateWithDuration:0.35 
                         animations:^{
                             self.addSitesView.frame = CGRectMake(-768, 44, 768, 960);   
                             self.addFriendsView.frame = CGRectMake(0, 44, 768, 960); 
                         }];
    } else if (currentStep == 3) {
        nextButton.title = ADD_NEWSBLUR_BUTTON_TITLE;
        self.addNewsBlurView.frame = CGRectMake(768, 44, 768, 960);
        [self.view addSubview:addNewsBlurView];
        [UIView animateWithDuration:0.35 
                         animations:^{
                             self.addFriendsView.frame = CGRectMake(-768, 44, 768, 960);   
                             self.addNewsBlurView.frame = CGRectMake(0, 44, 768, 960); 
                         }];
    } else if (currentStep == 4) {
        NSLog(@"Calling appDeletage reload feeds");
        [self dismissModalViewControllerAnimated:YES];
        [appDelegate reloadFeedsView:YES];
    }
}
@end
