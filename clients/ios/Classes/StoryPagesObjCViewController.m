//
//  StoryPagesObjCViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "StoryPagesObjCViewController.h"
#import "NewsBlurAppDelegate.h"
#import "FontSettingsViewController.h"
#import "UserProfileViewController.h"
#import "ShareViewController.h"
#import "Utilities.h"
#import "NSString+HTML.h"
#import "DataUtilities.h"
#import "SBJson4.h"
#import "UIBarButtonItem+Image.h"
#import "THCircularProgressView.h"
#import "FMDatabase.h"
#import "StoriesCollection.h"
#import "NewsBlur-Swift.h"

@import WebKit;

@interface StoryPagesObjCViewController () <StoryToolbarDelegate>

@property (nonatomic) CGFloat statusBarHeight;
@property (nonatomic) BOOL wasNavigationBarHidden;
@property (nonatomic) BOOL isNavigationBarFaded;
@property (nonatomic, readwrite) CGFloat navigationBarFadeAlpha;
@property (nonatomic) BOOL isUpdatingNavigationBarFade;
@property (nonatomic) BOOL doneInitialRefresh;
@property (nonatomic) BOOL doneInitialDisplay;
@property (nonatomic) BOOL isRefreshingPages;
@property (nonatomic, strong) StoryDetailViewController *pendingPresentationPage;
@property (nonatomic, copy) NSString *pendingPresentationHash;
@property (nonatomic, copy) void (^pendingPresentationCompletion)(NSInteger location);
@property (nonatomic, weak) StoriesCollection *pendingPresentationCollection;
@property (nonatomic) NSUInteger pendingPresentationFetch;
@property (nonatomic, weak) UIViewController *pendingPresentationSource;
@property (nonatomic, strong) UIView *storyPreparationHost;
@property (nonatomic) BOOL pendingPresentationAnimated;
@property (nonatomic, strong) StoryDetailViewController *pendingIntermediatePage;
@property (nonatomic, strong) UIView *storyIntermediatePreparationHost;
@property (nonatomic, strong) UIView *storySelectionTransitionHost;
@property (nonatomic, strong) UIViewPropertyAnimator *storySelectionAnimator;
@property (nonatomic, strong) NSArray<StoryDetailViewController *> *storySelectionTransitionPages;
@property (nonatomic, strong) NSMutableDictionary<NSString *, StoryDetailViewController *> *deferredSelectionRedraws;
@property (nonatomic, strong) UIView *storySelectionRedrawCover;
@property (nonatomic) BOOL refreshAfterStorySelection;
@property (nonatomic) BOOL isRepositioningFirstPage;
@property (nonatomic, strong) NSTimer *autoscrollTimer;
@property (nonatomic, strong) NSTimer *autoscrollViewTimer;
@property (nonatomic, strong) NSString *restoringStoryId;
@property (nonatomic) CGSize lastScrollViewBoundsSize;
@property (nonatomic, strong) UIBarButtonItem *temporaryFullScreenButton;
@property (nonatomic, strong) UIScreenEdgePanGestureRecognizer *storyTitlesEdgeRevealGesture;
@property (nonatomic, strong) UIView *uiTestStoryStateProbeView;
@property (nonatomic, strong) UIView *uiTestTraverseFadeProbeView;

- (void)resetTraverseFadeForStoryChange;
- (void)completePendingStoryPresentationCallingCompletion:(BOOL)callCompletion;
- (void)finishStorySelectionAnimation;
- (void)animatePreparedStorySelection:(StoryDetailViewController *)page location:(NSInteger)location;
- (void)prepareSelectionReplacement:(StoryDetailViewController *)page redraw:(BOOL)redraw;
- (void)cancelPendingStoryPresentationWithoutRedraw;

@end

@implementation StoryPagesObjCViewController

@synthesize currentPage, nextPage, previousPage;
@synthesize circularProgressView;
@synthesize buttonPrevious;
@synthesize buttonNext;
@synthesize buttonAction;
@synthesize buttonText;
@synthesize buttonSend;
@synthesize fontSettingsButton;
@synthesize originalStoryButton;
@synthesize subscribeButton;
@synthesize buttonBack;
@synthesize bottomSize;
@synthesize bottomSizeHeightConstraint;
@synthesize loadingIndicator;
@synthesize inTouchMove;
@synthesize isDraggingScrollview;
@synthesize waitingForNextUnreadFromServer;
@synthesize storyHUD;
@synthesize scrollingToPage;
@synthesize traverseView;
@synthesize isAnimatedIntoPlace;
@synthesize progressView, progressViewContainer;
@synthesize traversePinned, traverseFloating;
@synthesize traverseBottomConstraint;
@synthesize scrollBottomConstraint;

- (CGFloat)traverseBottomGap {
    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPhone) {
        return 12;
    }
    CGFloat safeAreaBottom = self.view.safeAreaInsets.bottom;
    return (safeAreaBottom > 0) ? 12.0 : 8.0;
}

