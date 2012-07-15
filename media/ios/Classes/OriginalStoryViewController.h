//
//  OriginalStoryViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/13/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseViewController.h"

@class NewsBlurAppDelegate;

static const CGFloat kNavBarHeight  = 58.0f;
static const CGFloat kLabelHeight   = 18.0f;
static const CGFloat kMargin        = 6.0f;
static const CGFloat kSpacer        = 2.0f;
static const CGFloat kLabelFontSize = 12.0f;
static const CGFloat kAddressHeight = 30.0f;
static const CGFloat kButtonWidth   = 48.0f;

@interface OriginalStoryViewController : BaseViewController
<UIActionSheetDelegate, UITextFieldDelegate, UIWebViewDelegate> {
    
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

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIBarButtonItem *closeButton;
@property (nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic) IBOutlet UIBarButtonItem* back;
@property (nonatomic) IBOutlet UIBarButtonItem* forward;
@property (nonatomic) IBOutlet UIBarButtonItem* refresh;
@property (nonatomic) IBOutlet UIBarButtonItem* pageAction;
@property (nonatomic) IBOutlet UILabel *pageTitle;
@property (nonatomic) IBOutlet UITextField *pageUrl;
@property (nonatomic) IBOutlet UIToolbar *toolbar;

- (IBAction) doCloseOriginalStoryViewController;
- (IBAction) doOpenActionSheet;
- (IBAction)loadAddress:(id)sender;
- (void)updateTitle:(UIWebView*)aWebView;
- (void)updateAddress:(NSURLRequest*)request;
- (void)updateButtons;

@end
