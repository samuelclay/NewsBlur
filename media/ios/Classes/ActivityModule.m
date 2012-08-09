//
//  ActivityModule.m
//  NewsBlur
//
//  Created by Roy Yang on 7/11/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "ActivityModule.h"
#import "ActivityCell.h"
#import "NewsBlurAppDelegate.h"
#import "UserProfileViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "ASIHTTPRequest.h"
#import "ActivityCell.h"

@implementation ActivityModule

@synthesize appDelegate;
@synthesize activitiesTable;
@synthesize activitiesArray;
@synthesize popoverController;
@synthesize pageFetching;
@synthesize pageFinished;
@synthesize activitiesPage;

#define MINIMUM_ACTIVITY_HEIGHT 48 + 30

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // initialize code here
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.activitiesTable = [[UITableView alloc] init];
    self.activitiesTable.dataSource = self;
    self.activitiesTable.delegate = self;
    self.activitiesTable.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);;
    self.activitiesTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self addSubview:self.activitiesTable];   
}
    
- (void)refreshWithActivities:(NSArray *)activities {
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];   
    self.activitiesArray = activities;

    [self.activitiesTable reloadData];
    
    self.pageFetching = NO;
    
    [self performSelector:@selector(checkScroll)
               withObject:nil
               afterDelay:0.1];
}

- (void)checkScroll {
    NSInteger currentOffset = self.activitiesTable.contentOffset.y;
    NSInteger maximumOffset = self.activitiesTable.contentSize.height - self.activitiesTable.frame.size.height;
    
    if (maximumOffset - currentOffset <= 60.0) {
        [self fetchActivitiesDetail:self.activitiesPage + 1];
    }
}

#pragma mark -
#pragma mark Get Interactions

- (void)fetchActivitiesDetail:(int)page {
    if (page == 1) {
        self.pageFetching = NO;
        self.pageFinished = NO;
        appDelegate.userActivitiesArray = nil;
    }
    if (!self.pageFetching && !self.pageFinished) {
        self.activitiesPage = page;
        self.pageFetching = YES;
        self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];  
        NSString *urlString = [NSString stringWithFormat:@"http://%@/social/activities?user_id=%@&page=%i&limit=10",
                               NEWSBLUR_URL,
                               [appDelegate.dictUserProfile objectForKey:@"user_id"],
                               page];
        
        NSURL *url = [NSURL URLWithString:urlString];
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
        
        [request setDidFinishSelector:@selector(finishLoadActivities:)];
        [request setDidFailSelector:@selector(requestFailed:)];
        [request setDelegate:self];
        [request startAsynchronous];
    }
}

- (void)finishLoadActivities:(ASIHTTPRequest *)request {
    self.pageFetching = NO;
    NSString *responseString = [request responseString];
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    // check for last page
    if (![[results objectForKey:@"has_next_page"] intValue]) {
        self.pageFinished = YES;
    }
    
    NSArray *newActivities = [results objectForKey:@"activities"];
    NSMutableArray *confirmedActivities = [NSMutableArray array];
    if ([appDelegate.userActivitiesArray count]) {
        NSMutableSet *activitiesDate = [NSMutableSet set];
        for (id activity in appDelegate.userActivitiesArray) {
            [activitiesDate addObject:[activity objectForKey:@"date"]];
        }
        for (id activity in newActivities) {
            if (![activitiesDate containsObject:[activity objectForKey:@"date"]]) {
                [confirmedActivities addObject:activity];
            }
        }
    } else {
        confirmedActivities = [newActivities copy];
    }
    
    if (self.activitiesPage == 1) {
        appDelegate.userActivitiesArray = confirmedActivities;
    } else {
        appDelegate.userActivitiesArray = [appDelegate.userActivitiesArray arrayByAddingObjectsFromArray:newActivities];
    }
    
    [self refreshWithActivities:appDelegate.userActivitiesArray];
} 

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

