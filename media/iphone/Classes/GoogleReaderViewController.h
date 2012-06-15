//
//  GoogleReaderViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/15/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@class NewsBlurAppDelegate;

@interface GoogleReaderViewController : UIViewController <UIWebViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (retain, nonatomic) IBOutlet UIWebView *webView;

@end
