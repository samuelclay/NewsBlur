//
//  OSKWebViewController.m
//  Overshare
//
//  Created by Jared Sinclair on 10/11/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKWebViewController.h"

#import "OSKActivityIndicatorItem.h"
#import "OSKPresentationManager.h"
#import "OSKRPSTPasswordManagementAppService.h"

@interface OSKWebViewController () <UIWebViewDelegate>

@property (strong, nonatomic, readwrite) UIWebView *webView;
@property (strong, nonatomic) NSURL *initialURL;
@property (strong, nonatomic) OSKActivityIndicatorItem *activityIndicatorView;
@property (assign, nonatomic) BOOL viewHasAppeared;
@property (assign, nonatomic) BOOL showOnePasswordButton;

@end

@implementation OSKWebViewController

- (instancetype)initWithURL:(NSURL *)URL {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _initialURL = URL;
        if ([self.class queryForOnePasswordSearch] != nil) {
            _showOnePasswordButton = [OSKRPSTPasswordManagementAppService passwordManagementAppIsAvailable];
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [[OSKPresentationManager sharedInstance] color_opaqueBackground];
    
    NSString *cancelTitle = [[OSKPresentationManager sharedInstance] localizedText_Cancel];
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithTitle:cancelTitle style:UIBarButtonItemStylePlain target:self action:@selector(cancelButtonPressed:)];
    
    if (self.showOnePasswordButton) {
        NSString *pwTitle = @"1Password";
        UIBarButtonItem *onePWItem = [[UIBarButtonItem alloc] initWithTitle:pwTitle style:UIBarButtonItemStylePlain target:self action:@selector(onePasswordButtonTapped:)];
        UIBarButtonItem *space1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        self.navigationItem.leftBarButtonItems = @[cancelItem, space1, onePWItem];
        self.title = @"";
    } else {
        self.navigationItem.leftBarButtonItems = @[cancelItem];
    }
    
    self.activityIndicatorView = [self spinnerViewItem];
    self.navigationItem.rightBarButtonItem = self.activityIndicatorView;
    
    _webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    _webView.alpha = 0; // We'll fade it in.
    _webView.suppressesIncrementalRendering = NO;
    _webView.scalesPageToFit = YES;
    _webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _webView.delegate = self;
    [self.view addSubview:_webView];
    
    
    [_webView loadRequest:[NSURLRequest requestWithURL:_initialURL]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.viewHasAppeared == NO) {
        __weak OSKWebViewController *weakSelf = self;
        [UIView animateWithDuration:0.3 animations:^{
            [weakSelf.webView setAlpha:1.0f];
        }];
    }
    [self setViewHasAppeared:YES];
}

#pragma mark - Button Actions

- (void)cancelButtonPressed:(id)sender {
    // no op
}

#pragma mark - Web View Delegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    BOOL shouldStart = YES;
    if ([self.webViewControllerDelegate respondsToSelector:@selector(webViewController:shouldStartLoadWithRequest:navigationType:)]) {
        shouldStart = [self.webViewControllerDelegate webViewController:self shouldStartLoadWithRequest:request navigationType:navigationType];
    }
    if (shouldStart) {
        [self.activityIndicatorView startSpinning];
    }
    return shouldStart;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    if ([self.webViewControllerDelegate respondsToSelector:@selector(webViewControllerDidStartLoad:)]) {
        [self.webViewControllerDelegate webViewControllerDidStartLoad:self];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSString *pageTitle = [webView stringByEvaluatingJavaScriptFromString:@"document.title;"];
    [self setTitle:pageTitle];
    if ([self.webViewControllerDelegate respondsToSelector:@selector(webViewControllerDidFinishLoad:)]) {
        [self.webViewControllerDelegate webViewControllerDidFinishLoad:self];
    }
    [self.activityIndicatorView stopSpinning];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if ([self.webViewControllerDelegate respondsToSelector:@selector(webViewController:didFailLoadWithError:)]) {
        [self.webViewControllerDelegate webViewController:self didFailLoadWithError:error];
    }
    [self.activityIndicatorView stopSpinning];
}

#pragma mark - Activity Indicator View

- (OSKActivityIndicatorItem *)spinnerViewItem {
    UIActivityIndicatorViewStyle style = (self.navigationController.navigationBar.barStyle == UIBarStyleBlack)
                                        ? UIActivityIndicatorViewStyleWhite
                                        : UIActivityIndicatorViewStyleGray;
    return [OSKActivityIndicatorItem item:style];
}

#pragma mark - Cookies

- (void)clearCookiesForBaseURLs:(NSArray *)baseURLstrings {
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSString *aURLstring in baseURLstrings) {
        NSURL *URL = [NSURL URLWithString:aURLstring];
        if (URL) {
            NSArray *cookies = [storage cookiesForURL:URL];
            for (NSHTTPCookie *cookie in cookies) {
                [storage deleteCookie:cookie];
            }
        }
    }
}

#pragma mark - One Password

+ (NSString *)queryForOnePasswordSearch {
    // Subclasses may override
    return nil;
}

- (void)onePasswordButtonTapped:(id)sender {
    NSString *query = [self.class queryForOnePasswordSearch];
    if (query) {
        NSURL *URL = [OSKRPSTPasswordManagementAppService passwordManagementAppCompleteURLForSearchQuery:query];
        [[UIApplication sharedApplication] openURL:URL];
    }
}

@end








