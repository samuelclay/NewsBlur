//
//  StoryDetailObjCViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import "StoryDetailObjCViewController.h"
#import "NewsBlurAppDelegate.h"
#import "FontSettingsViewController.h"
#import "UserProfileViewController.h"
#import "ShareViewController.h"
#import "Utilities.h"
#import "NSString+HTML.h"
#import "DataUtilities.h"
#import "FMDatabase.h"
#import "SBJson4.h"
#import "StringHelper.h"
#import "StoriesCollection.h"
#import "UIView+ViewController.h"
#import "JNWThrottledBlock.h"
#import "NewsBlur-Swift.h"

#define iPadPro12 ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && ([UIScreen mainScreen].bounds.size.height == 1366 || [UIScreen mainScreen].bounds.size.width == 1366))
#define iPadPro10 ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && ([UIScreen mainScreen].bounds.size.height == 1112 || [UIScreen mainScreen].bounds.size.width == 1112))

@interface StoryDetailObjCViewController ()

@property (nonatomic, strong) NSString *fullStoryHTML;

@end

@implementation StoryDetailObjCViewController

@synthesize appDelegate;
@synthesize activeStoryId;
@synthesize activeStory;
@synthesize innerView;
@synthesize webView;
@synthesize feedTitleGradient;
@synthesize noStoryMessage;
@synthesize pullingScrollview;
@synthesize pageIndex;
@synthesize storyHUD;
@synthesize inTextView;
@synthesize isRecentlyUnread;

#pragma mark -
#pragma mark View boilerplate

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)dealloc {
    [self.webView.scrollView removeObserver:self forKeyPath:@"contentOffset"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)description {
    NSString *page = appDelegate.storyPagesViewController.currentPage == self ? @"currentPage" : appDelegate.storyPagesViewController.previousPage == self ? @"previousPage" : appDelegate.storyPagesViewController.nextPage == self ? @"nextPage" : @"unattached page";
    return [NSString stringWithFormat:@"%@", page];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback
                        error:nil];
    
    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSString *videoPlayback = [preferences stringForKey:@"video_playback"];
    
    configuration.allowsInlineMediaPlayback = ![videoPlayback isEqualToString:@"fullscreen"];
    
    self.webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:configuration];
    
    [self.view addSubview:self.webView];
    
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.navigationDelegate = self;
    self.webView.allowsLinkPreview = YES;
    
    [self.webView.scrollView setAlwaysBounceVertical:appDelegate.storyPagesViewController.isHorizontal];
    [self.webView.scrollView setDelaysContentTouches:NO];
    [self.webView.scrollView setDecelerationRate:UIScrollViewDecelerationRateNormal];
    [self.webView.scrollView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth |
                                                     UIViewAutoresizingFlexibleHeight)];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    
    [self.webView.scrollView addObserver:self forKeyPath:@"contentOffset"
                                 options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                 context:nil];
    
    [self.appDelegate prepareWebView:self.webView completionHandler:nil];
    
    [self clearWebView];

    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc]
                                                initWithTarget:self action:@selector(doubleTap:)];
    doubleTapGesture.numberOfTapsRequired = 2;
    doubleTapGesture.delegate = self;
    [self.webView addGestureRecognizer:doubleTapGesture];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(tap:)];
    tapGesture.numberOfTapsRequired = 1;
    tapGesture.delegate = self;
    [tapGesture requireGestureRecognizerToFail:doubleTapGesture];
    [self.webView addGestureRecognizer:tapGesture];
    
    UITapGestureRecognizer *doubleDoubleTapGesture = [[UITapGestureRecognizer alloc]
                                                      initWithTarget:self
                                                      action:@selector(doubleTap:)];
    doubleDoubleTapGesture.numberOfTouchesRequired = 2;
    doubleDoubleTapGesture.numberOfTapsRequired = 2;
    doubleDoubleTapGesture.delegate = self;
    [self.webView addGestureRecognizer:doubleDoubleTapGesture];
    
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc]
                                                      initWithTarget:self
                                                      action:@selector(longPress:)];
    longPressGesture.numberOfTouchesRequired = 1;
    longPressGesture.delegate = self;
    [self.webView addGestureRecognizer:longPressGesture];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc]
                                                  initWithTarget:self action:@selector(pinchGesture:)];
        [self.webView addGestureRecognizer:pinchGesture];
    }
    
    [[ThemeManager themeManager] addThemeGestureRecognizerToView:self.webView];
    
    self.pageIndex = -2;
    self.inTextView = NO;
    
    _orientation = self.view.window.windowScene.interfaceOrientation;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
//    NSLog(@"%@: taps: %@, state: %@", gestureRecognizer.class, @(touch.tapCount), @(gestureRecognizer.state));
    inDoubleTap = (touch.tapCount == 2);
    
    CGPoint pt = [self pointForGesture:gestureRecognizer];
    if (pt.x == CGPointZero.x && pt.y == CGPointZero.y) return YES;
//    NSLog(@"Tapped point: %@", NSStringFromCGPoint(pt));
    
    if (inDoubleTap) {
        self.webView.scrollView.scrollEnabled = NO;
        [self performSelector:@selector(deferredEnableScrolling) withObject:nil afterDelay:0.0];
    }
    
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
//    NSLog(@"Should conflict? \n\tgesture:%@ \n\t  other:%@",
//          gestureRecognizer, otherGestureRecognizer);
    return YES;
}

- (void)tap:(UITapGestureRecognizer *)gestureRecognizer {
//    NSLog(@"Gesture tap: %ld (%ld) - %d", (long)gestureRecognizer.state, (long)UIGestureRecognizerStateEnded, inDoubleTap);
    
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded && gestureRecognizer.numberOfTouches == 1 && self.presentedViewController == nil) {
        CGPoint pt = [self pointForGesture:gestureRecognizer];
        if (pt.x == CGPointZero.x && pt.y == CGPointZero.y) return;
        if (inDoubleTap) return;
//        NSLog(@"Tapped point: %@", NSStringFromCGPoint(pt));
        [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'tagName');", (long)pt.x,(long)pt.y] completionHandler:^(NSString *tagName, NSError *error) {
            // Special case to handle the story title, Train, Save, and Share buttons.
            if ([self isTag:tagName equalTo:@"DIV"]) {
                [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'id');", (long)pt.x,(long)pt.y] completionHandler:^(NSString *identifier, NSError *error) {
                    [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'outerHTML');", (long)pt.x,(long)pt.y] completionHandler:^(NSString *outerHTML, NSError *error) {
                        if ([identifier isEqualToString:@"NB-story"] || ![outerHTML containsString:@"NB-"]) {
                            [self.appDelegate.storyPagesViewController tappedStory];
                        }
                    }];
                }];
                
                return;
            }
            
            // Ignore links, videos, and iframes (e.g. embedded YouTube videos).
            if (![@[@"A", @"VIDEO", @"IFRAME"] containsObject:tagName]) {
                [self.appDelegate.storyPagesViewController tappedStory];
            }
        }];
    }
}

- (void)doubleTap:(UITapGestureRecognizer *)gestureRecognizer {
//    NSLog(@"Gesture double tap: %d (%d) - %d", gestureRecognizer.state, UIGestureRecognizerStateEnded, inDoubleTap);
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded && inDoubleTap) {
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
            [appDelegate.storiesCollection toggleStoryUnread];
            [appDelegate.feedDetailViewController reloadData];
        } else if (saveStory) {
            [appDelegate.storiesCollection toggleStorySaved];
            [appDelegate.feedDetailViewController reloadData];
        }
        inDoubleTap = NO;
        [self performSelector:@selector(deferredEnableScrolling) withObject:nil afterDelay:0.0];
        appDelegate.storyPagesViewController.autoscrollActive = NO;
    }
}

- (void)longPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint pt = [self pointForGesture:gestureRecognizer];
        if (pt.x == CGPointZero.x && pt.y == CGPointZero.y) return;
        if (inDoubleTap) return;
        
        [webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'tagName');", (long)pt.x,(long)pt.y] completionHandler:^(NSString *tagName, NSError *error) {
            if ([self isTag:tagName equalTo:@"IMG"]) {
                [self showImageMenu:pt];
            }
        }];
    }
}

