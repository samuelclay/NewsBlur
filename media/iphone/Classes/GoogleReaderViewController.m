//
//  GoogleReaderViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/15/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "GoogleReaderViewController.h"
#import "NewsBlurAppDelegate.h"

@implementation GoogleReaderViewController

@synthesize appDelegate;
@synthesize webView;

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
    [webView setDelegate:self];
    NSString *urlAddress = @"http://newsblur.com/import/authorize/";
    NSURL *url = [NSURL URLWithString:urlAddress];
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];

    [webView loadRequest:requestObj];
    
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [self setWebView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)dealloc {
    [webView release];
    [super dealloc];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString *URLString = [[request URL] absoluteString];
    NSLog(@"IN IT!@!!!");
    NSLog(@"%@", URLString);
    if ([URLString isEqualToString:@"http://www.newsblur.com/"]) {
         [self dismissModalViewControllerAnimated:YES];
         [appDelegate.firstTimeUserViewController addedGoogleReader];
         return NO;
    }

    return YES;
}

@end
