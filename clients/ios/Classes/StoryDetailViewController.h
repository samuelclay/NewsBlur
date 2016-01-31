//
//  StoryDetailViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>
#import "BaseViewController.h"

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;

@interface StoryDetailViewController : BaseViewController
<UIScrollViewDelegate, UIGestureRecognizerDelegate,
UIActionSheetDelegate>

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
@property (nonatomic) BOOL inDoubleTap;
@property (nonatomic) CGFloat scrollPct;
@property (nonatomic) BOOL hasScrolled;
@property (nonatomic) NSInteger actionSheetCopyImageIndex;
@property (nonatomic) NSInteger actionSheetSaveImageIndex;
@property (nonatomic) NSInteger actionSheetViewImageIndex;
@property (nonatomic) NSURL *activeLongPressUrl;

@property NSInteger pageIndex;
@property (nonatomic) MBProgressHUD *storyHUD;
@property (nonatomic) UIInterfaceOrientation cachedOrientation;

- (void)initStory;
- (void)hideNoStoryMessage;
- (void)drawStory;
- (void)drawStory:(BOOL)force withOrientation:(UIInterfaceOrientation)orientation;
- (void)drawFeedGradient;
- (void)showStory;
- (void)clearStory;
- (void)hideStory;

- (void)toggleLikeComment:(BOOL)likeComment;
- (void)flashCheckmarkHud:(NSString *)messageType;
- (void)scrolltoComment;
- (void)tryScrollingDown:(BOOL)down;
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
- (void)finishLikeComment:(ASIHTTPRequest *)request;
- (void)subscribeToBlurblog;
- (void)finishSubscribeToBlurblog:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)setActiveStoryAtIndex:(NSInteger)activeStoryIndex;
- (NSString *)getHeader;
- (NSString *)getShareBar;
- (NSString *)getComments;
- (NSString *)getComment:(NSDictionary *)commentDict;
- (NSString *)getReplies:(NSArray *)replies forUserId:(NSString *)commentUserId;
- (NSString *)getAvatars:(NSString *)key;
- (void)refreshHeader;
- (void)refreshSideoptions;

- (void)showTextOrStoryView;
- (void)showStoryView;
- (void)fetchTextView;
- (void)finishFetchTextView:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;


@end