- (void)pinchGesture:(UIPinchGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }
    
    appDelegate.storyPagesViewController.forceNavigationBarShown = gestureRecognizer.scale < 1;
    [appDelegate.storyPagesViewController changedFullscreen];
}

- (void)screenEdgeSwipe:(UITapGestureRecognizer *)gestureRecognizer {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    BOOL swipeEnabled = [[userPreferences stringForKey:@"story_detail_swipe_left_edge"]
                         isEqualToString:@"pop_to_story_list"];
    
    if (swipeEnabled && gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [appDelegate hideStoryDetailView];
    }
}

- (void)deferredEnableScrolling {
    self.webView.scrollView.scrollEnabled = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (!appDelegate.showingSafariViewController &&
        appDelegate.feedsNavigationController.visibleViewController != (UIViewController *)appDelegate.shareViewController &&
        appDelegate.feedsNavigationController.visibleViewController != (UIViewController *)appDelegate.trainerViewController &&
        appDelegate.feedsNavigationController.visibleViewController != (UIViewController *)appDelegate.originalStoryViewController) {
        [self clearStory];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (!self.isPhoneOrCompact) {
        [appDelegate.feedDetailViewController.view endEditing:YES];
    }
    [self storeScrollPosition:NO];
    
    self.fullStoryHTML = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (!self.isPhoneOrCompact) {
        [appDelegate.feedDetailViewController.view endEditing:YES];
    }

    if (_orientation != self.view.window.windowScene.interfaceOrientation) {
        _orientation = self.view.window.windowScene.interfaceOrientation;
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

    scrollPct = self.webView.scrollView.contentOffset.y / self.webView.scrollView.contentSize.height;
//    NSLog(@"Current scroll is %2.2f%% (offset %.0f - height %.0f)", scrollPct*100, self.webView.scrollView.contentOffset.y,
//          self.webView.scrollView.contentSize.height);

    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        self->_orientation = self.view.window.windowScene.interfaceOrientation;
        [self changeWebViewWidth];
        [self drawFeedGradient];
        [self scrollToLastPosition:NO];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
    }];
}

- (void)viewWillLayoutSubviews {
    UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
    [super viewWillLayoutSubviews];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.appDelegate.storyPagesViewController layoutForInterfaceOrientation:orientation];
        [self changeWebViewWidth];
        [self drawFeedGradient];
    });

//    NSLog(@"viewWillLayoutSubviews: %.2f", self.webView.scrollView.bounds.size.width);
}

- (void)layoutForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (interfaceOrientation != _orientation) {
        _orientation = interfaceOrientation;
        [self changeWebViewWidth];
        [self drawFeedGradient];
        [self drawStory];
    }
}

- (BOOL)isPhoneOrCompact {
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone || self.appDelegate.isCompactWidth;
}

// allow keyboard commands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

#pragma mark -
#pragma mark Story setup

- (void)initStory {
    appDelegate.inStoryDetail = YES;
    self.noStoryMessage.hidden = YES;
    self.inTextView = NO;

    [appDelegate hideShareView:NO];
}

- (void)loadHTMLString:(NSString *)html {
    static NSURL *baseURL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        baseURL = [NSBundle mainBundle].bundleURL;
    });

    [self.webView loadHTMLString:html baseURL:baseURL];
}

- (void)hideNoStoryMessage {
    self.noStoryMessage.hidden = YES;
}

- (void)drawStory {
    UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
    [self drawStory:NO withOrientation:orientation];
}

- (void)drawStory:(BOOL)force withOrientation:(UIInterfaceOrientation)orientation {
    if (!force && [self.activeStoryId isEqualToString:[self.activeStory objectForKey:@"story_hash"]]) {
//        NSLog(@"Already drawn story, drawing anyway: %@", [self.activeStory objectForKey:@"story_title"]);
//        return;
    }
    
    if (self.activeStory == nil) {
        return;
    }

    scrollPct = 0;
    hasScrolled = NO;
    
    NSString *shareBarString = [self getShareBar];
    NSString *commentString = [self getComments];
    NSString *headerString;
    NSString *sharingHtmlString;
    NSString *footerString;
    NSString *fontStyleClass = @"";
    NSString *customStyle = @"";
    NSString *fontSizeClass = @"NB-";
    NSString *lineSpacingClass = @"NB-line-spacing-";
    NSString *premiumOnlyClass = (self.inTextView && !appDelegate.isPremium) ? @"NB-premium-only" : @"";
    NSString *storyContent = [self.activeStory objectForKey:@"story_content"];
    if (self.inTextView && [self.activeStory objectForKey:@"original_text"]) {
        storyContent = [self.activeStory objectForKey:@"original_text"];
    }
    NSString *changes = self.activeStory[@"story_changes"];
    if (changes != nil) {
        storyContent = changes;
    }
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    NSString *premiumTextString = [NSString stringWithFormat:@"<div class=\"NB-feed-story-premium-only-divider\"></div>"
                                   "<div class=\"NB-feed-story-premium-only-text\">The full Text view is a <a href=\"http://ios.newsblur.com/premium\">premium feature</a></div>"];
    
    fontStyleClass = [userPreferences stringForKey:@"fontStyle"];
    if (!fontStyleClass) {
        fontStyleClass = @"GothamNarrow-Book";
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
    
#if TARGET_OS_MACCATALYST
    // CATALYST: probably will want to add custom CSS for Macs.
    contentWidthClass = @"NB-ipad-wide NB-ipad-pro-12-wide NB-width-768";
#else
    if (UIInterfaceOrientationIsLandscape(orientation) && !self.isPhoneOrCompact) {
        if (iPadPro12) {
            contentWidthClass = @"NB-ipad-wide NB-ipad-pro-12-wide";
        } else if (iPadPro10) {
            contentWidthClass = @"NB-ipad-wide NB-ipad-pro-10-wide";
        } else {
            contentWidthClass = @"NB-ipad-wide";
        }
    } else if (!UIInterfaceOrientationIsLandscape(orientation) && !self.isPhoneOrCompact) {
        if (iPadPro12) {
            contentWidthClass = @"NB-ipad-narrow NB-ipad-pro-12-narrow";
        } else if (iPadPro10) {
            contentWidthClass = @"NB-ipad-narrow NB-ipad-pro-10-narrow";
        } else {
            contentWidthClass = @"NB-ipad-narrow";
        }
    } else if (UIInterfaceOrientationIsLandscape(orientation) && self.isPhoneOrCompact) {
        contentWidthClass = @"NB-iphone-wide";
    } else {
        contentWidthClass = @"NB-iphone";
    }
    
    contentWidthClass = [NSString stringWithFormat:@"%@ NB-width-%d",
                         contentWidthClass, (int)floorf(CGRectGetWidth(self.view.frame))];
#endif
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                           [self.activeStory
                            objectForKey:@"story_feed_id"]];
    NSDictionary *feed = [appDelegate getFeed:feedIdStr];
    NSString *storyClassSuffix = @"";
    
    if ([feed[@"is_newsletter"] isEqualToNumber:[NSNumber numberWithInt:1]]) {
        storyClassSuffix = @" NB-newsletter";
    }
    
    NSString *riverClass = (appDelegate.storiesCollection.isRiverView ||
                            appDelegate.storiesCollection.isSocialView ||
                            appDelegate.storiesCollection.isSavedView ||
                            appDelegate.storiesCollection.isWidgetView ||
                            appDelegate.storiesCollection.isReadView) ?
                            @"NB-river" : @"NB-non-river";
    
    NSString *themeStyle = [NSString stringWithFormat:@"<link rel=\"stylesheet\" type=\"text/css\" id=\"NB-theme-style\" href=\"storyDetailView%@.css\">", [ThemeManager themeManager].themeCSSSuffix];
    
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
    
    sharingHtmlString = [self getSideOptions];

    NSString *storyHeader = [self getHeader];
    
    NSString *htmlTop = [NSString stringWithFormat:@
                            "<!DOCTYPE html>\n"
                            "<html>"
                            "<head>%@</head>" // header string
                            "<body id=\"story_pane\" class=\"%@ %@\">"
                            "    <div class=\"%@\" id=\"NB-premium-check\">"
                            "    <div class=\"%@\" id=\"NB-font-style\"%@>"
                            "    <div class=\"%@\" id=\"NB-font-size\">"
                            "    <div class=\"%@\" id=\"NB-line-spacing\">"
                            "        <div id=\"NB-header-container\">%@</div>" // storyHeader
                            "        %@", // shareBar
                            headerString,
                            contentWidthClass,
                            riverClass,
                            premiumOnlyClass,
                            fontStyleClass,
                            customStyle,
                            fontSizeClass,
                            lineSpacingClass,
                            storyHeader,
                            shareBarString
                            ];
    
    NSString *htmlBottom = [NSString stringWithFormat:@
                            "    </div>" // line-spacing
                            "    </div>" // font-size
                            "    </div>" // font-style
                            "    </div>" // premium check
                            "</body>"
                            "</html>"
                            ];
    
    NSString *htmlContent = [NSString stringWithFormat:@
                             "%@" // header
                             "        <div id=\"NB-story\" class=\"NB-story%@\">%@</div>"
                             "        <div class=\"NB-text-view-premium-only\">%@</div>"
                             "        <div id=\"NB-sideoptions-container\">%@</div>"
                             "        <div id=\"NB-comments-wrapper\">"
                             "            %@" // friends comments
                             "        </div>"
                             "        %@"
                             "%@", // footer
                             htmlTop,
                             storyClassSuffix,
                             storyContent,
                             premiumTextString,
                             sharingHtmlString,
                             commentString,
                             footerString,
                             htmlBottom
                             ];
    
    NSString *htmlTopAndBottom = [htmlTop stringByAppendingString:htmlBottom];
    
//    NSLog(@"\n\n\n\nStory html (%@):\n\n\n%@\n\n\n", self.activeStory[@"story_title"], htmlContent);
    self.hasStory = NO;
    self.fullStoryHTML = htmlContent;
    
    dispatch_async(dispatch_get_main_queue(), ^{
//        NSLog(@"Drawing Story: %@", [self.activeStory objectForKey:@"story_title"]);
        if (self.hasStory)
            return;
        
        [self loadHTMLString:htmlTopAndBottom];
        [self.appDelegate.storyPagesViewController setTextButton:(StoryDetailViewController *)self];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self loadStory];
    });
    
    self.activeStoryId = [self.activeStory objectForKey:@"story_hash"];
}

