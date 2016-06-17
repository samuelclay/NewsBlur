//
//  StoryPageControl.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "StoryPageControl.h"
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
#import "SBJson4.h"
#import "UIBarButtonItem+Image.h"
#import "THCircularProgressView.h"
#import "FMDatabase.h"
#import "StoriesCollection.h"

@implementation StoryPageControl

@synthesize appDelegate;
@synthesize currentPage, nextPage, previousPage;
@synthesize circularProgressView;
@synthesize separatorBarButton;
@synthesize spacerBarButton, spacer2BarButton, spacer3BarButton;
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

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
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
    currentPage.view.frame = self.scrollView.frame;
    nextPage.view.frame = self.scrollView.frame;
    previousPage.view.frame = self.scrollView.frame;
    
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
//    NSLog(@"Scroll view frame post: %@", NSStringFromCGRect(self.scrollView.frame));
//    NSLog(@"Scroll view parent: %@", NSStringFromCGRect(currentPage.view.frame));
    [self.scrollView sizeToFit];
//    NSLog(@"Scroll view frame post 2: %@", NSStringFromCGRect(self.scrollView.frame));
    
    // adding HUD for progress bar
    CGFloat radius = 8;
    circularProgressView = [[THCircularProgressView alloc]
                            initWithCenter:CGPointMake(self.buttonNext.frame.origin.x + 2*radius,
                                                       self.traverseView.frame.size.height / 2)
                            radius:radius
                            lineWidth:radius / 4.0f
                            progressMode:THProgressModeFill
                            progressColor:[UIColor colorWithRed:0.612f green:0.62f blue:0.596f alpha:0.4f]
                            progressBackgroundMode:THProgressBackgroundModeCircumference
                            progressBackgroundColor:[UIColor colorWithRed:0.312f green:0.32f blue:0.296f alpha:.04f]
                            percentage:20];
    circularProgressView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.traverseView addSubview:circularProgressView];
    UIView *tapIndicator = [[UIView alloc]
                            initWithFrame:CGRectMake(circularProgressView.frame.origin.x -
                                                     circularProgressView.frame.size.width / 2,
                                                     circularProgressView.frame.origin.y -
                                                     circularProgressView.frame.size.height / 2,
                                                     circularProgressView.frame.size.width*2,
                                                     circularProgressView.frame.size.height*2)];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(tapProgressBar:)];
    [tapIndicator addGestureRecognizer:tap];
    tapIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.traverseView insertSubview:tapIndicator aboveSubview:circularProgressView];
    self.loadingIndicator.frame = self.circularProgressView.frame;

    spacerBarButton = [[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                       target:nil action:nil];
    spacerBarButton.width = -12;
    spacer2BarButton = [[UIBarButtonItem alloc]
                        initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                        target:nil action:nil];
    spacer2BarButton.width = -6;
    spacer3BarButton = [[UIBarButtonItem alloc]
                        initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                        target:nil action:nil];
    spacer3BarButton.width = -6;
    
    UIImage *separatorImage = [UIImage imageNamed:@"bar-separator.png"];
    if ([ThemeManager themeManager].isDarkTheme) {
        separatorImage = [UIImage imageNamed:@"bar_separator_dark"];
    }
    separatorBarButton = [UIBarButtonItem barItemWithImage:separatorImage
                                                    target:nil
                                                    action:nil];
    [separatorBarButton setEnabled:NO];
    separatorBarButton.isAccessibilityElement = NO;
    
    UIImage *settingsImage = [UIImage imageNamed:@"nav_icn_settings.png"];
    fontSettingsButton = [UIBarButtonItem barItemWithImage:settingsImage
                                                    target:self
                                                    action:@selector(toggleFontSize:)];
    fontSettingsButton.accessibilityLabel = @"Story settings";
    
    UIImage *markreadImage = [UIImage imageNamed:@"original_button.png"];
    originalStoryButton = [UIBarButtonItem barItemWithImage:markreadImage
                                                     target:self
                                                     action:@selector(showOriginalSubview:)];
    originalStoryButton.accessibilityLabel = @"Show original story";
    
    UIBarButtonItem *subscribeBtn = [[UIBarButtonItem alloc]
                                     initWithTitle:@"Follow User"
                                     style:UIBarButtonSystemItemAction
                                     target:self
                                     action:@selector(subscribeToBlurblog)
                                     ];
    
    self.subscribeButton = subscribeBtn;
    
    // back button
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc]
                                   initWithTitle:@"All Sites"
                                   style:UIBarButtonItemStylePlain
                                   target:self
                                   action:@selector(transitionFromFeedDetail)];
    self.buttonBack = backButton;
    
    self.notifier = [[NBNotifier alloc] initWithTitle:@"Fetching text..."
                                               inView:self.view
                                           withOffset:CGPointMake(0.0, 0.0 /*self.bottomSize.frame.size.height*/)];
    [self.view addSubview:self.notifier];
    [self.notifier hideNow];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:
                                                   originalStoryButton,
                                                   separatorBarButton,
                                                   fontSettingsButton, nil];
    }
    
    [self.scrollView addObserver:self forKeyPath:@"contentOffset"
                         options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         context:nil];
    
    _orientation = [UIApplication sharedApplication].statusBarOrientation;

    [self addKeyCommandWithInput:UIKeyInputDownArrow modifierFlags:0 action:@selector(changeToNextPage:) discoverabilityTitle:@"Next Story"];
    [self addKeyCommandWithInput:@"j" modifierFlags:0 action:@selector(changeToNextPage:) discoverabilityTitle:@"Next Story"];
    [self addKeyCommandWithInput:UIKeyInputUpArrow modifierFlags:0 action:@selector(changeToPreviousPage:) discoverabilityTitle:@"Previous Story"];
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
    [self addCancelKeyCommandWithAction:@selector(backToDashboard:) discoverabilityTitle:@"Dashboard"];
    [self addKeyCommandWithInput:@"d" modifierFlags:UIKeyModifierShift action:@selector(backToDashboard:) discoverabilityTitle:@"Dashboard"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateTraverseBackground];
    [self setNextPreviousButtons];
    [self setTextButton];

    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    BOOL swipeEnabled = [[userPreferences stringForKey:@"story_detail_swipe_left_edge"]
                         isEqualToString:@"pop_to_story_list"];;
    self.navigationController.interactivePopGestureRecognizer.enabled = swipeEnabled;

    if (self.isPhoneOrCompact) {
        if (!appDelegate.storiesCollection.isSocialView) {
            UIImage *titleImage;
            if (appDelegate.storiesCollection.isSocialRiverView &&
                [appDelegate.storiesCollection.activeFolder isEqualToString:@"river_global"]) {
                titleImage = [UIImage imageNamed:@"ak-icon-global.png"];
            } else if (appDelegate.storiesCollection.isSocialRiverView &&
                       [appDelegate.storiesCollection.activeFolder isEqualToString:@"river_blurblogs"]) {
                titleImage = [UIImage imageNamed:@"ak-icon-blurblogs.png"];
            } else if (appDelegate.storiesCollection.isRiverView &&
                       [appDelegate.storiesCollection.activeFolder isEqualToString:@"everything"]) {
                titleImage = [UIImage imageNamed:@"ak-icon-allstories.png"];
            } else if (appDelegate.storiesCollection.isSavedView &&
                       appDelegate.storiesCollection.activeSavedStoryTag) {
                titleImage = [UIImage imageNamed:@"tag.png"];
            } else if ([appDelegate.storiesCollection.activeFolder isEqualToString:@"read_stories"]) {
                titleImage = [UIImage imageNamed:@"g_icn_folder_read.png"];
            } else if ([appDelegate.storiesCollection.activeFolder isEqualToString:@"saved_stories"]) {
                titleImage = [UIImage imageNamed:@"clock.png"];
            } else if (appDelegate.storiesCollection.isRiverView) {
                titleImage = [UIImage imageNamed:@"g_icn_folder.png"];
            } else {
                NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                                       [appDelegate.activeStory objectForKey:@"story_feed_id"]];
                titleImage = [appDelegate getFavicon:feedIdStr];
            }
            
            UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
            if (appDelegate.storiesCollection.isRiverView) {
                titleImageView.frame = CGRectMake(0.0, 2.0, 22.0, 22.0);
            } else {
                titleImageView.frame = CGRectMake(0.0, 2.0, 16.0, 16.0);
            }
            titleImageView.hidden = YES;
            titleImageView.contentMode = UIViewContentModeScaleAspectFit;
            if (!self.navigationItem.titleView) {
                self.navigationItem.titleView = titleImageView;
            }
            titleImageView.hidden = NO;
        } else {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                                   [appDelegate.storiesCollection.activeFeed objectForKey:@"id"]];
            UIImage *titleImage  = [appDelegate getFavicon:feedIdStr];
            titleImage = [Utilities roundCorneredImage:titleImage radius:6];
            
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
            imageView.frame = CGRectMake(0.0, 0.0, 28.0, 28.0);
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            [imageView setImage:titleImage];
            self.navigationItem.titleView = imageView;
        }
    }
    
    previousPage.view.hidden = YES;
    self.traverseView.alpha = 1;
    self.isAnimatedIntoPlace = NO;
    currentPage.view.hidden = NO;
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithTitle:@" "
                                             style:UIBarButtonItemStylePlain
                                             target:nil action:nil];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    [self layoutForInterfaceOrientation:orientation];
    [self adjustDragBar:orientation];
    [self reorientPages];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // set the subscribeButton flag
    if (appDelegate.isTryFeedView && !self.isPhoneOrCompact) {
        self.subscribeButton.title = [NSString stringWithFormat:@"Follow %@",
                                      [appDelegate.storiesCollection.activeFeed objectForKey:@"username"]];
        self.navigationItem.leftBarButtonItem = self.subscribeButton;
        //        self.subscribeButton.tintColor = UIColorFromRGB(0x0a6720);
    }
    appDelegate.isTryFeedView = NO;
    [self reorientPages];