- (void)ensureTemporaryFullScreenButton {
    if (self.temporaryFullScreenButton) {
        return;
    }

    UIImage *fullScreenImage = [[UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right"]
                                imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    self.temporaryFullScreenButton = [[UIBarButtonItem alloc] initWithImage:fullScreenImage
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:appDelegate.detailViewController
                                                                     action:@selector(toggleTemporaryFullScreen:)];
    self.temporaryFullScreenButton.accessibilityLabel = @"Toggle Full Screen";
}

- (void)updateStoryTitleNavigationButtons {
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    [self ensureTemporaryFullScreenButton];

    NSMutableArray *items = [NSMutableArray array];
    [items addObject:originalStoryButton];
    [items addObject:fontSettingsButton];

    // Temporary full-screen toggle button (iPad only, not Mac).
    if (!self.isPhoneOrCompact && !self.isMac) {
        BOOL isTemporaryFullScreen = self.appDelegate.detailViewController.isTemporaryFullScreen;
        NSString *behavior = [[NSUserDefaults standardUserDefaults] stringForKey:@"split_behavior"] ?: @"auto";
        BOOL isUserOverlayMode = [behavior isEqualToString:@"overlay"];

        BOOL shouldShowTemporaryFullScreenButton =
            [StoryDetailFullscreenButtonDecision showsTemporaryFullscreenButtonWithStoryDetailVisible:self.appDelegate.detailViewController.hasVisibleStoryForSidebarLayout
                                                                                    isPhoneOrCompact:self.isPhoneOrCompact
                                                                                               isMac:self.isMac
                                                                                   isUserOverlayMode:isUserOverlayMode
                                                                               isTemporaryFullScreen:isTemporaryFullScreen];

        if (shouldShowTemporaryFullScreenButton) {
            NSString *iconName = isTemporaryFullScreen
                ? @"arrow.down.right.and.arrow.up.left"
                : @"arrow.up.left.and.arrow.down.right";
            self.temporaryFullScreenButton.image = [[UIImage systemImageNamed:iconName]
                                                    imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [items addObject:self.temporaryFullScreenButton];
        }
    }

    if (!self.appDelegate.detailViewController.storyTitlesOnLeft) {
        [items addObject:markReadBarButton];
    }

    self.appDelegate.detailViewController.storiesNavigationItem.rightBarButtonItems = items;
}

- (void)setupStoryTitlesEdgeRevealGesture {
    if (self.storyTitlesEdgeRevealGesture || self.isPhoneOrCompact || !appDelegate.detailViewController.storyTitlesOnLeft) {
        return;
    }

    self.storyTitlesEdgeRevealGesture = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(handleStoryTitlesEdgeReveal:)];
    self.storyTitlesEdgeRevealGesture.edges = UIRectEdgeLeft;
    self.storyTitlesEdgeRevealGesture.maximumNumberOfTouches = 1;
    self.storyTitlesEdgeRevealGesture.delegate = self;
    [self.view addGestureRecognizer:self.storyTitlesEdgeRevealGesture];

    [self.scrollView.panGestureRecognizer requireGestureRecognizerToFail:self.storyTitlesEdgeRevealGesture];
    NSArray *pageControllers = @[self.currentPage, self.nextPage, self.previousPage];
    for (StoryDetailViewController *pageController in pageControllers) {
        if (pageController.webView.scrollView.panGestureRecognizer) {
            [pageController.webView.scrollView.panGestureRecognizer requireGestureRecognizerToFail:self.storyTitlesEdgeRevealGesture];
        }
    }
}

- (void)handleStoryTitlesEdgeReveal:(UIScreenEdgePanGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }

    [appDelegate.detailViewController revealStoryTitlesFromLeadingEdgeGesture:gestureRecognizer];
}

- (void)ensureCurrentPageViewIsFrontmost {
    if (!self.currentPage || !self.scrollView) {
        return;
    }

    if (self.scrollView.subviews.lastObject != self.currentPage.view) {
        [self.scrollView bringSubviewToFront:self.currentPage.view];
    }
}

- (void)refreshCurrentPageChrome {
    if (!self.currentPage) {
        return;
    }

    [self ensureCurrentPageViewIsFrontmost];
    [self.currentPage drawFeedGradient];
}

- (void)resetTraverseFadeForStoryChange {
    self.traverseFadeAccumulator = 0.0;

    BOOL hasFeedOrFolder = appDelegate.storiesCollection.activeFeed != nil || appDelegate.storiesCollection.activeFolder != nil;
    if (hasFeedOrFolder) {
        self.traverseView.alpha = 1.0;
    }
    [self updateUITestTraverseFadeProbe];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Enable edge-to-edge layout so content can appear under the nav bar when it fades
    self.edgesForExtendedLayout = UIRectEdgeAll;
    self.extendedLayoutIncludesOpaqueBars = YES;

	currentPage = [[StoryDetailViewController alloc]
                   initWithNibName:@"StoryDetailViewController"
                   bundle:nil];
	nextPage = [[StoryDetailViewController alloc]
                initWithNibName:@"StoryDetailViewController"
                bundle:nil];
    previousPage = [[StoryDetailViewController alloc]
                    initWithNibName:@"StoryDetailViewController"
                    bundle:nil];
    
    currentPage.appDelegate = appDelegate;
    nextPage.appDelegate = appDelegate;
    previousPage.appDelegate = appDelegate;
    CGRect scrollBounds = self.scrollView.bounds;
    currentPage.view.frame = scrollBounds;
    nextPage.view.frame = scrollBounds;
    previousPage.view.frame = scrollBounds;
    
//    NSLog(@"Scroll view content inset: %@", NSStringFromCGRect(self.scrollView.bounds));
//    NSLog(@"Scroll view frame pre: %@", NSStringFromCGRect(self.scrollView.frame));
	[self.scrollView addSubview:currentPage.view];
	[self.scrollView addSubview:nextPage.view];
    [self.scrollView addSubview:previousPage.view];
    [self addChildViewController:currentPage];
    [self addChildViewController:nextPage];
    [self addChildViewController:previousPage];
    [self.scrollView setPagingEnabled:YES];
	[self.scrollView setScrollEnabled:YES];
	[self.scrollView setShowsHorizontalScrollIndicator:NO];
	[self.scrollView setShowsVerticalScrollIndicator:NO];
    [self.scrollView setAlwaysBounceHorizontal:self.isHorizontal];
    [self.scrollView setAlwaysBounceVertical:!self.isHorizontal];
    [self.scrollView setDirectionalLockEnabled:YES];
    
    if (@available(iOS 17.0, *)) {
        self.scrollView.allowsKeyboardScrolling = NO;
    }
    
    // Ensure paging is edge-to-edge on iPhone (avoid safe-area inset offsets).
    self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scrollView.contentInset = UIEdgeInsetsZero;
    [self setupStoryTitlesEdgeRevealGesture];
    
//    NSLog(@"Scroll view frame post: %@", NSStringFromCGRect(self.scrollView.frame));
//    NSLog(@"Scroll view parent: %@", NSStringFromCGRect(currentPage.view.frame));
    [self.scrollView sizeToFit];
//    NSLog(@"Scroll view frame post 2: %@", NSStringFromCGRect(self.scrollView.frame));
    
    self.statusBarHeight = self.view.window.windowScene.statusBarManager.statusBarFrame.size.height;
    
    // Build the new native traverse bar, replacing old XIB-based buttons
    StoryTraverseBar *bar = [[StoryTraverseBar alloc] init];
    [bar setupIn:self.traverseView];
    self.traverseBar = bar;

    // Reassign outlets to the new bar's views
    circularProgressView = bar.circularProgressView;
    self.loadingIndicator = bar.loadingIndicator;
    buttonPrevious = bar.previousButton;
    buttonNext = bar.nextButton;
    buttonText = bar.textButton;
    buttonSend = bar.sendButton;

    // Wire up button actions
    [bar.textButton addTarget:self action:@selector(toggleTextView:) forControlEvents:UIControlEventTouchUpInside];
    [bar.sendButton addTarget:self action:@selector(openSendToDialog:) forControlEvents:UIControlEventTouchUpInside];
    [bar.previousButton addTarget:self action:@selector(doPreviousStory:) forControlEvents:UIControlEventTouchUpInside];
    [bar.nextButton addTarget:self action:@selector(doNextUnreadStory:) forControlEvents:UIControlEventTouchUpInside];

    // Progress tap gesture
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(tapProgressBar:)];
    [bar.progressTapArea addGestureRecognizer:tap];

    UIImage *settingsImage = [Utilities imageNamed:@"settings" sized:self.isMac ? 24 : 30];
    settingsImage = [settingsImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    fontSettingsButton = [UIBarButtonItem barItemWithImage:settingsImage
                                                    target:self
                                                    action:@selector(toggleFontSize:)];
    fontSettingsButton.accessibilityLabel = @"Story settings";
    
    UIImage *markreadImage = [Utilities imageNamed:@"original_button.png" sized:self.isMac ? 24 : 30];
    markreadImage = [markreadImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    originalStoryButton = [UIBarButtonItem barItemWithImage:markreadImage
                                                     target:self
                                                     action:@selector(showOriginalSubview:)];
    originalStoryButton.accessibilityLabel = @"Show original story";

    UIImage *markReadImage = [UIImage imageNamed:@"markread.png"];
    markReadImage = [markReadImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    markReadBarButton = [UIBarButtonItem barItemWithImage:markReadImage
                                                                    target:self
                                                                    action:@selector(markAllRead:)];
    markReadBarButton.accessibilityLabel = @"Mark all as read";

    UIBarButtonItem *subscribeBtn = [[UIBarButtonItem alloc]
                                     initWithTitle:@"Follow User"
                                     style:UIBarButtonItemStylePlain
                                     target:self
                                     action:@selector(subscribeToBlurblog)
                                     ];
    
    self.subscribeButton = subscribeBtn;

    [self updateTheme];
    
    self.notifier = [[NBNotifier alloc] initWithTitle:@"Fetching text..."
                                           withOffset:CGPointMake(0.0, 0.0 /*self.bottomSize.frame.size.height*/)];
    [self.view addSubview:self.notifier];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:NOTIFIER_HEIGHT]];
    self.notifier.topOffsetConstraint = [NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];
    [self.view addConstraint:self.notifier.topOffsetConstraint];
    [self.notifier hideNow];

    self.traverseBottomConstraint.constant = self.traverseBottomGap;

    [self updateStoryTitleNavigationButtons];

    // Custom toolbar for scroll-to-hide (replaces system nav bar when fullscreen)
    self.toolbarScrollHandler = [[StoryToolbarScrollHandler alloc] init];
    StoryToolbar *toolbar = [[StoryToolbar alloc] init];
    [toolbar setupIn:self.view];
    toolbar.delegate = (id<StoryToolbarDelegate>)self;
    toolbar.hidden = YES;
    self.storyToolbar = toolbar;

    // Status bar background covers the area above the safe area so the toolbar
    // slides behind an opaque surface when translating upward, and so story
    // content never shows through the status bar.
    if (!self.statusBarBackgroundView) {
        UIView *sbBg = [[UIView alloc] init];
        sbBg.translatesAutoresizingMaskIntoConstraints = NO;
        sbBg.backgroundColor = UIColorFromLightSepiaMediumDarkRGB(0xE3E6E0, 0xF3E2CB, 0x333333, 0x222222);
        [self.view addSubview:sbBg];
        [NSLayoutConstraint activateConstraints:@[
            [sbBg.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [sbBg.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [sbBg.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [sbBg.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        ]];
        self.statusBarBackgroundView = sbBg;
    }

    if (!self.uiTestStoryStateProbeView) {
        UIView *probeView = [[UIView alloc] init];
        probeView.translatesAutoresizingMaskIntoConstraints = NO;
        probeView.userInteractionEnabled = NO;
        probeView.isAccessibilityElement = YES;
        probeView.accessibilityTraits = UIAccessibilityTraitStaticText;
        probeView.accessibilityIdentifier = @"story-current-story";
        probeView.accessibilityLabel = @"No story selected";
        probeView.alpha = 0.01;
        [self.view addSubview:probeView];
        [NSLayoutConstraint activateConstraints:@[
            [probeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [probeView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [probeView.widthAnchor constraintEqualToConstant:1],
            [probeView.heightAnchor constraintEqualToConstant:1],
        ]];
        self.uiTestStoryStateProbeView = probeView;
    }
    if (!self.uiTestTraverseFadeProbeView) {
        UIView *probeView = [[UIView alloc] init];
        probeView.translatesAutoresizingMaskIntoConstraints = NO;
        probeView.userInteractionEnabled = NO;
        probeView.isAccessibilityElement = YES;
        probeView.accessibilityTraits = UIAccessibilityTraitStaticText;
        probeView.accessibilityIdentifier = @"story-traverse-fade-state";
        probeView.accessibilityLabel = @"Traverse fade state";
        probeView.alpha = 0.01;
        [self.view addSubview:probeView];
        [NSLayoutConstraint activateConstraints:@[
            [probeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [probeView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:1],
            [probeView.widthAnchor constraintEqualToConstant:1],
            [probeView.heightAnchor constraintEqualToConstant:1],
        ]];
        self.uiTestTraverseFadeProbeView = probeView;
        [self updateUITestTraverseFadeProbe];
    }
    
    [self.scrollView addObserver:self forKeyPath:@"contentOffset"
                         options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         context:nil];
    
    _orientation = self.view.window.windowScene.interfaceOrientation;
    
    [self addKeyCommandWithInput:UIKeyInputDownArrow modifierFlags:0 action:@selector(changeToNextPage:) discoverabilityTitle:@"Next Story" wantPriority:YES];
    [self addKeyCommandWithInput:@"j" modifierFlags:0 action:@selector(changeToNextPage:) discoverabilityTitle:@"Next Story"];
    [self addKeyCommandWithInput:UIKeyInputUpArrow modifierFlags:0 action:@selector(changeToPreviousPage:) discoverabilityTitle:@"Previous Story" wantPriority:YES];
    [self addKeyCommandWithInput:@"k" modifierFlags:0 action:@selector(changeToPreviousPage:) discoverabilityTitle:@"Previous Story"];
    [self addKeyCommandWithInput:@"\r" modifierFlags:UIKeyModifierShift action:@selector(toggleTextView:) discoverabilityTitle:@"Text View"];
    [self addKeyCommandWithInput:@" " modifierFlags:0 action:@selector(scrollPageDown:) discoverabilityTitle:@"Page Down"];
    [self addKeyCommandWithInput:@" " modifierFlags:UIKeyModifierShift action:@selector(scrollPageUp:) discoverabilityTitle:@"Page Up"];
    [self addKeyCommandWithInput:@"n" modifierFlags:0 action:@selector(doNextUnreadStory:) discoverabilityTitle:@"Next Unread Story"];
    [self addKeyCommandWithInput:@"u" modifierFlags:0 action:@selector(toggleStoryUnread:) discoverabilityTitle:@"Toggle Read/Unread"];
    [self addKeyCommandWithInput:@"m" modifierFlags:0 action:@selector(toggleStoryUnread:) discoverabilityTitle:@"Toggle Read/Unread"];
    [self addKeyCommandWithInput:@"s" modifierFlags:0 action:@selector(toggleStorySaved:) discoverabilityTitle:@"Save/Unsave Story"];
    [self addKeyCommandWithInput:@"o" modifierFlags:0 action:@selector(showOriginalSubview:) discoverabilityTitle:@"Open in Browser"];
    [self addKeyCommandWithInput:@"v" modifierFlags:0 action:@selector(showOriginalSubview:) discoverabilityTitle:@"Open in Browser"];
    [self addKeyCommandWithInput:@"s" modifierFlags:UIKeyModifierShift action:@selector(openShareDialog) discoverabilityTitle:@"Share This Story"];
    [self addKeyCommandWithInput:@"c" modifierFlags:0 action:@selector(scrolltoComment) discoverabilityTitle:@"Scroll to Comments"];
    [self addKeyCommandWithInput:@"t" modifierFlags:0 action:@selector(openStoryTrainerFromKeyboard:) discoverabilityTitle:@"Open Story Trainer"];
    [self addKeyCommandWithInput:@"a" modifierFlags:UIKeyModifierShift action:@selector(doMarkAllRead:) discoverabilityTitle:@"Mark All as Read"];
    [self addKeyCommandWithInput:UIKeyInputDownArrow modifierFlags:UIKeyModifierShift action:@selector(nextFolder:) discoverabilityTitle:@"Next Folder" wantPriority:YES];
    [self addKeyCommandWithInput:UIKeyInputUpArrow modifierFlags:UIKeyModifierShift action:@selector(previousFolder:) discoverabilityTitle:@"Previous Folder" wantPriority:YES];
    [self addKeyCommandWithInput:UIKeyInputDownArrow modifierFlags:UIKeyModifierAlternate action:@selector(nextSite:) discoverabilityTitle:@"Next Site" wantPriority:YES];
    [self addKeyCommandWithInput:UIKeyInputUpArrow modifierFlags:UIKeyModifierAlternate action:@selector(previousSite:) discoverabilityTitle:@"Previous Site" wantPriority:YES];
    [self addKeyCommandWithInput:UIKeyInputLeftArrow modifierFlags:0 action:@selector(hideStoryTitlesSidebar:) discoverabilityTitle:@"Hide Story Titles" wantPriority:YES];
    [self addKeyCommandWithInput:UIKeyInputRightArrow modifierFlags:0 action:@selector(showStoryTitlesSidebar:) discoverabilityTitle:@"Show Story Titles" wantPriority:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
#if TARGET_OS_MACCATALYST
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
#endif

    [self applyToolbarButtonTint];
    [self updateTheme];
    [self updateStoryTitleNavigationButtons];
    
    [self updateAutoscrollButtons];
    [self updateTraverseBackground];
    [self setNextPreviousButtons];
    [self setTextButton];
    [self updateStatusBarState];
    
    self.currentlyTogglingNavigationBar = NO;
    self.doneInitialDisplay = NO;
    self.navigationBarFadeAlpha = 1.0;
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    BOOL swipeEnabled = [[userPreferences stringForKey:@"story_detail_swipe_left_edge"]
                         isEqualToString:@"pop_to_story_list"];;
    
    UINavigationController *navController = self.navigationController ?: appDelegate.detailViewController.parentNavigationController;
    navController.interactivePopGestureRecognizer.enabled = swipeEnabled;
    navController.interactivePopGestureRecognizer.delegate = nil;
    if (swipeEnabled) {
        if (navController.interactivePopGestureRecognizer) {
            [self.scrollView.panGestureRecognizer requireGestureRecognizerToFail:navController.interactivePopGestureRecognizer];
            [self.currentPage.webView.scrollView.panGestureRecognizer requireGestureRecognizerToFail:navController.interactivePopGestureRecognizer];
        }
    }
    
    if (self.isPhoneOrCompact) {
        if (!appDelegate.storiesCollection.isSocialView) {
            UIImage *titleImage;
            if (appDelegate.storiesCollection.isSocialRiverView &&
                [appDelegate.storiesCollection.activeFolder isEqualToString:@"river_global"]) {
                titleImage = [UIImage imageNamed:@"global-shares"];
            } else if (appDelegate.storiesCollection.isSocialRiverView &&
                       [appDelegate.storiesCollection.activeFolder isEqualToString:@"river_blurblogs"]) {
                titleImage = [UIImage imageNamed:@"all-shares"];
            } else if (appDelegate.storiesCollection.isRiverView &&
                       [appDelegate.storiesCollection.activeFolder isEqualToString:@"everything"]) {
                titleImage = [UIImage imageNamed:@"all-stories"];
            } else if (appDelegate.storiesCollection.isRiverView &&
                       [appDelegate.storiesCollection.activeFolder isEqualToString:@"dashboard"]) {
                titleImage = [UIImage imageNamed:@"saved-stories"];
            } else if (appDelegate.storiesCollection.isRiverView &&
                       [appDelegate.storiesCollection.activeFolder isEqualToString:@"infrequent"]) {
                titleImage = [UIImage imageNamed:@"ak-icon-infrequent.png"];
            } else if (appDelegate.storiesCollection.isRiverView &&
                       [appDelegate.storiesCollection.activeFolder isEqualToString:@"trending:well_read"]) {
                titleImage = [UIImage imageNamed:@"trending-well-read"];
            } else if (appDelegate.storiesCollection.isRiverView &&
                       [appDelegate.storiesCollection.activeFolder isEqualToString:@"trending:long_reads"]) {
                titleImage = [UIImage imageNamed:@"trending-long-reads"];
            } else if (appDelegate.storiesCollection.isRiverView &&
                       [appDelegate.storiesCollection.activeFolder isEqualToString:@"trending:good_reads"]) {
                titleImage = [UIImage systemImageNamed:@"star.fill"];
            } else if (appDelegate.storiesCollection.isRiverView &&
                       [appDelegate.storiesCollection.activeFolder isEqualToString:@"daily_briefing"]) {
                titleImage = [UIImage imageNamed:@"briefing"];
            } else if (appDelegate.storiesCollection.isSavedView &&
                       appDelegate.storiesCollection.activeSavedStoryTag) {
                titleImage = [UIImage imageNamed:@"tag.png"];
            } else if ([appDelegate.storiesCollection.activeFolder isEqualToString:@"widget_stories"]) {
                titleImage = [UIImage imageNamed:@"g_icn_folder_widget.png"];
            } else if ([appDelegate.storiesCollection.activeFolder isEqualToString:@"read_stories"]) {
                titleImage = [UIImage imageNamed:@"indicator-unread"];
            } else if ([appDelegate.storiesCollection.activeFolder isEqualToString:@"saved_searches"]) {
                titleImage = [UIImage imageNamed:@"search"];
            } else if ([appDelegate.storiesCollection.activeFolder isEqualToString:@"saved_stories"]) {
                titleImage = [UIImage imageNamed:@"saved-stories"];
            } else if (appDelegate.storiesCollection.isRiverView) {
                // Check for custom folder icon
                NSString *folderName = appDelegate.storiesCollection.activeFolder;
                NSDictionary *customIcon = appDelegate.dictFolderIcons[folderName];
                if (customIcon && ![customIcon[@"icon_type"] isEqualToString:@"none"]) {
                    titleImage = [CustomIconRenderer renderIcon:customIcon size:CGSizeMake(22, 22)];
                }
                if (!titleImage) {
                    titleImage = [UIImage imageNamed:@"folder-open"];
                }
            } else {
                NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                                       [appDelegate.activeStory objectForKey:@"story_feed_id"]];
                // Check for custom feed icon
                NSDictionary *customIcon = appDelegate.dictFeedIcons[feedIdStr];
                if (customIcon && ![customIcon[@"icon_type"] isEqualToString:@"none"]) {
                    titleImage = [CustomIconRenderer renderIcon:customIcon size:CGSizeMake(16, 16)];
                }
                if (!titleImage) {
                    titleImage = [appDelegate getFavicon:feedIdStr];
                }
            }
            
            UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
            UIImageView *titleImageViewWrapper = [[UIImageView alloc] init];
            if (appDelegate.storiesCollection.isRiverView) {
                titleImageView.frame = CGRectMake(0.0, 2.0, 22.0, 22.0);
            } else {
                titleImageView.frame = CGRectMake(0.0, 2.0, 16.0, 16.0);
            }
            titleImageView.hidden = YES;
            titleImageView.contentMode = UIViewContentModeScaleAspectFit;
            [titleImageViewWrapper addSubview:titleImageView];
            [titleImageViewWrapper setFrame:titleImageView.frame];
            if (!appDelegate.detailViewController.navigationItem.titleView) {
                appDelegate.detailViewController.navigationItem.titleView = titleImageViewWrapper;
            }
            titleImageView.hidden = NO;
        } else {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                                   [appDelegate.storiesCollection.activeFeed objectForKey:@"id"]];
            UIImage *titleImage = nil;
            // Check for custom feed icon
            NSDictionary *customIcon = appDelegate.dictFeedIcons[feedIdStr];
            if (customIcon && ![customIcon[@"icon_type"] isEqualToString:@"none"]) {
                titleImage = [CustomIconRenderer renderIcon:customIcon size:CGSizeMake(28, 28)];
            }
            if (!titleImage) {
                titleImage = [appDelegate getFavicon:feedIdStr];
            }
            titleImage = [Utilities roundCorneredImage:titleImage radius:6];
            
            UIImageView *titleImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
            UIImageView *titleImageViewWrapper = [[UIImageView alloc] init];
            titleImageView.frame = CGRectMake(0.0, 0.0, 28.0, 28.0);
            titleImageView.contentMode = UIViewContentModeScaleAspectFit;
            [titleImageView setImage:titleImage];
            [titleImageViewWrapper addSubview:titleImageView];
            [titleImageViewWrapper setFrame:titleImageView.frame];
            appDelegate.detailViewController.navigationItem.titleView = titleImageViewWrapper;
        }
    }
    
    // Update custom toolbar title with same image used for nav bar
    [self updateStoryToolbarTitle];

    // On iPhone, always use the custom toolbar instead of the system nav bar.
    // Wrap in performWithoutAnimation to prevent the toolbar from animating in
    // from (0,0) during the navigation controller push transition.
    if (self.useCustomToolbar) {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
        [UIView performWithoutAnimation:^{
            self.storyToolbar.hidden = NO;
            self.storyToolbar.transform = CGAffineTransformIdentity;
            [self.toolbarScrollHandler reset];
            // Ensure toolbar and status bar bg are above the scroll view
            [self.view bringSubviewToFront:self.storyToolbar];
            [self.view bringSubviewToFront:self.statusBarBackgroundView];
            [self.view layoutIfNeeded];
        }];
        [self updateStatusBarState];
        // Force content insets on all pages so content starts below the toolbar
        [self.currentPage updateContentInsetForNavigationBarAlpha:1.0 maintainVisualPosition:NO force:YES];
        [self.nextPage updateContentInsetForNavigationBarAlpha:1.0 maintainVisualPosition:NO force:YES];
        [self.previousPage updateContentInsetForNavigationBarAlpha:1.0 maintainVisualPosition:NO force:YES];
    } else {
        [self.navigationController setNavigationBarHidden:NO animated:animated];
        self.storyToolbar.hidden = YES;
    }

    self.autoscrollView.alpha = 0;
    previousPage.view.hidden = YES;
    // Only show traverse controls when there's an active feed or folder
    BOOL hasFeedOrFolder = appDelegate.storiesCollection.activeFeed != nil || appDelegate.storiesCollection.activeFolder != nil;
    self.traverseView.alpha = hasFeedOrFolder ? 1 : 0;
    [self updateUITestTraverseFadeProbe];
    self.isAnimatedIntoPlace = NO;
    currentPage.view.hidden = NO;

    self.navigationController.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithTitle:@" "
                                             style:UIBarButtonItemStylePlain
                                             target:nil action:nil];

    UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
    [self layoutForInterfaceOrientation:orientation];
    [self reorientPages];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // set the subscribeButton flag
    if (appDelegate.isTryFeedView && !self.isPhoneOrCompact &&
        ![[appDelegate.storiesCollection.activeFeed objectForKey:@"username"] isKindOfClass:[NSNull class]] &&
        [appDelegate.storiesCollection.activeFeed objectForKey:@"username"]) {
        self.subscribeButton.title = [NSString stringWithFormat:@"Follow %@",
                                      [appDelegate.storiesCollection.activeFeed objectForKey:@"username"]];
        appDelegate.detailViewController.navigationItem.leftBarButtonItem = self.subscribeButton;
    }
    appDelegate.isTryFeedView = NO;
    [self reorientPages];
    previousPage.view.hidden = NO;
    [self alignScrollViewToCurrentPageIfNeeded];
    // Correct viewport width on all pages now that the view is at its final size.
    [appDelegate adjustStoryDetailWebView];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.doneInitialDisplay = YES;
    });

    if (self.isPhoneOrCompact) {
        [self configureFullScreenPopGesture];
    }

    [self becomeFirstResponder];
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self alignScrollViewToCurrentPageIfNeeded];
}

- (void)viewDidLayoutSubviews {
    if (self.storySelectionRedrawCover) {
        self.storySelectionRedrawCover.frame = [self.scrollView.superview convertRect:self.scrollView.bounds fromView:self.scrollView];
        self.storySelectionRedrawCover.subviews.firstObject.frame = self.storySelectionRedrawCover.bounds;
    }
    if (self.storySelectionTransitionHost &&
        !CGSizeEqualToSize(self.storySelectionTransitionHost.bounds.size, self.scrollView.bounds.size)) {
        [self finishStorySelectionAnimation];
    }
    CGRect frame = self.scrollView.frame;
    
    if (frame.size.width != floor(frame.size.width)) {
        self.scrollView.frame = CGRectMake(frame.origin.x, frame.origin.y, floor(frame.size.width), floor(frame.size.height));
    }

    if (!CGSizeEqualToSize(self.lastScrollViewBoundsSize, self.scrollView.bounds.size)) {
        self.lastScrollViewBoundsSize = self.scrollView.bounds.size;
        [self reorientPages];
        // Update viewport width on all pages to match the new layout size.
        // Deferred so web view subviews complete their layout pass first.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->appDelegate adjustStoryDetailWebView];
        });
    }
    
    [self ensureCurrentPageViewIsFrontmost];

    [self alignScrollViewToCurrentPageIfNeeded];
    
    [super viewDidLayoutSubviews];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (!appDelegate.detailViewController.storyTitlesInGridView) {
        appDelegate.detailViewController.navigationItem.leftBarButtonItem = nil;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.storySelectionTransitionHost || self.storySelectionRedrawCover) [self cancelPendingStoryPresentationForNavigation];

    [[ReadTimeTracker shared] harvestAndFlush];

    previousPage.view.hidden = YES;
    UINavigationController *navController = self.navigationController ?: appDelegate.detailViewController.parentNavigationController;
    navController.interactivePopGestureRecognizer.enabled = YES;
    navController.interactivePopGestureRecognizer.delegate = appDelegate.feedDetailViewController.standardInteractivePopGestureDelegate;

#if !TARGET_OS_MACCATALYST
    [navController setNavigationBarHidden:NO animated:YES];
#endif
    navController.navigationBar.alpha = 1.0;
    navController.navigationBar.userInteractionEnabled = YES;

    self.autoscrollActive = NO;

    // During interactive pop, keep custom toolbar visible until transition completes.
    // If cancelled, re-hide the system nav bar and keep our toolbar.
    if (self.useCustomToolbar && self.transitionCoordinator.isInteractive) {
        [self.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if (context.isCancelled) {
                // Gesture cancelled — restore custom toolbar state
                [navController setNavigationBarHidden:YES animated:NO];
            } else {
                // Transition completed — clean up custom toolbar
                self.storyToolbar.hidden = YES;
                self.storyToolbar.transform = CGAffineTransformIdentity;
                [self.toolbarScrollHandler reset];
            }
        }];
    } else {
        // Non-interactive (back button, programmatic pop) — hide immediately
        self.storyToolbar.hidden = YES;
        self.storyToolbar.transform = CGAffineTransformIdentity;
        [self.toolbarScrollHandler reset];
    }
}

- (BOOL)becomeFirstResponder {
    // delegate to current page
    return [currentPage becomeFirstResponder];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    inRotation = YES;
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
//        NSLog(@"---> Story page control is re-orienting: %@ / %@", NSStringFromCGSize(self.scrollView.bounds.size), NSStringFromCGSize(size));
        UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
        self->_orientation = orientation;
        [self layoutForInterfaceOrientation:orientation];
        [self reorientPages];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
//        NSLog(@"---> Story page control did re-orient: %@ / %@", NSStringFromCGSize(self.scrollView.bounds.size), NSStringFromCGSize(size));
        self->inRotation = NO;
        
        [self updateStatusBarState];

        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }];
}

- (void)layoutForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//    NSLog(@"layout for stories: %@", NSStringFromCGRect(self.view.frame));
    if (interfaceOrientation != _orientation) {
        _orientation = interfaceOrientation;
        if (currentPage.pageIndex == 0) {
            previousPage.view.hidden = YES;
        }
    }
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    // Scroll view is edge-to-edge; content inset handles nav bar spacing
    self.scrollViewTopConstraint.constant = 0;

    UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
    [self layoutForInterfaceOrientation:orientation];
}

- (BOOL)shouldHideStatusBar {
    // Disabled for now, as not working currently.
    return NO;
    
//    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
//
//    return [preferences boolForKey:@"story_hide_status_bar"];
}

