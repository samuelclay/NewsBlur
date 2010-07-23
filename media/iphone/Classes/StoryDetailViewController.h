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
<UIWebViewDelegate> {
    NewsBlurAppDelegate *appDelegate;

    UIWebView *webView;
}

@property (nonatomic, retain) IBOutlet UIWebView *webView;

@end
