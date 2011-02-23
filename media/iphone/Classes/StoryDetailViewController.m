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
@synthesize scrollView;
@synthesize toolbar;
@synthesize buttonNext;
@synthesize buttonPrevious;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
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
    NSError *error = [request error];
    [error release];
}


- (void)showStory {
    NSLog(@"Loaded Story view: %@", [appDelegate.activeStory objectForKey:@"story_title"]);
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
                              "  padding: 12px 12px;"
                              "  text-shadow: 1px 1px 0 #EFEFEF;"
                              "}"
                              ".NB-story {"
                              "  margin: 12px;"
                              "}"
                              "</style>"];
    NSString *storyHeader = [NSString stringWithFormat:@"<div class=\"NB-header\">"
                             "%@"
                             "</div>", [appDelegate.activeStory objectForKey:@"story_title"]];
    NSString *htmlString = [NSString stringWithFormat:@"%@ %@ <div class=\"NB-story\">%@</div>",
                            imgCssString, storyHeader, 
                            [appDelegate.activeStory objectForKey:@"story_content"]];
    [webView loadHTMLString:htmlString
                    baseURL:[NSURL URLWithString:[appDelegate.activeFeed 
                                                  objectForKey:@"feed_link"]]];
    
    
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
    [self resizeWebView];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [self resizeWebView];
}

- (void)resizeWebView {
    
    CGRect frame = webView.frame;
    frame.size.height = 1;
    webView.frame = frame;
    CGSize fittingSize = [webView sizeThatFits:CGSizeZero];
    frame.size = fittingSize;
    webView.frame = frame;
    NSLog(@"heights: %f / %f", frame.size.width, frame.size.height, toolbar.frame.size.height);
    toolbar.frame = CGRectMake(0, webView.frame.size.height, toolbar.frame.size.width, toolbar.frame.size.height);
    
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
}


- (void)dealloc {
    [appDelegate release];
    [webView release];
    [super dealloc];
}


@end
