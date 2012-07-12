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

@implementation InteractionsModule

@synthesize appDelegate;
@synthesize interactionsTable;
@synthesize interactionsArray;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
    }
    return self;
}

- (void)dealloc {
    [appDelegate release];
    [interactionsTable release];
    [interactionsArray release];
    [super dealloc];
}

- (void)layoutSubviews {
    [super layoutSubviews];
}


- (void)refreshWithInteractions:(NSMutableArray *)interactions {
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];   
    self.interactionsArray = interactions;
    
    self.interactionsTable = [[[UITableView alloc] init] autorelease];
    self.interactionsTable.dataSource = self;
    self.interactionsTable.delegate = self;
    self.interactionsTable.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    self.interactionsTable.layer.cornerRadius = 10;
    
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
    int userInteractions = [appDelegate.dictUserInteractions count];
    if (userInteractions) {
        return userInteractions;
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
    
    int userInteractions = [appDelegate.dictUserInteractions count];
    if (userInteractions) {
        
        NSDictionary *interaction = [appDelegate.dictUserInteractions objectAtIndex:indexPath.row];
        NSString *category = [interaction objectForKey:@"category"];
        NSString *content = [interaction objectForKey:@"content"];
        NSString *username = [[interaction objectForKey:@"with_user"] objectForKey:@"username"];
        if ([category isEqualToString:@"follow"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ is now following you", username];
        } else if ([category isEqualToString:@"comment_reply"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ replied to your comment: %@", username, content];
        }
        cell.textLabel.font = [UIFont systemFontOfSize:13];
    }
    
    return cell;
}

@end