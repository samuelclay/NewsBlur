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
#import "JSON.h"
#import "SHK.h"

@implementation StoryPageControl

@synthesize appDelegate;
@synthesize currentPage, nextPage;
@synthesize progressView;
@synthesize progressViewContainer;
@synthesize toolbar;
@synthesize buttonPrevious;
@synthesize buttonNext;
@synthesize buttonAction;
@synthesize activity;
@synthesize buttonNextStory;
@synthesize fontSettingsButton;
@synthesize originalStoryButton;
@synthesize subscribeButton;
@synthesize buttonBack;
@synthesize bottomPlaceholderToolbar;
@synthesize popoverController;
@synthesize loadingIndicator;
@synthesize inTouchMove;
@synthesize isDraggingScrollview;
@synthesize storyHUD;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
	currentPage = [[StoryDetailViewController alloc] initWithNibName:@"StoryDetailViewController" bundle:nil];
	nextPage = [[StoryDetailViewController alloc] initWithNibName:@"StoryDetailViewController" bundle:nil];
    currentPage.appDelegate = appDelegate;
    nextPage.appDelegate = appDelegate;
    currentPage.view.frame = self.scrollView.frame;
    nextPage.view.frame = self.scrollView.frame;
	[self.scrollView addSubview:currentPage.view];
	[self.scrollView addSubview:nextPage.view];
    [self.scrollView setPagingEnabled:YES];
	[self.scrollView setScrollEnabled:YES];
	[self.scrollView setShowsHorizontalScrollIndicator:NO];
	[self.scrollView setShowsVerticalScrollIndicator:NO];
    
    popoverClass = [WEPopoverController class];

    // loading indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc]
                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.activity.customView = self.loadingIndicator;
    
    // adding HUD for progress bar
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapProgressBar:)];
    
    [self.progressViewContainer addGestureRecognizer:tap];
    self.progressViewContainer.hidden = YES;
    
    
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
                                   initWithTitle:@"All Sites" style:UIBarButtonItemStyleBordered target:self action:@selector(transitionFromFeedDetail)];
    self.buttonBack = backButton;
    
    
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
    
    [self.scrollView addObserver:self forKeyPath:@"contentOffset"
                         options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         context:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [self setNextPreviousButtons];
    [appDelegate adjustStoryDetailWebView];
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

- (void)viewDidDisappear:(BOOL)animated {
    [self.currentPage hideStory];
    [self.nextPage hideStory];
}

- (void)transitionFromFeedDetail {
    [self performSelector:@selector(resetPages) withObject:self afterDelay:0.5];
    [appDelegate.masterContainerViewController transitionFromFeedDetail];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self resizeScrollView];
    [appDelegate adjustStoryDetailWebView];
    int pageIndex = currentPage.pageIndex;
    currentPage.pageIndex = -1;
    nextPage.pageIndex = -1;
    [self changePage:pageIndex animated:NO];
//    self.scrollView.contentOffset = CGPointMake(self.scrollView.frame.size.width * currentPage.pageIndex, 0);
}

- (void)resetPages {
    [currentPage clearStory];
    [nextPage clearStory];

    [currentPage hideStory];
    [nextPage hideStory];

    currentPage.pageIndex = -1;
    nextPage.pageIndex = -1;
    
    self.scrollView.contentOffset = CGPointMake(0, 0);
}

- (void)resizeScrollView {
    NSInteger widthCount = self.appDelegate.storyCount;
	if (widthCount == 0) {
		widthCount = 1;
	}
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width
                                             * widthCount,
                                             self.scrollView.frame.size.height);
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

#pragma mark -
#pragma mark Side scroll view

