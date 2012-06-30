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
#import "JSON.h"

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
@synthesize buttonNextStory;
@synthesize toggleViewButton;

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
    [buttonNextStory release];
    [buttonNextStory release];
    [toggleViewButton release];
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
    
    UIBarButtonItem *fontSettingsButton = [[UIBarButtonItem alloc] 
                                       initWithTitle:@"Aa" 
                                       style:UIBarButtonItemStyleBordered 
                                       target:self 
                                       action:@selector(toggleFontSize:)
                                       ];
    
    UIImage *slide = [UIImage imageNamed: appDelegate.splitStoryController.isShowingMaster ? @"slide_left.png" : @"slide_right.png"];
    
    UIBarButtonItem *toggleButton = [[UIBarButtonItem alloc]
                        initWithImage:slide
                        style:UIBarButtonItemStylePlain
                        target:self
                        action:@selector(toggleView)];
    
    self.toggleViewButton = toggleButton;
    


        
    if (UI_USER_INTERFACE_IDIOM()== UIUserInterfaceIdiomPad) {
        appDelegate.splitStoryDetailViewController.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:originalButton, fontSettingsButton, nil];
        appDelegate.splitStoryDetailViewController.navigationItem.leftBarButtonItem = self.toggleViewButton;

    } else {
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:originalButton, fontSettingsButton, nil];
        self.navigationItem.rightBarButtonItem = self.toggleViewButton;
    }

    [toggleButton release];
    [originalButton release];
    [fontSettingsButton release];
	[super viewDidAppear:animated];
}