//    [self applyNewIndex:previousPage.pageIndex pageController:previousPage];
    previousPage.view.hidden = NO;
    [self becomeFirstResponder];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
//    [self reorientPages];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    self.navigationItem.leftBarButtonItem = nil;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    previousPage.view.hidden = YES;
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
}

- (BOOL)becomeFirstResponder {
    // delegate to current page
    return [currentPage becomeFirstResponder];
}

- (void)transitionFromFeedDetail {
//    [self performSelector:@selector(resetPages) withObject:self afterDelay:0.5];
    [appDelegate.masterContainerViewController transitionFromFeedDetail];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
//        NSLog(@"---> Story page control is re-orienting: %@ / %@", NSStringFromCGSize(self.view.bounds.size), NSStringFromCGSize(size));
        UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
        _orientation = [UIApplication sharedApplication].statusBarOrientation;
        [self layoutForInterfaceOrientation:orientation];
        [self adjustDragBar:orientation];
        [self reorientPages];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
//        NSLog(@"---> Story page control did re-orient: %@ / %@", NSStringFromCGSize(self.view.bounds.size), NSStringFromCGSize(size));
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        [self refreshPages];
    }];
}

- (void)layoutForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
//        appDelegate.masterContainerViewController.originalViewIsVisible) {
//        return;
//    }
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
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    [self layoutForInterfaceOrientation:orientation];
    [self adjustDragBar:orientation];
}