- (void)applyNewIndex:(NSInteger)newIndex pageController:(StoryDetailViewController *)pageController
{
	NSInteger pageCount = [[appDelegate activeFeedStoryLocations] count];
	BOOL outOfBounds = newIndex >= pageCount || newIndex < 0;
    
	if (!outOfBounds) {
		CGRect pageFrame = pageController.view.frame;
		pageFrame.origin.y = 0;
		pageFrame.origin.x = self.scrollView.frame.size.width * newIndex;
		pageController.view.frame = pageFrame;
	} else {
		CGRect pageFrame = pageController.view.frame;
		pageFrame.origin.y = self.scrollView.frame.size.height / 2;
		pageController.view.frame = pageFrame;
	}
    
	pageController.pageIndex = newIndex;
    
    if (newIndex >= [appDelegate.activeFeedStoryLocations count]) {
        if (self.appDelegate.feedDetailViewController.feedPage < 50 &&
            !self.appDelegate.feedDetailViewController.pageFinished &&
            !self.appDelegate.feedDetailViewController.pageFetching) {
            [self.appDelegate.feedDetailViewController fetchNextPage:^() {
                [self applyNewIndex:newIndex pageController:pageController];
            }];
        } else {
            
//            [appDelegate.navigationController
//             popToViewController:[appDelegate.navigationController.viewControllers
//                                  objectAtIndex:0]
//             animated:YES];
//            [appDelegate hideStoryDetailView];
        }
    } else {
        int location = [appDelegate indexFromLocation:pageController.pageIndex];
        [pageController setActiveStoryAtIndex:location];
        [pageController initStory];
        [pageController drawStory];
    }
    
    [self resizeScrollView];
    [self.loadingIndicator stopAnimating];
}

- (void)scrollViewDidScroll:(UIScrollView *)sender
{
    [sender setContentOffset:CGPointMake(sender.contentOffset.x, 0)];
    CGFloat pageWidth = self.scrollView.frame.size.width;
    float fractionalPage = self.scrollView.contentOffset.x / pageWidth;
	
	NSInteger lowerNumber = floor(fractionalPage);
	NSInteger upperNumber = lowerNumber + 1;
	
	if (lowerNumber == currentPage.pageIndex)
	{
		if (upperNumber != nextPage.pageIndex)
		{
			[self applyNewIndex:upperNumber pageController:nextPage];
		}
	}
	else if (upperNumber == currentPage.pageIndex)
	{
		if (lowerNumber != nextPage.pageIndex)
		{
			[self applyNewIndex:lowerNumber pageController:nextPage];
		}
	}
	else
	{
		if (lowerNumber == nextPage.pageIndex)
		{
			[self applyNewIndex:upperNumber pageController:currentPage];
		}
		else if (upperNumber == nextPage.pageIndex)
		{
			[self applyNewIndex:lowerNumber pageController:currentPage];
		}
		else
		{
			[self applyNewIndex:lowerNumber pageController:currentPage];
			[self applyNewIndex:upperNumber pageController:nextPage];
		}
	}
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.isDraggingScrollview = YES;
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)newScrollView
{
    self.isDraggingScrollview = NO;
    [self setStoryFromScroll];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (keyPath == @"contentOffset" && self.isDraggingScrollview) {
        CGFloat pageWidth = self.scrollView.frame.size.width;
        float fractionalPage = self.scrollView.contentOffset.x / pageWidth;
        NSInteger nearestNumber = lround(fractionalPage);
        
        int storyIndex = [appDelegate indexFromLocation:nearestNumber];
        appDelegate.activeStory = [appDelegate.activeFeedStories objectAtIndex:storyIndex];
        [appDelegate changeActiveFeedDetailRow];
    }
}


- (void)scrollViewDidEndDecelerating:(UIScrollView *)newScrollView
{
	[self scrollViewDidEndScrollingAnimation:newScrollView];
}

- (void)changePage:(NSInteger)pageIndex {
    [self changePage:pageIndex animated:YES];
}

- (void)changePage:(NSInteger)pageIndex animated:(BOOL)animated {
	// update the scroll view to the appropriate page
    [self resizeScrollView];

    CGRect frame = self.scrollView.frame;
    frame.origin.x = frame.size.width * pageIndex;
    frame.origin.y = 0;

    if (self.scrollView.contentOffset.x == frame.origin.x) {
        [self applyNewIndex:pageIndex pageController:currentPage];
        [self setStoryFromScroll];
    } else {
        [self.scrollView scrollRectToVisible:frame animated:animated];
        if (!animated) {
            [self setStoryFromScroll];
        }
    }
}

- (void)setStoryFromScroll {
    CGFloat pageWidth = self.scrollView.frame.size.width;
    float fractionalPage = self.scrollView.contentOffset.x / pageWidth;
	NSInteger nearestNumber = lround(fractionalPage);
    
	if (currentPage.pageIndex != nearestNumber)
	{
		StoryDetailViewController *swapController = currentPage;
		currentPage = nextPage;
		nextPage = swapController;
	}
    
    if (currentPage.pageIndex == -1) return;
    
    int storyIndex = [appDelegate indexFromLocation:currentPage.pageIndex];
    appDelegate.activeStory = [appDelegate.activeFeedStories objectAtIndex:storyIndex];
    [self updatePageWithActiveStory:currentPage.pageIndex];
}

