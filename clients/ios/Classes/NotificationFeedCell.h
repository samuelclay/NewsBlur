//
//  NotificationFeedCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/23/16.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface NotificationFeedCell : UITableViewCell

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSString *feedId;
@property (nonatomic) UISegmentedControl *filterControl;
@property (nonatomic) UIButton *emailNotificationTypeButton;
@property (nonatomic) UIButton *webNotificationTypeButton;
@property (nonatomic) UIButton *iOSNotificationTypeButton;
@property (nonatomic) UIButton *androidNotificationTypeButton;

@end
