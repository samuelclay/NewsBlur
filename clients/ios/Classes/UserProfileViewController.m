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
#import "FollowGrid.h"
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
@synthesize request;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc {
    self.profileTable.dataSource = nil;
    self.profileTable.delegate = nil;
    request.delegate = nil;
    [request cancel];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate]; 

    UITableView *profiles = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) style:UITableViewStyleGrouped];
    self.profileTable = profiles;
    self.profileTable.dataSource = self;
    self.profileTable.delegate = self;
    self.profileTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
//    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    ProfileBadge *badge = [[ProfileBadge alloc] init];
    self.profileBadge = badge;
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    self.appDelegate = nil;
    self.profileBadge = nil;
    self.profileTable = nil;
    self.activitiesArray = nil;
    self.activitiesUsername = nil;
    self.userProfile = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    CGRect vb = self.view.bounds;
    self.preferredContentSize = self.view.frame.size;
    self.view.frame = vb;
    self.profileTable.frame = vb;
    self.profileBadge.frame = CGRectMake(0, 0, vb.size.width, 140);
    
    self.view.backgroundColor = UIColorFromRGB(0xd7dadf);
    self.profileTable.backgroundColor = UIColorFromRGB(0xd7dadf);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self.profileTable reloadData];
}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)doCancelButton {
    [appDelegate.modalNavigationController dismissViewControllerAnimated:NO completion:nil];
}

- (void)getUserProfile {
//    self.view.frame = self.view.bounds;
    self.preferredContentSize = CGSizeMake(320, 454);

    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];  
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Profiling...";
    [self.profileBadge initProfile];
    NSString *urlString = [NSString stringWithFormat:@
                           "%@/social/profile?user_id=%@"
                           "&category=follow&category=comment_reply&category=comment_like&category=sharedstory",
                           self.appDelegate.url,
                           appDelegate.activeUserProfileId];
    NSURL *url = [NSURL URLWithString:urlString];

    request = [ASIHTTPRequest requestWithURL:url];

    [request setDelegate:self];
    [request setDidFinishSelector:@selector(requestFinished:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)requestFinished:(ASIHTTPRequest *)_request {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSString *responseString = [_request responseString];
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
    
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [self.appDelegate.dictSocialProfile objectForKey:@"user_id"]];   
    NSString *profileUserId = [NSString stringWithFormat:@"%@", [self.userProfile objectForKey:@"user_id"]];   
    
    // check follow button status    
    if ([currentUserId isEqualToString:profileUserId]) {
        NSMutableDictionary *newUserProfile = [self.userProfile mutableCopy];
        [newUserProfile setValue:[NSNumber numberWithInt:1] forKey:@"yourself"];
        self.userProfile = newUserProfile;
    }
        
    self.activitiesArray = [results objectForKey:@"activities"];

    [self.profileTable reloadData];
    [self.view addSubview:self.profileTable];
}

- (void)requestFailed:(ASIHTTPRequest *)_request {
    NSError *error = [_request error];
    NSLog(@"Error: %@", error);
    [appDelegate informError:error];
}

