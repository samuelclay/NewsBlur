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
#import "Utilities.h"
#import "NSString+HTML.h"
#import "NBContainerViewController.h"
#import "DataUtilities.h"
#import "SBJson4.h"
#import "UIBarButtonItem+Image.h"
#import "THCircularProgressView.h"
#import "FMDatabase.h"
#import "StoriesCollection.h"

@interface StoryPageControl ()

@property (nonatomic, strong) NSTimer *autoscrollTimer;
@property (nonatomic, strong) NSTimer *autoscrollViewTimer;
@property (nonatomic, strong) NSString *restoringStoryId;

@end

@implementation StoryPageControl

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
@synthesize traverseBottomConstraint;
@synthesize scrollBottomConstraint;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
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
    [self.scrollView setAlwaysBounceHorizontal:self.isHorizontal];
    [self.scrollView setAlwaysBounceVertical:!self.isHorizontal];
    
    if (@available(iOS 11.0, *)) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
    }
    
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

    separatorBarButton2 = [UIBarButtonItem barItemWithImage:separatorImage
                                                                      target:nil
                                                                      action:nil];
    [separatorBarButton2 setEnabled:NO];
    separatorBarButton2.isAccessibilityElement = NO;
    
    UIImage *markReadImage = [UIImage imageNamed:@"markread.png"];
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
    
    // back button
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc]
                                   initWithTitle:@"All Sites"
                                   style:UIBarButtonItemStylePlain
                                   target:self
                                   action:@selector(transitionFromFeedDetail)];
    self.buttonBack = backButton;
    
    self.notifier = [[NBNotifier alloc] initWithTitle:@"Fetching text..."
                                           withOffset:CGPointMake(0.0, 0.0 /*self.bottomSize.frame.size.height*/)];
    [self.view addSubview:self.notifier];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:NOTIFIER_HEIGHT]];
    self.notifier.topOffsetConstraint = [NSLayoutConstraint constraintWithItem:self.notifier attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];
    [self.view addConstraint:self.notifier.topOffsetConstraint];
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
    
    [self updateAutoscrollButtons];
    [self updateTraverseBackground];
    [self setNextPreviousButtons];
    [self setTextButton];
    
    self.currentlyTogglingNavigationBar = NO;
    
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
            } else if (appDelegate.storiesCollection.isRiverView &&
                       [appDelegate.storiesCollection.activeFolder isEqualToString:@"infrequent"]) {
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
            if (!self.navigationItem.titleView) {
                self.navigationItem.titleView = titleImageViewWrapper;
            }
            titleImageView.hidden = NO;
        } else {
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                                   [appDelegate.storiesCollection.activeFeed objectForKey:@"id"]];
            UIImage *titleImage  = [appDelegate getFavicon:feedIdStr];
            titleImage = [Utilities roundCorneredImage:titleImage radius:6];
            
            UIImageView *titleImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
            UIImageView *titleImageViewWrapper = [[UIImageView alloc] init];
            titleImageView.frame = CGRectMake(0.0, 0.0, 28.0, 28.0);
            titleImageView.contentMode = UIViewContentModeScaleAspectFit;
            [titleImageView setImage:titleImage];
            [titleImageViewWrapper addSubview:titleImageView];
            [titleImageViewWrapper setFrame:titleImageView.frame];
            self.navigationItem.titleView = titleImageViewWrapper;
        }
    }
    
    self.autoscrollView.alpha = 0;
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
    if (appDelegate.isTryFeedView && !self.isPhoneOrCompact &&
        ![[appDelegate.storiesCollection.activeFeed objectForKey:@"username"] isKindOfClass:[NSNull class]] &&
        [appDelegate.storiesCollection.activeFeed objectForKey:@"username"]) {
        self.subscribeButton.title = [NSString stringWithFormat:@"Follow %@",
                                      [appDelegate.storiesCollection.activeFeed objectForKey:@"username"]];
        self.navigationItem.leftBarButtonItem = self.subscribeButton;
        //        self.subscribeButton.tintColor = UIColorFromRGB(0x0a6720);
    }
    appDelegate.isTryFeedView = NO;
    [self reorientPages];
//    [self applyNewIndex:previousPage.pageIndex pageController:previousPage];
    previousPage.view.hidden = NO;
//    [self showAutoscrollBriefly:YES];
    
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
    self.autoscrollActive = NO;
}

- (BOOL)becomeFirstResponder {
    // delegate to current page
    return [currentPage becomeFirstResponder];
}

