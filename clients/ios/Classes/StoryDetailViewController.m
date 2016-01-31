//
//  StoryDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "StoryDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NewsBlurViewController.h"
#import "FeedDetailViewController.h"
#import "FontSettingsViewController.h"
#import "UserProfileViewController.h"
#import "ShareViewController.h"
#import "StoryPageControl.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "AFHTTPRequestOperation.h"
#import "Base64.h"
#import "Utilities.h"
#import "NSString+HTML.h"
#import "NBContainerViewController.h"
#import "DataUtilities.h"
#import "FMDatabase.h"
#import "SBJson4.h"
#import "StringHelper.h"
#import "StoriesCollection.h"
#import "UIWebView+Offsets.h"
#import "UIView+ViewController.h"
#import "JNWThrottledBlock.h"

@interface StoryDetailViewController () <WKNavigationDelegate>

@end

@implementation StoryDetailViewController

#pragma mark -
#pragma mark View boilerplate

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"estimatedProgress"];
}

- (NSString *)description {
    NSString *page = self.appDelegate.storyPageControl.currentPage == self ? @"currentPage" : self.appDelegate.storyPageControl.previousPage == self ? @"previousPage" : self.appDelegate.storyPageControl.nextPage == self ? @"nextPage" : @"unattached page";
    return [NSString stringWithFormat:@"%@", page];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback
                        error:nil];
    
    WKWebViewConfiguration *webConfig = [WKWebViewConfiguration new];
    
    if ([webConfig respondsToSelector:@selector(requiresUserActionForMediaPlayback)]) {
        webConfig.requiresUserActionForMediaPlayback = NO;
        webConfig.applicationNameForUserAgent = @"NewsBlur";
    } else {
        webConfig.mediaPlaybackRequiresUserAction = NO;
    }
    
    self.webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:webConfig];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.navigationDelegate = self;
    [self.view addSubview:self.webView];
    
//    self.webView.scalesPageToFit = YES;
//    self.webView.multipleTouchEnabled = NO;
    
    [self.webView.scrollView setDelaysContentTouches:NO];
    [self.webView.scrollView setDecelerationRate:UIScrollViewDecelerationRateNormal];
    [self.webView.scrollView setAutoresizesSubviews:(UIViewAutoresizingFlexibleWidth |
                                                     UIViewAutoresizingFlexibleHeight)];
    [self.webView.scrollView addObserver:self forKeyPath:@"contentOffset"
                                 options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                 context:nil];
    
    [self clearWebView];

//    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc]
//                                              initWithTarget:self action:@selector(showOriginalStory:)];
//    [self.webView addGestureRecognizer:pinchGesture];
    
    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc]
                                                initWithTarget:self action:@selector(doubleTap:)];
    doubleTapGesture.numberOfTapsRequired = 2;
    doubleTapGesture.delegate = self;
    [self.webView addGestureRecognizer:doubleTapGesture];
    
//    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]
//                                          initWithTarget:self action:@selector(tap:)];
//    tapGesture.numberOfTapsRequired = 1;
//    tapGesture.delegate = self;
//    [tapGesture requireGestureRecognizerToFail:doubleTapGesture];
//    [self.webView addGestureRecognizer:tapGesture];
    
    UITapGestureRecognizer *doubleDoubleTapGesture = [[UITapGestureRecognizer alloc]
                                                      initWithTarget:self
                                                      action:@selector(doubleTap:)];
    doubleDoubleTapGesture.numberOfTouchesRequired = 2;
    doubleDoubleTapGesture.numberOfTapsRequired = 2;
    doubleDoubleTapGesture.delegate = self;
    [self.webView addGestureRecognizer:doubleDoubleTapGesture];
    
    [[ThemeManager themeManager] addThemeGestureRecognizerToView:self.webView];
    
    // This makes the theme gesture work reliably, but makes scrolling more "sticky", so isn't acceptable:
//    UIGestureRecognizer *themeGesture = [[ThemeManager themeManager] addThemeGestureRecognizerToView:self.webView];
//    [self.webView.scrollView.panGestureRecognizer requireGestureRecognizerToFail:themeGesture];
    
    self.pageIndex = -2;
    self.inTextView = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tapAndHold:)
                                                 name:@"TapAndHoldNotification"
                                               object:nil];
    
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueChangeNewKey context:NULL];
    
    self.cachedOrientation = [UIApplication sharedApplication].statusBarOrientation;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
//    NSLog(@"Should conflict? \n\tgesture:%@ \n\t  other:%@",
//          gestureRecognizer, otherGestureRecognizer);
    return YES;
}

- (void)tap:(UITapGestureRecognizer *)gestureRecognizer {
//    NSLog(@"Gesture tap: %d (%d) - %d", gestureRecognizer.state, UIGestureRecognizerStateEnded, self.inDoubleTap);

    if (gestureRecognizer.state == UIGestureRecognizerStateEnded && gestureRecognizer.numberOfTouches == 1) {
        [self tapImage:gestureRecognizer];
    }
}

- (void)doubleTap:(UITapGestureRecognizer *)gestureRecognizer {
//    NSLog(@"Gesture double tap: %d (%d) - %d", gestureRecognizer.state, UIGestureRecognizerStateEnded, self.inDoubleTap);
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded && self.inDoubleTap) {
        NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
        BOOL openOriginal = NO;
        BOOL showText = NO;
        BOOL markUnread = NO;
        BOOL saveStory = NO;
        if (gestureRecognizer.numberOfTouches == 2) {
            NSString *twoFingerTap = [preferences stringForKey:@"two_finger_double_tap"];
            if ([twoFingerTap isEqualToString:@"open_original_story"]) {
                openOriginal = YES;
            } else if ([twoFingerTap isEqualToString:@"show_original_text"]) {
                showText = YES;
            } else if ([twoFingerTap isEqualToString:@"mark_unread"]) {
                markUnread = YES;
            } else if ([twoFingerTap isEqualToString:@"save_story"]) {
                saveStory = YES;
            }
        } else {
            NSString *doubleTap = [preferences stringForKey:@"double_tap_story"];
            if ([doubleTap isEqualToString:@"open_original_story"]) {
                openOriginal = YES;
            } else if ([doubleTap isEqualToString:@"show_original_text"]) {
                showText = YES;
            } else if ([doubleTap isEqualToString:@"mark_unread"]) {
                markUnread = YES;
            } else if ([doubleTap isEqualToString:@"save_story"]) {
                saveStory = YES;
            }
        }
        if (openOriginal) {
            [self showOriginalStory:gestureRecognizer];
        } else if (showText) {
            [self fetchTextView];
        } else if (markUnread) {
            [self.appDelegate.storiesCollection toggleStoryUnread];
            [self.appDelegate.feedDetailViewController reloadData];
        } else if (saveStory) {
            [self.appDelegate.storiesCollection toggleStorySaved];
            [self.appDelegate.feedDetailViewController reloadData];
        }
        self.inDoubleTap = NO;
        [self performSelector:@selector(deferredEnableScrolling) withObject:nil afterDelay:0.0];
    }
}

- (void)deferredEnableScrolling {
    self.webView.scrollView.scrollEnabled = YES;
}

