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
}

@property (nonatomic, retain) NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) UITableView *activitiesTable;
@property (nonatomic, retain) NSArray *activitiesArray;
@property (nonatomic, retain) NSString *activitiesUsername;

- (void)refreshWithActivities:(NSDictionary *)activitiesDict;

@end