- (void)drawFeedGradient {
    BOOL shouldHideStatusBar = appDelegate.storyPagesViewController.shouldHideStatusBar;
    CGFloat yOffset = -1;
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                           [self.activeStory
                            objectForKey:@"story_feed_id"]];
    NSDictionary *feed = [appDelegate getFeed:feedIdStr];
    
    if (appDelegate.storyPagesViewController.view.safeAreaInsets.top > 0.0 && appDelegate.storyPagesViewController.currentlyTogglingNavigationBar && !appDelegate.storyPagesViewController.isNavigationBarHidden) {
        yOffset -= 25;
    }
    
    if (self.feedTitleGradient) {
        [self.feedTitleGradient removeFromSuperview];
        self.feedTitleGradient = nil;
    }
    
    self.feedTitleGradient = [appDelegate
                              makeFeedTitleGradient:feed
                              withRect:CGRectMake(0, yOffset, CGRectGetWidth(self.view.bounds), 25)]; // 1024 hack for self.webView.frame.size.width
    self.feedTitleGradient.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.feedTitleGradient.tag = FEED_TITLE_GRADIENT_TAG; // Not attached yet. Remove old gradients, first.
    
    for (UIView *subview in self.webView.subviews) {
        if (subview.tag == FEED_TITLE_GRADIENT_TAG) {
            [subview removeFromSuperview];
        }
    }
    
    if (appDelegate.storiesCollection.isRiverView ||
        appDelegate.storiesCollection.isSocialView ||
        appDelegate.storiesCollection.isSavedView ||
        appDelegate.storiesCollection.isWidgetView ||
        appDelegate.storiesCollection.isReadView) {
        self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(24, 0, 0, 0);
    } else {
        self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(9, 0, 0, 0);
    }
    [self.webView insertSubview:feedTitleGradient aboveSubview:self.webView.scrollView];
    
    if (appDelegate.storyPagesViewController.view.safeAreaInsets.top > 0.0 && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && shouldHideStatusBar) {
        feedTitleGradient.alpha = appDelegate.storyPagesViewController.isNavigationBarHidden ? 1 : 0;
        
        [UIView animateWithDuration:0.3 animations:^{
            self.feedTitleGradient.alpha = self.appDelegate.storyPagesViewController.isNavigationBarHidden ? 0 : 1;
        }];
    }
}

- (void)showStory {
    id storyId = [self.activeStory objectForKey:@"story_hash"];
    [appDelegate.storiesCollection pushReadStory:storyId];
    [appDelegate resetShareComments];
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
    [self.activityIndicator stopAnimating];
    [appDelegate.storyPagesViewController setTextButton];
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
    
    NSString *html = [NSString stringWithFormat:@"<html>"
                      "<head><link rel=\"stylesheet\" type=\"text/css\" href=\"storyDetailView.css\">%@</head>" // header string
                      "<body></body>"
                      "</html>", themeStyle];

    [self loadHTMLString:html];
}