#pragma mark -
#pragma mark Table View - Profile Modules List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1 && self.activitiesArray.count) {
        return @"Latest Activity";
    } else if (section == 2 && self.activitiesArray.count) {
        return @"Followers";
    } else {
        return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {    
    if (section == 0) {
        return 1;
    } else if (section == 2) {
        return 1;
    } else {
        return [self.activitiesArray count];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGRect vb = self.view.bounds;
    // you can only hardcode this due to limitation in apple API that doesn't give you width of grouped cell
    int width = 300 - 20;
    if (vb.size.width == 480) {
        width = 460 - 20;
    } else if (vb.size.width == 540) {
        width = 478 - 20;
    }

    if (indexPath.section == 0 || indexPath.section == 2) {
        return 180;
    } else {
        SmallActivityCell *activityCell = [[SmallActivityCell alloc] init];
        int height = [activityCell setActivity:[self.activitiesArray objectAtIndex:(indexPath.row)] 
                               withUserProfile:self.userProfile
                                     withWidth:width];
        return height;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGRect vb = self.view.bounds;

    if (indexPath.section == 0) {
        ProfileBadge *cell = [tableView 
                                 dequeueReusableCellWithIdentifier:@"ProfileBadgeCellIdentifier"];
        
        if (cell == nil) {
            cell = [[ProfileBadge alloc] 
                    initWithStyle:UITableViewCellStyleDefault 
                    reuseIdentifier:nil];
        } 
        
        [cell refreshWithProfile:self.userProfile showStats:YES withWidth:vb.size.width];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    } else if(indexPath.section == 1) {
        SmallActivityCell *cell = [tableView 
                                   dequeueReusableCellWithIdentifier:@"ActivityCellIdentifier"];
        if (cell == nil) {
            cell = [[SmallActivityCell alloc] 
                    initWithStyle:UITableViewCellStyleDefault 
                    reuseIdentifier:@"ActivityCellIdentifier"];
        }
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.accessoryType=  UITableViewCellAccessoryDisclosureIndicator;
        [cell setActivity:[self.activitiesArray objectAtIndex:(indexPath.row)] 
          withUserProfile:self.userProfile
                withWidth:vb.size.width];
        
            return cell;
    } else {
        FollowGrid *cell = [tableView
                            dequeueReusableCellWithIdentifier:@"FollowGridCellIdentifier"];
        if (cell == nil) {
            cell = [[FollowGrid alloc] 
                    initWithStyle:UITableViewCellStyleDefault 
                    reuseIdentifier:@"FollowGridCellIdentifier"];
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        [cell refreshWithWidth:vb.size.width];
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger activitiesCount = [self.activitiesArray count];
    
    // badge is not tappable
    if (indexPath.section == 0 || indexPath.section == 2) {
        return;
    }
    
    if (indexPath.row < activitiesCount) {
        NSDictionary *activity = [self.activitiesArray objectAtIndex:indexPath.row];
        NSString *category = [activity objectForKey:@"category"];
        if ([category isEqualToString:@"follow"]) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            
            NSString *userId = [NSString stringWithFormat:@"%@",
                                [[activity objectForKey:@"with_user"] objectForKey:@"user_id"]];
            appDelegate.activeUserProfileId = userId;
            
            NSString *username = [NSString stringWithFormat:@"%@",
                                  [[activity objectForKey:@"with_user"] objectForKey:@"username"]];
            appDelegate.activeUserProfileName = username;

            [appDelegate pushUserProfile];
        } else if ([category isEqualToString:@"comment_reply"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                                   [[activity objectForKey:@"with_user"] objectForKey:@"id"]];
            NSString *contentIdStr = [NSString stringWithFormat:@"%@",
                                      [activity objectForKey:@"content_id"]];
            [appDelegate loadTryFeedDetailView:feedIdStr
                                     withStory:contentIdStr
                                      isSocial:YES
                                      withUser:[activity objectForKey:@"with_user"]
                              showFindingStory:YES];
            appDelegate.tryFeedCategory = category;
        } else if ([category isEqualToString:@"comment_like"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                                   [[activity objectForKey:@"with_user"] objectForKey:@"id"]];
            NSString *contentIdStr = [NSString stringWithFormat:@"%@",
                                      [activity objectForKey:@"content_id"]];
            [appDelegate loadTryFeedDetailView:feedIdStr
                                     withStory:contentIdStr
                                      isSocial:YES
                                      withUser:self.userProfile
                              showFindingStory:YES];
            appDelegate.tryFeedCategory = category;
        } else if ([category isEqualToString:@"sharedstory"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                                   [self.userProfile objectForKey:@"id"]];
            NSString *contentIdStr = [NSString stringWithFormat:@"%@",
                                      [activity objectForKey:@"content_id"]];
            [appDelegate loadTryFeedDetailView:feedIdStr
                                     withStory:contentIdStr
                                      isSocial:YES
                                      withUser:self.userProfile
                              showFindingStory:YES];
            appDelegate.tryFeedCategory = category;
        } else if ([category isEqualToString:@"feedsub"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                                   [activity objectForKey:@"feed_id"]];
            NSString *contentIdStr = nil;
            [appDelegate loadTryFeedDetailView:feedIdStr
                                     withStory:contentIdStr
                                      isSocial:NO
                                      withUser:self.userProfile
                              showFindingStory:NO];
        }
        
        // have the selected cell deselect
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

@end