- (BOOL)isNavigationBarHidden {
    if (self.isCustomToolbarActive) {
        return self.toolbarScrollHandler.toolbarOffset >= self.toolbarScrollHandler.toolbarHeight - 1;
    }
    return self.isNavigationBarFaded;
}

- (void)updateStatusBarState {
    // On iPhone the status bar background must always be visible so the toolbar
    // slides behind an opaque surface. Use useCustomToolbar (not isCustomToolbarActive)
    // because the toolbar may still be hidden during early viewWillAppear setup.
    if (self.useCustomToolbar) {
        [self.statusBarBackgroundView.layer removeAllAnimations];
        self.statusBarBackgroundView.hidden = NO;
        self.statusBarBackgroundView.alpha = 1.0;
        return;
    }

    BOOL shouldShow = !self.shouldHideStatusBar && self.isNavigationBarHidden && appDelegate.isPortrait;
    CGFloat targetAlpha = shouldShow ? 1.0 : 0.0;
    if (shouldShow) {
        self.statusBarBackgroundView.hidden = NO;
    }
    [UIView animateWithDuration:0.15 animations:^{
        self.statusBarBackgroundView.alpha = targetAlpha;
    } completion:^(BOOL finished) {
        if (finished && !shouldShow) {
            self.statusBarBackgroundView.hidden = YES;
        }
    }];
}

- (BOOL)prefersStatusBarHidden {
    [self updateStatusBarState];
    
    return self.shouldHideStatusBar && self.isNavigationBarHidden;
}

- (BOOL)allowFullscreen {
    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPhone || self.presentedViewController != nil) {
        return NO;
    }

    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    BOOL storyFullScreen = [preferences boolForKey:@"story_full_screen"];
    BOOL result = (storyFullScreen || self.autoscrollAvailable) && !self.forceNavigationBarShown;
    return result;
}

- (BOOL)useCustomToolbar {
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone;
}

- (void)setNavigationBarHidden:(BOOL)hide {
    [self setNavigationBarHidden:hide alsoTraverse:NO];
}

- (void)setNavigationBarHidden:(BOOL)hide alsoTraverse:(BOOL)alsoTraverse {
//    #warning temporarily disabled hiding menubar
//    return;
    
    if (appDelegate.isMac || self.navigationController == nil || self.isNavigationBarFaded == hide || self.currentlyTogglingNavigationBar || !self.doneInitialDisplay) {
        return;
    }
    
    self.currentlyTogglingNavigationBar = YES;
    self.wasNavigationBarHidden = hide;
    self.isNavigationBarFaded = hide;
    self.navBarFadeAccumulator = hide ? 80.0 : 0.0;

    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    BOOL swipeEnabled = [[userPreferences stringForKey:@"story_detail_swipe_left_edge"]
                         isEqualToString:@"pop_to_story_list"];;
    UINavigationController *navController = self.navigationController ?: appDelegate.detailViewController.parentNavigationController;
    navController.interactivePopGestureRecognizer.enabled = swipeEnabled;
    navController.interactivePopGestureRecognizer.delegate = nil;
    
    self.navigationController.navigationBar.userInteractionEnabled = !hide;
    
    if (alsoTraverse) {
        self.traversePinned = YES;
        self.traverseFloating = NO;
        
        if (!hide) {
            self.traverseBottomConstraint.constant = self.traverseBottomGap;
            [self.view layoutIfNeeded];
        }
    }

    [self.appDelegate.detailViewController adjustForAutoscroll];
    [self refreshCurrentPageChrome];
    
    if (alsoTraverse) {
        [self.view layoutIfNeeded];
        // Only show traverse controls when there's an active feed or folder
        BOOL hasFeedOrFolder = appDelegate.storiesCollection.activeFeed != nil || appDelegate.storiesCollection.activeFolder != nil;
        self.traverseView.alpha = (hide || !hasFeedOrFolder) ? 0 : 1;
        [self updateUITestTraverseFadeProbe];

        if (hide) {
            [self hideAutoscrollImmediately];
        }
    }
    
    if (!self.isHorizontal) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            [self reorientPages];
        });
    }
    
    if (self.isCustomToolbarActive) {
        CGFloat targetOffset = hide ? self.toolbarScrollHandler.toolbarHeight : 0;
        [UIView animateWithDuration:0.2 animations:^{
            [self setToolbarOffset:targetOffset];
        } completion:^(BOOL finished) {
            self.currentlyTogglingNavigationBar = NO;
            [self updateStatusBarState];
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            [self setNavigationBarFadeAlpha:(hide ? 0.0 : 1.0)];
        } completion:^(BOOL finished) {
            self.currentlyTogglingNavigationBar = NO;
            [self updateStatusBarState];
        }];
    }
}

- (void)setNavigationBarFadeAlpha:(CGFloat)alpha {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setNavigationBarFadeAlpha:alpha];
        });
        return;
    }

    CGFloat clampedAlpha = MAX(0.0, MIN(1.0, alpha));
    if (self.isUpdatingNavigationBarFade) {
        return;
    }

    self.isUpdatingNavigationBarFade = YES;

    UIView *loadedView = self.viewIfLoaded;
    if (!loadedView || loadedView.window == nil) {
        self.navigationBarFadeAlpha = clampedAlpha;
        self.isUpdatingNavigationBarFade = NO;
        return;
    }

    UINavigationController *navController = self.navigationController;
    if (!navController) {
        self.navigationBarFadeAlpha = clampedAlpha;
        self.isUpdatingNavigationBarFade = NO;
        return;
    }

    if (fabs(self.navigationBarFadeAlpha - clampedAlpha) < 0.001 &&
        self.isNavigationBarFaded == (clampedAlpha < 0.05)) {
        self.isUpdatingNavigationBarFade = NO;
        return;
    }
    self.navigationBarFadeAlpha = clampedAlpha;
    navController.navigationBar.alpha = clampedAlpha;
    navController.navigationBar.userInteractionEnabled = clampedAlpha > 0.05;

    // Update content inset on all pages' web views so swiping between them is seamless
    // Current page: force update when transitioning from hidden to shown so content isn't clipped
    BOOL wasFaded = self.isNavigationBarFaded;
    [self.currentPage updateContentInsetForNavigationBarAlpha:clampedAlpha
                                       maintainVisualPosition:YES
                                                        force:NO];
    // Adjacent pages: always maintain visual position to keep them at correct scroll position
    [self.previousPage updateContentInsetForNavigationBarAlpha:clampedAlpha maintainVisualPosition:YES];
    [self.nextPage updateContentInsetForNavigationBarAlpha:clampedAlpha maintainVisualPosition:YES];

    if (self.isNavigationBarFaded) {
        self.isNavigationBarFaded = clampedAlpha < 0.10;  // must rise above 0.10 to unfade
    } else {
        self.isNavigationBarFaded = clampedAlpha < 0.03;  // must drop below 0.03 to fade
    }

    if (wasFaded != self.isNavigationBarFaded) {
        [self.currentPage updateFeedTitleGradientPosition];
        [self updateStatusBarState];
    }

    self.isUpdatingNavigationBarFade = NO;
}

#pragma mark - Custom Toolbar (Scroll-to-hide)

- (BOOL)isCustomToolbarActive {
    return !self.storyToolbar.hidden;
}

- (void)setToolbarOffset:(CGFloat)offset {
    CGFloat clamped = MAX(0, MIN(self.toolbarScrollHandler.toolbarHeight, offset));
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0, -clamped);
    BOOL toolbarChanged = !CGAffineTransformEqualToTransform(self.storyToolbar.transform, transform);
    // StoryPagesObjCViewController.m is called after the scroll handler has already advanced its offset.
    if (self.toolbarScrollHandler.toolbarOffset != clamped) {
        [self.toolbarScrollHandler setOffset:clamped];
    }
    if (toolbarChanged) {
        self.storyToolbar.transform = transform;
        [self updateStatusBarState];
        // StoryDetailObjCViewController.m already updates this gradient for content scrolling.
        [self.currentPage updateFeedTitleGradientPosition];
    }

    // Keep adjacent pages in sync so there's no jump when swiping to them.
    // Only adjust pages that are at the top (not user-scrolled).
    StoryDetailViewController *adjacentPages[] = {self.nextPage, self.previousPage};
    for (NSUInteger index = 0; index < 2; index++) {
        StoryDetailViewController *page = adjacentPages[index];
        if (!page || page == self.currentPage) continue;
        UIScrollView *sv = page.webView.scrollView;
        CGFloat topRest = -sv.contentInset.top;
        CGFloat maxAdjustedTop = topRest + self.toolbarScrollHandler.toolbarHeight;
        CGFloat targetOffset = topRest + clamped;
        // Page is "at top" if within the toolbar adjustment range (topRest to topRest+toolbarHeight)
        if (sv.contentOffset.y <= maxAdjustedTop + 1) {
            // StoryPagesObjCViewController.m must still synchronize newly loaded pages when the toolbar is unchanged.
            BOOL pageOffsetChanged = sv.contentOffset.y != targetOffset;
            if (pageOffsetChanged) {
                sv.contentOffset = CGPointMake(sv.contentOffset.x, targetOffset);
            }
            if (pageOffsetChanged || toolbarChanged) {
                [page updateFeedTitleGradientPosition];
            }
        }
    }
}

- (void)updateStoryToolbarTitle {
    UIImage *titleImage = nil;
    NSString *titleText = nil;

    if (!appDelegate.storiesCollection.isSocialView) {
        if (appDelegate.storiesCollection.isSocialRiverView &&
            [appDelegate.storiesCollection.activeFolder isEqualToString:@"river_global"]) {
            titleImage = [UIImage imageNamed:@"global-shares"];
            titleText = @"Global Shared Stories";
        } else if (appDelegate.storiesCollection.isSocialRiverView &&
                   [appDelegate.storiesCollection.activeFolder isEqualToString:@"river_blurblogs"]) {
            titleImage = [UIImage imageNamed:@"all-shares"];
            titleText = @"All Shared Stories";
        } else if (appDelegate.storiesCollection.isRiverView &&
                   [appDelegate.storiesCollection.activeFolder isEqualToString:@"everything"]) {
            titleImage = [UIImage imageNamed:@"all-stories"];
            titleText = @"All Site Stories";
        } else if (appDelegate.storiesCollection.isRiverView &&
                   [appDelegate.storiesCollection.activeFolder isEqualToString:@"dashboard"]) {
            titleImage = [UIImage imageNamed:@"saved-stories"];
            titleText = @"Dashboard";
        } else if (appDelegate.storiesCollection.isRiverView &&
                   [appDelegate.storiesCollection.activeFolder isEqualToString:@"infrequent"]) {
            titleImage = [UIImage imageNamed:@"ak-icon-infrequent.png"];
            titleText = @"Infrequent Stories";
        } else if (appDelegate.storiesCollection.isRiverView &&
                   [appDelegate.storiesCollection.activeFolder isEqualToString:@"trending:well_read"]) {
            titleImage = [UIImage imageNamed:@"trending-well-read"];
            titleText = @"Widely Read Stories";
        } else if (appDelegate.storiesCollection.isRiverView &&
                   [appDelegate.storiesCollection.activeFolder isEqualToString:@"trending:long_reads"]) {
            titleImage = [UIImage imageNamed:@"trending-long-reads"];
            titleText = @"Long Reads";
        } else if (appDelegate.storiesCollection.isRiverView &&
                   [appDelegate.storiesCollection.activeFolder isEqualToString:@"trending:good_reads"]) {
            titleImage = [UIImage systemImageNamed:@"star.fill"];
            titleText = @"Good Reads";
        } else if (appDelegate.storiesCollection.isRiverView &&
                   [appDelegate.storiesCollection.activeFolder isEqualToString:@"daily_briefing"]) {
            titleImage = [UIImage imageNamed:@"briefing"];
            titleText = @"Daily Briefing";
        } else if (appDelegate.storiesCollection.isSavedView &&
                   appDelegate.storiesCollection.activeSavedStoryTag) {
            titleImage = [UIImage imageNamed:@"tag.png"];
            titleText = appDelegate.storiesCollection.activeSavedStoryTag;
        } else if ([appDelegate.storiesCollection.activeFolder isEqualToString:@"widget_stories"]) {
            titleImage = [UIImage imageNamed:@"g_icn_folder_widget.png"];
            titleText = @"Widget Stories";
        } else if ([appDelegate.storiesCollection.activeFolder isEqualToString:@"read_stories"]) {
            titleImage = [UIImage imageNamed:@"indicator-unread"];
            titleText = @"Read Stories";
        } else if ([appDelegate.storiesCollection.activeFolder isEqualToString:@"saved_searches"]) {
            titleImage = [UIImage imageNamed:@"search"];
            titleText = @"Saved Searches";
        } else if ([appDelegate.storiesCollection.activeFolder isEqualToString:@"saved_stories"]) {
            titleImage = [UIImage imageNamed:@"saved-stories"];
            titleText = @"Saved Stories";
        } else if (appDelegate.storiesCollection.isRiverView) {
            NSString *folderName = appDelegate.storiesCollection.activeFolder;
            NSDictionary *customIcon = appDelegate.dictFolderIcons[folderName];
            if (customIcon && ![customIcon[@"icon_type"] isEqualToString:@"none"]) {
                titleImage = [CustomIconRenderer renderIcon:customIcon size:CGSizeMake(22, 22)];
            }
            if (!titleImage) {
                titleImage = [UIImage imageNamed:@"folder-open"];
            }
            titleText = folderName;
        } else {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                                   [appDelegate.activeStory objectForKey:@"story_feed_id"]];
            NSDictionary *feed = [appDelegate getFeed:feedIdStr];
            NSDictionary *customIcon = appDelegate.dictFeedIcons[feedIdStr];
            if (customIcon && ![customIcon[@"icon_type"] isEqualToString:@"none"]) {
                titleImage = [CustomIconRenderer renderIcon:customIcon size:CGSizeMake(16, 16)];
            }
            if (!titleImage) {
                titleImage = [appDelegate getFavicon:feedIdStr];
            }
            titleText = [feed objectForKey:@"feed_title"];
        }
    } else {
        NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                               [appDelegate.storiesCollection.activeFeed objectForKey:@"id"]];
        NSDictionary *customIcon = appDelegate.dictFeedIcons[feedIdStr];
        if (customIcon && ![customIcon[@"icon_type"] isEqualToString:@"none"]) {
            titleImage = [CustomIconRenderer renderIcon:customIcon size:CGSizeMake(22, 22)];
        }
        if (!titleImage) {
            titleImage = [appDelegate getFavicon:feedIdStr];
            titleImage = [Utilities roundCorneredImage:titleImage radius:6];
        }
        titleText = [appDelegate.storiesCollection.activeFeed objectForKey:@"feed_title"];
    }

    [self.storyToolbar updateTitleWithImage:titleImage text:titleText];
}

#pragma mark - StoryToolbarDelegate

- (void)toolbarDidTapBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)toolbarDidTapSettings {
    [self toggleFontSize:self.storyToolbar.settingsButton];
}

- (void)toolbarDidTapBrowser {
    [self showOriginalSubview:self.storyToolbar.browserButton];
}

- (CGFloat)topInsetForNavigationBarAlpha:(CGFloat)alpha {
    if (!appDelegate.isCompactWidth && [[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPhone) {
        return 0;
    }

    // StoryPagesObjCViewController.m still uses the presenting window after WebKit leaves its host and before the page attaches.
    UIWindow *window = self.view.window ?: self.pendingPresentationPage.webView.window ?:
        appDelegate.feedsNavigationController.viewIfLoaded.window ?: appDelegate.detailViewController.view.window;

    // StoryPagesObjCViewController.m must respect a real window's zero inset in
    // landscape instead of replacing it with stale portrait or status bar geometry.
    CGFloat safeAreaTop;
    if (window) {
        safeAreaTop = window.safeAreaInsets.top;
    } else {
        safeAreaTop = self.view.safeAreaInsets.top;
        if (safeAreaTop <= 0) {
            safeAreaTop = 59;  // Fallback before any presentation window is available.
        }
    }

    // When custom toolbar is used (always on iPhone), content inset is always fixed at
    // safeAreaTop + toolbarHeight. This keeps insets stable during scroll (no jitter).
    // When toolbar is hidden and a new story loads, the initial scroll position is
    // adjusted instead (see setStoryFromScroll:).
    if (self.useCustomToolbar) {
        return safeAreaTop + self.toolbarScrollHandler.toolbarHeight;
    }

    UINavigationController *navController = self.navigationController;
    if (!navController) {
        return 0;
    }

    CGFloat navBarHeight = navController.navigationBar.frame.size.height;

    // When nav bar is fully visible (alpha=1), include full nav bar height
    // When nav bar is faded out (alpha=0), just include safe area top
    CGFloat navOffset = navBarHeight > 0.0 ? navBarHeight * alpha : 0.0;
    return safeAreaTop + navOffset;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.fullScreenPopGesture) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint velocity = [pan velocityInView:self.view];
        if (velocity.x <= 0 || fabs(velocity.x) <= fabs(velocity.y)) {
            return NO;
        }
        UINavigationController *navController = self.navigationController ?: appDelegate.feedsNavigationController;
        return navController.viewControllers.count > 1;
    }

    UINavigationController *navController = self.navigationController ?: appDelegate.detailViewController.parentNavigationController;
    if (gestureRecognizer == self.storyTitlesEdgeRevealGesture) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint velocity = [pan velocityInView:self.view];
        BOOL usesOverlay = appDelegate.splitViewController.splitBehavior == UISplitViewControllerSplitBehaviorOverlay;
        if (velocity.x <= 0 || fabs(velocity.x) <= fabs(velocity.y)) {
            return NO;
        }

        return [StorySidebarRevealGestureDecision shouldBeginLeadingEdgeStoryTitlesRevealWithUsesOverlay:usesOverlay
                                                                                             presentation:appDelegate.detailViewController.fullscreenSidebarPresentation
                                                                                         storyTitlesOnLeft:appDelegate.detailViewController.storyTitlesOnLeft
                                                                                         isPhoneOrCompact:self.isPhoneOrCompact];
    }

    if (gestureRecognizer == navController.interactivePopGestureRecognizer) {
        return navController.viewControllers.count > 1;
    }

    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.fullScreenPopGesture) {
        return NO;
    }

    UINavigationController *navController = self.navigationController ?: appDelegate.detailViewController.parentNavigationController;
    if (gestureRecognizer == navController.interactivePopGestureRecognizer) {
        return YES;
    }

    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    UINavigationController *navController = self.navigationController ?: appDelegate.detailViewController.parentNavigationController;
    if (gestureRecognizer == navController.interactivePopGestureRecognizer) {
        if (otherGestureRecognizer == self.scrollView.panGestureRecognizer ||
            otherGestureRecognizer == self.currentPage.webView.scrollView.panGestureRecognizer) {
            return YES;
        }
    }
    
    return NO;
}

