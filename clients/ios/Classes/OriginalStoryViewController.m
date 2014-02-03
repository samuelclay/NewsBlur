//
//  OriginalStoryViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/13/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "NBContainerViewController.h"
#import "OriginalStoryViewController.h"
#import "NSString+HTML.h"
#import "TransparentToolbar.h"
#import "MBProgressHUD.h"
#import "UIBarButtonItem+Image.h"
#import "NBBarButtonItem.h"

@implementation OriginalStoryViewController

@synthesize appDelegate;
@synthesize webView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"Original Story View: %@", [appDelegate activeOriginalStoryURL]);
    
    UIImage *separatorImage = [UIImage imageNamed:@"bar-separator.png"];
    UIBarButtonItem *separatorBarButton = [UIBarButtonItem barItemWithImage:separatorImage
                                                                     target:nil
                                                                     action:nil];
    [separatorBarButton setEnabled:NO];

    UIBarButtonItem *sendToBarButton = [UIBarButtonItem
                                        barItemWithImage:[UIImage imageNamed:@"barbutton_sendto.png"]
                                        target:self
                                        action:@selector(doOpenActionSheet:)];
    backBarButton = [UIBarButtonItem
                     barItemWithImage:[UIImage imageNamed:@"barbutton_back.png"]
                     target:self
                     action:@selector(webViewGoBack:)];
    backBarButton.enabled = NO;

    self.navigationItem.rightBarButtonItems = @[sendToBarButton,
                                                separatorBarButton,
                                                backBarButton
                                                ];


    appDelegate.originalStoryViewNavController.navigationBar.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
}

- (void)viewWillDisappear:(BOOL)animated {
    if (!appDelegate.masterContainerViewController.interactiveOriginalTransition) {
        [appDelegate.masterContainerViewController transitionFromOriginalView];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    if ([self.webView isLoading]) {
        [self.webView stopLoading];
    }
    activeUrl = nil;
    
    NSLog(@"Original disappear: %@ - %@", NSStringFromCGRect(self.view.frame), NSStringFromCGPoint(self.view.center));
    CGRect frame = self.view.frame;
    frame.origin.x = 0;
    self.view.frame = frame;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)viewDidLoad {    
//    self.navigationItem.title = [[appDelegate activeStory] objectForKey:@"story_title"];
    UIPanGestureRecognizer *gesture = [[UIPanGestureRecognizer alloc]
                                             initWithTarget:self action:@selector(handlePanGesture:)];
    [self.view addGestureRecognizer:gesture];
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)recognizer {
    CGFloat percentage = 1 - (recognizer.view.frame.size.width - recognizer.view.frame.origin.x) / recognizer.view.frame.size.width;
    CGPoint center = recognizer.view.center;
    CGPoint translation = [recognizer translationInView:recognizer.view];
    NSLog(@"Panning %f%%. (%@ - %@)", percentage, NSStringFromCGRect(recognizer.view.frame), NSStringFromCGPoint(translation));

    if (recognizer.state == UIGestureRecognizerStateChanged) {
        center = CGPointMake(MAX(recognizer.view.frame.size.width / 2, center.x + translation.x),
                             center.y);
        recognizer.view.center = center;
        [recognizer setTranslation:CGPointZero inView:recognizer.view];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [appDelegate.masterContainerViewController interactiveTransitionFromOriginalView:percentage];
        } else {
            
        }
    }
    
    if ([recognizer state] == UIGestureRecognizerStateEnded ||
        [recognizer state] == UIGestureRecognizerStateCancelled) {
        CGFloat velocity = [recognizer velocityInView:recognizer.view].x;
        if (velocity > 0) {
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                [appDelegate.masterContainerViewController transitionFromOriginalView];
            } else {
                
            }
        } else {
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                [appDelegate.masterContainerViewController transitionToOriginalView:NO];
            } else {
                
            }
        }
    }
}

- (void)loadInitialStory {
    [self loadAddress:nil];
    self.navigationItem.title = [[appDelegate activeStory] objectForKey:@"story_title"];
    
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.webView animated:YES];
    HUD.labelText = @"On its way...";
    [HUD hide:YES afterDelay:2];
}

- (IBAction)webViewGoBack:(id)sender {
    [webView goBack];
}

- (IBAction)webViewGoForward:(id)sender {
    [webView goForward];
}

- (IBAction)webViewRefresh:(id)sender {
    [webView reload];
}

# pragma mark: -
# pragma mark: UIWebViewDelegate protocol

- (BOOL)webView:(UIWebView *)aWebView
        shouldStartLoadWithRequest:(NSURLRequest *)request 
        navigationType:(UIWebViewNavigationType)navigationType {

    if ([aWebView canGoBack]) {
        [backBarButton setEnabled:YES];
    } else {
        [backBarButton setEnabled:NO];
    }
    
    if ([[[request URL] scheme] isEqual:@"mailto"]) {
        [[UIApplication sharedApplication] openURL:[request URL]];
        return NO;
    } else if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        activeUrl = [[request URL] absoluteString];
        [self loadAddress:nil];
        return NO;
    }
    
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)aWebView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView
{
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateTitle:aWebView];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    // User clicking on another link before the page loads is OK.
    if ([error code] != NSURLErrorCancelled) {
        [self informError:error];   
    }
}

- (void)updateTitle:(UIWebView*)aWebView
{
    NSString *pageTitleValue = [aWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
    self.navigationItem.title = [pageTitleValue stringByDecodingHTMLEntities];
}

- (IBAction)loadAddress:(id)sender {
    if (!activeUrl) {
        activeUrl = [appDelegate.activeOriginalStoryURL absoluteString];
    }
    NSString* urlString = activeUrl;
    NSURL* url = [NSURL URLWithString:urlString];
    
    if (!url.scheme) {
        NSString* modifiedURLString = [NSString stringWithFormat:@"%@", urlString];
        url = [NSURL URLWithString:modifiedURLString];
    }
    if ([self.webView isLoading]) {
        [self.webView stopLoading];
    }
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
    self.navigationItem.title = @"Loading...";
    
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (IBAction)doOpenActionSheet:(id)sender {
//    NSURL *url = [NSURL URLWithString:appDelegate.activeOriginalStoryURL];
    NSURL *url = [NSURL URLWithString:self.webView.request.URL.absoluteString];
    NSString *title = [[webView stringByEvaluatingJavaScriptFromString:@"document.title"]
                       stringByDecodingHTMLEntities];
    
    [appDelegate showSendTo:self
                     sender:sender
                    withUrl:url
                 authorName:nil
                       text:nil
                      title:title
                  feedTitle:nil
                     images:nil];
}

@end
