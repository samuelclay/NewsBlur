//
//  ShareViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/21/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "ShareViewController.h"
#import "NewsBlurAppDelegate.h"
#import "StoryDetailViewController.h"
#import "FeedDetailViewController.h"
#import "StoryPageControl.h"
#import <QuartzCore/QuartzCore.h>
#import "Utilities.h"
#import "DataUtilities.h"
#import "ASIHTTPRequest.h"
#import "StoriesCollection.h"
#import "NSString+HTML.h"

@implementation ShareViewController

@synthesize facebookButton;
@synthesize twitterButton;
@synthesize appdotnetButton;
@synthesize submitButton;
@synthesize commentField;
@synthesize appDelegate;
@synthesize activeReplyId;
@synthesize activeCommentId;
@synthesize activeStoryId;
@synthesize currentType;
@synthesize storyTitle;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate]; 
    
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(onTextChange:)
     name:UITextViewTextDidChangeNotification 
     object:self.commentField];
    
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc]
                               initWithTitle:@"Cancel"
                               style:UIBarButtonSystemItemCancel
                               target:self
                               action:@selector(doCancelButton:)];
    self.navigationItem.leftBarButtonItem = cancel;
    
    UIBarButtonItem *submit = [[UIBarButtonItem alloc]
                               initWithTitle:@"Post"
                               style:UIBarButtonSystemItemDone
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
    appdotnetButton.layer.borderWidth = 1.0f;
    appdotnetButton.layer.cornerRadius = 1.0f;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];

    [super viewDidLoad];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidUnload {
    [self setCommentField:nil];
    [self setFacebookButton:nil];
    [self setTwitterButton:nil];
    [self setSubmitButton:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
        
    [UIView animateWithDuration:0.2f animations:^{
        [self adjustCommentField:kbSize];
    }];
}


- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    
    [UIView animateWithDuration:0.2f animations:^{
        [self adjustCommentField:kbSize];
    }];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self adjustCommentField:CGSizeZero];
}

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
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.storyTitle.text = [[appDelegate.activeStory objectForKey:@"story_title"]
                                stringByDecodingHTMLEntities];
        [self.commentField becomeFirstResponder];
        
        NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                               [appDelegate.activeStory objectForKey:@"story_feed_id"]];
        UIImage *titleImage  = [appDelegate getFavicon:feedIdStr];
        UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
        titleImageView.frame = CGRectMake(0.0, 2.0, 16.0, 16.0);
        titleImageView.hidden = YES;
        titleImageView.contentMode = UIViewContentModeScaleAspectFit;
        self.navigationItem.titleView = titleImageView;
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
    
    if (appdotnetButton.selected &&
        [[[appDelegate.dictSocialServices objectForKey:@"appdotnet"]
          objectForKey:@"appdotnet_uid"] class] == [NSNull class]) {
        [self doToggleButton:appdotnetButton];
    } else {
        appdotnetButton.selected = NO;
        appdotnetButton.layer.borderColor = [UIColorFromRGB(0xD9DBD6) CGColor];
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
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.storyTitle.frame = CGRectMake(20, 8, v.width - 20*2, 24);
        stOffset = self.storyTitle.frame.origin.y + self.storyTitle.frame.size.height;
        stHeight = self.storyTitle.frame.size.height;
    } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
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
    self.twitterButton.frame   = CGRectMake(v.width - 20 - bW*3 - bP*2, o.y + c.height + bP, bW, bH);
    self.facebookButton.frame  = CGRectMake(v.width - 20 - bW*2 - bP*1, o.y + c.height + bP, bW, bH);
    self.appdotnetButton.frame = CGRectMake(v.width - 20 - bW*1 - bP*0, o.y + c.height + bP, bW, bH);
    
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
    } else if (button.tag == 3) { // App.net
        if (selected) {
            [self checkService:@"appdotnet"];
            button.layer.borderColor = [UIColorFromRGB(0xD16857) CGColor];
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
    } else if ([service isEqualToString:@"appdotnet"] &&
              [[[appDelegate.dictSocialServices objectForKey:@"appdotnet"]
                objectForKey:@"appdotnet_uid"] class] == [NSNull class]) {
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
        appdotnetButton.hidden = YES;
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
        appdotnetButton.hidden = YES;
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
        appdotnetButton.hidden = NO;
        
        // get old comment
        self.commentField.text = [self stringByStrippingHTML:[appDelegate.activeComment objectForKey:@"comments"]];
        
        [submitButton setTitle:@"Share with comments"];
        [submitButton setAction:(@selector(doShareThisStory:))];
    } else if ([type isEqualToString: @"share"]) {        
        facebookButton.hidden = NO;
        twitterButton.hidden = NO;
        appdotnetButton.hidden = NO;
        [submitButton setTitle:@"Share this story"];
        [submitButton setAction:(@selector(doShareThisStory:))];
        if (![self.currentType isEqualToString:@"share"] &&
            ![self.currentType isEqualToString:@"reply"]) {
            self.commentField.text = @"";
        }
    }
}

