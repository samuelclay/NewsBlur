//
//  StoryDetailViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;
@class ASIHTTPRequest;

@interface StoryDetailViewController : UIViewController <UIPopoverControllerDelegate> {
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
    UIPopoverController *popoverController;
    UIToolbar *topToolbar;
    UIToolbar *bottomPlaceholderToolbar;
}

@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSString *activeStoryId;
@property (nonatomic) IBOutlet UIProgressView *progressView;
@property (nonatomic) IBOutlet UIView *innerView;
@property (nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic) IBOutlet UIToolbar *toolbar;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonPrevious;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonNext;
@property (nonatomic) IBOutlet UIBarButtonItem *activity;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonAction;
@property (nonatomic) IBOutlet UIView *feedTitleGradient;
@property (nonatomic) IBOutlet UIBarButtonItem *buttonNextStory;
@property (nonatomic) UIPopoverController *popoverController;
@property (nonatomic) IBOutlet UIToolbar *topToolbar;
@property (nonatomic) IBOutlet UIToolbar *bottomPlaceholderToolbar;

- (void)setNextPreviousButtons;
- (void)markStoryAsRead;
- (void)showStory;
- (void)scrolltoBottom;
- (void)showOriginalSubview:(id)sender;
- (IBAction)doNextUnreadStory;
- (IBAction)doNextStory;
- (IBAction)doPreviousStory;
- (void)changeWebViewWidth:(int)width;
- (void)showUserProfile:(NSString *)userId xCoordinate:(int)x yCoordinate:(int)y width:(int)width height:(int)height;
- (void)initStory;

- (void)refreshComments;
- (void)finishMarkAsRead:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)setActiveStory;
- (IBAction)toggleFontSize:(id)sender;
- (void)hideToggleFontSize;
- (void)setFontStyle:(NSString *)fontStyle;
- (void)changeFontSize:(NSString *)fontSize;
- (NSString *)getComments:(NSString *)type;
- (NSString *)getComment:(NSDictionary *)commentDict;
- (NSString *)getReplies:(NSArray *)replies forUserId:(NSString *)commentUserId;
- (NSString *)getAvatars:(BOOL)areFriends;
- (NSDictionary *)getUser:(int)user_id;
- (void)transitionFromFeedDetail;

@end
