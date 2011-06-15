//
//  StoryDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "StoryDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"


@implementation StoryDetailViewController

@synthesize appDelegate;
@synthesize webView;
@synthesize toolbar;
@synthesize buttonNext;
@synthesize buttonPrevious;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [self showStory];
    if ([[appDelegate.activeStory objectForKey:@"read_status"] intValue] != 1) {
        [self markStoryAsRead];   
    }
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] 
                                               initWithTitle:@"Original" 
                                               style:UIBarButtonItemStyleBordered 
                                               target:self 
                                               action:@selector(showOriginalSubview:)
                                              ] autorelease];
	[super viewDidAppear:animated];
}

- (void)markStoryAsRead {
    [appDelegate.activeStory setValue:[NSDecimalNumber numberWithInt:1] forKey:@"read_status"];
    
    NSString *urlString = @"http://nb.local.host:8000/reader/mark_story_as_read";
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:[appDelegate.activeStory objectForKey:@"id"] forKey:@"story_id"]; 
    [request setPostValue:[appDelegate.activeFeed objectForKey:@"id"] forKey:@"feed_id"]; 
    [request setDelegate:self];
    [request startAsynchronous];
}


- (void)requestFinished:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    int code = [[results valueForKey:@"code"] intValue];
    NSLog(@"Read Story: %@", code);
    
    [results release];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
//    NSError *error = [request error];
//    [error release];
}


- (void)showStory {
//    NSLog(@"Loaded Story view: %@", appDelegate.activeStory);
    NSString *imgCssString = [NSString stringWithFormat:@"<style>"
                              "body {"
                              "  line-height: 18px;"
                              "  font-size: 13px;"
                              "  font-family: 'Lucida Grande',Helvetica, Arial;"
                              "  text-rendering: optimizeLegibility;"
                              "  margin: 0;"
                              "}"
                              "img {"
                              "  max-width: 300px;"
                              "  width: auto;"
                              "  height: auto;"
                              "}"
                              "blockquote {"
                              "  background-color: #F0F0F0;"
                              "  border-left: 1px solid #9B9B9B;"
                              "  padding: .5em 2em;"
                              "  margin: 0px;"
                              "}"
                              ".NB-header {"
                              "  font-size: 14px;"
                              "  font-weight: bold;"
                              "  background-color: #E0E0E0;"
                              "  border-bottom: 1px solid #A0A0A0;"
                              "  padding: 12px 12px 8px;"
                              "  text-shadow: 1px 1px 0 #EFEFEF;"
                              "}"
                              ".NB-story {"
                              "  margin: 12px;"
                              "}"
                              ".NB-story-author {"
                              "    color: #969696;"
                              "    font-size: 10px;"
                              "    text-transform: uppercase;"
                              "    margin: 0 16px 4px 0;"
                              "    text-shadow: 0 1px 0 #F9F9F9;"
                              "    float: left;"
                              "}"
                              ".NB-story-tags {"
                              "  clear: both;"
                              "  overflow: hidden;"
                              "  line-height: 12px;"
                              "  height: 14px;"
                              "  margin: 6px 0 0 0;"
                              "  text-transform: uppercase;"
                              "}"
                              ".NB-story-tag {"
                              "    float: left;"
                              "    font-weight: normal;"
                              "    font-size: 9px;"
                              "    padding: 0px 4px 0px;"
                              "    margin: 0 4px 2px 0;"
                              "    background-color: #C6CBC3;"
                              "    color: #505050;"
                              "    text-shadow: 0 1px 0 #E7E7E7;"
                              "    border-radius: 4px;"
                              "    -moz-border-radius: 4px;"
                              "    -webkit-border-radius: 4px;"
                              "}"
                              ".NB-story-date {"
                              "  float: right;"
                              "  font-size: 11px;"
                              "  color: #252D6C;"
                              "}"
                              ".NB-story-title {"
                              "  clear: left;"
                              "}"
                              "</style>"];
    NSString *story_author      = @"";
    if ([appDelegate.activeStory objectForKey:@"story_authors"]) {
        NSString *author = [NSString stringWithFormat:@"%@",[appDelegate.activeStory objectForKey:@"story_authors"]];
        if (author && ![author isEqualToString:@"<null>"]) {
            story_author = [NSString stringWithFormat:@"<div class=\"NB-story-author\">%@</div>",author];
        }
    }
    NSString *story_tags      = @"";
    if ([appDelegate.activeStory objectForKey:@"story_tags"]) {
        NSArray *tag_array = [appDelegate.activeStory objectForKey:@"story_tags"];
        if ([tag_array count] > 0) {
            story_tags = [NSString stringWithFormat:@"<div class=\"NB-story-tags\"><div class=\"NB-story-tag\">%@</div></div>",
                          [tag_array componentsJoinedByString:@"</div><div class=\"NB-story-tag\">"]];
        }
    }
    NSString *storyHeader = [NSString stringWithFormat:@"<div class=\"NB-header\">"
                             "<div class=\"NB-story-date\">%@</div>"
                             "%@"
                             "<div class=\"NB-story-title\">%@</div>"
                             "%@"
                             "</div>", 
                             [story_tags length] ? [appDelegate.activeStory objectForKey:@"long_parsed_date"] : [appDelegate.activeStory objectForKey:@"short_parsed_date"], 
                             story_author,
                             [appDelegate.activeStory objectForKey:@"story_title"],
                             story_tags];
    NSString *htmlString = [NSString stringWithFormat:@"%@ %@ <div class=\"NB-story\">%@</div>",
                            imgCssString, storyHeader, 
                            [appDelegate.activeStory objectForKey:@"story_content"]];
    [webView loadHTMLString:htmlString
                    baseURL:[NSURL URLWithString:[appDelegate.activeFeed 
                                                  objectForKey:@"feed_link"]]];
    
    
}

- (IBAction)doNextUnreadStory {
    int nextIndex = [appDelegate indexOfNextStory];
    if (nextIndex == -1) {
        
    } else {
        [appDelegate setActiveStory:[[appDelegate activeFeedStories] objectAtIndex:nextIndex]];
        [self showStory];

        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:.5];
        [UIView setAnimationBeginsFromCurrentState:NO];
        [UIView setAnimationTransition:UIViewAnimationTransitionCurlUp forView:self.view cache:NO];
        [UIView commitAnimations];
    }
}

- (IBAction)doPreviousStory {
    NSInteger nextIndex = [appDelegate indexOfPreviousStory];
    if (nextIndex == -1) {
        
    } else {
        [appDelegate setActiveStory:[[appDelegate activeFeedStories] objectAtIndex:nextIndex]];
        [self showStory];
        
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:.5];
        [UIView setAnimationBeginsFromCurrentState:NO];
        [UIView setAnimationTransition:UIViewAnimationTransitionCurlDown forView:self.view cache:NO];
        [UIView commitAnimations];
    }
}

- (void)showOriginalSubview:(id)sender {
    NSURL *url = [NSURL URLWithString:[appDelegate.activeStory 
                                       objectForKey:@"story_permalink"]];
    [appDelegate showOriginalStory:url];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
    self.webView = nil;
    self.appDelegate = nil;
}



- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        NSURL *url = [request URL];
        [appDelegate showOriginalStory:url];
        //[url release];
        return NO;
    }
    
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
}

- (void)dealloc {
    [appDelegate release];
    [webView release];
    [super dealloc];
}


@end
