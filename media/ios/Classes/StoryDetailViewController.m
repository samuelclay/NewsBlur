//
//  StoryDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "StoryDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "MGSplitViewController.h"
#import "NewsBlurViewController.h"
#import "FeedDetailViewController.h"
#import "FontSettingsViewController.h"
#import "UserProfileViewController.h"
#import "ShareViewController.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "Base64.h"
#import "Utilities.h"
#import "JSON.h"

@implementation StoryDetailViewController

@synthesize appDelegate;
@synthesize activeStoryId;
@synthesize progressView;
@synthesize innerView;
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


- (void)viewDidLoad {
    [super viewDidLoad];
    
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
    self.loadingIndicator = [[UIActivityIndicatorView alloc] 
                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    
    self.webView.scalesPageToFit = NO; 
    self.webView.multipleTouchEnabled = NO;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.navigationItem.hidesBackButton = YES;
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:originalButton, fontSettingsButton, nil];
    } else {
        UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        backBtn.frame = CGRectMake(0, 0, 51, 31);
        [backBtn setImage:[UIImage imageNamed:@"nav_btn_back.png"] forState:UIControlStateNormal];
        [backBtn addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
        self.navigationItem.backBarButtonItem = back; 
        
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:originalButton, fontSettingsButton, nil];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [self initStory];
	[super viewWillAppear:animated];
    
    if (UI_USER_INTERFACE_IDIOM()== UIUserInterfaceIdiomPad) {
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;        
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            self.navigationItem.leftBarButtonItem = self.toggleViewButton;
        } else {
            self.navigationItem.leftBarButtonItem = nil;
        }
    }
}

- (void)initStory {
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
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [popoverController dismissPopoverAnimated:YES];
        [appDelegate hideShareView:YES];
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        // copy the title from the master view to detail view
        if (appDelegate.splitStoryController.isShowingMaster) {
            self.navigationItem.titleView = nil;
        } else {
            UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.activeFeed];
            self.navigationItem.titleView = titleLabel;
        }
        
        if (UIInterfaceOrientationIsPortrait(fromInterfaceOrientation)) {
            self.navigationItem.leftBarButtonItem = nil;
        } else {
            self.navigationItem.leftBarButtonItem = self.toggleViewButton;
        }
        
        [appDelegate adjustStoryDetailWebView];
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [appDelegate.shareViewController.commentField resignFirstResponder];
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
                            "<a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\"><img src=\"%@\" /></a>"
                            "</div></div>",
                            [user objectForKey:@"user_id"],
                            [user objectForKey:@"photo_url"]];
        avatarString = [avatarString stringByAppendingString:avatar];
    }
    
    if (areFriends && [share_user_ids count]) {
        avatarString = [avatarString stringByAppendingString:@"</div>"];
        
    }
    return avatarString;
}

- (NSString *)getComments:(NSString *)type {
    NSString *comments = @"";
//    NSLog(@"the comment string is %@", [appDelegate.activeStory objectForKey:@"share_count"]);
//    NSLog(@"appDelegate.activeStory is %@", appDelegate.activeStory);
    if ([appDelegate.activeStory objectForKey:@"share_count"] != [NSNull null] &&
        [[appDelegate.activeStory objectForKey:@"share_count"] intValue] > 0) {
        
        NSDictionary *story = appDelegate.activeStory;
        NSArray *friendsCommentsArray =  [story objectForKey:@"friend_comments"];   
        NSArray *publicCommentsArray =  [story objectForKey:@"public_comments"];   
                
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

        // add friends comments
        for (int i = 0; i < friendsCommentsArray.count; i++) {
            NSString *comment = [self getComment:[friendsCommentsArray objectAtIndex:i]];
            comments = [comments stringByAppendingString:comment];
        }
        
        if ([[story objectForKey:@"comment_count_public"] intValue] > 0 ) {
            NSString *publicCommentHeader = [NSString stringWithFormat:@
                                             "<div class=\"NB-story-comments-public-header-wrapper\">"
                                             "<div class=\"NB-story-comments-public-header\">%i public comment%@</div>"
                                             "</div>",
                                             [[story objectForKey:@"comment_count_public"] intValue],
                                             [[story objectForKey:@"comment_count_public"] intValue] == 1 ? @"" : @"s"];
            
            comments = [comments stringByAppendingString:publicCommentHeader];
            
            // add friends comments
            for (int i = 0; i < publicCommentsArray.count; i++) {
                NSString *comment = [self getComment:[publicCommentsArray objectAtIndex:i]];
                comments = [comments stringByAppendingString:comment];
            }
        }


        comments = [comments stringByAppendingString:[NSString stringWithFormat:@"</div>"]];
    }
    
    return comments;
}

