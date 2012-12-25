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
    UILabel *titleLabel = (UILabel *)[appDelegate makeFeedTitle:appDelegate.activeFeed];
    titleLabel.shadowColor = UIColorFromRGB(0x306070);
    navBar.topItem.titleView = titleLabel;
    
    [self.webView loadHTMLString:[self makeTrainerSections] baseURL:nil];
}


#pragma mark -
#pragma mark Story layout

- (NSString *)makeTrainerSections {
    NSString *storyAuthor = [self makeAuthor];
    NSString *storyTags = [self makeTags];
    NSString *storyTitle = [self makeTitle];
    NSString *storyPublisher = [self makePublisher];
    
    NSString *storyHeader = [NSString stringWithFormat:@
                             "<div class=\"NB-trainer\"><div class=\"NB-trainer-inner\">"
                             "<div class=\"NB-trainer-title\">%@</div>"
                             "<div class=\"NB-trainer-author\">%@</div>"
                             "<div class=\"NB-trainer-tags\">%@</div>"
                             "<div class=\"NB-trainer-publisher\">%@</div>"
                             "</div></div>",
                             storyTitle,
                             storyAuthor,
                             storyTags,
                             storyPublisher];
    return storyHeader;
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
            storyAuthor = [NSString stringWithFormat:@"<a href=\"http://ios.newsblur.com/classify-author/%@\" "
                           "class=\"NB-story-author %@\" id=\"NB-story-author\"><div class=\"NB-highlight\"></div>%@</a>",
                           author,
                           authorScore > 0 ? @"NB-story-author-positive" : authorScore < 0 ? @"NB-story-author-negative" : @"",
                           author];
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
                NSString *tagHtml = [NSString stringWithFormat:@"<a href=\"http://ios.newsblur.com/classify-tag/%@\" "
                                     "class=\"NB-story-tag %@\"><div class=\"NB-highlight\"></div>%@</a>",
                                     tag,
                                     tagScore > 0 ? @"NB-story-tag-positive" : tagScore < 0 ? @"NB-story-tag-negative" : @"",
                                     tag];
                [tagStrings addObject:tagHtml];
            }
            storyTags = [NSString
                         stringWithFormat:@"<div id=\"NB-story-tags\" class=\"NB-story-tags\">"
                         "%@"
                         "</div>",
                         [tagStrings componentsJoinedByString:@""]];
        }
    }

    return storyTags;
}
- (NSString *)makePublisher {
    NSString *feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory
                                                          objectForKey:@"story_feed_id"]];
    NSString *storyPublisher = [NSString stringWithFormat:@"%@", [[appDelegate.dictFeeds objectForKey:feedId] objectForKey:@"feed_title"]];
    return storyPublisher;
}

- (NSString *)makeTitle {
    NSString *feedId = [NSString stringWithFormat:@"%@", [appDelegate.activeStory
                                                          objectForKey:@"story_feed_id"]];
    NSString *storyTitle = [appDelegate.activeStory objectForKey:@"story_title"];
    NSMutableDictionary *titleClassifiers = [[appDelegate.activeClassifiers objectForKey:feedId]
                                             objectForKey:@"titles"];
    for (NSString *titleClassifier in titleClassifiers) {
        if ([storyTitle containsString:titleClassifier]) {
            int titleScore = [[titleClassifiers objectForKey:titleClassifier] intValue];
            storyTitle = [storyTitle
                          stringByReplacingOccurrencesOfString:titleClassifier
                          withString:[NSString stringWithFormat:@"<span class=\"NB-story-title-%@\">%@</span>",
                                      titleScore > 0 ? @"positive" : titleScore < 0 ? @"negative" : @"",
                                      titleClassifier]];
        }
    }
    
    return storyTitle;
}

#pragma mark -
#pragma mark Actions

- (IBAction)doCloseDialog:(id)sender {
    [appDelegate.trainerViewController dismissModalViewControllerAnimated:YES];
}

@end