- (NSString *)getHeader {
    NSString *feedId = [NSString stringWithFormat:@"%@", [self.activeStory
                                                          objectForKey:@"story_feed_id"]];
    NSString *storyAuthor = @"";
    if ([[self.activeStory objectForKey:@"story_authors"] class] != [NSNull class] &&
        [[self.activeStory objectForKey:@"story_authors"] length]) {
        NSString *author = [NSString stringWithFormat:@"%@",
                            [[[[self.activeStory objectForKey:@"story_authors"] stringByReplacingOccurrencesOfString:@"\"" withString:@""]
                            stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]
                            stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"]];
        if (author && author.length) {
            int authorScore = [[[[appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
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
                int tagScore = [[[[appDelegate.storiesCollection.activeClassifiers objectForKey:feedId]
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
    if (self.isRecentlyUnread && [appDelegate.storiesCollection isStoryUnread:self.activeStory]) {
        NSInteger score = [NewsBlurAppDelegate computeStoryScore:[self.activeStory objectForKey:@"intelligence"]];
        storyUnread = [NSString stringWithFormat:@"<div class=\"NB-story-unread NB-%@\"></div>",
                       score > 0 ? @"positive" : score < 0 ? @"negative" : @"neutral"];
    }
    
    NSString *storyTitle = [self.activeStory objectForKey:@"story_title"];
    NSString *storyPermalink = [self.activeStory objectForKey:@"story_permalink"];
    NSMutableDictionary *titleClassifiers = [[appDelegate.storiesCollection.activeClassifiers
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
    
    NSString *storyToggleChanges = [self.activeStory[@"has_modifications"] boolValue] ? [NSString stringWithFormat:@"<a href=\"http://ios.newsblur.com/togglechanges\" "
                                                                           "class=\"NB-story-toggle-changes\" id=\"NB-story-toggle-changes\">%@</a><span class=\"NB-middot\">&middot;</span>", self.activeStory[@"story_changes"] != nil ? @"Hide Changes" : @"Show Changes"] : @"";
    
    NSString *storyDate = [Utilities formatLongDateFromTimestamp:[[self.activeStory
                                                                  objectForKey:@"story_timestamp"]
                                                                  integerValue]];
    NSString *storyHeader = [NSString stringWithFormat:@
                             "<div class=\"NB-header\"><div class=\"NB-header-inner\">"
                             "<div class=\"NB-story-title\">"
                             "  %@"
                             "  <a href=\"%@\" class=\"NB-story-permalink\">%@</a>"
                             "</div>"
                             "%@"
                             "<div class=\"NB-story-date\">%@</div>"
                             "%@"
                             "%@"
                             "%@"
                             "%@"
                             "</div></div>",
                             storyUnread,
                             storyPermalink,
                             storyTitle,
                             storyToggleChanges,
                             storyDate,
                             storyAuthor,
                             storyTags,
                             storyStarred,
                             storyUserTags];
    return storyHeader;
}

- (NSString *)getSideOptions {
    BOOL isSaved = [[self.activeStory objectForKey:@"starred"] boolValue];
    BOOL isShared = [[self.activeStory objectForKey:@"shared"] boolValue];
    
    NSString *sideOptions = [NSString stringWithFormat:@
                             "<div class='NB-sideoptions'>"
                             "<div class='NB-share-header'></div>"
                             "<div class='NB-share-wrapper'><div class='NB-share-inner-wrapper'>"
                             "  <div id=\"NB-share-button-id\" class='NB-share-button NB-train-button NB-button'>"
                             "    <a href=\"http://ios.newsblur.com/train\"><div>"
                             "      <span class=\"NB-icon\"></span>"
                             "      <span class=\"NB-sideoption-text\">Train</span>"
                             "    </div></a>"
                             "  </div>"
                             "  <div id=\"NB-share-button-id\" class='NB-share-button NB-button %@'>"
                             "    <a href=\"http://ios.newsblur.com/share\"><div>"
                             "      <span class=\"NB-icon\"></span>"
                             "      <span class=\"NB-sideoption-text\">%@</span>"
                             "    </div></a>"
                             "  </div>"
                             "  <div id=\"NB-share-button-id\" class='NB-share-button NB-save-button NB-button %@'>"
                             "    <a href=\"http://ios.newsblur.com/save/save/\"><div>"
                             "      <span class=\"NB-icon\"></span>"
                             "      <span class=\"NB-sideoption-text\">%@</span>"
                             "    </div></a>"
                             "  </div>"
                             "</div></div></div>",
                             isShared ? @"NB-button-active" : @"",
                             isShared ? @"Shared" : @"Share",
                             isSaved ? @"NB-button-active" : @"",
                             isSaved ? @"Saved" : @"Save"
                             ];
    
    return sideOptions;
}

- (NSString *)getAvatars:(NSString *)key {
    NSString *avatarString = @"";
    NSArray *shareUserIds = [self.activeStory objectForKey:key];
    
    for (int i = 0; i < shareUserIds.count; i++) {
        NSDictionary *user = [appDelegate getUser:[[shareUserIds objectAtIndex:i] intValue]];
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
            
            comments = [comments stringByAppendingString:publicCommentHeader];
            comments = [comments stringByAppendingFormat:@"<div class=\"NB-feed-story-comments\">"];
            
            // add public comments
            for (int i = 0; i < publicCommentsArray.count; i++) {
                NSString *comment = [self getComment:[publicCommentsArray objectAtIndex:i]];
                comments = [comments stringByAppendingString:comment];
            }
            comments = [comments stringByAppendingString:@"</div>"];
            comments = [comments stringByAppendingString:@"</div>"];
        }
    }
    
    return comments;
}

- (NSString *)getShareBar {
    NSString *comments = @"<div id=\"NB-share-bar-wrapper\">";
    NSString *commentLabel = @"";
    NSString *shareLabel = @"";
    
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
    NSDictionary *user = [appDelegate getUser:[[commentDict objectForKey:@"user_id"] intValue]];
    NSString *userAvatarClass = @"NB-user-avatar";
    NSString *userReshareString = @"";
    NSString *userEditButton = @"";
    NSString *userLikeButton = @"";
    NSString *commentUserId = [NSString stringWithFormat:@"%@", [commentDict objectForKey:@"user_id"]];
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictSocialProfile objectForKey:@"user_id"]];
    NSArray *likingUsersArray = [commentDict objectForKey:@"liking_users"];
    NSString *likingUsers = @"";
    
    if ([likingUsersArray count]) {
        likingUsers = @"<div class=\"NB-story-comment-likes-icon\"></div>";
        for (NSNumber *likingUser in likingUsersArray) {
            NSDictionary *sourceUser = [appDelegate getUser:[likingUser intValue]];
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

        NSDictionary *sourceUser = [appDelegate getUser:[[commentDict objectForKey:@"source_user_id"] intValue]];
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
            NSDictionary *user = [appDelegate getUser:[[replyDict objectForKey:@"user_id"] intValue]];

            NSString *userEditButton = @"";
            NSString *replyUserId = [NSString stringWithFormat:@"%@", [replyDict objectForKey:@"user_id"]];
            NSString *replyId = [replyDict objectForKey:@"reply_id"];
            NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictSocialProfile objectForKey:@"user_id"]];
            
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

#pragma mark - Scrolling

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqual:@"contentOffset"]) {
        BOOL isHorizontal = appDelegate.storyPagesViewController.isHorizontal;
        BOOL isNavBarHidden = appDelegate.storyPagesViewController.isNavigationBarHidden;
        
        if (self.webView.scrollView.contentOffset.y < (-1 * self.feedTitleGradient.frame.size.height + 1 + self.webView.scrollView.verticalScrollIndicatorInsets.top)) {
            // Pulling
            if (!pullingScrollview) {
                pullingScrollview = YES;
                
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
            if (pullingScrollview) {
                pullingScrollview = NO;
                [self.feedTitleGradient.layer setShadowOpacity:0];
                
                if (!isNavBarHidden) {
                    [self.webView insertSubview:self.feedTitleGradient aboveSubview:self.webView.scrollView];
                    
                    self.feedTitleGradient.frame = CGRectMake(0, -1,
                                                              self.feedTitleGradient.frame.size.width,
                                                              self.feedTitleGradient.frame.size.height);
                }
                
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
        
        if (appDelegate.storyPagesViewController.currentPage != self) return;

        int webpageHeight = self.webView.scrollView.contentSize.height;
        int viewportHeight = self.view.frame.size.height;
        int topPosition = self.webView.scrollView.contentOffset.y;
        
        CGFloat bottomInset = appDelegate.detailViewController.view.safeAreaInsets.bottom;
        
        int safeBottomMargin = bottomInset;
        int bottomPosition = webpageHeight - topPosition - viewportHeight;
        BOOL singlePage = webpageHeight - 200 <= viewportHeight;
        BOOL atBottom = bottomPosition < 150;
        BOOL pullingDown = topPosition < 0;
        BOOL atTop = topPosition < 50;
        BOOL nearTop = topPosition < 100;
        
        if (!hasScrolled && topPosition != 0) {
            hasScrolled = YES;
        }
        
        if (hasScrolled && !atTop && [appDelegate.storiesCollection isStoryUnread:activeStory]) {
            [appDelegate.storiesCollection markStoryRead:activeStory];
            [appDelegate.storiesCollection syncStoryAsRead:activeStory];
            
            NSIndexPath *reloadIndexPath = appDelegate.feedDetailViewController.storyTitlesTable.indexPathForSelectedRow;
            if (reloadIndexPath != nil) {
                [appDelegate.feedDetailViewController.storyTitlesTable reloadRowsAtIndexPaths:@[reloadIndexPath]
                                                                             withRowAnimation:UITableViewRowAnimationNone];
            }
        }
        
        if (!isNavBarHidden && self.canHideNavigationBar && !nearTop) {
            [appDelegate.storyPagesViewController setNavigationBarHidden:YES];
        }
        
        if (isNavBarHidden && pullingDown) {
            [appDelegate.storyPagesViewController setNavigationBarHidden:NO];
        }
        
        if (!atTop && !atBottom && !singlePage) {
            BOOL traversalVisible = appDelegate.storyPagesViewController.traverseView.alpha > 0;
            
            // Hide
            [UIView animateWithDuration:.3 delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
            animations:^{
                self.appDelegate.storyPagesViewController.traverseView.alpha = 0;
                
                if (traversalVisible) {
                    [self.appDelegate.storyPagesViewController hideAutoscrollImmediately];
                }
            } completion:^(BOOL finished) {
                
            }];
        } else if (singlePage || !isHorizontal) {
            appDelegate.storyPagesViewController.traverseView.alpha = 1;
//            NSLog(@" ---> Bottom position: %d", bottomPosition);
            if (bottomPosition >= 0 || !isHorizontal) {
                appDelegate.storyPagesViewController.traverseBottomConstraint.constant = 0;
            } else {
                if (webpageHeight > 0 && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
                    appDelegate.storyPagesViewController.traverseBottomConstraint.constant = viewportHeight - (webpageHeight - topPosition) - safeBottomMargin;
                } else {
                    appDelegate.storyPagesViewController.traverseBottomConstraint.constant = 0;
                }
            }
        } else if ((!singlePage && (atTop && !atBottom)) || [[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPhone) {
            // Pin to bottom of viewport, regardless of scrollview
            appDelegate.storyPagesViewController.traversePinned = YES;
            appDelegate.storyPagesViewController.traverseFloating = NO;
            [appDelegate.storyPagesViewController.view layoutIfNeeded];

            appDelegate.storyPagesViewController.traverseBottomConstraint.constant = 0;
            [appDelegate.storyPagesViewController.view layoutIfNeeded];
            [UIView animateWithDuration:.3 delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
             animations:^{
                [self.appDelegate.storyPagesViewController.view layoutIfNeeded];
                self.appDelegate.storyPagesViewController.traverseView.alpha = 1;
            } completion:nil];
        } else if (appDelegate.storyPagesViewController.traverseView.alpha == 1 &&
                   appDelegate.storyPagesViewController.traversePinned) {
            // Scroll with bottom of scrollview, but smoothly
            appDelegate.storyPagesViewController.traverseFloating = YES;
            [appDelegate.storyPagesViewController.view layoutIfNeeded];

            appDelegate.storyPagesViewController.traverseBottomConstraint.constant = 0;
            [appDelegate.storyPagesViewController.view layoutIfNeeded];
            [UIView animateWithDuration:.3 delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
             animations:^{
                 [self.appDelegate.storyPagesViewController.view layoutIfNeeded];
             } completion:^(BOOL finished) {
                 self.appDelegate.storyPagesViewController.traversePinned = NO;
             }];
        } else {
            // Scroll with bottom of scrollview
            appDelegate.storyPagesViewController.traversePinned = NO;
            appDelegate.storyPagesViewController.traverseFloating = YES;
            appDelegate.storyPagesViewController.traverseView.alpha = 1;
            appDelegate.storyPagesViewController.traverseBottomConstraint.constant = viewportHeight - (webpageHeight - topPosition) - safeBottomMargin;
        }
        
        [appDelegate.storyPagesViewController resizeScrollView];
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
    if (!hasScrolled) return;
    
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

- (void)realignScroll {
    hasScrolled = NO;
    [self scrollToLastPosition:YES];
}

- (void)scrollToLastPosition:(BOOL)animated {
    if (hasScrolled) return;
    hasScrolled = YES;
    
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
                if (([scroll isKindOfClass:[NSNull class]] || [scroll integerValue] == 0) && !self->scrollPct) {
                    NSLog(@" ---> No scroll found for story: %@", [strongSelf.activeStory objectForKey:@"story_title"]);
                    // No scroll found
                    continue;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!self->scrollPct) self->scrollPct = [scroll floatValue] / 1000.f;
                    NSInteger position = floor(self->scrollPct * strongSelf.webView.scrollView.contentSize.height);
                    NSInteger maxPosition = (NSInteger)(floor(strongSelf.webView.scrollView.contentSize.height - strongSelf.webView.frame.size.height));
                    if (position > maxPosition) {
                        NSLog(@"Position too far, scaling back to max position: %ld > %ld", (long)position, (long)maxPosition);
                        position = maxPosition;
                    }
                    if (position > 0) {
                        NSLog(@"Scrolling to %ld / %.1f%% (%.f+%.f) on %@-%@", (long)position, self->scrollPct*100, strongSelf.webView.scrollView.contentSize.height, strongSelf.webView.frame.size.height, [story objectForKey:@"story_hash"], [strongSelf.activeStory objectForKey:@"story_title"]);
                            [strongSelf.webView.scrollView setContentOffset:CGPointMake(0, position) animated:animated];
                    }
                });
            }
            [cursor close];
            
        }];
    });
}

- (void)setActiveStoryAtIndex:(NSInteger)activeStoryIndex {
    if (activeStoryIndex >= 0) {
        self.activeStory = [[appDelegate.storiesCollection.activeFeedStories
                             objectAtIndex:activeStoryIndex] mutableCopy];
    } else {
        self.activeStory = [appDelegate.activeStory mutableCopy];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURLRequest *request = navigationAction.request;
    NSURL *url = [request URL];
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
        appDelegate.activeComment = nil;
        appDelegate.activeShareType = action;
        
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
                    appDelegate.activeComment = [friendComments objectAtIndex:i];
                }
            }
            
            
            NSArray *friendShares = [self.activeStory objectForKey:@"friend_shares"];
            for (int i = 0; i < friendShares.count; i++) {
                NSString *userId = [NSString stringWithFormat:@"%@",
                                    [[friendShares objectAtIndex:i] objectForKey:@"user_id"]];
                if([userId isEqualToString:[NSString stringWithFormat:@"%@",
                                            [urlComponents objectAtIndex:2]]]){
                    appDelegate.activeComment = [friendShares objectAtIndex:i];
                }
            }
            
            if (appDelegate.activeComment == nil) {
                NSArray *publicComments = [self.activeStory objectForKey:@"public_comments"];
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
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
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
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else if ([action isEqualToString:@"togglechanges"]) {
            if (self.activeStory[@"story_changes"] != nil) {
                [self.activeStory removeObjectForKey:@"story_changes"];
                [self drawStory];
            } else {
                [self fetchStoryChanges];
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
            BOOL isSaved = [appDelegate.storiesCollection toggleStorySaved:self.activeStory];
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
        } else if ([action isEqualToString:@"premium"]) {
            [self.appDelegate showPremiumDialog];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else if ([action isEqualToString:@"show-profile"] && [urlComponents count] > 6) {
            appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
                        
            for (int i = 0; i < appDelegate.storiesCollection.activeFeedUserProfiles.count; i++) {
                NSString *userId = [NSString stringWithFormat:@"%@", [[appDelegate.storiesCollection.activeFeedUserProfiles objectAtIndex:i] objectForKey:@"user_id"]];
                if ([userId isEqualToString:appDelegate.activeUserProfileId]){
                    appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@", [[appDelegate.storiesCollection.activeFeedUserProfiles objectAtIndex:i] objectForKey:@"username"]];
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
        } else if ([action isEqualToString:@"notify-loaded"]) {
            [self webViewNotifyLoaded];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
    } else if ([url.host hasSuffix:@"itunes.apple.com"]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
//        NSLog(@"Link clicked, views: %@ = %@", appDelegate.navigationController.topViewController, appDelegate.masterContainerViewController.childViewControllers);
        if (appDelegate.isPresentingActivities) {
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
        [appDelegate showOriginalStory:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)showOriginalStory:(UIGestureRecognizer *)gesture {
    NSURL *url = [NSURL URLWithString:[appDelegate.activeStory
                                       objectForKey:@"story_permalink"]];
    [appDelegate hidePopover];

    if (!gesture || [gesture isKindOfClass:[UITapGestureRecognizer class]]) {
        [appDelegate showOriginalStory:url];
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
        [appDelegate showOriginalStory:url];
        gesture.enabled = NO;
        gesture.enabled = YES;
    }
}

- (void)showUserProfile:(NSString *)userId xCoordinate:(int)x yCoordinate:(int)y width:(int)width height:(int)height {
    CGRect frame = CGRectZero;
    if (!self.isPhoneOrCompact) {
        // only adjust for the bar if user is scrolling
        if (appDelegate.storiesCollection.isRiverView ||
            appDelegate.storiesCollection.isSocialView ||
            appDelegate.storiesCollection.isSavedView ||
            appDelegate.storiesCollection.isWidgetView ||
            appDelegate.storiesCollection.isReadView) {
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
    [appDelegate showUserProfileModal:[NSValue valueWithCGRect:frame]];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    if (!self.hasStory) // other Web page loads aren't visible
        return;

    // DOM should already be set up here
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    [self changeFontSize:[userPreferences stringForKey:@"story_font_size"]];
    [self changeLineSpacing:[userPreferences stringForKey:@"story_line_spacing"]];
    [self.webView evaluateJavaScript:@"document.body.style.webkitTouchCallout='none';" completionHandler:nil];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self loadStory];
}

- (void)loadStory {
    if (!self.fullStoryHTML)
        return; // if we're loading anything other than a full story, the view will be hidden
    
    [self.activityIndicator stopAnimating];
    
    [self loadHTMLString:self.fullStoryHTML];
    self.fullStoryHTML = nil;
    self.hasStory = YES;
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    if ([appDelegate.storiesCollection.activeFeedStories count] &&
        self.activeStoryId) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .15 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
                           [self checkTryFeedStory];
                       });
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.webView.hidden = NO;
        [self.webView setNeedsDisplay];
    });
}

- (void)webViewNotifyLoaded {
    [self scrollToLastPosition:YES];
}

- (void)checkTryFeedStory {
    // see if it's a tryfeed for animation
    if (!self.webView.hidden &&
        appDelegate.tryFeedCategory &&
        ([[self.activeStory objectForKey:@"id"] isEqualToString:appDelegate.tryFeedStoryId] ||
         [[self.activeStory objectForKey:@"story_hash"] isEqualToString:appDelegate.tryFeedStoryId])) {
        [MBProgressHUD hideHUDForView:appDelegate.storyPagesViewController.view animated:YES];
        
        if ([appDelegate.tryFeedCategory isEqualToString:@"comment_like"] ||
            [appDelegate.tryFeedCategory isEqualToString:@"comment_reply"]) {
            NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictSocialProfile objectForKey:@"user_id"]];
            NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true, true);", currentUserId];
            [self.webView evaluateJavaScript:jsFlashString completionHandler:nil];
        } else if ([appDelegate.tryFeedCategory isEqualToString:@"story_reshare"] ||
                   [appDelegate.tryFeedCategory isEqualToString:@"reply_reply"]) {
            NSString *blurblogUserId = [NSString stringWithFormat:@"%@", [self.activeStory objectForKey:@"social_user_id"]];
            NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true, true);", blurblogUserId];
            [self.webView evaluateJavaScript:jsFlashString completionHandler:nil];
        }
        appDelegate.tryFeedCategory = nil;
    }
}

- (void)setFontStyle:(NSString *)fontStyle {
    NSString *jsString;
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    [userPreferences setObject:fontStyle forKey:@"fontStyle"];
    [userPreferences synchronize];
    
    jsString = [NSString stringWithFormat:@
                "document.getElementById('NB-font-style').setAttribute('class', '%@')",
                fontStyle];
    
    [self.webView evaluateJavaScript:jsString completionHandler:nil];
    
    if (![fontStyle hasPrefix:@"NB-"]) {
        jsString = [NSString stringWithFormat:@
                    "document.getElementById('NB-font-style').setAttribute('style', 'font-family: %@;')",
                    fontStyle];
    } else {
        jsString = @"document.getElementById('NB-font-style').setAttribute('style', '')";
    }
    
    [self.webView evaluateJavaScript:jsString completionHandler:nil];
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

- (void)updateStoryTheme {
    self.view.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    
    NSString *jsString = [NSString stringWithFormat:@"document.getElementById('NB-theme-style').href='storyDetailView%@.css';",
                          [ThemeManager themeManager].themeCSSSuffix];
    
    [self.webView evaluateJavaScript:jsString completionHandler:nil];
    
    self.webView.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    
    if ([ThemeManager themeManager].isDarkTheme) {
        self.webView.scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    } else {
        self.webView.scrollView.indicatorStyle = UIScrollViewIndicatorStyleBlack;
    }
}

- (BOOL)canHideNavigationBar {
    if (!appDelegate.storyPagesViewController.allowFullscreen) {
//        NSLog(@"canHideNavigationBar: no, toggle is off");  // log
        return NO;
    }
    
    return YES;
}

- (BOOL)isSinglePage {
    NSInteger webpageHeight = self.webView.scrollView.contentSize.height;
    NSInteger viewportHeight = self.view.frame.size.height;
    
    return webpageHeight - 200 <= viewportHeight;
}

#pragma mark -
#pragma mark Actions

- (void)toggleLikeComment:(BOOL)likeComment {
    [appDelegate.storyPagesViewController showShareHUD:@"Favoriting"];
    NSString *urlString;
    if (likeComment) {
        urlString = [NSString stringWithFormat:@"%@/social/like_comment",
                               self.appDelegate.url];
    } else {
        urlString = [NSString stringWithFormat:@"%@/social/remove_like_comment",
                               self.appDelegate.url];
    }
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[self.activeStory objectForKey:@"id"] forKey:@"story_id"];
    [params setObject:[self.activeStory objectForKey:@"story_feed_id"] forKey:@"story_feed_id"];
    [params setObject:[appDelegate.activeComment objectForKey:@"user_id"] forKey:@"comment_user_id"];
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishLikeComment:responseObject];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        [self requestFailed:error statusCode:httpResponse.statusCode];
    }];
}

- (void)finishLikeComment:(NSDictionary *)results {
    // add the comment into the activeStory dictionary
    NSDictionary *newStory = [DataUtilities updateComment:results for:appDelegate];

    // update the current story and the activeFeedStories
    appDelegate.activeStory = newStory;
    [self setActiveStoryAtIndex:-1];
    
    NSMutableArray *newActiveFeedStories = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < appDelegate.storiesCollection.activeFeedStories.count; i++)  {
        NSDictionary *feedStory = [appDelegate.storiesCollection.activeFeedStories objectAtIndex:i];
        NSString *storyId = [NSString stringWithFormat:@"%@", [feedStory objectForKey:@"story_hash"]];
        NSString *currentStoryId = [NSString stringWithFormat:@"%@", [self.activeStory objectForKey:@"story_hash"]];
        if ([storyId isEqualToString: currentStoryId]){
            [newActiveFeedStories addObject:newStory];
        } else {
            [newActiveFeedStories addObject:[appDelegate.storiesCollection.activeFeedStories objectAtIndex:i]];
        }
    }
    
    appDelegate.storiesCollection.activeFeedStories = [NSArray arrayWithArray:newActiveFeedStories];
    
    [MBProgressHUD hideHUDForView:appDelegate.storyPagesViewController.view animated:NO];
    [MBProgressHUD hideHUDForView:appDelegate.storyPagesViewController.currentPage.view animated:NO];
    [self refreshComments:@"like"];
} 


- (void)requestFailed:(NSError *)error statusCode:(NSInteger)statusCode {
    NSLog(@"Error in story detail: %@", error);
    
    [MBProgressHUD hideHUDForView:appDelegate.storyPagesViewController.view animated:NO];
    [MBProgressHUD hideHUDForView:appDelegate.storyPagesViewController.currentPage.view animated:NO];

    [self informError:error statusCode:statusCode];
}

- (void)openShareDialog {
    // test to see if the user has commented
    // search for the comment from friends comments
    NSArray *friendComments = [self.activeStory objectForKey:@"friend_comments"];
    
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictSocialProfile objectForKey:@"user_id"]];
    for (int i = 0; i < friendComments.count; i++) {
        NSString *userId = [NSString stringWithFormat:@"%@",
                            [[friendComments objectAtIndex:i] objectForKey:@"user_id"]];
        if([userId isEqualToString:currentUserId]){
            appDelegate.activeComment = [friendComments objectAtIndex:i];
            break;
        } else {
            appDelegate.activeComment = nil;
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
}

- (void)openTrainingDialog:(int)x yCoordinate:(int)y width:(int)width height:(int)height {
    CGRect frame = CGRectZero;
    if (!self.isPhoneOrCompact) {
        // only adjust for the bar if user is scrolling
        if (appDelegate.storiesCollection.isRiverView ||
            appDelegate.storiesCollection.isSocialView ||
            appDelegate.storiesCollection.isSavedView ||
            appDelegate.storiesCollection.isWidgetView ||
            appDelegate.storiesCollection.isReadView) {
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
    [appDelegate openTrainStory:[NSValue valueWithCGRect:frame]];
}

- (void)openUserTagsDialog:(int)x yCoordinate:(int)y width:(int)width height:(int)height {
    CGRect frame = CGRectZero;
    // only adjust for the bar if user is scrolling
    if (appDelegate.storiesCollection.isRiverView ||
        appDelegate.storiesCollection.isSocialView ||
        appDelegate.storiesCollection.isSavedView ||
        appDelegate.storiesCollection.isReadView) {
        if (self.webView.scrollView.contentOffset.y == -20) {
            y = y + 20;
        }
    } else {
        if (self.webView.scrollView.contentOffset.y == -9) {
            y = y + 9;
        }
    }
    
    frame = CGRectMake(x, y, width, height);

    [appDelegate openUserTagsStory:[NSValue valueWithCGRect:frame]];
}

- (BOOL)isTag:(NSString *)tagName equalTo:(NSString *)tagValue {
    return [tagName isKindOfClass:[NSString class]] && [tagName isEqualToString:tagValue];
}

- (void)tapImage:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint pt = [self pointForGesture:gestureRecognizer];
    if (pt.x == CGPointZero.x && pt.y == CGPointZero.y) return;
//    NSLog(@"Tapped point: %@", NSStringFromCGPoint(pt));
    [webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'tagName');", (long)pt.x,(long)pt.y] completionHandler:^(NSString *tagName, NSError *error) {
        if ([self isTag:tagName equalTo:@"IMG"]) {
            [self showImageMenu:pt];
            [gestureRecognizer setEnabled:NO];
            [gestureRecognizer setEnabled:YES];
        }
    }];
}

- (void)showImageMenu:(CGPoint)pt {
    [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'title');", (long)pt.x,(long)pt.y] completionHandler:^(NSString *title, NSError *error) {
        [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'alt');", (long)pt.x,(long)pt.y] completionHandler:^(NSString *alt, NSError *error) {
            [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'src');", (long)pt.x,(long)pt.y] completionHandler:^(NSString *src, NSError * error) {
                NSString *alertTitle = title.length ? title : alt;
                self->activeLongPressUrl = [NSURL URLWithString:src];
                
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:alertTitle.length ? alertTitle : nil
                                                                               message:nil
                                                                        preferredStyle:UIAlertControllerStyleActionSheet];
                [alert addAction:[UIAlertAction actionWithTitle:@"View and zoom" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self.appDelegate showOriginalStory:self->activeLongPressUrl];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Copy image" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self fetchImage:self->activeLongPressUrl copy:YES save:NO];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Save to camera roll" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self fetchImage:self->activeLongPressUrl copy:NO save:YES];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    
                }]];
                
                [alert setModalPresentationStyle:UIModalPresentationPopover];
                
                UIPopoverPresentationController *popover = [alert popoverPresentationController];
                popover.sourceRect = CGRectMake(pt.x, pt.y, 1, 1);
                popover.sourceView = self.appDelegate.storyPagesViewController.view;
                [self presentViewController:alert animated:YES completion:nil];
            }];
        }];
    }];
}

