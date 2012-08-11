//
//  AuthorizeServicesViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 8/10/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "AuthorizeServicesViewController.h"
#import "NewsBlurAppDelegate.h"
#import "FirstTimeUserAddSitesViewController.h"
#import "FirstTimeUserAddFriendsViewController.h"

@implementation AuthorizeServicesViewController

@synthesize appDelegate;
@synthesize webView;
@synthesize url;
@synthesize type;

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
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    self.webView.delegate = self;
}

- (void)viewDidUnload {
    [self setWebView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    NSString *urlAddress = [NSString stringWithFormat:@"http://%@%@", NEWSBLUR_URL, url];
    NSURL *fullUrl = [NSURL URLWithString:urlAddress];
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:fullUrl];
    [self.webView loadRequest:requestObj];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString *URLString = [[request URL] absoluteString];
    NSLog(@"URL STRING IS %@", URLString);
    
    if ([URLString isEqualToString:[NSString stringWithFormat:@"http://%@/", NEWSBLUR_URL]]) {
        [self.navigationController popViewControllerAnimated:YES];
        if ([type isEqualToString:@"google"]) {
            [appDelegate.firstTimeUserAddSitesViewController importFromGoogleReader];
        } else if ([type isEqualToString:@"facebook"]) {
            [appDelegate.firstTimeUserAddFriendsViewController selectFacebookButton];
        } else if ([type isEqualToString:@"twitter"]) {
            [appDelegate.firstTimeUserAddFriendsViewController selectTwitterButton];
        }
        return NO;
    }
    
    return YES;
}


@end
