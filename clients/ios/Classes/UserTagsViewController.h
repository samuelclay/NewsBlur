//
//  UserTagsViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/10/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "NewsBlur-Swift.h"

@interface UserTagsViewController : UIViewController
<UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate> {
    UITableView *tagsTableView;
    UISearchBar *addTagBar;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;

- (NSArray *)arrayUserTags;
- (NSArray *)arrayUserTagsNotInStory;

@end