- (void)toggleView {
    if (appDelegate.splitStoryController.isShowingMaster){
        [appDelegate animateHidingMasterView];
    } else {
        [appDelegate animateShowingMasterView];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    Class viewClass = [appDelegate.navigationController.visibleViewController class];
    if (viewClass == [appDelegate.feedDetailViewController class] ||
        viewClass == [appDelegate.feedsViewController class]) {
        self.activeStoryId = nil;
        [webView loadHTMLString:@"" baseURL:[NSURL URLWithString:@""]];
    }
    [popoverController dismissPopoverAnimated:YES];
}

#pragma mark -
#pragma mark Story layout

- (NSString *)getAvatars:(BOOL)areFriends {
    NSString *avatarString = @"";
    NSArray *share_user_ids;
    if (areFriends) {        
        share_user_ids = [appDelegate.activeStory objectForKey:@"shared_by_friends"];

        // only if your friends are sharing to do you see the shared label
        if ([share_user_ids count]) {
            avatarString = [avatarString stringByAppendingString:@
                            "<div class=\"NB-story-share-label\">Shared by: </div>"
                            "<div class=\"NB-story-share-profiles NB-story-share-profiles-friends\">"];
        }
    } else {
        share_user_ids = [appDelegate.activeStory objectForKey:@"shared_by_public"];
    }
    
    for (int i = 0; i < share_user_ids.count; i++) {
        NSDictionary *user = [self getUser:[[share_user_ids objectAtIndex:i] intValue]];
        NSString *avatar = [NSString stringWithFormat:@
                            "<div class=\"NB-story-share-profile\"><div class=\"NB-user-avatar\">"
                            "<img src=\"%@\">"
                            "</div></div>",
                            [user objectForKey:@"photo_url"]];
        avatarString = [avatarString stringByAppendingString:avatar];
    }
    
    if (areFriends && [share_user_ids count]) {
        avatarString = [avatarString stringByAppendingString:@"</div>"];
        
    }
    return avatarString;
}

- (NSString *)getComments {
    NSString *comments = @"";
//    NSLog(@"the comment string is %@", [appDelegate.activeStory objectForKey:@"share_count"]);
//    NSLog(@"appDelegate.activeStory is %@", appDelegate.activeStory);
    if ([appDelegate.activeStory objectForKey:@"share_count"] != [NSNull null] && [[appDelegate.activeStory objectForKey:@"share_count"] intValue] > 0) {
        NSArray *comments_array = [appDelegate.activeStory objectForKey:@"comments"];            
        comments = [comments stringByAppendingString:[NSString stringWithFormat:@
                                                      "<div class=\"NB-feed-story-comments\">"
                                                      "<div class=\"NB-story-comments-shares-teaser-wrapper\">"
                                                      "<div class=\"NB-story-comments-shares-teaser\">"
                                                      
                                                      "<div class=\"NB-right\">Shared by %@</div>"
                                                      
                                                      "<div class=\"NB-story-share-profiles NB-story-share-profiles-public\">"
                                                      "%@"
                                                      "</div>"
                                            
                                                      "%@"
                                                    
                                                      "</div></div>",
                                                      [[appDelegate.activeStory objectForKey:@"share_count"] intValue] == 1
                                                        ? [NSString stringWithFormat:@"1 person"] : 
                                                        [NSString stringWithFormat:@"%@ people", [appDelegate.activeStory objectForKey:@"share_count"]],
                                                      [self getAvatars:NO],
                                                      [self getAvatars:YES]
                                                      ]];

        for (int i = 0; i < comments_array.count; i++) {
            NSString *comment = [self getComment:[comments_array objectAtIndex:i]];
            comments = [comments stringByAppendingString:comment];
        }
        comments = [comments stringByAppendingString:[NSString stringWithFormat:@"</div>"]];
    }
    
    return comments;
}

- (NSString *)getComment:(NSDictionary *)commentDict {
    NSDictionary *user = [self getUser:[[commentDict objectForKey:@"user_id"] intValue]];
    NSString *comment = [NSString stringWithFormat:@
                         "<div class=\"NB-story-comment\" id=\"NB-user-comment-%@\"><div>"
                         "<div class=\"NB-user-avatar\"><img src=\"%@\" /></div>"
                         "<div class=\"NB-story-comment-author-container\">"
                         "<div class=\"NB-story-comment-username\">%@</div>"
                         "<div class=\"NB-story-comment-date\">%@ ago</div>"
                         "<div class=\"NB-story-comment-reply-button\"><div class=\"NB-story-comment-reply-button-wrapper\">"
                         "<a href=\"http://ios.newsblur.com/reply/%@/%@\">reply</a>"
                         "</div></div>"
                         "</div>"
                         "<div class=\"NB-story-comment-content\">%@</div>"
                         "%@"
                         "</div></div>",
                         [commentDict objectForKey:@"user_id"],
                         [user objectForKey:@"photo_url"],
                         [user objectForKey:@"username"],
                         [commentDict objectForKey:@"shared_date"],
                         [commentDict objectForKey:@"user_id"],
                         [user objectForKey:@"username"],
                         [commentDict objectForKey:@"comments"],
                         [self getReplies:[commentDict objectForKey:@"replies"]]];

    return comment;
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
                                "   <img class=\"NB-user-avatar NB-story-comment-reply-photo\" src=\"%@\" />"
                                "   <div class=\"NB-story-comment-username NB-story-comment-reply-username\">%@</div>"
                                "   <div class=\"NB-story-comment-date NB-story-comment-reply-date\">%@ ago</div>"
                                "   <div class=\"NB-story-comment-edit-button NB-story-comment-reply-edit-button\">"
                                "       <div class=\"NB-story-comment-edit-button-wrapper\">edit</div>"            
                                "   </div>"
                                "   <div class=\"NB-story-comment-reply-content\">%@</div>"
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
    appDelegate.inStoryDetail = YES;
    
    int activeLocation = appDelegate.locationOfActiveStory;    
    if (activeLocation >= ([appDelegate.activeFeedStoryLocations count] - 1)) {
        self.buttonNextStory.enabled = NO;
    } else {
        self.buttonNextStory.enabled = YES;
    }
    
    [appDelegate resetShareComments];
    NSString *commentsString = [self getComments];    
    NSString *headerString;
    NSString *sharingHtmlString;
    NSString *footerString;
    NSString *fontStyleClass = @"";
    NSString *fontSizeClass = @"";
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];    
    if ([userPreferences stringForKey:@"fontStyle"]){
        fontStyleClass = [fontStyleClass stringByAppendingString:[userPreferences stringForKey:@"fontStyle"]];
    } else {
        fontStyleClass = [fontStyleClass stringByAppendingString:@"NB-san-serif"];
    }    
    if ([userPreferences stringForKey:@"fontSizing"]){
        fontSizeClass = [fontSizeClass stringByAppendingString:[userPreferences stringForKey:@"fontSizing"]];
    } else {
        fontSizeClass = [fontSizeClass stringByAppendingString:@"NB-medium"];
    }
    
    int contentWidth = self.view.frame.size.width;
    NSString *contentWidthClass;
    
    if (contentWidth > 700) {
        contentWidthClass = @"NB-ipad-wide";
    } else if (contentWidth > 420) {
        contentWidthClass = @"NB-ipad-narrow";
    } else {
        contentWidthClass = @"NB-iphone";
    }
    
    
    // set up layout values based on iPad/iPhone    
    headerString = [NSString stringWithFormat:@
                    "<link rel=\"stylesheet\" type=\"text/css\" href=\"reader.css\" >"
                    "<link rel=\"stylesheet\" type=\"text/css\" href=\"storyDetailView.css\" >"
                    "<meta name=\"viewport\" content=\"width=%i\"/>",
                    contentWidth];
    footerString = [NSString stringWithFormat:@
                    "<script src=\"zepto.js\"></script>"
                    "<script src=\"storyDetailView.js\"></script>"];

    sharingHtmlString = [NSString stringWithFormat:@
                         "<div class='NB-share-header'></div>"
                         "<div class='NB-share-wrapper'><div class='NB-share-inner-wrapper'>"
                         "<div class='NB-share-button'><span class='NB-share-icon'></span>Post to Blurblog</div>"
                         //"<div class='NB-save-button'><span class='NB-save-icon'></span>Save this story</div>"
                         "</div></div>"];
    NSString *story_author = @"";
    if ([appDelegate.activeStory objectForKey:@"story_authors"]) {
        NSString *author = [NSString stringWithFormat:@"%@",
                            [appDelegate.activeStory objectForKey:@"story_authors"]];
        if (author && ![author isEqualToString:@"<null>"]) {
            story_author = [NSString stringWithFormat:@"<div class=\"NB-story-author\">%@</div>",author];
        }
    }
    NSString *story_tags = @"";
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
                            "<html>"
                            "<head>%@</head>" // header string
                            "<body id=\"story_pane\" class=\"%@\">"
                            "    <div class=\"%@\" id=\"NB-font-style\">"
                            "    %@" // storyHeader
                            "    <div class=\"%@\" id=\"NB-font-size\">"
                            "        <div class=\"NB-story\">%@ </div>"
                            "    </div>" // font-size
                            "    <div id=\"NB-comments-wrapper\">%@</div>" // comments
                            "        %@" // share
                            "    </div>" // font-style
                            "    %@"
                            "</body>"
                            "</html>",
                            headerString,
                            contentWidthClass,
                            fontStyleClass,
                            storyHeader, 
                            fontSizeClass,
                            [appDelegate.activeStory objectForKey:@"story_content"],
                            commentsString,
                            sharingHtmlString,
                            footerString
                            ];

    //NSLog(@"\n\n\n\nhtmlString:\n\n\n%@\n\n\n", htmlString);
    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    
    [webView loadHTMLString:htmlString
                    //baseURL:[NSURL URLWithString:feed_link]];
                    baseURL:baseURL];
    
    
    NSDictionary *feed;
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", 
                           [appDelegate.activeStory 
                            objectForKey:@"story_feed_id"]];
                           
    if (appDelegate.isSocialView) {
        feed = [appDelegate.dictActiveFeeds objectForKey:feedIdStr];
        // this is to catch when a user is already subscribed
        if (!feed) {
            feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        }
    } else {
        feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
    }
    
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
            if (appDelegate.isRiverView || appDelegate.isSocialView) {
                theScrollView.contentInset = UIEdgeInsetsMake(19, 0, 0, 0);
                theScrollView.scrollIndicatorInsets = UIEdgeInsetsMake(24, 0, 5, 0);
            } else {
                theScrollView.contentInset = UIEdgeInsetsMake(9, 0, 0, 0);
                theScrollView.scrollIndicatorInsets = UIEdgeInsetsMake(14, 0, 5, 0);
            }
            [self.webView insertSubview:feedTitleGradient aboveSubview:theScrollView];
            [theScrollView setContentOffset:CGPointMake(0, (appDelegate.isRiverView || appDelegate.isSocialView) ? -19 : -9) animated:NO];
                        
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
    NSURL *url = [request URL];
    NSArray *urlComponents = [url pathComponents];
    NSString *action = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:1]];
    // HACK: Using ios.newsblur.com to intercept the javascript share, reply, and edit events.
    // the pathComponents do not work correctly unless it is a correctly formed url
    // Is there a better way?  Someone show me the light
    if ([[url host] isEqualToString: @"ios.newsblur.com"]){
        if ([action isEqualToString:@"reply"]) {
            NSArray *comments = [appDelegate.activeStory objectForKey:@"comments"];
            for (int i = 0; i < comments.count; i++) {
                NSString *userId = [NSString stringWithFormat:@"%@", 
                                    [[comments objectAtIndex:i] objectForKey:@"user_id"]];
                if([userId isEqualToString:[NSString stringWithFormat:@"%@", 
                                            [urlComponents objectAtIndex:2]]]){
                    appDelegate.activeComment = [comments objectAtIndex:i];
                }
            }
            [appDelegate showShareView:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]]
                           setUsername:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:3]]];
            return NO;
        } else if ([action isEqualToString:@"share"]) {
            [appDelegate showShareView:nil setUsername:nil];
            return NO; 
        }
    }
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        [appDelegate showOriginalStory:url];
        return NO;
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];    
    if ([userPreferences integerForKey:@"fontSizing"]){
        [self changeFontSize:[userPreferences stringForKey:@"fontSizing"]];
    }

}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];    
    if ([userPreferences integerForKey:@"fontSizing"]){
        [self changeFontSize:[userPreferences stringForKey:@"fontSizing"]];
    }
}

