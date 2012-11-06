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


- (void)toggleLikeComment:(BOOL)likeComment;
- (void)showStory;
- (void)scrolltoComment;
- (void)changeWebViewWidth:(int)width;
- (void)showUserProfile:(NSString *)userId xCoordinate:(int)x yCoordinate:(int)y width:(int)width height:(int)height;
- (void)setFontStyle:(NSString *)fontStyle;
- (void)changeFontSize:(NSString *)fontSize;
- (void)initStory;
- (void)clearStory;

- (void)showShareHUD:(NSString *)msg;
- (void)refreshComments:(NSString *)replyId;

- (void)openShareDialog;
- (void)finishLikeComment:(ASIHTTPRequest *)request;
- (void)subscribeToBlurblog;
- (void)finishSubscribeToBlurblog:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)setActiveStoryAtIndex:(NSInteger)activeStoryIndex;
- (NSString *)getShareBar;
- (NSString *)getComments;
- (NSString *)getComment:(NSDictionary *)commentDict;
- (NSString *)getReplies:(NSArray *)replies forUserId:(NSString *)commentUserId;
- (NSString *)getAvatars:(NSString *)key;
- (NSDictionary *)getUser:(int)user_id;
- (void)transitionFromFeedDetail;



@end