- (void)viewDidUnload {
    [self setInnerView:nil];
    
    [super viewDidUnload];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (!self.appDelegate.showingSafariViewController &&
        self.appDelegate.navigationController.visibleViewController != (UIViewController *)self.appDelegate.originalStoryViewController) {
        [self clearStory];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (!self.isPhoneOrCompact) {
        [self.appDelegate.feedDetailViewController.view endEditing:YES];
    }
    [self storeScrollPosition:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (!self.isPhoneOrCompact) {
        [self.appDelegate.feedDetailViewController.view endEditing:YES];
    }

    if (self.cachedOrientation != [UIApplication sharedApplication].statusBarOrientation) {
        self.cachedOrientation = [UIApplication sharedApplication].statusBarOrientation;
        NSLog(@"Found stale orientation in story detail: %@", NSStringFromCGSize(self.view.bounds.size));
    }
    
    if (!self.hasStory) {
        [self drawStory];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Fix the position and size; can probably remove this once all views use auto layout
    CGRect viewFrame = self.view.frame;
    CGSize superSize = self.view.superview.bounds.size;
    
    if (viewFrame.size.height > superSize.height) {
        self.view.frame = CGRectMake(viewFrame.origin.x, viewFrame.origin.y, viewFrame.size.width, superSize.height);
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    self.scrollPct = self.webView.scrollView.contentOffset.y / self.webView.scrollView.contentSize.height;
//    NSLog(@"Current scroll is %2.2f%% (offset %.0f - height %.0f)", self.scrollPct*100, self.webView.scrollView.contentOffset.y,
//          self.webView.scrollView.contentSize.height);

    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        self.cachedOrientation = [UIApplication sharedApplication].statusBarOrientation;
        [self changeWebViewWidth];
        [self drawFeedGradient];
        [self scrollToLastPosition:NO];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
    }];
}

- (void)viewWillLayoutSubviews {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    [super viewWillLayoutSubviews];
    [self.appDelegate.storyPageControl layoutForInterfaceOrientation:orientation];
    [self changeWebViewWidth];
    [self drawFeedGradient];

//    NSLog(@"viewWillLayoutSubviews: %.2f", self.webView.scrollView.bounds.size.width);
}

- (void)layoutForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (interfaceOrientation != self.cachedOrientation) {
        self.cachedOrientation = interfaceOrientation;
        [self changeWebViewWidth];
        [self drawFeedGradient];
        [self drawStory];
    }
}

- (BOOL)isPhoneOrCompact {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone || self.appDelegate.isCompactWidth;
}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

#pragma mark -
#pragma mark Story setup

- (void)initStory {
    self.appDelegate.inStoryDetail = YES;
    self.noStoryMessage.hidden = YES;
    self.inTextView = NO;

    [self.appDelegate hideShareView:NO];
}

- (void)hideNoStoryMessage {
    self.noStoryMessage.hidden = YES;
}

- (void)drawStory {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    [self drawStory:NO withOrientation:orientation];
}

- (void)drawStory:(BOOL)force withOrientation:(UIInterfaceOrientation)orientation {
    if (!force && [self.activeStoryId isEqualToString:[self.activeStory objectForKey:@"story_hash"]]) {
//        NSLog(@"Already drawn story, drawing anyway: %@", [self.activeStory objectForKey:@"story_title"]);
//        return;
    }

    self.scrollPct = 0;
    self.hasScrolled = NO;
    
    NSString *shareBarString = [self getShareBar];
    NSString *commentString = [self getComments];
    NSString *headerString;
    NSString *sharingHtmlString;
    NSString *footerString;
    NSString *fontStyleClass = @"";
    NSString *customStyle = @"";
    NSString *fontSizeClass = @"NB-";
    NSString *lineSpacingClass = @"NB-line-spacing-";
    NSString *storyContent = [self.activeStory objectForKey:@"story_content"];
    if (self.inTextView && [self.activeStory objectForKey:@"original_text"]) {
        storyContent = [self.activeStory objectForKey:@"original_text"];
    }
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    fontStyleClass = [userPreferences stringForKey:@"fontStyle"];
    if (!fontStyleClass) {
        fontStyleClass = @"NB-helvetica";
    }
    
    fontSizeClass = [fontSizeClass stringByAppendingString:[userPreferences stringForKey:@"story_font_size"]];
    
    if (![fontStyleClass hasPrefix:@"NB-"]) {
        customStyle = [NSString stringWithFormat:@" style='font-family: %@;'", fontStyleClass];
    }
    
    if ([userPreferences stringForKey:@"story_line_spacing"]){
        lineSpacingClass = [lineSpacingClass stringByAppendingString:[userPreferences stringForKey:@"story_line_spacing"]];
    } else {
        lineSpacingClass = [lineSpacingClass stringByAppendingString:@"medium"];
    }
    
    int contentWidth = CGRectGetWidth(self.webView.scrollView.bounds);
    NSString *contentWidthClass;
//    NSLog(@"Drawing story: %@ / %d", [self.activeStory objectForKey:@"story_title"], contentWidth);
    
    if (UIInterfaceOrientationIsLandscape(orientation) && !self.isPhoneOrCompact) {
        contentWidthClass = @"NB-ipad-wide";
    } else if (!UIInterfaceOrientationIsLandscape(orientation) && !self.isPhoneOrCompact) {
        contentWidthClass = @"NB-ipad-narrow";
    } else if (UIInterfaceOrientationIsLandscape(orientation) && self.isPhoneOrCompact) {
        contentWidthClass = @"NB-iphone-wide";
    } else {
        contentWidthClass = @"NB-iphone";
    }
    
    contentWidthClass = [NSString stringWithFormat:@"%@ NB-width-%d",
                         contentWidthClass, (int)floorf(CGRectGetWidth(self.view.frame))];
    
    // Replace image urls that are locally cached, even when online
//    NSString *storyHash = [self.activeStory objectForKey:@"story_hash"];
//    NSArray *imageUrls = [self.appDelegate.activeCachedImages objectForKey:storyHash];
//    if (imageUrls) {
//        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
//        NSString *storyImagesDirectory = [[paths objectAtIndex:0]
//                                          stringByAppendingPathComponent:@"story_images"];
//        for (NSString *imageUrl in imageUrls) {
//            NSString *cachedImage = [storyImagesDirectory
//                                     stringByAppendingPathComponent:[Utilities md5:imageUrl]];
//            storyContent = [storyContent
//                            stringByReplacingOccurrencesOfString:imageUrl
//                            withString:cachedImage];
//        }
//    }
    
    NSString *riverClass = (self.appDelegate.storiesCollection.isRiverView ||
                            self.appDelegate.storiesCollection.isSocialView ||
                            self.appDelegate.storiesCollection.isSavedView ||
                            self.appDelegate.storiesCollection.isReadView) ?
                            @"NB-river" : @"NB-non-river";
    
    NSString *themeStyle = [ThemeManager themeManager].themeCSSSuffix;
    
    if (themeStyle.length) {
        themeStyle = [NSString stringWithFormat:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"storyDetailView%@.css\">", themeStyle];
    }
    
    // set up layout values based on iPad/iPhone
    headerString = [NSString stringWithFormat:@
                    "<link rel=\"stylesheet\" type=\"text/css\" href=\"storyDetailView.css\">%@"
                    "<meta name=\"viewport\" id=\"viewport\" content=\"width=%d, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no\"/>",
                    themeStyle, contentWidth];
    footerString = [NSString stringWithFormat:@
                    "<script src=\"zepto.js\"></script>"
                    "<script src=\"fitvid.js\"></script>"
                    "<script src=\"storyDetailView.js\"></script>"
                    "<script src=\"fastTouch.js\"></script>"];
    
    sharingHtmlString = [self getSideoptions];

    NSString *storyHeader = [self getHeader];
    NSString *htmlString = [NSString stringWithFormat:@
                            "<!DOCTYPE html>\n"
                            "<html>"
                            "<head>%@</head>" // header string
                            "<body id=\"story_pane\" class=\"%@ %@\">"
                            "    <div class=\"%@\" id=\"NB-font-style\"%@>"
                            "    <div class=\"%@\" id=\"NB-font-size\">"
                            "    <div class=\"%@\" id=\"NB-line-spacing\">"
                            "        <div id=\"NB-header-container\">%@</div>" // storyHeader
                            "        %@" // shareBar
                            "        <div id=\"NB-story\" class=\"NB-story\">%@</div>"
                            "        <div id=\"NB-sideoptions-container\">%@</div>"
                            "        <div id=\"NB-comments-wrapper\">"
                            "            %@" // friends comments
                            "        </div>"
                            "        %@"
                            "    </div>" // line-spacing
                            "    </div>" // font-size
                            "    </div>" // font-style
                            "</body>"
                            "</html>",
                            headerString,
                            contentWidthClass,
                            riverClass,
                            fontStyleClass,
                            customStyle,
                            fontSizeClass,
                            lineSpacingClass,
                            storyHeader,
                            shareBarString,
                            storyContent,
                            sharingHtmlString,
                            commentString,
                            footerString
                            ];
    
//    NSLog(@"\n\n\n\nhtmlString:\n\n\n%@\n\n\n", htmlString);
    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.hasStory = YES;
//        NSLog(@"Drawing Story: %@", [self.activeStory objectForKey:@"story_title"]);
        [self.webView loadHTMLString:htmlString baseURL:baseURL];
        [self.appDelegate.storyPageControl setTextButton:self];
    });


    self.activeStoryId = [self.activeStory objectForKey:@"story_hash"];
}

- (void)drawFeedGradient {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                           [self.activeStory
                            objectForKey:@"story_feed_id"]];
    NSDictionary *feed = [self.appDelegate getFeed:feedIdStr];
    
    if (self.feedTitleGradient) {
        [self.feedTitleGradient removeFromSuperview];
        self.feedTitleGradient = nil;
    }
    
    self.feedTitleGradient = [self.appDelegate
                              makeFeedTitleGradient:feed
                              withRect:CGRectMake(0, -1, CGRectGetWidth(self.view.bounds), 21)]; // 1024 hack for self.webView.frame.size.width
    self.feedTitleGradient.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.feedTitleGradient.tag = FEED_TITLE_GRADIENT_TAG; // Not attached yet. Remove old gradients, first.
    
    for (UIView *subview in self.webView.subviews) {
        if (subview.tag == FEED_TITLE_GRADIENT_TAG) {
            [subview removeFromSuperview];
        }
    }
    
    if (self.appDelegate.storiesCollection.isRiverView ||
        self.appDelegate.storiesCollection.isSocialView ||
        self.appDelegate.storiesCollection.isSavedView ||
        self.appDelegate.storiesCollection.isReadView) {
        self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(20, 0, 0, 0);
    } else {
        self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(9, 0, 0, 0);
    }
    [self.webView insertSubview:self.feedTitleGradient aboveSubview:self.webView.scrollView];
}

- (void)showStory {
    id storyId = [self.activeStory objectForKey:@"story_hash"];
    [self.appDelegate.storiesCollection pushReadStory:storyId];
    [self.appDelegate resetShareComments];
}

- (void)clearStory {
    self.activeStoryId = nil;
    if (self.activeStory) self.activeStoryId = [self.activeStory objectForKey:@"story_hash"];
    
    [self clearWebView];
    [MBProgressHUD hideHUDForView:self.webView animated:NO];
}

- (void)hideStory {
    self.activeStoryId = nil;
    self.webView.hidden = YES;
    self.noStoryMessage.hidden = NO;
}

#pragma mark -
#pragma mark Story layout

- (void)clearWebView {
    self.hasStory = NO;
    
    self.view.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    self.webView.hidden = YES;
    self.activityIndicator.color = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    [self.activityIndicator startAnimating];
    
    NSString *themeStyle = [ThemeManager themeManager].themeCSSSuffix;
    
    if (themeStyle.length) {
        themeStyle = [NSString stringWithFormat:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"storyDetailView%@.css\">", themeStyle];
    }
    
    NSURL *baseURL = [NSBundle mainBundle].bundleURL;
    NSString *html = [NSString stringWithFormat:@"<html>"
                      "<head><link rel=\"stylesheet\" type=\"text/css\" href=\"storyDetailView.css\">%@</head>" // header string
                      "<body></body>"
                      "</html>", themeStyle];
    
    [self.webView loadHTMLString:html baseURL:baseURL];
}

