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
    ActivityCell *activityCell = [[[ActivityCell alloc] init] autorelease];
    int height = [activityCell refreshActivity:[self.activitiesArray objectAtIndex:(indexPath.row)] withUsername:self.activitiesUsername] + 20;
    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] 
                 initWithStyle:UITableViewCellStyleDefault 
                 reuseIdentifier:CellIdentifier] autorelease];
    } else {
        [[[cell contentView] subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
    }
    
    int activitesCount = [self.activitiesArray count];
    if (activitesCount >= (indexPath.row + 1)) {
        ActivityCell *activityCell = [[ActivityCell alloc] init];
        [activityCell refreshActivity:[self.activitiesArray objectAtIndex:(indexPath.row)] withUsername:self.activitiesUsername];
        [cell.contentView addSubview:activityCell];
        [activityCell release];
    }    
    return cell;
}



@end