- (void)showLinkContextMenu:(CGPoint)pt {
    [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'href');", (long)pt.x,(long)pt.y] completionHandler:^(NSString *href, NSError *error) {
        [self.webView evaluateJavaScript:[NSString stringWithFormat:@"linkAt(%li, %li, 'innerText');", (long)pt.x,(long)pt.y] completionHandler:^(NSString *title, NSError *error) {
            NSURL *url = [NSURL URLWithString:href];
            
            if (!href || ![href length]) return;
            
            NSValue *ptValue = [NSValue valueWithCGPoint:pt];
            [self.appDelegate showSendTo:self.appDelegate.storyPagesViewController
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

- (CGPoint)pointForEvent:(NSNotification*)notification {
    if (self != appDelegate.storyPagesViewController.currentPage) return CGPointZero;
    if (!self.view.window) return CGPointZero;
    
    CGPoint pt;
    NSDictionary *coord = [notification object];
    pt.x = [[coord objectForKey:@"x"] floatValue];
    pt.y = [[coord objectForKey:@"y"] floatValue];
    
    // convert point from window to view coordinate system
    pt = [webView convertPoint:pt fromView:nil];
    
    return pt;
}

- (CGPoint)pointForGesture:(UIGestureRecognizer *)gestureRecognizer {
    if (self != appDelegate.storyPagesViewController.currentPage) return CGPointZero;
    if (!self.view.window) return CGPointZero;
    
    CGPoint pt = [gestureRecognizer locationInView:appDelegate.storyPagesViewController.currentPage.webView];
    
    return pt;
}

- (void)fetchImage:(NSURL *)url copy:(BOOL)copy save:(BOOL)save {
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    [appDelegate.storyPagesViewController showShareHUD:copy ?
                                               @"Copying..." : @"Saving..."];
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    [manager setResponseSerializer:[AFImageResponseSerializer serializer]];
    [manager GET:url.absoluteString parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        UIImage *image = responseObject;
        if (copy) {
            [UIPasteboard generalPasteboard].image = image;
            [self flashCheckmarkHud:@"copied"];
        } else if (save) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                PHAssetChangeRequest *changeRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                changeRequest.creationDate = [NSDate date];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        [self flashCheckmarkHud:@"saved"];
                    } else {
                        [MBProgressHUD hideHUDForView:self.webView animated:NO];
                        [self informError:error];
                    }
                });
            }];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [MBProgressHUD hideHUDForView:self.webView animated:YES];
        [self informError:@"Could not fetch image"];
    }];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if ([self respondsToSelector:action])
        return self.noStoryMessage.hidden;
    return [super canPerformAction:action withSender:sender];
}

