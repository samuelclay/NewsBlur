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
        
    BOOL pageFetching;
    BOOL pageFinished;
    int activitiesPage;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic, strong) UITableView *activitiesTable;

@property (nonatomic, readwrite) BOOL pageFetching;
@property (nonatomic, readwrite) BOOL pageFinished;
@property (readwrite) int activitiesPage;

- (void)refreshWithActivities:(NSArray *)activities;

- (void)fetchActivitiesDetail:(int)page;

- (void)checkScroll;

@end
