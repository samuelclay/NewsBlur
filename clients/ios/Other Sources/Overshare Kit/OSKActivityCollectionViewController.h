//
//  OSKActivityCollectionViewController.h
//  Overshare
//
//  Created by Jared Sinclair on 10/12/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class OSKActivity;
@class OSKActivityCollectionViewController;

@protocol OSKActivityCollectionViewControllerDelegate <NSObject>

- (void)activityCollection:(OSKActivityCollectionViewController *)viewController didChangeNumberOfPages:(NSInteger)numberOfPages;
- (void)activityCollection:(OSKActivityCollectionViewController *)viewController didScrollToPageIndex:(NSInteger)pageIndex;
- (void)activityCollection:(OSKActivityCollectionViewController *)viewController didSelectActivity:(OSKActivity *)activity;

@end

@interface OSKActivityCollectionViewController : UICollectionViewController

@property (strong, nonatomic) NSArray *activities;

- (instancetype)initWithActivities:(NSArray *)activities delegate:(id <OSKActivityCollectionViewControllerDelegate>)delegate;

- (NSInteger)numberOfVisibleActivitiesPerRow;
- (void)osk_invalidateLayout;
- (NSInteger)numberOfPages;
- (void)scrollToPage:(NSInteger)pageIndex;

@end