# pragma mark -
# pragma mark Subscribing to blurblog

- (void)subscribeToBlurblog {
    [appDelegate.storyPagesViewController showShareHUD:@"Following"];
    NSString *urlString = [NSString stringWithFormat:@"%@/social/follow",
                     self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[appDelegate.storiesCollection.activeFeed
                           objectForKey:@"user_id"] 
                   forKey:@"user_id"];

    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishSubscribeToBlurblog:responseObject];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        [self requestFailed:error statusCode:httpResponse.statusCode];
    }];
}

- (void)finishSubscribeToBlurblog:(NSDictionary *)results {
    [MBProgressHUD hideHUDForView:appDelegate.storyPagesViewController.view animated:NO];
    self.storyHUD = [MBProgressHUD showHUDAddedTo:self.webView animated:YES];
    self.storyHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
    self.storyHUD.mode = MBProgressHUDModeCustomView;
    self.storyHUD.removeFromSuperViewOnHide = YES;  
    self.storyHUD.labelText = @"Followed";
    [self.storyHUD hide:YES afterDelay:1];
    appDelegate.storyPagesViewController.navigationItem.leftBarButtonItem = nil;
    [appDelegate reloadFeedsView:NO];
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
    [self.webView evaluateJavaScript:jsString completionHandler:^(id result, NSError * _Nullable error) {
        [self.webView evaluateJavaScript:@"attachFastClick();" completionHandler:^(id result, NSError * _Nullable error) {
            // HACK to make the scroll event happen after the replace innerHTML event above happens.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .15 * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^{
                if (!replyId) {
                    NSString *currentUserId = [NSString stringWithFormat:@"%@",
                                               [self.appDelegate.dictSocialProfile objectForKey:@"user_id"]];
                    NSString *jsFlashString = [[NSString alloc]
                                               initWithFormat:@"slideToComment('%@', true);", currentUserId];
                    [self.webView evaluateJavaScript:jsFlashString completionHandler:^(id result, NSError * _Nullable error) {
                        [self flashCheckmarkHud:shareType];
                        [self refreshSideOptions];
                    }];
                } else if ([replyId isEqualToString:@"like"]) {
                    
                } else {
                    NSString *jsFlashString = [[NSString alloc]
                                               initWithFormat:@"slideToComment('%@', true);", replyId];
                    [self.webView evaluateJavaScript:jsFlashString completionHandler:^(id result, NSError * _Nullable error) {
                        [self flashCheckmarkHud:shareType];
                        [self refreshSideOptions];
                    }];
                }
            });
        }];
    }];
}

