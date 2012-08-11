//
//  FTUXaddSitesViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "FirstTimeUserAddSitesViewController.h"
#import "FirstTimeUserAddFriendsViewController.h"
#import "AuthorizeServicesViewController.h"
#import "NewsBlurViewController.h"

@interface FirstTimeUserAddSitesViewController()

@property (readwrite) int importedFeedCount_;

@end;

@implementation FirstTimeUserAddSitesViewController

@synthesize appDelegate;
@synthesize googleReaderButton;
@synthesize nextButton;
@synthesize activityIndicator;
@synthesize instructionLabel;
@synthesize categories;
@synthesize importedFeedCount_;

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
    self.nextButton.enabled = NO;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"Step 2 of 4";
    self.activityIndicator.hidesWhenStopped = YES;
    
}

- (void)viewDidUnload
{

    [self setActivityIndicator:nil];
    [self setInstructionLabel:nil];
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

- (void)importFromGoogleReader {
    self.nextButton.enabled = YES;
    [self.googleReaderButton setTitle:@"Importing..." forState:UIControlStateNormal];
    self.googleReaderButton.userInteractionEnabled = NO;
    self.instructionLabel.text = @"This might take a minute.  Feel free to continue and we'll let you know when we finish importing";
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/import/import_from_google_reader/",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:@"true" forKey:@"auto_active"];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishImportFromGoogleReader:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)finishImportFromGoogleReader:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    NSLog(@"results are %@", results);
    
    self.importedFeedCount_ = [[results objectForKey:@"feed_count"] intValue];
    [self performSelector:@selector(updateSites) withObject:nil afterDelay:1];
}

- (void)updateSites {
    self.instructionLabel.text = @"And just like that, we're done!  Time to see what your friends are sharing.";
    [appDelegate.feedsViewController fetchFeedList:NO];
    NSString *msg = [NSString stringWithFormat:@"Imported %i site%@", 
                     self.importedFeedCount_,
                     self.importedFeedCount_ == 1 ? @"" : @"s"];
    [self.googleReaderButton setTitle:msg  forState:UIControlStateSelected];
    self.googleReaderButton.selected = YES;
    [self.activityIndicator stopAnimating];
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
