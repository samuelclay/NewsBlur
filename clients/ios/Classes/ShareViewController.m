//
//  ShareViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/21/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "ShareViewController.h"
#import "NewsBlurAppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import "Utilities.h"
#import "DataUtilities.h"
#import "StoriesCollection.h"
#import "NSString+HTML.h"
#import "NewsBlur-Swift.h"

@implementation ShareViewController

@synthesize facebookButton;
@synthesize twitterButton;
@synthesize submitButton;
@synthesize commentField;
@synthesize appDelegate;
@synthesize activeReplyId;
@synthesize activeCommentId;
@synthesize activeStoryId;
@synthesize currentType;
@synthesize storyTitle;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {

    }

    return self;
}

- (void)viewDidLoad {
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(onTextChange:)
     name:UITextViewTextDidChangeNotification 
     object:self.commentField];
    
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc]
                               initWithTitle:@"Cancel"
                               style:UIBarButtonItemStylePlain
                               target:self
                               action:@selector(doCancelButton:)];
    self.navigationItem.leftBarButtonItem = cancel;
    
    UIBarButtonItem *submit = [[UIBarButtonItem alloc]
                               initWithTitle:@"Post"
                               style:UIBarButtonItemStyleDone
                               target:self
                               action:@selector(doShareThisStory:)];
    self.submitButton = submit;
    self.navigationItem.rightBarButtonItem = submit;
    
    // Do any additional setup after loading the view from its nib.
    commentField.layer.borderWidth = 1.0f;
    commentField.layer.cornerRadius = 4;
    commentField.layer.borderColor = [UIColorFromRGB(0x808080) CGColor];
    
    twitterButton.layer.borderWidth = 1.0f;
    twitterButton.layer.cornerRadius = 1.0f;
    facebookButton.layer.borderWidth = 1.0f;
    facebookButton.layer.cornerRadius = 1.0f;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];

    [super viewDidLoad];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (bool)isHardwareKeyboardUsed:(NSNotification*)keyboardNotification {
    NSDictionary* info = [keyboardNotification userInfo];
    CGRect keyboardEndFrame;
    [[info valueForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardEndFrame];
    float height = [[UIScreen mainScreen] bounds].size.height - keyboardEndFrame.origin.y;
    float gThresholdForHardwareKeyboardToolbar = 160.f;
    return height < gThresholdForHardwareKeyboardToolbar;
}

- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    
    // Get the size of the keyboard.
    NSValue* keyboardFrameValue     = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect keyboardRectWrtScreen    = [keyboardFrameValue CGRectValue];
    
    CGFloat keyboardWidth = keyboardRectWrtScreen.size.width;
    CGFloat keyboardHeight = [[[self view] window] frame].size.height - keyboardRectWrtScreen.origin.y;
    NSLog(@"Keyboard height: %f %d", keyboardHeight, [self isHardwareKeyboardUsed:aNotification]);
    CGSize kbSize = CGSizeMake(keyboardWidth, keyboardHeight);
    
    [UIView animateWithDuration:0.2f animations:^{
        [self adjustCommentField:kbSize];
    }];
}


- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    
    // Get the size of the keyboard.
    NSValue* keyboardFrameValue     = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect keyboardRectWrtScreen    = [keyboardFrameValue CGRectValue];
    
    CGFloat keyboardWidth = keyboardRectWrtScreen.size.width;
    CGFloat keyboardHeight = [[[self view] window] frame].size.height - keyboardRectWrtScreen.origin.y;
    NSLog(@"Keyboard height on hide: %f %d", keyboardHeight, [self isHardwareKeyboardUsed:aNotification]);
    CGSize kbSize = CGSizeMake(keyboardWidth, keyboardHeight);

    [UIView animateWithDuration:0.2f animations:^{
        [self adjustCommentField:kbSize];
    }];
}

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//	return YES;
//}
//
//- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
//    [self adjustCommentField:CGSizeZero];
//}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self adjustCommentField:CGSizeZero];
    [self adjustShareButtons];
    
    self.view.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    self.commentField.layer.borderColor = [UIColorFromRGB(0x808080) CGColor];
    self.commentField.backgroundColor = UIColorFromRGB(0xDCDFD6);
    self.commentField.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    self.commentField.tintColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    self.storyTitle.textColor = UIColorFromRGB(0x404040);
    self.storyTitle.shadowColor = UIColorFromRGB(0xF0F0F0);
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.storyTitle.text = [[appDelegate.activeStory objectForKey:@"story_title"]
                                stringByDecodingHTMLEntities];
        [self.commentField becomeFirstResponder];
        
        NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                               [appDelegate.activeStory objectForKey:@"story_feed_id"]];
        UIImage *titleImage  = [appDelegate getFavicon:feedIdStr];
        UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
        UIImageView *titleImageViewWrapper = [[UIImageView alloc] init];
        titleImageView.frame = CGRectMake(0.0, 2.0, 16.0, 16.0);
        titleImageView.hidden = YES;
        titleImageView.contentMode = UIViewContentModeScaleAspectFit;
        [titleImageViewWrapper addSubview:titleImageView];
        [titleImageViewWrapper setFrame:titleImageView.frame];
        self.navigationItem.titleView = titleImageViewWrapper;
        titleImageView.hidden = NO;
    }
}

