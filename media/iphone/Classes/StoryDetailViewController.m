//
//  StoryDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "StoryDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "FeedDetailViewController.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "Base64.h"
#import "Utilities.h"

@implementation StoryDetailViewController

@synthesize activeStoryId;
@synthesize appDelegate;
@synthesize progressView;
@synthesize webView;
@synthesize toolbar;
@synthesize buttonNext;
@synthesize buttonPrevious;
@synthesize activity;
@synthesize loadingIndicator;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)dealloc {
    [activeStoryId release];
    [appDelegate release];
    [progressView release];
    [webView release];
    [toolbar release];
    [buttonNext release];
    [buttonPrevious release];
    [activity release];
    [loadingIndicator release];
    [super dealloc];
}

- (void)viewDidLoad {
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(0, 0, 51, 31);
    [backBtn setImage:[UIImage imageNamed:@"nav_btn_back.png"] forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *back = [[[UIBarButtonItem alloc] initWithCustomView:backBtn] autorelease];
    self.navigationItem.backBarButtonItem = back;  
    self.loadingIndicator = [[[UIActivityIndicatorView alloc] 
                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite] 
                             autorelease];

    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
//    NSLog(@"Stories; %@ -- %@ (%d)", self.activeStoryId,  [appDelegate.activeStory objectForKey:@"id"], self.activeStoryId ==  [appDelegate.activeStory objectForKey:@"id"]);    
    id storyId = [appDelegate.activeStory objectForKey:@"id"];
    if (self.activeStoryId != storyId) {
        [appDelegate pushReadStory:storyId];
        [self setActiveStory];
        [self showStory];
        [self markStoryAsRead];   
        [self setNextPreviousButtons];
        self.webView.scalesPageToFit = YES;
    }
    [self.loadingIndicator stopAnimating];
    
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    UIBarButtonItem *originalButton = [[UIBarButtonItem alloc] 
                                       initWithTitle:@"Original" 
                                       style:UIBarButtonItemStyleBordered 
                                       target:self 
                                       action:@selector(showOriginalSubview:)
                                       ];
    self.navigationItem.rightBarButtonItem = originalButton;
    [originalButton release];
	[super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    Class viewClass = [appDelegate.navigationController.visibleViewController class];
    if (viewClass == [appDelegate.feedDetailViewController class] ||
        viewClass == [appDelegate.feedsViewController class]) {
        self.activeStoryId = nil;
        [webView loadHTMLString:@"" baseURL:[NSURL URLWithString:@""]];
    }
}

- (void)setNextPreviousButtons {
    int nextIndex = [appDelegate indexOfNextStory];
    int unreadCount = [appDelegate unreadCount];
    if (nextIndex == -1 && unreadCount > 0) {
        [buttonNext setStyle:UIBarButtonItemStyleBordered];
        [buttonNext setTitle:@"Next Unread"];        
    } else if (nextIndex == -1) {
        [buttonNext setStyle:UIBarButtonItemStyleDone];
        [buttonNext setTitle:@"Done"];
    } else {
        [buttonNext setStyle:UIBarButtonItemStyleBordered];
        [buttonNext setTitle:@"Next Unread"];
    }
    
    int readStoryCount = [appDelegate.readStories count];
    if (readStoryCount == 0 || 
        (readStoryCount == 1 && 
         [appDelegate.readStories lastObject] == [appDelegate.activeStory objectForKey:@"id"])) {
            
        [buttonPrevious setStyle:UIBarButtonItemStyleDone];
        [buttonPrevious setTitle:@"Done"];
    } else {
        [buttonPrevious setStyle:UIBarButtonItemStyleBordered];
        [buttonPrevious setTitle:@"Previous"];
    }
    
    float unreads = [appDelegate unreadCount];
    float total = [appDelegate originalStoryCount];
    float progress = (total - unreads) / total;
//    NSLog(@"Total: %f / %f = %f", unreads, total, progress);
    [progressView setProgress:progress];
}

- (void)markStoryAsRead {
    if ([[appDelegate.activeStory objectForKey:@"read_status"] intValue] != 1) {
        [appDelegate markActiveStoryRead];
        
        NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/mark_story_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setPostValue:[appDelegate.activeStory 
                               objectForKey:@"id"] 
                       forKey:@"story_id"]; 
        [request setPostValue:[appDelegate.activeStory 
                               objectForKey:@"story_feed_id"] 
                       forKey:@"feed_id"]; 
        [request setDidFinishSelector:@selector(markedAsRead)];
        [request setDidFailSelector:@selector(markedAsRead)];
        [request setDelegate:self];
        [request startAsynchronous];
    }
}

- (void)markedAsRead {
    
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
                              "h1, h2, h3, h4, h5, h6, div, table, span, pre, code {"
                              "  max-width: 300px;"
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
                              "  padding: 8px 8px 6px;"
                              "  text-shadow: 1px 1px 0 #EFEFEF;"
                              "  overflow: hidden;"
                              "  max-width: none;"
                              "}"
                              ".NB-story {"
                              "  margin: 12px 8px;"
                              "}"
                              ".NB-story-author {"
                              "    color: #969696;"
                              "    font-size: 10px;"
                              "    text-transform: uppercase;"
                              "    margin: 2px 8px 0px 0;"
                              "    text-shadow: 0 1px 0 #F9F9F9;"
                              "    float: left;"
                              "}"
                              ".NB-story-tags {"
                              "  overflow: hidden;"
                              "  line-height: 12px;"
                              "  height: 14px;"
                              "  padding: 5px 0 0 0;"
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
                              "  font-size: 11px;"
                              "  color: #454D6C;"
                              "}"
                              ".NB-story-title {"
                              "  clear: left;"
                              "  margin: 4px 0 4px;"
                              "}"
                              "ins {"
                              "  text-decoration: none;"
                              "}"
                              "del {"
                              "  display: none;"
                              "}"
                              "</style>"
                              "<meta name=\"viewport\" content=\"width=320\"/>"];
    NSString *story_author      = @"";
    if ([appDelegate.activeStory objectForKey:@"story_authors"]) {
        NSString *author = [NSString stringWithFormat:@"%@",
                            [appDelegate.activeStory objectForKey:@"story_authors"]];
        if (author && ![author isEqualToString:@"<null>"]) {
            story_author = [NSString stringWithFormat:@"<div class=\"NB-story-author\">%@</div>",author];
        }
    }
    NSString *story_tags      = @"";
    if ([appDelegate.activeStory objectForKey:@"story_tags"]) {
        NSArray *tag_array = [appDelegate.activeStory objectForKey:@"story_tags"];
        if ([tag_array count] > 0) {
            story_tags = [NSString 
                          stringWithFormat:@"<div class=\"NB-story-tags\">"
                                            "<div class=\"NB-story-tag\">"
                                            "%@</div></div>",
                          [tag_array componentsJoinedByString:@"</div><div class=\"NB-story-tag\">"]];
        }
    }
    NSString *storyHeader = [NSString stringWithFormat:@"<div class=\"NB-header\">"
                             "<div class=\"NB-story-date\">%@</div>"
                             "<div class=\"NB-story-title\">%@</div>"
                             "%@"
                             "%@"
                             "</div>", 
                             [story_tags length] ? 
                             [appDelegate.activeStory 
                              objectForKey:@"long_parsed_date"] : 
                             [appDelegate.activeStory 
                              objectForKey:@"short_parsed_date"],
                             [appDelegate.activeStory objectForKey:@"story_title"],
                             story_author,
                             story_tags];
    NSString *htmlString = [NSString stringWithFormat:@"%@ %@ <div class=\"NB-story\">%@</div>",
                            imgCssString, storyHeader, 
                            [appDelegate.activeStory objectForKey:@"story_content"]];
    NSString *feed_link = [appDelegate.dictFeeds objectForKey:[appDelegate.activeStory objectForKey:@"story_feed_id"]];
    [webView loadHTMLString:htmlString
                    baseURL:[NSURL URLWithString:feed_link]];
}