- (void)flashCheckmarkHud:(NSString *)messageType {
    [MBProgressHUD hideHUDForView:self.webView animated:NO];
    [MBProgressHUD hideHUDForView:appDelegate.storyPagesViewController.currentPage.view animated:NO];
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
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictSocialProfile objectForKey:@"user_id"]];
    NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true);", currentUserId];
    [self.webView evaluateJavaScript:jsFlashString completionHandler:nil];
}

- (void)tryScrollingDown:(BOOL)down {
    UIScrollView *scrollView = webView.scrollView;
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
    // Don't do this in the background, to avoid scrolling to the top unnecessarily
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        return;
    }
    
//    NSLog(@"changeWebViewWidth: %@ / %@ / %@", NSStringFromCGSize(self.view.bounds.size), NSStringFromCGSize(webView.scrollView.bounds.size), NSStringFromCGSize(webView.scrollView.contentSize));

    NSInteger contentWidth = CGRectGetWidth(webView.scrollView.bounds);
    NSString *contentWidthClass;

#if TARGET_OS_MACCATALYST
    // CATALYST: probably will want to add custom CSS for Macs.
    contentWidthClass = @"NB-ipad-wide NB-ipad-pro-12-wide NB-width-768";
#else
    UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
    
    if (UIInterfaceOrientationIsLandscape(orientation) && !self.isPhoneOrCompact) {
        if (iPadPro12) {
            contentWidthClass = @"NB-ipad-wide NB-ipad-pro-12-wide";
        } else if (iPadPro10) {
            contentWidthClass = @"NB-ipad-wide NB-ipad-pro-10-wide";
        } else {
            contentWidthClass = @"NB-ipad-wide";
        }
    } else if (!UIInterfaceOrientationIsLandscape(orientation) && !self.isPhoneOrCompact) {
        if (iPadPro12) {
            contentWidthClass = @"NB-ipad-narrow NB-ipad-pro-12-narrow";
        } else if (iPadPro10) {
            contentWidthClass = @"NB-ipad-narrow NB-ipad-pro-10-narrow";
        } else {
            contentWidthClass = @"NB-ipad-narrow";
        }
    } else if (UIInterfaceOrientationIsLandscape(orientation) && self.isPhoneOrCompact) {
        contentWidthClass = @"NB-iphone-wide";
    } else {
        contentWidthClass = @"NB-iphone";
    }
    
    contentWidthClass = [NSString stringWithFormat:@"%@ NB-width-%d",
                         contentWidthClass, (int)floorf(CGRectGetWidth(webView.scrollView.bounds))];