- (void)adjustDragBar:(UIInterfaceOrientation)orientation {
//    CGRect scrollViewFrame = self.scrollView.frame;
//    CGRect traverseViewFrame = self.traverseView.frame;

    if (self.isPhoneOrCompact ||
        UIInterfaceOrientationIsLandscape(orientation)) {
//        scrollViewFrame.size.height = self.view.bounds.size.height;
//        self.bottomSize.hidden = YES;
        [self.bottomSizeHeightConstraint setConstant:0];
        [bottomSize setHidden:YES];
    } else {
//        scrollViewFrame.size.height = self.view.bounds.size.height - 12;
//        self.bottomSize.hidden = NO;
        [self.bottomSizeHeightConstraint setConstant:12];
        [bottomSize setHidden:NO];
    }
    
    [self.view layoutIfNeeded];
//    self.scrollView.frame = scrollViewFrame;
//    traverseViewFrame.origin.y = scrollViewFrame.size.height - traverseViewFrame.size.height;
//    self.traverseView.frame = traverseViewFrame;
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

- (void)resetPages {
    self.navigationItem.titleView = nil;

    [currentPage clearStory];
    [nextPage clearStory];
    [previousPage clearStory];

    CGRect frame = self.scrollView.frame;
    self.scrollView.contentSize = frame.size;
    
//    NSLog(@"Pages are at: %f / %f / %f (%@)", previousPage.view.frame.origin.x, currentPage.view.frame.origin.x, nextPage.view.frame.origin.x, NSStringFromCGRect(frame));
    currentPage.view.frame = self.scrollView.frame;
    nextPage.view.frame = self.scrollView.frame;
    previousPage.view.frame = self.scrollView.frame;

    currentPage.pageIndex = -2;
    nextPage.pageIndex = -2;
    previousPage.pageIndex = -2;
}

- (void)hidePages {
    [currentPage hideStory];
    [nextPage hideStory];
    [previousPage hideStory];
}

- (void)refreshPages {
    NSInteger pageIndex = currentPage.pageIndex;
    [self resizeScrollView];
    [appDelegate adjustStoryDetailWebView];
    currentPage.pageIndex = -2;
    nextPage.pageIndex = -2;
    previousPage.pageIndex = -2;
    [self changePage:pageIndex animated:NO];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [self.notifier hide];
    //    self.scrollView.contentOffset = CGPointMake(self.scrollView.frame.size.width * currentPage.pageIndex, 0);
}

- (void)reorientPages {
    [self applyNewIndex:currentPage.pageIndex-1 pageController:previousPage supressRedraw:YES];
    [self applyNewIndex:currentPage.pageIndex+1 pageController:nextPage supressRedraw:YES];
    [self applyNewIndex:currentPage.pageIndex pageController:currentPage supressRedraw:YES];

    NSInteger currentIndex = currentPage.pageIndex;
    [self resizeScrollView]; // Will change currentIndex, so preserve
    
    // Scroll back to preserved index
    CGRect frame = self.scrollView.bounds;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        frame = self.view.bounds;
    }
    frame.origin.x = frame.size.width * currentIndex;
    frame.origin.y = 0;
    [self.scrollView scrollRectToVisible:frame animated:NO];
//    NSLog(@"---> Scrolling to story at: %@ %d-%d", NSStringFromCGRect(frame), currentPage.pageIndex, currentIndex);
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [self hideNotifier];
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

    [currentPage refreshSideoptions];
    [nextPage refreshSideoptions];
    [previousPage refreshSideoptions];
}