- (NSString *)getHeader {
    NSString *feedId = [NSString stringWithFormat:@"%@", [self.activeStory
                                                          objectForKey:@"story_feed_id"]];
    NSString *storyAuthor = @"";
    if ([[self.activeStory objectForKey:@"story_authors"] class] != [NSNull class] &&
        [[self.activeStory objectForKey:@"story_authors"] length]) {
        NSString *author = [NSString stringWithFormat:@"%@",
                            [self.activeStory objectForKey:@"story_authors"]];
        if (author && [author class] != [NSNull class]) {
            int authorScore = [[[[self.appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
                                 objectForKey:@"authors"]
                                objectForKey:author] intValue];
            storyAuthor = [NSString stringWithFormat:@"<span class=\"NB-middot\">&middot;</span><a href=\"http://ios.newsblur.com/classify-author/%@\" "
                           "class=\"NB-story-author %@\" id=\"NB-story-author\"><div class=\"NB-highlight\"></div>%@</a>",
                           author,
                           authorScore > 0 ? @"NB-story-author-positive" : authorScore < 0 ? @"NB-story-author-negative" : @"",
                           author];
        }
    }
    NSString *storyTags = @"";
    if ([self.activeStory objectForKey:@"story_tags"]) {
        NSArray *tagArray = [self.activeStory objectForKey:@"story_tags"];
        if ([tagArray count] > 0) {
            NSMutableArray *tagStrings = [NSMutableArray array];
            for (NSString *tag in tagArray) {
                int tagScore = [[[[self.appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
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
    NSString *storyStarred = @"";
    NSString *storyUserTags = @"";
    NSMutableArray *tagStrings = [NSMutableArray array];
    if ([self.activeStory objectForKey:@"starred"] && [self.activeStory objectForKey:@"starred_date"]) {
        storyStarred = [NSString stringWithFormat:@"<div class=\"NB-story-starred-date\">Saved on %@</div>",
                        [self.activeStory objectForKey:@"starred_date"]];
        
        if ([self.activeStory objectForKey:@"user_tags"]) {
            NSArray *tagArray = [self.activeStory objectForKey:@"user_tags"];
            if ([tagArray count] > 0) {
                for (NSString *tag in tagArray) {
                    NSString *tagHtml = [NSString stringWithFormat:@"<a href=\"http://ios.newsblur.com/remove-user-tag/%@\" "
                                         "class=\"NB-user-tag\"><div class=\"NB-highlight\"></div>%@</a>",
                                         tag,
                                         tag];
                    [tagStrings addObject:tagHtml];
                }
            }
        }

        storyUserTags = [NSString
                         stringWithFormat:@"<div id=\"NB-user-tags\" class=\"NB-user-tags\">"
                         "%@"
                         "<a class=\"NB-user-tag NB-add-user-tag\" href=\"http://ios.newsblur.com/add-user-tag/add-user-tag/\"><div class=\"NB-highlight\"></div>Add Tag</a>"
                         "</div>",
                         [tagStrings componentsJoinedByString:@""]];

    }
    
    NSString *storyUnread = @"";
    if (self.isRecentlyUnread && [self.appDelegate.storiesCollection isStoryUnread:self.activeStory]) {
        NSInteger score = [NewsBlurAppDelegate computeStoryScore:[self.activeStory objectForKey:@"intelligence"]];
        storyUnread = [NSString stringWithFormat:@"<div class=\"NB-story-unread NB-%@\"></div>",
                       score > 0 ? @"positive" : score < 0 ? @"negative" : @"neutral"];
    }
    
    NSString *storyTitle = [self.activeStory objectForKey:@"story_title"];
    NSString *storyPermalink = [self.activeStory objectForKey:@"story_permalink"];
    NSMutableDictionary *titleClassifiers = [[self.appDelegate.storiesCollection.activeClassifiers
                                              objectForKey:feedId]
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
    
    NSString *storyDate = [Utilities formatLongDateFromTimestamp:[[self.activeStory
                                                                  objectForKey:@"story_timestamp"]
                                                                  integerValue]];
    NSString *storyHeader = [NSString stringWithFormat:@
                             "<div class=\"NB-header\"><div class=\"NB-header-inner\">"
                             "<div class=\"NB-story-title\">"
                             "  %@"
                             "  <a href=\"%@\" class=\"NB-story-permalink\">%@</a>"
                             "</div>"
                             "<div class=\"NB-story-date\">%@</div>"
                             "%@"
                             "%@"
                             "%@"
                             "%@"
                             "</div></div>",
                             storyUnread,
                             storyPermalink,
                             storyTitle,
                             storyDate,
                             storyAuthor,
                             storyTags,
                             storyStarred,
                             storyUserTags];
    return storyHeader;
}

- (NSString *)getSideoptions {
    BOOL isSaved = [[self.activeStory objectForKey:@"starred"] boolValue];
    BOOL isShared = [[self.activeStory objectForKey:@"shared"] boolValue];
    
    NSString *sideoptions = [NSString stringWithFormat:@
                             "<div class='NB-sideoptions'>"
                             "<div class='NB-share-header'></div>"
                             "<div class='NB-share-wrapper'><div class='NB-share-inner-wrapper'>"
                             "  <div id=\"NB-share-button-id\" class='NB-share-button NB-train-button NB-button'>"
                             "    <a href=\"http://ios.newsblur.com/train\"><div>"
                             "      <span class=\"NB-icon\"></span> Train"
                             "    </div></a>"
                             "  </div>"
                             "  <div id=\"NB-share-button-id\" class='NB-share-button NB-button %@'>"
                             "    <a href=\"http://ios.newsblur.com/share\"><div>"
                             "      <span class=\"NB-icon\"></span> %@"
                             "    </div></a>"
                             "  </div>"
                             "  <div id=\"NB-share-button-id\" class='NB-share-button NB-save-button NB-button %@'>"
                             "    <a href=\"http://ios.newsblur.com/save/save/\"><div>"
                             "      <span class=\"NB-icon\"></span> %@"
                             "    </div></a>"
                             "  </div>"
                             "</div></div></div>",
                             isShared ? @"NB-button-active" : @"",
                             isShared ? @"Shared" : @"Share",
                             isSaved ? @"NB-button-active" : @"",
                             isSaved ? @"Saved" : @"Save"
                             ];
    
    return sideoptions;
}

- (NSString *)getAvatars:(NSString *)key {
    NSString *avatarString = @"";
    NSArray *shareUserIds = [self.activeStory objectForKey:key];
    
    for (int i = 0; i < shareUserIds.count; i++) {
        NSDictionary *user = [self.appDelegate getUser:[[shareUserIds objectAtIndex:i] intValue]];
        NSString *avatarClass = @"NB-user-avatar";
        if ([key isEqualToString:@"commented_by_public"] ||
            [key isEqualToString:@"shared_by_public"]) {
            avatarClass = @"NB-public-user NB-user-avatar";
        }
        NSString *avatar = [NSString stringWithFormat:@
                            "<div class=\"NB-story-share-profile\"><div class=\"%@\">"
                            "<a id=\"NB-user-share-bar-%@\" class=\"NB-show-profile\" "
                            " href=\"http://ios.newsblur.com/show-profile/%@\">"
                            "<div class=\"NB-highlight\"></div>"
                            "<img src=\"%@\" />"
                            "</a>"
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
    NSString *comments = @"";

    if ([self.activeStory objectForKey:@"share_count"] != [NSNull null] &&
        [[self.activeStory objectForKey:@"share_count"] intValue] > 0) {
        NSDictionary *story = self.activeStory;
        NSArray *friendsCommentsArray =  [story objectForKey:@"friend_comments"];   
        NSArray *friendsShareArray =  [story objectForKey:@"friend_shares"];
        NSArray *publicCommentsArray =  [story objectForKey:@"public_comments"];
        
        if ([[story objectForKey:@"comment_count_friends"] intValue] > 0 ) {
            comments = [comments stringByAppendingString:@"<div class=\"NB-story-comments-group NB-story-comment-friend-comments\">"];
            NSString *commentHeader = [NSString stringWithFormat:@
                                       "<div class=\"NB-story-comments-friends-header-wrapper\">"
                                       "  <div class=\"NB-story-comments-friends-header\">%i comment%@</div>"
                                       "</div>",
                                       [[story objectForKey:@"comment_count_friends"] intValue],
                                       [[story objectForKey:@"comment_count_friends"] intValue] == 1 ? @"" : @"s"];
            comments = [comments stringByAppendingString:commentHeader];
            
            // add friends comments
            comments = [comments stringByAppendingFormat:@"<div class=\"NB-feed-story-comments\">"];
            for (int i = 0; i < friendsCommentsArray.count; i++) {
                NSString *comment = [self getComment:[friendsCommentsArray objectAtIndex:i]];
                comments = [comments stringByAppendingString:comment];
            }
            comments = [comments stringByAppendingString:@"</div>"];
            comments = [comments stringByAppendingString:@"</div>"];
        }
        
        NSInteger sharedByFriendsCount = [[story objectForKey:@"shared_by_friends"] count];
        if (sharedByFriendsCount > 0 ) {
            comments = [comments stringByAppendingString:@"<div class=\"NB-story-comments-group NB-story-comment-friend-shares\">"];
            NSString *commentHeader = [NSString stringWithFormat:@
                                       "<div class=\"NB-story-comments-friend-shares-header-wrapper\">"
                                       "  <div class=\"NB-story-comments-friends-header\">%ld share%@</div>"
                                       "</div>",
                                       (long)sharedByFriendsCount,
                                       sharedByFriendsCount == 1 ? @"" : @"s"];
            comments = [comments stringByAppendingString:commentHeader];
            
            // add friend shares
            comments = [comments stringByAppendingFormat:@"<div class=\"NB-feed-story-comments\">"];
            for (int i = 0; i < friendsShareArray.count; i++) {
                NSString *comment = [self getComment:[friendsShareArray objectAtIndex:i]];
                comments = [comments stringByAppendingString:comment];
            }
            comments = [comments stringByAppendingString:@"</div>"];
            comments = [comments stringByAppendingString:@"</div>"];
        }
        
        if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"show_public_comments"] boolValue] &&
            [[story objectForKey:@"comment_count_public"] intValue] > 0 ) {
            comments = [comments stringByAppendingString:@"<div class=\"NB-story-comments-group NB-story-comment-public-comments\">"];
            NSString *publicCommentHeader = [NSString stringWithFormat:@
                                             "<div class=\"NB-story-comments-public-header-wrapper\">"
                                             "  <div class=\"NB-story-comments-public-header\">%i public comment%@</div>"
                                             "</div>",
                                             [[story objectForKey:@"comment_count_public"] intValue],
                                             [[story objectForKey:@"comment_count_public"] intValue] == 1 ? @"" : @"s"];
            
            comments = [comments stringByAppendingString:@"</div>"];
            comments = [comments stringByAppendingString:publicCommentHeader];
            comments = [comments stringByAppendingFormat:@"<div class=\"NB-feed-story-comments\">"];
            
            // add public comments
            for (int i = 0; i < publicCommentsArray.count; i++) {
                NSString *comment = [self getComment:[publicCommentsArray objectAtIndex:i]];
                comments = [comments stringByAppendingString:comment];
            }
            comments = [comments stringByAppendingString:@"</div>"];
        }
    }
    
    return comments;
}

- (NSString *)getShareBar {
    NSString *comments = @"<div id=\"NB-share-bar-wrapper\">";
    NSString *commentLabel = @"";
    NSString *shareLabel = @"";
//    NSString *replyStr = @"";
    
//    if ([[self.activeStory objectForKey:@"reply_count"] intValue] == 1) {
//        replyStr = [NSString stringWithFormat:@" and <b>1 reply</b>"];        
//    } else if ([[self.activeStory objectForKey:@"reply_count"] intValue] == 1) {
//        replyStr = [NSString stringWithFormat:@" and <b>%@ replies</b>", [self.activeStory objectForKey:@"reply_count"]];
//    }
    if (![[self.activeStory objectForKey:@"comment_count"] isKindOfClass:[NSNull class]] &&
        [[self.activeStory objectForKey:@"comment_count"] intValue]) {
        commentLabel = [commentLabel stringByAppendingString:[NSString stringWithFormat:@
                                                              "<div class=\"NB-story-comments-label\">"
                                                                "%@" // comment count
                                                                //"%@" // reply count
                                                              "</div>"
                                                              "<div class=\"NB-story-share-profiles NB-story-share-profiles-comments\">"
                                                                "%@" // friend avatars
                                                                "%@" // public avatars
                                                              "</div>",
                                                              [[self.activeStory objectForKey:@"comment_count"] intValue] == 1
                                                              ? [NSString stringWithFormat:@"<b>1 comment</b>"] :
                                                              [NSString stringWithFormat:@"<b>%@ comments</b>", [self.activeStory objectForKey:@"comment_count"]],
                                                              
                                                              //replyStr,
                                                              [self getAvatars:@"commented_by_friends"],
                                                              [self getAvatars:@"commented_by_public"]]];
    }
    
    if (![[self.activeStory objectForKey:@"share_count"] isKindOfClass:[NSNull class]] &&
        [[self.activeStory objectForKey:@"share_count"] intValue]) {
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
                                                              [[self.activeStory objectForKey:@"share_count"] intValue] == 1
                                                              ? [NSString stringWithFormat:@"<b>1 share</b>"] : 
                                                              [NSString stringWithFormat:@"<b>%@ shares</b>", [self.activeStory objectForKey:@"share_count"]]]];
    }
    
    if ([self.activeStory objectForKey:@"share_count"] != [NSNull null] &&
        [[self.activeStory objectForKey:@"share_count"] intValue] > 0) {
        
        comments = [comments stringByAppendingString:[NSString stringWithFormat:@
                                                      "<div class=\"NB-story-shares\">"
                                                        "<div class=\"NB-story-comments-shares-teaser-wrapper\">"
                                                          "<div class=\"NB-story-comments-shares-teaser\">"
                                                            "%@"
                                                            "%@"
                                                          "</div>"
                                                        "</div>"
                                                      "</div>",
                                                      commentLabel,
                                                      shareLabel
                                                      ]];
    }
    comments = [comments stringByAppendingString:[NSString stringWithFormat:@"</div>"]];
    return comments;
}

- (NSString *)getComment:(NSDictionary *)commentDict {
    NSDictionary *user = [self.appDelegate getUser:[[commentDict objectForKey:@"user_id"] intValue]];
    NSString *userAvatarClass = @"NB-user-avatar";
    NSString *userReshareString = @"";
    NSString *userEditButton = @"";
    NSString *userLikeButton = @"";
    NSString *commentUserId = [NSString stringWithFormat:@"%@", [commentDict objectForKey:@"user_id"]];
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [self.appDelegate.dictSocialProfile objectForKey:@"user_id"]];
    NSArray *likingUsersArray = [commentDict objectForKey:@"liking_users"];
    NSString *likingUsers = @"";
    
    if ([likingUsersArray count]) {
        likingUsers = @"<div class=\"NB-story-comment-likes-icon\"></div>";
        for (NSNumber *likingUser in likingUsersArray) {
            NSDictionary *sourceUser = [self.appDelegate getUser:[likingUser intValue]];
            NSString *likingUserString = [NSString stringWithFormat:@
                                          "<div class=\"NB-story-comment-likes-user\">"
                                          "    <div class=\"NB-user-avatar\"><img src=\"%@\"></div>"
                                          "</div>",
                                          [sourceUser objectForKey:@"photo_url"]];
            likingUsers = [likingUsers stringByAppendingString:likingUserString];
        }
    }
    
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
        for (int i = 0; i < likingUsersArray.count; i++) {
            if ([[[likingUsersArray objectAtIndex:i] stringValue] isEqualToString:currentUserId]) {
                isInLikingUsers = YES;
                break;
            }
        }
        
        if (isInLikingUsers) {
            userLikeButton = [NSString stringWithFormat:@
                              "<div class=\"NB-story-comment-like-button NB-button selected\">"
                              "<a href=\"http://ios.newsblur.com/unlike-comment/%@\"><div class=\"NB-story-comment-like-button-wrapper\">"
                              "<span class=\"NB-favorite-icon\"></span>"
                              "</div></a>"
                              "</div>",
                              commentUserId]; 
        } else {
            userLikeButton = [NSString stringWithFormat:@
                              "<div class=\"NB-story-comment-like-button NB-button\">"
                              "<a href=\"http://ios.newsblur.com/like-comment/%@\"><div class=\"NB-story-comment-like-button-wrapper\">"
                              "<span class=\"NB-favorite-icon\"></span>"
                              "</div></a>"
                              "</div>",
                              commentUserId]; 
        }

    }

    if ([commentDict objectForKey:@"source_user_id"] != [NSNull null]) {
        userAvatarClass = @"NB-user-avatar NB-story-comment-reshare";

        NSDictionary *sourceUser = [self.appDelegate getUser:[[commentDict objectForKey:@"source_user_id"] intValue]];
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
    
    if (location.length && ![[user objectForKey:@"location"] isKindOfClass:[NSNull class]]) {
        locationHtml = [NSString stringWithFormat:@"<div class=\"NB-story-comment-location\">%@</div>", location];
    }
    
    if (!self.isPhoneOrCompact) {
        comment = [NSString stringWithFormat:@
                    "<div class=\"NB-story-comment\" id=\"NB-user-comment-%@\">"
                    "<div class=\"%@\">"
                    "<a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\">"
                    "<div class=\"NB-highlight\"></div>"
                    "<img src=\"%@\" />"
                    "</a>"
                    "</div>"
                    "<div class=\"NB-story-comment-author-container\">"
                    "   %@"
                    "    <div class=\"NB-story-comment-username\">%@</div>"
                    "    <div class=\"NB-story-comment-date\">%@ ago</div>"
                    "    <div class=\"NB-story-comment-likes\">%@</div>"
                    "</div>"
                    "<div class=\"NB-story-comment-content\">%@</div>"
                    "%@" // location
                    "<div class=\"NB-button-wrapper\">"
                    "    <div class=\"NB-story-comment-reply-button NB-button\">"
                    "        <a href=\"http://ios.newsblur.com/reply/%@/%@\"><div class=\"NB-story-comment-reply-button-wrapper\">"
                    "            Reply"
                    "        </div></a>"
                    "    </div>"
                    "    %@" //User Like Button
                    "    %@" //User Edit Button
                    "</div>"
                    "%@"
                    "</div>",
                    [commentDict objectForKey:@"user_id"],
                    userAvatarClass,
                    [commentDict objectForKey:@"user_id"],
                    [user objectForKey:@"photo_url"],
                    userReshareString,
                    [user objectForKey:@"username"],
                    [commentDict objectForKey:@"shared_date"],
                    likingUsers,
                    commentContent,
                    locationHtml,
                    [commentDict objectForKey:@"user_id"],
                    [user objectForKey:@"username"],
                    userEditButton,
                    userLikeButton,
                    [self getReplies:[commentDict objectForKey:@"replies"] forUserId:[commentDict objectForKey:@"user_id"]]];
    } else {
        comment = [NSString stringWithFormat:@
                   "<div class=\"NB-story-comment\" id=\"NB-user-comment-%@\">"
                   "<div class=\"%@\">"
                   "<a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\">"
                   "<div class=\"NB-highlight\"></div>"
                   "<img src=\"%@\" />"
                   "</a>"
                   "</div>"
                   "<div class=\"NB-story-comment-author-container\">"
                   "    %@"
                   "    <div class=\"NB-story-comment-username\">%@</div>"
                   "    <div class=\"NB-story-comment-date\">%@ ago</div>"
                   "    <div class=\"NB-story-comment-likes\">%@</div>"
                   "</div>"
                   "<div class=\"NB-story-comment-content\">%@</div>"
                   "%@" // location
                   "<div class=\"NB-button-wrapper\">"
                   "    <div class=\"NB-story-comment-reply-button NB-button\">"
                   "        <a href=\"http://ios.newsblur.com/reply/%@/%@\"><div class=\"NB-story-comment-reply-button-wrapper\">"
                   "            Reply"
                   "        </div></a>"
                   "    </div>"
                   "    %@" // User Like Button
                   "    %@" // User Edit Button
                   "</div>"
                   "%@"
                   "</div>",
                   [commentDict objectForKey:@"user_id"],
                   userAvatarClass,
                   [commentDict objectForKey:@"user_id"],
                   [user objectForKey:@"photo_url"],
                   userReshareString,
                   [user objectForKey:@"username"],
                   [commentDict objectForKey:@"shared_date"],
                   likingUsers,
                   commentContent,
                   locationHtml,
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
            NSDictionary *user = [self.appDelegate getUser:[[replyDict objectForKey:@"user_id"] intValue]];

            NSString *userEditButton = @"";
            NSString *replyUserId = [NSString stringWithFormat:@"%@", [replyDict objectForKey:@"user_id"]];
            NSString *replyId = [replyDict objectForKey:@"reply_id"];
            NSString *currentUserId = [NSString stringWithFormat:@"%@", [self.appDelegate.dictSocialProfile objectForKey:@"user_id"]];
            
            if ([replyUserId isEqualToString:currentUserId]) {
                userEditButton = [NSString stringWithFormat:@
                                  "<div class=\"NB-story-comment-edit-button NB-story-comment-share-edit-button NB-button\">"
                                  "<a href=\"http://ios.newsblur.com/edit-reply/%@/%@/%@\">"
                                  "<div class=\"NB-story-comment-edit-button-wrapper\">"
                                  "Edit"
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
            
            if (!self.isPhoneOrCompact) {
                reply = [NSString stringWithFormat:@
                         "<div class=\"NB-story-comment-reply\" id=\"NB-user-comment-%@\">"
                         "   <a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\">"
                         "       <div class=\"NB-highlight\"></div>"
                         "       <img class=\"NB-story-comment-reply-photo\" src=\"%@\" />"
                         "   </a>"
                         "   <div class=\"NB-story-comment-username NB-story-comment-reply-username\">%@</div>"
                         "   <div class=\"NB-story-comment-date NB-story-comment-reply-date\">%@ ago</div>"
                         "   <div class=\"NB-story-comment-reply-content\">%@</div>"
                         "   %@" // location
                         "   <div class=\"NB-button-wrapper\">"
                         "       %@" // edit
                         "   </div>"
                         "</div>",
                         [replyDict objectForKey:@"reply_id"],
                         [user objectForKey:@"user_id"],
                         [user objectForKey:@"photo_url"],
                         [user objectForKey:@"username"],
                         [replyDict objectForKey:@"publish_date"],
                         replyContent,
                         locationHtml,
                         userEditButton];
            } else {
                reply = [NSString stringWithFormat:@
                         "<div class=\"NB-story-comment-reply\" id=\"NB-user-comment-%@\">"
                         "   <a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\">"
                         "       <div class=\"NB-highlight\"></div>"
                         "       <img class=\"NB-story-comment-reply-photo\" src=\"%@\" />"
                         "   </a>"
                         "   <div class=\"NB-story-comment-username NB-story-comment-reply-username\">%@</div>"
                         "   <div class=\"NB-story-comment-date NB-story-comment-reply-date\">%@ ago</div>"
                         "   <div class=\"NB-story-comment-reply-content\">%@</div>"
                         "   %@"
                         "   <div class=\"NB-button-wrapper\">"
                         "       %@" // edit
                         "   </div>"
                         "</div>",
                         [replyDict objectForKey:@"reply_id"],
                         [user objectForKey:@"user_id"],  
                         [user objectForKey:@"photo_url"],
                         [user objectForKey:@"username"],
                         [replyDict objectForKey:@"publish_date"],
                         replyContent,
                         locationHtml,
                         userEditButton];
            }
            repliesString = [repliesString stringByAppendingString:reply];
        }
        repliesString = [repliesString stringByAppendingString:@"</div>"];
    }
    return repliesString;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        [self.webView evaluateJavaScript:@"document.readyState == \"interactive\"" completionHandler:^(id isLoaded, NSError * _Nullable error) {
            if ([isLoaded boolValue]) {
                [self.activityIndicator stopAnimating];
            }
        }];
    } else if ([keyPath isEqual:@"contentOffset"]) {
        if (self.webView.scrollView.contentOffset.y < (-1 * self.feedTitleGradient.frame.size.height + 1 + self.webView.scrollView.scrollIndicatorInsets.top)) {
            // Pulling
            if (!self.pullingScrollview) {
                self.pullingScrollview = YES;
                
                for (id subview in self.webView.scrollView.subviews) {
                    UIImageView *imgView = [subview isKindOfClass:[UIImageView class]] ?
                    (UIImageView*)subview : nil;
                    // image views whose image is 1px wide are shadow images, hide them
                    if (imgView && imgView.image.size.width > 1) {
                        [self.webView.scrollView insertSubview:self.feedTitleGradient
                                                  belowSubview:subview];
                        [self.webView.scrollView bringSubviewToFront:subview];
                    }
                }
            }
        } else {
            // Normal reading
            if (self.pullingScrollview) {
                self.pullingScrollview = NO;
                [self.feedTitleGradient.layer setShadowOpacity:0];
                [self.webView insertSubview:self.feedTitleGradient aboveSubview:self.webView.scrollView];
                
                self.feedTitleGradient.frame = CGRectMake(0, -1,
                                                          self.feedTitleGradient.frame.size.width,
                                                          self.feedTitleGradient.frame.size.height);
                
                for (id subview in self.webView.scrollView.subviews) {
                    UIImageView *imgView = [subview isKindOfClass:[UIImageView class]] ?
                    (UIImageView*)subview : nil;
                    // image views whose image is 1px wide are shadow images, hide them
                    if (imgView && imgView.image.size.width == 1) {
                        imgView.hidden = NO;
                    }
                }
            }
        }
        
        if (self.appDelegate.storyPageControl.currentPage != self) return;
        if (!self.hasScrolled) self.hasScrolled = YES;

        int webpageHeight = self.webView.scrollView.contentSize.height;
        int viewportHeight = self.webView.scrollView.frame.size.height;
        int topPosition = self.webView.scrollView.contentOffset.y;
        int bottomPosition = webpageHeight - topPosition - viewportHeight;
        BOOL singlePage = webpageHeight - 200 <= viewportHeight;
        BOOL atBottom = bottomPosition < 150;
        BOOL atTop = topPosition < 10;
        if (!atTop && !atBottom && !singlePage) {
            // Hide
            [UIView animateWithDuration:.3 delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
            animations:^{
                self.appDelegate.storyPageControl.traverseView.alpha = 0;
            } completion:^(BOOL finished) {
                
            }];
        } else if (singlePage) {
            self.appDelegate.storyPageControl.traverseView.alpha = 1;
            CGRect tvf = self.appDelegate.storyPageControl.traverseView.frame;
            if (bottomPosition > 0) {
                self.appDelegate.storyPageControl.traverseView.frame = CGRectMake(tvf.origin.x,
                                                                             self.webView.scrollView.frame.size.height - tvf.size.height,
                                                                             tvf.size.width, tvf.size.height);
            } else {
                self.appDelegate.storyPageControl.traverseView.frame = CGRectMake(tvf.origin.x,
                                                                             (self.webView.scrollView.contentSize.height - self.webView.scrollView.contentOffset.y) - tvf.size.height,
                                                                             tvf.size.width, tvf.size.height);
            }
        } else if (!singlePage && (atTop && !atBottom)) {
            // Pin to bottom of viewport, regardless of scrollview
            self.appDelegate.storyPageControl.traversePinned = YES;
            self.appDelegate.storyPageControl.traverseFloating = NO;
            CGRect tvf = self.appDelegate.storyPageControl.traverseView.frame;
            self.appDelegate.storyPageControl.traverseView.frame = CGRectMake(tvf.origin.x,
                                                                         self.webView.scrollView.frame.size.height - tvf.size.height,
                                                                         tvf.size.width, tvf.size.height);
            [UIView animateWithDuration:.3 delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
             animations:^{
                self.appDelegate.storyPageControl.traverseView.alpha = 1;
            } completion:nil];
        } else if (self.appDelegate.storyPageControl.traverseView.alpha == 1 &&
                   self.appDelegate.storyPageControl.traversePinned) {
            // Scroll with bottom of scrollview, but smoothly
            self.appDelegate.storyPageControl.traverseFloating = YES;
            CGRect tvf = self.appDelegate.storyPageControl.traverseView.frame;
            [UIView animateWithDuration:.3 delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
             animations:^{
             self.appDelegate.storyPageControl.traverseView.frame = CGRectMake(tvf.origin.x,
                                                                         (self.webView.scrollView.contentSize.height - self.webView.scrollView.contentOffset.y) - tvf.size.height,
                                                                         tvf.size.width, tvf.size.height);
             } completion:^(BOOL finished) {
                 self.appDelegate.storyPageControl.traversePinned = NO;
             }];
        } else {
            // Scroll with bottom of scrollview
            self.appDelegate.storyPageControl.traversePinned = NO;
            self.appDelegate.storyPageControl.traverseFloating = YES;
            self.appDelegate.storyPageControl.traverseView.alpha = 1;
            CGRect tvf = self.appDelegate.storyPageControl.traverseView.frame;
            self.appDelegate.storyPageControl.traverseView.frame = CGRectMake(tvf.origin.x,
                                                                         (self.webView.scrollView.contentSize.height - self.webView.scrollView.contentOffset.y) - tvf.size.height,
                                                                         tvf.size.width, tvf.size.height);
        }
        
        [self storeScrollPosition:YES];
    }
}

- (NSInteger)scrollPosition {
    NSInteger updatedPos = floor(self.webView.scrollView.contentOffset.y / self.webView.scrollView.contentSize.height
                                 * 1000);
    return updatedPos;
}

- (void)storeScrollPosition:(BOOL)queue {
    __block NSInteger position = [self scrollPosition];
    __block NSDictionary *story = self.activeStory;
    __weak __typeof(&*self)weakSelf = self;

    if (position < 0) return;
    
    NSString *storyIdentifier = [NSString stringWithFormat:@"markScrollPosition:%@", [story objectForKey:@"story_hash"]];
    if (queue) {
        NSTimeInterval interval = 2;
        [JNWThrottledBlock runBlock:^{
            __strong __typeof(&*weakSelf)strongSelf = weakSelf;
            if (!strongSelf) return;
            NSInteger updatedPos = [strongSelf scrollPosition];
            [self.appDelegate markScrollPosition:updatedPos inStory:story];
        } withIdentifier:storyIdentifier throttle:interval];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,
                                                 (unsigned long)NULL), ^(void) {
            [self.appDelegate markScrollPosition:position inStory:story];
        });
    }
}

- (void)scrollToLastPosition:(BOOL)animated {
    if (self.hasScrolled) return;
    self.hasScrolled = YES;
    
    __block NSString *storyHash = [self.activeStory objectForKey:@"story_hash"];
    __weak __typeof(&*self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,
                                             (unsigned long)NULL), ^(void) {
        [self.appDelegate.database inDatabase:^(FMDatabase *db) {
            __strong __typeof(&*weakSelf)strongSelf = weakSelf;
            if (!strongSelf) {
                NSLog(@" !!! Lost strong reference to story detail vc");
                return;
            }
            FMResultSet *cursor = [db executeQuery:@"SELECT scroll, story_hash FROM story_scrolls s WHERE s.story_hash = ? LIMIT 1", storyHash];
            
            while ([cursor next]) {
                NSDictionary *story = [cursor resultDictionary];
                id scroll = [story objectForKey:@"scroll"];
                if ([scroll isKindOfClass:[NSNull class]] && !self.scrollPct) {
                    NSLog(@"No scroll found for story: %@", [strongSelf.activeStory objectForKey:@"story_title"]);
                    // No scroll found
                    continue;
                }
                if (!self.scrollPct) self.scrollPct = [scroll floatValue] / 1000.f;
                NSInteger position = floor(self.scrollPct * strongSelf.webView.scrollView.contentSize.height);
                NSInteger maxPosition = (NSInteger)(floor(strongSelf.webView.scrollView.contentSize.height - strongSelf.webView.frame.size.height));
                if (position > maxPosition) {
                    NSLog(@"Position too far, scaling back to max position: %ld > %ld", (long)position, (long)maxPosition);
                    position = maxPosition;
                }
                if (position > 0) {
                    NSLog(@"Scrolling to %ld / %.1f%% (%.f+%.f) on %@-%@", (long)position, self.scrollPct*100, strongSelf.webView.scrollView.contentSize.height, strongSelf.webView.frame.size.height, [story objectForKey:@"story_hash"], [strongSelf.activeStory objectForKey:@"story_title"]);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [strongSelf.webView.scrollView setContentOffset:CGPointMake(0, position) animated:animated];
                    });
                }
            }
            [cursor close];
            
        }];
    });
}

- (void)setActiveStoryAtIndex:(NSInteger)activeStoryIndex {
    if (activeStoryIndex >= 0) {
        self.activeStory = [[self.appDelegate.storiesCollection.activeFeedStories
                             objectAtIndex:activeStoryIndex] mutableCopy];
    } else {
        self.activeStory = [self.appDelegate.activeStory mutableCopy];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSArray *urlComponents = [url pathComponents];
    NSString *action = @"";
    NSString *feedId = [NSString stringWithFormat:@"%@", [self.activeStory
                                                          objectForKey:@"story_feed_id"]];
    if ([urlComponents count] > 1) {
         action = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:1]];
    }
    
//    NSLog(@"Tapped url: %@", url);
    // HACK: Using ios.newsblur.com to intercept the javascript share, reply, and edit events.
    // the pathComponents do not work correctly unless it is a correctly formed url
    // Is there a better way?  Someone show me the light
    if ([[url host] isEqualToString: @"ios.newsblur.com"]){
        // reset the active comment
        self.appDelegate.activeComment = nil;
        self.appDelegate.activeShareType = action;
        
        if ([action isEqualToString:@"reply"] || 
            [action isEqualToString:@"edit-reply"] ||
            [action isEqualToString:@"edit-share"] ||
            [action isEqualToString:@"like-comment"] ||
            [action isEqualToString:@"unlike-comment"]) {

            // search for the comment from friends comments and shares
            NSArray *friendComments = [self.activeStory objectForKey:@"friend_comments"];
            for (int i = 0; i < friendComments.count; i++) {
                NSString *userId = [NSString stringWithFormat:@"%@", 
                                    [[friendComments objectAtIndex:i] objectForKey:@"user_id"]];
                if([userId isEqualToString:[NSString stringWithFormat:@"%@", 
                                            [urlComponents objectAtIndex:2]]]){
                    self.appDelegate.activeComment = [friendComments objectAtIndex:i];
                }
            }
            
            
            NSArray *friendShares = [self.activeStory objectForKey:@"friend_shares"];
            for (int i = 0; i < friendShares.count; i++) {
                NSString *userId = [NSString stringWithFormat:@"%@",
                                    [[friendShares objectAtIndex:i] objectForKey:@"user_id"]];
                if([userId isEqualToString:[NSString stringWithFormat:@"%@",
                                            [urlComponents objectAtIndex:2]]]){
                    self.appDelegate.activeComment = [friendShares objectAtIndex:i];
                }
            }
            
            if (self.appDelegate.activeComment == nil) {
                NSArray *publicComments = [self.activeStory objectForKey:@"public_comments"];
                for (int i = 0; i < publicComments.count; i++) {
                    NSString *userId = [NSString stringWithFormat:@"%@", 
                                        [[publicComments objectAtIndex:i] objectForKey:@"user_id"]];
                    if([userId isEqualToString:[NSString stringWithFormat:@"%@", 
                                                [urlComponents objectAtIndex:2]]]){
                        self.appDelegate.activeComment = [publicComments objectAtIndex:i];
                    }
                }
            }
            
            if (self.appDelegate.activeComment == nil) {
                NSLog(@"PROBLEM! the active comment was not found in friend or public comments");
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
            
            if ([action isEqualToString:@"reply"]) {
                [self.appDelegate showShareView:@"reply"
                                 setUserId:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]]
                               setUsername:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:3]]
                                setReplyId:nil];
            } else if ([action isEqualToString:@"edit-reply"]) {
                [self.appDelegate showShareView:@"edit-reply"
                                 setUserId:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]]
                               setUsername:nil
                                setReplyId:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:4]]];
            } else if ([action isEqualToString:@"edit-share"]) {
                [self.appDelegate showShareView:@"edit-share"
                                 setUserId:nil
                               setUsername:nil
                                setReplyId:nil];
            } else if ([action isEqualToString:@"like-comment"]) {
                [self toggleLikeComment:YES];
            } else if ([action isEqualToString:@"unlike-comment"]) {
                [self toggleLikeComment:NO];
            }
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else if ([action isEqualToString:@"share"]) {
            [self openShareDialog];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else if ([action isEqualToString:@"train"] && [urlComponents count] > 5) {
            [self openTrainingDialog:[[urlComponents objectAtIndex:2] intValue]
                         yCoordinate:[[urlComponents objectAtIndex:3] intValue]
                               width:[[urlComponents objectAtIndex:4] intValue]
                              height:[[urlComponents objectAtIndex:5] intValue]];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else if ([action isEqualToString:@"save"]) {
            BOOL isSaved = [self.appDelegate.storiesCollection toggleStorySaved:self.activeStory];
            if (isSaved) {
                [self openUserTagsDialog:[[urlComponents objectAtIndex:3] intValue]
                             yCoordinate:[[urlComponents objectAtIndex:4] intValue]
                                   width:[[urlComponents objectAtIndex:5] intValue]
                                  height:[[urlComponents objectAtIndex:6] intValue]];
            }
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else if ([action isEqualToString:@"remove-user-tag"] || [action isEqualToString:@"add-user-tag"]) {
            [self openUserTagsDialog:[[urlComponents objectAtIndex:3] intValue]
                         yCoordinate:[[urlComponents objectAtIndex:4] intValue]
                               width:[[urlComponents objectAtIndex:5] intValue]
                              height:[[urlComponents objectAtIndex:6] intValue]];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else if ([action isEqualToString:@"classify-author"]) {
            NSString *author = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
            [self.appDelegate toggleAuthorClassifier:author feedId:feedId];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else if ([action isEqualToString:@"classify-tag"]) {
            NSString *tag = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
            [self.appDelegate toggleTagClassifier:tag feedId:feedId];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else if ([action isEqualToString:@"show-profile"] && [urlComponents count] > 6) {
            self.appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
                        
            for (int i = 0; i < self.appDelegate.storiesCollection.activeFeedUserProfiles.count; i++) {
                NSString *userId = [NSString stringWithFormat:@"%@", [[self.appDelegate.storiesCollection.activeFeedUserProfiles objectAtIndex:i] objectForKey:@"user_id"]];
                if ([userId isEqualToString:self.appDelegate.activeUserProfileId]){
                    self.appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@", [[self.appDelegate.storiesCollection.activeFeedUserProfiles objectAtIndex:i] objectForKey:@"username"]];
                    break;
                }
            }
            
            [self showUserProfile:[urlComponents objectAtIndex:2]
                      xCoordinate:[[urlComponents objectAtIndex:3] intValue] 
                      yCoordinate:[[urlComponents objectAtIndex:4] intValue] 
                            width:[[urlComponents objectAtIndex:5] intValue] 
                           height:[[urlComponents objectAtIndex:6] intValue]];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
    } else if ([url.host hasSuffix:@"itunes.apple.com"]) {
        [[UIApplication sharedApplication] openURL:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    if (navigationAction.navigationType == UIWebViewNavigationTypeLinkClicked) {
//        NSLog(@"Link clicked, views: %@ = %@", self.appDelegate.navigationController.topViewController, self.appDelegate.masterContainerViewController.childViewControllers);
        if (self.appDelegate.isPresentingActivities) {
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
        
        [self.appDelegate showOriginalStory:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)showOriginalStory:(UIGestureRecognizer *)gesture {
    NSURL *url = [NSURL URLWithString:[self.appDelegate.activeStory
                                       objectForKey:@"story_permalink"]];
    [self.appDelegate hidePopover];

    if (!gesture || [gesture isKindOfClass:[UITapGestureRecognizer class]]) {
        [self.appDelegate showOriginalStory:url];
        return;
    }
    
    if ([gesture isKindOfClass:[UIPinchGestureRecognizer class]] &&
        gesture.state == UIGestureRecognizerStateChanged &&
        [gesture numberOfTouches] >= 2) {
        CGPoint touch1 = [gesture locationOfTouch:0 inView:self.view];
        CGPoint touch2 = [gesture locationOfTouch:1 inView:self.view];
        CGPoint slope = CGPointMake(touch2.x-touch1.x, touch2.y-touch1.y);
        CGFloat distance = sqrtf(slope.x*slope.x + slope.y*slope.y);
        CGFloat scale = [(UIPinchGestureRecognizer *)gesture scale];
        
//        NSLog(@"Gesture: %f - %f", [(UIPinchGestureRecognizer *)gesture scale], distance);
        
        if ((distance < 150 && scale <= 1.5) ||
            (distance < 500 && scale <= 1.2)) {
            return;
        }
        [self.appDelegate showOriginalStory:url];
        gesture.enabled = NO;
        gesture.enabled = YES;
    }
}

- (void)showUserProfile:(NSString *)userId xCoordinate:(int)x yCoordinate:(int)y width:(int)width height:(int)height {
    CGRect frame = CGRectZero;
    if (!self.isPhoneOrCompact) {
        // only adjust for the bar if user is scrolling
        if (self.appDelegate.storiesCollection.isRiverView ||
            self.appDelegate.storiesCollection.isSocialView ||
            self.appDelegate.storiesCollection.isSavedView ||
            self.appDelegate.storiesCollection.isReadView) {
            if (self.webView.scrollView.contentOffset.y == -20) {
                y = y + 20;
            }
        } else {
            if (self.webView.scrollView.contentOffset.y == -9) {
                y = y + 9;
            }
        }  
        
        frame = CGRectMake(x, y, width, height);
    } 
    [self.appDelegate showUserProfileModal:[NSValue valueWithCGRect:frame]];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    [self changeFontSize:[userPreferences stringForKey:@"story_font_size"]];
    [self changeLineSpacing:[userPreferences stringForKey:@"story_line_spacing"]];

}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.webView.hidden = NO;
    [self.activityIndicator stopAnimating];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    [self changeFontSize:[userPreferences stringForKey:@"story_font_size"]];
    [self changeLineSpacing:[userPreferences stringForKey:@"story_line_spacing"]];
    [self.webView evaluateJavaScript:@"document.body.style.webkitTouchCallout='none';" completionHandler:^(id _Nullable value, NSError * _Nullable error) {
        if ([self.appDelegate.storiesCollection.activeFeedStories count] &&
            self.activeStoryId && self.hasStory) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .15 * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^{
                               [self checkTryFeedStory];
                           });
        }
        
        [self.webView evaluateJavaScript:@"document.readyState" completionHandler:^(id _Nullable value, NSError * _Nullable error) {
            if ([value isEqualToString:@"complete"]) {
                [self scrollToLastPosition:YES];
            }
        }];
    }];
}

- (void)checkTryFeedStory {
    // see if it's a tryfeed for animation
    if (!self.webView.hidden &&
        self.appDelegate.tryFeedCategory &&
        ([[self.activeStory objectForKey:@"id"] isEqualToString:self.appDelegate.tryFeedStoryId] ||
         [[self.activeStory objectForKey:@"story_hash"] isEqualToString:self.appDelegate.tryFeedStoryId])) {
        [MBProgressHUD hideHUDForView:self.appDelegate.storyPageControl.view animated:YES];
        
        if ([self.appDelegate.tryFeedCategory isEqualToString:@"comment_like"] ||
            [self.appDelegate.tryFeedCategory isEqualToString:@"comment_reply"]) {
            NSString *currentUserId = [NSString stringWithFormat:@"%@", [self.appDelegate.dictSocialProfile objectForKey:@"user_id"]];
            NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true, true);", currentUserId];
            [self.webView evaluateJavaScript:jsFlashString completionHandler:^(id _Nullable value, NSError * _Nullable error) {
                self.appDelegate.tryFeedCategory = nil;
            }];
        } else if ([self.appDelegate.tryFeedCategory isEqualToString:@"story_reshare"] ||
                   [self.appDelegate.tryFeedCategory isEqualToString:@"reply_reply"]) {
            NSString *blurblogUserId = [NSString stringWithFormat:@"%@", [self.activeStory objectForKey:@"social_user_id"]];
            NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true, true);", blurblogUserId];
            [self.webView evaluateJavaScript:jsFlashString completionHandler:^(id _Nullable value, NSError * _Nullable error) {
                self.appDelegate.tryFeedCategory = nil;
            }];
        }
    }
}

- (void)setFontStyle:(NSString *)fontStyle {
    __block NSString *jsString;
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    [userPreferences setObject:fontStyle forKey:@"fontStyle"];
    [userPreferences synchronize];
    
    jsString = [NSString stringWithFormat:@
                "document.getElementById('NB-font-style').setAttribute('class', '%@')",
                fontStyle];
    
    [self.webView evaluateJavaScript:jsString completionHandler:^(id _Nullable value, NSError * _Nullable error) {
        if (![fontStyle hasPrefix:@"NB-"]) {
            jsString = [NSString stringWithFormat:@
                        "document.getElementById('NB-font-style').setAttribute('style', 'font-family: %@;')",
                        fontStyle];
        } else {
            jsString = @"document.getElementById('NB-font-style').setAttribute('style', '')";
        }
        
        [self.webView evaluateJavaScript:jsString completionHandler:nil];
    }];
}

- (void)changeFontSize:(NSString *)fontSize {
    NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementById('NB-font-size').setAttribute('class', 'NB-%@')",
                          fontSize];
    
    [self.webView evaluateJavaScript:jsString completionHandler:nil];
}

- (void)changeLineSpacing:(NSString *)lineSpacing {
    NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementById('NB-line-spacing').setAttribute('class', 'NB-line-spacing-%@')",
                          lineSpacing];
    
    [self.webView evaluateJavaScript:jsString completionHandler:nil];
}

#pragma mark -
#pragma mark Actions

- (void)toggleLikeComment:(BOOL)likeComment {
    [self.appDelegate.storyPageControl showShareHUD:@"Favoriting"];
    NSString *urlString;
    if (likeComment) {
        urlString = [NSString stringWithFormat:@"%@/social/like_comment",
                               self.appDelegate.url];
    } else {
        urlString = [NSString stringWithFormat:@"%@/social/remove_like_comment",
                               self.appDelegate.url];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    
    [request setPostValue:[self.activeStory
                   objectForKey:@"id"] 
           forKey:@"story_id"];
    [request setPostValue:[self.activeStory
                           objectForKey:@"story_feed_id"] 
                   forKey:@"story_feed_id"];
    

    [request setPostValue:[self.appDelegate.activeComment objectForKey:@"user_id"] forKey:@"comment_user_id"];
    
    [request setDidFinishSelector:@selector(finishLikeComment:)];
    [request setDidFailSelector:@selector(requestFailed:)];
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
    
    if (request.responseStatusCode != 200) {
        return [self requestFailed:request];
    }
    
    // add the comment into the activeStory dictionary
    NSDictionary *newStory = [DataUtilities updateComment:results for:self.appDelegate];

    // update the current story and the activeFeedStories
    self.appDelegate.activeStory = newStory;
    [self setActiveStoryAtIndex:-1];
    
    NSMutableArray *newActiveFeedStories = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < self.appDelegate.storiesCollection.activeFeedStories.count; i++)  {
        NSDictionary *feedStory = [self.appDelegate.storiesCollection.activeFeedStories objectAtIndex:i];
        NSString *storyId = [NSString stringWithFormat:@"%@", [feedStory objectForKey:@"story_hash"]];
        NSString *currentStoryId = [NSString stringWithFormat:@"%@", [self.activeStory objectForKey:@"story_hash"]];
        if ([storyId isEqualToString: currentStoryId]){
            [newActiveFeedStories addObject:newStory];
        } else {
            [newActiveFeedStories addObject:[self.appDelegate.storiesCollection.activeFeedStories objectAtIndex:i]];
        }
    }
    
    self.appDelegate.storiesCollection.activeFeedStories = [NSArray arrayWithArray:newActiveFeedStories];
    
    [MBProgressHUD hideHUDForView:self.appDelegate.storyPageControl.view animated:NO];
    [self refreshComments:@"like"];
} 


- (void)requestFailed:(ASIHTTPRequest *)request {    
    NSLog(@"Error in story detail: %@", [request error]);
    NSString *error;
    
    [MBProgressHUD hideHUDForView:self.appDelegate.storyPageControl.view animated:NO];
    
    if ([request error]) {
        error = [NSString stringWithFormat:@"%@", [request error]];
    } else {
        error = @"The server barfed!";
    }
    [self informError:error];
}

- (void)openShareDialog {
    // test to see if the user has commented
    // search for the comment from friends comments
    NSArray *friendComments = [self.activeStory objectForKey:@"friend_comments"];
    
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [self.appDelegate.dictSocialProfile objectForKey:@"user_id"]];
    for (int i = 0; i < friendComments.count; i++) {
        NSString *userId = [NSString stringWithFormat:@"%@",
                            [[friendComments objectAtIndex:i] objectForKey:@"user_id"]];
        if([userId isEqualToString:currentUserId]){
            self.appDelegate.activeComment = [friendComments objectAtIndex:i];
            break;
        } else {
            self.appDelegate.activeComment = nil;
        }
    }
    
    if (self.appDelegate.activeComment == nil) {
        [self.appDelegate showShareView:@"share"
                         setUserId:nil
                       setUsername:nil
                        setReplyId:nil];
    } else {
        [self.appDelegate showShareView:@"edit-share"
                         setUserId:nil
                       setUsername:nil
                        setReplyId:nil];
    }
}

- (void)openTrainingDialog:(int)x yCoordinate:(int)y width:(int)width height:(int)height {
    CGRect frame = CGRectZero;
    if (!self.isPhoneOrCompact) {
        // only adjust for the bar if user is scrolling
        if (self.appDelegate.storiesCollection.isRiverView ||
            self.appDelegate.storiesCollection.isSocialView ||
            self.appDelegate.storiesCollection.isSavedView ||
            self.appDelegate.storiesCollection.isReadView) {
            if (self.webView.scrollView.contentOffset.y == -20) {
                y = y + 20;
            }
        } else {
            if (self.webView.scrollView.contentOffset.y == -9) {
                y = y + 9;
            }
        }
        
        frame = CGRectMake(x, y, width, height);
    }
    //    NSLog(@"Open trainer: %@ (%d/%d/%d/%d)", NSStringFromCGRect(frame), x, y, width, height);
    [self.appDelegate openTrainStory:[NSValue valueWithCGRect:frame]];
}

- (void)openUserTagsDialog:(int)x yCoordinate:(int)y width:(int)width height:(int)height {
    CGRect frame = CGRectZero;
    // only adjust for the bar if user is scrolling
    if (self.appDelegate.storiesCollection.isRiverView ||
        self.appDelegate.storiesCollection.isSocialView ||
        self.appDelegate.storiesCollection.isSavedView ||
        self.appDelegate.storiesCollection.isReadView) {
        if (self.webView.scrollView.contentOffset.y == -20) {
            y = y + 20;
        }
    } else {
        if (self.webView.scrollView.contentOffset.y == -9) {
            y = y + 9;
        }
    }
    
    frame = CGRectMake(x, y, width, height);

    [self.appDelegate openUserTagsStory:[NSValue valueWithCGRect:frame]];
}

- (void)tapImage:(UIGestureRecognizer *)gestureRecognizer {
    [self pointForGesture:gestureRecognizer completion:^(CGPoint pt) {
        if (pt.x == CGPointZero.x && pt.y == CGPointZero.y) return;
        //    NSLog(@"Tapped point: %@", NSStringFromCGPoint(pt));
        
        NSString *jsString = [NSString stringWithFormat:@"linkAt(%li, %li, 'tagName');", (long)pt.x,(long)pt.y];
        
        [self.webView evaluateJavaScript:jsString completionHandler:^(id _Nullable tagName, NSError * _Nullable error) {
            if ([tagName isEqualToString:@"IMG"]) {
                [self showImageMenu:pt];
                [gestureRecognizer setEnabled:NO];
                [gestureRecognizer setEnabled:YES];
            }
        }];
    }];
}

- (void)tapAndHold:(NSNotification*)notification {
    [self pointForEvent:notification completion:^(CGPoint pt) {
        if (pt.x == CGPointZero.x && pt.y == CGPointZero.y) return;
        
        NSString *jsString = [NSString stringWithFormat:@"linkAt(%li, %li, 'tagName');", (long)pt.x,(long)pt.y];
        
        [self.webView evaluateJavaScript:jsString completionHandler:^(id _Nullable tagName, NSError * _Nullable error) {
            if ([tagName isEqualToString:@"IMG"]) {
                [self showImageMenu:pt];
            }
            
            if ([tagName isEqualToString:@"A"]) {
                [self showLinkContextMenu:pt];
            }
        }];
    }];
}

- (void)showImageMenu:(CGPoint)pt {
    [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'title');",
                                                   (long)pt.x,(long)pt.y] completionHandler:^(NSString *title, NSError * _Nullable error) {
        [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'alt');",
                                                     (long)pt.x,(long)pt.y] completionHandler:^(NSString *alt, NSError * _Nullable error) {
            [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'src');",
                                         (long)pt.x,(long)pt.y] completionHandler:^(NSString *src, NSError * _Nullable error) {
                self.activeLongPressUrl = [NSURL URLWithString:src];
                
                UIActionSheet *actions = [[UIActionSheet alloc] initWithTitle:title.length ? title : nil
                                                                     delegate:self
                                                            cancelButtonTitle:@"Done"
                                                       destructiveButtonTitle:nil
                                                            otherButtonTitles:nil];
                self.actionSheetViewImageIndex = [actions addButtonWithTitle:@"View and zoom"];
                self.actionSheetCopyImageIndex = [actions addButtonWithTitle:@"Copy image"];
                self.actionSheetSaveImageIndex = [actions addButtonWithTitle:@"Save to camera roll"];
                [actions showFromRect:CGRectMake(pt.x, pt.y, 1, 1)
                               inView:self.appDelegate.storyPageControl.view animated:YES];
                //    [actions showInView:self.appDelegate.storyPageControl.view];
            }];
        }];
    }];
}

