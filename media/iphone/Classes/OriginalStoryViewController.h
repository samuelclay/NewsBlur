//
//  OriginalStoryViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/13/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

static const CGFloat kNavBarHeight  = 60.0f;
static const CGFloat kLabelHeight   = 18.0f;
static const CGFloat kMargin        = 10.0f;
static const CGFloat kSpacer        = 2.0f;
static const CGFloat kLabelFontSize = 12.0f;
static const CGFloat kAddressHeight = 28.0f;
static const CGFloat kButtonWidth   = 48.0f;

@interface OriginalStoryViewController : UIViewController {
    
    NewsBlurAppDelegate *appDelegate;
    
    IBOutlet UIBarButtonItem * closeButton;
    UIWebView *webView;
    
    UIBarButtonItem* back;
    UIBarButtonItem* forward;
    UIBarButtonItem* refresh;
    UIBarButtonItem* pageAction;
    UILabel *pageTitle;
    UITextField *pageUrl;
    UIToolbar *toolbar;
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *closeButton;
@property (nonatomic, retain) IBOutlet UIWebView *webView;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* back;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* forward;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* refresh;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* pageAction;
@property (nonatomic, retain) IBOutlet UILabel *pageTitle;
@property (nonatomic, retain) IBOutlet UITextField *pageUrl;
@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;

- (IBAction) doCloseOriginalStoryViewController;
- (void)loadAddress:(id)sender event:(UIEvent*)event;
- (void)updateTitle:(UIWebView*)aWebView;
- (void)updateAddress:(NSURLRequest*)request;
- (void)updateButtons;
- (void)informError:(NSError*)error;    

@end