- (void)resizeScrollView {
    NSInteger widthCount = appDelegate.storiesCollection.storyLocationsCount;
	if (widthCount == 0) {
		widthCount = 1;
	}
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width
                                             * widthCount,
                                             self.scrollView.bounds.size.height);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    if (!self.isPhoneOrCompact &&
        UIInterfaceOrientationIsPortrait(orientation)) {
        UITouch *theTouch = [touches anyObject];
        CGPoint tappedPt = [theTouch locationInView:self.view];
        NSInteger fudge = appDelegate.masterContainerViewController.storyTitlesOnLeft ? -30 : -20;
        BOOL inside = CGRectContainsPoint(CGRectInset(self.bottomSize.frame, 0, fudge), tappedPt);
        BOOL attached = self.inTouchMove;
        
        if (theTouch.view == self.bottomSize || inside || attached) {
            self.inTouchMove = YES;
            CGPoint touchLocation = [theTouch locationInView:self.view];
            CGFloat y = touchLocation.y;
            [appDelegate.masterContainerViewController dragStoryToolbar:y];
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    if (!self.isPhoneOrCompact &&
        UIInterfaceOrientationIsPortrait(orientation)) {
        if (self.inTouchMove) {
            self.inTouchMove = NO;
            [appDelegate.masterContainerViewController adjustFeedDetailScreenForStoryTitles];
        }
    }
}

- (BOOL)isPhoneOrCompact {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone || self.appDelegate.isCompactWidth;
}

- (void)updateTraverseBackground {
    self.textStorySendBackgroundImageView.image = [[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"traverse_background.png"]];
    self.prevNextBackgroundImageView.image = [[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"traverse_background.png"]];
    self.dragBarImageView.image = [[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"drag_icon.png"]];
    self.bottomSize.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
}

- (void)updateTheme {
    [super updateTheme];
    
    [self updateTraverseBackground];
    [self setNextPreviousButtons];
    [self setTextButton];
    [self drawStories];
}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
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
	NSInteger pageCount = [[appDelegate.storiesCollection activeFeedStoryLocations] count];
	BOOL outOfBounds = newIndex >= pageCount || newIndex < 0;
    
	if (!outOfBounds) {
		CGRect pageFrame = pageController.view.bounds;
		pageFrame.origin.y = 0;
		pageFrame.origin.x = CGRectGetWidth(self.view.bounds) * newIndex;
        pageFrame.size.height = CGRectGetHeight(self.view.bounds) - self.bottomSizeHeightConstraint.constant;
        pageController.view.hidden = NO;
		pageController.view.frame = pageFrame;
	} else {
//        NSLog(@"Out of bounds: was %d, now %d", pageController.pageIndex, newIndex);
		CGRect pageFrame = pageController.view.bounds;
		pageFrame.origin.x = CGRectGetWidth(self.view.bounds) * newIndex;
		pageFrame.origin.y = CGRectGetHeight(self.view.bounds);
        pageFrame.size.height = CGRectGetHeight(self.view.bounds) - self.bottomSizeHeightConstraint.constant;
        pageController.view.hidden = YES;
		pageController.view.frame = pageFrame;
	}
//    NSLog(@"---> Story page control orient page: %@ (%d-%d)", NSStringFromCGRect(self.view.bounds), pageController.pageIndex, suppressRedraw);

    if (suppressRedraw) return;
    
    //    NSInteger wasIndex = pageController.pageIndex;
	pageController.pageIndex = newIndex;
//    NSLog(@"Applied Index to %@: Was %ld, now %ld (%ld/%ld/%ld) [%lu stories - %d] %@", pageController, (long)wasIndex, (long)newIndex, (long)previousPage.pageIndex, (long)currentPage.pageIndex, (long)nextPage.pageIndex, (unsigned long)[appDelegate.storiesCollection.activeFeedStoryLocations count], outOfBounds, NSStringFromCGRect(self.scrollView.frame));
    
    if (newIndex > 0 && newIndex >= [appDelegate.storiesCollection.activeFeedStoryLocations count]) {
        pageController.pageIndex = -2;
        if (self.appDelegate.storiesCollection.feedPage < 100 &&
            !self.appDelegate.feedDetailViewController.pageFinished &&
            !self.appDelegate.feedDetailViewController.pageFetching) {
            [self.appDelegate.feedDetailViewController fetchNextPage:^() {
//                NSLog(@"Fetched next page, %d stories", [appDelegate.activeFeedStoryLocations count]);
                [self applyNewIndex:newIndex pageController:pageController];
            }];
        } else if (!self.appDelegate.feedDetailViewController.pageFinished &&
                   !self.appDelegate.feedDetailViewController.pageFetching) {
            [appDelegate.navigationController
             popToViewController:[appDelegate.navigationController.viewControllers
                                  objectAtIndex:0]
             animated:YES];
            [appDelegate hideStoryDetailView];
        }
    } else if (!outOfBounds) {
        NSInteger location = [appDelegate.storiesCollection indexFromLocation:pageController.pageIndex];
        [pageController setActiveStoryAtIndex:location];
        [pageController clearStory];
        if (self.isDraggingScrollview ||
            self.scrollingToPage < 0 ||
            ABS(newIndex - self.scrollingToPage) <= 1) {
            [pageController drawFeedGradient];
            NSString *originalStoryId = pageController.activeStoryId;
            __block StoryDetailViewController *blockPageController = pageController;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), ^{
                if (blockPageController.activeStoryId && ![blockPageController.activeStoryId isEqualToString:originalStoryId]) {
                    NSLog(@"Stale story, already drawn. Was: %@, Now: %@", originalStoryId, blockPageController.activeStoryId);
                    return;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [blockPageController initStory];
                    [blockPageController drawStory];
                    [blockPageController showTextOrStoryView];
                });
            });
        } else {
//            [pageController clearStory];
//            NSLog(@"Skipping drawing %d (waiting for %d)", newIndex, self.scrollingToPage);
        }
    } else if (outOfBounds) {
        [pageController clearStory];
    }
    
    if (!suppressRedraw) {
        [self resizeScrollView];
    }
    [self setTextButton];
    [self.loadingIndicator stopAnimating];
    self.circularProgressView.hidden = NO;
}

