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
#import <QuartzCore/QuartzCore.h>

@implementation UserProfileViewController

@synthesize appDelegate;
@synthesize profileBadge;
@synthesize activityModule;
@synthesize profileTable;

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
    [self setProfileTable:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    
    self.profileTable = [[[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 460) style:UITableViewStyleGrouped] autorelease];
    self.profileTable.dataSource = self;
    self.profileTable.delegate = self;
    self.profileTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    ProfileBadge *badge = [[ProfileBadge alloc] init];
    badge.frame = CGRectMake(0, 0, 320, 140);
    self.profileBadge = badge;
    
    ActivityModule *activity = [[ActivityModule alloc] init];
    activity.frame = CGRectMake(0, badge.frame.size.height, 320, 300);
    self.activityModule = activity;
    
    self.view.frame = CGRectMake(0, 0, 320, 500);
    self.view.backgroundColor = [UIColor whiteColor];
//    [self.view addSubview:self.profileBadge];
//    [self.view addSubview:self.activityModule];
    [self.view addSubview:self.profileTable];
    
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
    [self.activityModule refreshWithActivities:results];
    [self.profileTable reloadData];
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
        return 5;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 180;
    } else {
        return 44;
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
    }
    
    NSLog(@"indexPath.section is %i", indexPath.section);
    if (indexPath.section == 0) {
        [cell addSubview:self.profileBadge];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.textLabel.text = @"test";
    }
//    int activitesCount = [self.activitiesArray count];
//    if (activitesCount) {
//        
//        NSDictionary *activity = [self.activitiesArray objectAtIndex:indexPath.row];
//        NSString *category = [activity objectForKey:@"category"];
//        NSString *content = [activity objectForKey:@"content"];
//        NSString *title = [activity objectForKey:@"title"];
//        
//        if ([category isEqualToString:@"follow"]) {
//            
//            NSString *withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
//            cell.textLabel.text = [NSString stringWithFormat:@"%@ followed %@", self.activitiesUsername, withUserUsername];
//            
//        } else if ([category isEqualToString:@"comment_reply"]) {
//            NSString *withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
//            cell.textLabel.text = [NSString stringWithFormat:@"%@ replied to %@", self.activitiesUsername, withUserUsername];
//            
//        } else if ([category isEqualToString:@"sharedstory"]) {
//            cell.textLabel.text = [NSString stringWithFormat:@"%@ shared %@ : %@", self.activitiesUsername, title, content];
//            
//            // star and feedsub are always private.
//        } else if ([category isEqualToString:@"star"]) {
//            cell.textLabel.text = [NSString stringWithFormat:@"You saved %@", content];
//            
//        } else if ([category isEqualToString:@"feedsub"]) {
//            
//            cell.textLabel.text = [NSString stringWithFormat:@"You subscribed to %@", content];
//        }
//        
//        cell.textLabel.font = [UIFont systemFontOfSize:13];
//    }
    
    return cell;
}


@end
