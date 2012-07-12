//
//  ActivityModule.m
//  NewsBlur
//
//  Created by Roy Yang on 7/11/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "ActivityModule.h"
#import "NewsBlurAppDelegate.h"
#import "Utilities.h"
#import "ASIHTTPRequest.h"
#import "JSON.h"

@implementation ActivityModule

@synthesize appDelegate;
@synthesize activitiesTable;
@synthesize activitiesArray;
@synthesize isSelf;


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
    }
    return self;
}

- (void)dealloc {
    [appDelegate release];
    [activitiesTable release];
    [activitiesArray release];
    [super dealloc];
}

- (void)layoutSubviews {
    [super layoutSubviews];
}


- (void)refreshWithActivities:(NSArray *)activities asSelf:(BOOL)asSelf {
    self.isSelf = asSelf;
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];   
    self.activitiesArray = activities;
    
    self.activitiesTable = [[[UITableView alloc] init] autorelease];
    self.activitiesTable.dataSource = self;
    self.activitiesTable.delegate = self;
    self.activitiesTable.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] 
                 initWithStyle:UITableViewCellStyleDefault 
                 reuseIdentifier:CellIdentifier] autorelease];
    }
    
    int activitesCount = [self.activitiesArray count];
    if (activitesCount) {

        NSDictionary *activity = [self.activitiesArray objectAtIndex:indexPath.row];
        NSString *category = [activity objectForKey:@"category"];
        NSString *content = [activity objectForKey:@"content"];
        NSString *title = [activity objectForKey:@"title"];
        NSString *username = self.isSelf ? @"You" : @"Stub for username";
        NSString *withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];

        
        if ([category isEqualToString:@"follow"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ followed %@", username, withUserUsername];
            
        } else if ([category isEqualToString:@"comment_reply"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ replied to %@", username, withUserUsername];
            
        } else if ([category isEqualToString:@"sharedstory"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ shared %@ : %@", username, title, content];
        
        // star and feedsub are always private.
        } else if ([category isEqualToString:@"star"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"You saved %@", content];
            
        } else if ([category isEqualToString:@"feedsub"]) {
            
            cell.textLabel.text = [NSString stringWithFormat:@"You subscribed to %@", content];
        }
        
        cell.textLabel.font = [UIFont systemFontOfSize:13];
    }
    
    return cell;
}



@end