- (void)scrollViewDidScroll:(UIScrollView *)sender {
//    [sender setContentOffset:CGPointMake(sender.contentOffset.x, 0)];
    if (inRotation) return;
    CGFloat pageWidth = self.scrollView.frame.size.width;
    float fractionalPage = self.scrollView.contentOffset.x / pageWidth;
	
	NSInteger lowerNumber = floor(fractionalPage);
	NSInteger upperNumber = lowerNumber + 1;
	NSInteger previousNumber = lowerNumber - 1;
	
    NSInteger storyCount = [appDelegate.storiesCollection.activeFeedStoryLocations count];
    if (storyCount == 0 || lowerNumber > storyCount) return;
    
//    NSLog(@"Did Scroll: %f = %d (%d/%d/%d)", fractionalPage, lowerNumber, previousPage.pageIndex, currentPage.pageIndex, nextPage.pageIndex);
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
    
    // Stick to bottom
    CGRect tvf = self.traverseView.frame;
    traversePinned = YES;
    [UIView animateWithDuration:.24 delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self.traverseView setNeedsLayout];
                         self.traverseView.frame = CGRectMake(tvf.origin.x,
                                                              self.view.bounds.size.height - tvf.size.height - bottomSizeHeightConstraint.constant,
                                                              tvf.size.width, tvf.size.height);
                         self.traverseView.alpha = 1;
                         self.traversePinned = YES;
                     } completion:^(BOOL finished) {
                         
                     }];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.isDraggingScrollview = YES;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)newScrollView
{
	[self scrollViewDidEndScrollingAnimation:newScrollView];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)newScrollView
{
    self.isDraggingScrollview = NO;
    CGFloat pageWidth = self.scrollView.frame.size.width;
    float fractionalPage = self.scrollView.contentOffset.x / pageWidth;
	NSInteger nearestNumber = lround(fractionalPage);
    self.scrollingToPage = nearestNumber;
    [self setStoryFromScroll];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (!self.isPhoneOrCompact &&
        [keyPath isEqual:@"contentOffset"] &&
        self.isDraggingScrollview) {
        CGFloat pageWidth = self.scrollView.frame.size.width;
        float fractionalPage = self.scrollView.contentOffset.x / pageWidth;
        NSInteger nearestNumber = lround(fractionalPage);
        
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
        frame.origin.x = frame.size.width;
        self.scrollView.frame = frame;
        [UIView animateWithDuration:(animated ? .22 : 0) delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
        {
            CGRect frame = self.scrollView.frame;
            frame.origin.x = 0;
            self.scrollView.frame = frame;
        } completion:^(BOOL finished) {
            self.isAnimatedIntoPlace = YES;
        }];
    }
}