- (void)highlightButton:(UIButton *)b {
    if (![b isKindOfClass:[UIButton class]]) return;
    [b setHighlighted:YES];
}
- (void)unhighlightButton:(UIButton *)b {
    if (![b isKindOfClass:[UIButton class]]) return;
    [b setHighlighted:NO];
}

- (IBAction)beginTouchDown:(UIButton *)sender {
    [self performSelector:@selector(highlightButton:) withObject:sender afterDelay:0.0];
}

- (IBAction)endTouchDown:(UIButton *)sender {
    if (!sender) return;
    
    [self performSelector:@selector(unhighlightButton:) withObject:sender afterDelay:0.2];
}

- (BOOL)isPortraitOrientation {
    return UIInterfaceOrientationIsPortrait(self.view.window.windowScene.interfaceOrientation);
}

- (BOOL)isHorizontal {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"scroll_stories_horizontally"] boolValue];
}

- (void)resetPages {
    [self cancelPendingStoryPresentation];
    appDelegate.detailViewController.navigationItem.titleView = nil;

    currentPage.activeStory = nil;
    nextPage.activeStory = nil;
    previousPage.activeStory = nil;

    [currentPage clearStory];
    [nextPage clearStory];
    [previousPage clearStory];
    
    [currentPage hideStory];

    CGRect bounds = self.scrollView.bounds;
    self.scrollView.contentSize = bounds.size;
    
//    NSLog(@"Pages are at: %f / %f / %f (%@)", previousPage.view.frame.origin.x, currentPage.view.frame.origin.x, nextPage.view.frame.origin.x, NSStringFromCGRect(frame));
    CGRect scrollBounds = self.scrollView.bounds;
    currentPage.view.frame = scrollBounds;
    nextPage.view.frame = scrollBounds;
    previousPage.view.frame = scrollBounds;

    currentPage.pageIndex = -2;
    nextPage.pageIndex = -2;
    previousPage.pageIndex = -2;
}

- (void)hidePages {
    [self cancelPendingStoryPresentation];
    [currentPage hideStory];
    [nextPage hideStory];
    [previousPage hideStory];
}

- (void)refreshPages {
    if (self.pendingPresentationPage) {
        self.refreshAfterStorySelection = YES;
        return;
    }
    if (![StoryPageRefreshDecision shouldBeginRefreshWithIsRefreshInProgress:self.isRefreshingPages]) {
        return;
    }

    self.isRefreshingPages = YES;
    @try {
        NSInteger pageIndex = currentPage.pageIndex;
        [self resizeScrollView];
        [appDelegate adjustStoryDetailWebView];
        if ([appDelegate.feedDetailViewController hasRetainedFirstPageStory]) {
            [self reorientPages];
            return;
        }
        currentPage.pageIndex = -2;
        nextPage.pageIndex = -2;
        previousPage.pageIndex = -2;
        [self changePage:pageIndex animated:NO];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [self.notifier hide];
        //    self.scrollView.contentOffset = CGPointMake(self.scrollView.frame.size.width * currentPage.pageIndex, 0);
    } @finally {
        self.isRefreshingPages = NO;
    }
}

- (void)preserveCurrentPageAtLocation:(NSInteger)location {
    if (location < 0 || location >= appDelegate.storiesCollection.storyLocationsCount || !self.currentPage) return;
    if (self.currentPage.pageIndex == location) return;
    self.isRepositioningFirstPage = YES;
    // StoryPagesObjCViewController.m moves the existing rendered page without invoking its story-loading path.
    self.currentPage.pageIndex = location;
    [self resizeScrollView];
    [self applyNewIndex:location pageController:self.currentPage supressRedraw:YES];
    CGRect bounds = self.scrollView.bounds;
    CGFloat axisInset = [self axisInsetForScrollView:self.scrollView];
    CGPoint offset = self.scrollView.contentOffset;
    if (self.isHorizontal) offset.x = [self pageOffsetForIndex:location pageAmount:bounds.size.width axisInset:axisInset];
    else offset.y = [self pageOffsetForIndex:location pageAmount:bounds.size.height axisInset:axisInset];
    [self.scrollView setContentOffset:offset animated:NO];
    if (self.previousPage) [self applyNewIndex:location - 1 pageController:self.previousPage];
    if (self.nextPage) [self applyNewIndex:location + 1 pageController:self.nextPage];
    self.isRepositioningFirstPage = NO;
}

- (void)reorientPages {
    NSInteger currentIndex = currentPage.pageIndex;
    [self resizeScrollView]; // Will change currentIndex, so preserve
    
    [self applyNewIndex:currentPage.pageIndex-1 pageController:previousPage supressRedraw:YES];
    [self applyNewIndex:currentPage.pageIndex+1 pageController:nextPage supressRedraw:YES];
    [self applyNewIndex:currentPage.pageIndex pageController:currentPage supressRedraw:YES];
    
    // Scroll back to preserved index
    CGRect frame = self.scrollView.bounds;
    CGFloat axisInset = [self axisInsetForScrollView:self.scrollView];
    
    if (self.isHorizontal) {
        frame.origin.x = [self pageOffsetForIndex:currentIndex
                                       pageAmount:frame.size.width
                                        axisInset:axisInset];
        frame.origin.y = 0;
    } else {
        frame.origin.x = 0;
        frame.origin.y = [self pageOffsetForIndex:currentIndex
                                       pageAmount:frame.size.height
                                        axisInset:axisInset];
    }
    
    [self.scrollView scrollRectToVisible:frame animated:NO];
//    NSLog(@"---> Scrolling to story at: %@ %d-%d", NSStringFromCGRect(frame), currentPage.pageIndex, currentIndex);
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [self hideNotifier];
    
    if (!self.isPhoneOrCompact) {
        [currentPage realignScroll];
    }
}

- (void)refreshHeaders {
    [currentPage setActiveStoryAtIndex:[appDelegate.storiesCollection
                                        indexOfStoryId:currentPage.activeStoryId]];
    [nextPage setActiveStoryAtIndex:[appDelegate.storiesCollection
                                     indexOfStoryId:nextPage.activeStoryId]];
    [previousPage setActiveStoryAtIndex:[appDelegate.storiesCollection
                                         indexOfStoryId:previousPage.activeStoryId]];

    [currentPage refreshHeader];
    [nextPage refreshHeader];
    [previousPage refreshHeader];

    [currentPage refreshSideOptions];
    [nextPage refreshSideOptions];
    [previousPage refreshSideOptions];
}

- (void)resizeScrollView {
    NSInteger storyCount = appDelegate.storiesCollection.storyLocationsCount;
    if ([appDelegate.feedDetailViewController hasRetainedFirstPageStory]) storyCount = MAX(storyCount, currentPage.pageIndex + 2);
	if (storyCount == 0) {
		storyCount = 1;
	}
    
    if (self.isHorizontal) {
        self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width
                                                 * storyCount,
                                                 self.scrollView.bounds.size.height);
    } else {
        self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width,
                                                 self.scrollView.bounds.size.height
                                                 * storyCount);
    }
}

- (BOOL)isPhoneOrCompact {
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone || appDelegate.isCompactWidth;
}

- (void)updateAutoscrollButtons {
    self.autoscrollBackgroundImageView.image = [[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"traverse_background.png"]];
    
    [self.autoscrollDisableButton setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"autoscroll_off.png"]]  forState:UIControlStateNormal];
    
    if (self.autoscrollActive) {
        [self.autoscrollPauseResumeButton setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"autoscroll_pause.png"]]  forState:UIControlStateNormal];
    } else {
        [self.autoscrollPauseResumeButton setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"autoscroll_resume.png"]]  forState:UIControlStateNormal];
    }
    
    [self.autoscrollSlowerButton setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"autoscroll_slower.png"]]  forState:UIControlStateNormal];
    [self.autoscrollFasterButton setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"autoscroll_faster.png"]]  forState:UIControlStateNormal];
}

- (void)updateTraverseBackground {
    [self.traverseBar updateTheme];
    self.bottomSize.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
}

- (void)updateTheme {
    [super updateTheme];

    [self applyToolbarButtonTint];
    
    UIColor *toolbarButtonTint = UIColorFromLightSepiaMediumDarkRGB(0x8F918B, 0x8B7B6B, 0xAEAFAF, 0xAEAFAF);
    self.navigationController.navigationBar.tintColor = toolbarButtonTint;
    self.navigationController.navigationBar.barTintColor = [UINavigationBar appearance].barTintColor;
    self.navigationController.navigationBar.backgroundColor = [UINavigationBar appearance].backgroundColor;
    self.navigationController.navigationBar.barStyle = ThemeManager.shared.isDarkTheme ? UIBarStyleBlack : UIBarStyleDefault;
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = self.navigationController.navigationBar.standardAppearance;
        if (!appearance) {
            appearance = [[UINavigationBarAppearance alloc] init];
        }
        appearance.backgroundColor = self.navigationController.navigationBar.barTintColor;

        UIBarButtonItemAppearance *buttonAppearance = [[UIBarButtonItemAppearance alloc] init];
        NSDictionary *textAttributes = @{NSForegroundColorAttributeName: toolbarButtonTint};
        [buttonAppearance.normal setTitleTextAttributes:textAttributes];
        [buttonAppearance.highlighted setTitleTextAttributes:textAttributes];
        [buttonAppearance.disabled setTitleTextAttributes:textAttributes];
        appearance.buttonAppearance = buttonAppearance;
        appearance.backButtonAppearance = buttonAppearance;
        appearance.doneButtonAppearance = buttonAppearance;
        appearance.titleTextAttributes = [UINavigationBar appearance].titleTextAttributes;
        
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.compactAppearance = appearance;
    }
    self.view.backgroundColor = UIColorFromLightDarkRGB(0xe0e0e0, 0x111111);
    
    [self updateAutoscrollButtons];
    [self updateTraverseBackground];
    [self setNextPreviousButtons];
    [self setTextButton];
    [self updateStoriesTheme];
    [self updateStatusBarTheme];
    [self.storyToolbar updateTheme];
    self.statusBarBackgroundView.backgroundColor = UIColorFromLightSepiaMediumDarkRGB(0xE3E6E0, 0xF3E2CB, 0x333333, 0x222222);
}

- (void)applyToolbarButtonTint {
    UIColor *toolbarButtonTint = UIColorFromLightSepiaMediumDarkRGB(0x8F918B, 0x8B7B6B, 0xAEAFAF, 0xAEAFAF);

    fontSettingsButton.tintColor = toolbarButtonTint;
    originalStoryButton.tintColor = toolbarButtonTint;
    markReadBarButton.tintColor = toolbarButtonTint;
    self.temporaryFullScreenButton.tintColor = toolbarButtonTint;
    self.subscribeButton.tintColor = toolbarButtonTint;
    UIButton *settingsButton = (UIButton *)fontSettingsButton.customView;
    if ([settingsButton isKindOfClass:[UIButton class]]) {
        settingsButton.tintColor = toolbarButtonTint;
    }
    UIButton *originalButton = (UIButton *)originalStoryButton.customView;
    if ([originalButton isKindOfClass:[UIButton class]]) {
        originalButton.tintColor = toolbarButtonTint;
    }
    UIButton *markReadButton = (UIButton *)markReadBarButton.customView;
    if ([markReadButton isKindOfClass:[UIButton class]]) {
        markReadButton.tintColor = toolbarButtonTint;
    }
    self.navigationController.navigationBar.tintColor = toolbarButtonTint;
    self.navigationController.toolbar.tintColor = toolbarButtonTint;
}

// allow keyboard commands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

#pragma mark -
#pragma mark State Restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    
    [coder encodeObject:currentPage.activeStoryId forKey:@"current_story_id"];
    
    [appDelegate.storiesCollection toggleStoryUnread];
    self.temporarilyMarkedUnread = YES;
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    
    self.restoringStoryId = [coder decodeObjectOfClass:[NSString class] forKey:@"current_story_id"];
}

- (void)restorePage {
    if (self.restoringStoryId.length > 0) {
        NSInteger pageIndex = [appDelegate.storiesCollection indexOfStoryId:self.restoringStoryId];
        
        if (pageIndex >= 0) {
            [self changePage:pageIndex animated:NO];
        } else if (!self.isPhoneOrCompact) {
            // If the story can't be found, don't show anything; uncomment this to instead show the first unread story:
//            [self doNextUnreadStory:nil];
        } else {
            [appDelegate hideStoryDetailView];
        }
        
        self.restoringStoryId = nil;
    }
}

#pragma mark -
#pragma mark Side scroll view

- (void)applyNewIndex:(NSInteger)newIndex
       pageController:(StoryDetailViewController *)pageController {
    [self applyNewIndex:newIndex pageController:pageController supressRedraw:NO];
}

- (void)applyNewIndex:(NSInteger)newIndex
       pageController:(StoryDetailViewController *)pageController
        supressRedraw:(BOOL)suppressRedraw {
    // StoryPagesObjCViewController.m keeps normal neighbor/layout callbacks from replacing the staged selection.
    if ((pageController == self.pendingPresentationPage && self.storyPreparationHost) ||
        (pageController == self.pendingIntermediatePage && self.storyIntermediatePreparationHost) ||
        [self.storySelectionTransitionPages containsObject:pageController]) return;
    BOOL retainedCurrentPage = pageController && pageController == currentPage &&
        [appDelegate.feedDetailViewController hasRetainedFirstPageStory];
    if (retainedCurrentPage) {
        // StoryPagesObjCViewController.m updates a retained article's frame without hiding or reloading its current web content.
        newIndex = currentPage.pageIndex;
        suppressRedraw = YES;
    }
	NSInteger pageCount = [[appDelegate.storiesCollection activeFeedStoryLocations] count];
	BOOL outOfBounds = !retainedCurrentPage && (newIndex >= pageCount || newIndex < 0);
    
	if (!outOfBounds) {
        CGRect pageFrame = pageController.view.bounds;
        if (self.isHorizontal) {
            pageFrame.origin.y = 0;
            pageFrame.origin.x = CGRectGetWidth(self.scrollView.bounds) * newIndex;
        } else {
            pageFrame.origin.y = CGRectGetHeight(self.scrollView.bounds) * newIndex;
            pageFrame.origin.x = 0;
        }
        pageFrame.size.height = CGRectGetHeight(self.scrollView.bounds);
        pageFrame.size.width = CGRectGetWidth(self.scrollView.bounds);
        
        if (self.currentlyTogglingNavigationBar && !self.isNavigationBarHidden) {
            pageFrame.size.height -= 20.0;
        }
        
        pageController.view.hidden = NO;
		pageController.view.frame = pageFrame;
	} else {
//        NSLog(@"Out of bounds: was %@, now %@", @(pageController.pageIndex), @(newIndex));
		CGRect pageFrame = pageController.view.bounds;
        if (self.isHorizontal) {
            pageFrame.origin.x = CGRectGetWidth(self.scrollView.bounds) * newIndex;
            pageFrame.origin.y = CGRectGetHeight(self.scrollView.bounds);
        } else {
            pageFrame.origin.x = 0;
            pageFrame.origin.y = CGRectGetHeight(self.scrollView.bounds) * newIndex;
        }
        pageFrame.size.height = CGRectGetHeight(self.scrollView.bounds);
        pageFrame.size.width = CGRectGetWidth(self.scrollView.bounds);
        pageController.view.hidden = YES;
		pageController.view.frame = pageFrame;
	}
//    NSLog(@"---> Story page control orient page: %@ (%@-%@)", NSStringFromCGRect(self.scrollView.bounds), @(pageController.pageIndex), suppressRedraw ? @"supress" : @"redraw");

    if (suppressRedraw) return;

    NSString *previousStoryId = pageController.activeStoryId;
    BOOL hadRenderedStory = pageController.hasStory;
    pageController.pageIndex = newIndex;
//    NSLog(@"Applied Index to %@: Was %ld, now %ld (%ld/%ld/%ld) [%lu stories - %d] %@", pageController, (long)wasIndex, (long)newIndex, (long)previousPage.pageIndex, (long)currentPage.pageIndex, (long)nextPage.pageIndex, (unsigned long)[appDelegate.storiesCollection.activeFeedStoryLocations count], outOfBounds, NSStringFromCGRect(self.scrollView.frame));
    
    if (newIndex > 0 && newIndex >= [appDelegate.storiesCollection.activeFeedStoryLocations count]) {
        pageController.pageIndex = -2;
        NSString *notificationHash = appDelegate.storiesCollection.notificationStory[@"story_hash"];
        // StoryPagesObjCViewController.m leaves an exact notification's unloaded gap for explicit navigation.
        BOOL isAutomaticNotificationNeighbor = notificationHash &&
            [notificationHash isEqualToString:currentPage.activeStoryId] &&
            pageController != currentPage && !self.isDraggingScrollview && self.scrollingToPage != newIndex;
        if (!isAutomaticNotificationNeighbor && appDelegate.storiesCollection.feedPage < 100 &&
            !appDelegate.feedDetailViewController.pageFinished &&
            !appDelegate.feedDetailViewController.pageFetching) {
            StoriesCollection *notificationCollection = [notificationHash isEqualToString:currentPage.activeStoryId] ? appDelegate.storiesCollection : nil;
            NSInteger notificationLocation = notificationCollection ? [notificationCollection locationOfStoryId:notificationHash] : -1;
            NSInteger neighborOffset = newIndex - notificationLocation;
            NSUInteger requestId = appDelegate.feedDetailViewController.fetchRequestId;
            NSString *account = [appDelegate.activeUsername copy];
            NSString *host = [appDelegate.url copy];
            [appDelegate.feedDetailViewController fetchNextPage:^() {
                NSInteger requestedIndex = newIndex;
                if (notificationCollection && notificationLocation >= 0) {
                    if (notificationCollection != self.appDelegate.storiesCollection ||
                        requestId != self.appDelegate.feedDetailViewController.fetchRequestId ||
                        ![account isEqualToString:self.appDelegate.activeUsername] || ![host isEqualToString:self.appDelegate.url] ||
                        ![notificationHash isEqualToString:self.currentPage.activeStoryId] || pageController != self.nextPage) return;
                    NSInteger location = [notificationCollection locationOfStoryId:notificationHash];
                    if (location < 0) return;
                    // StoryPagesObjCViewController.m keeps explicit navigation relative to the same story as intervening pages arrive.
                    requestedIndex = location + neighborOffset;
                    self.scrollingToPage = requestedIndex;
                }
                [self applyNewIndex:requestedIndex pageController:pageController];
            }];
        } else if (!isAutomaticNotificationNeighbor && !appDelegate.feedDetailViewController.pageFinished &&
                   !appDelegate.feedDetailViewController.pageFetching) {
            [appDelegate.feedsNavigationController
             popToViewController:[appDelegate.feedsNavigationController.viewControllers
                                  objectAtIndex:0]
             animated:YES];
            [appDelegate hideStoryDetailView];
        }
    } else if (!outOfBounds) {
        NSInteger location = [appDelegate.storiesCollection indexFromLocation:pageController.pageIndex];
        // Look up the target story hash before setActiveStoryAtIndex changes activeStory
        NSString *targetStoryHash = nil;
        if (location >= 0 && location < (NSInteger)[appDelegate.storiesCollection.activeFeedStories count]) {
            targetStoryHash = [appDelegate.storiesCollection.activeFeedStories[location] objectForKey:@"story_hash"];
        }
        [pageController setActiveStoryAtIndex:location];
        UINavigationController *navController = self.navigationController ?: appDelegate.detailViewController.parentNavigationController;
        if (navController.interactivePopGestureRecognizer) {
            [pageController.webView.scrollView.panGestureRecognizer requireGestureRecognizerToFail:navController.interactivePopGestureRecognizer];
            [self.scrollView.panGestureRecognizer requireGestureRecognizerToFail:navController.interactivePopGestureRecognizer];
        }
        // Skip redraw if page already shows the target story (e.g. after pagination fetch)
        if (hadRenderedStory && previousStoryId && targetStoryHash && [previousStoryId isEqualToString:targetStoryHash]) {
            [pageController drawFeedGradient];
            [pageController refreshHeader];
            [pageController refreshSideOptions];
        } else {
        [pageController clearStory];
        if (self.isDraggingScrollview ||
            self.scrollingToPage < 0 ||
            ABS(newIndex - self.scrollingToPage) <= 1) {
            [pageController drawFeedGradient];
            NSString *originalStoryId = pageController.activeStoryId;
            __block StoryDetailViewController *blockPageController = pageController;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), ^{
                if (blockPageController.activeStoryId && ![blockPageController.activeStoryId isEqualToString:originalStoryId]) {
//                    NSLog(@"Stale story, already drawn. Was: %@, Now: %@", originalStoryId, blockPageController.activeStoryId);
                    return;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ((blockPageController == self.pendingPresentationPage && self.storyPreparationHost) ||
                        (blockPageController == self.pendingIntermediatePage && self.storyIntermediatePreparationHost) ||
                        [self.storySelectionTransitionPages containsObject:blockPageController]) return;
                    [blockPageController initStory];
                    [blockPageController drawStory];
                    [blockPageController showTextOrStoryView];
                });
            });
        } else {
//            NSLog(@"Skipping drawing %d (waiting for %d)", newIndex, self.scrollingToPage);
        }
        } // end else (needs redraw)
    } else if (outOfBounds && pageController == self.currentPage) {
        [pageController clearStory];
        
        [self.appDelegate showColumn:UISplitViewControllerColumnSecondary debugInfo:@"applyNewIndex" animated:YES];
    }
    
    if (!suppressRedraw) {
        [self resizeScrollView];
    }
    [self setTextButton];
    [self.loadingIndicator stopAnimating];
    self.circularProgressView.hidden = NO;
    
