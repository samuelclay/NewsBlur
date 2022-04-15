//
//  StoryPagesObjCViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "BaseViewController.h"
#import "THCircularProgressView.h"
#import "NBNotifier.h"

@class StoryDetailViewController;

@interface StoryPagesObjCViewController : BaseViewController
<UIScrollViewDelegate, UIPopoverControllerDelegate, UIPopoverPresentationControllerDelegate, UIGestureRecognizerDelegate> {
    NewsBlurAppDelegate *appDelegate;
    THCircularProgressView *circularProgressView;
    UIButton *buttonPrevious;
    UIButton *buttonNext;
    UIButton *buttonText;
    UIBarButtonItem *markReadBarButton;
    UIBarButtonItem *separatorBarButton2;
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

@property (nonatomic, strong) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) StoryDetailViewController *currentPage;
@property (nonatomic) StoryDetailViewController *nextPage;
@property (nonatomic) StoryDetailViewController *previousPage;
@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) IBOutlet UIPageControl *pageControl;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *scrollViewTopConstraint;

@property (weak, nonatomic) IBOutlet UIView *autoscrollView;
@property (weak, nonatomic) IBOutlet UIImageView *autoscrollBackgroundImageView;
@property (weak, nonatomic) IBOutlet UIButton *autoscrollDisableButton;
@property (weak, nonatomic) IBOutlet UIButton *autoscrollPauseResumeButton;
@property (weak, nonatomic) IBOutlet UIButton *autoscrollSlowerButton;
@property (weak, nonatomic) IBOutlet UIButton *autoscrollFasterButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *autoscrollBottomConstraint;

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
@property (nonatomic) IBOutlet NSLayoutConstraint *traverseBottomConstraint;
@property (nonatomic) IBOutlet NSLayoutConstraint *scrollBottomConstraint;
@property (nonatomic) IBOutlet UIView *statusBarBackgroundView;
@property (nonatomic) BOOL autoscrollAvailable;
@property (nonatomic) BOOL autoscrollActive;
@property (nonatomic) NSTimeInterval autoscrollSpeed;
@property (readwrite) BOOL traversePinned;
@property (readwrite) BOOL traverseFloating;
@property (readwrite) CGFloat inTouchMove;
@property (assign) BOOL isDraggingScrollview;
@property (assign) BOOL isAnimatedIntoPlace;
@property (assign) BOOL waitingForNextUnreadFromServer;
@property (nonatomic) MBProgressHUD *storyHUD;
@property (nonatomic, strong) NBNotifier *notifier;
@property (nonatomic) NSInteger scrollingToPage;
@property (nonatomic, readonly) BOOL shouldHideStatusBar;
@property (nonatomic, readonly) BOOL isNavigationBarHidden;
@property (nonatomic, readonly) BOOL allowFullscreen;
@property (nonatomic) BOOL forceNavigationBarShown;
@property (nonatomic) BOOL currentlyTogglingNavigationBar;
@property (nonatomic, readonly) BOOL isHorizontal;
@property (nonatomic) BOOL temporarilyMarkedUnread;

- (void)resizeScrollView;
- (void)applyNewIndex:(NSInteger)newIndex pageController:(StoryDetailViewController *)pageController;
- (void)layoutForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (void)updateStatusBarState;
- (void)setNavigationBarHidden:(BOOL)hide;
- (void)setNavigationBarHidden:(BOOL)hide alsoTraverse:(BOOL)alsoTraverse;

//- (void)transitionFromFeedDetail;
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

- (void)setNextPreviousButtons;
- (void)setTextButton;
- (void)setTextButton:(StoryDetailViewController *)storyViewController;
- (void)subscribeToBlurblog;

- (IBAction)toggleFontSize:(id)sender;
- (void)setFontStyle:(NSString *)fontStyle;
- (void)changeFontSize:(NSString *)fontSize;
- (void)changeLineSpacing:(NSString *)lineSpacing;
- (void)changedFullscreen;
- (void)changedAutoscroll;
- (void)changedScrollOrientation;
- (void)updateStoriesTheme;
- (void)showShareHUD:(NSString *)msg;
- (void)showFetchingTextNotifier;
- (void)hideNotifier;

- (IBAction)showOriginalSubview:(id)sender;

- (void)flashCheckmarkHud:(NSString *)messageType;

- (void)tappedStory;
- (void)showAutoscrollBriefly:(BOOL)briefly;
- (void)hideAutoscrollAfterDelay;
- (void)hideAutoscrollImmediately;

- (IBAction)autoscrollDisable:(UIButton *)sender;
- (IBAction)autoscrollPauseResume:(UIButton *)sender;
- (IBAction)autoscrollSlower:(UIButton *)sender;
- (IBAction)autoscrollFaster:(UIButton *)sender;

- (IBAction)openSendToDialog:(id)sender;
- (IBAction)doNextUnreadStory:(id)sender;
- (IBAction)doPreviousStory:(id)sender;
- (IBAction)tapProgressBar:(id)sender;
- (IBAction)toggleTextView:(id)sender;

- (void)finishMarkAsSaved:(NSDictionary *)params;
- (BOOL)failedMarkAsSaved:(NSDictionary *)params;
- (void)finishMarkAsUnsaved:(NSDictionary *)params;
- (BOOL)failedMarkAsUnsaved:(NSDictionary *)params;
- (BOOL)failedMarkAsUnread:(NSDictionary *)params;

@end