- (void)changePage:(NSInteger)pageIndex {
    [self changePage:pageIndex animated:YES];
}

- (void)changePage:(NSInteger)pageIndex animated:(BOOL)animated {
//    NSLog(@"changePage to %d (animated: %d)", pageIndex, animated);
	// update the scroll view to the appropriate page
    [self resizeScrollView];
    CGRect frame = self.scrollView.frame;
    frame.origin.x = frame.size.width * pageIndex;
    frame.origin.y = 0;

    self.scrollingToPage = pageIndex;
    [self.currentPage hideNoStoryMessage];
    [self.nextPage hideNoStoryMessage];
    [self.previousPage hideNoStoryMessage];
    
    // Check if already on the selected page
    if (self.scrollView.contentOffset.x == frame.origin.x) {
        [self applyNewIndex:pageIndex pageController:currentPage];
        [self setStoryFromScroll];
    } else {
        [self.scrollView scrollRectToVisible:frame animated:animated];
        if (!animated) {
            [self setStoryFromScroll];
        }
    }
    [self becomeFirstResponder];
}

- (void)changeToNextPage:(id)sender {
    NSInteger nextPageIndex = nextPage.pageIndex;
    if (nextPageIndex < 0 && currentPage.pageIndex < 0) {
        // just displaying a placeholder - display the first story instead
        [self changePage:0 animated:YES];
        return;
    }
    [self changePage:nextPageIndex animated:YES];
}

- (void)changeToPreviousPage:(id)sender {
    NSInteger previousPageIndex = previousPage.pageIndex;
    if (previousPageIndex < 0) {
        if (currentPage.pageIndex < 0)
            [self changeToNextPage:sender];
        return;
    }
    [self changePage:previousPageIndex animated:YES];
}

- (void)setStoryFromScroll {
    [self setStoryFromScroll:NO];
}

- (void)setStoryFromScroll:(BOOL)force {
    CGFloat pageWidth = self.view.bounds.size.width;
    float fractionalPage = self.scrollView.contentOffset.x / pageWidth;
	NSInteger nearestNumber = lround(fractionalPage);
    
    if (!force && currentPage.pageIndex >= 0 &&
        currentPage.pageIndex == nearestNumber &&
        currentPage.pageIndex != self.scrollingToPage) {
//        NSLog(@"Skipping setStoryFromScroll: currentPage is %d (%d, %d)", currentPage.pageIndex, nearestNumber, self.scrollingToPage);
        return;
    }
    
	if (currentPage.pageIndex < nearestNumber) {
//        NSLog(@"Swap next into current, current into previous: %d / %d", currentPage.pageIndex, nearestNumber);
		StoryDetailViewController *swapCurrentController = currentPage;
		StoryDetailViewController *swapPreviousController = previousPage;
		currentPage = nextPage;
		previousPage = swapCurrentController;
        nextPage = swapPreviousController;
	} else if (currentPage.pageIndex > nearestNumber) {
//        NSLog(@"Swap previous into current: %d / %d", currentPage.pageIndex, nearestNumber);
		StoryDetailViewController *swapCurrentController = currentPage;
		StoryDetailViewController *swapNextController = nextPage;
		currentPage = previousPage;
		nextPage = swapCurrentController;
        previousPage = swapNextController;
    }
    
//    NSLog(@"Set Story from scroll: %f = %d (%d/%d/%d)", fractionalPage, nearestNumber, previousPage.pageIndex, currentPage.pageIndex, nextPage.pageIndex);
    
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
        appDelegate.activeStory = [appDelegate.storiesCollection.activeFeedStories objectAtIndex:storyIndex];
        [self updatePageWithActiveStory:currentPage.pageIndex];
        if ([appDelegate.storiesCollection isStoryUnread:appDelegate.activeStory]) {
            [appDelegate.storiesCollection markStoryRead:appDelegate.activeStory];
            [appDelegate.storiesCollection syncStoryAsRead:appDelegate.activeStory];
        }
        [appDelegate.feedDetailViewController redrawUnreadStory];
    }

    [currentPage becomeFirstResponder];
}