- (NSString *)getComment:(NSDictionary *)commentDict {
    
    NSDictionary *user = [self getUser:[[commentDict objectForKey:@"user_id"] intValue]];
    NSString *userAvatarClass = @"NB-user-avatar";
    NSString *userReshareString = @"";
    NSString *userEditButton = @"";
    NSString *commentUserId = [NSString stringWithFormat:@"%@", [commentDict objectForKey:@"user_id"]];
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
    
    if ([commentUserId isEqualToString:currentUserId]) {
        userEditButton = [NSString stringWithFormat:@
                          "<div class=\"NB-story-comment-edit-button NB-story-comment-share-edit-button\">"
                            "<div class=\"NB-story-comment-edit-button-wrapper\">"
                                "<a href=\"http://ios.newsblur.com/edit-share\">edit</a>"
                            "</div>"
                          "</div>"
                          ];
    }

    if ([commentDict objectForKey:@"source_user_id"] != [NSNull null]) {
        userAvatarClass = @"NB-user-avatar NB-story-comment-reshare";

        NSDictionary *sourceUser = [self getUser:[[commentDict objectForKey:@"source_user_id"] intValue]];
        userReshareString = [NSString stringWithFormat:@
                             "<div class=\"NB-story-comment-reshares\">"
                             "    <div class=\"NB-story-share-profile\">"
                             "        <div class=\"NB-user-avatar\"><img src=\"%@\"></div>"
                             "    </div>"
                             "</div>",
                             [sourceUser objectForKey:@"photo_url"]];
    } 
    
    NSString *comment = [NSString stringWithFormat:@
                        "<div class=\"NB-story-comment\" id=\"NB-user-comment-%@\">"
                        "<div class=\"%@\"><a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\"><img src=\"%@\" /></a></div>"
                        "<div class=\"NB-story-comment-author-container\">"
                        "   %@"
                        "    <div class=\"NB-story-comment-username\">%@</div>"
                        "    <div class=\"NB-story-comment-date\">%@ ago</div>"
                        "    %@" //User Edit Button>"
                        "    <div class=\"NB-story-comment-reply-button\">"
                        "        <div class=\"NB-story-comment-reply-button-wrapper\">"
                        "            <a href=\"http://ios.newsblur.com/reply/%@/%@\">reply</a>"
                        "        </div>"
                        "    </div>"
                        "</div>"
                        "<div class=\"NB-story-comment-content\">%@</div>"
                        "%@"
                        "</div>",
                        [commentDict objectForKey:@"user_id"],
                        userAvatarClass,
                        [commentDict objectForKey:@"user_id"],
                        [user objectForKey:@"photo_url"],
                        userReshareString,
                        [user objectForKey:@"username"],
                        [commentDict objectForKey:@"shared_date"],
                        userEditButton,
                        [commentDict objectForKey:@"user_id"],
                        [user objectForKey:@"username"],
                        [commentDict objectForKey:@"comments"],
                        [self getReplies:[commentDict objectForKey:@"replies"] forUserId:[commentDict objectForKey:@"user_id"]]]; 

    return comment;
}