- (void)adjustShareButtons {
    if (twitterButton.selected &&
        [[[appDelegate.dictSocialServices objectForKey:@"twitter"]
          objectForKey:@"twitter_uid"] class] == [NSNull class]) {
        [self doToggleButton:twitterButton];
    } else {
        twitterButton.selected = NO;
        twitterButton.layer.borderColor = [UIColorFromRGB(0xD9DBD6) CGColor];
    }
    
    if (facebookButton.selected &&
        [[[appDelegate.dictSocialServices objectForKey:@"facebook"]
          objectForKey:@"facebook_uid"] class] == [NSNull class]) {
        [self doToggleButton:facebookButton];
    } else {
        facebookButton.selected = NO;
        facebookButton.layer.borderColor = [UIColorFromRGB(0xD9DBD6) CGColor];
    }
}

- (void)adjustCommentField:(CGSize)kbSize {
    CGSize v = self.view.frame.size;
    int bP = 8;
    int bW = 32;
    int bH = 24;
    int k = kbSize.height;
    int stOffset = 6;
    int stHeight = 0;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.storyTitle.frame = CGRectMake(20, 8, v.width - 20*2, 24);
        stOffset = self.storyTitle.frame.origin.y + self.storyTitle.frame.size.height;
        stHeight = self.storyTitle.frame.size.height;
    } else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        k = 0;
    }
    NSLog(@"Share type: %@", self.currentType);
    BOOL showingShareButtons = [self.currentType isEqualToString:@"share"] ||
                               [self.currentType isEqualToString:@"edit-share"];
    self.commentField.frame = CGRectMake(20, stOffset + 4,
                                         v.width - 20*2,
                                         v.height - k - (showingShareButtons ? bH + bP*2 : 6) - 12 - stHeight);
    CGPoint o = self.commentField.frame.origin;
    CGSize c = self.commentField.frame.size;
    self.twitterButton.frame   = CGRectMake(v.width - 20 - bW*2 - bP*2, o.y + c.height + bP, bW, bH);
    self.facebookButton.frame  = CGRectMake(v.width - 20 - bW*1 - bP*1, o.y + c.height + bP, bW, bH);
    
    [self onTextChange:nil];
}

- (IBAction)doCancelButton:(id)sender {
    [appDelegate hideShareView:NO];
}

- (IBAction)doToggleButton:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.selected = !button.selected;
    int selected = button.selected ? 1 : 0;
    
    if (button.tag == 1) { // Twitter
        if (selected) {
            [self checkService:@"twitter"];
            button.layer.borderColor = [UIColorFromRGB(0x4E8ECD) CGColor];
        } else {
            button.layer.borderColor = [UIColorFromRGB(0xD9DBD6) CGColor];
        }
    } else if (button.tag == 2) { // Facebook
        if (selected) {
            [self checkService:@"facebook"];
            button.layer.borderColor = [UIColorFromRGB(0x6884CD) CGColor];
        } else {
            button.layer.borderColor = [UIColorFromRGB(0xD9DBD6) CGColor];
        }
    }
}

- (void)checkService:(NSString *)service {
    if ([service isEqualToString:@"twitter"] &&
        [[[appDelegate.dictSocialServices objectForKey:@"twitter"]
          objectForKey:@"twitter_uid"] class] == [NSNull class]) {
        [appDelegate showConnectToService:service];
    } else if ([service isEqualToString:@"facebook"] &&
              [[[appDelegate.dictSocialServices objectForKey:@"facebook"]
                objectForKey:@"facebook_uid"] class] == [NSNull class]) {
        [appDelegate showConnectToService:service];
    }
}

- (void)setCommentType:(NSString *)type {
    self.currentType = type;
}

