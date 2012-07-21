//
//  FirstTimeUserViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FirstTimeUserViewController.h"
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"

#define WELCOME_BUTTON_TITLE @"LET'S GET STARTED"
#define ADD_SITES_SKIP_BUTTON_TITLE @"SKIP THIS STEP"
#define ADD_SITES_BUTTON_TITLE @"NEXT"
#define ADD_FRIENDS_BUTTON_TITLE @"SKIP THIS STEP"
#define ADD_NEWSBLUR_BUTTON_TITLE @"FINISH"

@implementation FirstTimeUserViewController

@synthesize appDelegate;
@synthesize googleReaderButton;
@synthesize welcomeView;
@synthesize addSitesView;
@synthesize addFriendsView;
@synthesize addNewsBlurView;
@synthesize toolbar;
@synthesize toolbarTitle;
@synthesize nextButton;
@synthesize logo;
@synthesize categories;

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
    categories = [[NSMutableArray alloc] init];
    currentStep = 0;
    importedGoogle = 0;
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [self setGoogleReaderButton:nil];
    [self setWelcomeView:nil];
    [self setAddSitesView:nil];
    [self setAddFriendsView:nil];
    [self setAddNewsBlurView:nil];
    [self setToolbar:nil];
    [self setToolbarTitle:nil];
    [self setNextButton:nil];
    [self setLogo:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [self rotateLogo];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}


- (IBAction)tapNextButton {
    currentStep++;
    if (currentStep == 1) {
        [toolbarTitle setTitle:@"Step 2 of 4" forState:normal];
        nextButton.title = ADD_SITES_SKIP_BUTTON_TITLE;
        self.addSitesView.frame = CGRectMake(768, 44, 768, 960);
        [self.view addSubview:addSitesView];
        [UIView animateWithDuration:0.35 
                         animations:^{
                            self.welcomeView.frame = CGRectMake(-768, 44, 768, 960);   
                            self.addSitesView.frame = CGRectMake(0, 44, 768, 960); 
                         }];
        
    } else if (currentStep == 2) {
        [self addCategories];
        [toolbarTitle setTitle:@"Step 3 of 4" forState:normal];

        nextButton.title = ADD_FRIENDS_BUTTON_TITLE;
        self.addFriendsView.frame = CGRectMake(768, 44, 768, 960);
        [self.view addSubview:addFriendsView];
        [UIView animateWithDuration:0.35 
                         animations:^{
                             self.addSitesView.frame = CGRectMake(-768, 44, 768, 960);   
                             self.addFriendsView.frame = CGRectMake(0, 44, 768, 960); 
                         }];
    } else if (currentStep == 3) {
        [toolbarTitle setTitle:@"Step 4 of 4" forState:normal];
        nextButton.title = ADD_NEWSBLUR_BUTTON_TITLE;
        self.addNewsBlurView.frame = CGRectMake(768, 44, 768, 960);
        [self.view addSubview:addNewsBlurView];
        [UIView animateWithDuration:0.35 
                         animations:^{
                             self.addFriendsView.frame = CGRectMake(-768, 44, 768, 960);   
                             self.addNewsBlurView.frame = CGRectMake(0, 44, 768, 960); 
                         }];
    } else if (currentStep == 4) {
        NSLog(@"Calling appDeletage reload feeds");
        [self dismissModalViewControllerAnimated:YES];
        [appDelegate reloadFeedsView:YES];
    }
}

- (IBAction)tapCategoryButton:(id)sender {
    UIButton *categoryButton = (UIButton *)sender;
    NSString *category = categoryButton.currentTitle;

    if (categoryButton.selected) {
        categoryButton.selected = NO;
        [categories removeObject:category];
    } else {
        [categories addObject: category];
        categoryButton.selected = YES;
    }
    
    if (categories.count || importedGoogle) {
        nextButton.title = ADD_SITES_BUTTON_TITLE;
    } else {
        nextButton.title = ADD_SITES_SKIP_BUTTON_TITLE;
    }
}

- (IBAction)tapNewsBlurButton:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.selected = YES;
    button.userInteractionEnabled = NO;
    [self addSite:@"http://blog.newsblur.com/"];
}

#pragma mark -
#pragma mark Import Google Reader

- (IBAction)tapGoogleReaderButton {
    [appDelegate showGoogleReaderAuthentication];
}

- (void)selectGoogleReaderButton {
    self.googleReaderButton.selected = YES;
    self.googleReaderButton.userInteractionEnabled = NO;
}

#pragma mark -
#pragma mark Add Categories

- (void)addCategories {
    
    // TO DO: curate the list of sites
    
    for (id key in categories) {
        // add folder 
        NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/add_folder",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setPostValue:key forKey:@"folder"]; 
        [request setDelegate:self];
        [request setDidFinishSelector:@selector(finishAddFolder:)];
        [request setDidFailSelector:@selector(requestFailed:)];
        [request startAsynchronous];
    }
    
}

- (void)finishAddFolder:(ASIHTTPRequest *)request {
    NSLog(@"Successfully added.");
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

#pragma mark -
#pragma mark Add Site

- (void)addSite:(NSString *)siteUrl {
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/add_url",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];

    [request setPostValue:siteUrl forKey:@"url"]; 
        
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishAddFolder:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)rotateLogo {
    // Setup the animation
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:(NSTimeInterval)60.0];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear];
    [UIView setAnimationBeginsFromCurrentState:YES];
    
    NSLog(@"%f", M_PI);
    
    // The transform matrix
    CGAffineTransform transform = CGAffineTransformMakeRotation(3.14);
    self.logo.transform = transform;
    
    // Commit the changes
    [UIView commitAnimations];
}

@end