- (NSString *)getReplies:(NSArray *)replies forUserId:(NSString *)commentUserId {
    NSString *repliesString = @"";
    if (replies.count > 0) {
        repliesString = [repliesString stringByAppendingString:@"<div class=\"NB-story-comment-replies\">"];
        for (int i = 0; i < replies.count; i++) {
            NSDictionary *replyDict = [replies objectAtIndex:i];
            NSDictionary *user = [self getUser:[[replyDict objectForKey:@"user_id"] intValue]];

            NSString *userEditButton = @"";
            NSString *replyUserId = [NSString stringWithFormat:@"%@", [replyDict objectForKey:@"user_id"]];
            NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
            
            if ([replyUserId isEqualToString:currentUserId]) {
                userEditButton = [NSString stringWithFormat:@
                                  "<div class=\"NB-story-comment-edit-button NB-story-comment-share-edit-button\">"
                                  "<div class=\"NB-story-comment-edit-button-wrapper\">"
                                  "<a href=\"http://ios.newsblur.com/edit-reply/%@/%@/%i\">edit</a>"
                                  "</div>"
                                  "</div>",
                                  commentUserId,
                                  replyUserId,
                                  i // comment number in array
                                  ];
            }
            
            NSString *reply = [NSString stringWithFormat:@
                                "<div class=\"NB-story-comment-reply\">"
                                "   <a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\">"
                                "       <img class=\"NB-user-avatar NB-story-comment-reply-photo\" src=\"%@\" />"
                                "   </a>"
                                "   <div class=\"NB-story-comment-username NB-story-comment-reply-username\">%@</div>"
                                "   <div class=\"NB-story-comment-date NB-story-comment-reply-date\">%@ ago</div>"
                                "    %@" //User Edit Button>"
                                "   <div class=\"NB-story-comment-reply-content\">%@</div>"
                                "</div>",
                               [user objectForKey:@"user_id"],  
                               [user objectForKey:@"photo_url"],
                               [user objectForKey:@"username"],  
                               [replyDict objectForKey:@"publish_date"],
                               userEditButton,
                               [replyDict objectForKey:@"comments"]];
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
    [appDelegate hideFindingStoryHUD];
    [appDelegate hideShareView:YES];
    
    int activeLocation = appDelegate.locationOfActiveStory;    
    if (activeLocation >= ([appDelegate.activeFeedStoryLocations count] - 1)) {
        self.buttonNextStory.enabled = NO;
    } else {
        self.buttonNextStory.enabled = YES;
    }
    
    [appDelegate resetShareComments];
    NSString *commentString = [self getComments:@"friends"];       
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
                    "<meta name=\"viewport\" id=\"viewport\" content=\"width=%i, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\"/>",


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
                            "    %@" // storyHeader
                            "    <div class=\"%@\" id=\"NB-font-style\">"
                            "       <div class=\"%@\" id=\"NB-font-size\">"
                            "           <div class=\"NB-story\">%@</div>"
                            "       </div>" // font-size
                            "    </div>" // font-style
                            "    <div id=\"NB-comments-wrapper\">"
                            "       %@" // friends comments
                            "    </div>" 
                            "    %@" // share
                            "    %@"
                            "</body>"
                            "</html>",
                            headerString,
                            contentWidthClass,
                            storyHeader, 
                            fontStyleClass,
                            fontSizeClass,
                            [appDelegate.activeStory objectForKey:@"story_content"],
                            commentString,
                            sharingHtmlString,
                            footerString
                            ];

//    NSLog(@"\n\n\n\nhtmlString:\n\n\n%@\n\n\n", htmlString);
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
                theScrollView.scrollIndicatorInsets = UIEdgeInsetsMake(19, 0, 0, 0);
            } else {
                theScrollView.contentInset = UIEdgeInsetsMake(9, 0, 0, 0);
                theScrollView.scrollIndicatorInsets = UIEdgeInsetsMake(9, 0, 0, 0);
            }
            [self.webView insertSubview:feedTitleGradient aboveSubview:theScrollView];
            [theScrollView setContentOffset:CGPointMake(0, (appDelegate.isRiverView || appDelegate.isSocialView) ? -19 : -9) animated:NO];
                        
            break;
        }
    }
}

