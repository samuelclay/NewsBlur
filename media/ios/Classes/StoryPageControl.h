//
//  StoryPageControl.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseViewController.h"
#import "NewsBlurAppDelegate.h"
#import "PagerViewController.h"

@class NewsBlurAppDelegate;

@interface StoryPageControl : UIViewController
<UIScrollViewDelegate> {
    
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) StoryDetailViewController *currentPage;
@property (nonatomic) StoryDetailViewController *nextPage;
@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) IBOutlet UIPageControl *pageControl;

- (void)applyNewIndex:(NSInteger)newIndex pageController:(StoryDetailViewController *)pageController;

- (IBAction)changePage:(id)sender;

@end
