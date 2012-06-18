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
#import "FontSettingsViewController.h"
#import "SplitStoryDetailViewController.h"
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
@synthesize buttonAction;
@synthesize activity;
@synthesize loadingIndicator;
@synthesize feedTitleGradient;
@synthesize popoverController;

#pragma mark -
#pragma mark View boilerplate

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
    [buttonAction release];
    [activity release];
    [loadingIndicator release];
    [feedTitleGradient release];
    [popoverController release];
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
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
    if (UI_USER_INTERFACE_IDIOM()== UIUserInterfaceIdiomPad) {
        appDelegate.splitStoryDetailViewController.navigationItem.rightBarButtonItem = originalButton;  
    } else {
        self.navigationItem.rightBarButtonItem = originalButton;   
    }

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

#pragma mark -
#pragma mark Story layout

- (void)showStory {
//    NSLog(@"Loaded Story view: %@", appDelegate.activeStory);

    NSString *customImgCssString, *universalImgCssString, *sharingHtmlString;
    // set up layout values based on iPad/iPhone
    
    universalImgCssString = [NSString stringWithFormat:@
                             "<link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\" >"
                             "<script>"
                             "function init() {"
                             "var a = document.getElementsByTagName('a');"
                             "for (var i = 0, l = a.length; i < l; i++) {"
                             "    if (a[i].href.indexOf('feedburner') != -1) {"
                             "      a[i].className = 'NB-no-style';"
                             "    } else {"
                             "      var img = a[i].getElementsByTagName('img');"
                             "      if(img.length) {"
                             "          a[i].className='NB-contains-image';"
                             "      }"
                             "    }"
                             "}"
                             "var img = document.getElementsByTagName('img');"
                             "for (var i = 0, l = img.length; i < l; i++) {"
                             "      if (img[i].height == 1) {"
                             "          img[i].className = 'NB-tracker';"
                             "      } else {"
                             "          img[i].className = 'NB-image';"
                             "      }"
                             "}"
                             "}"
                             "</script>"
                             "<meta name=\"viewport\" content=\"width=device-width\"/>"];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        customImgCssString = [NSString stringWithFormat:@"<style>"
                              "h1, h2, h3, h4, h5, h6, div, table, span, pre, code, img {"
                              "  max-width: 588px;"
                              "}"
                              "h1, h2, h3, h4, h5, h6, div, table, span, pre, code {"

                              "  overflow: auto;"
                              "}"
                              "</style>"];

    } else {
        customImgCssString = [NSString stringWithFormat:@"<style>"
                              "h1, h2, h3, h4, h5, h6, div, table, span, pre, code, img {"
                              "  max-width: 296px;"
                              "}"
                              "</style>"];
    }
    
   sharingHtmlString      = [NSString stringWithFormat:@
    "<div class='NB-share-header'></div>"
    "<div class='NB-share-wrapper'><div class='NB-share-inner-wrapper'>"
    "<a class='NB-share-button' href='share://share'><span class='NB-share-icon'></span>Share Story</a>"
    "<a class='NB-save-button' href='save://save'><span class='NB-save-icon'></span>Save Story</a>"
                        "</div></div>"];
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
    NSString *htmlString = [NSString stringWithFormat:@"<html><head>%@ %@</head><body onload='init()'>%@<div class=\"NB-story\">%@ </div>%@</body></html>",
                            universalImgCssString, 
                            customImgCssString,
                            storyHeader, 
                            [appDelegate.activeStory objectForKey:@"story_content"],
                            sharingHtmlString
                            ];
    //NSLog(@"%@", [appDelegate.activeStory objectForKey:@"story_content"]);