- (void)setSiteInfo:(NSString *)type
          setUserId:(NSString *)userId
        setUsername:(NSString *)username
         setReplyId:(NSString *)replyId {
    NSLog(@"SetSiteInfo: %@", type);
    [self.submitButton setStyle:UIBarButtonItemStyleDone];
    if ([type isEqualToString: @"edit-reply"]) {
        [submitButton setTitle:@"Save your reply"];
        facebookButton.hidden = YES;
        twitterButton.hidden = YES;
        [submitButton setAction:(@selector(doReplyToComment:))];
        self.activeReplyId = replyId;
        
        // get existing reply
        NSArray *replies = [appDelegate.activeComment objectForKey:@"replies"];
        NSDictionary *reply = nil;
        for (int i = 0; i < replies.count; i++) {
            NSString *replyId = [NSString stringWithFormat:@"%@",
                                 [[replies objectAtIndex:i] valueForKey:@"reply_id"]];
            if ([replyId isEqualToString:self.activeReplyId]) {
                reply = [replies objectAtIndex:i];
            }
        }
        if (reply) {
            self.commentField.text = [self stringByStrippingHTML:[reply objectForKey:@"comments"]]; 
        }
    } else if ([type isEqualToString: @"reply"]) {
        self.activeReplyId = nil;
        [submitButton setTitle:[NSString stringWithFormat:@"Reply to %@", username]];
        facebookButton.hidden = YES;
        twitterButton.hidden = YES;
        [submitButton setAction:(@selector(doReplyToComment:))];
        
        // Don't bother to reset comment field for replies while on the same story.
        // It'll get cleared out on a new story and when posting a reply.
        if (!self.activeCommentId || ![self.activeCommentId isEqualToString:userId] ||
            !self.activeStoryId || ![self.activeStoryId isEqualToString:[appDelegate.activeStory objectForKey:@"story_hash"]]) {
            self.activeCommentId = userId;
            self.activeStoryId = [appDelegate.activeStory objectForKey:@"story_hash"];
            self.commentField.text = @"";
        }
    } else if ([type isEqualToString: @"edit-share"]) {
        facebookButton.hidden = NO;
        twitterButton.hidden = NO;
        
        // get old comment
        self.commentField.text = [self stringByStrippingHTML:[appDelegate.activeComment objectForKey:@"comments"]];
        
        [submitButton setTitle:@"Share with comments"];
        [submitButton setAction:(@selector(doShareThisStory:))];
    } else if ([type isEqualToString: @"share"]) {        
        facebookButton.hidden = NO;
        twitterButton.hidden = NO;
        [submitButton setTitle:@"Share this story"];
        [submitButton setAction:(@selector(doShareThisStory:))];
        if (![self.currentType isEqualToString:@"share"] &&
            ![self.currentType isEqualToString:@"reply"]) {
            self.commentField.text = @"";
        }
    }
    
    [self onTextChange:nil];
}

- (void)clearComments {
    self.commentField.text = nil;
    self.currentType = nil;
    self.twitterButton.selected = NO;
    self.facebookButton.selected = NO;
}

# pragma mark
# pragma mark Share Story

- (IBAction)doShareThisStory:(id)sender {
    [appDelegate.storyPagesViewController showShareHUD:@"Sharing"];
    NSString *urlString = [NSString stringWithFormat:@"%@/social/share_story",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSMutableArray *services = [NSMutableArray array];
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    NSString *storyIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"id"]];

    [params setObject:feedIdStr forKey:@"feed_id"]; 
    [params setObject:storyIdStr forKey:@"story_id"];
    
    if (facebookButton.selected) {
        [services addObject:@"facebook"];
    }
    if (twitterButton.selected) {
        [services addObject:@"twitter"];
    }
    [params setObject:services forKey:@"post_to_services"];
    
    if (appDelegate.storiesCollection.isSocialRiverView) {
        if ([[appDelegate.activeStory objectForKey:@"friend_user_ids"] count] > 0) {
            [params setObject:[NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"friend_user_ids"][0]] forKey:@"source_user_id"];
        } else if ([[appDelegate.activeStory objectForKey:@"public_user_ids"] count] > 0) {
            [params setObject:[NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"public_user_ids"][0]] forKey:@"source_user_id"];
        }
    } else {
        if ([appDelegate.activeStory objectForKey:@"social_user_id"] != nil) {
            NSString *sourceUserIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"social_user_id"]];
            [params setObject:sourceUserIdStr forKey:@"source_user_id"]; 
        }
    }

    
    NSString *comments = commentField.text;
    if ([comments length]) {
        [params setObject:comments forKey:@"comments"]; 
    }
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishShareThisStory:responseObject];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        [self requestFailed:error statusCode:httpResponse.statusCode];
    }];

    [appDelegate hideShareView:YES];
}

