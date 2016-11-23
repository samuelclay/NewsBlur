//
//  NotificationFeedCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/23/16.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface NotificationFeedCell : UITableViewCell {
    NewsBlurAppDelegate *appDelegate;

}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSInteger feedId;

@end