#pragma mark -
#pragma mark Actions

- (void)setNextPreviousButtons {
    int nextIndex = [appDelegate indexOfNextUnreadStory];
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
        
        NSString *urlString;
        
        if (appDelegate.isSocialView) {
            urlString = [NSString stringWithFormat:@"http://%@/reader/mark_social_stories_as_read",
                        NEWSBLUR_URL];
        } else {
            urlString = [NSString stringWithFormat:@"http://%@/reader/mark_story_as_read",
                         NEWSBLUR_URL];
        }

        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        
        if (appDelegate.isSocialView) {
            NSArray *storyId = [NSArray arrayWithObject:[appDelegate.activeStory objectForKey:@"id"]];
            NSDictionary *feedStory = [NSDictionary dictionaryWithObject:storyId 
                                                                     forKey:[NSString stringWithFormat:@"%@", 
                                                                             [appDelegate.activeStory objectForKey:@"story_feed_id"]]];
                                         
            NSDictionary *usersFeedsStories = [NSDictionary dictionaryWithObject:feedStory 
                                                                          forKey:[NSString stringWithFormat:@"%@",
                                                                                  [appDelegate.activeStory objectForKey:@"social_user_id"]]];
            
            [request setPostValue:[usersFeedsStories JSONRepresentation] forKey:@"users_feeds_stories"]; 
        } else {
            [request setPostValue:[appDelegate.activeStory 
                                   objectForKey:@"id"] 
                           forKey:@"story_id"];
            [request setPostValue:[appDelegate.activeStory 
                                   objectForKey:@"story_feed_id"] 
                           forKey:@"feed_id"]; 
        }
                         
        [request setDidFinishSelector:@selector(finishMarkAsRead:)];
        [request setDidFailSelector:@selector(finishedWithError:)];
        [request setDelegate:self];
        [request startAsynchronous];
    }
}

