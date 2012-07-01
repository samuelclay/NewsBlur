//
//  FriendsListViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/1/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface FriendsListViewController : UITableViewController {
    NewsBlurAppDelegate *appDelegate;
    NSArray *allItems;

}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;

@property (nonatomic, copy) NSArray *allItems;

- (void)doCancelButton;
@end
