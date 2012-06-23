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

@synthesize appDelegate;
@synthesize activeStoryId;
@synthesize progressView;
@synthesize webView;
@synthesize toolbar;
@synthesize buttonPrevious;
@synthesize buttonNext;
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

- (NSString *)getComments {
    NSString *comments = @"";
        
    if ([appDelegate.activeStory objectForKey:@"comments"]) {
        NSArray *comments_array = [appDelegate.activeStory objectForKey:@"comments"];
        if ([comments_array count] > 0) {
            
            comments = [comments stringByAppendingString:[NSString stringWithFormat:@
                                                          "<div class=\"NB-story-comments-shares-teaser-wrapper\">"
                                                          "<div class=\"NB-story-comments-shares-teaser\">"
                                                          "<div class=\"NB-right\">Shared by <b>%@</b> people</div>"
                                                          "<div class=\"NB-story-share-label\">Shared by: </div>"
                                                          "<div class=\"NB-story-share-profiles NB-story-share-profiles-friends\">"
                                                          "<div class=\"NB-story-share-profile\"><div class=\"NB-user-avatar\" original-title=\"popular\"><img src=\"http://f.cl.ly/items/0L3E37240r1O1V140k2q/popular.jpg\"></div></div>"
                                                          "<div class=\"NB-story-share-profile\"><div class=\"NB-user-avatar\" original-title=\"roy\"><img src=\"http://a0.twimg.com/profile_images/1220963194/32457_608147485418_1702670_35737586_6975021_n_normal.jpg\"></div></div>"
                                                          "<div class=\"NB-story-share-profile\"><div class=\"NB-user-avatar\" original-title=\"samuel\"><img src=\"http://a0.twimg.com/profile_images/1382021023/Campeche_Steps_normal.jpg\"></div></div>"
                                                          "</div></div></div>",
                                                          [appDelegate.activeStory objectForKey:@"comment_count"]
                                                          ]];
            
            for (int i = 0; i < comments_array.count; i++) {
                NSDictionary *comment_dict = [comments_array objectAtIndex:i];
                NSDictionary *user = [self getUser:[[comment_dict objectForKey:@"user_id"] intValue]];
                NSString *comment = [NSString stringWithFormat:@
                                     "<div class=\"NB-story-comment\"><div>"
            
                                     "<div class=\"NB-user-avatar\"><img src=\"%@\" /></div>"
                                     
                                     "<div class=\"NB-story-comment-author-container\">"
                                     "<div class=\"NB-story-comment-username\">%@</div>"
                                     "<div class=\"NB-story-comment-date\">%@</div>"
                                     "<div class=\"NB-story-comment-reply-button\"><div class=\"NB-story-comment-reply-button-wrapper\">"
                                     "<a href=\"nb-share://share-link\">reply</a>"
                                     "</div></div>"
                                     "</div>"

                                     "<div class=\"NB-story-comment-content\">%@</div>"
                                     "%@"
                                     "</div></div>",
                                     [user objectForKey:@"photo_url"],
                                     [user objectForKey:@"username"],
                                     [comment_dict objectForKey:@"shared_date"],
                                     [comment_dict objectForKey:@"comments"],
                                     [self getReplies:[comment_dict objectForKey:@"replies"]]];
                comments = [comments stringByAppendingString:comment];
            }
        }
    }
    return comments;
}

- (NSString *)getReplies:(NSArray *)replies {
    NSString *repliesString = @"";
    if (replies.count > 0) {
        repliesString = [repliesString stringByAppendingString:@"<div class=\"NB-story-comment-replies\">"];
        for (int i = 0; i < replies.count; i++) {
            NSDictionary *reply_dict = [replies objectAtIndex:i];
            NSDictionary *user = [self getUser:[[reply_dict objectForKey:@"user_id"] intValue]];
            NSString *reply = [NSString stringWithFormat:@
                                "<div class=\"NB-story-comment-reply\">"
                                "<img class=\"NB-user-avatar NB-story-comment-reply-photo\" src=\"%@\" />"
                                "<div class=\"NB-story-comment-username NB-story-comment-reply-username\">%@</div>"
                                "<div class=\"NB-story-comment-date NB-story-comment-reply-date\">%@</div>"
                                "<div class=\"NB-story-comment-reply-content\">%@</div>"
                                "</div>",
                               [user objectForKey:@"photo_url"],
                               [user objectForKey:@"username"],  
                               [reply_dict objectForKey:@"publish_date"],
                               [reply_dict objectForKey:@"comments"]];
            repliesString = [repliesString stringByAppendingString:reply];
        }
        repliesString = [repliesString stringByAppendingString:@"</div>"];
    }
    return repliesString;
}

