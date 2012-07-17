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
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];   
    self.interactionsArray = interactions;
    
    self.interactionsTable = [[UITableView alloc] init];
    self.interactionsTable.dataSource = self;
    self.interactionsTable.delegate = self;
    self.interactionsTable.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    self.interactionsTable.layer.cornerRadius = 10;
    self.interactionsTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self addSubview:self.interactionsTable];    
    [self.interactionsTable reloadData];
    
}

#pragma mark -
#pragma mark Table View - Interactions List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
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
    }
    
    int userInteractions = [appDelegate.dictUserInteractions count];
    if (userInteractions) {
        cell.textLabel.font = [UIFont systemFontOfSize:13];        
        NSDictionary *interaction = [appDelegate.dictUserInteractions objectAtIndex:indexPath.row];
        NSString *category = [interaction objectForKey:@"category"];
        NSString *content = [interaction objectForKey:@"content"];
        NSString *title = [interaction objectForKey:@"title"];
        NSString *username = [[interaction objectForKey:@"with_user"] objectForKey:@"username"];
        
        if ([category isEqualToString:@"follow"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ is now following you", username];
            
        } else if ([category isEqualToString:@"comment_reply"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ replied to your comment: %@", username, content];
        
        } else if ([category isEqualToString:@"reply_reply"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ replied to your reply: %@", username, content];
            
        } else if ([category isEqualToString:@"story_reshare"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ re-shared: %@.", username, title];
        }

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
             [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr];
         } else if ([category isEqualToString:@"reply_reply"] || 
                    [category isEqualToString:@"story_reshare"]) {
             NSString *feedIdStr = [NSString stringWithFormat:@"%@", [[interaction objectForKey:@"with_user"] objectForKey:@"id"]];
             NSString *contentIdStr = [NSString stringWithFormat:@"%@", [interaction objectForKey:@"content_id"]];
             [appDelegate loadTryFeedDetailView:feedIdStr withStory:contentIdStr];
         }

    }
}

@end