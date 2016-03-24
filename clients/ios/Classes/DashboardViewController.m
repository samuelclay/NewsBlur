//
//  DashboardViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/10/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "DashboardViewController.h"
#import "NewsBlurAppDelegate.h"
#import "ActivityModule.h"
#import "InteractionsModule.h"
#import "FeedDetailViewController.h"
#import "UserProfileViewController.h"
#import "TMCache.h"
#import "StoriesCollection.h"
#import "UISearchBar+Field.h"

#define FEEDBACK_URL @"http://www.newsblur.com/about"

@implementation DashboardViewController

@synthesize appDelegate;
@synthesize interactionsModule;
@synthesize activitiesModule;
@synthesize storiesModule;
@synthesize feedbackWebView;
@synthesize topToolbar;
@synthesize toolbar;
@synthesize segmentedButton;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.interactionsModule.hidden = YES;
    } else {
        self.interactionsModule.hidden = NO;
    }
    self.activitiesModule.hidden = YES;
    self.feedbackWebView.hidden = YES;
    self.feedbackWebView.delegate = self;
    self.segmentedButton.selectedSegmentIndex = 0;
    
    // preload feedback
    self.feedbackWebView.scalesPageToFit = YES;
    
    [self.segmentedButton
     setTitleTextAttributes:@{NSFontAttributeName:
                                  [UIFont fontWithName:@"Helvetica-Bold" size:11.0f]}
     forState:UIControlStateNormal];
    
    NSString *urlAddress = FEEDBACK_URL;
    //Create a URL object.
    NSURL *url = [NSURL URLWithString:urlAddress];
    //URL Requst Object
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
    //Load the request in the UIWebView.
    [self.feedbackWebView loadRequest:requestObj];
    
    CGRect topToolbarFrame = self.topToolbar.frame;
    topToolbarFrame.size.height += 20;
    self.topToolbar.frame = topToolbarFrame;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.storiesModule = [FeedDetailViewController new];
        self.storiesModule.isDashboardModule = YES;
        self.storiesModule.storiesCollection = [StoriesCollection new];
//        NSLog(@"Dashboard story module view: %@ (%@)", self.storiesModule, self.storiesModule.storiesCollection);
        self.storiesModule.view.frame = self.activitiesModule.frame;
        [self.view insertSubview:self.storiesModule.view belowSubview:self.activitiesModule];
        [self addChildViewController:self.storiesModule];
        [self.storiesModule didMoveToParentViewController:self];
    }
    
    [self updateLogo];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (IBAction)doLogout:(id)sender {
    [appDelegate confirmLogout];
}

- (void)updateLogo {
    if ([ThemeManager themeManager].isDarkTheme) {
        self.logoImageView.image = [UIImage imageNamed:@"logo_newsblur_blur-dark.png"];
    } else {
        self.logoImageView.image = [UIImage imageNamed:@"logo_newsblur_blur.png"];
    }
}

- (void)updateTheme {
    self.topToolbar.barTintColor = UIColorFromRGB(0xE3E6E0);
    self.toolbar.barTintColor = UIColorFromRGB(0xE3E6E0);
    self.segmentedButton.tintColor = UIColorFromRGB(0x8F918B);
    
    self.storiesModule.searchBar.backgroundColor = UIColorFromRGB(0xE3E6E0);
    self.storiesModule.searchBar.tintColor = UIColorFromRGB(0xffffff);
    self.storiesModule.searchBar.nb_searchField.textColor = UIColorFromRGB(0x0);
    
    self.storiesModule.storyTitlesTable.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    self.interactionsModule.interactionsTable.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    self.activitiesModule.activitiesTable.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    
    self.storiesModule.storyTitlesTable.separatorColor = UIColorFromRGB(0xE9E8E4);
    self.interactionsModule.interactionsTable.separatorColor = UIColorFromRGB(0xE9E8E4);
    self.activitiesModule.activitiesTable.separatorColor = UIColorFromRGB(0xE9E8E4);
    
    [self.storiesModule.storyTitlesTable reloadData];
    [self.interactionsModule.interactionsTable reloadData];
    [self.activitiesModule.activitiesTable reloadData];
    
    [self updateLogo];
}

# pragma mark
# pragma mark Navigation

- (IBAction)tapSegmentedButton:(id)sender {
    NSInteger selectedSegmentIndex = [self.segmentedButton selectedSegmentIndex];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (selectedSegmentIndex == 0) {
            self.storiesModule.view.hidden = NO;
            self.interactionsModule.hidden = YES;
            self.activitiesModule.hidden = YES;
        } else if (selectedSegmentIndex == 1) {
            [self refreshInteractions];
            self.storiesModule.view.hidden = YES;
            self.interactionsModule.hidden = NO;
            self.activitiesModule.hidden = YES;
        } else if (selectedSegmentIndex == 2) {
            [self refreshActivity];
            self.storiesModule.view.hidden = YES;
            self.interactionsModule.hidden = YES;
            self.activitiesModule.hidden = NO;
        }
    } else {
        if (selectedSegmentIndex == 0) {
            self.interactionsModule.hidden = NO;
            self.activitiesModule.hidden = YES;
        } else if (selectedSegmentIndex == 1) {
            self.interactionsModule.hidden = YES;
            self.activitiesModule.hidden = NO;
        }
    }
}

#pragma mark - Stories

- (void)refreshStories {
    [appDelegate.cachedStoryImages removeAllObjects:^(TMCache *cache) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [appDelegate loadRiverFeedDetailView:self.storiesModule withFolder:@"everything"];
            appDelegate.inFeedDetail = NO;
        });
    }];
}

# pragma mark
# pragma mark Interactions

- (void)refreshInteractions {
    appDelegate.userInteractionsArray = nil;
    [self.interactionsModule.interactionsTable reloadData];
    [self.interactionsModule.interactionsTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
    [self.interactionsModule fetchInteractionsDetail:1];
}

# pragma mark
# pragma mark Activities

- (void)refreshActivity {
    appDelegate.userActivitiesArray = nil;
    [self.activitiesModule.activitiesTable reloadData];
    [self.activitiesModule.activitiesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
    [self.activitiesModule fetchActivitiesDetail:1];    
}

# pragma mark
# pragma mark Feedback

- (BOOL)webView:(UIWebView *)webView 
shouldStartLoadWithRequest:(NSURLRequest *)request 
 navigationType:(UIWebViewNavigationType)navigationType {
    NSURL *url = [request URL];
    NSString *urlString = [NSString stringWithFormat:@"%@", url];

    if ([urlString isEqualToString: FEEDBACK_URL]){
        return YES;
    } else {
        return NO;
    }
}
@end