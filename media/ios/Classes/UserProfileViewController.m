//
//  UserProfileViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/1/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "UserProfileViewController.h"
#import "NewsBlurAppDelegate.h"
#import "ProfileBadge.h"
#import "ActivityModule.h"
#import "ActivityCell.h"
#import "ASIHTTPRequest.h"
#import "JSON.h"
#import "Utilities.h"
#import "MBProgressHUD.h"
#import <QuartzCore/QuartzCore.h>

@implementation UserProfileViewController

@synthesize appDelegate;
@synthesize profileBadge;
@synthesize profileTable;
@synthesize activitiesArray;
@synthesize activitiesUsername;

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
    [self setProfileBadge:nil];
    [self setProfileTable:nil];
    [self setActivitiesArray:nil];
    [self setActivitiesUsername:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    self.view.frame = CGRectMake(0, 0, 320, 400);
    self.view.backgroundColor = UIColorFromRGB(0xd7dadf);
    
    self.profileTable = [[[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) style:UITableViewStyleGrouped] autorelease];
    self.profileTable.dataSource = self;
    self.profileTable.delegate = self;
    self.profileTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    ProfileBadge *badge = [[ProfileBadge alloc] init];
    badge.frame = CGRectMake(0, 0, self.view.frame.size.width, 140);
    self.profileBadge = badge;
    
    [badge release];
    [self getUserProfile];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.profileTable removeFromSuperview];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)dealloc {
    [appDelegate release];
    [profileBadge release];
    [activitiesArray release];
    [activitiesUsername release];
    [profileBadge release];
    [super dealloc];
}

- (void)doCancelButton {
    [appDelegate.findFriendsNavigationController dismissModalViewControllerAnimated:NO];
}

- (void)getUserProfile {
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];  
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
    
    self.activitiesArray = [results objectForKey:@"activities"];
    self.activitiesUsername = [results objectForKey:@"username"];
    
    if (!self.activitiesUsername) {
        self.activitiesUsername = [[results objectForKey:@"user_profile"] objectForKey:@"username"];
    }
    
    [self.profileTable reloadData];
    [self.view addSubview:self.profileTable];
    [results release];
}


- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

#pragma mark -
#pragma mark Table View - Profile Modules List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        return @"Latest Activity";
    } else {
        return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {    
    if (section == 0) {
        return 1;
    } else {
        return [self.activitiesArray count] * 50;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 180;
    } else {
        ActivityCell *activityCell = [[[ActivityCell alloc] init] autorelease];
        int height = [activityCell refreshActivity:[self.activitiesArray objectAtIndex:(indexPath.row % 5)] withUsername:self.activitiesUsername] + 20;
        return height;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier;
        
    if (indexPath.section == 0) {
        CellIdentifier = @"ProfileBadgeCellIdentifier";
    } else {
        CellIdentifier = @"ActivityCellIdentifier";
    }
    
    UITableViewCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] 
                 initWithStyle:UITableViewCellStyleDefault 
                 reuseIdentifier:CellIdentifier] autorelease];
    } else {
        [[[cell contentView] subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
    }
    
    // Profile Badge
    if (indexPath.section == 0) {
        [cell addSubview:self.profileBadge];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    // User Activities
    } else {
        int activitesCount = [self.activitiesArray count];
        if (activitesCount * 50 >= (indexPath.row + 1)) {
            ActivityCell *activityCell = [[ActivityCell alloc] init];
            activityCell.tag = 1;
            [activityCell refreshActivity:[self.activitiesArray objectAtIndex:(indexPath.row % 5)] withUsername:self.activitiesUsername];
            [cell.contentView addSubview:activityCell];
            [activityCell release];
        }
    }

    return cell;
}

@end
