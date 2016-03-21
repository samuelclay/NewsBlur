//
//  FeedChooserViewController.h
//  NewsBlur
//
//  Created by David Sinclair on 2016-01-22.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, FeedChooserOperation)
{
    FeedChooserOperationMuteSites = 0,
    FeedChooserOperationOrganizeSites = 1
};


@interface FeedChooserViewController : UIViewController

@property (weak) IBOutlet UITableView *tableView;

@property (nonatomic) FeedChooserOperation operation;

@end
