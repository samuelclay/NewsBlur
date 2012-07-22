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
#import <QuartzCore/QuartzCore.h>
#import "ASIHTTPRequest.h"
#import "JSON.h"

@implementation ActivityModule

@synthesize appDelegate;
@synthesize activitiesTable;
@synthesize activitiesArray;
@synthesize activitiesUsername;
@synthesize popoverController;
@synthesize pageFetching;
@synthesize pageFinished;
@synthesize activitiesPage;

#define MINIMUM_INTERACTION_HEIGHT 48 + 30

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
    
- (void)refreshWithActivities:(NSArray *)activities withUsername:(NSString *)username {
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];   
    self.activitiesArray = activities;
    self.activitiesUsername = username;

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
        [self fetchInteractionsDetail:self.activitiesPage + 1];
    }
}

#pragma mark -
#pragma mark Get Interactions

- (void)fetchInteractionsDetail:(int)page {
    if (page == 1) {
        self.pageFetching = NO;
        self.pageFinished = NO;
        appDelegate.dictUserActivities = nil;
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
        
        [request setDidFinishSelector:@selector(finishLoadInteractions:)];
        [request setDidFailSelector:@selector(requestFailed:)];
        [request setDelegate:self];
        [request startAsynchronous];
    }
}

- (void)finishLoadActivities:(ASIHTTPRequest *)request {
    self.pageFetching = NO;
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    
    NSArray *newActivities = [results objectForKey:@"interactions"];
    NSMutableArray *confirmedActivities = [NSMutableArray array];
    if ([appDelegate.dictUserActivities count]) {
        NSMutableSet *activitiesDate = [NSMutableSet set];
        for (id activity in appDelegate.dictUserActivities) {
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
    
//    if (self.activitiesPage == 1) {
//        appDelegate.dictUserActivities = confirmedActivities;
//    } else {
//        appDelegate.dictUserActivities = [appDelegate.dictUserActivities arrayByAddingObjectsFromArray:newActivities];
//    }
//    
//    if ([confirmedInteractions count] == 0 || self.activitiesTable > 100) {
//        self.pageFinished = YES;
//    }
//    [self refreshWithInteractions:appDelegate.dictUserInteractions withUsername:self.activitiesUsername];
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
    if (activitesCount) {
        return activitesCount;
    } else {
        return 0;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {    
    int activitiesCount = [self.activitiesArray count];
    if (indexPath.row >= activitiesCount) {
        return MINIMUM_INTERACTION_HEIGHT;
    }
    
    ActivityCell *activityCell = [[ActivityCell alloc] init];
    int height = [activityCell setActivity:[self.activitiesArray objectAtIndex:(indexPath.row)] withUsername:self.activitiesUsername  withWidth:self.frame.size.width] + 30;
    
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
    
    [cell setActivity:[self.activitiesArray objectAtIndex:(indexPath.row)] 
                     withUsername:self.activitiesUsername
                        withWidth:self.frame.size.width];

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
