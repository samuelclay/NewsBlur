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
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;

@property (retain, nonatomic) IBOutlet UIToolbar *toolbar;

@end
