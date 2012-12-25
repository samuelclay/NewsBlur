//
//  TrainerViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 12/24/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseViewController.h"
#import "NewsBlurAppDelegate.h"

@interface TrainerViewController : BaseViewController
<UIWebViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    IBOutlet UIBarButtonItem * closeButton;
    UIWebView *webView;
    UINavigationBar *navBar;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIBarButtonItem *closeButton;
@property (nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic) IBOutlet UINavigationBar *navBar;

- (NSString *)makeTrainerSections;
- (NSString *)makeAuthor;
- (NSString *)makeTags;
- (NSString *)makePublisher;
- (NSString *)makeTitle;
- (IBAction)doCloseDialog:(id)sender;

@end