- (void)updatePageWithActiveStory:(int)location {
    [self markStoryAsRead];
    [appDelegate pushReadStory:[appDelegate.activeStory objectForKey:@"id"]];
    
    self.bottomPlaceholderToolbar.hidden = YES;
    self.progressViewContainer.hidden = NO;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects: originalStoryButton, fontSettingsButton, nil];
    }
    
    [self setNextPreviousButtons];
    [appDelegate changeActiveFeedDetailRow];
    
    
    if (self.currentPage.pageIndex != location) {
        [self applyNewIndex:location pageController:self.currentPage];
    }
    if (self.nextPage.pageIndex != location+1) {
        [self applyNewIndex:location+1 pageController:self.nextPage];
    }
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSLog(@"Error in story detail: %@", [request error]);
    NSString *error;
    if ([request error]) {
        error = [NSString stringWithFormat:@"%@", [request error]];
    } else {
        error = @"The server barfed!";
    }
    [self informError:error];
}

#pragma mark -
#pragma mark Actions

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
    buttonNext.enabled = YES;
    
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
        [request setDidFailSelector:@selector(requestFailed:)];
        [request setDelegate:self];
        [request startAsynchronous];
    }
}


- (void)finishMarkAsRead:(ASIHTTPRequest *)request {
    //    NSString *responseString = [request responseString];
    //    NSDictionary *results = [[NSDictionary alloc]
    //                             initWithDictionary:[responseString JSONValue]];
    //    NSLog(@"results in mark as read is %@", results);
}

- (void)openSendToDialog {
    NSURL *url = [NSURL URLWithString:[appDelegate.activeStory
                                       objectForKey:@"story_permalink"]];
    SHKItem *item = [SHKItem URL:url title:[appDelegate.activeStory
                                            objectForKey:@"story_title"]];
    SHKActionSheet *actionSheet = [SHKActionSheet actionSheetForItem:item];
    [actionSheet showInView:self.view];
}

- (void)markStoryAsSaved {
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/mark_story_as_starred",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    [request setPostValue:[appDelegate.activeStory
                           objectForKey:@"id"]
                   forKey:@"story_id"];
    [request setPostValue:[appDelegate.activeStory
                           objectForKey:@"story_feed_id"]
                   forKey:@"feed_id"];
    
    [request setDidFinishSelector:@selector(finishMarkAsSaved:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)finishMarkAsSaved:(ASIHTTPRequest *)request {
    if ([request responseStatusCode] != 200) {
        return [self requestFailed:request];
    }
    
    [appDelegate markActiveStorySaved:YES];
    [self informMessage:@"This story is now saved"];
}

- (void)markStoryAsUnsaved {
    //    [appDelegate markActiveStoryUnread];
    
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/mark_story_as_unstarred",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    [request setPostValue:[appDelegate.activeStory
                           objectForKey:@"id"]
                   forKey:@"story_id"];
    [request setPostValue:[appDelegate.activeStory
                           objectForKey:@"story_feed_id"]
                   forKey:@"feed_id"];
    
    [request setDidFinishSelector:@selector(finishMarkAsUnsaved:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)finishMarkAsUnsaved:(ASIHTTPRequest *)request {
    if ([request responseStatusCode] != 200) {
        return [self requestFailed:request];
    }
    
    //    [appDelegate markActiveStoryUnread];
    //    [appDelegate.feedDetailViewController redrawUnreadStory];
    
    [appDelegate markActiveStorySaved:NO];
    [self informMessage:@"This story is no longer saved"];
}

- (void)markStoryAsUnread {
    if ([[appDelegate.activeStory objectForKey:@"read_status"] intValue] == 1) {
        NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/mark_story_as_unread",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        
        [request setPostValue:[appDelegate.activeStory
                               objectForKey:@"id"]
                       forKey:@"story_id"];
        [request setPostValue:[appDelegate.activeStory
                               objectForKey:@"story_feed_id"]
                       forKey:@"feed_id"];
        
        [request setDidFinishSelector:@selector(finishMarkAsUnread:)];
        [request setDidFailSelector:@selector(requestFailed:)];
        [request setDelegate:self];
        [request startAsynchronous];
    }
}

- (void)finishMarkAsUnread:(ASIHTTPRequest *)request {
    if ([request responseStatusCode] != 200) {
        return [self requestFailed:request];
    }
    
    [appDelegate markActiveStoryUnread];
    [appDelegate.feedDetailViewController redrawUnreadStory];
    
    [self informMessage:@"This story is now unread"];
}

- (IBAction)showOriginalSubview:(id)sender {
    NSURL *url = [NSURL URLWithString:[appDelegate.activeStory
                                       objectForKey:@"story_permalink"]];
    [appDelegate showOriginalStory:url];
}

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


#pragma mark -
#pragma mark Styles


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
        [self.popoverController setPopoverContentSize:CGSizeMake(240, 154)];
        [self.popoverController presentPopoverFromBarButtonItem:self.fontSettingsButton
                                       permittedArrowDirections:UIPopoverArrowDirectionAny
                                                       animated:YES];
    }
}

