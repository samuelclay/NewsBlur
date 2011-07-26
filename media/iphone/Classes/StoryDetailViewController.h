//
//  StoryDetailViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface StoryDetailViewController : UIViewController 
<UIScrollViewDelegate> {
    NewsBlurAppDelegate *appDelegate;

    UIProgressView *progressView;
    UIWebView *webView;
    UIToolbar *toolbar;
    UIBarButtonItem *buttonPrevious;
    UIBarButtonItem *buttonNext;
    
    int originalUnreadCount;
}

@property (nonatomic, retain) IBOutlet UIProgressView *progressView;
@property (nonatomic, retain) IBOutlet UIWebView *webView;
@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *buttonPrevious;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *buttonNext;
@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (readwrite) int originalunreadCount;

- (void)setNextPreviousButtons;
- (void)markStoryAsRead;
- (void)showStory;
- (void)showOriginalSubview:(id)sender;
- (IBAction)doNextUnreadStory;
- (IBAction)doPreviousStory;

@end
