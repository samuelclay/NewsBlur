//
//  OriginalStoryViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/13/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseViewController.h"
#import <WebKit/WebKit.h>

@interface OriginalStoryViewController : BaseViewController
<UITextFieldDelegate, WKNavigationDelegate, WKUIDelegate,
UIGestureRecognizerDelegate> {
    
    NSString *activeUrl;
    NSMutableArray *visitedUrls;
    WKWebView *webView;
    UIBarButtonItem *backBarButton;
    UILabel *titleView;
    UIBarButtonItem *closeButton;
    UIProgressView *progressView;
    BOOL finishedLoading;
}

@property (nonatomic) IBOutlet WKWebView *webView;
//@property (strong, nonatomic) SloppySwiper *swiper;
@property (nonatomic) UIProgressView *progressView;
@property (nonatomic, strong) NSString *customPageTitle;

- (void)resetProgressBar;
- (void)loadInitialStory;
- (IBAction) doOpenActionSheet:(id)sender;
- (IBAction)loadAddress:(id)sender;
- (IBAction)webViewGoBack:(id)sender;
- (IBAction)webViewGoForward:(id)sender;
- (IBAction)webViewRefresh:(id)sender;
- (void)updateTitle:(WKWebView*)aWebView;
- (void)closeOriginalView;

@end
