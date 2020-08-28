//
//  FeedChooserViewController.h
//  NewsBlur
//
//  Created by David Sinclair on 2016-01-22.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "NewsBlur-Swift.h"

typedef NS_ENUM(NSUInteger, FeedChooserOperation)
{
    FeedChooserOperationMuteSites = 0,
    FeedChooserOperationOrganizeSites = 1,
    FeedChooserOperationWidgetSites = 2
};


@interface FeedChooserViewController : BaseViewController {
    NewsBlurAppDelegate *appDelegate;
}

@property (weak) IBOutlet UITableView *tableView;

@property (nonatomic) FeedChooserOperation operation;

@end