- (void)showLinkContextMenu:(CGPoint)pt {
    [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'href');",
                                                  (long)pt.x,(long)pt.y] completionHandler:^(NSString *href, NSError * _Nullable error) {
        [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'innerText');",
                                                       (long)pt.x,(long)pt.y] completionHandler:^(NSString *title, NSError * _Nullable error) {
            NSURL *url = [NSURL URLWithString:href];
            
            if (!href || ![href length]) return;
            
            NSValue *ptValue = [NSValue valueWithCGPoint:pt];
            [self.appDelegate showSendTo:self.appDelegate.storyPageControl
                             sender:ptValue
                            withUrl:url
                         authorName:nil
                               text:nil
                              title:title
                          feedTitle:nil
                             images:nil];
        }];
    }];
}

- (void)windowSizeWithCompletion:(void (^)(CGSize size))completionHandler {
    if (completionHandler) {
        [self.webView evaluateJavaScript:@"window.innerWidth" completionHandler:^(id width, NSError * _Nullable error) {
            [self.webView evaluateJavaScript:@"window.innerHeight" completionHandler:^(id height, NSError * _Nullable error) {
                completionHandler(CGSizeMake([width integerValue], [height integerValue]));
            }];
        }];
    }
}

- (void)pointForEvent:(NSNotification*)notification completion:(void (^)(CGPoint pt))completionHandler {
    if (!completionHandler) {
        return;
    }
    
    if (self != self.appDelegate.storyPageControl.currentPage || !self.view.window) {
        completionHandler(CGPointZero);
        return;
    }
    
    CGPoint pt;
    NSDictionary *coord = [notification object];
    pt.x = [[coord objectForKey:@"x"] floatValue];
    pt.y = [[coord objectForKey:@"y"] floatValue];
    
    // convert point from window to view coordinate system
    pt = [self.webView convertPoint:pt fromView:nil];
    
    // convert point from view to HTML coordinate system
    CGSize viewSize = [self.webView frame].size;
    
    [self windowSizeWithCompletion:^(CGSize windowSize) {
        CGFloat f = windowSize.width / viewSize.width;
        
        completionHandler(CGPointMake(pt.x * f, pt.y * f));
    }];
}

