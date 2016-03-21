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
#import "THCircularProgressView.h"
#import "NBNotifier.h"

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;

@interface StoryPageControl : BaseViewController
<UIScrollViewDelegate, UIPopoverControllerDelegate, UIPopoverPresentationControllerDelegate, UIGestureRecognizerDelegate> {
    
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
    
    BOOL isDraggingScrollview;
    BOOL isAnimatedIntoPlace;
    BOOL inRotation;
    BOOL waitingForNextUnreadFromServer;
    UIInterfaceOrientation _orientation;
    CGFloat scrollPct;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) StoryDetailViewController *currentPage;
@property (nonatomic) StoryDetailViewController *nextPage;
@property (nonatomic) StoryDetailViewController *previousPage;
@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) IBOutlet UIPageControl *pageControl;

@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *loadingIndicator;
@property (nonatomic) IBOutlet UIImageView *textStorySendBackgroundImageView;
@property (nonatomic) IBOutlet UIImageView *prevNextBackgroundImageView;
@property (nonatomic) IBOutlet THCircularProgressView *circularProgressView;
@property (nonatomic) IBOutlet UIButton *buttonPrevious;
@property (nonatomic) IBOutlet UIButton *buttonNext;
@property (nonatomic) IBOutlet UIButton *buttonText;
@property (nonatomic) IBOutlet UIButton *buttonSend;
@property (nonatomic) UIBarButtonItem *buttonBack;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonAction;
@property (nonatomic) IBOutlet UIView *bottomSize;
@property (nonatomic) IBOutlet NSLayoutConstraint *bottomSizeHeightConstraint;
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
@property (nonatomic) IBOutlet UIImageView *dragBarImageView;
@property (readwrite) BOOL traversePinned;
@property (readwrite) BOOL traverseFloating;
@property (readwrite) CGFloat inTouchMove;
@property (assign) BOOL isDraggingScrollview;
@property (assign) BOOL isAnimatedIntoPlace;
@property (assign) BOOL waitingForNextUnreadFromServer;
@property (nonatomic) MBProgressHUD *storyHUD;
@property (nonatomic, strong) NBNotifier *notifier;
@property (nonatomic) NSInteger scrollingToPage;

- (void)resizeScrollView;
- (void)applyNewIndex:(NSInteger)newIndex pageController:(StoryDetailViewController *)pageController;
- (void)layoutForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (void)adjustDragBar:(UIInterfaceOrientation)orientation;

- (void)transitionFromFeedDetail;
- (void)resetPages;
- (void)hidePages;
- (void)refreshPages;
- (void)reorientPages;
- (void)refreshHeaders;
- (void)setStoryFromScroll;
- (void)setStoryFromScroll:(BOOL)force;
- (void)advanceToNextUnread;
- (void)updatePageWithActiveStory:(NSInteger)location;
- (void)animateIntoPlace:(BOOL)animated;
- (void)changePage:(NSInteger)pageIndex;
- (void)changePage:(NSInteger)pageIndex animated:(BOOL)animated;
- (void)requestFailed:(ASIHTTPRequest *)request;

- (void)setNextPreviousButtons;
- (void)setTextButton;
- (void)setTextButton:(StoryDetailViewController *)storyViewController;
- (void)finishMarkAsSaved:(ASIFormDataRequest *)request;
- (BOOL)failedMarkAsSaved:(ASIFormDataRequest *)request;
- (void)finishMarkAsUnsaved:(ASIFormDataRequest *)request;
- (BOOL)failedMarkAsUnsaved:(ASIFormDataRequest *)request;
- (BOOL)failedMarkAsUnread:(ASIFormDataRequest *)request;
- (void)subscribeToBlurblog;

- (IBAction)toggleFontSize:(id)sender;
- (void)setFontStyle:(NSString *)fontStyle;
- (void)changeFontSize:(NSString *)fontSize;
- (void)changeLineSpacing:(NSString *)lineSpacing;
- (void)drawStories;
- (void)showShareHUD:(NSString *)msg;
- (void)showFetchingTextNotifier;
- (void)hideNotifier;

- (IBAction)showOriginalSubview:(id)sender;

- (void)flashCheckmarkHud:(NSString *)messageType;

- (IBAction)openSendToDialog:(id)sender;
- (IBAction)doNextUnreadStory:(id)sender;
- (IBAction)doPreviousStory:(id)sender;
- (IBAction)tapProgressBar:(id)sender;
- (IBAction)toggleTextView:(id)sender;

@end
