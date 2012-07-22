//
//  ActivityModule.h
//  NewsBlur
//
//  Created by Roy Yang on 7/11/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;

@interface ActivityModule : UIView
    <UITableViewDelegate, 
    UITableViewDataSource> {
    NewsBlurAppDelegate *appDelegate;
    UITableView *activitiesTable;
    NSArray *activitiesArray;
    NSString *activitiesUsername;
    UIPopoverController *popoverController;
        
    BOOL pageFetching;
    BOOL pageFinished;
    int activitiesPage;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic, strong) UITableView *activitiesTable;
@property (nonatomic) NSArray *activitiesArray;
@property (nonatomic) NSString *activitiesUsername;
@property (nonatomic, strong) UIPopoverController *popoverController;

@property (nonatomic, readwrite) BOOL pageFetching;
@property (nonatomic, readwrite) BOOL pageFinished;
@property (readwrite) int activitiesPage;

- (void)refreshWithActivities:(NSArray *)activities withUsername:(NSString *)username;

- (void)fetchActivitiesDetail:(int)page;
- (void)finishLoadActivities:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;

- (void)checkScroll;

@end