- (void)advanceToNextUnread {
    if (!self.waitingForNextUnreadFromServer) {
        return;
    }
    
    self.waitingForNextUnreadFromServer = NO;
    [self doNextUnreadStory:nil];
}

- (void)updatePageWithActiveStory:(NSInteger)location {
    [appDelegate.storiesCollection pushReadStory:[appDelegate.activeStory objectForKey:@"story_hash"]];
    
//    [self.view setNeedsLayout];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:
                                                   originalStoryButton,
                                                   separatorBarButton,
                                                   fontSettingsButton, nil];
    }
    
    [self setNextPreviousButtons];
    EventWindow *tapDetectingWindow = (EventWindow*)appDelegate.window;
    tapDetectingWindow.tapDetectingView = currentPage.view;
    [appDelegate changeActiveFeedDetailRow];
    
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

- (void)setNextPreviousButtons {
    // setting up the PREV BUTTON
    NSInteger readStoryCount = [appDelegate.readStories count];
    if (readStoryCount == 0 ||
        (readStoryCount == 1 &&
         [appDelegate.readStories lastObject] == [appDelegate.activeStory objectForKey:@"story_hash"])) {
        [buttonPrevious setEnabled:NO];
    } else {
        [buttonPrevious setEnabled:YES];
    }
    
    [buttonPrevious setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"traverse_previous.png"]]
                              forState:UIControlStateNormal];
    
    // setting up the NEXT UNREAD STORY BUTTON
    buttonNext.enabled = YES;
    NSInteger nextIndex = [appDelegate.storiesCollection indexOfNextUnreadStory];
    NSInteger unreadCount = [appDelegate unreadCount];
    BOOL pageFinished = self.appDelegate.feedDetailViewController.pageFinished;
    if ((nextIndex == -1 && unreadCount > 0 && !pageFinished) ||
        nextIndex != -1) {
        [buttonNext setTitle:[@"Next" uppercaseString] forState:UIControlStateNormal];
        [buttonNext setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"traverse_next.png"]]
                              forState:UIControlStateNormal];
    } else {
        [buttonNext setTitle:[@"Done" uppercaseString] forState:UIControlStateNormal];
        [buttonNext setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"traverse_done.png"]]
                              forState:UIControlStateNormal];
    }
    
    float unreads = (float)[appDelegate unreadCount];
    float total = [appDelegate originalStoryCount];
    float progress = (total - unreads) / total;
    circularProgressView.percentage = progress;
}

- (void)setTextButton {
    [self setTextButton:currentPage];
}

- (void)setTextButton:(StoryDetailViewController *)storyViewController {
    if (storyViewController != currentPage) return;
    if (storyViewController.pageIndex >= 0) {
        [buttonText setEnabled:YES];
        [buttonText setAlpha:1];
        [buttonSend setEnabled:YES];
        [buttonSend setAlpha:1];
    } else {
        [buttonText setEnabled:NO];
        [buttonText setAlpha:.4];
        [buttonSend setEnabled:NO];
        [buttonSend setAlpha:.4];
    }
    
    [buttonSend setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"traverse_send.png"]]
                          forState:UIControlStateNormal];
    
    if (storyViewController.inTextView) {
        [buttonText setTitle:[@"Story" uppercaseString] forState:UIControlStateNormal];
        [buttonText setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"traverse_text_on.png"]]
                              forState:nil];
        self.buttonText.titleEdgeInsets = UIEdgeInsetsMake(0, 26, 0, 0);
    } else {
        [buttonText setTitle:[@"Text" uppercaseString] forState:UIControlStateNormal];
        [buttonText setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"traverse_text.png"]]
                              forState:nil];
        self.buttonText.titleEdgeInsets = UIEdgeInsetsMake(0, 22, 0, 0);
    }
}

- (IBAction)openSendToDialog:(id)sender {
    [self endTouchDown:sender];
    [appDelegate showSendTo:self sender:sender];
}

- (void)openStoryTrainerFromKeyboard:(id)sender {
    // don't have a tap target for the popover, but the settings button at least doesn't move
    [appDelegate openTrainStory:self.fontSettingsButton];
}

- (void)finishMarkAsSaved:(ASIFormDataRequest *)request {
    if ([request responseStatusCode] != 200) {
        return [self requestFailed:request];
    }
    
    [appDelegate.feedDetailViewController redrawUnreadStory];
    [self refreshHeaders];
    [self.currentPage flashCheckmarkHud:@"saved"];
}

- (BOOL)failedMarkAsSaved:(ASIFormDataRequest *)request {
    if (![[request.userInfo objectForKey:@"story_hash"]
          isEqualToString:[currentPage.activeStory objectForKey:@"story_hash"]]) {
        return NO;
    }

    [self informError:@"Failed to save story"];
    return YES;
}