- (void)requestFailed:(ASIHTTPRequest *)request {    
    NSLog(@"Error in mark as read is %@", [request error]);
}

- (void)finishMarkAsRead:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    NSLog(@"results in mark as read is %@", results);
    [results release];
} 

- (void)refreshComments {
    NSString *commentsString = [self getComments];    
    NSString *jsString = [[NSString alloc] initWithFormat:@
                          "document.getElementById('NB-comments-wrapper').innerHTML = '%@';",
                          commentsString];
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
    [jsString release];
    
}

   

- (IBAction)doNextUnreadStory {
    int nextIndex = [appDelegate indexOfNextUnreadStory];
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

- (IBAction)doNextStory {
    int nextIndex = [appDelegate indexOfNextStory];
    
    if (nextIndex == -1) {
        return;
    }
    
    [self.loadingIndicator stopAnimating];
    
    if (self.appDelegate.feedDetailViewController.pageFetching) {
        return;
    }
    
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

- (IBAction)doPreviousStory {
    [self.loadingIndicator stopAnimating];
    id previousStoryId = [appDelegate popReadStory];
    if (!previousStoryId || previousStoryId == [appDelegate.activeStory objectForKey:@"id"]) {
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
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

- (void)changeWebViewWidth:(int)width {
    int contentWidth = self.view.frame.size.width;
    NSString *contentWidthClass;
    
    if (contentWidth > 700) {
        contentWidthClass = @"NB-ipad-wide";
    } else if (contentWidth > 420) {
        contentWidthClass = @"NB-ipad-narrow";
    } else {
        contentWidthClass = @"NB-iphone";
    }
    
    NSString *jsString = [[NSString alloc] initWithFormat:@
                          "document.getElementsByTagName('body')[0].setAttribute('class', '%@');"
                          "document.querySelector('meta[name=viewport]').setAttribute('content', 'width=%d;', false); ", 
                          contentWidthClass,
                          width];
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
    [contentWidthClass release];
    [jsString release];
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

- (void)changeFontSize:(NSString *)fontSize {
    NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementById('NB-font-size').setAttribute('class', '%@')", 
                          fontSize];
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
    [jsString release];
}

- (void)setFontStyle:(NSString *)fontStyle {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([fontStyle isEqualToString:@"Helvetica"]) {
        [userPreferences setObject:@"NB-san-serif" forKey:@"fontStyle"];
    } else {
        [userPreferences setObject:@"NB-serif" forKey:@"fontStyle"];
    }
    [userPreferences synchronize];
    
    NSString *jsString;
    
    if ([fontStyle isEqualToString:@"Helvetica"]) {
        jsString = [[NSString alloc] initWithFormat:@"document.getElementById('NB-font-style').setAttribute('class', 'NB-san-serif')", 
                              fontStyle];
    } else {
        jsString = [[NSString alloc] initWithFormat:@"document.getElementById('NB-font-style').setAttribute('class', 'NB-serif')", 
                              fontStyle];
    }
    
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
    [jsString release];
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

- (void)viewDidUnload {
    [buttonNextStory release];
    buttonNextStory = nil;
    [self setButtonNextStory:nil];
    [super viewDidUnload];
}
@end