- (void)pointForGesture:(UIGestureRecognizer *)gestureRecognizer completion:(void (^)(CGPoint pt))completionHandler {
    if (!completionHandler) {
        return;
    }
    
    if (self != self.appDelegate.storyPageControl.currentPage || !self.view.window) {
        completionHandler(CGPointZero);
        return;
    }
    
    CGPoint pt = [gestureRecognizer locationInView:self.appDelegate.storyPageControl.currentPage.webView];
    
    // convert point from view to HTML coordinate system
    CGSize viewSize = [self.webView frame].size;
    
    [self windowSizeWithCompletion:^(CGSize windowSize) {
        CGFloat f = windowSize.width / viewSize.width;
        
        completionHandler(CGPointMake(pt.x * f, pt.y * f));
    }];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == self.actionSheetViewImageIndex) {
        [self.appDelegate showOriginalStory:self.activeLongPressUrl];
    } else if (buttonIndex == self.actionSheetCopyImageIndex ||
               buttonIndex == self.actionSheetSaveImageIndex) {
        [self fetchImage:self.activeLongPressUrl buttonIndex:buttonIndex];
    }
}

- (void)fetchImage:(NSURL *)url buttonIndex:(NSInteger)buttonIndex {
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    [self.appDelegate.storyPageControl showShareHUD:buttonIndex == self.actionSheetCopyImageIndex ?
                                               @"Copying..." : @"Saving..."];
    
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    AFHTTPRequestOperation *requestOperation = [[AFHTTPRequestOperation alloc]
                                                initWithRequest:urlRequest];
    [requestOperation setResponseSerializer:[AFImageResponseSerializer serializer]];
    [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        UIImage *image = responseObject;
        if (buttonIndex == self.actionSheetCopyImageIndex) {
            [UIPasteboard generalPasteboard].image = image;
            [self flashCheckmarkHud:@"copied"];
        } else if (buttonIndex == self.actionSheetSaveImageIndex) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
            [self flashCheckmarkHud:@"saved"];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [MBProgressHUD hideHUDForView:self.webView animated:YES];
        [self informError:@"Could not fetch image"];
    }];
    [requestOperation start];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if ([self respondsToSelector:action])
        return self.noStoryMessage.hidden;
    return [super canPerformAction:action withSender:sender];
}

