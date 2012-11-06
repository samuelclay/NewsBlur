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
#import "WEPopoverController.h"

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;

@interface StoryPageControl : BaseViewController
<UIScrollViewDelegate, UIPopoverControllerDelegate, WEPopoverControllerDelegate> {
    
    NewsBlurAppDelegate *appDelegate;

    UIProgressView *progressView;
    UIToolbar *toolbar;
    UIBarButtonItem *buttonPrevious;
    UIBarButtonItem *buttonNext;
    UIBarButtonItem *activity;
    UIActivityIndicatorView *loadingIndicator;
    UIToolbar *bottomPlaceholderToolbar;
    UIBarButtonItem *buttonBack;
    
    WEPopoverController *popoverController;
	Class popoverClass;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) StoryDetailViewController *currentPage;
@property (nonatomic) StoryDetailViewController *nextPage;
@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) IBOutlet UIPageControl *pageControl;

@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic) IBOutlet UIProgressView *progressView;
@property (strong, nonatomic) IBOutlet UIView *progressViewContainer;
@property (nonatomic) IBOutlet UIToolbar *toolbar;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonPrevious;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonNext;
@property (nonatomic) UIBarButtonItem *buttonBack;
@property (nonatomic) IBOutlet UIBarButtonItem *activity;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonAction;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonNextStory;
@property (nonatomic) IBOutlet UIToolbar *bottomPlaceholderToolbar;
@property (nonatomic) IBOutlet UIBarButtonItem *fontSettingsButton;
@property (nonatomic) IBOutlet UIBarButtonItem *originalStoryButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *subscribeButton;

@property (nonatomic, strong) WEPopoverController *popoverController;

- (void)applyNewIndex:(NSInteger)newIndex pageController:(StoryDetailViewController *)pageController;

- (void)setStory;
- (void)changePage:(NSInteger)pageIndex;
- (void)requestFailed:(ASIHTTPRequest *)request;

- (void)setNextPreviousButtons;
- (void)markStoryAsRead;
- (void)finishMarkAsRead:(ASIHTTPRequest *)request;
- (void)openSendToDialog;
- (void)markStoryAsUnread;
- (void)finishMarkAsUnread:(ASIHTTPRequest *)request;
- (void)markStoryAsSaved;
- (void)finishMarkAsSaved:(ASIHTTPRequest *)request;
- (void)markStoryAsUnsaved;
- (void)finishMarkAsUnsaved:(ASIHTTPRequest *)request;

- (IBAction)toggleFontSize:(id)sender;

- (IBAction)showOriginalSubview:(id)sender;
- (IBAction)doNextUnreadStory;
- (IBAction)doNextStory;
- (IBAction)doPreviousStory;
- (IBAction)tapProgressBar:(id)sender;

@end
