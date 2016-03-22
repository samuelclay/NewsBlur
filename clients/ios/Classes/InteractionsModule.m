//
//  InteractionsModule.m
//  NewsBlur
//
//  Created by Roy Yang on 7/11/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "InteractionsModule.h"
#import "NewsBlurAppDelegate.h"
#import "InteractionCell.h"
#import "SmallInteractionCell.h"
#import <QuartzCore/QuartzCore.h>
#import "ASIHTTPRequest.h"
#import "UserProfileViewController.h"
#import "DashboardViewController.h"

#define MINIMUM_INTERACTION_HEIGHT_IPAD 78
#define MINIMUM_INTERACTION_HEIGHT_IPHONE 54

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
    self.interactionsTable.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    
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
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // if there is no social profile, we are DONE
//    if ([[appDelegate.dictSocialProfile allKeys] count] == 0) {
//        self.pageFinished = YES;
//        [self.interactionsTable reloadData];
//        return;
//    } else {
//        if (page == 1) {
//            self.pageFinished = NO;
//        }
//    }
    
    if (page == 1) {
        self.pageFetching = NO;
        self.pageFinished = NO;
        appDelegate.userInteractionsArray = nil;
    }

    if (!self.pageFetching && !self.pageFinished) {
        self.interactionsPage = page;
        self.pageFetching = YES;
  
        NSString *urlString = [NSString stringWithFormat:@
                               "%@/social/interactions?user_id=%@&page=%i&limit=10"
                               "&category=follow&category=comment_reply&category=comment_like&category=reply_reply&category=story_reshare",
                               self.appDelegate.url,
                               [appDelegate.dictSocialProfile objectForKey:@"user_id"],
                               page];

        NSURL *url = [NSURL URLWithString:urlString];
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
        [request setValidatesSecureCertificate:NO];

        [request setDidFinishSelector:@selector(finishLoadInteractions:)];
        [request setDidFailSelector:@selector(requestFailed:)];
        [request setDelegate:self];
        [request startAsynchronous];
    }
}

- (void)finishLoadInteractions:(ASIHTTPRequest *)request {
    self.pageFetching = NO;
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    NSArray *newInteractions = [results objectForKey:@"interactions"];
    
    // check for last page
    if (![[results objectForKey:@"has_next_page"] intValue]) {
        self.pageFinished = YES;
    }
    
    NSMutableArray *confirmedInteractions = [NSMutableArray array];
    if ([appDelegate.userInteractionsArray count]) {
        NSMutableSet *interactionsDates = [NSMutableSet set];
        for (id interaction in appDelegate.userInteractionsArray) {
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
        appDelegate.userInteractionsArray = confirmedInteractions;
    } else {
        appDelegate.userInteractionsArray = [appDelegate.userInteractionsArray arrayByAddingObjectsFromArray:newInteractions];
    }
    
    
    [self refreshWithInteractions:appDelegate.userInteractionsArray];
} 

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
    [appDelegate informError:error];
}

#pragma mark -
#pragma mark Table View - Interactions List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger userInteractions = [appDelegate.userInteractionsArray count];
    int minimumHeight;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        minimumHeight = MINIMUM_INTERACTION_HEIGHT_IPAD;
    } else {
        minimumHeight = MINIMUM_INTERACTION_HEIGHT_IPHONE;
    }
    
    if (indexPath.row >= userInteractions) {
        return minimumHeight;
    }
    
    InteractionCell *interactionCell;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        interactionCell = [[InteractionCell alloc] init];
    } else {
        interactionCell = [[SmallInteractionCell alloc] init];
    }
    int height = [interactionCell setInteraction:[appDelegate.userInteractionsArray objectAtIndex:(indexPath.row)] withWidth:self.frame.size.width - 20];

    return height;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *blank = [[UIView alloc] init];
    return blank;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{    
    NSInteger userInteractionsCount = [appDelegate.userInteractionsArray count];
    return userInteractionsCount + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    InteractionCell *cell = [tableView
                             dequeueReusableCellWithIdentifier:@"InteractionCell"];
    if (cell == nil) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            cell = [[InteractionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"InteractionCell"];
        } else {
            cell = [[SmallInteractionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"InteractionCell"];
        }
    }
    
    if (indexPath.row >= [appDelegate.userInteractionsArray count]) {
        // add in loading cell
        return [self makeLoadingCell];
    } else {
        NSDictionary *interaction = [appDelegate.userInteractionsArray objectAtIndex:(indexPath.row)];
        NSString *category = [interaction objectForKey:@"category"];
        if (![category isEqualToString:@"follow"]) {
            cell.accessoryType=  UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        cell.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
        
        // update the cell information
        [cell setInteraction:interaction withWidth: self.frame.size.width - 20];
        [cell layoutSubviews];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger userInteractions = [appDelegate.userInteractionsArray count];
    if (indexPath.row < userInteractions) {
        NSDictionary *interaction = [appDelegate.userInteractionsArray objectAtIndex:indexPath.row];
        NSString *category = [interaction objectForKey:@"category"];
        if ([category isEqualToString:@"follow"]) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            
            NSString *userId = [NSString stringWithFormat:@"%@", [[interaction objectForKey:@"with_user"] objectForKey:@"user_id"]];
            appDelegate.activeUserProfileId = userId;
            
            NSString *username = [NSString stringWithFormat:@"%@", [[interaction objectForKey:@"with_user"] objectForKey:@"username"]];
            appDelegate.activeUserProfileName = username;

            // pass cell to the show UserProfile
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            [appDelegate showUserProfileModal:cell];
        } else if ([category isEqualToString:@"comment_reply"] || 
                   [category isEqualToString:@"reply_reply"] ||
                   [category isEqualToString:@"comment_like"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", [interaction objectForKey:@"feed_id"]];
            NSString *contentIdStr = [NSString stringWithFormat:@"%@", [interaction objectForKey:@"content_id"]];
            [appDelegate loadTryFeedDetailView:feedIdStr 
                                     withStory:contentIdStr 
                                      isSocial:YES
                                      withUser:[interaction objectForKey:@"with_user"]
                              showFindingStory:YES];
            appDelegate.tryFeedCategory = category;
        } else if ([category isEqualToString:@"story_reshare"]) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", [[interaction objectForKey:@"with_user"] objectForKey:@"id"]];
            NSString *contentIdStr = [NSString stringWithFormat:@"%@", [interaction objectForKey:@"content_id"]];
            [appDelegate loadTryFeedDetailView:feedIdStr
                                     withStory:contentIdStr
                                      isSocial:YES
                                      withUser:[interaction objectForKey:@"with_user"]
                              showFindingStory:YES];
            appDelegate.tryFeedCategory = category;
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
    cell.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    
    if (self.pageFinished) {
        UIImage *img = [UIImage imageNamed:@"fleuron.png"];
        UIImageView *fleuron = [[UIImageView alloc] initWithImage:img];
        
        int height;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            height = MINIMUM_INTERACTION_HEIGHT_IPAD;
        } else {
            height = MINIMUM_INTERACTION_HEIGHT_IPHONE;
        }
        
        fleuron.frame = CGRectMake(0, 0, self.frame.size.width, height);
        fleuron.contentMode = UIViewContentModeCenter;
        [cell.contentView addSubview:fleuron];
        fleuron.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
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