# pragma mark
# pragma mark Subscribing to blurblog

- (void)subscribeToBlurblog {
    [self.appDelegate.storyPageControl showShareHUD:@"Following"];
    NSString *urlString = [NSString stringWithFormat:@"%@/social/follow",
                     self.appDelegate.url];
    
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    [request setPostValue:[self.appDelegate.storiesCollection.activeFeed
                           objectForKey:@"user_id"] 
                   forKey:@"user_id"];

    [request setDidFinishSelector:@selector(finishSubscribeToBlurblog:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
} 

- (void)finishSubscribeToBlurblog:(ASIHTTPRequest *)request {
    [MBProgressHUD hideHUDForView:self.appDelegate.storyPageControl.view animated:NO];
    self.storyHUD = [MBProgressHUD showHUDAddedTo:self.webView animated:YES];
    self.storyHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
    self.storyHUD.mode = MBProgressHUDModeCustomView;
    self.storyHUD.removeFromSuperViewOnHide = YES;  
    self.storyHUD.labelText = @"Followed";
    [self.storyHUD hide:YES afterDelay:1];
    self.appDelegate.storyPageControl.navigationItem.leftBarButtonItem = nil;
    [self.appDelegate reloadFeedsView:NO];
}

- (void)refreshComments:(NSString *)replyId {
    NSString *shareBarString = [self getShareBar];  
    
    NSString *commentString = [self getComments];  
    NSString *jsString = [[NSString alloc] initWithFormat:@
                          "document.getElementById('NB-comments-wrapper').innerHTML = '%@';"
                          "document.getElementById('NB-share-bar-wrapper').innerHTML = '%@';",
                          commentString, 
                          shareBarString];
    NSString *shareType = self.appDelegate.activeShareType;
    [self.webView evaluateJavaScript:jsString completionHandler:^(id _Nullable value, NSError * _Nullable error) {
        [self.webView evaluateJavaScript:@"attachFastClick();" completionHandler:^(id _Nullable value, NSError * _Nullable error) {
            // HACK to make the scroll event happen after the replace innerHTML event above happens.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .15 * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^{
                               if (!replyId) {
                                   NSString *currentUserId = [NSString stringWithFormat:@"%@",
                                                              [self.appDelegate.dictSocialProfile objectForKey:@"user_id"]];
                                   NSString *jsFlashString = [[NSString alloc]
                                                              initWithFormat:@"slideToComment('%@', true);", currentUserId];
                                   [self.webView evaluateJavaScript:jsFlashString completionHandler:nil];
                               } else if ([replyId isEqualToString:@"like"]) {
                                   
                               } else {
                                   NSString *jsFlashString = [[NSString alloc]
                                                              initWithFormat:@"slideToComment('%@', true);", replyId];
                                   [self.webView evaluateJavaScript:jsFlashString completionHandler:nil];
                               }
                           });
            
            
            //    // adding in a simulated delay
            //    sleep(1);
            
            [self flashCheckmarkHud:shareType];
            [self refreshSideoptions];
        }];
    }];
}

