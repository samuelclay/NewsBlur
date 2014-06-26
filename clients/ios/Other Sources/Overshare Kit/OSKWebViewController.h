//
//  OSKWebViewController.h
//  Overshare
//
//  Created by Jared Sinclair on 10/11/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class OSKWebViewController;

@protocol OSKWebViewControllerDelegate <NSObject>

@optional
- (BOOL)webViewController:(OSKWebViewController *)webViewController shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;
- (void)webViewControllerDidStartLoad:(OSKWebViewController *)webViewController;
- (void)webViewControllerDidFinishLoad:(OSKWebViewController *)webViewController;
- (void)webViewController:(OSKWebViewController *)webViewController didFailLoadWithError:(NSError *)error;

@end

@interface OSKWebViewController : UIViewController

@property (strong, nonatomic, readonly) UIWebView *webView; // Do not set the webView's delegate, use the protocol above if needed
@property (weak, nonatomic) id <OSKWebViewControllerDelegate> webViewControllerDelegate;

- (instancetype)initWithURL:(NSURL *)URL;
- (void)cancelButtonPressed:(id)sender;
- (void)clearCookiesForBaseURLs:(NSArray *)baseURLstrings;

@end

@interface OSKWebViewController (OnePasswordOptions)

+ (NSString *)queryForOnePasswordSearch;

@end
