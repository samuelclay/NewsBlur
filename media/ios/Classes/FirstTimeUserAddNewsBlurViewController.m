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
    
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Start Enjoying" style:UIBarButtonSystemItemDone target:self action:@selector(tapNextButton)];
    self.nextButton = next;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"All Done!";
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.instructionsLabel.font = [UIFont systemFontOfSize:13];
    }
    
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

- (IBAction)tapNewsBlurButton:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.selected = YES;
    button.userInteractionEnabled = NO;
    [self addSite:@"http://blog.newsblur.com/"];
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
    [request setDidFinishSelector:@selector(finishAddSite:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

- (void)finishAddSite:(ASIHTTPRequest *)request {
    NSLog(@"request: %@", request);
}

@end
