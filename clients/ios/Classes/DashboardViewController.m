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
#import "UserProfileViewController.h"
#import "PINCache.h"
#import "StoriesCollection.h"
#import "UISearchBar+Field.h"
#import "NewsBlur-Swift.h"

@implementation DashboardViewController

@synthesize appDelegate;
@synthesize interactionsModule;
@synthesize activitiesModule;
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
    self.interactionsModule.hidden = NO;
    self.activitiesModule.hidden = YES;
    self.segmentedButton.selectedSegmentIndex = 0;
    
    [self.segmentedButton
     setTitleTextAttributes:@{NSFontAttributeName:
                                  [UIFont fontWithName:@"WhitneySSm-Medium" size:12.0f]}
     forState:UIControlStateNormal];
    
    CGRect topToolbarFrame = self.topToolbar.frame;
    topToolbarFrame.size.height += 20;
    self.topToolbar.frame = topToolbarFrame;
    
    [self updateTheme];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//	return YES;
//}

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
    
    self.interactionsModule.interactionsTable.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    self.activitiesModule.activitiesTable.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    
    self.interactionsModule.interactionsTable.separatorColor = UIColorFromRGB(0xE9E8E4);
    self.activitiesModule.activitiesTable.separatorColor = UIColorFromRGB(0xE9E8E4);
    
    [self.interactionsModule.interactionsTable reloadData];
    [self.activitiesModule.activitiesTable reloadData];
    
    [[ThemeManager themeManager] updateSegmentedControl:self.segmentedButton];
    
    [self updateLogo];
}

# pragma mark
# pragma mark Navigation

- (IBAction)tapSegmentedButton:(id)sender {
    NSInteger selectedSegmentIndex = [self.segmentedButton selectedSegmentIndex];
    
    if (selectedSegmentIndex == 0) {
        self.interactionsModule.hidden = NO;
        self.activitiesModule.hidden = YES;
    } else if (selectedSegmentIndex == 1) {
        self.interactionsModule.hidden = YES;
        self.activitiesModule.hidden = NO;
    }
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
