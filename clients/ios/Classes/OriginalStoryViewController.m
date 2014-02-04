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

    appDelegate.originalStoryViewNavController.navigationBar.hidden = YES;
    [self.webView loadHTMLString:@"" baseURL:nil];
}

- (void)viewDidAppear:(BOOL)animated {
}

- (void)viewWillDisappear:(BOOL)animated {
    self.navigationController.navigationBar.alpha = 1;
}

- (void)viewDidDisappear:(BOOL)animated {
    if ([self.webView isLoading]) {
        [self.webView stopLoading];
    }
    activeUrl = nil;
    titleView.alpha = 1.0;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)viewDidLoad {    
//    self.navigationItem.title = [[appDelegate activeStory] objectForKey:@"story_title"];
    
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
    
    titleView = [[UILabel alloc] init];
    titleView.textColor = UIColorFromRGB(0x303030);
    titleView.font = [UIFont fontWithName:@"Helvetica-Bold" size:14.0];
    titleView.text = @"Loading...";
    [titleView sizeToFit];
    titleView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.navigationItem.titleView = titleView;
    
    self.navigationItem.rightBarButtonItems = @[sendToBarButton,
                                                separatorBarButton,
                                                backBarButton
                                                ];
    
    UIPanGestureRecognizer *gesture = [[UIPanGestureRecognizer alloc]
                                             initWithTarget:self action:@selector(handlePanGesture:)];
    [self.view addGestureRecognizer:gesture];
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)recognizer {
    CGFloat percentage = 1 - (recognizer.view.frame.size.width - recognizer.view.frame.origin.x) / recognizer.view.frame.size.width;
    CGPoint center = recognizer.view.center;
    CGPoint translation = [recognizer translationInView:recognizer.view];

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
        if ((percentage > 0.25 && velocity > 0) ||
            (percentage > 0.05 && velocity > 1000)) {
            NSLog(@"Original velocity ESCAPED: %f (at %.2f%%)", velocity, percentage*100);
            [self transitionToFeedDetail:recognizer];
        } else {
            NSLog(@"Original velocity: %f (at %.2f%%)", velocity, percentage*100);
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                [appDelegate.masterContainerViewController transitionToOriginalView:NO];
            } else {
                
            }
        }
    }
}

- (void)transitionToFeedDetail:(UIGestureRecognizer *)recognizer {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController transitionFromOriginalView];
    } else {
        
    }
}

- (void)loadInitialStory {
    [self loadAddress:nil];
    titleView.text = [[appDelegate activeStory] objectForKey:@"story_title"];
    [titleView sizeToFit];

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
    titleView.text = [pageTitleValue stringByDecodingHTMLEntities];
    [titleView sizeToFit];
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
    titleView.text = @"Loading...";
    [titleView sizeToFit];
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
