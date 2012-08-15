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
#import <QuartzCore/QuartzCore.h>
#import "Utilities.h"
#import "DataUtilities.h"
#import "ASIHTTPRequest.h"

@implementation ShareViewController

@synthesize facebookButton;
@synthesize twitterButton;
@synthesize submitButton;
@synthesize commentField;
@synthesize appDelegate;
@synthesize activeReplyId;
@synthesize currentType;


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
    
    // For textField1
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(onTextChange:)
     name:UITextViewTextDidChangeNotification 
     object:self.commentField];
    
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonSystemItemCancel target:self action:@selector(doCancelButton:)];
    self.navigationItem.leftBarButtonItem = cancel;
    
    UIBarButtonItem *submit = [[UIBarButtonItem alloc] initWithTitle:@"Post" style:UIBarButtonSystemItemDone target:self action:@selector(doShareThisStory:)];
    self.submitButton = submit;
    self.navigationItem.rightBarButtonItem = submit;
    
    
    // Do any additional setup after loading the view from its nib.
    commentField.layer.borderWidth = 1.0f;
    commentField.layer.cornerRadius = 4;
    commentField.layer.borderColor = [[UIColor grayColor] CGColor];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];    
    if ([userPreferences integerForKey:@"shareToFacebook"]){
        facebookButton.selected = YES;
    }
    if ([userPreferences integerForKey:@"shareToTwitter"]){
        twitterButton.selected = YES;
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    } else {
        self.submitButton.tintColor = UIColorFromRGB(0x709d3c);
    }

    [super viewDidLoad];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidUnload
{
    [self setCommentField:nil];
    [self setFacebookButton:nil];
    [self setTwitterButton:nil];
    [self setSubmitButton:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self adjustCommentField];
}

- (void)viewWillAppear:(BOOL)animated {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.commentField becomeFirstResponder];
        [self adjustCommentField];
    }
}

- (void)adjustCommentField {
	UIInterfaceOrientation orientation = (UIInterfaceOrientation)[[UIApplication sharedApplication] statusBarOrientation];
    if (UIInterfaceOrientationIsPortrait(orientation)){
        self.commentField.frame = CGRectMake(20, 20, 280, 124);
        self.twitterButton.frame = CGRectMake(228, 152, 32, 32);
        self.facebookButton.frame = CGRectMake(268, 152, 32, 32);
    } else {
        self.commentField.frame = CGRectMake(60, 20, 400, 74);
        self.twitterButton.frame = CGRectMake(15, 20, 32, 32);
        self.facebookButton.frame = CGRectMake(15, 63, 32, 32);
    }
}

- (IBAction)doCancelButton:(id)sender {
    [appDelegate hideShareView:NO];
}

- (IBAction)doToggleButton:(id)sender {
    UIButton *button = (UIButton *)sender;
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if (button.selected) {
        button.selected = NO;
        if ([[button currentTitle] isEqualToString: @"Facebook"]) {
            [userPreferences setInteger:0 forKey:@"shareToFacebook"];
        } else if ([[button currentTitle] isEqualToString: @"Twitter"]) {
            [userPreferences setInteger:0 forKey:@"shareToTwitter"];
        }
    } else {
        button.selected = YES;
        if ([[button currentTitle] isEqualToString: @"Facebook"]) {
            [userPreferences setInteger:1 forKey:@"shareToFacebook"];
        } else if ([[button currentTitle] isEqualToString: @"Twitter"]) {
            [userPreferences setInteger:1 forKey:@"shareToTwitter"];
        }
    }
    [userPreferences synchronize];
}