//    if (self.currentPage != nil && pageController == self.currentPage) {
//        [self.appDelegate.feedDetailViewController changedStoryHeight:currentPage.webView.scrollView.contentSize.height];
//    }
}

- (void)scrollViewDidScroll:(UIScrollView *)sender {
    if (inRotation || self.isRepositioningFirstPage || self.storySelectionTransitionHost) return;
    if ([appDelegate.feedDetailViewController hasRetainedFirstPageStory]) { [self setStoryFromScroll]; return; }
    NSInteger currentPageIndex = currentPage.pageIndex;
    CGSize size = self.scrollView.bounds.size;
    CGPoint offset = self.scrollView.contentOffset;
    CGFloat axisInset = [self axisInsetForScrollView:self.scrollView];
    if (self.isHorizontal) {
        CGFloat lockedY = -self.scrollView.adjustedContentInset.top;
        if (fabs(offset.y - lockedY) > 0.5) {
            offset.y = lockedY;
            self.scrollView.contentOffset = CGPointMake(offset.x, offset.y);
        }
    } else {
        CGFloat lockedX = -self.scrollView.adjustedContentInset.left;
        if (fabs(offset.x - lockedX) > 0.5) {
            offset.x = lockedX;
            self.scrollView.contentOffset = CGPointMake(offset.x, offset.y);
        }
    }
    CGFloat pageAmount = self.isHorizontal ? size.width : size.height;
    float fractionalPage = ((self.isHorizontal ? offset.x : offset.y) + axisInset) / pageAmount;
	
	NSInteger lowerNumber = floor(fractionalPage);
	NSInteger upperNumber = lowerNumber + 1;
	NSInteger previousNumber = lowerNumber - 1;
	
    NSInteger storyCount = [appDelegate.storiesCollection.activeFeedStoryLocations count];
    if (storyCount == 0 || lowerNumber > storyCount) return;
    
//    NSLog(@"Did Scroll: %@ = %@ (%@/%@/%@)", @(fractionalPage), @(lowerNumber), @(previousPage.pageIndex), @(currentPage.pageIndex), @(nextPage.pageIndex));
	if (lowerNumber == currentPage.pageIndex) {
		if (upperNumber != nextPage.pageIndex) {
//            NSLog(@"Next was %d, now %d (A)", nextPage.pageIndex, upperNumber);
			[self applyNewIndex:upperNumber pageController:nextPage];
		}
		if (previousNumber != previousPage.pageIndex) {
//            NSLog(@"Prev was %d, now %d (A)", previousPage.pageIndex, previousNumber);
			[self applyNewIndex:previousNumber pageController:previousPage];
		}
	} else if (upperNumber == currentPage.pageIndex) {
        // Going backwards
		if (lowerNumber != previousPage.pageIndex) {
//            NSLog(@"Prev was %d, now %d (B)", previousPage.pageIndex, previousNumber);
			[self applyNewIndex:lowerNumber pageController:previousPage];
		}
	} else {
        // Going forwards
		if (lowerNumber == nextPage.pageIndex) {
//            NSLog(@"Prev was %d, now %d (C1)", previousPage.pageIndex, previousNumber);
//			[self applyNewIndex:upperNumber pageController:nextPage];
//			[self applyNewIndex:lowerNumber pageController:currentPage];
			[self applyNewIndex:previousNumber pageController:previousPage];
		} else if (upperNumber == nextPage.pageIndex) {
//            NSLog(@"Prev was %d, now %d (C2)", previousPage.pageIndex, previousNumber);
			[self applyNewIndex:lowerNumber pageController:currentPage];
			[self applyNewIndex:previousNumber pageController:previousPage];
		} else {
//            NSLog(@"Next was %d, now %d (C3)", nextPage.pageIndex, upperNumber);
//            NSLog(@"Current was %d, now %d (C3)", currentPage.pageIndex, lowerNumber);
//            NSLog(@"Prev was %d, now %d (C3)", previousPage.pageIndex, previousNumber);
			[self applyNewIndex:lowerNumber pageController:currentPage];
			[self applyNewIndex:upperNumber pageController:nextPage];
			[self applyNewIndex:previousNumber pageController:previousPage];
		}
	}
    
//    if (self.isDraggingScrollview) {
        [self setStoryFromScroll];
//    }
    
    if (currentPage.pageIndex == currentPageIndex) {
        return;
    }
    
    [self showAutoscrollBriefly:YES];
    
    // Stick to bottom
    traversePinned = YES;

    self.traverseBottomConstraint.constant = self.traverseBottomGap;
    
    if (self.traverseView.alpha == 0) {
        [UIView animateWithDuration:.24 delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [self.traverseView setNeedsLayout];
                             self.traverseView.alpha = 1;
                             self.traversePinned = YES;
                             [self.view layoutIfNeeded];
                         } completion:^(BOOL finished) {

                         }];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self cancelPendingStoryPresentationForNavigation];
    self.isDraggingScrollview = YES;
    // Prevent diagonal scrolling: disable web view scroll and cancel in-progress gestures
    if (self.isHorizontal) {
        [self setWebViewsScrollEnabled:NO];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (scrollView != self.scrollView || decelerate) {
        return;
    }

    [self lockScrollViewToNearestPage];
    [self scrollViewDidEndScrollingAnimation:scrollView];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                     withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint *)targetContentOffset {
    if (scrollView != self.scrollView || inRotation) {
        return;
    }

    CGFloat pageAmount = self.isHorizontal ? scrollView.bounds.size.width : scrollView.bounds.size.height;
    if (pageAmount <= 0) {
        return;
    }

    CGFloat axisInset = [self axisInsetForScrollView:scrollView];
    CGFloat rawOffset = self.isHorizontal ? targetContentOffset->x : targetContentOffset->y;
    // StoryPagesObjCViewController.m keeps a retained article's projected swipe around its existing frame until the gesture chooses its new neighbor.
    NSInteger nearestNumber;
    if ([appDelegate.feedDetailViewController hasRetainedFirstPageStory]) {
        NSInteger projectedPage = lround((rawOffset + axisInset) / pageAmount);
        nearestNumber = MAX(0, MAX(currentPage.pageIndex - 1, MIN(currentPage.pageIndex + 1, projectedPage)));
    } else {
        nearestNumber = [self clampedPageIndexForOffset:rawOffset pageAmount:pageAmount];
    }
    CGFloat targetOffset = [self pageOffsetForIndex:nearestNumber pageAmount:pageAmount axisInset:axisInset];

    if (self.isHorizontal) {
        targetContentOffset->x = targetOffset;
        targetContentOffset->y = -scrollView.adjustedContentInset.top;
    } else {
        targetContentOffset->y = targetOffset;
        targetContentOffset->x = -scrollView.adjustedContentInset.left;
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)newScrollView
{
	[self scrollViewDidEndScrollingAnimation:newScrollView];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)newScrollView
{
    if (self.storySelectionTransitionHost) return;
    [self lockScrollViewToNearestPage];
    self.isDraggingScrollview = NO;
    [self setWebViewsScrollEnabled:YES];
    if (appDelegate.feedDetailViewController.suppressMarkAsRead) {
        return;
    }
    CGSize size = self.scrollView.bounds.size;
    CGPoint offset = self.scrollView.contentOffset;
    CGFloat pageAmount = self.isHorizontal ? size.width : size.height;
    NSInteger nearestNumber = [self clampedPageIndexForOffset:(self.isHorizontal ? offset.x : offset.y)
                                                  pageAmount:pageAmount];
    self.scrollingToPage = nearestNumber;
    [self setStoryFromScroll];
}

- (void)setWebViewsScrollEnabled:(BOOL)enabled {
    for (StoryDetailViewController *page in @[currentPage, nextPage, previousPage]) {
        if (!page) continue;
        UIScrollView *sv = page.webView.scrollView;
        sv.scrollEnabled = enabled;
        if (!enabled) {
            // Force-cancel any in-progress pan gesture by toggling enabled.
            // This transitions the gesture to .cancelled then back to .possible.
            sv.panGestureRecognizer.enabled = NO;
            sv.panGestureRecognizer.enabled = YES;
        }
    }
}

- (void)lockScrollViewToNearestPage {
    if ([appDelegate.feedDetailViewController hasRetainedFirstPageStory]) return;
    CGFloat pageAmount = self.isHorizontal ? self.scrollView.bounds.size.width : self.scrollView.bounds.size.height;
    if (pageAmount <= 0) {
        return;
    }

    CGFloat axisInset = [self axisInsetForScrollView:self.scrollView];
    CGPoint offset = self.scrollView.contentOffset;
    CGFloat rawOffset = self.isHorizontal ? offset.x : offset.y;
    NSInteger nearestNumber = [self clampedPageIndexForOffset:rawOffset pageAmount:pageAmount];
    CGFloat targetOffset = [self pageOffsetForIndex:nearestNumber pageAmount:pageAmount axisInset:axisInset];

    if (self.isHorizontal) {
        offset.x = targetOffset;
        offset.y = -self.scrollView.adjustedContentInset.top;
    } else {
        offset.y = targetOffset;
        offset.x = -self.scrollView.adjustedContentInset.left;
    }

    if (fabs(self.scrollView.contentOffset.x - offset.x) > 0.5 ||
        fabs(self.scrollView.contentOffset.y - offset.y) > 0.5) {
        [self.scrollView setContentOffset:offset animated:NO];
    }
}

- (void)alignScrollViewToCurrentPageIfNeeded {
    if (self.isDraggingScrollview || inRotation || self.storySelectionTransitionHost) {
        return;
    }

    NSInteger targetIndex = currentPage.pageIndex >= 0 ? currentPage.pageIndex : self.scrollingToPage;
    if (targetIndex < 0) {
        return;
    }

    CGFloat pageAmount = self.isHorizontal ? self.scrollView.bounds.size.width : self.scrollView.bounds.size.height;
    if (pageAmount <= 0) {
        return;
    }

    CGFloat axisInset = [self axisInsetForScrollView:self.scrollView];
    CGFloat targetOffset = [self pageOffsetForIndex:targetIndex pageAmount:pageAmount axisInset:axisInset];
    CGPoint offset = self.scrollView.contentOffset;

    if (self.isHorizontal) {
        offset.x = targetOffset;
        offset.y = -self.scrollView.adjustedContentInset.top;
    } else {
        offset.y = targetOffset;
        offset.x = -self.scrollView.adjustedContentInset.left;
    }

    if (fabs(self.scrollView.contentOffset.x - offset.x) > 0.5 ||
        fabs(self.scrollView.contentOffset.y - offset.y) > 0.5) {
        [self.scrollView setContentOffset:offset animated:NO];
    }
}

- (void)scrollViewDidChangeAdjustedContentInset:(UIScrollView *)scrollView {
    if (scrollView != self.scrollView) {
        return;
    }

    [self alignScrollViewToCurrentPageIfNeeded];
}

- (CGFloat)axisInsetForScrollView:(UIScrollView *)scrollView {
    return self.isHorizontal ? scrollView.adjustedContentInset.left : scrollView.adjustedContentInset.top;
}

- (CGFloat)pageOffsetForIndex:(NSInteger)pageIndex pageAmount:(CGFloat)pageAmount axisInset:(CGFloat)axisInset {
    return (pageAmount * pageIndex) - axisInset;
}

- (NSInteger)clampedPageIndexForOffset:(CGFloat)rawOffset pageAmount:(CGFloat)pageAmount {
    CGFloat axisInset = [self axisInsetForScrollView:self.scrollView];
    NSInteger storyCount = appDelegate.storiesCollection.storyLocationsCount;
    if (storyCount <= 0) {
        storyCount = 1;
    }

    NSInteger nearestNumber = lround((rawOffset + axisInset) / pageAmount);
    return MAX(0, MIN(storyCount - 1, nearestNumber));
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (self.storySelectionTransitionHost) return;
    if (!self.isPhoneOrCompact &&
        [keyPath isEqual:@"contentOffset"] &&
        self.isDraggingScrollview) {
        CGSize size = self.scrollView.bounds.size;
        CGPoint offset = self.scrollView.contentOffset;
        CGFloat pageAmount = self.isHorizontal ? size.width : size.height;
        NSInteger nearestNumber = [self clampedPageIndexForOffset:(self.isHorizontal ? offset.x : offset.y)
                                                      pageAmount:pageAmount];
        
        if (![appDelegate.storiesCollection.activeFeedStories count]) return;
        
        NSInteger storyIndex = [appDelegate.storiesCollection indexFromLocation:nearestNumber];
        if (storyIndex != [appDelegate.storiesCollection indexOfActiveStory] && storyIndex != NSNotFound) {
            appDelegate.activeStory = [appDelegate.storiesCollection.activeFeedStories
                                       objectAtIndex:storyIndex];
            [appDelegate changeActiveFeedDetailRow];
        }
    }
}

- (void)animateIntoPlace:(BOOL)animated {
    // Move view into position if no story is selected yet
    if (!self.isPhoneOrCompact &&
        !self.isAnimatedIntoPlace) {
        CGRect frame = self.scrollView.frame;
        
        if (self.isHorizontal) {
            frame.origin.x = frame.size.width;
        } else {
            frame.origin.y = frame.size.height;
        }
        
        self.scrollView.frame = frame;
        
        [UIView animateWithDuration:(animated ? .22 : 0) delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
        {
            CGRect frame = self.scrollView.frame;
            if (self.isHorizontal) {
                frame.origin.x = 0;
            } else {
                frame.origin.y = 0;
            }
            self.scrollView.frame = frame;
        } completion:^(BOOL finished) {
            self.isAnimatedIntoPlace = YES;
        }];
    }
}

- (UIView *)preparationHostForPage:(StoryDetailViewController *)page viewport:(CGSize)viewport window:(UIWindow *)window {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewport.width, viewport.height)];
    host.userInteractionEnabled = NO;
    host.accessibilityElementsHidden = YES;
    [window insertSubview:host atIndex:0];
    CGRect pageFrame = page.view.frame;
    pageFrame.size = viewport;
    page.view.frame = pageFrame;
    // StoryPagesObjCViewController.m keeps controller containment while WebKit paints behind the visible app.
    [host addSubview:page.webView];
    page.webView.frame = host.bounds;
    [page.webView layoutIfNeeded];
    return host;
}

- (void)restorePreparedPage:(StoryDetailViewController *)page fromHost:(UIView *)host {
    if (!host) return;
    [page.view addSubview:page.webView];
    page.webView.frame = page.view.bounds;
    [host removeFromSuperview];
    [self applyNewIndex:page.pageIndex pageController:page supressRedraw:YES];
}

- (void)restoreStorySelectionViews {
    UIViewPropertyAnimator *animator = self.storySelectionAnimator;
    self.storySelectionAnimator = nil;
    if (animator.state == UIViewAnimatingStateActive) [animator stopAnimation:YES];
    UIView *host = self.storySelectionTransitionHost;
    NSArray<StoryDetailViewController *> *pages = self.storySelectionTransitionPages;
    self.storySelectionTransitionHost = nil;
    self.storySelectionTransitionPages = nil;
    for (StoryDetailViewController *page in pages) {
        [self.scrollView addSubview:page.view];
        [self applyNewIndex:page.pageIndex pageController:page supressRedraw:YES];
    }
    [host removeFromSuperview];
}

- (BOOL)deferStoryRedrawDuringSelection:(StoryDetailViewController *)page {
    if (![self.storySelectionTransitionPages containsObject:page]) return NO;
    NSString *hash = page.activeStory[@"story_hash"];
    if (!hash.length) return NO;
    if (!self.deferredSelectionRedraws) self.deferredSelectionRedraws = [NSMutableDictionary dictionary];
    for (NSString *previousHash in self.deferredSelectionRedraws.allKeys) {
        if (self.deferredSelectionRedraws[previousHash] == page) [self.deferredSelectionRedraws removeObjectForKey:previousHash];
    }
    // StoryPagesObjCViewController.m keeps the painted document intact until its live-view movement is finished.
    self.deferredSelectionRedraws[hash] = page;
    return YES;
}

