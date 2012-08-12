//
//  FTUXAddNewsBlurViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FirstTimeUserAddNewsBlurViewController.h"

@implementation FirstTimeUserAddNewsBlurViewController

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
@synthesize previousButton;
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
    
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Start Enjoying" style:UIBarButtonSystemItemDone target:self action:@selector(tapNextButton)];
    self.nextButton = next;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"Step 4 of 4";
    
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
    [self setPreviousButton:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [self rotateLogo];
}

- (void)viewDidAppear:(BOOL)animated {
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
        return YES;
    }
    
    return NO;
}


- (IBAction)tapNextButton {
    [appDelegate.ftuxNavigationController dismissModalViewControllerAnimated:YES];
}

- (IBAction)tapCategoryButton:(id)sender {

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
