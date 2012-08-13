//
//  StoryDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "StoryDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NewsBlurViewController.h"
#import "FeedDetailViewController.h"
#import "FontSettingsViewController.h"
#import "UserProfileViewController.h"
#import "ShareViewController.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "Base64.h"
#import "Utilities.h"
#import "NSString+HTML.h"
#import "NBContainerViewController.h"
#import "DataUtilities.h"
#import "JSON.h"

@interface StoryDetailViewController ()

@property (readwrite) CGFloat inTouchMove;
@property (nonatomic) MBProgressHUD *storyHUD;

@end

@implementation StoryDetailViewController

@synthesize appDelegate;
@synthesize activeStoryId;
@synthesize progressView;
@synthesize progressViewContainer;
@synthesize innerView;
@synthesize webView;
@synthesize toolbar;
@synthesize buttonPrevious;
@synthesize buttonNext;
@synthesize buttonAction;
@synthesize activity;
@synthesize loadingIndicator;
@synthesize feedTitleGradient;
@synthesize buttonNextStory;
@synthesize popoverController;
@synthesize fontSettingsButton;
@synthesize originalStoryButton;
@synthesize subscribeButton;
@synthesize noStorySelectedLabel;
@synthesize buttonBack;
@synthesize bottomPlaceholderToolbar;

// private
@synthesize inTouchMove;
@synthesize storyHUD;



#pragma mark -
#pragma mark View boilerplate

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    popoverClass = [WEPopoverController class];
    
    // adding HUD for progress bar
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapProgressBar:)];

    [self.progressViewContainer addGestureRecognizer:tap];
    self.progressViewContainer.hidden = YES;


    // settings button to right
//    UIImage *settingsImage = [UIImage imageNamed:@"settings.png"];
//    UIButton *settings = [UIButton buttonWithType:UIButtonTypeCustom];    
//    settings.bounds = CGRectMake(0, 0, 32, 32);
//    [settings addTarget:self action:@selector(toggleFontSize:) forControlEvents:UIControlEventTouchUpInside];
//    [settings setImage:settingsImage forState:UIControlStateNormal];
//    
//    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] 
//                                       initWithCustomView:settings];

    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings.png"] style:UIBarButtonItemStylePlain target:self action:@selector(toggleFontSize:)];
    
    self.fontSettingsButton = settingsButton;
    
    // original button for iPhone
    
    UIBarButtonItem *originalButton = [[UIBarButtonItem alloc] 
                                       initWithTitle:@"Original" 
                                       style:UIBarButtonItemStyleBordered 
                                       target:self 
                                       action:@selector(showOriginalSubview:)
                                       ];
    
    self.originalStoryButton = originalButton;
    
    UIBarButtonItem *subscribeBtn = [[UIBarButtonItem alloc] 
                                       initWithTitle:@"Follow User" 
                                       style:UIBarButtonSystemItemAction 
                                       target:self 
                                       action:@selector(subscribeToBlurblog)
                                       ];
    
    self.subscribeButton = subscribeBtn;
    
    // back button
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] 
                                   initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:self action:@selector(transitionFromFeedDetail)];
    self.buttonBack = backButton;
    
    // loading indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] 
                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    self.webView.scalesPageToFit = NO; 
    self.webView.multipleTouchEnabled = NO;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        backBtn.frame = CGRectMake(0, 0, 51, 31);
        [backBtn setImage:[UIImage imageNamed:@"nav_btn_back.png"] forState:UIControlStateNormal];
        [backBtn addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
        self.navigationItem.backBarButtonItem = back; 
        
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects: originalButton, settingsButton, nil];
    } else {
        self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
        self.bottomPlaceholderToolbar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    }
}

- (void)transitionFromFeedDetail {
    [self performSelector:@selector(clearStory) withObject:self afterDelay:0.5];
    [appDelegate.masterContainerViewController transitionFromFeedDetail];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
    [appDelegate adjustStoryDetailWebView];
    [self setActiveStory];
}

- (void)viewDidAppear:(BOOL)animated {
    // set the subscribeButton flag
    if (appDelegate.isTryFeedView) {
        self.subscribeButton.title = [NSString stringWithFormat:@"Follow %@", [appDelegate.activeFeed objectForKey:@"username"]]; 
        self.navigationItem.leftBarButtonItem = self.subscribeButton;
        //        self.subscribeButton.tintColor = UIColorFromRGB(0x0a6720);
    }
    appDelegate.isTryFeedView = NO;

}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && UIInterfaceOrientationIsPortrait(orientation)) {
        UITouch *theTouch = [touches anyObject];
        if ([theTouch.view isKindOfClass: UIToolbar.class] || [theTouch.view isKindOfClass: UIView.class]) {
            self.inTouchMove = YES;
            CGPoint touchLocation = [theTouch locationInView:self.view];
            CGFloat y = touchLocation.y;
            [appDelegate.masterContainerViewController dragStoryToolbar:y];  
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && UIInterfaceOrientationIsPortrait(orientation)) {
        UITouch *theTouch = [touches anyObject];
        
        if (([theTouch.view isKindOfClass: UIToolbar.class] || [theTouch.view isKindOfClass: UIView.class]) && self.inTouchMove) {
            self.inTouchMove = NO;
            [appDelegate.masterContainerViewController adjustFeedDetailScreenForStoryTitles];  
        }
    }
}

- (void)viewDidUnload {
    [self setButtonNextStory:nil];
    [self setInnerView:nil];
    [self setBottomPlaceholderToolbar:nil];
    [self setProgressViewContainer:nil];
    [self setNoStorySelectedLabel:nil];
    [super viewDidUnload];
}

