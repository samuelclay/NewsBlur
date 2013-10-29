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
#import "WEPopoverController.h"
#import "THCircularProgressView.h"

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;

@interface StoryPageControl : BaseViewController
<UIScrollViewDelegate, UIPopoverControllerDelegate, UIGestureRecognizerDelegate, WEPopoverControllerDelegate> {
    
    NewsBlurAppDelegate *appDelegate;

    THCircularProgressView *circularProgressView;
    UIButton *buttonPrevious;
    UIButton *buttonNext;
    UIButton *buttonText;
    UIActivityIndicatorView *loadingIndicator;
    UIBarButtonItem *buttonBack;
    UIView *traverseView;
    UIView *progressView;
    UIView *progressViewContainer;
    
    WEPopoverController *popoverController;
	Class popoverClass;
    
    BOOL isDraggingScrollview;
    BOOL waitingForNextUnreadFromServer;
    UIInterfaceOrientation _orientation;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) StoryDetailViewController *currentPage;
@property (nonatomic) StoryDetailViewController *nextPage;
@property (nonatomic) StoryDetailViewController *previousPage;
@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) IBOutlet UIPageControl *pageControl;

@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *loadingIndicator;
@property (nonatomic) IBOutlet THCircularProgressView *circularProgressView;
@property (nonatomic) IBOutlet UIButton *buttonPrevious;
@property (nonatomic) IBOutlet UIButton *buttonNext;
@property (nonatomic) IBOutlet UIButton *buttonText;
@property (nonatomic) IBOutlet UIButton *buttonSend;
@property (nonatomic) UIBarButtonItem *buttonBack;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonAction;
@property (nonatomic) IBOutlet UIView *bottomSize;
@property (nonatomic) IBOutlet UIBarButtonItem * spacerBarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * spacer2BarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * spacer3BarButton;
@property (nonatomic) IBOutlet UIBarButtonItem * separatorBarButton;
@property (nonatomic) IBOutlet UIView *traverseView;
@property (nonatomic) IBOutlet UIView *progressView;
@property (nonatomic) IBOutlet UIView *progressViewContainer;
@property (nonatomic) IBOutlet UIBarButtonItem *fontSettingsButton;
@property (nonatomic) IBOutlet UIBarButtonItem *originalStoryButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *subscribeButton;
@property (readwrite) BOOL traversePinned;
@property (readwrite) BOOL traverseFloating;
@property (readwrite) CGFloat inTouchMove;
@property (assign) BOOL isDraggingScrollview;
@property (assign) BOOL waitingForNextUnreadFromServer;
@property (nonatomic) MBProgressHUD *storyHUD;
@property (nonatomic) NSInteger scrollingToPage;

@property (nonatomic, strong) WEPopoverController *popoverController;

- (void)resizeScrollView;
- (void)applyNewIndex:(NSInteger)newIndex pageController:(StoryDetailViewController *)pageController;
- (void)layoutForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (void)adjustDragBar:(UIInterfaceOrientation)orientation;

- (void)transitionFromFeedDetail;
- (void)resetPages;
- (void)hidePages;
- (void)refreshPages;
- (void)refreshHeaders;
- (void)setStoryFromScroll;
- (void)setStoryFromScroll:(BOOL)force;
- (void)advanceToNextUnread;
- (void)updatePageWithActiveStory:(NSInteger)location;
- (void)changePage:(NSInteger)pageIndex;
- (void)changePage:(NSInteger)pageIndex animated:(BOOL)animated;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)requestFailedMarkStoryRead:(ASIFormDataRequest *)request;

- (void)setNextPreviousButtons;
- (void)setTextButton;
- (void)markStoryAsRead;
- (void)finishMarkAsRead:(ASIFormDataRequest *)request;
- (void)markStoryAsUnread;
- (void)finishMarkAsUnread:(ASIFormDataRequest *)request;
- (void)markStoryAsSaved;
- (void)finishMarkAsSaved:(ASIFormDataRequest *)request;
- (void)markStoryAsUnsaved;
- (void)finishMarkAsUnsaved:(ASIFormDataRequest *)request;
- (void)failedMarkAsUnread:(ASIFormDataRequest *)request;
- (void)subscribeToBlurblog;

- (IBAction)toggleFontSize:(id)sender;
- (void)setFontStyle:(NSString *)fontStyle;
- (void)changeFontSize:(NSString *)fontSize;
- (void)showShareHUD:(NSString *)msg;

- (IBAction)showOriginalSubview:(id)sender;

- (void)flashCheckmarkHud:(NSString *)messageType;

- (IBAction)openSendToDialog:(id)sender;
- (IBAction)doNextUnreadStory:(id)sender;
- (IBAction)doPreviousStory:(id)sender;
- (IBAction)tapProgressBar:(id)sender;
- (IBAction)toggleView:(id)sender;

@end
