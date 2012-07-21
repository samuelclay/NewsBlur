//
//  FeedDashboardViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/20/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface FeedDashboardViewController : UIViewController {
    NewsBlurAppDelegate *appDelegate;
    UILabel *storyLabel;

}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;

@property (nonatomic) IBOutlet UILabel *storyLabel;

@end