- (void)initStory {
    id storyId = [appDelegate.activeStory objectForKey:@"id"];
    [appDelegate pushReadStory:storyId];
    [self showStory];  
    self.webView.scalesPageToFit = YES;
    [self.loadingIndicator stopAnimating];    
}

- (void)clearStory {
    [self.webView loadHTMLString:@"<html><head></head><body></body></html>" baseURL:nil];
    self.noStorySelectedLabel.hidden = NO;
}

- (void)viewDidDisappear:(BOOL)animated {
//    Class viewClass = [appDelegate.navigationController.visibleViewController class];
//    if (viewClass == [appDelegate.feedDetailViewController class] ||
//        viewClass == [appDelegate.feedsViewController class]) {
////        self.activeStoryId = nil;
//        [webView loadHTMLString:@"" baseURL:[NSURL URLWithString:@""]];
//    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [appDelegate adjustStoryDetailWebView];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
//    [appDelegate.shareViewController.commentField resignFirstResponder];
}


#pragma mark -
#pragma mark Story layout

- (NSString *)getAvatars:(NSString *)key {
    NSString *avatarString = @"";
    NSArray *share_user_ids = [appDelegate.activeStory objectForKey:key];
    
    for (int i = 0; i < share_user_ids.count; i++) {
        NSDictionary *user = [self getUser:[[share_user_ids objectAtIndex:i] intValue]];
        NSString *avatarClass = @"NB-user-avatar";
        if ([key isEqualToString:@"commented_by_public"] ||
            [key isEqualToString:@"shared_by_public"]) {
            avatarClass = @"NB-public-user NB-user-avatar";
        }
        NSString *avatar = [NSString stringWithFormat:@
                            "<div class=\"NB-story-share-profile\"><div class=\"%@\">"
                            "<a id=\"NB-user-share-bar-%@\" class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\"><img src=\"%@\" /></a>"
                            "</div></div>",
                            avatarClass,
                            [user objectForKey:@"user_id"],
                            [user objectForKey:@"user_id"],
                            [user objectForKey:@"photo_url"]];
        avatarString = [avatarString stringByAppendingString:avatar];
    }

    return avatarString;
}