#pragma mark -
#pragma mark Table View - Interactions List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{    
    int activitesCount = [self.activitiesArray count];
    return activitesCount + 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {    
    int activitiesCount = [self.activitiesArray count];
    if (indexPath.row >= activitiesCount) {
        return MINIMUM_ACTIVITY_HEIGHT;
    }
    
    ActivityCell *activityCell = [[ActivityCell alloc] init];
    
    NSMutableDictionary *userProfile = [appDelegate.dictUserProfile  mutableCopy];
    [userProfile setValue:@"You" forKey:@"username"];
    
    int height = [activityCell setActivity:[self.activitiesArray 
                                            objectAtIndex:(indexPath.row)] 
                           withUserProfile:userProfile
                                 withWidth:self.frame.size.width - 20] + 30;
    
    return height;

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ActivityCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:@"ActivityCell"];
    if (cell == nil) {
        cell = [[ActivityCell alloc] 
                 initWithStyle:UITableViewCellStyleDefault 
                 reuseIdentifier:@"ActivityCell"];
    } 
    
    if (indexPath.row >= [appDelegate.userActivitiesArray count]) {
        // add in loading cell
        return [self makeLoadingCell];
    } else {

        NSMutableDictionary *userProfile = [appDelegate.dictUserProfile  mutableCopy];
        [userProfile setValue:@"You" forKey:@"username"];
        
        NSDictionary *activitiy = [self.activitiesArray 
                                   objectAtIndex:(indexPath.row)];
        NSString *category = [activitiy objectForKey:@"category"];
        if (![category isEqualToString:@"follow"]) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }

        // update the cell information
        [cell setActivity: activitiy
          withUserProfile:userProfile
                withWidth:self.frame.size.width - 20];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    int activitiesCount = [self.activitiesArray count];
    if (indexPath.row < activitiesCount) {
        NSDictionary *activity = [self.activitiesArray objectAtIndex:indexPath.row];
        NSString *category = [activity objectForKey:@"category"];
        if ([category isEqualToString:@"follow"]) {

            
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            
            NSString *userId = [NSString stringWithFormat:@"%@", [[activity objectForKey:@"with_user"] objectForKey:@"user_id"]];
            appDelegate.activeUserProfileId = userId;
            
            NSString *username = [NSString stringWithFormat:@"%@", [[activity objectForKey:@"with_user"] objectForKey:@"username"]];
            appDelegate.activeUserProfileName = username;
            
            // pass cell to the show UserProfile
            ActivityCell *cell = (ActivityCell *)[tableView cellForRowAtIndexPath:indexPath];
            [appDelegate showUserProfileModal:cell];
        } else if ([category isEqualToString:@"comment_reply"] ||
                   [category isEqualToString:@"comment_like"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", [[activity objectForKey:@"with_user"] objectForKey:@"id"]];
            NSString *contentIdStr = [NSString stringWithFormat:@"%@", [activity objectForKey:@"content_id"]];
            [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr isSocial:YES withUser:[activity objectForKey:@"with_user"]];
        } else if ([category isEqualToString:@"sharedstory"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"id"]];
            NSString *contentIdStr = [NSString stringWithFormat:@"%@", [activity objectForKey:@"content_id"]];
            [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr isSocial:YES withUser:[activity objectForKey:@"with_user"]];
        } else if ([category isEqualToString:@"feedsub"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", [activity objectForKey:@"feed_id"]];
            NSString *contentIdStr = nil;
            [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr isSocial:NO withUser:[activity objectForKey:@"with_user"]];
        }
        
        // have the selected cell deselect
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (UITableViewCell *)makeLoadingCell {
    UITableViewCell *cell = [[UITableViewCell alloc] 
                             initWithStyle:UITableViewCellStyleSubtitle 
                             reuseIdentifier:@"NoReuse"];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (self.pageFinished) {
        UIImage *img = [UIImage imageNamed:@"fleuron.png"];
        UIImageView *fleuron = [[UIImageView alloc] initWithImage:img];
        int height = MINIMUM_ACTIVITY_HEIGHT;
        
        fleuron.frame = CGRectMake(0, 0, self.frame.size.width, height);
        fleuron.contentMode = UIViewContentModeCenter;
        [cell.contentView addSubview:fleuron];
        fleuron.backgroundColor = [UIColor whiteColor];
    } else {
        cell.textLabel.text = @"Loading...";
        
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] 
                                            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        UIImage *spacer = [UIImage imageNamed:@"spacer"];
        UIGraphicsBeginImageContext(spinner.frame.size);        
        [spacer drawInRect:CGRectMake(0, 0, spinner.frame.size.width,spinner.frame.size.height)];
        UIImage* resizedSpacer = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        cell.imageView.image = resizedSpacer;
        [cell.imageView addSubview:spinner];
        [spinner startAnimating];
    }
    
    return cell;
}

- (void)scrollViewDidScroll: (UIScrollView *)scroll {
    [self checkScroll];
}

@end
