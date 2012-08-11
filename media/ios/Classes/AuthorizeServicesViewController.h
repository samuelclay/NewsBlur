//
//  AuthorizeServicesViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 8/10/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface AuthorizeServicesViewController : UIViewController <UIWebViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
    NSString *url;
    NSString *type;        
}

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) NSString *url;
@property (nonatomic) NSString *type;

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end