- (NSString *)getComments {
    NSString *comments = @"<div class=\"NB-feed-story-comments\">";

    if ([appDelegate.activeStory objectForKey:@"share_count"] != [NSNull null] &&
        [[appDelegate.activeStory objectForKey:@"share_count"] intValue] > 0) {
        
        NSDictionary *story = appDelegate.activeStory;
        NSArray *friendsCommentsArray =  [story objectForKey:@"friend_comments"];   
        NSArray *publicCommentsArray =  [story objectForKey:@"public_comments"];   

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

- (NSString *)getShareBar {
    NSString *comments = @"<div id=\"NB-share-bar-wrapper\">";
    NSString *commentLabel = @"";
    NSString *shareLabel = @"";
//    NSString *replyStr = @"";
    
//    if ([[appDelegate.activeStory objectForKey:@"reply_count"] intValue] == 1) {
//        replyStr = [NSString stringWithFormat:@" and <b>1 reply</b>"];        
//    } else if ([[appDelegate.activeStory objectForKey:@"reply_count"] intValue] == 1) {
//        replyStr = [NSString stringWithFormat:@" and <b>%@ replies</b>", [appDelegate.activeStory objectForKey:@"reply_count"]];
//    }
    NSLog(@"[appDelegate.activeStory objectForKey:@'comment_count'] %@", [[appDelegate.activeStory objectForKey:@"comment_count"] class]);
    if (![[appDelegate.activeStory objectForKey:@"comment_count"] isKindOfClass:[NSNull class]] &&
        [[appDelegate.activeStory objectForKey:@"comment_count"] intValue]) {
        commentLabel = [commentLabel stringByAppendingString:[NSString stringWithFormat:@
                                                              "<div class=\"NB-story-comments-label\">"
                                                              "%@" // comment count
                                                              //"%@" // reply count
                                                              "</div>"
                                                              "<div class=\"NB-story-share-profiles NB-story-share-profiles-comments\">"
                                                              "%@" // friend avatars
                                                              "%@" // public avatars
                                                              "</div>",
                                                              [[appDelegate.activeStory objectForKey:@"comment_count"] intValue] == 1
                                                              ? [NSString stringWithFormat:@"<b>1 comment</b>"] : 
                                                              [NSString stringWithFormat:@"<b>%@ comments</b>", [appDelegate.activeStory objectForKey:@"comment_count"]],
                                                              
                                                              //replyStr,
                                                              [self getAvatars:@"commented_by_friends"],
                                                              [self getAvatars:@"commented_by_public"]]];
        NSLog(@"commentLabel is %@", commentLabel);
    }
    
    if (![[appDelegate.activeStory objectForKey:@"share_count"] isKindOfClass:[NSNull class]] &&
        [[appDelegate.activeStory objectForKey:@"share_count"] intValue]) {
        shareLabel = [shareLabel stringByAppendingString:[NSString stringWithFormat:@

                                                              "<div class=\"NB-right\">"
                                                                "<div class=\"NB-story-share-profiles NB-story-share-profiles-shares\">"
                                                                  "%@" // friend avatars
                                                                  "%@" // public avatars
                                                                "</div>"
                                                              "<div class=\"NB-story-share-label\">"
                                                              "%@" // comment count
                                                              "</div>"
                                                              "</div>",
                                                              [self getAvatars:@"shared_by_public"],
                                                              [self getAvatars:@"shared_by_friends"],
                                                              [[appDelegate.activeStory objectForKey:@"share_count"] intValue] == 1
                                                              ? [NSString stringWithFormat:@"<b>1 share</b>"] : 
                                                              [NSString stringWithFormat:@"<b>%@ shares</b>", [appDelegate.activeStory objectForKey:@"share_count"]]]];
        NSLog(@"commentLabel is %@", commentLabel);
    }
    
    if ([appDelegate.activeStory objectForKey:@"share_count"] != [NSNull null] &&
        [[appDelegate.activeStory objectForKey:@"share_count"] intValue] > 0) {
        
        comments = [comments stringByAppendingString:[NSString stringWithFormat:@
                                                      "<div class=\"NB-story-shares\">"
                                                      "<div class=\"NB-story-comments-shares-teaser-wrapper\">"
                                                      "<div class=\"NB-story-comments-shares-teaser\">"
                                                      "%@"
                                                      "%@"
                                                      "</div></div></div></div>",
                                                      commentLabel,
                                                      shareLabel
                                                      ]];

        
        

        comments = [comments stringByAppendingString:[NSString stringWithFormat:@"</div>"]];
    }
    comments = [comments stringByAppendingString:[NSString stringWithFormat:@"</div>"]];
    return comments;
}

- (NSString *)getComment:(NSDictionary *)commentDict {
    
    NSDictionary *user = [self getUser:[[commentDict objectForKey:@"user_id"] intValue]];
    NSString *userAvatarClass = @"NB-user-avatar";
    NSString *userReshareString = @"";
    NSString *userEditButton = @"";
    NSString *userLikeButton = @"";
    NSString *commentUserId = [NSString stringWithFormat:@"%@", [commentDict objectForKey:@"user_id"]];
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
    NSArray *likingUsers = [commentDict objectForKey:@"liking_users"];
    

    
    if ([commentUserId isEqualToString:currentUserId]) {
        userEditButton = [NSString stringWithFormat:@
                          "<div class=\"NB-story-comment-edit-button NB-story-comment-share-edit-button NB-button\">"
                            "<a href=\"http://ios.newsblur.com/edit-share/%@\"><div class=\"NB-story-comment-edit-button-wrapper\">"
                                "Edit"
                            "</div></a>"
                          "</div>",
                          commentUserId];
    } else {
        BOOL isInLikingUsers = NO;
        for (int i = 0; i < likingUsers.count; i++) {
            if ([[[likingUsers objectAtIndex:i] stringValue] isEqualToString:currentUserId]) {
                isInLikingUsers = YES;
                break;
            }
        }
        
        if (isInLikingUsers) {
            userLikeButton = [NSString stringWithFormat:@
                              "<div class=\"NB-story-comment-like-button NB-button selected\">"
                              "<a href=\"http://ios.newsblur.com/unlike-comment/%@\"><div class=\"NB-story-comment-like-button-wrapper\">"
                              "<span class=\"NB-favorite-icon\"></span>Favorited"
                              "</div></a>"
                              "</div>",
                              commentUserId]; 
        } else {
            userLikeButton = [NSString stringWithFormat:@
                              "<div class=\"NB-story-comment-like-button NB-button\">"
                              "<a href=\"http://ios.newsblur.com/like-comment/%@\"><div class=\"NB-story-comment-like-button-wrapper\">"
                              "<span class=\"NB-favorite-icon\"></span>Favorite"
                              "</div></a>"
                              "</div>",
                              commentUserId]; 
        }

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
    
    NSString *commentContent = [self textToHtml:[commentDict objectForKey:@"comments"]];
    
    NSString *comment;
    NSString *locationHtml = @"";
    NSString *location = [NSString stringWithFormat:@"%@", [user objectForKey:@"location"]];
    
    if (location.length) {
        locationHtml = [NSString stringWithFormat:@"<div class=\"NB-story-comment-location\">%@</div>", location];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        comment = [NSString stringWithFormat:@
                    "<div class=\"NB-story-comment\" id=\"NB-user-comment-%@\">"
                    "<div class=\"%@\"><a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\"><img src=\"%@\" /></a></div>"
                    "<div class=\"NB-story-comment-author-container\">"
                    "   %@"
                    "    <div class=\"NB-story-comment-username\">%@</div>"
                    " %@" // location
                    "    <div class=\"NB-story-comment-date\">%@ ago</div>"
                    "    <div class=\"NB-button-wrapper\">"
                    "    %@" //User Like Button>"
                    "    %@" //User Edit Button>"
                    "    <div class=\"NB-story-comment-reply-button NB-button\">"
                    "        <a href=\"http://ios.newsblur.com/reply/%@/%@\"><div class=\"NB-story-comment-reply-button-wrapper\">"
                    "            Reply"
                    "        </div></a>"
                    "    </div>"
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
                    locationHtml,
                    [commentDict objectForKey:@"shared_date"],
                    userEditButton,
                    userLikeButton,
                    [commentDict objectForKey:@"user_id"],
                    [user objectForKey:@"username"],
                    commentContent,
                    [self getReplies:[commentDict objectForKey:@"replies"] forUserId:[commentDict objectForKey:@"user_id"]]]; 
    } else {
        comment = [NSString stringWithFormat:@
                   "<div class=\"NB-story-comment\" id=\"NB-user-comment-%@\">"
                   "<div class=\"%@\"><a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\"><img src=\"%@\" /></a></div>"
                   "<div class=\"NB-story-comment-author-container\">"
                   "   %@"
                   "    <div class=\"NB-story-comment-username\">%@</div>"
                   "   %@"
                   "    <div class=\"NB-story-comment-date\">%@ ago</div>"
                   "</div>"
                   "<div class=\"NB-story-comment-content\">%@"

                   "<div style=\"clear:both\">"
                   "    <div class=\"NB-story-comment-reply-button NB-button\">"
                   "        <a href=\"http://ios.newsblur.com/reply/%@/%@\"><div class=\"NB-story-comment-reply-button-wrapper\">"
                   "            Reply"
                   "        </div></a>"
                   "    </div>"
                   "    %@" //User Edit Button>"
                   "    %@" //User Like Button>"
                   "</div>"
                   "</div>"
                   "%@"
                   "</div>",
                   [commentDict objectForKey:@"user_id"],
                   userAvatarClass,
                   [commentDict objectForKey:@"user_id"],
                   [user objectForKey:@"photo_url"],
                   userReshareString,
                   [user objectForKey:@"username"],
                   locationHtml,
                   [commentDict objectForKey:@"shared_date"],
                   commentContent,
                   [commentDict objectForKey:@"user_id"],
                   [user objectForKey:@"username"],
                   userEditButton,
                   userLikeButton,
                   [self getReplies:[commentDict objectForKey:@"replies"] forUserId:[commentDict objectForKey:@"user_id"]]]; 

    }
    
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
            NSString *replyId = [replyDict objectForKey:@"reply_id"];
            NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
            
            if ([replyUserId isEqualToString:currentUserId]) {
                userEditButton = [NSString stringWithFormat:@
                                  "<div class=\"NB-story-comment-edit-button NB-story-comment-share-edit-button NB-button\">"
                                  "<a href=\"http://ios.newsblur.com/edit-reply/%@/%@/%@\">"
                                  "<div class=\"NB-story-comment-edit-button-wrapper\">"
                                  "edit"
                                  "</div>"
                                  "</a>"
                                  "</div>",
                                  commentUserId,
                                  replyUserId,
                                  replyId
                                  ];
            }
            
            NSString *replyContent = [self textToHtml:[replyDict objectForKey:@"comments"]];
            
            NSString *locationHtml = @"";
            NSString *location = [NSString stringWithFormat:@"%@", [user objectForKey:@"location"]];
            
            if (location.length) {
                locationHtml = [NSString stringWithFormat:@"<div class=\"NB-story-comment-location\">%@</div>", location];
            }
                        
            NSString *reply;
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                reply = [NSString stringWithFormat:@
                        "<div class=\"NB-story-comment-reply\" id=\"NB-user-comment-%@\">"
                        "   <a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\">"
                        "       <img class=\"NB-story-comment-reply-photo\" src=\"%@\" />"
                        "   </a>"
                        "   <div class=\"NB-story-comment-username NB-story-comment-reply-username\">%@</div>"
                        "   %@"
                        "   <div class=\"NB-story-comment-date NB-story-comment-reply-date\">%@ ago</div>"
                        "    %@" //User Edit Button>"
                        "   <div class=\"NB-story-comment-reply-content\">%@</div>"
                        "</div>",
                       [replyDict objectForKey:@"reply_id"],
                       [user objectForKey:@"user_id"],  
                       [user objectForKey:@"photo_url"],
                       [user objectForKey:@"username"],
                       locationHtml,
                       [replyDict objectForKey:@"publish_date"],
                       userEditButton,
                       replyContent];
            } else {
                
            }
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
    NSLog(@"in showStory");
    // when we show story, we mark it as read
    [self markStoryAsRead]; 
    self.noStorySelectedLabel.hidden = YES;

    
    appDelegate.shareViewController.commentField.text = nil;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController transitionFromShareView];
    }
    
    self.webView.hidden = NO;
    self.bottomPlaceholderToolbar.hidden = YES;
    self.progressViewContainer.hidden = NO;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects: originalStoryButton, fontSettingsButton, nil];
    }

    [appDelegate hideShareView:YES];
        
    [appDelegate resetShareComments];
    NSString *shareBarString = [self getShareBar]; 
    NSString *commentString = [self getComments];       
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
    } else if (contentWidth > 480) {
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
                         "<div id=\"NB-share-button-id\" class='NB-share-button NB-button'>"
                         "<a href=\"http://ios.newsblur.com/share\"><div>"
                         "Post to Blurblog <span class=\"NB-share-icon\"></span>"
                         "</div></a>"
                         "</div>"
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
    NSString *storyHeader = [NSString stringWithFormat:@
                             "<div class=\"NB-header\"><div class=\"NB-header-inner\">"
                             "<div class=\"NB-story-date\">%@</div>"
                             "<div class=\"NB-story-title\">%@</div>"
                             "%@"
                             "%@"
                             "</div></div>", 
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
                            "    %@" // shareBar
                            "    <div class=\"%@\" id=\"NB-font-style\">"
                            "       <div class=\"%@\" id=\"NB-font-size\">"
                            "           <div class=\"NB-story\">%@</div>"
                            "       </div>" // font-size
                            "    </div>" // font-style
                            "    %@" // share
                            "    <div id=\"NB-comments-wrapper\">"
                            "       %@" // friends comments
                            "    </div>" 
                            "    %@"
                            "</body>"
                            "</html>",
                            headerString,
                            contentWidthClass,
                            storyHeader,
                            shareBarString,
                            fontStyleClass,
                            fontSizeClass,
                            [appDelegate.activeStory objectForKey:@"story_content"],
                            sharingHtmlString,
                            commentString,
                            footerString
                            ];

    NSLog(@"\n\n\n\nhtmlString:\n\n\n%@\n\n\n", htmlString);
    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    
    [webView loadHTMLString:htmlString
                    //baseURL:[NSURL URLWithString:feed_link]];
                    baseURL:baseURL];
    
    
    NSDictionary *feed;
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", 
                           [appDelegate.activeStory 
                            objectForKey:@"story_feed_id"]];
                           
    if (appDelegate.isSocialView || appDelegate.isSocialRiverView) {
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
    
    [self setNextPreviousButtons];
}

