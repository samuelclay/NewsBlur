//
//  NotificationFeedCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/23/16.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MultiSelectSegmentedControl.h"

@class NewsBlurAppDelegate;

@interface NotificationFeedCell : UITableViewCell <MultiSelectSegmentedControlDelegate> {
    NewsBlurAppDelegate *appDelegate;

}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSString *feedId;
@property (nonatomic) UISegmentedControl * filterControl;
@property (nonatomic) MultiSelectSegmentedControl * notificationTypeControl;

@end