- (void)setSiteInfo:(NSString *)type setUserId:(NSString *)userId setUsername:(NSString *)username setReplyId:(NSString *)replyId {
    [self.submitButton setStyle:UIBarButtonItemStyleDone];
    if ([type isEqualToString: @"edit-reply"]) {
        self.currentType = nil;
        [submitButton setTitle:@"Save your reply"];
        facebookButton.hidden = YES;
        twitterButton.hidden = YES;
//        self.navigationItem.title = @"Edit Your Reply";
        [submitButton setAction:(@selector(doReplyToComment:))];
        self.activeReplyId = replyId;
        
        // get existing reply
        NSArray *replies = [appDelegate.activeComment objectForKey:@"replies"];
        NSDictionary *reply = nil;
        for (int i = 0; i < replies.count; i++) {
            NSString *replyId = [NSString stringWithFormat:@"%@", [[replies objectAtIndex:i] valueForKey:@"reply_id"]];
            NSLog(@"[replies objectAtIndex:i] valueForKey:@reply_id] %@", [[replies objectAtIndex:i] valueForKey:@"reply_id"]);
            NSLog(@":self.activeReplyId %@", self.activeReplyId);
            
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
//        self.navigationItem.title = [NSString stringWithFormat:@"Reply to %@", username];
        [submitButton setAction:(@selector(doReplyToComment:))];
        
        if (![self.currentType isEqualToString:@"share"] &&
            ![self.currentType isEqualToString:@"reply"]) {
            self.commentField.text = @"";
            self.currentType = type;
        }
    } else if ([type isEqualToString: @"edit-share"]) {
        self.currentType = nil;
        facebookButton.hidden = NO;
        twitterButton.hidden = NO;
        
        // get old comment
        self.commentField.text = [self stringByStrippingHTML:[appDelegate.activeComment objectForKey:@"comments"]];
        
//        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
//            self.navigationItem.title = @"Edit Your Comment";
//            [submitButton setTitle:@"Save your comments"];
//        } else {
//            self.navigationItem.title = @"Edit Comment";
//            [submitButton setTitle:@"Save"];
//        }
        [submitButton setTitle:@"Save your comments"];
        [submitButton setAction:(@selector(doShareThisStory:))];
    } else if ([type isEqualToString: @"share"]) {        
        facebookButton.hidden = NO;
        twitterButton.hidden = NO;
        [submitButton setTitle:@"Share this story"];
        [submitButton setAction:(@selector(doShareThisStory:))];
        if (![self.currentType isEqualToString:@"share"] &&
            ![self.currentType isEqualToString:@"reply"]) {
            self.commentField.text = @"";
            self.currentType = type;
        }
    }
}

- (void)clearComments {
    self.commentField.text = nil;
    self.currentType = nil;
}

# pragma mark
# pragma mark Share Story

- (IBAction)doShareThisStory:(id)sender {
    [appDelegate.storyDetailViewController showShareHUD];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/share_story",
                           NEWSBLUR_URL];

    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    NSString *storyIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"id"]];

    [request setPostValue:feedIdStr forKey:@"feed_id"]; 
    [request setPostValue:storyIdStr forKey:@"story_id"];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];   
    if ([userPreferences integerForKey:@"shareToFacebook"]){
        [request addPostValue:@"facebook" forKey:@"post_to_services"];     
    }
    if ([userPreferences integerForKey:@"shareToTwitter"]){
        [request addPostValue:@"twitter" forKey:@"post_to_services"];     
    }
        
    if ([appDelegate.activeStory objectForKey:@"social_user_id"] != nil) {
        NSString *sourceUserIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"social_user_id"]];
        [request setPostValue:sourceUserIdStr forKey:@"source_user_id"]; 
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
    
    NSArray *userProfiles = [results objectForKey:@"user_profiles"];
    appDelegate.activeFeedUserProfiles = [DataUtilities 
                                          updateUserProfiles:appDelegate.activeFeedUserProfiles 
                                          withNewUserProfiles:userProfiles];
    
    [self replaceStory:[results objectForKey:@"story"] withReplyId:nil];
}

# pragma mark
# pragma mark Reply to Story

- (IBAction)doReplyToComment:(id)sender {
    [appDelegate.storyDetailViewController showShareHUD];
    NSString *comments = commentField.text;
    if ([comments length] == 0) {
        return;
    }
    
//    NSLog(@"REPLY TO COMMENT, %@", appDelegate.activeComment);
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/save_comment_reply",
                           NEWSBLUR_URL];
    
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
    [appDelegate hideShareView:YES];
    [appDelegate.storyDetailViewController showShareHUD];
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
    // add the comment into the activeStory dictionary
    NSDictionary *newStory = [DataUtilities updateComment:results for:appDelegate];
    [self replaceStory:newStory withReplyId:[results objectForKey:@"reply_id"]];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

- (void)replaceStory:(NSDictionary *)newStory withReplyId:(NSString *)replyId {
    NSMutableDictionary *newStoryParsed = [newStory mutableCopy];
    [newStoryParsed setValue:[NSNumber numberWithInt:1] forKey:@"read_status"];
    [newStoryParsed setValue:[appDelegate.activeStory objectForKey:@"short_parsed_date"] forKey:@"short_parsed_date"] ;

    // update the current story and the activeFeedStories
    appDelegate.activeStory = newStoryParsed;
    
    NSMutableArray *newActiveFeedStories = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < appDelegate.activeFeedStories.count; i++)  {
        NSDictionary *feedStory = [appDelegate.activeFeedStories objectAtIndex:i];
        NSString *storyId = [NSString stringWithFormat:@"%@", [feedStory objectForKey:@"id"]];
        NSString *currentStoryId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"id"]];
        if ([storyId isEqualToString: currentStoryId]){
            [newActiveFeedStories addObject:newStoryParsed];
        } else {
            [newActiveFeedStories addObject:[appDelegate.activeFeedStories objectAtIndex:i]];
        }
    }
    
    appDelegate.activeFeedStories = [NSArray arrayWithArray:newActiveFeedStories];
    
    self.commentField.text = nil;
    [appDelegate.storyDetailViewController refreshComments:replyId];
}


- (NSString *)stringByStrippingHTML:(NSString *)s {
    NSRange r;
    while ((r = [s rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
        s = [s stringByReplacingCharactersInRange:r withString:@""];
    return s; 
}

-(void)onTextChange:(NSNotification*)notification {
    NSString *text = self.commentField.text;
    if ([self.submitButton.title isEqualToString:@"Share this story"] || 
        [self.submitButton.title isEqualToString:@"Share with comments"]) {
        NSLog(@"text.length is %i", text.length);
        if (text.length) {
            self.submitButton.title = @"Share with comments";
        } else {
            self.submitButton.title = @"Share this story";
        }   
    }
    
    

}
@end
