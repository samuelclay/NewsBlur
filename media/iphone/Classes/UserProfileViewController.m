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
#import "SocialBadge.h"
#import "Utilities.h"
#import "MBProgressHUD.h"

@implementation UserProfileViewController

@synthesize appDelegate;
@synthesize followingCount;
@synthesize followersCount;
@synthesize socialBadge;

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
    self.socialBadge.frame = CGRectMake(0, 0, 320, 140);
}

- (void)viewDidUnload
{
    [self setFollowingCount:nil];
    [self setFollowersCount:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [self getUserProfile];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)dealloc {
    [appDelegate release];
    [followingCount release];
    [followersCount release];
    [super dealloc];
}

- (void)doCancelButton {
    [appDelegate.findFriendsNavigationController dismissModalViewControllerAnimated:NO];
}

- (void)getUserProfile {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Finding...";
    
    [self.socialBadge initProfile];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/settings/%@",
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
    
    NSLog(@"results %@", results);
    NSLog(@"appDelegate.activeUserProfileId %@", appDelegate.activeUserProfileId);
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [self.socialBadge refreshWithDict:results];
    
    [results release];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

@end
