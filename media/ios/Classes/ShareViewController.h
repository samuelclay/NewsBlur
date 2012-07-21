//
//  ShareViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/21/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@interface ShareViewController : UIViewController <ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;
    int activeCommentIndex;
}

@property ( nonatomic) IBOutlet UITextView *commentField;
@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property ( nonatomic) IBOutlet UIButton *facebookButton;
@property ( nonatomic) IBOutlet UIButton *twitterButton;
@property ( nonatomic) IBOutlet UIBarButtonItem *submitButton;
@property ( nonatomic) IBOutlet UIBarButtonItem *toolbarTitle;
@property (nonatomic) int activeCommentIndex;

- (void)setSiteInfo:(NSString *)type setUserId:(NSString *)userId setUsername:(NSString *)username setCommentIndex:(NSString *)commentIndex;
- (void)clearComments;
- (IBAction)doCancelButton:(id)sender;
- (IBAction)doToggleButton:(id)sender;
- (IBAction)doShareThisStory:(id)sender;
- (IBAction)doReplyToComment:(id)sender;
- (void)finishAddComment:(ASIHTTPRequest *)request;
- (void)finishAddReply:(ASIHTTPRequest *)request;
- (void)replaceStory:(NSDictionary *)newStory;

@end