- (void)setActiveStory {
    self.activeStoryId = [appDelegate.activeStory objectForKey:@"id"];  
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        if (!appDelegate.isSocialView) {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"story_feed_id"]];
            UIImage *titleImage = appDelegate.isRiverView ?
            [UIImage imageNamed:@"folder_white.png"] :
            [Utilities getImage:feedIdStr];
            UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
            titleImageView.frame = CGRectMake(0.0, 2.0, 16.0, 16.0);
            titleImageView.hidden = YES;
            self.navigationItem.titleView = titleImageView; 
            titleImageView.hidden = NO;
        } else {
            
            NSString *feedIdStr = [NSString stringWithFormat:@"%@", [appDelegate.activeFeed objectForKey:@"id"]];
            UIImage *titleImage  = [Utilities getImage:feedIdStr];
            titleImage = [Utilities roundCorneredImage:titleImage radius:6];
            
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
            imageView.frame = CGRectMake(0.0, 0.0, 28.0, 28.0);
            [imageView setImage:titleImage];
            self.navigationItem.titleView = imageView;        
        }
    }
}

- (BOOL)webView:(UIWebView *)webView 
shouldStartLoadWithRequest:(NSURLRequest *)request 
 navigationType:(UIWebViewNavigationType)navigationType {
    NSURL *url = [request URL];
    NSArray *urlComponents = [url pathComponents];
    NSString *action = @"";
    if ([urlComponents count] > 1) {
         action = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:1]];
    }
                              
    // HACK: Using ios.newsblur.com to intercept the javascript share, reply, and edit events.
    // the pathComponents do not work correctly unless it is a correctly formed url
    // Is there a better way?  Someone show me the light
    if ([[url host] isEqualToString: @"ios.newsblur.com"]){
        // reset the active comment
        appDelegate.activeComment = nil;
        appDelegate.activeShareType = action;
        
        if ([action isEqualToString:@"reply"] || 
            [action isEqualToString:@"edit-reply"] ||
            [action isEqualToString:@"edit-share"] ||
            [action isEqualToString:@"like-comment"] ||
            [action isEqualToString:@"unlike-comment"]) {

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
            
            if (appDelegate.activeComment == nil) {
                NSLog(@"PROBLEM! the active comment was not found in friend or public comments");
                return NO;
            }
            
            if ([action isEqualToString:@"reply"]) {
                [appDelegate showShareView:@"reply"
                                 setUserId:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]]
                               setUsername:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:3]]
                                setReplyId:nil];
            } else if ([action isEqualToString:@"edit-reply"]) {
                [appDelegate showShareView:@"edit-reply"
                                 setUserId:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]]
                               setUsername:nil
                                setReplyId:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:4]]];
            } else if ([action isEqualToString:@"edit-share"]) {
                [appDelegate showShareView:@"edit-share"
                                 setUserId:nil
                               setUsername:nil
                                setReplyId:nil];
            } else if ([action isEqualToString:@"like-comment"]) {
                [self toggleLikeComment:YES];
            } else if ([action isEqualToString:@"unlike-comment"]) {
                [self toggleLikeComment:NO];
            }
            return NO; 
        } else if ([action isEqualToString:@"share"]) {
            // test to see if the user has commented
            // search for the comment from friends comments
            NSArray *friendComments = [appDelegate.activeStory objectForKey:@"friend_comments"];
            NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
            for (int i = 0; i < friendComments.count; i++) {
                NSString *userId = [NSString stringWithFormat:@"%@", 
                                    [[friendComments objectAtIndex:i] objectForKey:@"user_id"]];
                if([userId isEqualToString:currentUserId]){
                    appDelegate.activeComment = [friendComments objectAtIndex:i];
                }
            }
            
            if (appDelegate.activeComment == nil) {
                [appDelegate showShareView:@"share"
                                 setUserId:nil
                               setUsername:nil
                           setReplyId:nil];
            } else {
                [appDelegate showShareView:@"edit-share"
                                 setUserId:nil
                               setUsername:nil
                           setReplyId:nil];
            }
            return NO; 
        } else if ([action isEqualToString:@"show-profile"]) {
            appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
                        
            for (int i = 0; i < appDelegate.activeFeedUserProfiles.count; i++) {
                NSString *userId = [NSString stringWithFormat:@"%@", [[appDelegate.activeFeedUserProfiles objectAtIndex:i] objectForKey:@"user_id"]];
                if ([userId isEqualToString:appDelegate.activeUserProfileId]){
                    appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@", [[appDelegate.activeFeedUserProfiles objectAtIndex:i] objectForKey:@"username"]];
                    break;
                }
            }
            
            
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
    CGRect frame = CGRectZero;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
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
        
        frame = CGRectMake(x, y, width, height);
    } 
    [appDelegate showUserProfileModal:[NSValue valueWithCGRect:frame]];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];    
    if ([userPreferences integerForKey:@"fontSizing"]){
        [self changeFontSize:[userPreferences stringForKey:@"fontSizing"]];
    }

}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];    
    if ([userPreferences integerForKey:@"fontSizing"]){
        [self changeFontSize:[userPreferences stringForKey:@"fontSizing"]];
    }
    
    // see if it's a tryfeed for animation
    if (appDelegate.tryFeedCategory) {
        if ([appDelegate.tryFeedCategory isEqualToString:@"comment_like"] ||
            [appDelegate.tryFeedCategory isEqualToString:@"comment_reply"]) {
            NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
            NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true, true);", currentUserId];
            [self.webView stringByEvaluatingJavaScriptFromString:jsFlashString];
        } else if ([appDelegate.tryFeedCategory isEqualToString:@"story_reshare"]) {
            NSString *blurblogUserId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory objectForKey:@"social_user_id"]];
            NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true);", blurblogUserId];
            [self.webView stringByEvaluatingJavaScriptFromString:jsFlashString];

        }
        appDelegate.tryFeedCategory = nil;
    }
}

