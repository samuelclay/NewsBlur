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

@implementation ActivityModule

@synthesize appDelegate;
@synthesize activitiesTable;
@synthesize activitiesArray;
@synthesize activitiesUsername;
@synthesize popoverController;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
    }
    return self;
}


- (void)layoutSubviews {
    [super layoutSubviews];
}


- (void)refreshWithActivities:(NSDictionary *)activitiesDict {
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];   
    self.activitiesArray = [activitiesDict objectForKey:@"activities"];
    self.activitiesUsername = [activitiesDict objectForKey:@"username"];
    
    if (!self.activitiesUsername) {
        self.activitiesUsername = [[activitiesDict objectForKey:@"user_profile"] objectForKey:@"username"];
    }
    
    self.activitiesTable = [[UITableView alloc] init];
    self.activitiesTable.dataSource = self;
    self.activitiesTable.delegate = self;
    self.activitiesTable.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    self.activitiesTable.layer.cornerRadius = 10;
    self.activitiesTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self addSubview:self.activitiesTable];    
    [self.activitiesTable reloadData];
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
    if (activitesCount) {
        return activitesCount;
    } else {
        return 0;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    ActivityCell *activityCell = [[ActivityCell alloc] init];
    int height = [activityCell refreshActivity:[self.activitiesArray objectAtIndex:(indexPath.row)] 
                                  withUsername:self.activitiesUsername 
                                     withWidth:self.frame.size.width] + 20;
    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] 
                 initWithStyle:UITableViewCellStyleDefault 
                 reuseIdentifier:CellIdentifier];
    } else {
        [[[cell contentView] subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
    }
    
    int activitesCount = [self.activitiesArray count];
    if (activitesCount >= (indexPath.row + 1)) {
        ActivityCell *activityCell = [[ActivityCell alloc] init];
        [activityCell refreshActivity:[self.activitiesArray objectAtIndex:(indexPath.row)] 
                         withUsername:self.activitiesUsername
                            withWidth:self.frame.size.width];
        [cell.contentView addSubview:activityCell];
    }    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    int activitiesCount = [self.activitiesArray count];
    if (indexPath.row < activitiesCount) {
        NSDictionary *activity = [self.activitiesArray objectAtIndex:indexPath.row];
        NSString *category = [activity objectForKey:@"category"];
        if ([category isEqualToString:@"follow"]) {
            NSString *userId = [[activity objectForKey:@"with_user"] objectForKey:@"user_id"];
            appDelegate.activeUserProfileId = userId;
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            self.popoverController = [[UIPopoverController alloc] initWithContentViewController:appDelegate.userProfileViewController];
            [self.popoverController setPopoverContentSize:CGSizeMake(320, 416)];
            [self.popoverController presentPopoverFromRect:cell.bounds 
                                                    inView:cell 
                                  permittedArrowDirections:UIPopoverArrowDirectionAny 
                                                  animated:YES];
        } else if ([category isEqualToString:@"comment_reply"] ||
                   [category isEqualToString:@"comment_like"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", [[activity objectForKey:@"with_user"] objectForKey:@"id"]];
            NSString *contentIdStr = [NSString stringWithFormat:@"%@", [activity objectForKey:@"content_id"]];
            [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr isSocial:YES];
        } else if ([category isEqualToString:@"sharedstory"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", [[activity objectForKey:@"with_user"] objectForKey:@"id"]];
            NSString *contentIdStr = [NSString stringWithFormat:@"%@", [activity objectForKey:@"content_id"]];
            [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr isSocial:YES];
        } else if ([category isEqualToString:@"feedsub"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", [activity objectForKey:@"feed_id"]];
            NSString *contentIdStr = nil;
            [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr isSocial:NO];
        }
        
        // have the selected cell deselect
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}





@end
