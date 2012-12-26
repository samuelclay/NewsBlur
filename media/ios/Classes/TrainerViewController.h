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


@interface TrainerWebView : UIWebView {}

- (void)changeTitle:(id)sender;

@end


@interface TrainerViewController : BaseViewController
<UIWebViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    IBOutlet UIBarButtonItem * closeButton;
    TrainerWebView *webView;
    UINavigationBar *navBar;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIBarButtonItem *closeButton;
@property (nonatomic) IBOutlet TrainerWebView *webView;
@property (nonatomic) IBOutlet UINavigationBar *navBar;

- (NSString *)makeTrainerSections;
- (NSString *)makeAuthor;
- (NSString *)makeTags;
- (NSString *)makePublisher;
- (NSString *)makeTitle;
- (NSString *)makeClassifier:(NSString *)classifierName withType:(NSString *)classifierType;

- (IBAction)doCloseDialog:(id)sender;
- (void)changeTitle:(id)sender;

@end