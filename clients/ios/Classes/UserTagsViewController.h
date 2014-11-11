//
//  UserTagsViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/10/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@interface UserTagsViewController : UIViewController
<UITableViewDataSource, UITableViewDelegate> {
    UITableView *tagsTableView;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;

@end
