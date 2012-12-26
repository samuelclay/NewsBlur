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
    NSString *storyAuthor = [self makeAuthor];
    NSString *storyTags = [self makeTags];
    NSString *storyTitle = [self makeTitle];
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

- (NSString *)makeAuthor {
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
                           "       class=\"NB-story-author %@\" id=\"NB-story-author\"><div class=\"NB-highlight\"></div>%@</a>"
                           "  </div>"
                           "</div>",
                           author,
                           authorScore > 0 ? @"NB-story-author-positive" : authorScore < 0 ? @"NB-story-author-negative" : @"",
                           [self makeClassifier:author withType:@"Author"]];
        }
    }
    return storyAuthor;
}

- (NSString *)makeTags {
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
                NSString *tagHtml = [NSString stringWithFormat:@"<div class=\"NB-trainer-tag\">"
                                     "  <a href=\"http://ios.newsblur.com/classify-tag/%@\" "
                                     "     class=\"NB-story-tag %@\"><div class=\"NB-highlight\"></div>%@</a>"
                                     "</div>",
                                     tag,
                                     tagScore > 0 ? @"NB-story-tag-positive" : tagScore < 0 ? @"NB-story-tag-negative" : @"",
                                     [self makeClassifier:tag withType:@"Tag"]];
                [tagStrings addObject:tagHtml];
            }
            storyTags = [NSString
                         stringWithFormat:@"<div class=\"NB-trainer-section-inner\">"
                         "  <div class=\"NB-trainer-section-title\">Story Tags</div>"
                         "  <div class=\"NB-trainer-section-body\">"
                         "    <div id=\"NB-story-tags\" class=\"NB-story-tags\">"
                         "      %@"
                         "    </div>"
                         "  </div>"
                         "</div>",
                         [tagStrings componentsJoinedByString:@""]];
        }
    }

    return storyTags;
}
- (NSString *)makePublisher {
    NSString *feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory
                                                          objectForKey:@"story_feed_id"]];
    NSString *feedTitle = [[appDelegate.dictFeeds objectForKey:feedId] objectForKey:@"feed_title"];
    
    NSString *storyPublisher = [NSString stringWithFormat:@"<div class=\"NB-trainer-section-inner\">"
                                "  <div class=\"NB-trainer-section-title\">Publisher</div>"
                                "  <div class=\"NB-trainer-section-body\">"
                                "    %@"
                                "  </div>"
                                "</div",
                                [self makeClassifier:feedTitle withType:@"Publisher"]];
    
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
                              "    <div class=\"NB-title-info\">Tap and hold the title below</div>"
                              "    <div class=\"NB-title-trainer\">%@</div>"
                              "  </div>"
                              "</div>", storyTitle];
    return titleTrainer;
}

- (NSString *)makeClassifier:(NSString *)classifierName withType:(NSString *)classifierType {
    NSString *classifier = [NSString stringWithFormat:@"<span class=\"NB-classifier NB-classifier-%@\">"
                            "<div class=\"NB-classifier-icon-like\"></div>"
                            "<div class=\"NB-classifier-icon-dislike\">"
                            "  <div class=\"NB-classifier-icon-dislike-inner\"></div>"
                            "</div>"
                            "<label><b>%@: </b><span>%@</span></label>"
                            "</span>",
                            classifierType,
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
    NSLog(@"changeTitle: %@", sender);
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
