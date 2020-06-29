//
//  AuthorizeServicesViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 8/10/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
@import WebKit;

@class NewsBlurAppDelegate;

@interface AuthorizeServicesViewController : UIViewController <WKNavigationDelegate> {
    NewsBlurAppDelegate *appDelegate;
    NSString *url;
    NSString *type;
    BOOL fromStory;
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSString *url;
@property (nonatomic) NSString *type;
@property (nonatomic, readwrite) BOOL fromStory;

@property (weak, nonatomic) IBOutlet WKWebView *webView;

- (void)doCancelButton;
- (void)showError:(NSString *)error;

@end
