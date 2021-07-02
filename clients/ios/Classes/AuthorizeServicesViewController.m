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
    }
    
    [self.appDelegate prepareWebView:self.webView completionHandler:^{
        NSString *urlAddress = [NSString stringWithFormat:@"%@%@", self.appDelegate.url, url];
        NSURL *fullUrl = [NSURL URLWithString:urlAddress];
        NSURLRequest *requestObj = [NSURLRequest requestWithURL:fullUrl];
        [self.webView loadRequest:requestObj];
    }];
    
    if (self.fromStory && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc]
                                         initWithTitle: @"Cancel"
                                         style: UIBarButtonItemStylePlain
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

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURLRequest *request = navigationAction.request;
    NSString *URLString = [[request URL] absoluteString];
    NSLog(@"URL STRING IS %@", URLString);
    
    // Look at the host & path to cope with http:// or https:// schemes
    if ([request.URL.host isEqualToString:self.appDelegate.host] && [request.URL.path isEqualToString:@"/"]) {
        [self.webView evaluateJavaScript:@"NEWSBLUR.error" completionHandler:^(id result, NSError *error) {
            NSString *errorString = result;
            
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
                if ([type isEqualToString:@"facebook"]) {
                    if (errorString.length) {
                        [self showError:errorString];
                    } else {
                        [appDelegate.firstTimeUserAddFriendsViewController selectFacebookButton];
                    }
                } else if ([type isEqualToString:@"twitter"]) {
                    if (errorString.length) {
                        [self showError:errorString];
                    } else {
                        [appDelegate.firstTimeUserAddFriendsViewController selectTwitterButton];
                    }
                }
            }
            
            decisionHandler(WKNavigationActionPolicyCancel);
        }];
        
        return;
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)showError:(NSString *)error {
    [appDelegate.firstTimeUserAddFriendsViewController changeMessaging:error];
}


@end