#endif
    
    NSString *alternateViewClass = @"";
    if (!self.isPhoneOrCompact) {
        if (!appDelegate.detailViewController.storyTitlesOnLeft) {
            alternateViewClass = @"NB-titles-bottom";
        } else {
            alternateViewClass = @"NB-titles-left";
        }
    }
    
    NSString *riverClass = (appDelegate.storiesCollection.isRiverView ||
                            appDelegate.storiesCollection.isSocialView ||
                            appDelegate.storiesCollection.isSavedView ||
                            appDelegate.storiesCollection.isWidgetView ||
                            appDelegate.storiesCollection.isReadView) ?
                            @"NB-river" : @"NB-non-river";
    
    NSString *jsString = [[NSString alloc] initWithFormat:
                          @"$('body').attr('class', '%@ %@ %@');"
                          "document.getElementById(\"viewport\").setAttribute(\"content\", \"width=%li;initial-scale=1; minimum-scale=1.0; maximum-scale=1.0; user-scalable=0;\");",
                          contentWidthClass,
                          alternateViewClass,
                          riverClass,
                          (long)contentWidth];
    [self.webView evaluateJavaScript:jsString completionHandler:nil];
}

- (void)refreshHeader {
    NSString *headerString = [[[self getHeader] stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"]
                              stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *jsString = [NSString stringWithFormat:@"document.getElementById('NB-header-container').innerHTML = '%@';",
                          headerString];
    
    [self.webView evaluateJavaScript:jsString completionHandler:^(id result, NSError *error) {
        [self.webView evaluateJavaScript:@"attachFastClick();" completionHandler:nil];
    }];
}

- (void)refreshSideOptions {
    NSString *sideOptionsString = [[[self getSideOptions] stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"]
                              stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *jsString = [NSString stringWithFormat:@"document.getElementById('NB-sideoptions-container').innerHTML = '%@';",
                          sideOptionsString];
    
    [self.webView evaluateJavaScript:jsString completionHandler:^(id result, NSError *error) {
        [self.webView evaluateJavaScript:@"attachFastClick();" completionHandler:nil];
    }];
}

#pragma mark -
#pragma mark Text view

- (void)showTextOrStoryView {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                           [self.activeStory objectForKey:@"story_feed_id"]];
    if ([appDelegate isFeedInTextView:feedIdStr]) {
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
    [appDelegate.storyPagesViewController setTextButton:(StoryDetailViewController *)self];
    [self drawStory];
}

- (void)fetchTextView {
    if (!self.activeStoryId || !self.activeStory) return;
    self.inTextView = YES;
//    NSLog(@"Fetching Text: %@", [self.activeStory objectForKey:@"story_title"]);
    if (self.activeStory == appDelegate.storyPagesViewController.currentPage.activeStory) {
        [self.appDelegate.storyPagesViewController showFetchingTextNotifier];
    }
    NSString *storyId = [self.activeStory objectForKey:@"id"];
    
    [appDelegate fetchTextForStory:[self.activeStory objectForKey:@"story_hash"] inFeed:[self.activeStory objectForKey:@"story_feed_id"] checkCache:YES withCallback:^(NSString *text) {
        if (text != nil) {
            [self finishFetchText:text storyId:storyId];
        } else {
            [self failedFetchText];
        }
    }];
}

- (void)failedFetchText {
    [self.appDelegate.storyPagesViewController hideNotifier];
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    if (self.activeStory == appDelegate.storyPagesViewController.currentPage.activeStory) {
        [self informError:@"Could not fetch text"];
    }
    self.inTextView = NO;
    [appDelegate.storyPagesViewController setTextButton:(StoryDetailViewController *)self];
}

- (void)finishFetchText:(NSString *)text storyId:(NSString *)storyId {
    if (![storyId isEqualToString:[self.activeStory objectForKey:@"id"]]) {
        [self.appDelegate.storyPagesViewController hideNotifier];
        [MBProgressHUD hideHUDForView:self.webView animated:YES];
        self.inTextView = NO;
        [appDelegate.storyPagesViewController setTextButton:(StoryDetailViewController *)self];
        return;
    }
    
    NSMutableDictionary *newActiveStory = [self.activeStory mutableCopy];
    [newActiveStory setObject:text forKey:@"original_text"];
    if ([[self.activeStory objectForKey:@"story_hash"] isEqualToString:[appDelegate.activeStory objectForKey:@"story_hash"]]) {
        appDelegate.activeStory = newActiveStory;
    }
    self.activeStory = newActiveStory;
    
    [self.appDelegate.storyPagesViewController hideNotifier];
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    
    self.inTextView = YES;
    
    [self drawStory];
    
//    NSLog(@"Fetched Text: %@", [self.activeStory objectForKey:@"story_title"]);
}

- (void)fetchStoryChanges {
    if (!self.activeStoryId || !self.activeStory) return;
    self.inTextView = YES;
//    NSLog(@"Fetching Changes: %@", [self.activeStory objectForKey:@"story_title"]);
    if (self.activeStory == appDelegate.storyPagesViewController.currentPage.activeStory) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.appDelegate.storyPagesViewController showFetchingTextNotifier];
        });
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/rss_feeds/story_changes",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[self.activeStory objectForKey:@"story_hash"] forKey:@"story_hash"];
    [params setObject:@"true" forKey:@"show_changes"];
    NSString *storyId = [self.activeStory objectForKey:@"id"];
    [appDelegate GET:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishFetchStoryChanges:responseObject storyId:storyId];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self failedFetchStoryChanges:error];
    }];
}

- (void)failedFetchStoryChanges:(NSError *)error {
    [self.appDelegate.storyPagesViewController hideNotifier];
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    if (self.activeStory == appDelegate.storyPagesViewController.currentPage.activeStory) {
        [self informError:@"Could not fetch changes"];
    }
    self.inTextView = NO;
    [appDelegate.storyPagesViewController setTextButton:(StoryDetailViewController *)self];
}

- (void)finishFetchStoryChanges:(NSDictionary *)results storyId:(NSString *)storyId {
    if ([results[@"failed"] boolValue]) {
        [self failedFetchText];
        return;
    }
    
    if (![storyId isEqualToString:self.activeStory[@"id"]]) {
        [self.appDelegate.storyPagesViewController hideNotifier];
        [MBProgressHUD hideHUDForView:self.webView animated:YES];
        self.inTextView = NO;
        [appDelegate.storyPagesViewController setTextButton:(StoryDetailViewController *)self];
        return;
    }
    
    NSMutableDictionary *newActiveStory = [self.activeStory mutableCopy];
    NSDictionary *resultsStory = results[@"story"];
    newActiveStory[@"story_changes"] = resultsStory[@"story_content"];
    if ([self.activeStory[@"story_hash"] isEqualToString:appDelegate.activeStory[@"story_hash"]]) {
        appDelegate.activeStory = newActiveStory;
    }
    self.activeStory = newActiveStory;
    
    [self.appDelegate.storyPagesViewController hideNotifier];
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    
    self.inTextView = YES;
    
    [self drawStory];
    
//    NSLog(@"Fetched Changes: %@", self.activeStory[@"story_title"]);
}

@end
