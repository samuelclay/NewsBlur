//
//  ActivityModule.h
//  NewsBlur
//
//  Created by Roy Yang on 7/11/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface ActivityModule : UIView
    <UITableViewDelegate, 
    UITableViewDataSource> {
    NewsBlurAppDelegate *appDelegate;
    UITableView *activitiesTable;
    NSArray *activitiesArray;
    NSString *activitiesUsername;
    UIPopoverController *popoverController;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic, strong) UITableView *activitiesTable;
@property (nonatomic) NSArray *activitiesArray;
@property (nonatomic) NSString *activitiesUsername;
@property (nonatomic, strong) UIPopoverController *popoverController;

- (void)refreshWithActivities:(NSDictionary *)activitiesDict;

@end
