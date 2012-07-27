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
#import "JSON.h"
#import "ASIHTTPRequest.h"

@implementation ShareViewController

@synthesize facebookButton;
@synthesize twitterButton;
@synthesize submitButton;
@synthesize toolbarTitle;
@synthesize commentField;
@synthesize appDelegate;
@synthesize activeCommentIndex;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    // Do any additional setup after loading the view from its nib.
    commentField.layer.borderWidth = 1.0f;
    commentField.layer.cornerRadius = 8;
    commentField.layer.borderColor = [[UIColor grayColor] CGColor];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];    
    if ([userPreferences integerForKey:@"shareToFacebook"]){
        facebookButton.selected = YES;
    }
    if ([userPreferences integerForKey:@"shareToTwitter"]){
        twitterButton.selected = YES;
    }
    
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate]; 
    [super viewDidLoad];
}

- (void)viewDidUnload
{
    [self setCommentField:nil];
    [self setFacebookButton:nil];
    [self setTwitterButton:nil];
    [self setSubmitButton:nil];
    [self setToolbarTitle:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)viewWillAppear:(BOOL)animated {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.commentField becomeFirstResponder];
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

- (void)setSiteInfo:(NSString *)type setUserId:(NSString *)userId setUsername:(NSString *)username setCommentIndex:(NSString *)commentIndex {
    if ([type isEqualToString: @"edit-reply"]) {
        [submitButton setTitle:@"Save"];
        facebookButton.hidden = YES;
        twitterButton.hidden = YES;
        [toolbarTitle setTitle:[NSString stringWithFormat:@"Edit Your Reply"]];
        [submitButton setAction:(@selector(doReplyToComment:))];
        self.activeCommentIndex = [commentIndex intValue];
        
        // get old comment
        NSArray *replies = [appDelegate.activeComment objectForKey:@"replies"];
        int commentIdx = [commentIndex intValue];
        self.commentField.text = [self stringByStrippingHTML:[[replies objectAtIndex:commentIdx] objectForKey:@"comments"]];
    } else if ([type isEqualToString: @"reply"]) {
        self.activeCommentIndex = -1;
        [submitButton setTitle:@"Reply"];
        facebookButton.hidden = YES;
        twitterButton.hidden = YES;
        [toolbarTitle setTitle:[NSString stringWithFormat:@"Reply to %@", username]];
        [submitButton setAction:(@selector(doReplyToComment:))];
        self.commentField.text = @"";
    } else if ([type isEqualToString: @"edit-share"]) {
        facebookButton.hidden = NO;
        twitterButton.hidden = NO;
        
        // get old comment
        self.commentField.text = [self stringByStrippingHTML:[appDelegate.activeComment objectForKey:@"comments"]];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [toolbarTitle setTitle:@"Edit Your Comment"];
            [submitButton setTitle:@"Save"];
        } else {
            [toolbarTitle setTitle:@"Edit Comment"];
            [submitButton setTitle:@"Save"];
        }
        [submitButton setAction:(@selector(doShareThisStory:))];
    } else if ([type isEqualToString: @"share"]) {        
        facebookButton.hidden = NO;
        twitterButton.hidden = NO;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [toolbarTitle setTitle:@"Post to Blurblog"];
            [submitButton setTitle:@"Share this Story"];
        } else {
            [toolbarTitle setTitle:@"Post to Blurblog"];
            [submitButton setTitle:@"Share"];
        }
        [submitButton setAction:(@selector(doShareThisStory:))];
        self.commentField.text = @"";
    }
}

- (void)clearComments {
    self.commentField.text = nil;
}

# pragma mark
# pragma mark Share Story

- (IBAction)doShareThisStory:(id)sender {
    [appDelegate.storyDetailViewController showShareHUD];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/share_story",
                           NEWSBLUR_URL];
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    NSString *storyIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"id"]];
    NSString *sourceUserIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"social_user_id"]];

    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:feedIdStr forKey:@"feed_id"]; 
    [request setPostValue:storyIdStr forKey:@"story_id"];

    if (!([sourceUserIdStr isEqualToString:@"(null)"])) {
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
    [commentField resignFirstResponder];
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
    
    [self replaceStory:[results objectForKey:@"story"]];
}

# pragma mark
# pragma mark Reply to Story

- (IBAction)doReplyToComment:(id)sender {
    [appDelegate.storyDetailViewController showShareHUD];
    NSString *comments = commentField.text;
    if ([comments length] == 0) {
        return;
    }
    
    NSLog(@"REPLY TO COMMENT, %@", appDelegate.activeComment);
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
    
    if (self.activeCommentIndex != -1) {
        NSDictionary *activeComment = [[appDelegate.activeComment objectForKey:@"replies"] objectAtIndex:self.activeCommentIndex];
        [request setPostValue:[self stringByStrippingHTML:[activeComment objectForKey:@"comments"]] forKey:@"original_message"]; 
    }
    
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishAddReply:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
    [commentField resignFirstResponder];
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
    [self replaceStory:newStory];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

- (void)replaceStory:(NSDictionary *)newStory {    
    // update the current story and the activeFeedStories
    appDelegate.activeStory = newStory;
    
    NSMutableArray *newActiveFeedStories = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < appDelegate.activeFeedStories.count; i++)  {
        NSDictionary *feedStory = [appDelegate.activeFeedStories objectAtIndex:i];
        NSString *storyId = [NSString stringWithFormat:@"%@", [feedStory objectForKey:@"id"]];
        NSString *currentStoryId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"id"]];
        if ([storyId isEqualToString: currentStoryId]){
            [newActiveFeedStories addObject:newStory];
        } else {
            [newActiveFeedStories addObject:[appDelegate.activeFeedStories objectAtIndex:i]];
        }
    }
    
    appDelegate.activeFeedStories = [NSArray arrayWithArray:newActiveFeedStories];
    
    self.commentField.text = nil;
    [appDelegate.storyDetailViewController refreshComments];
}


- (NSString *)stringByStrippingHTML:(NSString *)s {
    NSRange r;
    while ((r = [s rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
        s = [s stringByReplacingCharactersInRange:r withString:@""];
    return s; 
}

@end