- (void)setActiveStory {
    self.activeStoryId = [appDelegate.activeStory objectForKey:@"id"];  
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
        UIImage *titleImage = appDelegate.isRiverView ?
            [UIImage imageNamed:@"folder.png"] :
            [Utilities getImage:feedIdStr];
        UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
        titleImageView.frame = CGRectMake(0.0, 2.0, 16.0, 16.0);
        self.navigationItem.titleView = titleImageView;   
    }
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
        if ([action isEqualToString:@"reply"] || 
            [action isEqualToString:@"edit-reply"] ||
            [action isEqualToString:@"edit-share"]) {
            appDelegate.activeComment = nil;
            // search for the comment from friends comments
            NSArray *friendComments = [appDelegate.activeStory objectForKey:@"friend_comments"];
            for (int i = 0; i < friendComments.count; i++) {
                NSString *userId = [NSString stringWithFormat:@"%@", 
                                    [[friendComments objectAtIndex:i] objectForKey:@"user_id"]];
                if([userId isEqualToString:[NSString stringWithFormat:@"%@", 
                                            [urlComponents objectAtIndex:2]]]){
                    appDelegate.activeComment = [friendComments objectAtIndex:i];
                }
            }
            
            if (appDelegate.activeComment == nil) {
                NSArray *publicComments = [appDelegate.activeStory objectForKey:@"public_comments"];
                for (int i = 0; i < publicComments.count; i++) {
                    NSString *userId = [NSString stringWithFormat:@"%@", 
                                        [[publicComments objectAtIndex:i] objectForKey:@"user_id"]];
                    if([userId isEqualToString:[NSString stringWithFormat:@"%@", 
                                                [urlComponents objectAtIndex:2]]]){
                        appDelegate.activeComment = [publicComments objectAtIndex:i];
                    }
                }
            }
            
            if ([action isEqualToString:@"reply"]) {
                [appDelegate showShareView:@"reply"
                                 setUserId:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]]
                               setUsername:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:3]]
                           setCommentIndex:nil]; 
            } else if ([action isEqualToString:@"edit-reply"]) {
                [appDelegate showShareView:@"edit-reply"
                                 setUserId:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]]
                               setUsername:nil
                           setCommentIndex:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:4]]];
            } else if ([action isEqualToString:@"edit-share"]) {
                [appDelegate showShareView:@"edit-share"
                                 setUserId:nil
                               setUsername:nil
                           setCommentIndex:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:3]]];
            }
            return NO; 
        } else if ([action isEqualToString:@"share"]) {
            [appDelegate showShareView:@"share"
                             setUserId:nil
                           setUsername:nil
                       setCommentIndex:nil];
            return NO; 
        } else if ([action isEqualToString:@"show-profile"]) {
            appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
            [self showUserProfile:[urlComponents objectAtIndex:2]
                      xCoordinate:[[urlComponents objectAtIndex:3] intValue] 
                      yCoordinate:[[urlComponents objectAtIndex:4] intValue] 
                            width:[[urlComponents objectAtIndex:5] intValue] 
                           height:[[urlComponents objectAtIndex:6] intValue]];
            return NO; 
        }
    }
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        [appDelegate showOriginalStory:url];
        return NO;
    }
    return YES;
}

- (void)showUserProfile:(NSString *)userId xCoordinate:(int)x yCoordinate:(int)y width:(int)width height:(int)height {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (popoverController == nil) {
            popoverController = [[UIPopoverController alloc]
                                 initWithContentViewController:appDelegate.userProfileViewController];
            
            popoverController.delegate = self;
        } else {
            if (popoverController.isPopoverVisible) {
                [popoverController dismissPopoverAnimated:YES];
                return;
            }
            
            [popoverController setContentViewController:appDelegate.userProfileViewController];
        }
        
        [popoverController setPopoverContentSize:CGSizeMake(320, 416)];
        
        // only adjust for the bar if user is scrolling
        if (appDelegate.isRiverView || appDelegate.isSocialView) {
            if (self.webView.scrollView.contentOffset.y == -19) {
                y = y + 19;
            }
        } else {
            if (self.webView.scrollView.contentOffset.y == -9) {
                y = y + 9;
            }
        }  
        
        [popoverController presentPopoverFromRect:CGRectMake(x, y, width, height) 
                                           inView:self.view 
                         permittedArrowDirections:UIPopoverArrowDirectionAny 
                                         animated:YES];
    } else {
        [appDelegate showUserProfileModal];
    }
    
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
//    NSString *responseString = [request responseString];
//    NSDictionary *results = [[NSDictionary alloc] 
//                             initWithDictionary:[responseString JSONValue]];
//    NSLog(@"results in mark as read is %@", results);
} 