- (void)finishShareThisStory:(NSDictionary *)results {
    NSArray *userProfiles = [results objectForKey:@"user_profiles"];
    appDelegate.storiesCollection.activeFeedUserProfiles = [DataUtilities
                                                            updateUserProfiles:appDelegate.storiesCollection.activeFeedUserProfiles
                                                            withNewUserProfiles:userProfiles];
    [self replaceStory:[results objectForKey:@"story"] withReplyId:nil];
    [appDelegate.feedDetailViewController redrawUnreadStory];

    [MBProgressHUD hideHUDForView:appDelegate.storyPagesViewController.view animated:NO];
    [MBProgressHUD hideHUDForView:appDelegate.storyPagesViewController.currentPage.view animated:NO];
}

# pragma mark
# pragma mark Reply to Story

- (IBAction)doReplyToComment:(id)sender {
    [appDelegate.storyPagesViewController showShareHUD:@"Replying"];
    NSString *comments = commentField.text;
    if ([comments length] == 0) {
        return;
    }
    
//    NSLog(@"REPLY TO COMMENT, %@", appDelegate.activeComment);
    NSString *urlString = [NSString stringWithFormat:@"%@/social/save_comment_reply",
                           self.appDelegate.url];
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    NSString *storyIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"id"]];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:feedIdStr forKey:@"story_feed_id"]; 
    [params setObject:storyIdStr forKey:@"story_id"];
    [params setObject:[appDelegate.activeComment objectForKey:@"user_id"] forKey:@"comment_user_id"];
    [params setObject:commentField.text forKey:@"reply_comments"]; 
    
    if (self.activeReplyId) {
        [params setObject:activeReplyId forKey:@"reply_id"]; 
    }
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishAddReply:responseObject];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        [self requestFailed:error statusCode:httpResponse.statusCode];
    }];

    [appDelegate hideShareView:NO];
}

- (void)finishAddReply:(NSDictionary *)results {
    NSLog(@"Successfully added.");

    // add the comment into the activeStory dictionary
    NSDictionary *newStory = [DataUtilities updateComment:results for:appDelegate];
    [self replaceStory:newStory withReplyId:[results objectForKey:@"reply_id"]];
}

- (void)requestFailed:(NSError *)error statusCode:(NSInteger)statusCode {
    [MBProgressHUD hideHUDForView:appDelegate.storyPagesViewController.view animated:NO];
    [MBProgressHUD hideHUDForView:appDelegate.storyPagesViewController.currentPage.view animated:NO];

    NSLog(@"Error: %@", error);
    [appDelegate.storyPagesViewController.currentPage informError:error statusCode:statusCode];
}

- (void)replaceStory:(NSDictionary *)newStory withReplyId:(NSString *)replyId {
    NSMutableDictionary *newStoryParsed = [newStory mutableCopy];
    [newStoryParsed setValue:[NSNumber numberWithInt:1] forKey:@"read_status"];

    // update the current story and the activeFeedStories
    appDelegate.activeStory = newStoryParsed;
    [appDelegate.storyPagesViewController.currentPage setActiveStoryAtIndex:-1];

    NSMutableArray *newActiveFeedStories = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < appDelegate.storiesCollection.activeFeedStories.count; i++)  {
        NSDictionary *feedStory = [appDelegate.storiesCollection.activeFeedStories objectAtIndex:i];
        NSString *storyId = [NSString stringWithFormat:@"%@", [feedStory objectForKey:@"id"]];
        NSString *currentStoryId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"id"]];
        if ([storyId isEqualToString: currentStoryId]){
            [newActiveFeedStories addObject:newStoryParsed];
        } else {
            [newActiveFeedStories addObject:[appDelegate.storiesCollection.activeFeedStories objectAtIndex:i]];
        }
    }
    
    appDelegate.storiesCollection.activeFeedStories = [NSArray arrayWithArray:newActiveFeedStories];
    
    self.commentField.text = nil;
    [appDelegate.storyPagesViewController.currentPage refreshComments:replyId];
    [appDelegate changeActiveFeedDetailRow];
}


- (NSString *)stringByStrippingHTML:(NSString *)s {
    NSRange r;
    while ((r = [s rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
        s = [s stringByReplacingCharactersInRange:r withString:@""];
    return s; 
}

-(void)onTextChange:(NSNotification*)notification {
    NSString *text = self.commentField.text;
    if ([self.currentType isEqualToString: @"share"] ||
        [self.currentType isEqualToString:@"edit-share"]) {
        if (text.length) {
            self.submitButton.title = @"Share with comments";
        } else {
            self.submitButton.title = @"Share this story";
        }
        self.submitButton.enabled = YES;
    } else if ([self.currentType isEqualToString: @"reply"] ||
               [self.currentType isEqualToString:@"edit-reply"]) {
        self.submitButton.enabled = [self.commentField.text length] > 0;
    }
    

}
@end
