//
//  FTUXAddNewsBlurViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FirstTimeUserAddNewsBlurViewController.h"
#import "NewsBlurViewController.h"

@implementation FirstTimeUserAddNewsBlurViewController

@synthesize appDelegate;
@synthesize nextButton;
@synthesize instructionsLabel;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Start reading" style:UIBarButtonSystemItemDone target:self action:@selector(tapNextButton)];
    self.nextButton = next;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"All Done";
}

- (void)viewDidUnload
{
    [self setNextButton:nil];
    [self setInstructionsLabel:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationItem.rightBarButtonItem setStyle:UIBarButtonItemStyleDone];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self addSite:@"http://blog.newsblur.com/rss"];
    [self addPopular];
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
    [appDelegate.ftuxNavigationController dismissViewControllerAnimated:YES completion:nil];
        [appDelegate.feedsViewController fetchFeedList:NO];
}

- (IBAction)tapNewsBlurButton:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.selected = YES;
    button.userInteractionEnabled = NO;

    UIImage *checkmark = [UIImage imageNamed:@"258-checkmark"];
    UIImageView *checkmarkView = [[UIImageView alloc] initWithImage:checkmark];
    checkmarkView.frame = CGRectMake(button.frame.origin.x + button.frame.size.width - 24,
                                     button.frame.origin.y + 8,
                                     16,
                                     16);
    [self.view addSubview:checkmarkView];
    
    [self addSite:@"http://blog.newsblur.com/rss"];
}

- (IBAction)tapPopularButton:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.selected = YES;
    button.userInteractionEnabled = NO;
    
    UIImage *checkmark = [UIImage imageNamed:@"258-checkmark"];
    UIImageView *checkmarkView = [[UIImageView alloc] initWithImage:checkmark];
    checkmarkView.frame = CGRectMake(button.frame.origin.x + button.frame.size.width - 24,
                                     button.frame.origin.y + 8,
                                     16,
                                     16);
    [self.view addSubview:checkmarkView];
    [self addPopular];
}

#pragma mark -
#pragma mark Add Site

- (void)addPopular {
    NSString *urlString = [NSString stringWithFormat:@"%@/social/follow/",
                           self.appDelegate.url];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    [request setPostValue:@"social:popular" forKey:@"user_id"];     
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishAddSite:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)addSite:(NSString *)siteUrl {
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/add_url/",
                           self.appDelegate.url];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    [request setPostValue:siteUrl forKey:@"url"]; 
    [request setPostValue:@"true" forKey:@"auto_active"]; 
    [request setPostValue:@"true" forKey:@"skip_fetch"]; 
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishAddSite:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
    [appDelegate informError:error];
}

- (void)finishAddSite:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    NSLog(@"results are %@", results);
}

@end
