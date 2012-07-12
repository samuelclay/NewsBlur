//
//  ActivityModule.m
//  NewsBlur
//
//  Created by Roy Yang on 7/11/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "ActivityModule.h"
#import "NewsBlurAppDelegate.h"
#import <QuartzCore/QuartzCore.h>

@implementation ActivityModule

@synthesize appDelegate;
@synthesize activitiesTable;
@synthesize activitiesArray;
@synthesize activitiesUsername;

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
    [activitiesUsername release];
    [super dealloc];
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
    
    self.activitiesTable = [[[UITableView alloc] init] autorelease];
    self.activitiesTable.dataSource = self;
    self.activitiesTable.delegate = self;
    self.activitiesTable.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    self.activitiesTable.layer.cornerRadius = 10;
    
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
        
        if ([category isEqualToString:@"follow"]) {
            
            NSString *withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
            cell.textLabel.text = [NSString stringWithFormat:@"%@ followed %@", self.activitiesUsername, withUserUsername];
            
        } else if ([category isEqualToString:@"comment_reply"]) {
            NSString *withUserUsername = [[activity objectForKey:@"with_user"] objectForKey:@"username"];
            cell.textLabel.text = [NSString stringWithFormat:@"%@ replied to %@", self.activitiesUsername, withUserUsername];
            
        } else if ([category isEqualToString:@"sharedstory"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ shared %@ : %@", self.activitiesUsername, title, content];
        
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
