//
//  NBContainerViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/24/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface NBContainerViewController : UIViewController {
    NewsBlurAppDelegate *appDelegate;
}

@property (atomic, strong) IBOutlet NewsBlurAppDelegate *appDelegate;


- (void)adjustDashboardScreen;
- (void)adjustFeedDetailScreen;

- (void)transitionToFeedDetail;
- (void)transitionFromFeedDetail;

- (void)dragStoryToolbar:(int)yCoordinate;
@end
