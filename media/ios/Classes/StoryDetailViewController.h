//
//  StoryDetailViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "BaseViewController.h"

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;

@interface StoryDetailViewController : BaseViewController
<UIScrollViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    NSString *activeStoryId;
    NSDictionary *activeStory;
    UIView *innerView;
    UIWebView *webView;
    NSInteger pageIndex;
    BOOL pullingScrollview;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSString *activeStoryId;
@property (nonatomic, readwrite) NSDictionary *activeStory;
@property (nonatomic) IBOutlet UIView *innerView;
@property (nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic) IBOutlet UIView *feedTitleGradient;
@property (nonatomic) IBOutlet UILabel *noStorySelectedLabel;
@property (nonatomic, assign) BOOL pullingScrollview;
@property NSInteger pageIndex;
@property (nonatomic) MBProgressHUD *storyHUD;

- (void)initStory;
- (void)drawStory;
- (void)showStory;
- (void)clearStory;
- (void)hideStory;

- (void)toggleLikeComment:(BOOL)likeComment;
- (void)scrolltoComment;
- (void)changeWebViewWidth;
- (void)showUserProfile:(NSString *)userId xCoordinate:(int)x yCoordinate:(int)y width:(int)width height:(int)height;
- (void)checkTryFeedStory;
- (void)setFontStyle:(NSString *)fontStyle;
- (void)changeFontSize:(NSString *)fontSize;
- (void)refreshComments:(NSString *)replyId;

- (void)openShareDialog;
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
- (NSDictionary *)getUser:(int)user_id;

- (void)toggleAuthorClassifier:(NSString *)author;
- (void)toggleTagClassifier:(NSString *)tag;
- (void)refreshHeader;


@end
