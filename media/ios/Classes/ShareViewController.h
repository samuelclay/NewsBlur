//
//  ShareViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/21/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@interface ShareViewController : UIViewController <ASIHTTPRequestDelegate, UITextViewDelegate> {
    NewsBlurAppDelegate *appDelegate;
    NSString *activeReplyId;
}

@property (nonatomic) IBOutlet UITextView *commentField;
@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIButton *facebookButton;
@property (nonatomic) IBOutlet UIButton *twitterButton;
@property (nonatomic) IBOutlet UIBarButtonItem *submitButton;
@property (nonatomic) IBOutlet UIBarButtonItem *toolbarTitle;
@property (nonatomic) NSString * activeReplyId;

- (void)setSiteInfo:(NSString *)type setUserId:(NSString *)userId setUsername:(NSString *)username setReplyId:(NSString *)commentIndex;
- (void)clearComments;
- (IBAction)doCancelButton:(id)sender;
- (IBAction)doToggleButton:(id)sender;
- (IBAction)doShareThisStory:(id)sender;
- (IBAction)doReplyToComment:(id)sender;
- (void)finishShareThisStory:(ASIHTTPRequest *)request;
- (void)finishAddReply:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)replaceStory:(NSDictionary *)newStory withReplyId:(NSString *)replyId;
- (NSString *)stringByStrippingHTML:(NSString *)s;

@end