//    NSString *feed_link = [[appDelegate.dictFeeds objectForKey:[NSString stringWithFormat:@"%@", 
//                                                                [appDelegate.activeStory 
//                                                                 objectForKey:@"story_feed_id"]]] 
//                           objectForKey:@"feed_link"];

    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    
    [webView loadHTMLString:htmlString
                    //baseURL:[NSURL URLWithString:feed_link]];
                    baseURL:baseURL];
    
    NSDictionary *feed = [appDelegate.dictFeeds objectForKey:[NSString stringWithFormat:@"%@", 
                                                              [appDelegate.activeStory 
                                                               objectForKey:@"story_feed_id"]]];
    self.feedTitleGradient = [appDelegate makeFeedTitleGradient:feed 
                                 withRect:CGRectMake(0, -1, 1024, 21)]; // 1024 hack for self.webView.frame.size.width
    
    self.feedTitleGradient.tag = 12; // Not attached yet. Remove old gradients, first.
    for (UIView *subview in self.webView.subviews) {
        if (subview.tag == 12) {
            [subview removeFromSuperview];
        }
    }
    for (NSObject *aSubView in [self.webView subviews]) {
        if ([aSubView isKindOfClass:[UIScrollView class]]) {
            UIScrollView * theScrollView = (UIScrollView *)aSubView;
            if (appDelegate.isRiverView) {
                theScrollView.contentInset = UIEdgeInsetsMake(19, 0, 0, 0);
                theScrollView.scrollIndicatorInsets = UIEdgeInsetsMake(24, 0, 5, 0);
            } else {
                theScrollView.contentInset = UIEdgeInsetsMake(9, 0, 0, 0);
                theScrollView.scrollIndicatorInsets = UIEdgeInsetsMake(14, 0, 5, 0);
            }
            [self.webView insertSubview:feedTitleGradient aboveSubview:theScrollView];
            [theScrollView setContentOffset:CGPointMake(0, appDelegate.isRiverView ? -19 : -9) animated:NO];
            
            // Such a fucking hack. This hides the top shadow of the scroll view
            // so the gradient doesn't look like ass when the view is dragged down.
            NSArray *wsv = [NSArray arrayWithArray:[theScrollView subviews]];
            [[wsv objectAtIndex:7] setHidden:YES]; // Scroll to header
            [[wsv objectAtIndex:9] setHidden:YES]; // Scroll to header
            [[wsv objectAtIndex:3] setHidden:YES]; // Scroll to header
            [[wsv objectAtIndex:5] setHidden:YES]; // Scroll to header
//            UIImageView *topShadow = [[UIImageView alloc] initWithImage:[[wsv objectAtIndex:9] image]];
//            topShadow.frame = [[wsv objectAtIndex:9] frame];
//            [self.webView addSubview:topShadow];
//            [self.webView addSubview:[wsv objectAtIndex:9]];
            // Oh my god, the above code is beyond hack. It's evil. And it's going
            // to break, I swear to god. This shit deserves scorn.
            
            break;
        }
    }
}

- (void)setActiveStory {
    self.activeStoryId = [appDelegate.activeStory objectForKey:@"id"];  
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    UIImage *titleImage = appDelegate.isRiverView ?
    [UIImage imageNamed:@"folder.png"] :
    [Utilities getImage:feedIdStr];
	UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
	titleImageView.frame = CGRectMake(0.0, 2.0, 16.0, 16.0);
    self.navigationItem.titleView = titleImageView;
    [titleImageView release];
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

#pragma mark -
#pragma mark Actions

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
    
    float unreads = (float)[appDelegate unreadCount];
    float total = [appDelegate originalStoryCount];
    float progress = (total - unreads) / total;
    NSLog(@"Total: %f / %f = %f", unreads, total, progress);
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

- (IBAction)doNextUnreadStory {
    int nextIndex = [appDelegate indexOfNextStory];
    int unreadCount = [appDelegate unreadCount];
    [self.loadingIndicator stopAnimating];
    
    NSLog(@"doNextUnreadStory: %d/%d", nextIndex, unreadCount);
    
    if (self.appDelegate.feedDetailViewController.pageFetching) {
        return;
    }
    
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
        [appDelegate changeActiveFeedDetailRow:nextIndex];
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
        [appDelegate changeActiveFeedDetailRow:previousIndex];
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

- (IBAction)toggleFontSize:(id)sender {
    if (popoverController == nil) {
        popoverController = [[UIPopoverController alloc]
                           initWithContentViewController:appDelegate.fontSettingsViewController];
        
        popoverController.delegate=self;
    }
    
    [popoverController presentPopoverFromBarButtonItem:sender
                              permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];

}

- (void)setFontSize:(float)fontSize {
    NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust= '%f%%'", 
                          fontSize];
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
    [jsString release];
}

- (void)setFontStyle:(NSString *)fontStyle {
    NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementsByTagName('body')[0].style.fontFamily= '%@'", 
                          fontStyle];
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
    [jsString release];
}

- (void)showOriginalSubview:(id)sender {
    NSURL *url = [NSURL URLWithString:[appDelegate.activeStory 
                                       objectForKey:@"story_permalink"]];
    [appDelegate showOriginalStory:url];
}

@end
