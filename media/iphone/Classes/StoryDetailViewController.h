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
    UIWebView *webView;
    UIToolbar *toolbar;
    UIBarButtonItem *buttonPrevious;
    UIBarButtonItem *buttonNext;
    UIBarButtonItem *activity;
    UIBarButtonItem *toggleViewButton;
    UIActivityIndicatorView *loadingIndicator;
    UIPopoverController *popoverController;
}

@property (nonatomic, retain) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) NSString *activeStoryId;
@property (nonatomic, retain) IBOutlet UIProgressView *progressView;
@property (nonatomic, retain) IBOutlet UIWebView *webView;
@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *buttonPrevious;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *buttonNext;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *activity;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *toggleViewButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *buttonAction;
@property (nonatomic, retain) IBOutlet UIView *feedTitleGradient;
@property (retain,nonatomic) UIPopoverController *popoverController;
@property (retain, nonatomic) IBOutlet UIBarButtonItem *buttonNextStory;

- (void)setNextPreviousButtons;
- (void)markStoryAsRead;
- (void)toggleView;
- (void)showStory;
- (void)showOriginalSubview:(id)sender;
- (IBAction)doNextUnreadStory;
- (IBAction)doNextStory;
- (IBAction)doPreviousStory;
- (void)changeWebViewWidth:(int)width;
- (void)showUserProfile:(NSString *)userId xCoordinate:(int)x yCoordinate:(int)y width:(int)width height:(int)height;

- (void)refreshComments;
- (void)finishMarkAsRead:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)setActiveStory;
- (IBAction)toggleFontSize:(id)sender;
- (void)setFontStyle:(NSString *)fontStyle;
- (void)changeFontSize:(NSString *)fontSize;
- (NSString *)getComments;
- (NSString *)getComment:(NSDictionary *)commentDict;
- (NSString *)getReplies:(NSArray *)replies;
- (NSString *)getAvatars:(BOOL)areFriends;
- (NSString *)getImageURL:(NSString *)imageURL;
- (NSDictionary *)getUser:(int)user_id;

@end