#pragma mark -
#pragma mark Actions

- (IBAction)tapProgressBar:(id)sender {
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
	hud.mode = MBProgressHUDModeText;
	hud.removeFromSuperViewOnHide = YES;  
    int unreadCount = appDelegate.unreadCount;
    if (unreadCount == 0) {
        hud.labelText = @"No unread stories";
    } else if (unreadCount == 1) {
        hud.labelText = @"1 story left";
    } else {
        hud.labelText = [NSString stringWithFormat:@"%i stories left", unreadCount]; 
    }
	[hud hide:YES afterDelay:0.8];
}

- (void)setNextPreviousButtons {
    // setting up the PREV BUTTON
    int readStoryCount = [appDelegate.readStories count];
    if (readStoryCount == 0 || 
        (readStoryCount == 1 && 
        [appDelegate.readStories lastObject] == [appDelegate.activeStory objectForKey:@"id"])) {
        [buttonPrevious setStyle:UIBarButtonItemStyleBordered];
        [buttonPrevious setTitle:@"Previous"];
        [buttonPrevious setEnabled:NO];
    } else {
        [buttonPrevious setStyle:UIBarButtonItemStyleBordered];
        [buttonPrevious setTitle:@"Previous"];
        [buttonPrevious setEnabled:YES];
    }

    // setting up the NEXT UNREAD STORY BUTTON
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
    
    float unreads = (float)[appDelegate unreadCount];
    float total = [appDelegate originalStoryCount];
    float progress = (total - unreads) / total;
    [progressView setProgress:progress];
}