- (void)flashCheckmarkHud:(NSString *)messageType {
    [MBProgressHUD hideHUDForView:self.webView animated:NO];
    self.storyHUD = [MBProgressHUD showHUDAddedTo:self.webView animated:YES];
    self.storyHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
    self.storyHUD.mode = MBProgressHUDModeCustomView;
    self.storyHUD.removeFromSuperViewOnHide = YES;
    
    if ([messageType isEqualToString:@"reply"]) {
        self.storyHUD.labelText = @"Replied";
    } else if ([messageType isEqualToString:@"edit-reply"]) {
        self.storyHUD.labelText = @"Edited Reply";
    } else if ([messageType isEqualToString:@"edit-share"]) {
        self.storyHUD.labelText = @"Edited Comment";
    } else if ([messageType isEqualToString:@"share"]) {
        self.storyHUD.labelText = @"Shared";
    } else if ([messageType isEqualToString:@"like-comment"]) {
        self.storyHUD.labelText = @"Favorited";
    } else if ([messageType isEqualToString:@"unlike-comment"]) {
        self.storyHUD.labelText = @"Unfavorited";
    } else if ([messageType isEqualToString:@"saved"]) {
        self.storyHUD.labelText = @"Saved";
    } else if ([messageType isEqualToString:@"unsaved"]) {
        self.storyHUD.labelText = @"No longer saved";
    } else if ([messageType isEqualToString:@"unread"]) {
        self.storyHUD.labelText = @"Unread";
    } else if ([messageType isEqualToString:@"added"]) {
        self.storyHUD.labelText = @"Added";
    } else if ([messageType isEqualToString:@"copied"]) {
        self.storyHUD.labelText = @"Copied";
    } else if ([messageType isEqualToString:@"saved"]) {
        self.storyHUD.labelText = @"Saved";
    }
    [self.storyHUD hide:YES afterDelay:1];
}

