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
#import "ASIHTTPRequest.h"

@implementation ShareViewController

@synthesize siteFavicon;
@synthesize siteInformation;
@synthesize commentField;
@synthesize appDelegate;

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
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    commentField.layer.borderWidth = 1.0f;
    commentField.layer.cornerRadius = 8;
    commentField.layer.borderColor = [[UIColor grayColor] CGColor];
}

- (void)viewDidUnload
{
    [self setCommentField:nil];
    [self setSiteInformation:nil];
    [self setSiteFavicon:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)setSiteInfo {
    [self.siteInformation setNumberOfLines:2];
    
    NSString *siteInfoString = [NSString stringWithFormat:@"%@: %@",
                                [appDelegate.activeFeed objectForKey:@"feed_title"],
                                [appDelegate.activeStory objectForKey:@"story_title"]];
    
    [self.siteInformation setText:siteInfoString];
    
    // vertical align label    
    CGRect resizedLabel = [self.siteInformation textRectForBounds:self.siteInformation.bounds limitedToNumberOfLines:2];
    CGRect newResizedLabelFrame = self.siteInformation.frame;    
    newResizedLabelFrame.size.height = resizedLabel.size.height;
    self.siteInformation.frame = newResizedLabelFrame;
    
    // adding in favicon
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    [siteFavicon setImage:[Utilities getImage:feedIdStr]];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    

}

- (void)dealloc {
    [appDelegate release];
    [commentField release];
    [siteInformation release];
    [siteFavicon release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (IBAction)doCancelButton:(id)sender {
    [commentField resignFirstResponder];
    [appDelegate hideShareView];
}

- (IBAction)doToggleButton:(id)sender {
    UIButton *button = (UIButton *)sender;
    
    if (button.selected) {
        button.selected = NO;
    } else {
        button.selected = YES;
    }
}

- (IBAction)doShareThisStory:(id)sender {
    for (id key in appDelegate.activeStory) {
        NSLog(@"Key in appDelegate.activeStory is %@" , key);
    }
    
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/share_story",
                           NEWSBLUR_URL];
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    NSString *storyIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"id"]];
    
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:feedIdStr forKey:@"feed_id"]; 
    [request setPostValue:storyIdStr forKey:@"story_id"];

    NSString *comments = commentField.text;
    if (comments) {
        [request setPostValue:comments forKey:@"comments"]; 
    }
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishAddComment:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)finishAddComment:(ASIHTTPRequest *)request {
    NSLog(@"%@", [request responseString]);
    NSLog(@"Successfully added.");
    [commentField resignFirstResponder];
    [appDelegate hideShareView];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

-(void)keyboardWillHide:(NSNotification*)notification
{
    NSDictionary *userInfo = notification.userInfo;
    NSTimeInterval duration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
    
    CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    CGRect shareViewFrame = self.view.frame;
    CGRect storyDetailViewFrame = appDelegate.storyDetailViewController.view.frame;
    
    NSLog(@"Keyboard y is %f", keyboardFrame.size.height);
    shareViewFrame.origin.y = shareViewFrame.origin.y + keyboardFrame.size.height;
    storyDetailViewFrame.size.height = storyDetailViewFrame.size.height + keyboardFrame.size.height;
    
    [UIView animateWithDuration:duration 
                          delay:0 
                        options:UIViewAnimationOptionBeginFromCurrentState | curve 
                     animations:^{
        self.view.frame = shareViewFrame;
        appDelegate.storyDetailViewController.view.frame = storyDetailViewFrame;
    } completion:nil];
}

-(void)keyboardWillShow:(NSNotification*)notification
{
    NSDictionary *userInfo = notification.userInfo;
    NSTimeInterval duration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
    
    CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    CGRect shareViewFrame = self.view.frame;
    CGRect storyDetailViewFrame = appDelegate.storyDetailViewController.view.frame;
    
    NSLog(@"Keyboard y is %f", keyboardFrame.size.height);
    shareViewFrame.origin.y = shareViewFrame.origin.y - keyboardFrame.size.height;
    storyDetailViewFrame.size.height = storyDetailViewFrame.size.height - keyboardFrame.size.height;
    
    [UIView animateWithDuration:duration 
                          delay:0 
                        options:UIViewAnimationOptionBeginFromCurrentState | curve 
                     animations:^{
                         self.view.frame = shareViewFrame;
                         appDelegate.storyDetailViewController.view.frame = storyDetailViewFrame;
                     } completion:nil];
}

@end
