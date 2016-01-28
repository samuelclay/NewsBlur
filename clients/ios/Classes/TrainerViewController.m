//
//  TrainerViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 12/24/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "TrainerViewController.h"
#import "NBContainerViewController.h"
#import "StringHelper.h"
#import "Utilities.h"
#import "Base64.h"
#import "AFNetworking.h"
#import "StoriesCollection.h"

@implementation TrainerViewController

@synthesize closeButton;
@synthesize webView;
@synthesize navBar;
@synthesize appDelegate;
@synthesize feedTrainer;
@synthesize storyTrainer;
@synthesize feedLoaded;

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
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    UIBarButtonItem *done = [[UIBarButtonItem alloc]
                             initWithTitle:@"Done Training"
                             style:UIBarButtonSystemItemDone
                             target:self
                             action:@selector(doCloseDialog:)];
    self.navigationItem.rightBarButtonItem = done;
    
    [self hideGradientBackground:webView];
    [self.webView.scrollView setDelaysContentTouches:YES];
    [self.webView.scrollView setDecelerationRate:UIScrollViewDecelerationRateNormal];

    // Work around iOS 9 issue where menu doesn't appear the first time
    // http://stackoverflow.com/questions/32685198/
    [self.webView becomeFirstResponder];
}
- (void) hideGradientBackground:(UIView*)theView
{
    for (UIView * subview in theView.subviews)
    {
        if ([subview isKindOfClass:[UIImageView class]])
            subview.hidden = YES;
        
        [self hideGradientBackground:subview];
    }
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[UIMenuController sharedMenuController]
     setMenuItems:[NSArray arrayWithObjects:
                   [[UIMenuItem alloc] initWithTitle:@"👎 Hide" action:@selector(hideTitle:)],
                   [[UIMenuItem alloc] initWithTitle:@"👍 Focus" action:@selector(focusTitle:)],
                   nil]];
    
    UILabel *titleLabel = (UILabel *)[appDelegate makeFeedTitle:appDelegate.storiesCollection.activeFeed];
    self.navigationItem.titleView = titleLabel;
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    
    if (!feedLoaded) {
        MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        HUD.labelText = @"Loading trainer...";
        NSString *feedId = [self feedId];
        NSURL *url = [NSURL URLWithString:[NSString
                                           stringWithFormat:@"%@/reader/feeds_trainer?feed_id=%@",
                                           self.appDelegate.url, feedId]];

        __weak __typeof(&*self)weakSelf = self;
        AFHTTPRequestOperation *request = [[AFHTTPRequestOperation alloc] initWithRequest:[NSURLRequest requestWithURL:url]];
        [request setResponseSerializer:[AFJSONResponseSerializer serializer]];
        [request setCompletionBlockWithSuccess:^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject) {
            __strong __typeof(&*weakSelf)strongSelf = weakSelf;
            if (!strongSelf) return;
            [MBProgressHUD hideHUDForView:strongSelf.view animated:YES];
            NSDictionary *results = [responseObject objectAtIndex:0];
            NSMutableDictionary *newClassifiers = [[results objectForKey:@"classifiers"] mutableCopy];
            [appDelegate.storiesCollection.activeClassifiers setObject:newClassifiers
                                                                forKey:feedId];
            appDelegate.storiesCollection.activePopularAuthors = [results objectForKey:@"feed_authors"];
            appDelegate.storiesCollection.activePopularTags = [results objectForKey:@"feed_tags"];
            [self renderTrainer];
        } failure:^(AFHTTPRequestOperation * _Nonnull operation, NSError * _Nonnull error) {
            NSLog(@"Failed fetch trainer: %@", error);
            [self informError:@"Could not load trainer"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^() {
                if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                    [appDelegate hidePopover];
                } else {
                    [appDelegate.navigationController dismissViewControllerAnimated:YES completion:nil];
                }
            });
        }];
        [request start];
    } else {
        [self renderTrainer];
    }
}

