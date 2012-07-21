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

#define MINIMUM_INTERACTION_HEIGHT 78

@implementation InteractionsModule

@synthesize appDelegate;
@synthesize interactionsTable;
@synthesize interactionsArray;
@synthesize popoverController;
@synthesize pageFetching;
@synthesize pageFinished;
@synthesize interactionsPage;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
    }
    return self;
}


- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.interactionsTable = [[UITableView alloc] init];
    self.interactionsTable.dataSource = self;
    self.interactionsTable.delegate = self;
    self.interactionsTable.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    self.interactionsTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self addSubview:self.interactionsTable];  
}


- (void)refreshWithInteractions:(NSArray *)interactions {
    self.interactionsArray = interactions;
    
    [self.interactionsTable reloadData];
    
    self.pageFetching = NO;
        
    [self performSelector:@selector(checkScroll)
               withObject:nil
               afterDelay:0.1];
}

- (void)checkScroll {
    NSInteger currentOffset = self.interactionsTable.contentOffset.y;
    NSInteger maximumOffset = self.interactionsTable.contentSize.height - self.interactionsTable.frame.size.height;
    
    if (maximumOffset - currentOffset <= 60.0) {
        [self fetchInteractionsDetail:self.interactionsPage + 1];
    }
}


#pragma mark -
#pragma mark Get Interactions

- (void)fetchInteractionsDetail:(int)page {
    if (page == 1) {
        self.pageFetching = NO;
        self.pageFinished = NO;
        appDelegate.dictUserInteractions = nil;
    }
    if (!self.pageFetching && !self.pageFinished) {
        self.interactionsPage = page;
        self.pageFetching = YES;
        self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];  
        NSString *urlString = [NSString stringWithFormat:@"http://%@/social/interactions?user_id=%@&page=%i&limit=10",
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

- (void)finishLoadInteractions:(ASIHTTPRequest *)request {
    self.pageFetching = NO;
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    
    NSArray *newInteractions = [results objectForKey:@"interactions"];
    NSMutableArray *confirmedInteractions = [NSMutableArray array];
    if ([appDelegate.dictUserInteractions count]) {
        NSMutableSet *interactionsDates = [NSMutableSet set];
        for (id interaction in appDelegate.dictUserInteractions) {
            [interactionsDates addObject:[interaction objectForKey:@"date"]];
        }
        for (id interaction in newInteractions) {
            if (![interactionsDates containsObject:[interaction objectForKey:@"date"]]) {
                [confirmedInteractions addObject:interaction];
            }
        }
    } else {
        confirmedInteractions = [newInteractions copy];
    }
    
    if (self.interactionsPage == 1) {
        appDelegate.dictUserInteractions = confirmedInteractions;
    } else {
        appDelegate.dictUserInteractions = [appDelegate.dictUserInteractions arrayByAddingObjectsFromArray:newInteractions];
    }
    
    if ([confirmedInteractions count] == 0 || self.interactionsPage > 100) {
        self.pageFinished = YES;
    }
    [self refreshWithInteractions:appDelegate.dictUserInteractions];
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


-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 00;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    int userInteractions = [appDelegate.dictUserInteractions count];
    if (indexPath.row >= userInteractions) {
        return MINIMUM_INTERACTION_HEIGHT;
    }
    
    InteractionCell *interactionCell = [[InteractionCell alloc] init];
    int height = [interactionCell setInteraction:[appDelegate.dictUserInteractions objectAtIndex:(indexPath.row)] withWidth:self.frame.size.width] + 30;
    if (height < MINIMUM_INTERACTION_HEIGHT) {
        return MINIMUM_INTERACTION_HEIGHT;
    } else {
        return height;
    }

}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *blank = [[UIView alloc] init];
    return blank;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{    
    int userInteractionsCount = [appDelegate.dictUserInteractions count];
    return userInteractionsCount + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    InteractionCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:@"InteractionCell"];
    if (cell == nil) {
        cell = [[InteractionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"InteractionCell"];
    }
    

    if (indexPath.row >= [appDelegate.dictUserInteractions count]) {
        // add in loading cell
        return [self makeLoadingCell];
    } else {
        // update the cell information
        [cell setInteraction:[appDelegate.dictUserInteractions objectAtIndex:(indexPath.row)] withWidth: self.frame.size.width];
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

- (UITableViewCell *)makeLoadingCell {
    UITableViewCell *cell = [[UITableViewCell alloc] 
                             initWithStyle:UITableViewCellStyleSubtitle 
                             reuseIdentifier:@"NoReuse"];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (self.pageFinished) {
        UIImage *img = [UIImage imageNamed:@"fleuron.png"];
        UIImageView *fleuron = [[UIImageView alloc] initWithImage:img];
        int height = MINIMUM_INTERACTION_HEIGHT;
        
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