- (void)markStoryAsRead {
//    NSLog(@"[appDelegate.activeStory objectForKey:@read_status] intValue] %i", [[appDelegate.activeStory objectForKey:@"read_status"] intValue]);
    if ([[appDelegate.activeStory objectForKey:@"read_status"] intValue] != 1) {
        
        [appDelegate markActiveStoryRead];

        NSString *urlString;        
        if (appDelegate.isSocialView || appDelegate.isSocialRiverView) {
            urlString = [NSString stringWithFormat:@"http://%@/reader/mark_social_stories_as_read",
                        NEWSBLUR_URL];
        } else {
            urlString = [NSString stringWithFormat:@"http://%@/reader/mark_story_as_read",
                         NEWSBLUR_URL];
        }

        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        
        if (appDelegate.isSocialRiverView) {
            // grab the user id from the shared_by_friends
            NSArray *storyId = [NSArray arrayWithObject:[appDelegate.activeStory objectForKey:@"id"]];
            NSLog(@"[appDelegate.activeStory objectForKey:@shared_by_friends] %@", [appDelegate.activeStory objectForKey:@"shared_by_friends"]);
            NSString *friendUserId;
            
            if ([[appDelegate.activeStory objectForKey:@"shared_by_friends"] count]) {
                friendUserId = [NSString stringWithFormat:@"%@", 
                                          [[appDelegate.activeStory objectForKey:@"shared_by_friends"] objectAtIndex:0]];
            } else {
                friendUserId = [NSString stringWithFormat:@"%@", 
                                          [[appDelegate.activeStory objectForKey:@"commented_by_friends"] objectAtIndex:0]];
            }

            NSDictionary *feedStory = [NSDictionary dictionaryWithObject:storyId 
                                                                  forKey:[NSString stringWithFormat:@"%@", 
                                                                          [appDelegate.activeStory objectForKey:@"story_feed_id"]]];
            
            NSDictionary *usersFeedsStories = [NSDictionary dictionaryWithObject:feedStory 
                                                                          forKey:friendUserId];
            
            [request setPostValue:[usersFeedsStories JSONRepresentation] forKey:@"users_feeds_stories"]; 
        } else if (appDelegate.isSocialView) {
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

- (void)toggleLikeComment:(BOOL)likeComment {
    [self showShareHUD];
    NSString *urlString;
    if (likeComment) {
        urlString = [NSString stringWithFormat:@"http://%@/social/like_comment",
                               NEWSBLUR_URL];
    } else {
        urlString = [NSString stringWithFormat:@"http://%@/social/remove_like_comment",
                               NEWSBLUR_URL];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    
    [request setPostValue:[appDelegate.activeStory 
                   objectForKey:@"id"] 
           forKey:@"story_id"];
    [request setPostValue:[appDelegate.activeStory 
                           objectForKey:@"story_feed_id"] 
                   forKey:@"story_feed_id"];
    

    [request setPostValue:[appDelegate.activeComment objectForKey:@"user_id"] forKey:@"comment_user_id"];
    
    [request setDidFinishSelector:@selector(finishLikeComment:)];
    [request setDidFailSelector:@selector(finishedWithError:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)finishLikeComment:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    // add the comment into the activeStory dictionary
    NSDictionary *newStory = [DataUtilities updateComment:results for:appDelegate];

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
    
    [self refreshComments:@"like"];
} 


- (void)requestFailed:(ASIHTTPRequest *)request {    
    NSLog(@"Error in mark as read is %@", [request error]);
}

- (void)finishMarkAsRead:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    NSLog(@"results in mark as read is %@", results);
} 

# pragma mark
# pragma mark Subscribing to blurblog

- (void)subscribeToBlurblog {
    [self showFollowingHUD];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/follow",
                     NEWSBLUR_URL];
    
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    [request setPostValue:[appDelegate.activeFeed 
                           objectForKey:@"user_id"] 
                   forKey:@"user_id"];

    [request setDidFinishSelector:@selector(finishSubscribeToBlurblog:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
} 

- (void)finishSubscribeToBlurblog:(ASIHTTPRequest *)request {
    self.storyHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
    self.storyHUD.mode = MBProgressHUDModeCustomView;
    self.storyHUD.removeFromSuperViewOnHide = YES;  
    self.storyHUD.labelText = @"Followed";
    [self.storyHUD hide:YES afterDelay:1];
    self.navigationItem.leftBarButtonItem = nil;
    [appDelegate reloadFeedsView:NO];
//    [appDelegate.feedDetailViewController resetFeedDetail];
//    [appDelegate.feedDetailViewController fetchFeedDetail:1 withCallback:nil];
}

- (void)showShareHUD {
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    self.storyHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.storyHUD.labelText = @"Sharing";
    self.storyHUD.margin = 20.0f;
}

- (void)showFollowingHUD {
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    self.storyHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.storyHUD.labelText = @"Following";
    self.storyHUD.margin = 20.0f;
}

- (void)showFindingStoryHUD {
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    self.storyHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.storyHUD.labelText = @"Loading Story";
    self.storyHUD.margin = 20.0f;
    self.noStorySelectedLabel.hidden = YES;
}

- (void)refreshComments:(NSString *)replyId {
    NSString *shareBarString = [self getShareBar];  
    
    NSString *commentString = [self getComments];  
    NSString *jsString = [[NSString alloc] initWithFormat:@
                          "document.getElementById('NB-comments-wrapper').innerHTML = '%@';"
                          "document.getElementById('NB-share-bar-wrapper').innerHTML = '%@';",
                          commentString, 
                          shareBarString];
    NSString *shareType = appDelegate.activeShareType;
    
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
    
    if (!replyId) {
        NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
        NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true);", currentUserId];
        [self.webView stringByEvaluatingJavaScriptFromString:jsFlashString];
    } else if ([replyId isEqualToString:@"like"]) {
        
    } else {
        NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true);", replyId];
        [self.webView stringByEvaluatingJavaScriptFromString:jsFlashString];
    }
    

//    // adding in a simulated delay
//    sleep(4);
    
    self.storyHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
    self.storyHUD.mode = MBProgressHUDModeCustomView;
    self.storyHUD.removeFromSuperViewOnHide = YES;  
    
    if ([shareType isEqualToString:@"reply"]) {
        self.storyHUD.labelText = @"Replied";
    } else if ([shareType isEqualToString:@"edit-reply"]) {
        self.storyHUD.labelText = @"Edited Reply";
    } else if ([shareType isEqualToString:@"edit-share"]) {
        self.storyHUD.labelText = @"Edited Comment";
    } else if ([shareType isEqualToString:@"share"]) {
        self.storyHUD.labelText = @"Shared";
    } else if ([shareType isEqualToString:@"like-comment"]) {
        self.storyHUD.labelText = @"Favorited";
    } else if ([shareType isEqualToString:@"unlike-comment"]) {
        self.storyHUD.labelText = @"Unfavorited";
    }
    [self.storyHUD hide:YES afterDelay:1];
}

- (void)scrolltoComment {
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
    NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true);", currentUserId];
    [self.webView stringByEvaluatingJavaScriptFromString:jsFlashString];
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

        [appDelegate changeActiveFeedDetailRow];
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:.5];
        [UIView setAnimationBeginsFromCurrentState:NO];
        [UIView setAnimationTransition:UIViewAnimationTransitionCurlUp 
                               forView:self.webView 
                                 cache:NO];
        [UIView commitAnimations];
    }
}