- (void)refreshComments {
    NSString *commentString = [self getComments:@"friends"];    
    NSString *jsString = [[NSString alloc] initWithFormat:@
                          //"document.getElementById('NB-comments-wrapper').innerHTML = '%@';",
                          
                          
                          "document.write(%@)",
                          commentString];
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
}

- (void)scrolltoBottom {
    CGPoint bottomOffset = CGPointMake(0, self.webView.scrollView.contentSize.height - self.webView.bounds.size.height);
    [self.webView.scrollView setContentOffset:bottomOffset animated:YES];
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
    
    if (contentWidth > 740) {
        contentWidthClass = @"NB-ipad-wide";
    } else if (contentWidth > 420) {
        contentWidthClass = @"NB-ipad-narrow";
    } else {
        contentWidthClass = @"NB-iphone";
    }
    
    NSString *jsString = [[NSString alloc] initWithFormat:
                          @"document.getElementsByTagName('body')[0].setAttribute('class', '%@');"
                          "document.getElementById(\"viewport\").setAttribute(\"content\", \"width=%i;initial-scale=1; maximum-scale=1.0; user-scalable=0;\");",
                          contentWidthClass,
                          contentWidth];
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
}

- (IBAction)toggleFontSize:(id)sender {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (popoverController == nil) {
            popoverController = [[UIPopoverController alloc]
                                 initWithContentViewController:appDelegate.fontSettingsViewController];
            
            popoverController.delegate = self;
        } else {
            if (popoverController.isPopoverVisible) {
                [popoverController dismissPopoverAnimated:YES];
                return;
            }
            
            [popoverController setContentViewController:appDelegate.fontSettingsViewController];
        }
        
        [popoverController setPopoverContentSize:CGSizeMake(274.0, 130.0)];
        
        [popoverController presentPopoverFromBarButtonItem:sender
                                  permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        FontSettingsViewController *fontSettings = [[FontSettingsViewController alloc] init];
        appDelegate.fontSettingsViewController = fontSettings;
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:appDelegate.fontSettingsViewController];
        
        // adding Done button
        UIBarButtonItem *donebutton = [[UIBarButtonItem alloc]
                                       initWithTitle:@"Done" 
                                       style:UIBarButtonItemStyleDone 
                                       target:self 
                                       action:@selector(hideToggleFontSize)];
        
        appDelegate.fontSettingsViewController.navigationItem.rightBarButtonItem = donebutton;
        appDelegate.fontSettingsViewController.navigationItem.title = @"Style";
        navController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
        [self presentModalViewController:navController animated:YES];
        
    }
}

- (void)hideToggleFontSize {
    [self dismissModalViewControllerAnimated:YES];
}

- (void)changeFontSize:(NSString *)fontSize {
    NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementById('NB-font-size').setAttribute('class', '%@')", 
                          fontSize];
    
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
}
 
- (void)setFontStyle:(NSString *)fontStyle {
    NSString *jsString;
    NSString *fontStyleStr;
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if ([fontStyle isEqualToString:@"Helvetica"]) {
        [userPreferences setObject:@"NB-san-serif" forKey:@"fontStyle"];
        fontStyleStr = @"NB-san-serif";
    } else {
        [userPreferences setObject:@"NB-serif" forKey:@"fontStyle"];
        fontStyleStr = @"NB-serif";
    }
    [userPreferences synchronize];
    
    jsString = [NSString stringWithFormat:@
                "document.getElementById('NB-font-style').setAttribute('class', '%@')", 
                fontStyleStr];
    
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
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
    [self setButtonNextStory:nil];
    [self setInnerView:nil];
    [super viewDidUnload];
}
@end
