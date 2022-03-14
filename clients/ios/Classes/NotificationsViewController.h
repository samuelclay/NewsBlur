//
//  NotificationsViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/23/16.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "NewsBlur-Swift.h"

@class NewsBlurAppDelegate;

@interface NotificationsViewController : BaseViewController <UITableViewDelegate, UITableViewDataSource> {
    NewsBlurAppDelegate *appDelegate;
    NSArray *notificationFeedIds;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UITableView *notificationsTable;
@property (nonatomic) NSString *feedId;

@end