- (NSString *)feedId {
    NSString *feedId;
    if (appDelegate.storiesCollection.activeFeed &&
        !appDelegate.storiesCollection.isSocialView) {
        feedId = [NSString stringWithFormat:@"%@",
                  [appDelegate.storiesCollection.activeFeed objectForKey:@"id"]];
    } else if (appDelegate.activeStory) {
        feedId = [NSString stringWithFormat:@"%@",
                  [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    }
    return feedId;
}

- (void)renderTrainer {
    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    [self.webView loadHTMLString:[self makeTrainerHTML] baseURL:baseURL];
}

- (void)refresh {
    if (self.view.hidden || self.view.superview == nil) {
        NSLog(@"Trainer hidden, ignoring redraw.");
        return;
    }
    NSString *headerString = [[[self makeTrainerSections]
                               stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"]
                              stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *jsString = [NSString stringWithFormat:@"document.getElementById('NB-trainer').innerHTML = '%@';",
                          headerString];
    
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
    
    [self.webView stringByEvaluatingJavaScriptFromString:@"attachFastClick({skipEvent: true});"];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self.webView loadHTMLString:@"" baseURL:[NSURL URLWithString:@"about:blank"]];
    [[UIMenuController sharedMenuController] setMenuItems:nil];
}

#pragma mark -
#pragma mark Story layout

- (NSString *)makeTrainerHTML {
    NSString *trainerSections = [self makeTrainerSections];
    
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
    NSString *headerString = [NSString stringWithFormat:@
                              "<link rel=\"stylesheet\" type=\"text/css\" href=\"trainer.css\" >"
                              "<meta name=\"viewport\" id=\"viewport\" content=\"width=%i, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\"/>",
                              contentWidth];
    NSString *footerString = [NSString stringWithFormat:@
                              "<script src=\"zepto.js\"></script>"
                              "<script src=\"trainer.js\"></script>"
                              "<script src=\"fastTouch.js\"></script>"];
    
    NSString *htmlString = [NSString stringWithFormat:@
                            "<html>"
                            "<head>%@</head>" // header string
                            "<body id=\"trainer\" class=\"%@\">"
                            "<div class=\"NB-trainer\" id=\"NB-trainer\">%@</div>"
                            "%@" // footer
                            "</body>"
                            "</html>",
                            headerString,
                            contentWidthClass,
                            trainerSections,
                            footerString
                            ];
    
    //    NSLog(@"\n\n\n\nhtmlString:\n\n\n%@\n\n\n", htmlString);

    return htmlString;
}

- (NSString *)makeTrainerSections {
    NSString *storyAuthor = self.feedTrainer ? [self makeFeedAuthors] : [self makeStoryAuthor];
    NSString *storyTags = self.feedTrainer ? [self makeFeedTags] : [self makeStoryTags];
    NSString *storyTitle = self.feedTrainer ? [self makeFeedTitles] : [self makeTitle];
    NSString *storyPublisher = [self makePublisher];
    
    NSString *htmlString = [NSString stringWithFormat:@
                            "<div class=\"NB-trainer-inner\">"
                            "    <div class=\"NB-trainer-title NB-trainer-section\">%@</div>"
                            "    <div class=\"NB-trainer-author NB-trainer-section\">%@</div>"
                            "    <div class=\"NB-trainer-tags NB-trainer-section\">%@</div>"
                            "    <div class=\"NB-trainer-publisher NB-trainer-section\">%@</div>"
                            "</div>",
                            storyTitle,
                            storyAuthor,
                            storyTags,
                            storyPublisher];
    
    return htmlString;
}
- (NSString *)makeStoryAuthor {
    NSString *feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory
                                                          objectForKey:@"story_feed_id"]];
    NSString *storyAuthor = @"";
    
    if ([[appDelegate.activeStory objectForKey:@"story_authors"] class] != [NSNull class] &&
        [[appDelegate.activeStory objectForKey:@"story_authors"] length]) {
        NSString *author = [NSString stringWithFormat:@"%@",
                            [appDelegate.activeStory objectForKey:@"story_authors"]];
        if (author && [author class] != [NSNull class]) {
            int authorScore = [[[[appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
                                 objectForKey:@"authors"]
                                objectForKey:author] intValue];
            storyAuthor = [NSString stringWithFormat:@"<div class=\"NB-trainer-section-inner\">"
                           "  <div class=\"NB-trainer-section-title\">Story Authors</div>"
                           "  <div class=\"NB-trainer-section-body\">"
                           "    <a href=\"http://ios.newsblur.com/classify-author/%@\" "
                           "       class=\"NB-story-author %@\">%@</a>"
                           "  </div>"
                           "</div>",
                           author,
                           authorScore > 0 ? @"NB-story-author-positive" : authorScore < 0 ? @"NB-story-author-negative" : @"",
                           [self makeClassifier:author withType:@"Author" score:authorScore]];
        }
    }
    return storyAuthor;
}

- (NSString *)makeFeedAuthors {
    NSString *feedId = [self feedId];
    NSString *feedAuthors = @"";
    NSArray *authorArray = appDelegate.storiesCollection.activePopularAuthors;
    NSMutableArray *userAuthorArray = [NSMutableArray array];
    for (NSString *trainedAuthor in [[[appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
                                      objectForKey:@"authors"] allKeys]) {
        BOOL found = NO;
        for (NSArray *classifierAuthor in authorArray) {
            if ([trainedAuthor isEqualToString:[classifierAuthor objectAtIndex:0]]) {
                found = YES;
                break;
            }
        }
        if (!found) {
            [userAuthorArray addObject:@[trainedAuthor, [NSNumber numberWithInt:0]]];
        }
    }
    NSArray *authors = [userAuthorArray arrayByAddingObjectsFromArray:authorArray];

    if ([authors count] > 0) {
        NSMutableArray *authorStrings = [NSMutableArray array];
        for (NSArray *authorObj in authors) {
            NSString *author = [authorObj objectAtIndex:0];
            int authorCount = [[authorObj objectAtIndex:1] intValue];
            int authorScore = [[[[appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
                              objectForKey:@"authors"]
                             objectForKey:author] intValue];
            NSString *authorCountString = @"";
            if (authorCount) {
                authorCountString = [NSString stringWithFormat:@"<span class=\"NB-classifier-count\">&times;&nbsp; %d</span>",
                                  authorCount];
            }
            NSString *authorHtml = [NSString stringWithFormat:@"<div class=\"NB-classifier-container\">"
                                    "  <a href=\"http://ios.newsblur.com/classify-author/%@\" "
                                    "     class=\"NB-story-author %@\">%@</a>"
                                    "  %@"
                                    "</div>",
                                    author,
                                    authorScore > 0 ? @"NB-story-author-positive" : authorScore < 0 ? @"NB-story-author-negative" : @"",
                                    [self makeClassifier:author withType:@"author" score:authorScore],
                                    authorCountString];
            [authorStrings addObject:authorHtml];
        }
        feedAuthors = [NSString
                       stringWithFormat:@"<div class=\"NB-trainer-section-inner\">"
                       "  <div class=\"NB-trainer-section-title\">Authors</div>"
                       "  <div class=\"NB-trainer-section-body\">"
                       "    <div class=\"NB-story-authors\">"
                       "      %@"
                       "    </div>"
                       "  </div>"
                       "</div>",
                       [authorStrings componentsJoinedByString:@""]];
    }
    
    return feedAuthors;
}


- (NSString *)makeStoryTags {
    NSString *feedId = [self feedId];
    NSString *storyTags = @"";
    
    if ([appDelegate.activeStory objectForKey:@"story_tags"]) {
        NSArray *tagArray = [appDelegate.activeStory objectForKey:@"story_tags"];
        if ([tagArray count] > 0) {
            NSMutableArray *tagStrings = [NSMutableArray array];
            for (NSString *tag in tagArray) {
                int tagScore = [[[[appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
                                  objectForKey:@"tags"]
                                 objectForKey:tag] intValue];
                NSString *tagHtml = [NSString stringWithFormat:@"<div class=\"NB-classifier-container\">"
                                     "  <a href=\"http://ios.newsblur.com/classify-tag/%@\" "
                                     "     class=\"NB-story-tag %@\">%@</a>"
                                     "</div>",
                                     tag,
                                     tagScore > 0 ? @"NB-story-tag-positive" : tagScore < 0 ? @"NB-story-tag-negative" : @"",
                                     [self makeClassifier:tag withType:@"Tag" score:tagScore]];
                [tagStrings addObject:tagHtml];
            }
            storyTags = [NSString
                         stringWithFormat:@"<div class=\"NB-trainer-section-inner\">"
                         "  <div class=\"NB-trainer-section-title\">Story Tags</div>"
                         "  <div class=\"NB-trainer-section-body\">"
                         "    <div class=\"NB-story-tags\">"
                         "      %@"
                         "    </div>"
                         "  </div>"
                         "</div>",
                         [tagStrings componentsJoinedByString:@""]];
        }
    }

    return storyTags;
}

- (NSString *)makeFeedTags {
    NSString *feedId = [self feedId];
    NSString *feedTags = @"";
    NSArray *tagArray = appDelegate.storiesCollection.activePopularTags;
    NSMutableArray *userTagArray = [NSMutableArray array];
    for (NSString *trainedTag in [[[appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
                                   objectForKey:@"tags"] allKeys]) {
        BOOL found = NO;
        for (NSArray *classifierTag in tagArray) {
            if ([trainedTag isEqualToString:[classifierTag objectAtIndex:0]]) {
                found = YES;
                break;
            }
        }
        if (!found) {
            [userTagArray addObject:@[trainedTag, [NSNumber numberWithInt:0]]];
        }
    }
    NSArray *tags = [userTagArray arrayByAddingObjectsFromArray:tagArray];

    if ([tags count] > 0) {
        NSMutableArray *tagStrings = [NSMutableArray array];
        for (NSArray *tagObj in tags) {
            NSString *tag = [tagObj objectAtIndex:0];
            int tagCount = [[tagObj objectAtIndex:1] intValue];
            int tagScore = [[[[appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
                              objectForKey:@"tags"]
                             objectForKey:tag] intValue];
            NSString *tagCountString = @"";
            if (tagCount) {
                tagCountString = [NSString stringWithFormat:@"<span class=\"NB-classifier-count\">&times;&nbsp; %d</span>",
                                  tagCount];
            }
            NSString *tagHtml = [NSString stringWithFormat:@"<div class=\"NB-classifier-container\">"
                                 "  <a href=\"http://ios.newsblur.com/classify-tag/%@\" "
                                 "     class=\"NB-story-tag %@\">%@</a>"
                                 "  %@"
                                 "</div>",
                                 tag,
                                 tagScore > 0 ? @"NB-story-tag-positive" : tagScore < 0 ? @"NB-story-tag-negative" : @"",
                                 [self makeClassifier:tag withType:@"Tag" score:tagScore],
                                 tagCountString];
            [tagStrings addObject:tagHtml];
        }
        feedTags = [NSString
                    stringWithFormat:@"<div class=\"NB-trainer-section-inner\">"
                    "  <div class=\"NB-trainer-section-title\">Story Tags</div>"
                    "  <div class=\"NB-trainer-section-body\">"
                    "    <div class=\"NB-story-tags\">"
                    "      %@"
                    "    </div>"
                    "  </div>"
                    "</div>",
                    [tagStrings componentsJoinedByString:@""]];
    }
    
    return feedTags;
}

- (NSString *)makePublisher {
    NSString *feedId;
    NSString *feedTitle;
    
    if (self.feedTrainer) {
        feedId = [NSString stringWithFormat:@"%@", [appDelegate.storiesCollection.activeFeed objectForKey:@"id"]];
        feedTitle = [appDelegate.storiesCollection.activeFeed objectForKey:@"feed_title"];
    } else {
        feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory
                                                    objectForKey:@"story_feed_id"]];
        NSDictionary *feed = [appDelegate getFeed:feedId];
        feedTitle = [feed objectForKey:@"feed_title"];
    }
    int publisherScore = [[[[appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
                            objectForKey:@"feeds"] objectForKey:feedId] intValue];
    
    UIImage *favicon = [appDelegate getFavicon:feedId];
    NSData *faviconData = UIImagePNGRepresentation(favicon);
    NSString *feedImageUrl = [NSString stringWithFormat:@"data:image/png;charset=utf-8;base64,%@",
                              [faviconData base64Encoding]];
    NSString *publisherTitle = [NSString stringWithFormat:@"<img class=\"feed_favicon\" src=\"%@\"> %@",
                                feedImageUrl, feedTitle];
    NSString *storyPublisher = [NSString stringWithFormat:@"<div class=\"NB-trainer-section-inner\">"
                                "  <div class=\"NB-trainer-section-title\">Publisher</div>"
                                "  <div class=\"NB-trainer-section-body\">"
                                "    <div class=\"NB-classifier-container\">"
                                "      <a href=\"http://ios.newsblur.com/classify-feed/%@\" "
                                "         class=\"NB-story-publisher NB-story-publisher-%@\">%@</a>"
                                "    </div>"
                                "  </div>"
                                "</div",
                                feedId,
                                publisherScore > 0 ? @"positive" : publisherScore < 0 ? @"negative" : @"",
                                [self makeClassifier:publisherTitle
                                            withType:@"publisher"
                                               score:publisherScore]];
    
    return storyPublisher;
}

- (NSString *)makeTitle {
    NSString *feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory
                                                          objectForKey:@"story_feed_id"]];
    NSString *storyTitle = [appDelegate.activeStory objectForKey:@"story_title"];
    
    if (!storyTitle) {
        return @"";
    }
    
    NSMutableDictionary *classifiers = [[appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
                                             objectForKey:@"titles"];
    NSMutableArray *titleStrings = [NSMutableArray array];
    for (NSString *title in classifiers) {
        if ([storyTitle containsString:title]) {
            int titleScore = [[classifiers objectForKey:title] intValue];
            NSString *titleClassifier = [NSString stringWithFormat:@
                                         "<div class=\"NB-classifier-container\">"
                                         "  <a href=\"http://ios.newsblur.com/classify-title/%@\" "
                                         "     class=\"NB-story-title NB-story-title-%@\">%@</a>"
                                         "</div>",
                                         title,
                                         titleScore > 0 ? @"positive" : titleScore < 0 ? @"negative" : @"",
                                         [self makeClassifier:title withType:@"title" score:titleScore]];
            [titleStrings addObject:titleClassifier];
        }
    }
    
    NSString *titleClassifiers;
    if ([titleStrings count]) {
        titleClassifiers = [titleStrings componentsJoinedByString:@""];
    } else {
        titleClassifiers = @"<div class=\"NB-title-info\">Tap and hold the title</div>";
    }
    NSString *titleTrainer = [NSString stringWithFormat:@"<div class=\"NB-trainer-section-inner\">"
                              "  <div class=\"NB-trainer-section-title\">Story Title</div>"
                              "  <div class=\"NB-trainer-section-body NB-title\">"
                              "    <div class=\"NB-title-trainer\">"
                              "      <span>%@</span>"
                              "    </div>"
                              "    %@"
                              "  </div>"
                              "</div>", storyTitle, titleClassifiers];
    return titleTrainer;
}

- (NSString *)makeFeedTitles {
    NSString *feedId = [self feedId];
    NSMutableDictionary *classifiers = [[appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
                                        objectForKey:@"titles"];
    NSMutableArray *titleStrings = [NSMutableArray array];
    for (NSString *title in classifiers) {
        int titleScore = [[classifiers objectForKey:title] intValue];
        NSString *titleClassifier = [NSString stringWithFormat:@
                                     "<div class=\"NB-classifier-container\">"
                                     "  <a href=\"http://ios.newsblur.com/classify-title/%@\" "
                                     "     class=\"NB-story-title NB-story-title-%@\">%@</a>"
                                     "</div>",
                                     title,
                                     titleScore > 0 ? @"positive" : titleScore < 0 ? @"negative" : @"",
                                     [self makeClassifier:title withType:@"title" score:titleScore]];
        [titleStrings addObject:titleClassifier];
    }
    
    NSString *titleClassifiers = [titleStrings componentsJoinedByString:@""];
    NSString *titleTrainer = [NSString stringWithFormat:@"<div class=\"NB-trainer-section-inner\">"
                              "  <div class=\"NB-trainer-section-title\">Story Titles</div>"
                              "  <div class=\"NB-trainer-section-body\">"
                              "    <div class=\"NB-story-titles\">"
                              "      %@"
                              "    </div>"
                              "  </div>"
                              "</div>", titleClassifiers];
    return titleTrainer;
}


- (NSString *)makeClassifier:(NSString *)classifierName withType:(NSString *)classifierType score:(int)score {
    NSString *classifier = [NSString stringWithFormat:@"<span class=\"NB-classifier NB-classifier-%@ NB-classifier-%@\">"
                            "<div class=\"NB-classifier-icon-like\"></div>"
                            "<div class=\"NB-classifier-icon-dislike\">"
                            "  <div class=\"NB-classifier-icon-dislike-inner\"></div>"
                            "</div>"
                            "<label><b>%@: </b><span>%@</span></label>"
                            "</span>",
                            classifierType,
                            score > 0 ? @"like" : score < 0 ? @"dislike" : @"",
                            classifierType,
                            classifierName];
    
    return classifier;
}

#pragma mark -
#pragma mark Actions

- (IBAction)doCloseDialog:(id)sender {
    [appDelegate hidePopover];
    [appDelegate.trainerViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)changeTitle:(id)sender score:(int)score {
    NSString *feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory
                                                          objectForKey:@"story_feed_id"]];
    NSString *selectedTitle = [self.webView
                               stringByEvaluatingJavaScriptFromString:@"window.getSelection().toString()"];

    [self.appDelegate toggleTitleClassifier:selectedTitle feedId:feedId score:score];
}


- (BOOL)webView:(UIWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType {
    NSURL *url = [request URL];
    NSArray *urlComponents = [url pathComponents];
    NSString *action = @"";
    NSString *feedId = [self feedId];
    
    if ([urlComponents count] > 1) {
        action = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:1]];
    }
    
    NSLog(@"Tapped url: %@", url);
    if ([[url host] isEqualToString: @"ios.newsblur.com"]){
        
        if ([action isEqualToString:@"classify-author"]) {
            NSString *author = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
            [self.appDelegate toggleAuthorClassifier:author feedId:feedId];
            return NO;
        } else if ([action isEqualToString:@"classify-tag"]) {
            NSString *tag = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
            [self.appDelegate toggleTagClassifier:tag feedId:feedId];
            return NO;
        } else if ([action isEqualToString:@"classify-title"]) {
            NSString *title = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
            [self.appDelegate toggleTitleClassifier:title feedId:feedId score:0];
            return NO;
        } else if ([action isEqualToString:@"classify-feed"]) {
            NSString *feedId = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
            [self.appDelegate toggleFeedClassifier:feedId];
            return NO;
        }
    }
    
    return YES;
}

@end


@implementation TrainerWebView

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(focusTitle:) || action == @selector(hideTitle:)) {
        return YES;
    } else {
        return NO;
    }
}

- (void)focusTitle:(id)sender {
    NewsBlurAppDelegate *appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    [appDelegate.trainerViewController changeTitle:sender score:1];
}

- (void)hideTitle:(id)sender {
    NewsBlurAppDelegate *appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    [appDelegate.trainerViewController changeTitle:sender score:-1];
}

// Work around iOS 9 issue where menu doesn't appear the first time
// http://stackoverflow.com/questions/32685198/
- (BOOL)canBecomeFirstResponder {
    return YES;
}

@end