- (void)prepareSelectionReplacement:(StoryDetailViewController *)page redraw:(BOOL)redraw {
    UIView *snapshot = [page.view snapshotViewAfterScreenUpdates:NO];
    if (!snapshot) {
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:page.view.bounds.size];
        UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            [page.view drawViewHierarchyInRect:page.view.bounds afterScreenUpdates:NO];
        }];
        snapshot = [[UIImageView alloc] initWithImage:image];
    }
    UIView *parent = self.scrollView.superview;
    UIView *cover = [[UIView alloc] initWithFrame:[parent convertRect:self.scrollView.bounds fromView:self.scrollView]];
    cover.clipsToBounds = YES;
    cover.userInteractionEnabled = NO;
    cover.accessibilityElementsHidden = YES;
    snapshot.frame = cover.bounds;
    snapshot.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [cover addSubview:snapshot];
    [parent insertSubview:cover aboveSubview:self.storySelectionTransitionHost ?: self.scrollView];
    [self.storySelectionRedrawCover removeFromSuperview];
    self.storySelectionRedrawCover = cover;
    [self restoreStorySelectionViews];
    self.pendingPresentationAnimated = NO;
    self.storyPreparationHost = [self preparationHostForPage:page viewport:self.scrollView.bounds.size window:self.view.window];
    [self.deferredSelectionRedraws removeObjectForKey:page.activeStory[@"story_hash"]];
    // StoryPagesObjCViewController.m covers only a late replacement while its fresh document passes the normal paint gate.
    if (redraw) [page drawStory];
    [page prepareCurrentStoryForPresentation];
}

- (void)replayDeferredSelectionRedraws:(NSDictionary<NSString *, StoryDetailViewController *> *)redraws excludingPage:(StoryDetailViewController *)excludedPage {
    [redraws enumerateKeysAndObjectsUsingBlock:^(NSString *storyHash, StoryDetailViewController *page, BOOL *stop) {
        if (page != excludedPage && [storyHash isEqualToString:page.activeStoryId] &&
            [storyHash isEqualToString:page.activeStory[@"story_hash"]]) [page drawStory];
    }];
}

- (void)cancelPendingStoryPresentation {
    NSDictionary *redraws = self.deferredSelectionRedraws;
    [self cancelPendingStoryPresentationWithoutRedraw];
    // StoryPagesObjCViewController.m applies late text to restored pages without reviving the cancelled presentation.
    [self replayDeferredSelectionRedraws:redraws excludingPage:nil];
}

- (void)cancelPendingStoryPresentationWithoutRedraw {
    if (ReaderPerformance.recordsUITestPresentation && self.pendingPresentationPage) NSLog(@"[ReaderPresentation] cancel page=%p hash=%@ fetch=%lu currentFetch=%lu", self.pendingPresentationPage, self.pendingPresentationHash, (unsigned long)self.pendingPresentationFetch, (unsigned long)appDelegate.feedDetailViewController.fetchRequestId);
    [self restoreStorySelectionViews];
    StoryDetailViewController *page = self.pendingPresentationPage;
    StoryDetailViewController *intermediate = self.pendingIntermediatePage;
    UIView *host = self.storyPreparationHost;
    UIView *intermediateHost = self.storyIntermediatePreparationHost;
    self.pendingPresentationCompletion = nil;
    self.pendingPresentationHash = nil;
    self.pendingPresentationPage = nil;
    self.pendingPresentationCollection = nil;
    self.pendingPresentationSource = nil;
    self.pendingPresentationAnimated = NO;
    self.pendingIntermediatePage = nil;
    self.storyPreparationHost = nil;
    self.storyIntermediatePreparationHost = nil;
    self.refreshAfterStorySelection = NO;
    self.deferredSelectionRedraws = nil;
    [self.storySelectionRedrawCover removeFromSuperview];
    self.storySelectionRedrawCover = nil;
    [page finishStoryPresentation];
    [intermediate finishStoryPresentation];
    [self restorePreparedPage:page fromHost:host];
    [self restorePreparedPage:intermediate fromHost:intermediateHost];
}

- (void)preparePageForPresentation:(NSInteger)pageIndex completion:(void (^)(NSInteger))completion {
    [self preparePageForPresentation:pageIndex animated:NO completion:completion];
}

- (void)preparePageForPresentation:(NSInteger)pageIndex animated:(BOOL)animated completion:(void (^)(NSInteger))completion {
    BOOL continuingSelection = self.pendingPresentationCollection == appDelegate.storiesCollection &&
        self.pendingPresentationFetch == appDelegate.feedDetailViewController.fetchRequestId;
    if (self.storySelectionTransitionHost) {
        // StoryPagesObjCViewController.m settles the already-painted destination before a rapid tap, without firing its old completion.
        [self completePendingStoryPresentationCallingCompletion:NO];
    }
    NSMutableDictionary *deferredRedraws = continuingSelection ? self.deferredSelectionRedraws : nil;
    UIView *redrawCover = continuingSelection ? self.storySelectionRedrawCover : nil;
    BOOL refreshAfterSelection = continuingSelection && self.refreshAfterStorySelection;
    if (redrawCover) self.storySelectionRedrawCover = nil;
    [self cancelPendingStoryPresentationWithoutRedraw];
    self.deferredSelectionRedraws = deferredRedraws;
    self.storySelectionRedrawCover = redrawCover;
    self.refreshAfterStorySelection = refreshAfterSelection;
    NSInteger index = [appDelegate.storiesCollection indexFromLocation:pageIndex];
    if (index < 0 || index >= appDelegate.storiesCollection.activeFeedStories.count) {
        if (ReaderPerformance.recordsUITestPresentation) NSLog(@"[ReaderPresentation] invalidLocation location=%ld index=%ld count=%lu", (long)pageIndex, (long)index, (unsigned long)appDelegate.storiesCollection.activeFeedStories.count);
        [self cancelPendingStoryPresentation];
        return;
    }
    NSDictionary *story = appDelegate.storiesCollection.activeFeedStories[index];
    NSString *hash = story[@"story_hash"];
    if (hash.length == 0) {
        [self cancelPendingStoryPresentation];
        return;
    }

    [self.view layoutIfNeeded];
    UINavigationController *navigation = appDelegate.feedsNavigationController;
    if (self.isPhoneOrCompact && self.view.window == nil && navigation.view.bounds.size.width > 0) {
        self.view.frame = navigation.view.bounds;
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }
    [self resizeScrollView];
    CGSize viewport = self.scrollView.bounds.size;
    if (viewport.width <= 0 || viewport.height <= 0) {
        if (ReaderPerformance.recordsUITestPresentation) NSLog(@"[ReaderPresentation] invalidViewport location=%ld viewport=%@", (long)pageIndex, NSStringFromCGSize(viewport));
        [self cancelPendingStoryPresentation];
        return;
    }
    BOOL animateSelection = animated && !redrawCover && !self.isPhoneOrCompact && !UIAccessibilityIsReduceMotionEnabled() &&
        self.view.window && currentPage.hasStory && !currentPage.webView.hidden &&
        !self.isDraggingScrollview && !self.scrollView.dragging && !self.scrollView.decelerating &&
        currentPage.pageIndex >= 0 && ![currentPage.activeStoryId isEqualToString:hash];
    BOOL distantSelection = animateSelection && labs(pageIndex - currentPage.pageIndex) > 1;
    BOOL forward = pageIndex > currentPage.pageIndex;

    StoryDetailViewController *page = nil;
    for (StoryDetailViewController *candidate in @[currentPage, nextPage, previousPage]) {
        if (candidate.hasStory && [candidate.activeStoryId isEqualToString:hash]) {
            page = candidate;
            break;
        }
    }
    if (!page) page = distantSelection ? (forward ? previousPage : nextPage) : nextPage;
    self.pendingPresentationPage = page;
    self.pendingPresentationHash = hash;
    self.pendingPresentationCollection = appDelegate.storiesCollection;
    self.pendingPresentationFetch = appDelegate.feedDetailViewController.fetchRequestId;
    self.pendingPresentationSource = navigation.visibleViewController;
    self.pendingPresentationCompletion = completion;
    self.pendingPresentationAnimated = animateSelection;

    // StoryPagesObjCViewController.m prepares the same native toolbar geometry that viewWillAppear will use.
    if (self.useCustomToolbar && self.view.window == nil) {
        self.navigationBarFadeAlpha = 1;
        self.storyToolbar.hidden = NO;
        self.storyToolbar.transform = CGAffineTransformIdentity;
        [self.toolbarScrollHandler reset];
    }

    UIWindow *window = self.view.window ?: navigation.view.window ?: appDelegate.detailViewController.view.window;
    if (page != currentPage || self.view.window == nil) {
        self.storyPreparationHost = [self preparationHostForPage:page viewport:viewport window:window];
    }
    StoryDetailViewController *intermediate = forward ? nextPage : previousPage;
    NSInteger intermediateLocation = intermediate.activeStoryId.length ?
        [appDelegate.storiesCollection locationOfStoryId:intermediate.activeStoryId] : -1;
    if (distantSelection && intermediate != page && intermediate.hasStory && !intermediate.webView.hidden &&
        intermediateLocation == currentPage.pageIndex + (forward ? 1 : -1)) {
        self.pendingIntermediatePage = intermediate;
        intermediate.pageIndex = intermediateLocation;
        self.storyIntermediatePreparationHost = [self preparationHostForPage:intermediate viewport:viewport window:window];
        [intermediate updateContentInsetForNavigationBarAlpha:self.navigationBarFadeAlpha maintainVisualPosition:NO force:YES];
        [intermediate prepareCurrentStoryForPresentation];
    }
    BOOL needsDocument = !page.hasStory || ![page.activeStoryId isEqualToString:hash];
    if (ReaderPerformance.recordsUITestPresentation) NSLog(@"[ReaderPresentation] prepare hash=%@ page=%p has=%d needs=%d viewport=%@ fetch=%lu source=%@", hash, page, page.hasStory, needsDocument, NSStringFromCGSize(viewport), (unsigned long)self.pendingPresentationFetch, self.pendingPresentationSource);
    page.pageIndex = pageIndex;
    if (needsDocument) {
        [page setActiveStoryAtIndex:index];
        [page clearStory];
        [page initStory];
        [page drawFeedGradient];
        [page drawStory];
        [page showTextOrStoryView];
    }
    [page updateContentInsetForNavigationBarAlpha:self.navigationBarFadeAlpha maintainVisualPosition:NO force:YES];
    [page prepareCurrentStoryForPresentation];
}

- (void)cancelPendingStoryPresentationForNavigation {
    if (!self.pendingPresentationPage) return;
    [self cancelPendingStoryPresentation];
    if (currentPage.activeStory) appDelegate.activeStory = currentPage.activeStory;
    // StoryPagesObjCViewController.m restores the normal neighbor indices before a gesture can swap page controllers.
    NSInteger location = currentPage.pageIndex;
    if (location >= 0) {
        [self applyNewIndex:location - 1 pageController:previousPage];
        [self applyNewIndex:location + 1 pageController:nextPage];
    }
}

- (void)storyDetailCouldNotPrepareForPresentation:(StoryDetailViewController *)page {
    if (ReaderPerformance.recordsUITestPresentation) NSLog(@"[ReaderPresentation] couldNotPrepare page=%p pending=%p", page, self.pendingPresentationPage);
    if (page == self.pendingPresentationPage) [self cancelPendingStoryPresentation];
    else if (page == self.pendingIntermediatePage) {
        UIView *host = self.storyIntermediatePreparationHost;
        self.pendingIntermediatePage = nil;
        self.storyIntermediatePreparationHost = nil;
        [page finishStoryPresentation];
        [self restorePreparedPage:page fromHost:host];
    }
}

- (void)storyDetailReadyForPresentation:(StoryDetailViewController *)page {
    if (self.storySelectionTransitionHost) return;
    if (page != self.pendingPresentationPage || !page.readyForPresentation || !self.pendingPresentationCompletion) return;
    NSString *hash = self.pendingPresentationHash;
    UINavigationController *navigation = appDelegate.feedsNavigationController;
    BOOL obsolete = self.pendingPresentationCollection != appDelegate.storiesCollection ||
        self.pendingPresentationFetch != appDelegate.feedDetailViewController.fetchRequestId ||
        ![hash isEqualToString:appDelegate.activeStory[@"story_hash"]] ||
        ![hash isEqualToString:page.activeStoryId] ||
        (self.isPhoneOrCompact && self.pendingPresentationSource != navigation.visibleViewController);
    NSInteger location = [appDelegate.storiesCollection locationOfStoryId:hash];
    if (ReaderPerformance.recordsUITestPresentation) NSLog(@"[ReaderPresentation] ready hash=%@ location=%ld obsolete=%d fetch=%lu/%lu active=%@ source=%@/%@", hash, (long)location, obsolete, (unsigned long)self.pendingPresentationFetch, (unsigned long)appDelegate.feedDetailViewController.fetchRequestId, appDelegate.activeStory[@"story_hash"], self.pendingPresentationSource, navigation.visibleViewController);
    if (obsolete || location < 0) {
        [self cancelPendingStoryPresentation];
        return;
    }
    CGSize viewport = self.scrollView.bounds.size;
    if (!CGSizeEqualToSize(page.webView.bounds.size, viewport)) {
        self.storyPreparationHost.frame = CGRectMake(0, 0, viewport.width, viewport.height);
        CGRect frame = page.view.frame;
        frame.size = viewport;
        page.view.frame = frame;
        page.webView.frame = page.view.bounds;
        [page prepareCurrentStoryForPresentation];
        return;
    }

    if (self.pendingPresentationAnimated && !UIAccessibilityIsReduceMotionEnabled() &&
        page != currentPage && currentPage.hasStory && !currentPage.webView.hidden && self.view.window) {
        [self animatePreparedStorySelection:page location:location];
    } else {
        [self completePendingStoryPresentationCallingCompletion:YES];
    }
}

- (void)animatePreparedStorySelection:(StoryDetailViewController *)page location:(NSInteger)location {
    CGSize viewport = self.scrollView.bounds.size;
    NSInteger sourceLocation = [appDelegate.storiesCollection locationOfStoryId:currentPage.activeStoryId];
    if (sourceLocation < 0 || sourceLocation == location) {
        [self completePendingStoryPresentationCallingCompletion:YES];
        return;
    }
    currentPage.pageIndex = sourceLocation;
    page.pageIndex = location;
    BOOL forward = location > sourceLocation;
    StoryDetailViewController *intermediate = self.pendingIntermediatePage;
    NSInteger intermediateLocation = intermediate.activeStoryId.length ?
        [appDelegate.storiesCollection locationOfStoryId:intermediate.activeStoryId] : -1;
    BOOL includeIntermediate = intermediate.readyForPresentation && intermediate.hasStory && !intermediate.webView.hidden &&
        CGSizeEqualToSize(intermediate.webView.bounds.size, viewport) &&
        (forward ? intermediateLocation > sourceLocation && intermediateLocation < location :
                   intermediateLocation < sourceLocation && intermediateLocation > location);
    if (includeIntermediate) intermediate.pageIndex = intermediateLocation;

    UIView *preparationHost = self.storyPreparationHost;
    UIView *intermediateHost = self.storyIntermediatePreparationHost;
    self.storyPreparationHost = nil;
    self.storyIntermediatePreparationHost = nil;
    [self restorePreparedPage:page fromHost:preparationHost];
    [self restorePreparedPage:intermediate fromHost:intermediateHost];
    [page finishStoryPresentation];
    [intermediate finishStoryPresentation];

    NSArray<StoryDetailViewController *> *sequence = includeIntermediate ? @[currentPage, intermediate, page] : @[currentPage, page];
    NSArray<StoryDetailViewController *> *ordered = forward ? sequence : sequence.reverseObjectEnumerator.allObjects;
    UIView *parent = self.scrollView.superview;
    UIView *host = [[UIView alloc] initWithFrame:[parent convertRect:self.scrollView.bounds fromView:self.scrollView]];
    host.clipsToBounds = YES;
    host.userInteractionEnabled = NO;
    host.accessibilityElementsHidden = YES;
    host.backgroundColor = self.scrollView.backgroundColor;
    [parent insertSubview:host aboveSubview:self.scrollView];
    self.storySelectionTransitionHost = host;
    self.storySelectionTransitionPages = ordered;

    CGFloat amount = self.isHorizontal ? viewport.width : viewport.height;
    CGFloat travel = (ordered.count - 1) * amount;
    UIView *track = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
        self.isHorizontal ? viewport.width * ordered.count : viewport.width,
        self.isHorizontal ? viewport.height : viewport.height * ordered.count)];
    [host addSubview:track];
    [ordered enumerateObjectsUsingBlock:^(StoryDetailViewController *visiblePage, NSUInteger index, BOOL *stop) {
        [track addSubview:visiblePage.view];
        visiblePage.view.hidden = NO;
        visiblePage.view.frame = CGRectMake(self.isHorizontal ? index * amount : 0,
                                           self.isHorizontal ? 0 : index * amount,
                                           viewport.width, viewport.height);
    }];
    CGFloat start = forward ? 0 : -travel;
    CGFloat end = forward ? -travel : 0;
    track.transform = CGAffineTransformMakeTranslation(self.isHorizontal ? start : 0, self.isHorizontal ? 0 : start);
    NSTimeInterval duration = includeIntermediate ? .42 : (labs(location - sourceLocation) > 1 ? .34 : .28);
    // StoryPagesObjCViewController.m animates only painted views, never the logical offsets of intervening stories.
    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:duration curve:UIViewAnimationCurveEaseInOut animations:^{
        track.transform = CGAffineTransformMakeTranslation(self.isHorizontal ? end : 0, self.isHorizontal ? 0 : end);
    }];
    self.storySelectionAnimator = animator;
    __weak typeof(self) weakSelf = self;
    __weak UIViewPropertyAnimator *weakAnimator = animator;
    [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.storySelectionAnimator != weakAnimator) return;
        strongSelf.storySelectionAnimator = nil;
        [strongSelf completePendingStoryPresentationCallingCompletion:YES];
    }];
    [animator startAnimation];
}

- (void)finishStorySelectionAnimation {
    UIViewPropertyAnimator *animator = self.storySelectionAnimator;
    if (animator.state != UIViewAnimatingStateActive) return;
    [animator stopAnimation:NO];
    [animator finishAnimationAtPosition:UIViewAnimatingPositionEnd];
}