- (void)transitionFromFeedDetail {
    if (appDelegate.masterContainerViewController.storyTitlesOnLeft) {
        [appDelegate.navigationController
         popToViewController:[appDelegate.navigationController.viewControllers
                              objectAtIndex:0]
         animated:YES];
        [appDelegate hideStoryDetailView];
    } else {
        [appDelegate.masterContainerViewController transitionFromFeedDetail];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    inRotation = YES;
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
//        NSLog(@"---> Story page control is re-orienting: %@ / %@", NSStringFromCGSize(self.scrollView.bounds.size), NSStringFromCGSize(size));
        UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
        _orientation = [UIApplication sharedApplication].statusBarOrientation;
        [self layoutForInterfaceOrientation:orientation];
        [self adjustDragBar:orientation];
        [self reorientPages];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
//        NSLog(@"---> Story page control did re-orient: %@ / %@", NSStringFromCGSize(self.scrollView.bounds.size), NSStringFromCGSize(size));
        inRotation = NO;

        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        
        // This causes the story to reload on rotation (or when going to the background), but doesn't seem necessary?
//        [self refreshPages];
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

- (BOOL)prefersStatusBarHidden {
    return self.navigationController.navigationBarHidden;
}

- (BOOL)wantNavigationBarHidden {
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    return ([preferences boolForKey:@"story_full_screen"] || self.autoscrollAvailable) && !self.forceNavigationBarShown;
}

- (void)setNavigationBarHidden:(BOOL)hide {
    [self setNavigationBarHidden:hide alsoTraverse:NO];
}

- (void)setNavigationBarHidden:(BOOL)hide alsoTraverse:(BOOL)alsoTraverse {
    if (self.navigationController == nil || self.navigationController.navigationBarHidden == hide || self.currentlyTogglingNavigationBar) {
        return;
    }
    
    self.currentlyTogglingNavigationBar = YES;
    
    [self.navigationController setNavigationBarHidden:hide animated:YES];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    BOOL swipeEnabled = [[userPreferences stringForKey:@"story_detail_swipe_left_edge"]
                         isEqualToString:@"pop_to_story_list"];;
    self.navigationController.interactivePopGestureRecognizer.enabled = swipeEnabled;
    
    if (hide) {
        self.navigationController.interactivePopGestureRecognizer.delegate = self;
    } else if (appDelegate.feedDetailViewController.standardInteractivePopGestureDelegate != nil) {
        self.navigationController.interactivePopGestureRecognizer.delegate = appDelegate.feedDetailViewController.standardInteractivePopGestureDelegate;
    }
    
    CGPoint oldOffset = currentPage.webView.scrollView.contentOffset;
    CGFloat navHeight = self.navigationController.navigationBar.bounds.size.height;
    CGFloat statusAdjustment = 20.0;
    
    if (@available(iOS 11.0, *)) {
        // The top inset is zero when the status bar is hidden, so using the bottom one to confirm.
        if (self.view.safeAreaInsets.top > 0.0 || self.view.safeAreaInsets.bottom > 0.0) {
            statusAdjustment = 0.0;
        }
    }
    
    if (oldOffset.y < 0.0) {
        oldOffset.y = 0.0;
    }
    
    CGFloat sign = hide ? -1.0 : 1.0;
    CGFloat absoluteAdjustment = navHeight + statusAdjustment;
    CGFloat totalAdjustment = sign * absoluteAdjustment;
    CGPoint newOffset = CGPointMake(oldOffset.x, oldOffset.y + totalAdjustment);
    BOOL singlePage = currentPage.isSinglePage;
    
    if (alsoTraverse) {
        self.traversePinned = YES;
        self.traverseFloating = NO;
        
        if (!hide) {
            int safeBottomMargin = 0;
            
            if (self.isPhoneOrCompact) {
                if (@available(iOS 11.0, *)) {
                    safeBottomMargin = -1 * self.view.safeAreaInsets.bottom/2;
                }
            }
            
            self.traverseBottomConstraint.constant = safeBottomMargin;
            [self.view layoutIfNeeded];
        }
    }
    
    [UIView animateWithDuration:0.2 animations:^{
        if (!self.isHorizontal) {
            [self reorientPages];
        }
        
        if (!singlePage) {
            currentPage.webView.scrollView.contentOffset = newOffset;
        }
        
        if (alsoTraverse) {
             [self.view layoutIfNeeded];
            self.traverseView.alpha = hide ? 0 : 1;
            
            if (hide) {
                [self hideAutoscrollImmediately];
            }
        }
    }];
    
    if (!hide) {
        [self resizeScrollView];
    }
    
    [UIView animateWithDuration:0.2 animations:^{
        [self setNeedsStatusBarAppearanceUpdate];
    } completion:^(BOOL finished) {
        self.currentlyTogglingNavigationBar = NO;
    }];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return ![otherGestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]];
}

- (void)adjustDragBar:(UIInterfaceOrientation)orientation {
//    CGRect scrollViewFrame = self.scrollView.frame;
//    CGRect traverseViewFrame = self.traverseView.frame;

    if (self.isPhoneOrCompact ||
        UIInterfaceOrientationIsLandscape(orientation)) {
//        scrollViewFrame.size.height = self.scrollView.bounds.size.height;
//        self.bottomSize.hidden = YES;
        [self.bottomSizeHeightConstraint setConstant:0];
        [self.scrollBottomConstraint setConstant:0];
        [bottomSize setHidden:YES];
    } else {
//        scrollViewFrame.size.height = self.scrollView.bounds.size.height - 12;
//        self.bottomSize.hidden = NO;
        [self.bottomSizeHeightConstraint setConstant:12];
        [self.scrollBottomConstraint setConstant:-12];
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

- (BOOL)isHorizontal {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"scroll_stories_horizontally"] boolValue];
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
        frame = self.scrollView.bounds;
    }
    
    if (self.isHorizontal) {
        frame.origin.x = frame.size.width * currentIndex;
        frame.origin.y = 0;
        
//        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
//            if (@available(iOS 11.0, *)) {
//                frame.origin.y -= self.view.safeAreaInsets.bottom;
//            }
//        }
    } else {
        frame.origin.x = 0;
        frame.origin.y = frame.size.height * currentIndex;
        
        if (@available(iOS 11.0, *)) {
            frame.origin.y -= self.view.safeAreaInsets.bottom;
        }
    }
    
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
    NSInteger storyCount = appDelegate.storiesCollection.storyLocationsCount;
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
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone || appDelegate.isCompactWidth;
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
    self.textStorySendBackgroundImageView.image = [[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"traverse_background.png"]];
    self.prevNextBackgroundImageView.image = [[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"traverse_background.png"]];
    self.dragBarImageView.image = [[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"drag_icon.png"]];
    self.bottomSize.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
}