- (IBAction)doNextStory {
    
    int nextIndex = [appDelegate indexOfNextStory];
    
    NSLog(@"nextIndex is %i", nextIndex);
    
    [self.loadingIndicator stopAnimating];
    
    if (self.appDelegate.feedDetailViewController.pageFetching) {
        return;
    }
    
    if (nextIndex == -1 && 
        self.appDelegate.feedDetailViewController.feedPage < 50 &&
        !self.appDelegate.feedDetailViewController.pageFinished &&
        !self.appDelegate.feedDetailViewController.pageFetching) {
                
        // Fetch next page and see if it has the unreads.
        [self.loadingIndicator startAnimating];
        self.activity.customView = self.loadingIndicator;
        [self.appDelegate.feedDetailViewController fetchNextPage:^() {
            [self doNextStory];
        }];
    } else if (nextIndex == -1) {
        [MBProgressHUD hideHUDForView:self.view animated:NO];
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeText;
        hud.removeFromSuperViewOnHide = YES;  
        hud.labelText = @"No stories left";
        [hud hide:YES afterDelay:0.8];
    } else {
        [appDelegate setActiveStory:[[appDelegate activeFeedStories] 
                                     objectAtIndex:nextIndex]];
        [appDelegate pushReadStory:[appDelegate.activeStory objectForKey:@"id"]];
        [self setActiveStory];
        [self showStory];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [appDelegate changeActiveFeedDetailRow];        
        }
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:.5];
        [UIView setAnimationBeginsFromCurrentState:NO];
        [UIView setAnimationTransition:UIViewAnimationTransitionCurlUp 
                               forView:self.webView 
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
        [appDelegate hideStoryDetailView];
    } else {
        int previousIndex = [appDelegate locationOfStoryId:previousStoryId];
        if (previousIndex == -1) {
            return [self doPreviousStory];
        }
        [appDelegate setActiveStory:[[appDelegate activeFeedStories] 
                                     objectAtIndex:previousIndex]];
        [self setActiveStory];
        [self showStory];
        [appDelegate changeActiveFeedDetailRow];
        
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:.5];
        [UIView setAnimationBeginsFromCurrentState:NO];
        [UIView setAnimationTransition:UIViewAnimationTransitionCurlDown 
                               forView:self.webView 
                                 cache:NO];
        [UIView commitAnimations];
    }
}

