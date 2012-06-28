//
//  StoryDetailViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface StoryDetailViewController : UIViewController <UIPopoverControllerDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    NSString *activeStoryId;
    UIProgressView *progressView;
    UIWebView *webView;
    UIToolbar *toolbar;
    UIBarButtonItem *buttonPrevious;
    UIBarButtonItem *buttonNext;
    UIBarButtonItem *activity;
    UIActivityIndicatorView *loadingIndicator;
    IBOutlet UIPopoverController *popoverController;
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
@property (nonatomic, retain) IBOutlet UIBarButtonItem *buttonAction;
@property (nonatomic, retain) IBOutlet UIView *feedTitleGradient;
@property (retain,nonatomic) UIPopoverController *popoverController;
@property (retain, nonatomic) IBOutlet UIBarButtonItem *buttonNextStory;

- (void)setNextPreviousButtons;
- (void)markStoryAsRead;
- (void)showStory;
- (void)showOriginalSubview:(id)sender;
- (IBAction)doNextUnreadStory;
- (IBAction)doNextStory;
- (IBAction)doPreviousStory;
- (void)changeWebViewWidth:(int)width;

- (void)refreshComments;
- (void)markedAsRead;
- (void)setActiveStory;
- (IBAction)toggleFontSize:(id)sender;
- (void)setFontStyle:(NSString *)fontStyle;
- (void)changeFontSize:(NSString *)fontSize;
- (NSString *)getComments;
- (NSString *)getComment:(NSDictionary *)commentDict;
- (NSString *)getReplies:(NSArray *)replies;
- (NSString *)getAvatars:(BOOL)areFriends;
- (NSDictionary *)getUser:(int)user_id;

@end