- (void)completePendingStoryPresentationCallingCompletion:(BOOL)callCompletion {
    StoryDetailViewController *page = self.pendingPresentationPage;
    NSString *hash = self.pendingPresentationHash;
    NSInteger location = hash.length ? [appDelegate.storiesCollection locationOfStoryId:hash] : -1;
    UINavigationController *navigation = appDelegate.feedsNavigationController;
    BOOL obsolete = !page || self.pendingPresentationCollection != appDelegate.storiesCollection ||
        self.pendingPresentationFetch != appDelegate.feedDetailViewController.fetchRequestId ||
        ![hash isEqualToString:page.activeStoryId] ||
        (callCompletion && ![hash isEqualToString:appDelegate.activeStory[@"story_hash"]]) ||
        (self.isPhoneOrCompact && self.pendingPresentationSource != navigation.visibleViewController);
    if (obsolete || location < 0) {
        [self cancelPendingStoryPresentation];
        return;
    }
    BOOL redraw = self.deferredSelectionRedraws[hash] == page;
    if (callCompletion && (redraw || !page.readyForPresentation)) {
        [self prepareSelectionReplacement:page redraw:redraw];
        return;
    }
    void (^completion)(NSInteger) = callCompletion ? self.pendingPresentationCompletion : nil;
    BOOL refresh = self.refreshAfterStorySelection;
    NSMutableDictionary<NSString *, StoryDetailViewController *> *deferredRedraws = self.deferredSelectionRedraws;
    [self cancelPendingStoryPresentationWithoutRedraw];
    // StoryPagesObjCViewController.m promotes one of its existing three controllers after painting and visual movement finish.
    if (page != currentPage) {
        if (page == nextPage) nextPage = currentPage;
        else previousPage = currentPage;
        currentPage = page;
    }
    page.pageIndex = location;
    CGSize viewport = self.scrollView.bounds.size;
    BOOL repositioning = self.isRepositioningFirstPage;
    self.isRepositioningFirstPage = YES;
    [self applyNewIndex:location pageController:page supressRedraw:YES];
    CGFloat amount = self.isHorizontal ? viewport.width : viewport.height;
    CGFloat offset = [self pageOffsetForIndex:location pageAmount:amount axisInset:[self axisInsetForScrollView:self.scrollView]];
    CGPoint position = self.scrollView.contentOffset;
    if (self.isHorizontal) position.x = offset; else position.y = offset;
    [self.scrollView setContentOffset:position animated:NO];
    self.isRepositioningFirstPage = repositioning;
    [self ensureCurrentPageViewIsFrontmost];
    if (!callCompletion) {
        self.deferredSelectionRedraws = deferredRedraws;
        self.refreshAfterStorySelection = refresh;
    }
    if (completion) completion(location);
    if (refresh && callCompletion) [self refreshPages];
    if (callCompletion) [self replayDeferredSelectionRedraws:deferredRedraws excludingPage:currentPage];
}

- (void)changePage:(NSInteger)pageIndex {
    [self changePage:pageIndex animated:YES];
}

- (void)immediatelyRealignPagesForPageIndex:(NSInteger)pageIndex {
    NSInteger storyIndex = [appDelegate.storiesCollection indexFromLocation:pageIndex];
    if (storyIndex < 0 || storyIndex >= [appDelegate.storiesCollection.activeFeedStories count]) {
        return;
    }

    appDelegate.activeStory = [appDelegate.storiesCollection.activeFeedStories objectAtIndex:storyIndex];
    [self updatePageWithActiveStory:pageIndex updateFeedDetail:YES];
    [self resetTraverseFadeForStoryChange];
}

- (void)changePage:(NSInteger)pageIndex animated:(BOOL)animated {
//    NSLog(@"changePage to %@ (%@animated)", @(pageIndex), animated ? @"" : @"not ");
    
	// update the scroll view to the appropriate page
    [self resizeScrollView];
    CGRect frame = self.scrollView.bounds;
    CGPoint offset = self.scrollView.contentOffset;
    CGFloat axisInset = [self axisInsetForScrollView:self.scrollView];
    
    if (self.isHorizontal) {
        frame.origin.x = [self pageOffsetForIndex:pageIndex
                                       pageAmount:frame.size.width
                                        axisInset:axisInset];
        frame.origin.y = 0;
    } else {
        frame.origin.x = 0;
        frame.origin.y = [self pageOffsetForIndex:pageIndex
                                       pageAmount:frame.size.height
                                        axisInset:axisInset];
    }
    
    self.scrollingToPage = pageIndex;
    BOOL shouldImmediatelyRealignPages = [StoryPageChangeDecision shouldImmediatelyRealignPagesWithCurrentPageIndex:currentPage.pageIndex
                                                                                                      targetPageIndex:pageIndex
                                                                                                             animated:animated];
    
    if (pageIndex >= 0) {
        [self.currentPage hideNoStoryMessage];
        [self.nextPage hideNoStoryMessage];
        [self.previousPage hideNoStoryMessage];
    }
    
    // Check if already on the selected page
    if (self.isHorizontal ? offset.x == frame.origin.x : offset.y == frame.origin.y) {
        [self applyNewIndex:pageIndex pageController:currentPage];
        if (shouldImmediatelyRealignPages) {
            [self immediatelyRealignPagesForPageIndex:pageIndex];
        } else {
            [self setStoryFromScroll];
        }
    } else {
        [self.scrollView scrollRectToVisible:frame animated:animated && self.currentPage.pageIndex > -2];
        if (shouldImmediatelyRealignPages) {
            [self immediatelyRealignPagesForPageIndex:pageIndex];
        } else if (!animated) {
            [self setStoryFromScroll];
        }
    }
    
    if (self.isPhoneOrCompact || animated) {
        appDelegate.storyPagesViewController.currentPage.view.hidden = NO;
        appDelegate.storyPagesViewController.currentPage.noStoryMessage.hidden = YES;
        
        [appDelegate showColumn:UISplitViewControllerColumnSecondary debugInfo:@"changePage" animated:animated];
    }
    
    // Ensure traverse bar is visible when a valid story page is loaded.
    // On iPad/Catalyst the split view keeps this VC visible so viewWillAppear
    // may have set alpha to 0 before any feed was active.
    if (pageIndex >= 0 && self.traverseView.alpha == 0) {
        BOOL hasFeedOrFolder = appDelegate.storiesCollection.activeFeed != nil || appDelegate.storiesCollection.activeFolder != nil;
        if (hasFeedOrFolder) {
            self.traversePinned = YES;
            self.traverseBottomConstraint.constant = self.traverseBottomGap;
            [UIView animateWithDuration:.24 delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:^{
                                 self.traverseView.alpha = 1;
                                 [self.view layoutIfNeeded];
                             } completion:nil];
        }
    }

    [self becomeFirstResponder];

    if (!self.isPhoneOrCompact && !self.doneInitialRefresh) {
        self.doneInitialRefresh = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            [self refreshPages];
        });
    }

}

- (void)changeToNextPage:(id)sender {
    [self cancelPendingStoryPresentationForNavigation];
    if ([appDelegate.feedDetailViewController hasRetainedFirstPageStory]) {
        NSInteger target = [appDelegate.feedDetailViewController consumeRetainedFirstPageStoryInDirection:1];
        if (target != NSNotFound) [self changePage:target animated:YES];
        return;
    }
    if (nextPage.pageIndex < 0 && currentPage.pageIndex < 0) {
        // just displaying a placeholder - display the first story instead
        [self changePage:0 animated:YES];
        return;
    }
    
    [self changePage:currentPage.pageIndex + 1 animated:YES];
}

- (void)changeToPreviousPage:(id)sender {
    [self cancelPendingStoryPresentationForNavigation];
    if ([appDelegate.feedDetailViewController hasRetainedFirstPageStory]) {
        NSInteger target = [appDelegate.feedDetailViewController consumeRetainedFirstPageStoryInDirection:-1];
        if (target != NSNotFound) [self changePage:target animated:YES];
        return;
    }
    if (previousPage.pageIndex < 0) {
        if (currentPage.pageIndex < 0) {
            [self changeToNextPage:sender];
        }
        return;
    }
    
    [self changePage:currentPage.pageIndex - 1 animated:YES];
}

- (void)setStoryFromScroll {
    [self setStoryFromScroll:NO];
}

- (void)setStoryFromScroll:(BOOL)force {
    if (self.isRepositioningFirstPage || self.storySelectionTransitionHost) return;
    BOOL retainedFirstPageStory = [appDelegate.feedDetailViewController hasRetainedFirstPageStory];
    if (retainedFirstPageStory && !self.scrollView.dragging && !self.scrollView.decelerating) return;
    CGSize size = self.scrollView.bounds.size;
    CGPoint offset = self.scrollView.contentOffset;
    CGFloat pageAmount = self.isHorizontal ? size.width : size.height;
	NSInteger nearestNumber = [self clampedPageIndexForOffset:(self.isHorizontal ? offset.x : offset.y)
                                                  pageAmount:pageAmount];
    if (retainedFirstPageStory) {
        if (pageAmount <= 0) return;
        CGFloat rawOffset = self.isHorizontal ? offset.x : offset.y;
        NSInteger intendedPage = lround((rawOffset + [self axisInsetForScrollView:self.scrollView]) / pageAmount);
        if (intendedPage == currentPage.pageIndex) return;
        NSInteger target = [appDelegate.feedDetailViewController consumeRetainedFirstPageStoryInDirection:intendedPage > currentPage.pageIndex ? 1 : -1];
        if (target != NSNotFound) [self changePage:target animated:NO];
        return;
    }
    StoryDetailViewController *previousCurrentPage = currentPage;
    
    
    if (!force && currentPage.pageIndex >= 0 &&
        currentPage.pageIndex == nearestNumber &&
        currentPage.pageIndex != self.scrollingToPage) {
//        NSLog(@"Skipping setStoryFromScroll: currentPage is %@ (%@, %@)", @(currentPage.pageIndex), @(nearestNumber), @(self.scrollingToPage));
        return;
    }
    
	if (currentPage.pageIndex < nearestNumber) {
//        NSLog(@"Swap next into current, current into previous: %@ / %@", @(currentPage.pageIndex), @(nearestNumber));
		StoryDetailViewController *swapCurrentController = currentPage;
		StoryDetailViewController *swapPreviousController = previousPage;
		currentPage = nextPage;
		previousPage = swapCurrentController;
        nextPage = swapPreviousController;
	} else if (currentPage.pageIndex > nearestNumber) {
//        NSLog(@"Swap previous into current: %@ / %@", @(currentPage.pageIndex), @(nearestNumber));
		StoryDetailViewController *swapCurrentController = currentPage;
		StoryDetailViewController *swapNextController = nextPage;
		currentPage = previousPage;
		nextPage = swapCurrentController;
        previousPage = swapNextController;
    }

    if (previousCurrentPage != currentPage) {
        [self refreshCurrentPageChrome];
    }
    
    
    self.autoscrollActive = NO;
//    [self showAutoscrollBriefly:YES];
    
    nextPage.webView.scrollView.scrollsToTop = NO;
    previousPage.webView.scrollView.scrollsToTop = NO;
    currentPage.webView.scrollView.scrollsToTop = YES;
    currentPage.isRecentlyUnread = NO;
    if (!self.isPhoneOrCompact) {
        appDelegate.feedDetailViewController.storyTitlesTable.scrollsToTop = NO;
    }
    self.scrollView.scrollsToTop = NO;
    
    if (self.isDraggingScrollview || self.scrollingToPage == currentPage.pageIndex) {
        if (currentPage.pageIndex == -2) return;
        self.scrollingToPage = -1;
        NSInteger storyIndex = [appDelegate.storiesCollection indexFromLocation:currentPage.pageIndex];
        
        if (storyIndex < 0 || storyIndex >= UINT_MAX) {
            NSLog(@"invalid story index: %@ for page index: %@", @(storyIndex), @(currentPage.pageIndex));  // log
        }
        
        // Harvest read time for the previous story before switching
        NSDictionary *previousStory = appDelegate.activeStory;
        if (previousStory) {
            NSString *prevHash = previousStory[@"story_hash"];
            if (prevHash) {
                NSInteger readTime = [[ReadTimeTracker shared] getAndResetReadTimeWithStoryHash:prevHash];
                if (readTime > 0) {
                    [[ReadTimeTracker shared] queueReadTimeWithStoryHash:prevHash seconds:readTime];
                }
            }
        }

        appDelegate.activeStory = [appDelegate.storiesCollection.activeFeedStories objectAtIndex:storyIndex];
        [self updatePageWithActiveStory:currentPage.pageIndex updateFeedDetail:YES];
        [self resetTraverseFadeForStoryChange];
        [appDelegate.feedDetailViewController markStoryReadIfNeeded:appDelegate.activeStory isScrolling:NO];
        [appDelegate.feedDetailViewController redrawUnreadStory];
        [appDelegate.storyPagesViewController.currentPage refreshHeader];

        // Start tracking read time for the new story
        NSString *newHash = [appDelegate.activeStory objectForKey:@"story_hash"];
        if (newHash) {
            [[ReadTimeTracker shared] startTrackingWithStoryHash:newHash];
        }

        // Reset scroll direction tracking so toolbar can respond to first scroll-up
        currentPage.lastDragDirectionDown = NO;

        // Sync all pages' content insets and scroll positions with current toolbar state
        [currentPage updateContentInsetForNavigationBarAlpha:self.navigationBarFadeAlpha maintainVisualPosition:NO force:YES];
        [nextPage updateContentInsetForNavigationBarAlpha:self.navigationBarFadeAlpha maintainVisualPosition:NO force:YES];
        [previousPage updateContentInsetForNavigationBarAlpha:self.navigationBarFadeAlpha maintainVisualPosition:NO force:YES];

        if (self.isCustomToolbarActive) {
            CGFloat toolbarOffset = self.toolbarScrollHandler.toolbarOffset;
            CGFloat toolbarHeight = self.toolbarScrollHandler.toolbarHeight;
            // Adjust all pages' scroll positions for toolbar state
            for (StoryDetailViewController *page in @[currentPage, nextPage, previousPage]) {
                if (!page) continue;
                UIScrollView *sv = page.webView.scrollView;
                CGFloat topRest = -sv.contentInset.top;
                CGFloat maxAdjustedTop = topRest + toolbarHeight;
                CGFloat targetOffset = topRest + toolbarOffset;
                if (sv.contentOffset.y <= maxAdjustedTop + 1) {
                    sv.contentOffset = CGPointMake(sv.contentOffset.x, targetOffset);
                }
            }
        }

        [self refreshCurrentPageChrome];
    }
    
    if (!appDelegate.storiesCollection.inSearch) {
        [currentPage becomeFirstResponder];
    }
}

- (void)advanceToNextUnread {
    if (self.restoringStoryId.length > 0) {
        [self restorePage];
        return;
    }
    
    if (!self.waitingForNextUnreadFromServer) {
        return;
    }
    
    self.waitingForNextUnreadFromServer = NO;
    [self doNextUnreadStory:nil];
}

- (void)updatePageWithActiveStory:(NSInteger)location updateFeedDetail:(BOOL)updateFeedDetail {
    if (appDelegate.activeStory == nil) {
        return;
    }
    
    [appDelegate.storiesCollection pushReadStory:[appDelegate.activeStory objectForKey:@"story_hash"]];
    
#if TARGET_OS_MACCATALYST
    self.appDelegate.detailViewController.navigationItem.leftBarButtonItems = @[[[UIBarButtonItem alloc] initWithCustomView:[UIView new]]];
#endif
    
    [self updateStoryTitleNavigationButtons];
    
    [self setNextPreviousButtons];
    [self updateUITestStoryStateProbe];
    
    if (updateFeedDetail) {
        [appDelegate changeActiveFeedDetailRow];
    }
    
    if (self.currentPage.pageIndex != location) {
//        NSLog(@"Updating Current: from %d to %d", currentPage.pageIndex, location);
        [self applyNewIndex:location pageController:self.currentPage];
    }
    if (self.nextPage.pageIndex != location+1) {
//        NSLog(@"Updating Next: from %d to %d", nextPage.pageIndex, location+1);
        [self applyNewIndex:location+1 pageController:self.nextPage];
    }
    if (self.previousPage.pageIndex != location-1) {
//        NSLog(@"Updating Previous: from %d to %d", previousPage.pageIndex, location-1);
        [self applyNewIndex:location-1 pageController:self.previousPage];
    }
}

- (void)requestFailed:(id)request {
    [self informError:@"The server barfed!"];
}

#pragma mark -
#pragma mark Actions

- (IBAction)markAllRead:(id)sender {
    [appDelegate.feedDetailViewController doOpenMarkReadMenu:markReadBarButton];
}

- (void)setNextPreviousButtons {
    // Previous button enabled state
    NSInteger readStoryCount = [appDelegate.readStories count];
    BOOL prevEnabled = !(readStoryCount == 0 ||
        (readStoryCount == 1 &&
         [[appDelegate.readStories lastObject] isEqual:[appDelegate.activeStory objectForKey:@"story_hash"]]));
    [self.traverseBar updatePreviousEnabled:prevEnabled];

    // Next/Done button state
    buttonNext.enabled = YES;
    NSInteger nextIndex = [appDelegate.storiesCollection indexOfNextUnreadStory];
    NSInteger unreadCount = [appDelegate unreadCount];
    BOOL pageFinished = appDelegate.feedDetailViewController.pageFinished;
    BOOL hasMoreUnread = (nextIndex == -1 && unreadCount > 0 && !pageFinished) || nextIndex != -1;
    [self.traverseBar updateNextShowDone:!hasMoreUnread];

    // Progress indicator
    float unreads = (float)[appDelegate unreadCount];
    float total = [appDelegate originalStoryCount];
    float progress = (total - unreads) / total;
    [self.traverseBar updateProgress:progress];
}

- (void)updateUITestStoryStateProbe {
    if (!self.uiTestStoryStateProbeView) {
        return;
    }

    NSDictionary *activeStory = appDelegate.activeStory;
    NSString *storyTitle = [activeStory[@"story_title"] isKindOfClass:[NSString class]] ? activeStory[@"story_title"] : nil;
    NSString *storyHash = [activeStory[@"story_hash"] isKindOfClass:[NSString class]] ? activeStory[@"story_hash"] : nil;

    self.uiTestStoryStateProbeView.accessibilityLabel = storyTitle.length ? storyTitle : @"No story selected";
    self.uiTestStoryStateProbeView.accessibilityValue = storyHash;
}

- (void)updateUITestTraverseFadeProbe {
    if (!self.uiTestTraverseFadeProbeView) {
        return;
    }

    self.uiTestTraverseFadeProbeView.accessibilityValue = [NSString stringWithFormat:@"alpha=%.3f accumulator=%.3f",
                                                           self.traverseView.alpha,
                                                           self.traverseFadeAccumulator];
}

