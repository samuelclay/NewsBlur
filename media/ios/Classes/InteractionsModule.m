//
//  InteractionsModule.m
//  NewsBlur
//
//  Created by Roy Yang on 7/11/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "InteractionsModule.h"
#import "NewsBlurAppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import "DashboardViewController.h"
#import "UserProfileViewController.h"
#import "InteractionCell.h"
#import "ASIHTTPRequest.h"
#import "JSON.h"

@implementation InteractionsModule

@synthesize appDelegate;
@synthesize interactionsTable;
@synthesize interactionsArray;
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


- (void)refreshWithInteractions:(NSMutableArray *)interactions {
 
    self.interactionsArray = interactions;
    
    self.interactionsTable = [[UITableView alloc] init];
    self.interactionsTable.dataSource = self;
    self.interactionsTable.delegate = self;
    self.interactionsTable.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
//    self.interactionsTable.layer.cornerRadius = 10;
    self.interactionsTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self addSubview:self.interactionsTable];    
    [self.interactionsTable reloadData];
    
}


#pragma mark -
#pragma mark Get Interactions

- (void)fetchInteractionsDetail:(int)page {
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];  
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/interactions?user_id=%@&page=%i",
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

- (void)finishLoadInteractions:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    
    appDelegate.dictUserInteractions = [results objectForKey:@"interactions"];
    
    [self refreshWithInteractions:appDelegate.dictUserInteractions];
    
    //    [self repositionDashboard];
} 

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

#pragma mark -
#pragma mark Table View - Interactions List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {

    #define MINIMUM_INTERACTION_HEIGHT 78
    
    InteractionCell *interactionCell = [[InteractionCell alloc] init];
    int height = [interactionCell refreshInteraction:[appDelegate.dictUserInteractions objectAtIndex:(indexPath.row)] withWidth:self.frame.size.width] + 30;
    NSLog(@"height is %i", height);
    if (height < MINIMUM_INTERACTION_HEIGHT) {
        return MINIMUM_INTERACTION_HEIGHT;
    } else {
        return height;
    }

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{    
    int userInteractionsCount = [appDelegate.dictUserInteractions count];
    if (userInteractionsCount) {
        return userInteractionsCount;
    } else {
        return 0;
    }
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
    
    int userInteractions = [appDelegate.dictUserInteractions count];
    if (userInteractions) {
        InteractionCell *interactionCell = [[InteractionCell alloc] init];
        [cell.contentView addSubview:interactionCell];
        [interactionCell refreshInteraction:[appDelegate.dictUserInteractions objectAtIndex:(indexPath.row)] withWidth: self.frame.size.width];
    }    

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    int userInteractions = [appDelegate.dictUserInteractions count];
    if (indexPath.row < userInteractions) {
        NSDictionary *interaction = [appDelegate.dictUserInteractions objectAtIndex:indexPath.row];
        NSString *category = [interaction objectForKey:@"category"];
        if ([category isEqualToString:@"follow"]) {
            NSString *userId = [[interaction objectForKey:@"with_user"] objectForKey:@"user_id"];
            appDelegate.activeUserProfileId = userId;
            [tableView deselectRowAtIndexPath:indexPath animated:YES];

            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            self.popoverController = [[UIPopoverController alloc] initWithContentViewController:appDelegate.userProfileViewController];
            [self.popoverController setPopoverContentSize:CGSizeMake(320, 416)];
            [self.popoverController presentPopoverFromRect:cell.bounds 
                                     inView:cell 
                   permittedArrowDirections:UIPopoverArrowDirectionAny 
                                   animated:YES];
        } else if ([category isEqualToString:@"comment_reply"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", [interaction objectForKey:@"feed_id"]];
            NSString *contentIdStr = [NSString stringWithFormat:@"%@", [interaction objectForKey:@"content_id"]];
            [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr isSocial:YES];
        } else if ([category isEqualToString:@"reply_reply"] || 
                [category isEqualToString:@"story_reshare"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", [[interaction objectForKey:@"with_user"] objectForKey:@"id"]];
            NSString *contentIdStr = [NSString stringWithFormat:@"%@", [interaction objectForKey:@"content_id"]];
            [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr isSocial:YES];
        }
        
        // have the selected cell deselect
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

@end