#pragma mark -
#pragma mark Scrolling

- (void)scrolltoComment {
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [self.appDelegate.dictSocialProfile objectForKey:@"user_id"]];
    NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true);", currentUserId];
    [self.webView evaluateJavaScript:jsFlashString completionHandler:nil];
}

- (void)tryScrollingDown:(BOOL)down {
    UIScrollView *scrollView = self.webView.scrollView;
    CGPoint contentOffset = scrollView.contentOffset;
    CGFloat frameHeight = scrollView.frame.size.height;
    CGFloat scrollHeight = frameHeight - 45; // ~height of source bar and buttons
    if (down) {
        CGSize contentSize = scrollView.contentSize;
        if (contentOffset.y + frameHeight == contentSize.height)
            return;
        contentOffset.y = MIN(contentOffset.y + scrollHeight, contentSize.height - frameHeight);
    } else {
        if (contentOffset.y <= 0)
            return;
        contentOffset.y = MAX(contentOffset.y - scrollHeight, 0);
    }
    [scrollView setContentOffset:contentOffset animated:YES];
}

- (void)scrollPageDown:(id)sender {
    [self tryScrollingDown:YES];
}

- (void)scrollPageUp:(id)sender {
    [self tryScrollingDown:NO];
}

- (NSString *)textToHtml:(NSString*)htmlString {
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"'"  withString:@"&#039;"];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"\n"  withString:@"<br/>"];
    return htmlString;
}

- (void)changeWebViewWidth {
//    [webView setNeedsLayout];
//    [webView layoutIfNeeded];
    
//    NSLog(@"changeWebViewWidth: %@ / %@ / %@", NSStringFromCGSize(self.view.bounds.size), NSStringFromCGSize(self.webView.scrollView.bounds.size), NSStringFromCGSize(self.webView.scrollView.contentSize));

    NSInteger contentWidth = CGRectGetWidth(self.webView.scrollView.bounds);
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    NSString *contentWidthClass;

    if (UIInterfaceOrientationIsLandscape(orientation) && !self.isPhoneOrCompact) {
        contentWidthClass = @"NB-ipad-wide";
    } else if (!UIInterfaceOrientationIsLandscape(orientation) && !self.isPhoneOrCompact) {
        contentWidthClass = @"NB-ipad-narrow";
    } else if (UIInterfaceOrientationIsLandscape(orientation) && self.isPhoneOrCompact) {
        contentWidthClass = @"NB-iphone-wide";
    } else {
        contentWidthClass = @"NB-iphone";
    }
    
    contentWidthClass = [NSString stringWithFormat:@"%@ NB-width-%d",
                         contentWidthClass, (int)floorf(CGRectGetWidth(self.webView.scrollView.bounds))];
    
    NSString *riverClass = (self.appDelegate.storiesCollection.isRiverView ||
                            self.appDelegate.storiesCollection.isSocialView ||
                            self.appDelegate.storiesCollection.isSavedView ||
                            self.appDelegate.storiesCollection.isReadView) ?
                            @"NB-river" : @"NB-non-river";
    
    NSString *jsString = [[NSString alloc] initWithFormat:
                          @"$('body').attr('class', '%@ %@');"
                          "document.getElementById(\"viewport\").setAttribute(\"content\", \"width=%li;initial-scale=1; minimum-scale=1.0; maximum-scale=1.0; user-scalable=0;\");",
                          contentWidthClass,
                          riverClass,
                          (long)contentWidth];
    [self.webView evaluateJavaScript:jsString completionHandler:nil];
    
//    self.webView.hidden = NO;
}

- (void)refreshHeader {
    NSString *headerString = [[[self getHeader] stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"]
                              stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *jsString = [NSString stringWithFormat:@"document.getElementById('NB-header-container').innerHTML = '%@';",
                          headerString];
    
    [self.webView evaluateJavaScript:jsString completionHandler:^(id _Nullable value, NSError * _Nullable error) {
        [self.webView evaluateJavaScript:@"attachFastClick();" completionHandler:nil];
    }];
}

- (void)refreshSideoptions {
    NSString *sideoptionsString = [[[self getSideoptions] stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"]
                              stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *jsString = [NSString stringWithFormat:@"document.getElementById('NB-sideoptions-container').innerHTML = '%@';",
                          sideoptionsString];
    
    [self.webView evaluateJavaScript:jsString completionHandler:^(id _Nullable value, NSError * _Nullable error) {
        [self.webView evaluateJavaScript:@"attachFastClick();" completionHandler:nil];
    }];
}

#pragma mark -
#pragma mark Text view

- (void)showTextOrStoryView {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                           [self.activeStory objectForKey:@"story_feed_id"]];
    if ([self.appDelegate isFeedInTextView:feedIdStr]) {
        if (!self.inTextView) {
            [self fetchTextView];
        }
    } else {
        if (self.inTextView) {
            [self showStoryView];
        }
    }
}

- (void)toggleTextView:(id)sender {
    if (self.inTextView)
        [self showStoryView];
    else
        [self fetchTextView];
}

- (void)showStoryView {
    self.inTextView = NO;
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    [self.appDelegate.storyPageControl setTextButton:self];
    [self drawStory];
}

- (void)fetchTextView {
    if (!self.activeStoryId || !self.activeStory) return;
    self.inTextView = YES;
//    NSLog(@"Fetching Text: %@", [self.activeStory objectForKey:@"story_title"]);
    if (self.activeStory == self.appDelegate.storyPageControl.currentPage.activeStory) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.appDelegate.storyPageControl showFetchingTextNotifier];
        });
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/rss_feeds/original_text",
                           self.appDelegate.url];
    ASIFormDataRequest *request = [self formRequestWithURL:urlString];
    [request addPostValue:[self.activeStory objectForKey:@"id"] forKey:@"story_id"];
    [request addPostValue:[self.activeStory objectForKey:@"story_feed_id"] forKey:@"feed_id"];
    [request setUserInfo:@{@"storyId": [self.activeStory objectForKey:@"id"]}];
    [request setDidFinishSelector:@selector(finishFetchTextView:)];
    [request setDidFailSelector:@selector(failedFetchText::)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)failedFetchText:(ASIHTTPRequest *)request {
    [self.appDelegate.storyPageControl hideNotifier];
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    if (self.activeStory == self.appDelegate.storyPageControl.currentPage.activeStory) {
        [self informError:@"Could not fetch text"];
    }
    self.inTextView = NO;
    [self.appDelegate.storyPageControl setTextButton:self];
}

- (void)finishFetchTextView:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSDictionary *results = [NSJSONSerialization
                             JSONObjectWithData:responseData
                             options:kNilOptions
                             error:&error];
    
    if ([[results objectForKey:@"failed"] boolValue]) {
        [self failedFetchText:request];
        return;
    }
    
    if (![[request.userInfo objectForKey:@"storyId"]
          isEqualToString:[self.activeStory objectForKey:@"id"]]) {
        [self.appDelegate.storyPageControl hideNotifier];
        [MBProgressHUD hideHUDForView:self.webView animated:YES];
        self.inTextView = NO;
        [self.appDelegate.storyPageControl setTextButton:self];
        return;
    }
    
    NSMutableDictionary *newActiveStory = [self.activeStory mutableCopy];
    [newActiveStory setObject:[results objectForKey:@"original_text"] forKey:@"original_text"];
    if ([[self.activeStory objectForKey:@"story_hash"] isEqualToString:[self.appDelegate.activeStory objectForKey:@"story_hash"]]) {
        self.appDelegate.activeStory = newActiveStory;
    }
    self.activeStory = newActiveStory;
    
    [self.appDelegate.storyPageControl hideNotifier];
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    
    self.inTextView = YES;
    
    [self drawStory];
    
//    NSLog(@"Fetched Text: %@", [self.activeStory objectForKey:@"story_title"]);
}


@end
