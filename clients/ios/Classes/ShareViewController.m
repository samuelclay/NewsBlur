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

@synthesize commentField;
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
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(onTextChange:)
     name:UITextViewTextDidChangeNotification
     object:self.commentField];

    // Hide the navigation bar items — we use inline controls instead
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;

    // Comment field styling
    commentField.layer.borderWidth = 1.0f;
    commentField.layer.cornerRadius = 6;
    commentField.font = [UIFont systemFontOfSize:14];

    // Create header label
    UILabel *header = [[UILabel alloc] init];
    header.text = @"Share this story";
    header.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    header.textAlignment = NSTextAlignmentLeft;
    self.headerLabel = header;
    [self.view addSubview:header];

    // Create inline submit button (UIButtonTypeCustom to avoid system tint/double border)
    UIButton *inlineBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [inlineBtn setTitle:@"Share" forState:UIControlStateNormal];
    inlineBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [inlineBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [inlineBtn setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.4] forState:UIControlStateDisabled];
    // Use direct color to avoid theme matrix transformation
    inlineBtn.backgroundColor = [UIColor colorWithRed:0.439 green:0.620 blue:0.365 alpha:1.0]; // #709E5D
    inlineBtn.layer.cornerRadius = 6;
    inlineBtn.contentEdgeInsets = UIEdgeInsetsMake(10, 20, 10, 20);
    [inlineBtn addTarget:self action:@selector(doShareThisStory:) forControlEvents:UIControlEventTouchUpInside];
    self.inlineSubmitButton = inlineBtn;
    [self.view addSubview:inlineBtn];

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
    CGSize kbSize = CGSizeMake(keyboardWidth, keyboardHeight);

    self.lastKeyboardSize = kbSize;
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
    CGSize kbSize = CGSizeMake(keyboardWidth, keyboardHeight);

    self.lastKeyboardSize = kbSize;
    [UIView animateWithDuration:0.2f animations:^{
        [self adjustCommentField:kbSize];
    }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Re-layout when the popover resizes our view (e.g. first presentation).
    // Guard against infinite recursion: sizeToFit -> layout -> viewDidLayoutSubviews.
    CGSize currentSize = self.view.bounds.size;
    if (!CGSizeEqualToSize(currentSize, _lastLayoutSize)) {
        _lastLayoutSize = currentSize;
        [self adjustCommentField:self.lastKeyboardSize];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Hide navigation bar for compact popover look
    self.navigationController.navigationBarHidden = YES;

    [self adjustCommentField:CGSizeZero];

    self.view.backgroundColor = UIColorFromLightSepiaMediumDarkRGB(0xEAECE6, 0xF3E2CB, 0x3D3D3D, 0x1A1A1A);
    self.commentField.layer.borderColor = [UIColorFromLightSepiaMediumDarkRGB(0xD0D2CC, 0xD4C8B8, 0x5A5A5A, 0x404040) CGColor];
    self.commentField.backgroundColor = UIColorFromLightSepiaMediumDarkRGB(0xF8F9F6, 0xFAF5ED, 0x3A3A3A, 0x222222);
    self.commentField.textColor = UIColorFromLightSepiaMediumDarkRGB(0x5E6267, 0x5C4A3D, 0xE0E0E0, 0xE8E8E8);
    self.commentField.tintColor = UIColorFromLightSepiaMediumDarkRGB(0x5E6267, 0x5C4A3D, 0xE0E0E0, 0xE8E8E8);
    self.headerLabel.textColor = UIColorFromLightSepiaMediumDarkRGB(0x5E6267, 0x5C4A3D, 0xC0C0C0, 0xD0D0D0);
    self.storyTitle.textColor = UIColorFromLightSepiaMediumDarkRGB(0x404040, 0x5C4A3D, 0xA0A0A0, 0xB0B0B0);
    self.storyTitle.shadowColor = nil;

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

- (void)adjustCommentField:(CGSize)kbSize {
    CGSize v = self.view.frame.size;
    int k = kbSize.height;
    int margin = 12;
    int headerHeight = 20;
    int btnHeight = 38;
    int btnPadding = 10;
    int topPadding = 12;
    int stOffset = 0;
    int stHeight = 0;

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.storyTitle.frame = CGRectMake(20, 8, v.width - 20*2, 24);
        stOffset = self.storyTitle.frame.origin.y + self.storyTitle.frame.size.height;
        stHeight = self.storyTitle.frame.size.height;
    } else if (!self.isPhone) {
        k = 0;
    }

    // Header label at top
    self.headerLabel.frame = CGRectMake(margin, topPadding + stOffset, v.width - margin*2, headerHeight);

    // Comment field below header
    CGFloat fieldTop = CGRectGetMaxY(self.headerLabel.frame) + 8;
    CGFloat fieldHeight = v.height - k - fieldTop - btnHeight - btnPadding*2 - stHeight;
    if (fieldHeight < 40) fieldHeight = 40;
    self.commentField.frame = CGRectMake(margin, fieldTop, v.width - margin*2, fieldHeight);

    // Position inline submit button below the comment field, right-aligned
    [self.inlineSubmitButton sizeToFit];
    CGFloat btnWidth = self.inlineSubmitButton.frame.size.width;
    if (btnWidth < 100) btnWidth = 100;
    self.inlineSubmitButton.frame = CGRectMake(v.width - margin - btnWidth,
                                               CGRectGetMaxY(self.commentField.frame) + btnPadding,
                                               btnWidth,
                                               btnHeight);

    [self onTextChange:nil];
}

- (IBAction)doCancelButton:(id)sender {
    [appDelegate hideShareView:NO];
}

- (void)setCommentType:(NSString *)type {
    self.currentType = type;
}

- (void)setSiteInfo:(NSString *)type
          setUserId:(NSString *)userId
        setUsername:(NSString *)username
         setReplyId:(NSString *)replyId {
    if ([type isEqualToString: @"edit-reply"]) {
        self.headerLabel.text = @"Edit your reply";
        [self.inlineSubmitButton setTitle:@"Save reply" forState:UIControlStateNormal];
        [self.inlineSubmitButton removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
        [self.inlineSubmitButton addTarget:self action:@selector(doReplyToComment:) forControlEvents:UIControlEventTouchUpInside];
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
        self.headerLabel.text = [NSString stringWithFormat:@"Reply to %@", username];
        [self.inlineSubmitButton setTitle:[NSString stringWithFormat:@"Reply to %@", username] forState:UIControlStateNormal];
        [self.inlineSubmitButton removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
        [self.inlineSubmitButton addTarget:self action:@selector(doReplyToComment:) forControlEvents:UIControlEventTouchUpInside];

        if (!self.activeCommentId || ![self.activeCommentId isEqualToString:userId] ||
            !self.activeStoryId || ![self.activeStoryId isEqualToString:[appDelegate.activeStory objectForKey:@"story_hash"]]) {
            self.activeCommentId = userId;
            self.activeStoryId = [appDelegate.activeStory objectForKey:@"story_hash"];
            self.commentField.text = @"";
        }
    } else if ([type isEqualToString: @"edit-share"]) {
        self.headerLabel.text = @"Edit your comment";
        // get old comment
        self.commentField.text = [self stringByStrippingHTML:[appDelegate.activeComment objectForKey:@"comments"]];

        [self.inlineSubmitButton removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
        [self.inlineSubmitButton addTarget:self action:@selector(doShareThisStory:) forControlEvents:UIControlEventTouchUpInside];
    } else if ([type isEqualToString: @"share"]) {
        self.headerLabel.text = @"Share this story";
        [self.inlineSubmitButton removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
        [self.inlineSubmitButton addTarget:self action:@selector(doShareThisStory:) forControlEvents:UIControlEventTouchUpInside];
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
}

# pragma mark
# pragma mark Share Story

- (IBAction)doShareThisStory:(id)sender {
    [appDelegate.storyPagesViewController showShareHUD:@"Sharing"];
    NSString *urlString = [NSString stringWithFormat:@"%@/social/share_story",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];

    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    NSString *storyIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"id"]];

    [params setObject:feedIdStr forKey:@"feed_id"];
    [params setObject:storyIdStr forKey:@"story_id"];
    [params setObject:@[] forKey:@"post_to_services"];

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
            [self.inlineSubmitButton setTitle:@"Share with comment" forState:UIControlStateNormal];
        } else {
            [self.inlineSubmitButton setTitle:@"Share" forState:UIControlStateNormal];
        }
        self.inlineSubmitButton.enabled = YES;
    } else if ([self.currentType isEqualToString: @"reply"] ||
               [self.currentType isEqualToString:@"edit-reply"]) {
        self.inlineSubmitButton.enabled = [self.commentField.text length] > 0;
    }

    // Resize button for new title text
    [self.inlineSubmitButton sizeToFit];
    CGFloat margin = 12;
    CGFloat btnWidth = self.inlineSubmitButton.frame.size.width + 40; // add back content insets
    if (btnWidth < 100) btnWidth = 100;
    CGFloat v = self.view.frame.size.width;
    CGRect f = self.inlineSubmitButton.frame;
    self.inlineSubmitButton.frame = CGRectMake(v - margin - btnWidth, f.origin.y, btnWidth, f.size.height);
}
@end