- (IBAction)doNextUnreadStory {
    int nextIndex = [appDelegate indexOfNextStory];
    int unreadCount = [appDelegate unreadCount];
    [self.loadingIndicator stopAnimating];

    if (nextIndex == -1 && unreadCount > 0 && 
        self.appDelegate.feedDetailViewController.feedPage < 50 &&
        !self.appDelegate.feedDetailViewController.pageFinished &&
        !self.appDelegate.feedDetailViewController.pageFetching) {
        // Fetch next page and see if it has the unreads.
        [self.loadingIndicator startAnimating];
        self.activity.customView = self.loadingIndicator;
        [self.appDelegate.feedDetailViewController fetchNextPage:^() {
            [self doNextUnreadStory];
        }];
    } else if (nextIndex == -1) {
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
    } else {
        [appDelegate setActiveStory:[[appDelegate activeFeedStories] 
                                     objectAtIndex:nextIndex]];
        [appDelegate pushReadStory:[appDelegate.activeStory objectForKey:@"id"]];
        [self setActiveStory];
        [self showStory];
        [self markStoryAsRead];
        [self setNextPreviousButtons];
        
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:.5];
        [UIView setAnimationBeginsFromCurrentState:NO];
        [UIView setAnimationTransition:UIViewAnimationTransitionCurlUp 
                               forView:self.view 
                                 cache:NO];
        [UIView commitAnimations];
    }
}

- (IBAction)doPreviousStory {
    [self.loadingIndicator stopAnimating];
    id previousStoryId = [appDelegate popReadStory];
    if (!previousStoryId || previousStoryId == [appDelegate.activeStory objectForKey:@"id"]) {
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
    } else {
        int previousIndex = [appDelegate locationOfStoryId:previousStoryId];
        if (previousIndex == -1) {
            return [self doPreviousStory];
        }
        [appDelegate setActiveStory:[[appDelegate activeFeedStories] 
                                     objectAtIndex:previousIndex]];
        [self setActiveStory];
        [self showStory];
        [self markStoryAsRead];
        [self setNextPreviousButtons];
        
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:.5];
        [UIView setAnimationBeginsFromCurrentState:NO];
        [UIView setAnimationTransition:UIViewAnimationTransitionCurlDown 
                               forView:self.view 
                                 cache:NO];
        [UIView commitAnimations];
    }
}

- (void)showOriginalSubview:(id)sender {
    NSURL *url = [NSURL URLWithString:[appDelegate.activeStory 
                                       objectForKey:@"story_permalink"]];
    [appDelegate showOriginalStory:url];
}

- (void)setActiveStory {
    self.activeStoryId = [appDelegate.activeStory objectForKey:@"id"];  
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    UIImage *titleImage = [Utilities getImage:feedIdStr];
	UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
	titleImageView.frame = CGRectMake(0.0, 2.0, 16.0, 16.0);
    self.navigationItem.titleView = titleImageView;
    [titleImageView release];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	self.activeStoryId = nil;
	// Release any cached data, images, etc that aren't in use.
}

- (BOOL)webView:(UIWebView *)webView 
    shouldStartLoadWithRequest:(NSURLRequest *)request 
    navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        NSURL *url = [request URL];
        [appDelegate showOriginalStory:url];
        return NO;
    }
    
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
}

@end
