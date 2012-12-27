//
//  TrainerViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 12/24/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "TrainerViewController.h"
#import "StringHelper.h"

@implementation TrainerViewController

@synthesize closeButton;
@synthesize webView;
@synthesize navBar;
@synthesize appDelegate;
@synthesize feedTrainer;
@synthesize storyTrainer;

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
    
    navBar.tintColor = UIColorFromRGB(0x183353);
    [self hideGradientBackground:webView];
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
    [[UIMenuController sharedMenuController]
     setMenuItems:[NSArray arrayWithObjects:
                   [[UIMenuItem alloc] initWithTitle:@"👎 Hide" action:@selector(changeTitle:)],
                   [[UIMenuItem alloc] initWithTitle:@"👍 Focus" action:@selector(changeTitle:)],
                   nil]];
    
    UILabel *titleLabel = (UILabel *)[appDelegate makeFeedTitle:appDelegate.activeFeed];
    titleLabel.shadowColor = UIColorFromRGB(0x306070);
    navBar.topItem.titleView = titleLabel;

    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    
    [self.webView loadHTMLString:[self makeTrainerSections] baseURL:baseURL];
}

- (void)viewDidAppear:(BOOL)animated {
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [[UIMenuController sharedMenuController] setMenuItems:nil];
}

#pragma mark -
#pragma mark Story layout

