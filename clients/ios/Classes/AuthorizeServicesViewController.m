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
#import "ShareViewController.h"

@implementation AuthorizeServicesViewController

@synthesize appDelegate;
@synthesize webView;
@synthesize url;
@synthesize type;
@synthesize fromStory;

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
    [super viewWillAppear:animated];
    
    if ([type isEqualToString:@"google"]) {
        self.navigationItem.title = @"Google Reader";
    } else if ([type isEqualToString:@"facebook"]) {
        self.navigationItem.title = @"Facebook";
    } else if ([type isEqualToString:@"twitter"]) {
        self.navigationItem.title = @"Twitter";
    } else if ([type isEqualToString:@"appdotnet"]) {
        self.navigationItem.title = @"App.net";
    }
    NSString *urlAddress = [NSString stringWithFormat:@"%@%@", self.appDelegate.url, url];
    NSURL *fullUrl = [NSURL URLWithString:urlAddress];
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:fullUrl];
    [self.webView loadRequest:requestObj];

    if (self.fromStory && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc]
                                         initWithTitle: @"Cancel"
                                         style: UIBarButtonSystemItemCancel
                                         target: self
                                         action: @selector(doCancelButton)];
        self.navigationItem.leftBarButtonItem = cancelButton;
        self.view.frame = CGRectMake(0, 0, 320, 416);
        self.preferredContentSize = self.view.frame.size;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)doCancelButton {
    [appDelegate.shareViewController adjustShareButtons];
    [appDelegate.modalNavigationController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString *URLString = [[request URL] absoluteString];
    NSLog(@"URL STRING IS %@", URLString);
    
    // Look at the host & path to cope with http:// or https:// schemes
    if ([request.URL.host isEqualToString:self.appDelegate.host] && [request.URL.path isEqualToString:@"/"]) {
        NSString *error = [self.webView stringByEvaluatingJavaScriptFromString:@"NEWSBLUR.error"];
        
        if (self.fromStory) {
            [appDelegate refreshUserProfile:^{
                if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                    [appDelegate.shareNavigationController viewWillAppear:YES];
                    [appDelegate.modalNavigationController dismissViewControllerAnimated:YES completion:nil];
                } else {
                    [self.navigationController popViewControllerAnimated:YES];
                }
            }];
        } else {
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
        }
        return NO;
    }
    
//    // for failed google reader authorization
//    if ([URLString hasPrefix:[NSString stringWithFormat:@"%@/import/callback", self.appDelegate.url]]) {
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