- (void)updateTheme {
    [super updateTheme];
    
    [self updateAutoscrollButtons];
    [self updateTraverseBackground];
    [self setNextPreviousButtons];
    [self setTextButton];
    [self updateStoriesTheme];
}

// allow keyboard comands
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
        
        if (pageIndex < 0) {
            [appDelegate hideStoryDetailView];
//            [self doNextUnreadStory:nil];
        } else {
            [self changePage:pageIndex animated:NO];
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
	NSInteger pageCount = [[appDelegate.storiesCollection activeFeedStoryLocations] count];
	BOOL outOfBounds = newIndex >= pageCount || newIndex < 0;
    
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
    
//    NSInteger wasIndex = pageController.pageIndex;
	pageController.pageIndex = newIndex;
//    NSLog(@"Applied Index to %@: Was %ld, now %ld (%ld/%ld/%ld) [%lu stories - %d] %@", pageController, (long)wasIndex, (long)newIndex, (long)previousPage.pageIndex, (long)currentPage.pageIndex, (long)nextPage.pageIndex, (unsigned long)[appDelegate.storiesCollection.activeFeedStoryLocations count], outOfBounds, NSStringFromCGRect(self.scrollView.frame));
    
    if (newIndex > 0 && newIndex >= [appDelegate.storiesCollection.activeFeedStoryLocations count]) {
        pageController.pageIndex = -2;
        if (appDelegate.storiesCollection.feedPage < 100 &&
            !appDelegate.feedDetailViewController.pageFinished &&
            !appDelegate.feedDetailViewController.pageFetching) {
            [appDelegate.feedDetailViewController fetchNextPage:^() {
//                NSLog(@"Fetched next page, %@ stories", @([appDelegate.storiesCollection.activeFeedStoryLocations count]));
                [self applyNewIndex:newIndex pageController:pageController];
            }];
        } else if (!appDelegate.feedDetailViewController.pageFinished &&
                   !appDelegate.feedDetailViewController.pageFetching) {
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
//                    NSLog(@"Stale story, already drawn. Was: %@, Now: %@", originalStoryId, blockPageController.activeStoryId);
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
    CGSize size = self.scrollView.frame.size;
    CGPoint offset = self.scrollView.contentOffset;
    CGFloat pageAmount = self.isHorizontal ? size.width : size.height;
    float fractionalPage = (self.isHorizontal ? offset.x : offset.y) / pageAmount;
	
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
    
    [self showAutoscrollBriefly:YES];
    
    // Stick to bottom
    traversePinned = YES;
    
    if (!self.isPhoneOrCompact) {
        self.traverseBottomConstraint.constant = 0;
    } else if (@available(iOS 11.0, *)) {
        self.traverseBottomConstraint.constant = -1 * self.view.safeAreaInsets.bottom/2;
    } else {
        self.traverseBottomConstraint.constant = 0;
    }

    [UIView animateWithDuration:.24 delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self.traverseView setNeedsLayout];
//                         self.traverseView.frame = CGRectMake(tvf.origin.x,
//                                                              self.scrollView.bounds.size.height - tvf.size.height - bottomSizeHeightConstraint.constant - (self.view.safeAreaInsets.bottom - 20),
//                                                              tvf.size.width, tvf.size.height);
                         self.traverseView.alpha = 1;
                         self.traversePinned = YES;
                         [self.view layoutIfNeeded];
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
    CGSize size = self.scrollView.frame.size;
    CGPoint offset = self.scrollView.contentOffset;
    CGFloat pageAmount = self.isHorizontal ? size.width : size.height;
    float fractionalPage = (self.isHorizontal ? offset.x : offset.y) / pageAmount;
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
        CGSize size = self.scrollView.frame.size;
        CGPoint offset = self.scrollView.contentOffset;
        CGFloat pageAmount = self.isHorizontal ? size.width : size.height;
        float fractionalPage = (self.isHorizontal ? offset.x : offset.y) / pageAmount;
        NSInteger nearestNumber = lround(fractionalPage);
        
        if (![appDelegate.storiesCollection.activeFeedStories count]) return;
        
//        NSLog(@"observe content offset: fractional page %@", @(fractionalPage));  // log
        
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

- (void)changePage:(NSInteger)pageIndex {
    [self changePage:pageIndex animated:YES];
}

- (void)changePage:(NSInteger)pageIndex animated:(BOOL)animated {
//    NSLog(@"changePage to %@ (%@animated)", @(pageIndex), animated ? @"" : @"not ");
    
	// update the scroll view to the appropriate page
    [self resizeScrollView];
    CGRect frame = self.scrollView.frame;
    CGPoint offset = self.scrollView.contentOffset;
    
    if (self.isHorizontal) {
        frame.origin.x = frame.size.width * pageIndex;
        frame.origin.y = 0;
    } else {
        frame.origin.x = 0;
        frame.origin.y = frame.size.height * pageIndex;
        
        if (@available(iOS 11.0, *)) {
            frame.origin.y -= self.view.safeAreaInsets.bottom;
        }
    }

    self.scrollingToPage = pageIndex;
    [self.currentPage hideNoStoryMessage];
    [self.nextPage hideNoStoryMessage];
    [self.previousPage hideNoStoryMessage];
    
    // Check if already on the selected page
    if (self.isHorizontal ? offset.x == frame.origin.x : offset.y == frame.origin.y) {
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
    if (nextPage.pageIndex < 0 && currentPage.pageIndex < 0) {
        // just displaying a placeholder - display the first story instead
        [self changePage:0 animated:YES];
        return;
    }
    
    [self changePage:currentPage.pageIndex + 1 animated:YES];
}

- (void)changeToPreviousPage:(id)sender {
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
    CGSize size = self.scrollView.bounds.size;
    CGPoint offset = self.scrollView.contentOffset;
    CGFloat pageAmount = self.isHorizontal ? size.width : size.height;
    float fractionalPage = (self.isHorizontal ? offset.x : offset.y) / pageAmount;
	NSInteger nearestNumber = lround(fractionalPage);
    
//    NSLog(@"setStoryFromScroll: fractional page %@", @(fractionalPage));  // log
    
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
    
//    NSLog(@"Set Story from scroll: %@ = %@ (%@/%@/%@)", @(fractionalPage), @(nearestNumber), @(previousPage.pageIndex), @(currentPage.pageIndex), @(nextPage.pageIndex));
    
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
    
    NSInteger topPosition = currentPage.webView.scrollView.contentOffset.y;
    BOOL canHide = currentPage.canHideNavigationBar && topPosition >= 0;
    
    if (!canHide && self.isHorizontal && self.navigationController.navigationBarHidden) {
        [self setNavigationBarHidden:NO];
    }
    
    if (self.isDraggingScrollview || self.scrollingToPage == currentPage.pageIndex) {
        if (currentPage.pageIndex == -2) return;
        self.scrollingToPage = -1;
        NSInteger storyIndex = [appDelegate.storiesCollection indexFromLocation:currentPage.pageIndex];
        
        if (storyIndex < 0) {
            NSLog(@"invalid story index: %@ for page index: %@", @(storyIndex), @(currentPage.pageIndex));  // log
        }
        
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

- (void)updatePageWithActiveStory:(NSInteger)location {
    [appDelegate.storiesCollection pushReadStory:[appDelegate.activeStory objectForKey:@"story_hash"]];
    
//    [self.view setNeedsLayout];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (appDelegate.masterContainerViewController.storyTitlesOnLeft) {
            self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:
                                                       originalStoryButton,
                                                       separatorBarButton,
                                                       fontSettingsButton, nil];
        } else {
            self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:
                                                       originalStoryButton,
                                                       separatorBarButton,
                                                       fontSettingsButton,
                                                       separatorBarButton2,
                                                       markReadBarButton, nil];
        }
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

- (IBAction)markAllRead:(id)sender {
    [appDelegate.feedDetailViewController doOpenMarkReadMenu:markReadBarButton];
}

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
    
    NSString *previousName = self.isHorizontal ? @"traverse_previous.png" : @"traverse_previous_vert.png";
    NSString *previousNameOff = self.isHorizontal ? @"traverse_previous_off.png" : @"traverse_previous_off_vert.png";
    [buttonPrevious setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:previousName]]
                              forState:UIControlStateNormal];
    [buttonPrevious setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:previousNameOff]]
                              forState:UIControlStateDisabled];
    
    // setting up the NEXT UNREAD STORY BUTTON
    buttonNext.enabled = YES;
    NSInteger nextIndex = [appDelegate.storiesCollection indexOfNextUnreadStory];
    NSInteger unreadCount = [appDelegate unreadCount];
    BOOL pageFinished = appDelegate.feedDetailViewController.pageFinished;
    if ((nextIndex == -1 && unreadCount > 0 && !pageFinished) ||
        nextIndex != -1) {
        NSString *nextName = self.isHorizontal ? @"traverse_next.png" : @"traverse_next_vert.png";
        [buttonNext setTitle:[@"Next" uppercaseString] forState:UIControlStateNormal];
        [buttonNext setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:nextName]]
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
                              forState:0];
        self.buttonText.titleEdgeInsets = UIEdgeInsetsMake(0, 26, 0, 0);
    } else {
        [buttonText setTitle:[@"Text" uppercaseString] forState:UIControlStateNormal];
        [buttonText setBackgroundImage:[[ThemeManager themeManager] themedImage:[UIImage imageNamed:@"traverse_text.png"]]
                              forState:0];
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
    UINavigationController *fontSettingsNavigationController = appDelegate.fontSettingsNavigationController;

    [fontSettingsNavigationController popToRootViewControllerAnimated:NO];
    [appDelegate showPopoverWithViewController:fontSettingsNavigationController contentSize:CGSizeZero barButtonItem:self.fontSettingsButton];
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
    BOOL wantHidden = self.wantNavigationBarHidden;
    BOOL isHidden = self.navigationController.navigationBarHidden;
    
    if (self.currentPage.webView.scrollView.contentOffset.y > 10 || isHidden) {
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
}

- (void)updateStoriesTheme {
    [self.currentPage updateStoryTheme];
    [self.nextPage updateStoryTheme];
    [self.previousPage updateStoryTheme];
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
    UIWebView *webView = self.currentPage.webView;
    CGFloat position = webView.scrollView.contentOffset.y + 0.5;
    CGFloat maximum = webView.scrollView.contentSize.height - webView.frame.size.height;
    
    if (@available(iOS 11.0, *)) {
        maximum += self.view.safeAreaInsets.bottom;
    }
    
    if (position < maximum) {
        [webView.scrollView setContentOffset:CGPointMake(0, position) animated:NO];
    } else {
        self.autoscrollActive = NO;
    }
}

- (void)showAutoscrollBriefly:(BOOL)briefly {
    if (!self.autoscrollAvailable || self.currentPage.webView.scrollView.contentSize.height - 200 <= self.currentPage.view.frame.size.height) {
        [self hideAutoscrollWithAnimation];
        return;
    }
    
    if (self.autoscrollView.alpha == 0) {
        if (self.isPhoneOrCompact) {
            self.autoscrollBottomConstraint.constant = 50;
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
