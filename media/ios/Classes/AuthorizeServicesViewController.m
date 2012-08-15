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
    
    if ([type isEqualToString:@"google"]) {
        self.navigationItem.title = @"Google Reader";
    } else if ([type isEqualToString:@"facebook"]) {
        self.navigationItem.title = @"Facebook";
    } else if ([type isEqualToString:@"twitter"]) {
        self.navigationItem.title = @"Twitter";    
    }    
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
        
        
        NSString *error = [self.webView stringByEvaluatingJavaScriptFromString:@"NEWSBLUR.error"];
        
        [self.navigationController popViewControllerAnimated:YES];
        if ([type isEqualToString:@"google"]) {
            if (error.length) {
                [appDelegate.firstTimeUserAddSitesViewController importFromGoogleReaderFailed:error];
            } else {
                [appDelegate.firstTimeUserAddSitesViewController importFromGoogleReader];
            }

        } else if ([type isEqualToString:@"facebook"]) {
            if (error.length) {
                [self showError:error];
            } else {
                [appDelegate.firstTimeUserAddFriendsViewController selectFacebookButton];
            }
            
        } else if ([type isEqualToString:@"twitter"]) {
            if (error.length) {
                [self showError:error];
            } else {
                [appDelegate.firstTimeUserAddFriendsViewController selectTwitterButton];
            }
        }
        return NO;
    }
    
//    // for failed google reader authorization
//    if ([URLString hasPrefix:[NSString stringWithFormat:@"http://%@/import/callback", NEWSBLUR_URL]]) {
//        [self.navigationController popViewControllerAnimated:YES];
//        [appDelegate.firstTimeUserAddSitesViewController importFromGoogleReaderFailed];
//        return NO;
//    }

    
    return YES;
}

- (void)showError:(NSString *)error {
    [appDelegate.firstTimeUserAddFriendsViewController changeMessaging:error];
}


@end
