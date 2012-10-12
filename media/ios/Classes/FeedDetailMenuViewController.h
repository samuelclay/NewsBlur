//
//  FeedDetailMenuViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/10/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface FeedDetailMenuViewController : UIViewController
<UITableViewDelegate,
UITableViewDataSource> {
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic, strong) NSArray *menuOptions;
@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UITableView *menuTableView;

@end