- (NSString *)makeTrainerSections {
    NSString *storyAuthor = self.feedTrainer ? [self makeFeedAuthors] : [self makeStoryAuthor];
    NSString *storyTags = self.feedTrainer ? [self makeFeedTags] : [self makeStoryTags];
    NSString *storyTitle = self.feedTrainer ? @"" : [self makeTitle];
    NSString *storyPublisher = [self makePublisher];
    
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
                            "  <div class=\"NB-trainer\"><div class=\"NB-trainer-inner\">"
                            "    <div class=\"NB-trainer-title NB-trainer-section\">%@</div>"
                            "    <div class=\"NB-trainer-author NB-trainer-section\">%@</div>"
                            "    <div class=\"NB-trainer-tags NB-trainer-section\">%@</div>"
                            "    <div class=\"NB-trainer-publisher NB-trainer-section\">%@</div>"
                            "  </div></div>"
                            "%@" // footer
                            "</body>"
                            "</html>",
                            headerString,
                            contentWidthClass,
                            storyTitle,
                            storyAuthor,
                            storyTags,
                            storyPublisher,
                            footerString
                            ];
    
    //    NSLog(@"\n\n\n\nhtmlString:\n\n\n%@\n\n\n", htmlString);

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
            int authorScore = [[[[appDelegate.activeClassifiers objectForKey:feedId]
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
    NSString *feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeFeed objectForKey:@"id"]];
    NSString *feedAuthors = @"";
    NSArray *authorArray = appDelegate.activePopularAuthors;
    
    if ([authorArray count] > 0) {
        NSMutableArray *authorStrings = [NSMutableArray array];
        for (NSArray *authorObj in authorArray) {
            NSString *author = [authorObj objectAtIndex:0];
            int authorCount = [[authorObj objectAtIndex:1] intValue];
            int authorScore = [[[[appDelegate.activeClassifiers objectForKey:feedId]
                              objectForKey:@"authors"]
                             objectForKey:author] intValue];
            NSString *authorHtml = [NSString stringWithFormat:@"<div class=\"NB-classifier-container\">"
                                    "  <a href=\"http://ios.newsblur.com/classify-author/%@\" "
                                    "     class=\"NB-story-author %@\">%@</a>"
                                    "  <span class=\"NB-classifier-count\">&times;&nbsp; %d</span>"
                                    "</div>",
                                    author,
                                    authorScore > 0 ? @"NB-story-author-positive" : authorScore < 0 ? @"NB-story-author-negative" : @"",
                                    [self makeClassifier:author withType:@"author" score:authorScore],
                                    authorCount];
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
    NSString *feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory
                                                          objectForKey:@"story_feed_id"]];
    NSString *storyTags = @"";
    
    if ([appDelegate.activeStory objectForKey:@"story_tags"]) {
        NSArray *tagArray = [appDelegate.activeStory objectForKey:@"story_tags"];
        if ([tagArray count] > 0) {
            NSMutableArray *tagStrings = [NSMutableArray array];
            for (NSString *tag in tagArray) {
                int tagScore = [[[[appDelegate.activeClassifiers objectForKey:feedId]
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
    NSString *feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeFeed objectForKey:@"id"]];
    NSString *feedTags = @"";
    NSArray *tagArray = appDelegate.activePopularTags;
    
    if ([tagArray count] > 0) {
        NSMutableArray *tagStrings = [NSMutableArray array];
        for (NSArray *tagObj in tagArray) {
            NSString *tag = [tagObj objectAtIndex:0];
            int tagCount = [[tagObj objectAtIndex:1] intValue];
            int tagScore = [[[[appDelegate.activeClassifiers objectForKey:feedId]
                              objectForKey:@"tags"]
                             objectForKey:tag] intValue];
            NSString *tagHtml = [NSString stringWithFormat:@"<div class=\"NB-classifier-container\">"
                                 "  <a href=\"http://ios.newsblur.com/classify-tag/%@\" "
                                 "     class=\"NB-story-tag %@\">%@</a>"
                                 "  <span class=\"NB-classifier-count\">&times;&nbsp; %d</span>"
                                 "</div>",
                                 tag,
                                 tagScore > 0 ? @"NB-story-tag-positive" : tagScore < 0 ? @"NB-story-tag-negative" : @"",
                                 [self makeClassifier:tag withType:@"Tag" score:tagScore],
                                 tagCount];
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
        feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeFeed objectForKey:@"id"]];
        feedTitle = [appDelegate.activeFeed objectForKey:@"feed_title"];
    } else {
        feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory
                                                    objectForKey:@"story_feed_id"]];
        feedTitle = [[appDelegate.dictFeeds objectForKey:feedId] objectForKey:@"feed_title"];
    }
    int publisherScore = [[[[appDelegate.activeClassifiers objectForKey:feedId]
                            objectForKey:@"feeds"] objectForKey:feedId] intValue];
    
    NSString *storyPublisher = [NSString stringWithFormat:@"<div class=\"NB-trainer-section-inner\">"
                                "  <div class=\"NB-trainer-section-title\">Publisher</div>"
                                "  <div class=\"NB-trainer-section-body\">"
                                "    <div class=\"NB-classifier-container\">"
                                "      <a href=\"http://ios.newsblur.com/classify-publisher/%@\" "
                                "         class=\"NB-story-publisher %@\">%@</a>"
                                "    </div>"
                                "  </div>"
                                "</div",
                                feedId,
                                publisherScore > 0 ? @"NB-story-publisher-positive" : publisherScore < 0 ? @"NB-story-publisher-negative" : @"",
                                [self makeClassifier:feedTitle withType:@"publisher" score:publisherScore]];
    
    return storyPublisher;
}

- (NSString *)makeTitle {
    NSString *feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory
                                                          objectForKey:@"story_feed_id"]];
    NSString *storyTitle = [appDelegate.activeStory objectForKey:@"story_title"];

    if (!storyTitle) {
        return @"";
    }
    
    NSMutableDictionary *titleClassifiers = [[appDelegate.activeClassifiers objectForKey:feedId]
                                             objectForKey:@"titles"];
    for (NSString *titleClassifier in titleClassifiers) {
        if ([storyTitle containsString:titleClassifier]) {
            int titleScore = [[titleClassifiers objectForKey:titleClassifier] intValue];
            storyTitle = [storyTitle
                          stringByReplacingOccurrencesOfString:titleClassifier
                          withString:[NSString stringWithFormat:@"  <span class=\"NB-story-title-%@\">%@</span>",
                                      titleScore > 0 ? @"positive" : titleScore < 0 ? @"negative" : @"",
                                      titleClassifier]];
        }
    }
    
    NSString *titleTrainer = [NSString stringWithFormat:@"<div class=\"NB-trainer-section-inner\">"
                              "  <div class=\"NB-trainer-section-title\">Story Title</div>"
                              "  <div class=\"NB-trainer-section-body NB-title\">"
                              "    <div class=\"NB-title-trainer\">%@</div>"
                              "    <div class=\"NB-title-info\">Tap and hold the title</div>"
                              "  </div>"
                              "</div>", storyTitle];
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
    [appDelegate.trainerViewController dismissModalViewControllerAnimated:YES];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(changeTitle:)) {
        return YES;
    } else {
        return NO;
    }
}

- (void)changeTitle:(id)sender {
    NSString *selectedTitle = [self.webView stringByEvaluatingJavaScriptFromString:@"window.getSelection().toString()"];
    NSLog(@"Selected: %@", selectedTitle);
}

@end


@implementation TrainerWebView

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(changeTitle:)) {
        return YES;
    } else {
        return NO;
    }
}

- (void)changeTitle:(id)sender {
    NewsBlurAppDelegate *appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    [appDelegate.trainerViewController changeTitle:sender];
}

@end