- (void)changeWebViewWidth:(int)width {
    int contentWidth = self.view.frame.size.width;
    NSString *contentWidthClass;
    
    if (contentWidth > 740) {
        contentWidthClass = @"NB-ipad-wide";
    } else if (contentWidth > 480) {
        contentWidthClass = @"NB-ipad-narrow";
    } else {
        contentWidthClass = @"NB-iphone";
    }
    
    NSString *jsString = [[NSString alloc] initWithFormat:
                          @"$('body').attr('class', '%@');"
                          "document.getElementById(\"viewport\").setAttribute(\"content\", \"width=%i;initial-scale=1; maximum-scale=1.0; user-scalable=0;\");",
                          contentWidthClass,
                          contentWidth];
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
}

- (IBAction)toggleFontSize:(id)sender {
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
//        if (popoverController == nil) {
//            popoverController = [[UIPopoverController alloc]
//                                 initWithContentViewController:appDelegate.fontSettingsViewController];
//            
//            popoverController.delegate = self;
//        } else {
//            if (popoverController.isPopoverVisible) {
//                [popoverController dismissPopoverAnimated:YES];
//                return;
//            }
//            
//            [popoverController setContentViewController:appDelegate.fontSettingsViewController];
//        }
//        
//        [popoverController setPopoverContentSize:CGSizeMake(274.0, 130.0)];
//        UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] 
//                                           initWithCustomView:sender];
//        
//        [popoverController presentPopoverFromBarButtonItem:settingsButton
//                                  permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
//    } else {
//        FontSettingsViewController *fontSettings = [[FontSettingsViewController alloc] init];
//        appDelegate.fontSettingsViewController = fontSettings;
//        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:appDelegate.fontSettingsViewController];
//        
//        // adding Done button
//        UIBarButtonItem *donebutton = [[UIBarButtonItem alloc]
//                                       initWithTitle:@"Done" 
//                                       style:UIBarButtonItemStyleDone 
//                                       target:self 
//                                       action:@selector(hideToggleFontSize)];
//        
//        appDelegate.fontSettingsViewController.navigationItem.rightBarButtonItem = donebutton;
//        appDelegate.fontSettingsViewController.navigationItem.title = @"Style";
//        navController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
//        [self presentModalViewController:navController animated:YES];
//        
//    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController showFontSettingsPopover:sender];
    } else {
        if (self.popoverController == nil) {
            self.popoverController = [[WEPopoverController alloc]
                                      initWithContentViewController:appDelegate.fontSettingsViewController];
            
            self.popoverController.delegate = self;
        } else {
            [self.popoverController dismissPopoverAnimated:YES];
            self.popoverController = nil;
        }
        
        if ([self.popoverController respondsToSelector:@selector(setContainerViewProperties:)]) {
            [self.popoverController setContainerViewProperties:[self improvedContainerViewProperties]];
        }
        [self.popoverController setPopoverContentSize:CGSizeMake(274, 130)];
        [self.popoverController presentPopoverFromBarButtonItem:self.fontSettingsButton
                                       permittedArrowDirections:UIPopoverArrowDirectionAny 
                                                       animated:YES];
    }
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

- (IBAction)showOriginalSubview:(id)sender {
    NSURL *url = [NSURL URLWithString:[appDelegate.activeStory 
                                       objectForKey:@"story_permalink"]];
    [appDelegate showOriginalStory:url];
}

- (NSString *)textToHtml:(NSString*)htmlString {
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"'"  withString:@"&#039;"];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"\n"  withString:@"<br/>"];
    return htmlString;
}

#pragma mark -
#pragma mark WEPopoverControllerDelegate implementation

- (void)popoverControllerDidDismissPopover:(WEPopoverController *)thePopoverController {
	//Safe to release the popover here
	self.popoverController = nil;
}

- (BOOL)popoverControllerShouldDismissPopover:(WEPopoverController *)thePopoverController {
	//The popover is automatically dismissed if you click outside it, unless you return NO here
	return YES;
}


/**
 Thanks to Paul Solt for supplying these background images and container view properties
 */
- (WEPopoverContainerViewProperties *)improvedContainerViewProperties {
	
	WEPopoverContainerViewProperties *props = [WEPopoverContainerViewProperties alloc];
	NSString *bgImageName = nil;
	CGFloat bgMargin = 0.0;
	CGFloat bgCapSize = 0.0;
	CGFloat contentMargin = 5.0;
	
	bgImageName = @"popoverBg.png";
	
	// These constants are determined by the popoverBg.png image file and are image dependent
	bgMargin = 13; // margin width of 13 pixels on all sides popoverBg.png (62 pixels wide - 36 pixel background) / 2 == 26 / 2 == 13 
	bgCapSize = 31; // ImageSize/2  == 62 / 2 == 31 pixels
	
	props.leftBgMargin = bgMargin;
	props.rightBgMargin = bgMargin;
	props.topBgMargin = bgMargin;
	props.bottomBgMargin = bgMargin;
	props.leftBgCapSize = bgCapSize;
	props.topBgCapSize = bgCapSize;
	props.bgImageName = bgImageName;
	props.leftContentMargin = contentMargin;
	props.rightContentMargin = contentMargin - 1; // Need to shift one pixel for border to look correct
	props.topContentMargin = contentMargin; 
	props.bottomContentMargin = contentMargin;
	
	props.arrowMargin = 4.0;
	
	props.upArrowImageName = @"popoverArrowUp.png";
	props.downArrowImageName = @"popoverArrowDown.png";
	props.leftArrowImageName = @"popoverArrowLeft.png";
	props.rightArrowImageName = @"popoverArrowRight.png";
	return props;	
}




@end