- (void)setTextButton {
    [self setTextButton:currentPage];
}

- (void)setTextButton:(StoryDetailViewController *)storyViewController {
    if (storyViewController != currentPage) return;

    BOOL enabled = storyViewController.pageIndex >= 0;
    [self.traverseBar updateTextInTextView:storyViewController.inTextView enabled:enabled];
    [self.traverseBar updateSendEnabled:enabled];

    fontSettingsButton.enabled = enabled;
    originalStoryButton.enabled = enabled;

#if TARGET_OS_MACCATALYST
    if (@available(macCatalyst 16.0, *)) {
        fontSettingsButton.hidden = !enabled;
        originalStoryButton.hidden = !enabled;
    }
#endif
}

- (IBAction)openSendToDialog:(id)sender {
    [self endTouchDown:sender];
    [appDelegate showSendTo:self sender:sender];
}

- (void)openStoryTrainerFromKeyboard:(id)sender {
    // don't have a tap target for the popover, but the settings button at least doesn't move
    [appDelegate openTrainStory:self.fontSettingsButton];
}

- (void)finishMarkAsSaved:(NSDictionary *)params {
    [appDelegate.feedDetailViewController redrawUnreadStory];
    [self refreshHeaders];
    [self.currentPage flashCheckmarkHud:@"saved"];
}

- (BOOL)failedMarkAsSaved:(NSDictionary *)params {
    if (![[params objectForKey:@"story_id"]
          isEqualToString:[currentPage.activeStory objectForKey:@"story_hash"]]) {
        return NO;
    }

    [self informError:@"Failed to save story"];
    [appDelegate hidePopover];
    return YES;
}

- (void)finishMarkAsUnsaved:(NSDictionary *)params {
    [appDelegate.storiesCollection markStory:[params objectForKey:@"story"] asSaved:NO];
    [appDelegate.feedDetailViewController redrawUnreadStory];
    [self refreshHeaders];
    [self.currentPage flashCheckmarkHud:@"unsaved"];
}


- (BOOL)failedMarkAsUnsaved:(NSDictionary *)params {
    if (![[params objectForKey:@"story_id"]
          isEqualToString:[currentPage.activeStory objectForKey:@"story_hash"]]) {
        return NO;
    }
    
    [self informError:@"Failed to unsave story"];
    return YES;
}

- (BOOL)failedMarkAsUnread:(NSDictionary *)params {
    if (![[params objectForKey:@"story_id"]
          isEqualToString:[currentPage.activeStory objectForKey:@"story_hash"]]) {
        return NO;
    }
    
    [self informError:@"Failed to unread story"];
    return YES;
}

- (IBAction)showOriginalSubview:(id)sender {
    [appDelegate hidePopover];
    
    NSString *permalink = [appDelegate.activeStory objectForKey:@"story_permalink"];
    NSURL *url = [NSURL URLWithString:permalink];
    
    if (url == nil) {
        url = [NSURL URLWithDataRepresentation:[permalink dataUsingEncoding:NSUTF8StringEncoding] relativeToURL:nil];
    }
    
    [appDelegate showOriginalStory:url sender:originalStoryButton];
}

- (IBAction)tapProgressBar:(id)sender {
    [MBProgressHUD hideHUDForView:currentPage.webView animated:NO];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:currentPage.webView animated:YES];
	hud.mode = MBProgressHUDModeText;
	hud.removeFromSuperViewOnHide = YES;
    NSInteger unreadCount = appDelegate.unreadCount;
    if (unreadCount == 0) {
        hud.labelText = @"No unread stories";
    } else if (unreadCount == 1) {
        hud.labelText = @"1 story left";
    } else {
        hud.labelText = [NSString stringWithFormat:@"%li stories left", (long)unreadCount];
    }
	[hud hide:YES afterDelay:0.8];
}

- (void)subscribeToBlurblog {
    [self.currentPage subscribeToBlurblog];
}

- (IBAction)toggleTextView:(id)sender {
    [self endTouchDown:sender];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                           [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    [appDelegate toggleFeedTextView:feedIdStr];
    
    [self.currentPage showTextOrStoryView];
    [self.nextPage showTextOrStoryView];
    [self.previousPage showTextOrStoryView];
    
    [self.appDelegate.feedDetailViewController reload];
//    [self.appDelegate.feedDetailViewController changedStoryHeight:currentPage.webView.scrollView.contentSize.height];
}

- (IBAction)toggleStorySaved:(id)sender {
    [appDelegate.storiesCollection toggleStorySaved];
}

- (IBAction)toggleStoryUnread:(id)sender {
    [appDelegate.storiesCollection toggleStoryUnread];
    [appDelegate.feedDetailViewController reload]; // XXX only if successful?
}

- (void)scrollPageDown:(id)sender {
    [self.currentPage scrollPageDown:sender];
}

- (void)scrollPageUp:(id)sender {
    [self.currentPage scrollPageUp:sender];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(toggleTextView:) ||
        action == @selector(scrollPageDown:) ||
        action == @selector(scrollPageUp:) ||
        action == @selector(toggleStoryUnread:) ||
        action == @selector(toggleStorySaved:) ||
        action == @selector(showOriginalSubview:) ||
        action == @selector(openShareDialog) ||
        action == @selector(scrolltoComment) ||
        action == @selector(openStoryTrainerFromKeyboard:)) {
        return (currentPage.pageIndex >= 0);
    }
    return [super canPerformAction:action withSender:sender];
}

#pragma mark -
#pragma mark Styles

//- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
//    if item.itemIdentifier ==
//    return !self.currentPage.view.isHidden;
//}

- (IBAction)toggleFontSize:(id)sender {
    UINavigationController *fontSettingsNavigationController = appDelegate.fontSettingsNavigationController;

    [fontSettingsNavigationController popToRootViewControllerAnimated:NO];
//    [appDelegate showPopoverWithViewController:fontSettingsNavigationController contentSize:CGSizeZero sourceNavigationController:self.navigationController barButtonItem:self.fontSettingsButton sourceView:nil sourceRect:CGRectZero permittedArrowDirections:UIPopoverArrowDirectionAny];
    
#if TARGET_OS_MACCATALYST
    UINavigationController *storiesNavController = appDelegate.storyPagesViewController.navigationController;
    UIView *sourceView = storiesNavController.view;
    CGRect sourceRect = CGRectMake(storiesNavController.view.frame.size.width - 59, 0, 20, 20);

    [appDelegate showPopoverWithViewController:fontSettingsNavigationController contentSize:CGSizeZero sourceView:sourceView sourceRect:sourceRect];
#else
    if (self.isCustomToolbarActive) {
        UIView *btn = self.storyToolbar.settingsButton;
        [appDelegate showPopoverWithViewController:fontSettingsNavigationController contentSize:CGSizeZero sourceView:btn sourceRect:btn.bounds permittedArrowDirections:UIPopoverArrowDirectionUp];
    } else {
        [appDelegate showPopoverWithViewController:fontSettingsNavigationController contentSize:CGSizeZero barButtonItem:self.fontSettingsButton];
    }
#endif
}

- (void)setFontStyle:(NSString *)fontStyle {
    [self.currentPage setFontStyle:fontStyle];
    [self.nextPage setFontStyle:fontStyle];
    [self.previousPage setFontStyle:fontStyle];
}

- (void)changeFontSize:(NSString *)fontSize {
    [self.currentPage changeFontSize:fontSize];
    [self.nextPage changeFontSize:fontSize];
    [self.previousPage changeFontSize:fontSize];
}

- (void)changeLineSpacing:(NSString *)lineSpacing {
    [self.currentPage changeLineSpacing:lineSpacing];
    [self.nextPage changeLineSpacing:lineSpacing];
    [self.previousPage changeLineSpacing:lineSpacing];
}

- (void)changedFullscreen {
    if (self.useCustomToolbar) {
        // Custom toolbar is always active on iPhone; fullscreen setting only controls scroll-to-hide.
        // When fullscreen is off, ensure toolbar is fully visible.
        if (!self.allowFullscreen) {
            [self.toolbarScrollHandler reset];
            [self setToolbarOffset:0];
        }
    } else {
        BOOL wantHidden = self.allowFullscreen;
        if (wantHidden) {
            [self.navigationController setNavigationBarHidden:YES animated:YES];
        } else {
            [self.navigationController setNavigationBarHidden:NO animated:YES];
        }
        [self setNavigationBarHidden:wantHidden alsoTraverse:YES];
    }
}

- (void)changedAutoscroll {
    self.autoscrollActive = self.autoscrollAvailable;
}

- (void)changedScrollOrientation {
    [self.scrollView setAlwaysBounceHorizontal:self.isHorizontal];
    [self.scrollView setAlwaysBounceVertical:!self.isHorizontal];
    [self reorientPages];
    [self updatePopGestureForScrollOrientation];
}

- (void)configureFullScreenPopGesture {
    if (self.fullScreenPopGesture != nil) {
        return;
    }

    UINavigationController *navController = self.navigationController ?: appDelegate.feedsNavigationController;
    if (!navController || !navController.interactivePopGestureRecognizer) {
        return;
    }

    NSArray *targets = [navController.interactivePopGestureRecognizer valueForKey:@"_targets"];
    id internalTarget = [targets firstObject];
    id target = [internalTarget valueForKey:@"target"];
    SEL action = NSSelectorFromString(@"handleNavigationTransition:");
    if (!target || ![target respondsToSelector:action]) {
        return;
    }

    self.fullScreenPopGesture = [[UIPanGestureRecognizer alloc] initWithTarget:target action:action];
    self.fullScreenPopGesture.delegate = self;
    [self.view addGestureRecognizer:self.fullScreenPopGesture];

    [self.scrollView.panGestureRecognizer requireGestureRecognizerToFail:self.fullScreenPopGesture];

    [self updatePopGestureForScrollOrientation];
}

- (void)updatePopGestureForScrollOrientation {
    UINavigationController *navController = self.navigationController ?: appDelegate.feedsNavigationController;
    if (self.isHorizontal) {
        self.fullScreenPopGesture.enabled = NO;
        navController.interactivePopGestureRecognizer.enabled = YES;
    } else {
        self.fullScreenPopGesture.enabled = YES;
        navController.interactivePopGestureRecognizer.enabled = NO;
    }
}

- (void)updateStoriesTheme {
    [self.currentPage updateStoryTheme];
    [self.nextPage updateStoryTheme];
    [self.previousPage updateStoryTheme];
}

- (void)updateStatusBarTheme {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self updateStatusBarState];
    }
}

#pragma mark -
#pragma mark HUDs

- (void)showShareHUD:(NSString *)msg {
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    self.storyHUD = [MBProgressHUD showHUDAddedTo:currentPage.view animated:YES];
    self.storyHUD.labelText = msg;
    self.storyHUD.margin = 20.0f;
    self.storyHUD.removeFromSuperViewOnHide = YES;
    self.currentPage.noStoryMessage.hidden = YES;
}

- (void)flashCheckmarkHud:(NSString *)messageType {
    [[self currentPage] flashCheckmarkHud:messageType];
}

- (void)showFetchingTextNotifier {
    self.notifier.style = NBSyncingStyle;
    self.notifier.title = @"Fetching text...";
    [self.notifier setProgress:0];
    [self.notifier show];
}

- (void)hideNotifier {
    [self.notifier hide];
}

#pragma mark -
#pragma mark Story Autoscroll

- (BOOL)autoscrollAvailable {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"story_autoscroll"];
}

- (void)setAutoscrollAvailable:(BOOL)available {
    [[NSUserDefaults standardUserDefaults] setBool:available forKey:@"story_autoscroll"];
}

- (NSTimeInterval)autoscrollSpeed {
    CGFloat speed = [[NSUserDefaults standardUserDefaults] doubleForKey:@"story_autoscroll_speed"];
    
    if (speed <= 0) {
        speed = 0.03;
    }
    
    return speed;
}

- (void)setAutoscrollSpeed:(NSTimeInterval)speed {
    [[NSUserDefaults standardUserDefaults] setDouble:speed forKey:@"story_autoscroll_speed"];
    
    // This will update the timer with the new speed.
    self.autoscrollActive = self.autoscrollActive;
    
    NSLog(@"set autoscroll speed to: %@", @(speed));  // log
}

- (BOOL)autoscrollActive {
    return self.autoscrollTimer != nil;
}

- (void)setAutoscrollActive:(BOOL)active {
    [self.autoscrollTimer invalidate];
    self.autoscrollTimer = nil;
    
    if (active && self.autoscrollAvailable) {
        self.autoscrollTimer = [NSTimer scheduledTimerWithTimeInterval:self.autoscrollSpeed target:self selector:@selector(autoscroll:) userInfo:nil repeats:YES];
    }
    
    [self updateAutoscrollButtons];
}

- (void)autoscroll:(NSTimer *)timer {
    WKWebView *webView = self.currentPage.webView;
    CGFloat position = webView.scrollView.contentOffset.y + 0.5;
    CGFloat maximum = (webView.scrollView.contentSize.height - webView.frame.size.height) + self.view.safeAreaInsets.bottom;
    
    if (position < maximum) {
        [webView.scrollView setContentOffset:CGPointMake(0, position) animated:NO];
    } else {
        self.autoscrollActive = NO;
    }
}

- (void)tappedStory {
    if (self.autoscrollAvailable) {
        [self showAutoscrollBriefly:YES];
//    } else if (self.allowFullscreen) {
//        [self setNavigationBarHidden: !self.isNavigationBarHidden];
    }
}

- (void)showAutoscrollBriefly:(BOOL)briefly {
    if (!self.autoscrollAvailable || self.currentPage.webView.scrollView.contentSize.height - 200 <= self.currentPage.view.frame.size.height) {
        [self hideAutoscrollWithAnimation];
        return;
    }
    
    if (self.autoscrollView.alpha == 0) {
        if (self.isPhoneOrCompact) {
            self.autoscrollBottomConstraint.constant = 70;
        } else {
            self.autoscrollBottomConstraint.constant = 0;
        }
        
        [self.view layoutIfNeeded];
        
        [UIView animateWithDuration:0.2 animations:^{
            [self.view layoutIfNeeded];
            self.autoscrollView.alpha = 1;
        }];
    }
    
    if (briefly) {
        [self hideAutoscrollAfterDelay];
    }
}

- (void)hideAutoscrollAfterDelay {
    [self.autoscrollViewTimer invalidate];
    self.autoscrollViewTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(hideAutoscrollWithAnimation) userInfo:nil repeats:NO];
}

- (void)hideAutoscrollWithAnimation {
    [self.autoscrollViewTimer invalidate];
    self.autoscrollViewTimer = nil;
    
    [self.view layoutIfNeeded];
    
    [UIView animateWithDuration:1 animations:^{
        [self.view layoutIfNeeded];
        self.autoscrollView.alpha = 0;
    }];
}

- (void)hideAutoscrollImmediately {
    [self.autoscrollViewTimer invalidate];
    self.autoscrollViewTimer = nil;
    self.autoscrollView.alpha = 0;
}

- (void)resetAutoscrollViewTimerIfNeeded {
    if (self.autoscrollViewTimer != nil) {
        [self hideAutoscrollAfterDelay];
    }
}

- (IBAction)autoscrollDisable:(UIButton *)sender {
    self.autoscrollAvailable = NO;
    self.autoscrollActive = NO;
    
    [self hideAutoscrollWithAnimation];
}

- (IBAction)autoscrollPauseResume:(UIButton *)sender {
    self.autoscrollActive = !self.autoscrollActive;
    
    [self resetAutoscrollViewTimerIfNeeded];
}

- (IBAction)autoscrollSlower:(UIButton *)sender {
    if (self.autoscrollSpeed < 1) {
        self.autoscrollSpeed = self.autoscrollSpeed * 2; // + 0.05;
    } else {
        NSLog(@"Minimum autoscroll speed reached");  // log
    }
    
    [self resetAutoscrollViewTimerIfNeeded];
}

- (IBAction)autoscrollFaster:(UIButton *)sender {
    if (self.autoscrollSpeed > 0.001) {
        self.autoscrollSpeed = self.autoscrollSpeed / 2; // - 0.05;
    } else {
        NSLog(@"Maximum autoscroll speed reached");  // log
    }
    
    [self resetAutoscrollViewTimerIfNeeded];
}

#pragma mark -
#pragma mark Story Traversal

- (IBAction)doNextUnreadStory:(id)sender {
    [self cancelPendingStoryPresentationForNavigation];
    if ([appDelegate.feedDetailViewController hasRetainedFirstPageStory]) { [self changeToNextPage:sender]; return; }
    FeedDetailViewController *fdvc = appDelegate.feedDetailViewController;
    NSInteger nextLocation = [appDelegate.storiesCollection locationOfNextUnreadStory];
    NSInteger unreadCount = [appDelegate unreadCount];
    BOOL pageFinished = appDelegate.feedDetailViewController.pageFinished;

    [self.loadingIndicator stopAnimating];
    
    [self endTouchDown:sender];
//    NSLog(@"doNextUnreadStory: %d (out of %d)", nextLocation, unreadCount);
    
    if (nextLocation == -1 && unreadCount > 0 && !pageFinished &&
        appDelegate.storiesCollection.feedPage < 100) {
        [self.loadingIndicator startAnimating];
        self.circularProgressView.hidden = YES;
        self.buttonNext.enabled = NO;
        // Fetch next page and see if it has the unreads.
        self.waitingForNextUnreadFromServer = YES;
        [fdvc fetchNextPage:nil];
    } else if (nextLocation == -1) {
        [appDelegate hideStoryDetailView];
    } else {
        [self changePage:nextLocation];
    }
}

- (IBAction)doPreviousStory:(id)sender {
    [self cancelPendingStoryPresentationForNavigation];
    if ([appDelegate.feedDetailViewController hasRetainedFirstPageStory]) { [self changeToPreviousPage:sender]; return; }
    [self endTouchDown:sender];
    [self.loadingIndicator stopAnimating];
    self.circularProgressView.hidden = NO;
    id previousStoryId = [appDelegate.storiesCollection popReadStory];
    if (!previousStoryId || [previousStoryId isEqual:[appDelegate.activeStory objectForKey:@"story_hash"]]) {
        [self.appDelegate showColumn:UISplitViewControllerColumnSecondary debugInfo:@"doPreviousStory" animated:YES];
        [appDelegate hideStoryDetailView];
    } else {
        NSInteger previousLocation = [appDelegate.storiesCollection locationOfStoryId:previousStoryId];
        if (previousLocation == -1) {
            return [self doPreviousStory:sender];
        }
        [self changePage:previousLocation];
    }
}

@end
