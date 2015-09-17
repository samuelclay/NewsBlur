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
//#import "SloppySwiper.h"

@implementation OriginalStoryViewController

@synthesize appDelegate;
@synthesize webView;
//@synthesize swiper;
@synthesize progressView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [webView setNavigationDelegate:self];
        [webView setUIDelegate:self];
    }
    return self;
}

- (void)dealloc {
    [webView removeObserver:self forKeyPath:@"estimatedProgress"];
    
    // if you have set either WKWebView delegate also set these to nil here
    [webView setNavigationDelegate:nil];
    [webView setUIDelegate:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    appDelegate.originalStoryViewNavController.navigationBar.hidden = YES;
//    self.swiper = [[SloppySwiper alloc] initWithNavigationController:self.navigationController];
//    self.navigationController.delegate = self.swiper;

}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self.navigationController.navigationBar addSubview:progressView];
    [self resetProgressBar];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.alpha = 1;
    [progressView removeFromSuperview];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    if ([self.webView isLoading]) {
        [self.webView stopLoading];
    }
    activeUrl = nil;
    titleView.alpha = 1.0;
    if (![appDelegate.navigationController.viewControllers containsObject:self]) {
        [self.webView loadHTMLString:@"" baseURL:nil];
    }
    
    self.navigationController.delegate = appDelegate;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)resetProgressBar {
    if (finishedLoading) return;
    
    progressView.progressBarView.alpha = 0.0f;
    [progressView setProgress:0 animated:NO];
    [progressView setProgress:NJKInitialProgressValue animated:YES];
}

