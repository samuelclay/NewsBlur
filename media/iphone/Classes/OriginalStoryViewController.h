//
//  OriginalStoryViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 11/13/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface OriginalStoryViewController : UIViewController {
    
    NewsBlurAppDelegate *appDelegate;
    
    IBOutlet UIBarButtonItem * closeButton;
    UIWebView *webView;
    
    UIBarButtonItem* back;
    UIBarButtonItem* forward;
    UIBarButtonItem* refresh;
    UIBarButtonItem* pageAction;
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *closeButton;
@property (nonatomic, retain) IBOutlet UIWebView *webView;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* back;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* forward;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* refresh;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* pageAction;

- (IBAction) doCloseOriginalStoryViewController;

- (void)updateButtons;

@end
