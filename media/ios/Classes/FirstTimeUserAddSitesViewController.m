//
//  FTUXaddSitesViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FirstTimeUserAddSitesViewController.h"
#import "FirstTimeUserAddFriendsViewController.h"
#import "AuthorizeServicesViewController.h"

@implementation FirstTimeUserAddSitesViewController

@synthesize appDelegate;
@synthesize googleReaderButton;
@synthesize nextButton;
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
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Next" style:UIBarButtonSystemItemDone target:self action:@selector(tapNextButton)];
    self.nextButton = next;
//    self.nextButton.enabled = NO;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"Step 2 of 4";
    
}

- (void)viewDidUnload
{

    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    [self setGoogleReaderButton:nil];
    [self setNextButton:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}


- (IBAction)tapNextButton {
    [appDelegate.ftuxNavigationController pushViewController:appDelegate.firstTimeUserAddFriendsViewController animated:YES];
}

- (IBAction)tapCategoryButton:(id)sender {
}

#pragma mark -
#pragma mark Import Google Reader

- (IBAction)tapGoogleReaderButton {
    AuthorizeServicesViewController *service = [[AuthorizeServicesViewController alloc] init];
    service.url = @"/import/authorize";
    service.type = @"google";
    [appDelegate.ftuxNavigationController pushViewController:service animated:YES];
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

@end