- (NSDictionary *)getUser:(int)user_id {
    for (int i = 0; i < appDelegate.activeFeedUserProfiles.count; i++) {
        if ([[[appDelegate.activeFeedUserProfiles objectAtIndex:i] objectForKey:@"user_id"] intValue] == user_id) {
            return [appDelegate.activeFeedUserProfiles objectAtIndex:i];
        }
    }
    return nil;
}

- (void)showStory {
    
    for (id key in appDelegate.activeStory) {
        
        NSLog(@"key is: %@  value: %@", key, [appDelegate.activeStory objectForKey:key]);
    }
    
    NSString *commentsString = [self getComments];    

    NSString *customImgCssString, *universalImgCssString, *sharingHtmlString;
    // set up layout values based on iPad/iPhone    
    universalImgCssString = [NSString stringWithFormat:@
                             "<script src=\"zepto.js\"></script>"
                             "<script src=\"storyDetailView.js\"></script>"
                             "<link rel=\"stylesheet\" type=\"text/css\" href=\"reader.css\" >"
                             "<link rel=\"stylesheet\" type=\"text/css\" href=\"storyDetailView.css\" >"
                             "<meta name=\"viewport\" content=\"width=device-width\"/>"];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        customImgCssString = [NSString stringWithFormat:@"<style>"
                              "h1, h2, h3, h4, h5, h6, div, table, span, pre, code, img {"
                              "  max-width: 588px;"
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
    "<a class='NB-share-button' href='nb-share://share-link'><span class='NB-share-icon'></span>Share this story</a>"
//    "<a class='NB-save-button' href='save://save'><span class='NB-save-icon'></span>Save this story</a>"
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
    NSString *htmlString = [NSString stringWithFormat:@
                            "<html><head>%@ %@</head>"
                            "<body id=\"story_pane\">%@"
                            "<div class=\"NB-story\">%@ </div>"
                            "<div class=\"NB-feed-story-comments\">%@</div>" // comments
                            "%@" // share
                            "</body></html>",
                            universalImgCssString, 
                            customImgCssString,
                            storyHeader, 
                            [appDelegate.activeStory objectForKey:@"story_content"],
                            commentsString,
                            sharingHtmlString
                            ];

    NSLog(@"\n\n\n\nstory content\n\n\n%@<div class=\"NB-story\">%@</div>\n\n\n", storyHeader, [appDelegate.activeStory objectForKey:@"story_content"]);
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
    
    self.feedTitleGradient.tag = FEED_TITLE_GRADIENT_TAG; // Not attached yet. Remove old gradients, first.
    for (UIView *subview in self.webView.subviews) {
        if (subview.tag == FEED_TITLE_GRADIENT_TAG) {
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
        if ([[url absoluteString] isEqualToString: @"nb-share://share-link"]) {
            [appDelegate showShareView];
            return NO;
        } else {
            [appDelegate showOriginalStory:url];
            return NO;
        }
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
        [appDelegate showMasterPopover];
        [appDelegate hideStoryDetailView];
    } else {
        [appDelegate setActiveStory:[[appDelegate activeFeedStories] 
                                     objectAtIndex:nextIndex]];
        [appDelegate pushReadStory:[appDelegate.activeStory objectForKey:@"id"]];
        [self setActiveStory];
        [self showStory];
        [self markStoryAsRead];
        [self setNextPreviousButtons];
        [appDelegate changeActiveFeedDetailRow];
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
        [appDelegate showMasterPopover];
        [appDelegate hideStoryDetailView];
    } else {
        int previousIndex = [appDelegate locationOfStoryId:previousStoryId];
        if (previousIndex == -1) {
            return [self doPreviousStory];
        }
        [appDelegate setActiveStory:[[appDelegate activeFeedStories] 
                                     objectAtIndex:previousIndex]];
        [appDelegate changeActiveFeedDetailRow];
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

- (IBAction)doShareButton:(id)sender {
    [appDelegate showShareView];
}

- (void)showOriginalSubview:(id)sender {
    NSURL *url = [NSURL URLWithString:[appDelegate.activeStory 
                                       objectForKey:@"story_permalink"]];
    [appDelegate showOriginalStory:url];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *theTouch = [touches anyObject];
    CGPoint touchLocation = [theTouch locationInView:self.view];
    CGFloat y = touchLocation.y;
    [appDelegate dragFeedDetailView:y];        
}

@end
