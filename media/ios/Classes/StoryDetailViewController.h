//
//  StoryDetailViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "WEPopoverController.h"
#import "BaseViewController.h"

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;

@interface StoryDetailViewController : BaseViewController
<UIPopoverControllerDelegate, WEPopoverControllerDelegate,
UIScrollViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    NSString *activeStoryId;
    UIProgressView *progressView;
    UIView *innerView;
    UIWebView *webView;
    UIToolbar *toolbar;
    UIBarButtonItem *buttonPrevious;
    UIBarButtonItem *buttonNext;
    UIBarButtonItem *activity;
    UIActivityIndicatorView *loadingIndicator;
    WEPopoverController *popoverController;
    UIToolbar *bottomPlaceholderToolbar;
    UIBarButtonItem *buttonBack;
	Class popoverClass;
    NSInteger pageIndex;
    BOOL pullingScrollview;
}

@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSString *activeStoryId;
@property (nonatomic) IBOutlet UIProgressView *progressView;
@property (strong, nonatomic) IBOutlet UIView *progressViewContainer;
@property (nonatomic) IBOutlet UIView *innerView;
@property (nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic) IBOutlet UIToolbar *toolbar;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonPrevious;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonNext;
@property (nonatomic) UIBarButtonItem *buttonBack;
@property (nonatomic) IBOutlet UIBarButtonItem *activity;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonAction;
@property (nonatomic) IBOutlet UIView *feedTitleGradient;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonNextStory;
@property (nonatomic, strong) WEPopoverController *popoverController;
@property (nonatomic) IBOutlet UIToolbar *bottomPlaceholderToolbar;
@property (nonatomic) IBOutlet UIBarButtonItem *fontSettingsButton;
@property (nonatomic) IBOutlet UIBarButtonItem *originalStoryButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *subscribeButton;
@property (nonatomic) IBOutlet UILabel *noStorySelectedLabel;
@property (nonatomic, assign) BOOL pullingScrollview;
@property NSInteger pageIndex;


- (void)setNextPreviousButtons;
- (void)markStoryAsRead;
- (void)toggleLikeComment:(BOOL)likeComment;
- (void)showStory;
- (void)scrolltoComment;
- (IBAction)showOriginalSubview:(id)sender;
- (IBAction)doNextUnreadStory;
- (IBAction)doNextStory;
- (IBAction)doPreviousStory;
- (IBAction)tapProgressBar:(id)sender;
- (void)changeWebViewWidth:(int)width;
- (void)showUserProfile:(NSString *)userId xCoordinate:(int)x yCoordinate:(int)y width:(int)width height:(int)height;
- (void)initStory;
- (void)clearStory;

- (void)showShareHUD:(NSString *)msg;
- (void)refreshComments:(NSString *)replyId;
- (void)finishMarkAsRead:(ASIHTTPRequest *)request;
- (void)openSendToDialog;
- (void)markStoryAsUnread;
- (void)finishMarkAsUnread:(ASIHTTPRequest *)request;
- (void)markStoryAsSaved;
- (void)finishMarkAsSaved:(ASIHTTPRequest *)request;
- (void)markStoryAsUnsaved;
- (void)finishMarkAsUnsaved:(ASIHTTPRequest *)request;
- (void)openShareDialog;
- (void)finishLikeComment:(ASIHTTPRequest *)request;
- (void)subscribeToBlurblog;
- (void)finishSubscribeToBlurblog:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)setActiveStory;
- (IBAction)toggleFontSize:(id)sender;
- (void)setFontStyle:(NSString *)fontStyle;
- (void)changeFontSize:(NSString *)fontSize;
- (NSString *)getShareBar;
- (NSString *)getComments;
- (NSString *)getComment:(NSDictionary *)commentDict;
- (NSString *)getReplies:(NSArray *)replies forUserId:(NSString *)commentUserId;
- (NSString *)getAvatars:(NSString *)key;
- (NSDictionary *)getUser:(int)user_id;
- (void)transitionFromFeedDetail;



@end
