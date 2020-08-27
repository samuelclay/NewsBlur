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
#import "PINCache.h"
#import "StoriesCollection.h"
#import "UISearchBar+Field.h"

@implementation DashboardViewController

@synthesize appDelegate;
@synthesize interactionsModule;
@synthesize activitiesModule;
@synthesize storiesModule;
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
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.interactionsModule.hidden = YES;
    } else {
        self.interactionsModule.hidden = NO;
    }
    self.activitiesModule.hidden = YES;
    self.segmentedButton.selectedSegmentIndex = 0;
    
    [self.segmentedButton
     setTitleTextAttributes:@{NSFontAttributeName:
                                  [UIFont fontWithName:@"Helvetica-Bold" size:11.0f]}
     forState:UIControlStateNormal];
    
    CGRect topToolbarFrame = self.topToolbar.frame;
    topToolbarFrame.size.height += 20;
    self.topToolbar.frame = topToolbarFrame;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.storiesModule = [FeedDetailViewController new];
        self.storiesModule.isDashboardModule = YES;
        self.storiesModule.storiesCollection = [StoriesCollection new];
//        NSLog(@"Dashboard story module view: %@ (%@)", self.storiesModule, self.storiesModule.storiesCollection);
        self.storiesModule.view.frame = self.activitiesModule.frame;
        self.storiesModule.view.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view insertSubview:self.storiesModule.view belowSubview:self.activitiesModule];
        [self addChildViewController:self.storiesModule];
        [self.storiesModule didMoveToParentViewController:self];
        
        [NSLayoutConstraint constraintWithItem:self.storiesModule.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.topToolbar attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0].active = YES;
        [NSLayoutConstraint constraintWithItem:self.storiesModule.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0].active = YES;
        [NSLayoutConstraint constraintWithItem:self.storiesModule.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0].active = YES;
        [NSLayoutConstraint constraintWithItem:self.storiesModule.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.toolbar attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0].active = YES;
    }
    
    [self updateTheme];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        if (@available(iOS 11.0, *)) {
            CGRect frame = self.toolbar.frame;
            frame.size.height = [NewsBlurAppDelegate sharedAppDelegate].navigationController.toolbar.bounds.size.height; // += self.view.safeAreaInsets.bottom;
            self.toolbar.frame = frame;
        }
    }
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
    self.topToolbar.barTintColor = [UINavigationBar appearance].barTintColor;
    self.topToolbar.backgroundColor = [UINavigationBar appearance].backgroundColor;
    self.toolbar.barTintColor = [UINavigationBar appearance].barTintColor;
    self.segmentedButton.tintColor = [UINavigationBar appearance].tintColor;
    
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
    
    [[ThemeManager themeManager] updateSegmentedControl:self.segmentedButton];
    
    [self updateLogo];
}

# pragma mark
# pragma mark Navigation

- (IBAction)tapSegmentedButton:(id)sender {
    NSInteger selectedSegmentIndex = [self.segmentedButton selectedSegmentIndex];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
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
    [appDelegate.cachedStoryImages removeAllObjects:^(PINCache * _Nonnull cache) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.appDelegate loadRiverFeedDetailView:self.storiesModule withFolder:@"everything"];
            self.appDelegate.inFeedDetail = NO;
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

@end