- (void)clearComments {
    self.commentField.text = nil;
    self.currentType = nil;
    self.twitterButton.selected = NO;
    self.facebookButton.selected = NO;
    self.appdotnetButton.selected = NO;
}

# pragma mark
# pragma mark Share Story

- (IBAction)doShareThisStory:(id)sender {
    [appDelegate.storyPageControl showShareHUD:@"Sharing"];
    NSString *urlString = [NSString stringWithFormat:@"%@/social/share_story",
                           self.appDelegate.url];

    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    NSString *storyIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"id"]];

    [request setPostValue:feedIdStr forKey:@"feed_id"]; 
    [request setPostValue:storyIdStr forKey:@"story_id"];
    
    if (facebookButton.selected) {
        [request addPostValue:@"facebook" forKey:@"post_to_services"];     
    }
    if (twitterButton.selected) {
        [request addPostValue:@"twitter" forKey:@"post_to_services"];
    }
    if (appdotnetButton.selected) {
        [request addPostValue:@"appdotnet" forKey:@"post_to_services"];
    }
    
    if (appDelegate.storiesCollection.isSocialRiverView) {
        if ([[appDelegate.activeStory objectForKey:@"friend_user_ids"] count] > 0) {
            [request setPostValue:[NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"friend_user_ids"][0]] forKey:@"source_user_id"];
        } else if ([[appDelegate.activeStory objectForKey:@"public_user_ids"] count] > 0) {
            [request setPostValue:[NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"public_user_ids"][0]] forKey:@"source_user_id"];
        }
    } else {
        if ([appDelegate.activeStory objectForKey:@"social_user_id"] != nil) {
            NSString *sourceUserIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"social_user_id"]];
            [request setPostValue:sourceUserIdStr forKey:@"source_user_id"]; 
        }
    }

    
    NSString *comments = commentField.text;
    if ([comments length]) {
        [request setPostValue:comments forKey:@"comments"]; 
    }
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishShareThisStory:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
    [appDelegate hideShareView:YES];
}

- (void)finishShareThisStory:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    if (request.responseStatusCode != 200) {
        return [self requestFailed:request];
    }
    
    NSArray *userProfiles = [results objectForKey:@"user_profiles"];
    appDelegate.storiesCollection.activeFeedUserProfiles = [DataUtilities
                                                            updateUserProfiles:appDelegate.storiesCollection.activeFeedUserProfiles
                                                            withNewUserProfiles:userProfiles];
    [self replaceStory:[results objectForKey:@"story"] withReplyId:nil];
    [appDelegate.feedDetailViewController redrawUnreadStory];
}

# pragma mark
# pragma mark Reply to Story

- (IBAction)doReplyToComment:(id)sender {
    [appDelegate.storyPageControl showShareHUD:@"Replying"];
    NSString *comments = commentField.text;
    if ([comments length] == 0) {
        return;
    }
    
//    NSLog(@"REPLY TO COMMENT, %@", appDelegate.activeComment);
    NSString *urlString = [NSString stringWithFormat:@"%@/social/save_comment_reply",
                           self.appDelegate.url];
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    NSString *storyIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"id"]];
    
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:feedIdStr forKey:@"story_feed_id"]; 
    [request setPostValue:storyIdStr forKey:@"story_id"];
    [request setPostValue:[appDelegate.activeComment objectForKey:@"user_id"] forKey:@"comment_user_id"];
    [request setPostValue:commentField.text forKey:@"reply_comments"]; 
    
    if (self.activeReplyId) {
        [request setPostValue:activeReplyId forKey:@"reply_id"]; 
    }
    
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishAddReply:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
    [appDelegate hideShareView:NO];
}

- (void)finishAddReply:(ASIHTTPRequest *)request {
    NSLog(@"Successfully added.");
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];

    if (request.responseStatusCode != 200) {
        return [self requestFailed:request];
    }
    
    // add the comment into the activeStory dictionary
    NSDictionary *newStory = [DataUtilities updateComment:results for:appDelegate];
    [self replaceStory:newStory withReplyId:[results objectForKey:@"reply_id"]];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSString *error;
    
    [MBProgressHUD hideHUDForView:appDelegate.storyPageControl.view animated:NO];
    
    if ([request error]) {
        error = [NSString stringWithFormat:@"%@", [request error]];
    } else {
        error = @"The server barfed!";
    }
    NSLog(@"Error: %@", error);
    [appDelegate.storyPageControl.currentPage informError:error];
}

- (void)replaceStory:(NSDictionary *)newStory withReplyId:(NSString *)replyId {
    NSMutableDictionary *newStoryParsed = [newStory mutableCopy];
    [newStoryParsed setValue:[NSNumber numberWithInt:1] forKey:@"read_status"];

    // update the current story and the activeFeedStories
    appDelegate.activeStory = newStoryParsed;
    [appDelegate.storyPageControl.currentPage setActiveStoryAtIndex:-1];

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
    [appDelegate.storyPageControl.currentPage refreshComments:replyId];
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
    } else if ([self.currentType isEqualToString: @"reply"] ||
               [self.currentType isEqualToString:@"edit-reply"]) {
        self.submitButton.enabled = [self.commentField.text length] > 0;
    }
    

}
@end
