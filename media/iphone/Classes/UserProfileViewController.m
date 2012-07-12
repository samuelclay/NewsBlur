//
//  UserProfileViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/1/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "UserProfileViewController.h"
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"
#import "JSON.h"
#import "ProfileBadge.h"
#import "ActivityModule.h"
#import "Utilities.h"
#import "MBProgressHUD.h"

@implementation UserProfileViewController

@synthesize appDelegate;
@synthesize profileBadge;
@synthesize activityModule;

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
}

- (void)viewDidUnload
{
    [self setActivityModule:nil];
    [self setProfileBadge:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    ProfileBadge *badge = [[ProfileBadge alloc] init];
    badge.frame = CGRectMake(0, 0, 320, 140);
    self.profileBadge = badge;
    
    ActivityModule *activity = [[ActivityModule alloc] init];
    activity.frame = CGRectMake(0, badge.frame.size.height, 320, 300);
    self.activityModule = activity;
    
    self.view.frame = CGRectMake(0, 0, 320, 500);
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.profileBadge];
    [self.view addSubview:self.activityModule];
    
    [badge release];
    [activity release];
    [self getUserProfile];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.profileBadge removeFromSuperview];
    [self.activityModule removeFromSuperview];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)dealloc {
    [appDelegate release];
    [profileBadge release];
    [activityModule release];
    [super dealloc];
}

- (void)doCancelButton {
    [appDelegate.findFriendsNavigationController dismissModalViewControllerAnimated:NO];
}

- (void)getUserProfile {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Profiling...";
    
    [self.profileBadge initProfile];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/profile?user_id=%@",
                           NEWSBLUR_URL,
                           appDelegate.activeUserProfileId];
    NSURL *url = [NSURL URLWithString:urlString];

    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(requestFinished:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)requestFinished:(ASIHTTPRequest *)request {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSLog(@"ERROR");
        [results release];
        return;
    } 

    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    [self.profileBadge refreshWithProfile:[results objectForKey:@"user_profile"]];
    [self.activityModule refreshWithActivities:results];

    [results release];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

@end