- (void)setFontStyle:(NSString *)fontStyle {
    [self.currentPage setFontStyle:fontStyle];
    [self.nextPage setFontStyle:fontStyle];
}

- (void)changeFontSize:(NSString *)fontSize {
    [self.currentPage changeFontSize:fontSize];
    [self.nextPage changeFontSize:fontSize];
}

- (void)showShareHUD:(NSString *)msg {
//    [MBProgressHUD hideHUDForView:self.view animated:NO];
    self.storyHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.storyHUD.labelText = msg;
    self.storyHUD.margin = 20.0f;
    self.currentPage.noStorySelectedLabel.hidden = YES;
    self.nextPage.noStorySelectedLabel.hidden = YES;
}

#pragma mark -
#pragma mark Story Traversal

- (IBAction)doNextUnreadStory {
    FeedDetailViewController *fdvc = self.appDelegate.feedDetailViewController;
    int nextLocation = [appDelegate locationOfNextUnreadStory];
    int unreadCount = [appDelegate unreadCount];
    [self.loadingIndicator stopAnimating];
    
    if (nextLocation == -1 && unreadCount > 0 &&
        fdvc.feedPage < 50) {
        [self.loadingIndicator startAnimating];
        self.activity.customView = self.loadingIndicator;
        self.buttonNext.enabled = NO;
        // Fetch next page and see if it has the unreads.
        [fdvc fetchNextPage:^() {
            [self doNextUnreadStory];
        }];
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

- (IBAction)doNextStory {
    
    int nextLocation = [appDelegate locationOfNextStory];
    
    [self.loadingIndicator stopAnimating];
    
    if (self.appDelegate.feedDetailViewController.pageFetching) {
        return;
    }
    
    if (nextLocation == -1 &&
        self.appDelegate.feedDetailViewController.feedPage < 50 &&
        !self.appDelegate.feedDetailViewController.pageFinished &&
        !self.appDelegate.feedDetailViewController.pageFetching) {
        
        // Fetch next page and see if it has the unreads.
        [self.loadingIndicator startAnimating];
        self.activity.customView = self.loadingIndicator;
        [self.appDelegate.feedDetailViewController fetchNextPage:^() {
            [self doNextStory];
        }];
    } else if (nextLocation == -1) {
        [MBProgressHUD hideHUDForView:self.view animated:NO];
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeText;
        hud.removeFromSuperViewOnHide = YES;
        hud.labelText = @"No stories left";
        [hud hide:YES afterDelay:0.8];
    } else {
//        [appDelegate setActiveStory:[[appDelegate activeFeedStories]
//                                     objectAtIndex:nextLocation]];
//        [appDelegate pushReadStory:[appDelegate.activeStory objectForKey:@"id"]];
//        
//        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
//            [appDelegate changeActiveFeedDetailRow];
//        }
        [self changePage:nextLocation];
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
        int previousLocation = [appDelegate locationOfStoryId:previousStoryId];
        if (previousLocation == -1) {
            return [self doPreviousStory];
        }
//        [appDelegate setActiveStory:[[appDelegate activeFeedStories]
//                                     objectAtIndex:previousIndex]];
//        [appDelegate changeActiveFeedDetailRow];
//        
        [self changePage:previousLocation];
    }
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
