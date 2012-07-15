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

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIWebView *webView;

- (IBAction)tapCancelButton:(id)sender;
@end
