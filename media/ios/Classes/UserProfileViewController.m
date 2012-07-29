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
#import "SmallActivityCell.h"
#import "ASIHTTPRequest.h"
#import "Utilities.h"
#import "MBProgressHUD.h"
#import <QuartzCore/QuartzCore.h>

@implementation UserProfileViewController

@synthesize appDelegate;
@synthesize profileBadge;
@synthesize profileTable;
@synthesize activitiesArray;
@synthesize activitiesUsername;
@synthesize userProfile;


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
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate]; 
    
    self.view.frame = CGRectMake(0, 0, 320, 416);
    self.contentSizeForViewInPopover = self.view.frame.size;
    self.view.backgroundColor = UIColorFromRGB(0xd7dadf);
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    
    UITableView *profiles = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) style:UITableViewStyleGrouped];
    self.profileTable = profiles;
    self.profileTable.dataSource = self;
    self.profileTable.delegate = self;
    self.profileTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    ProfileBadge *badge = [[ProfileBadge alloc] init];
    badge.frame = CGRectMake(0, 0, self.view.frame.size.width, 140);
    self.profileBadge = badge;

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
    CGRect frame = CGRectZero;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        frame = self.parentViewController.view.frame;
    }
    
    // account for UIPopover Navigation height and readjust
    frame.size.height = frame.size.height - 37;
    self.view.frame = frame;
    self.profileTable.frame = frame;

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)doCancelButton {
    [appDelegate.findFriendsNavigationController dismissModalViewControllerAnimated:NO];
}

- (void)getUserProfile {
//    [self.profileTable removeFromSuperview];
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
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];

    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSLog(@"ERROR");
        return;
    } 

    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    self.userProfile = [results objectForKey:@"user_profile"];  
    
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [self.appDelegate.dictUserProfile objectForKey:@"user_id"]];   
    NSString *profileUserId = [NSString stringWithFormat:@"%@", [self.userProfile objectForKey:@"user_id"]];   
    
    // check follow button status    
    if ([currentUserId isEqualToString:profileUserId]) {
        NSMutableDictionary *newUserProfile = [self.userProfile mutableCopy];
        [newUserProfile setValue:@"You" forKey:@"username"];
        self.userProfile = newUserProfile;
    }
        
    self.activitiesArray = [results objectForKey:@"activities"];

    [self.profileBadge refreshWithProfile:self.userProfile];  
    
    [self.profileTable reloadData];
    [self.view addSubview:self.profileTable];
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
        return [self.activitiesArray count];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 180;
    } else {
        SmallActivityCell *activityCell = [[SmallActivityCell alloc] init];
        int height = [activityCell setActivity:[self.activitiesArray objectAtIndex:(indexPath.row)] 
                               withUserProfile:self.userProfile
                                     withWidth:self.view.frame.size.width - 20] + 20;
        return height;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier;
        
    if (indexPath.section == 0) {
        CellIdentifier = @"ProfileBadgeCellIdentifier";
        UITableViewCell *cell = [tableView 
                                 dequeueReusableCellWithIdentifier:CellIdentifier];
        
        if (cell == nil) {
            cell = [[UITableViewCell alloc] 
                    initWithStyle:UITableViewCellStyleDefault 
                    reuseIdentifier:CellIdentifier];
        } else {
            [[[cell contentView] subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
        }
        
        [cell addSubview:self.profileBadge];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    } else {
        CellIdentifier = @"ActivityCellIdentifier";
        
        SmallActivityCell *cell = [tableView 
                              dequeueReusableCellWithIdentifier:@"ActivityCell"];
        if (cell == nil) {
            cell = [[SmallActivityCell alloc] 
                    initWithStyle:UITableViewCellStyleDefault 
                    reuseIdentifier:@"ActivityCell"];
        } 
        
        [cell setActivity:[self.activitiesArray objectAtIndex:(indexPath.row)] 
          withUserProfile:self.userProfile
                withWidth:self.view.frame.size.width];
        
            return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    int activitiesCount = [self.activitiesArray count];
    
    // badge is not tappable
    if (indexPath.section == 0) {
        return;
    }
    
    if (indexPath.row < activitiesCount) {
        NSDictionary *activity = [self.activitiesArray objectAtIndex:indexPath.row];
        NSString *category = [activity objectForKey:@"category"];
        if ([category isEqualToString:@"follow"]) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];

            NSString *userId = [[activity objectForKey:@"with_user"] objectForKey:@"user_id"];
            appDelegate.activeUserProfileId = userId;
            NSString *username = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
            appDelegate.activeUserProfileName = username;

            [appDelegate pushUserProfile];
        } else {
            [appDelegate hideUserProfileModal];
            if ([category isEqualToString:@"comment_reply"] ||
                       [category isEqualToString:@"comment_like"]) {
                NSString *feedIdStr = [NSString stringWithFormat:@"%@", [[activity objectForKey:@"with_user"] objectForKey:@"id"]];
                NSString *contentIdStr = [NSString stringWithFormat:@"%@", [activity objectForKey:@"content_id"]];
                [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr isSocial:YES withUser:[activity objectForKey:@"with_user"]];
            } else if ([category isEqualToString:@"sharedstory"]) {
                NSString *feedIdStr = [NSString stringWithFormat:@"%@", [[activity objectForKey:@"with_user"] objectForKey:@"id"]];
                NSString *contentIdStr = [NSString stringWithFormat:@"%@", [activity objectForKey:@"content_id"]];
                [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr isSocial:YES withUser:[activity objectForKey:@"with_user"]];
            } else if ([category isEqualToString:@"feedsub"]) {
                NSString *feedIdStr = [NSString stringWithFormat:@"%@", [activity objectForKey:@"feed_id"]];
                NSString *contentIdStr = nil;
                [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr isSocial:NO withUser:[activity objectForKey:@"with_user"]];
            }
        }
        
        // have the selected cell deselect
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}


@end
