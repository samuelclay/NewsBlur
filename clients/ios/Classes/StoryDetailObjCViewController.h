//
//  StoryDetailObjCViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "BaseViewController.h"
@import WebKit;

@class NewsBlurAppDelegate;

@interface StoryDetailObjCViewController : BaseViewController
<UIScrollViewDelegate, UIGestureRecognizerDelegate,
UIActionSheetDelegate, WKNavigationDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    NSString *activeStoryId;
    NSMutableDictionary *activeStory;
    UIView *innerView;
    WKWebView *webView;
    NSInteger pageIndex;
    BOOL pullingScrollview;
    BOOL inTextView;
    BOOL inDoubleTap;
    BOOL hasScrolled;
    NSURL *activeLongPressUrl;
    CGSize preRotateSize;
    CGFloat scrollPct;
    
    UIInterfaceOrientation _orientation;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSString *activeStoryId;
@property (nonatomic, readwrite) NSMutableDictionary *activeStory;
@property (nonatomic) IBOutlet UIView *innerView;
@property (nonatomic) IBOutlet WKWebView *webView;
@property (nonatomic) IBOutlet UIView *feedTitleGradient;
@property (nonatomic) IBOutlet UIView *noStoryMessage;
@property (nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (nonatomic, assign) BOOL pullingScrollview;
@property (nonatomic, assign) BOOL inTextView;
@property (nonatomic, assign) BOOL isRecentlyUnread;
@property (nonatomic) BOOL hasStory;
@property (nonatomic,  readonly) BOOL isSinglePage;

@property NSInteger pageIndex;
@property (nonatomic) MBProgressHUD *storyHUD;

- (void)initStory;
- (void)hideNoStoryMessage;
- (void)drawStory;
- (void)drawStory:(BOOL)force withOrientation:(UIInterfaceOrientation)orientation;
- (void)updateStoryTheme;
- (void)drawFeedGradient;
- (void)showStory;
- (void)clearStory;
- (void)hideStory;

- (void)toggleLikeComment:(BOOL)likeComment;
- (void)flashCheckmarkHud:(NSString *)messageType;
- (void)scrolltoComment;
- (void)tryScrollingDown:(BOOL)down;
- (void)scrollPageDown:(id)sender;
- (void)scrollPageUp:(id)sender;
- (void)realignScroll;
- (void)changeWebViewWidth;
- (void)showUserProfile:(NSString *)userId xCoordinate:(int)x yCoordinate:(int)y width:(int)width height:(int)height;
- (void)checkTryFeedStory;
- (void)setFontStyle:(NSString *)fontStyle;
- (void)changeFontSize:(NSString *)fontSize;
- (void)changeLineSpacing:(NSString *)lineSpacing;
- (void)refreshComments:(NSString *)replyId;

- (void)openShareDialog;
- (void)openTrainingDialog:(int)x yCoordinate:(int)y width:(int)width height:(int)height;
- (void)openUserTagsDialog:(int)x yCoordinate:(int)y width:(int)width height:(int)height;
- (void)subscribeToBlurblog;
- (void)setActiveStoryAtIndex:(NSInteger)activeStoryIndex;
- (NSString *)getHeader;
- (NSString *)getShareBar;
- (NSString *)getComments;
- (NSString *)getComment:(NSDictionary *)commentDict;
- (NSString *)getReplies:(NSArray *)replies forUserId:(NSString *)commentUserId;
- (NSString *)getAvatars:(NSString *)key;
- (void)refreshHeader;
- (void)refreshSideOptions;

- (CGPoint)pointForGesture:(UIGestureRecognizer *)gestureRecognizer;

- (void)showTextOrStoryView;
- (void)showStoryView;
- (void)fetchTextView;

@end
