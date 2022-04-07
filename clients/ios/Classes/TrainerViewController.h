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
#import "NewsBlur-Swift.h"

@import WebKit;

@interface TrainerWebView : WKWebView {}

- (void)focusTitle:(id)sender;
- (void)hideTitle:(id)sender;

@end


@interface TrainerViewController : BaseViewController <WKNavigationDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    IBOutlet UIBarButtonItem * closeButton;
    TrainerWebView *webView;
    IBOutlet UINavigationBar *navBar;
    
    BOOL feedLoaded;
    BOOL feedTrainer;
    BOOL storyTrainer;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIBarButtonItem *closeButton;
@property (nonatomic) IBOutlet TrainerWebView *webView;
@property (nonatomic) IBOutlet UINavigationBar *navBar;
@property (nonatomic, assign) BOOL feedTrainer;
@property (nonatomic, assign) BOOL storyTrainer;
@property (nonatomic, assign) BOOL feedLoaded;

- (void)refresh;
- (NSString *)makeTrainerHTML;
- (NSString *)makeTrainerSections;
- (NSString *)makeStoryAuthor;
- (NSString *)makeFeedAuthors;
- (NSString *)makeStoryTags;
- (NSString *)makeFeedTags;
- (NSString *)makePublisher;
- (NSString *)makeTitle;
- (NSString *)makeClassifier:(NSString *)classifierName withType:(NSString *)classifierType score:(int)score;

- (IBAction)doCloseDialog:(id)sender;

@end