- (void)finishMarkAsUnsaved:(ASIFormDataRequest *)request {
    if ([request responseStatusCode] != 200) {
        return [self requestFailed:request];
    }
    
    [appDelegate.storiesCollection markStory:[request.userInfo objectForKey:@"story"] asSaved:NO];
    [appDelegate.feedDetailViewController redrawUnreadStory];
    [self refreshHeaders];
    [self.currentPage flashCheckmarkHud:@"unsaved"];
}


- (BOOL)failedMarkAsUnsaved:(ASIFormDataRequest *)request {
    if (![[request.userInfo objectForKey:@"story_hash"]
          isEqualToString:[currentPage.activeStory objectForKey:@"story_hash"]]) {
        return NO;
    }
    
    [self informError:@"Failed to unsave story"];
    return YES;
}

- (BOOL)failedMarkAsUnread:(ASIFormDataRequest *)request {
    if (![[request.userInfo objectForKey:@"story_hash"]
          isEqualToString:[currentPage.activeStory objectForKey:@"story_hash"]]) {
        return NO;
    }
    
    [self informError:@"Failed to unread story"];
    return YES;
}

- (IBAction)showOriginalSubview:(id)sender {
    [appDelegate hidePopover];

    NSURL *url = [NSURL URLWithString:[appDelegate.activeStory
                                       objectForKey:@"story_permalink"]];
    [appDelegate showOriginalStory:url];
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
}

- (void)toggleStorySaved:(id)sender {
    [appDelegate.storiesCollection toggleStorySaved];
}

- (void)toggleStoryUnread:(id)sender {
    [appDelegate.storiesCollection toggleStoryUnread];
    [appDelegate.feedDetailViewController redrawUnreadStory]; // XXX only if successful?
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


- (IBAction)toggleFontSize:(id)sender {
    UINavigationController *fontSettingsNavigationController = self.appDelegate.fontSettingsNavigationController;

    [fontSettingsNavigationController popToRootViewControllerAnimated:NO];
    [self.appDelegate showPopoverWithViewController:fontSettingsNavigationController contentSize:CGSizeZero barButtonItem:self.fontSettingsButton];
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

- (void)drawStories {
    [self.currentPage drawStory];
    [self.nextPage drawStory];
    [self.previousPage drawStory];
}

- (void)backToDashboard:(id)sender {
    UINavigationController *feedDetailNavigationController = appDelegate.feedDetailViewController.navigationController;
    if (feedDetailNavigationController != nil)
        [feedDetailNavigationController popViewControllerAnimated: YES];
    [self transitionFromFeedDetail];
}

#pragma mark -
#pragma mark HUDs

- (void)showShareHUD:(NSString *)msg {
//    [MBProgressHUD hideHUDForView:self.view animated:NO];
    self.storyHUD = [MBProgressHUD showHUDAddedTo:currentPage.webView animated:YES];
    self.storyHUD.labelText = msg;
    self.storyHUD.margin = 20.0f;
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
#pragma mark Story Traversal

- (IBAction)doNextUnreadStory:(id)sender {
    FeedDetailViewController *fdvc = self.appDelegate.feedDetailViewController;
    NSInteger nextLocation = [appDelegate.storiesCollection locationOfNextUnreadStory];
    NSInteger unreadCount = [appDelegate unreadCount];
    BOOL pageFinished = self.appDelegate.feedDetailViewController.pageFinished;

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
        [appDelegate.navigationController
         popToViewController:[appDelegate.navigationController.viewControllers
                              objectAtIndex:0]
         animated:YES];
        [appDelegate hideStoryDetailView];
    } else {
        [self changePage:nextLocation];
    }
}

- (IBAction)doPreviousStory:(id)sender {
    [self endTouchDown:sender];
    [self.loadingIndicator stopAnimating];
    self.circularProgressView.hidden = NO;
    id previousStoryId = [appDelegate.storiesCollection popReadStory];
    if (!previousStoryId || previousStoryId == [appDelegate.activeStory objectForKey:@"story_hash"]) {
        [appDelegate.navigationController
         popToViewController:[appDelegate.navigationController.viewControllers
                              objectAtIndex:0]
         animated:YES];
        [appDelegate hideStoryDetailView];
    } else {
        NSInteger previousLocation = [appDelegate.storiesCollection locationOfStoryId:previousStoryId];
        if (previousLocation == -1) {
            return [self doPreviousStory:sender];
        }
//        [appDelegate setActiveStory:[[appDelegate activeFeedStories]
//                                     objectAtIndex:previousIndex]];
//        [appDelegate changeActiveFeedDetailRow];
//        
        [self changePage:previousLocation];
    }
}

@end