- (void)viewDidLoad {
//    self.navigationItem.title = [[appDelegate activeStory] objectForKey:@"story_title"];
    [super viewDidLoad];
    
    self.view.layer.masksToBounds = NO;
    self.view.layer.shadowRadius = 5;
    self.view.layer.shadowOpacity = 0.5;
    self.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.view.bounds].CGPath;

    UIImage *separatorImage = [UIImage imageNamed:@"bar-separator.png"];
    UIBarButtonItem *separatorBarButton = [UIBarButtonItem barItemWithImage:separatorImage
                                                                     target:nil
                                                                     action:nil];
    [separatorBarButton setEnabled:NO];
    
    UIBarButtonItem *sendToBarButton = [UIBarButtonItem
                                        barItemWithImage:[UIImage imageNamed:@"barbutton_sendto.png"]
                                        target:self
                                        action:@selector(doOpenActionSheet:)];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        closeButton = [UIBarButtonItem barItemWithImage:[UIImage imageNamed:@"ios7_back_button"]
                                                 target:self
                                                 action:@selector(closeOriginalView)];
        self.navigationItem.leftBarButtonItem = closeButton;
    }
    
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
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:NULL];

    CGFloat progressBarHeight = 2.f;
    CGRect navigaitonBarBounds = self.navigationController.navigationBar.bounds;
    CGRect barFrame = CGRectMake(0, navigaitonBarBounds.size.height - progressBarHeight, navigaitonBarBounds.size.width, progressBarHeight);
    progressView = [[NJKWebViewProgressView alloc] initWithFrame:barFrame];
    progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UIPanGestureRecognizer *gesture = [[UIPanGestureRecognizer alloc]
                                           initWithTarget:self action:@selector(handlePanGesture:)];
        gesture.delegate = self;
        [self.webView.scrollView addGestureRecognizer:gesture];
    }
    
    [self.webView loadHTMLString:@"" baseURL:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"] && object == self.webView) {
        NSLog(@"%f", webView.estimatedProgress);
        [progressView setProgress:webView.estimatedProgress animated:YES];
        
        if (webView.estimatedProgress == NJKInteractiveProgressValue) {
            // The web view has finished parsing the document,
            // but is still loading sub-resources
        }
        
        if (webView.estimatedProgress == NJKFinalProgressValue) {
            finishedLoading = YES;
        }
    }
    else {
        // Make sure to call the superclass's implementation in the else block in case it is also implementing KVO
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    CGPoint velocity = CGPointMake(0, 0);
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self.view];
    }
    if (self.webView.scrollView.contentOffset.x == 0 &&
        velocity.x > 0 && fabs(velocity.y) < 200) {
        return NO;
    }
    
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer{
    CGPoint velocity = CGPointMake(0, 0);
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self.view];
    }
    if (self.webView.scrollView.contentOffset.x == 0 &&
        velocity.x > 0 && fabs(velocity.y) < 200) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (self.webView.scrollView.contentOffset.x == 0 &&
        [gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    CGPoint velocity = CGPointMake(0, 0);
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self.view];
    }
    if (self.webView.scrollView.contentOffset.x == 0 &&
        velocity.x > 0 && fabs(velocity.y) < 200) {
        return YES;
    }
    return NO;
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)recognizer {
    CGFloat percentage = 1 - (self.view.frame.size.width - self.view.frame.origin.x) / self.view.frame.size.width;
    CGPoint center = self.view.center;
    CGPoint translation = [recognizer translationInView:self.view];
    
    if (self.webView.scrollView.contentOffset.x != 0) {
        return;
    }
    
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        center = CGPointMake(MAX(self.view.frame.size.width / 2, center.x + translation.x),
                             center.y);
        self.view.center = center;
        [recognizer setTranslation:CGPointZero inView:self.view];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [appDelegate.masterContainerViewController interactiveTransitionFromOriginalView:percentage];
        } else {
            
        }
    }
    
    if ([recognizer state] == UIGestureRecognizerStateEnded ||
        [recognizer state] == UIGestureRecognizerStateCancelled) {
        CGFloat velocity = [recognizer velocityInView:self.view].x;
        if ((percentage > 0.25 && velocity > 0) ||
            (percentage > 0.05 && velocity > 1000)) {
//            NSLog(@"Original velocity ESCAPED: %f (at %.2f%%)", velocity, percentage*100);
            [self transitionToFeedDetail:recognizer];
        } else {
//            NSLog(@"Original velocity: %f (at %.2f%%)", velocity, percentage*100);
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
    finishedLoading = NO;
    [self loadAddress:nil];
    
    titleView.text = [[[appDelegate activeStory] objectForKey:@"story_title"]
                      stringByDecodingHTMLEntities];
    [titleView sizeToFit];

    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.webView animated:YES];
    HUD.labelText = @"On its way...";
    [HUD hide:YES afterDelay:2];
    HUD.userInteractionEnabled = NO;
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
    finishedLoading = NO;

    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView
{
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateTitle:aWebView];
    finishedLoading = YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
//    if (error.code == 102 && [error.domain isEqual:@"WebKitErrorDomain"]) {    }

    // User clicking on another link before the page loads is OK.
    if ([error code] != NSURLErrorCancelled) {
        [self informError:error];   
    }
    finishedLoading = YES;
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
//    if ([urlString containsString:@"story_images"]) {
//        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
//        NSString *storyImagesDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"story_images"];
//
//        urlString = [urlString substringFromIndex:NSMaxRange([urlString
//                                                              rangeOfString:@"story_images/"])];
//        NSString *path = [storyImagesDirectory stringByAppendingPathComponent:urlString];
//        url = [NSURL fileURLWithPath:path];
//    }
    if (!url.scheme) {
        NSString* modifiedURLString = [NSString stringWithFormat:@"%@", urlString];
        url = [NSURL URLWithString:modifiedURLString];
    }
//    if ([self.webView isLoading]) {
//        [self.webView stopLoading];
//    }
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
    NSURL *url = [NSURL URLWithString:webView.URL.absoluteString];
    NSString *title = webView.title;
    
    [appDelegate showSendTo:self
                     sender:sender
                    withUrl:url
                 authorName:nil
                       text:nil
                      title:title
                  feedTitle:nil
                     images:nil];
}

- (void)closeOriginalView {
    [appDelegate closeOriginalStory];
}

@end
