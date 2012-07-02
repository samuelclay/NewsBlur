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
#import "Utilities.h"

@implementation UserProfileViewController

@synthesize appDelegate;
@synthesize userAvatar;
@synthesize username;
@synthesize userLocation;
@synthesize userDescription;
@synthesize userStats;
@synthesize followButton;
@synthesize followingCount;
@synthesize followersCount;

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
    [self setUserAvatar:nil];
    [self setUsername:nil];
    [self setUserLocation:nil];
    [self setUserDescription:nil];
    [self setUserStats:nil];
    [self setFollowButton:nil];
    [self setFollowingCount:nil];
    [self setFollowersCount:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)dealloc {
    [appDelegate release];
    [userAvatar release];
    [username release];
    [userLocation release];
    [userDescription release];
    [userStats release];
    [followButton release];
    [followingCount release];
    [followersCount release];
    [super dealloc];
}

- (IBAction)doFollowButton:(id)sender {
    if ([self.followButton.currentTitle isEqualToString:@"Following"]) {
        [self.followButton setTitle:@"Follow" forState:UIControlStateNormal];
    } else {
        [self.followButton setTitle:@"Following" forState:UIControlStateNormal];
    }
}

- (void)getUserProfile {
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/settings/%@",
                           NEWSBLUR_URL,
                           appDelegate.activeUserProfile];
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
        
    self.username.text = [results objectForKey:@"username"]; 
    
    if ([results objectForKey:@"location"] != [NSNull null]) {
        self.userLocation.text = [results objectForKey:@"location"];
    } else {
        self.userLocation.text = @"No location given...";
    }
    
    if ([results objectForKey:@"bio"] != [NSNull null]) {
        self.userDescription.text = [results objectForKey:@"bio"];
    } else {
        self.userDescription.text = @"No bio given...";
    }
    
    self.userStats.text = [NSString stringWithFormat:@"%i shared stories · %i followers", 
                           [[results objectForKey:@"shared_stories_count"] intValue],
                           [[results objectForKey:@"follower_count"] intValue]];
    self.followingCount.text = [NSString stringWithFormat:@"%i", 
                                [[results objectForKey:@"following_count"] intValue]];
    self.followersCount.text = [NSString stringWithFormat:@"%i",
                                [[results objectForKey:@"follower_count"] intValue]];
    
    NSURL *imageURL = [Utilities convertToAbsoluteURL:[results objectForKey:@"photo_url"]];
    NSLog(@"imageUrl is %@", imageURL);
    
    NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
    UIImage *image = [UIImage imageWithData:imageData];
    
    self.userAvatar.image = image;
    
    
    // check following to toggle follow button
    BOOL isFollowing = NO;
    NSArray *followingUserIds = [appDelegate.dictUserProfile objectForKey:@"following_user_ids"];
    for (int i = 0; i < followingUserIds.count ; i++) {
        NSString *followingUserId = [NSString stringWithFormat:@"%@", [followingUserIds objectAtIndex:i]];
        if ([followingUserId isEqualToString:[NSString stringWithFormat:@"%@", appDelegate.activeUserProfile]]) {
            isFollowing = YES;
        }
    }    
    if (isFollowing) {
        [self.followButton setTitle:@"Following" forState:UIControlStateNormal];
    }
    
    [results release];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

@end
