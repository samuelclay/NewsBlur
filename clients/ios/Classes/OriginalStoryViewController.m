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
#import "UIActivitiesControl.h"
#import "NBBarButtonItem.h"

@implementation OriginalStoryViewController

@synthesize appDelegate;
@synthesize closeButton;
@synthesize webView;
@synthesize back;
@synthesize forward;
@synthesize refresh;
@synthesize pageAction;
@synthesize pageTitle;
@synthesize pageUrl;
@synthesize toolbar;
@synthesize navBar;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
//    NSLog(@"Original Story View: %@", [appDelegate activeOriginalStoryURL]);
    appDelegate.originalStoryViewNavController.navigationBar.hidden = YES;

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:appDelegate.activeOriginalStoryURL] ;
    [self updateAddress:request];
    [self.pageTitle setText:[[appDelegate activeStory] objectForKey:@"story_title"]];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    [self layoutForInterfaceOrientation:orientation];
    
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.webView animated:YES];
    HUD.labelText = @"On its way...";
    [HUD hide:YES afterDelay:2];
}

- (void)viewDidAppear:(BOOL)animated {
    [self layoutNavBar];
}

- (void)viewWillDisappear:(BOOL)animated {
    if ([self.webView isLoading]) {
        [self.webView stopLoading];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self layoutForInterfaceOrientation:toInterfaceOrientation];
}

- (void)viewDidLoad {    
    CGRect labelFrame = CGRectMake(kMargin, kSpacer + 20,
                                   navBar.bounds.size.width - 2*kMargin,
                                   kLabelHeight);
    
    UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont systemFontOfSize:12];
    label.textColor = UIColorFromRGB(0x404040);
    label.shadowColor = UIColorFromRGB(0xFAFAFA);
    label.shadowOffset = CGSizeMake(0.0f, -1.0f);
    label.textAlignment = NSTextAlignmentCenter;
    label.text = [[appDelegate activeStory] objectForKey:@"story_title"];
    [navBar addSubview:label];
    self.pageTitle = label;
    
    UIBarButtonItem *close = [[UIBarButtonItem alloc]
                              initWithTitle:@"Close"
                              style:UIBarButtonItemStyleBordered
                              target:self
                              action:@selector(doCloseOriginalStoryViewController)];
    close.width = kButtonWidth;
    CGRect closeButtonFrame = CGRectMake(-20,
                                         kSpacer*2.0 + kLabelHeight - 7.0f + 20,
                                         kButtonWidth + kMargin,
                                         44.0);
    TransparentToolbar* tools = [[TransparentToolbar alloc]
                                 initWithFrame:closeButtonFrame];
    [tools setItems:[NSArray arrayWithObject:close] animated:NO];
    [tools setTintColor:UIColorFromRGB(0x183353)];
    [navBar addSubview:tools];
    
    CGRect addressFrame = CGRectMake(closeButtonFrame.origin.x +
                                     closeButtonFrame.size.width +
                                     kMargin,
                                     kSpacer*2.0 + kLabelHeight + 20,
                                     labelFrame.size.width
                                     - kButtonWidth - kMargin*2 + 20,
                                     kAddressHeight);
    UITextField *address = [[UITextField alloc] initWithFrame:addressFrame];
    address.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    address.borderStyle = UITextBorderStyleRoundedRect;
    address.font = [UIFont systemFontOfSize:14];
    address.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    address.adjustsFontSizeToFitWidth = NO;
    address.keyboardType = UIKeyboardTypeURL;
    address.autocapitalizationType = UITextAutocapitalizationTypeNone;
    address.clearButtonMode = UITextFieldViewModeWhileEditing;
    address.enablesReturnKeyAutomatically = YES;
    address.returnKeyType = UIReturnKeyGo;
    address.delegate = self;
    [navBar addSubview:address];
    self.pageUrl = address;

    UIImage *backImage = [UIImage imageNamed:@"barbutton_back.png"];
    NBBarButtonItem *backButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
    backButton.bounds = CGRectMake(0, 0, 44, 44);
    [backButton setImage:backImage forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(webViewGoBack:) forControlEvents:UIControlEventTouchUpInside];
    [back setCustomView:backButton];
    
    UIImage *forwardImage = [UIImage imageNamed:@"barbutton_forward.png"];
    NBBarButtonItem *forwardButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
    forwardButton.bounds = CGRectMake(0, 0, 44, 44);
    [forwardButton setImage:forwardImage forState:UIControlStateNormal];
    [forwardButton addTarget:self action:@selector(webViewGoForward:) forControlEvents:UIControlEventTouchUpInside];
    [forward setCustomView:forwardButton];
    
    UIImage *refreshImage = [UIImage imageNamed:@"barbutton_refresh.png"];
    NBBarButtonItem *refreshButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
    refreshButton.bounds = CGRectMake(0, 0, 44, 44);
    [refreshButton setImage:refreshImage forState:UIControlStateNormal];
    [refreshButton addTarget:self action:@selector(webViewRefresh:) forControlEvents:UIControlEventTouchUpInside];
    [refresh setCustomView:refreshButton];
    
    UIImage *sendtoImage = [UIImage imageNamed:@"barbutton_sendto.png"];
    NBBarButtonItem *sendtoButton = [NBBarButtonItem buttonWithType:UIButtonTypeCustom];
    sendtoButton.bounds = CGRectMake(0, 0, 44, 44);
    [sendtoButton setImage:sendtoImage forState:UIControlStateNormal];
    [sendtoButton addTarget:self action:@selector(doOpenActionSheet:) forControlEvents:UIControlEventTouchUpInside];
    [pageAction setCustomView:sendtoButton];
}

- (void)layoutNavBar {
    CGRect navBarFrame = self.view.bounds;
    navBarFrame.size.height = kNavBarHeight;
    navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    navBar.frame = navBarFrame;
    navBar.translucent = NO;
    toolbar.translucent = NO;
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

- (void) layoutForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    [self layoutNavBar];
    
    CGSize toolbarSize = [self.toolbar sizeThatFits:self.view.bounds.size];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.toolbar.frame = CGRectMake(-10.0f,
                                        CGRectGetHeight(self.view.bounds) - toolbarSize.height,
                                        toolbarSize.width + 20, toolbarSize.height);
    } else {
        self.toolbar.frame = (CGRect){CGPointMake(0.f, CGRectGetHeight(self.view.bounds) -
                                                  toolbarSize.height), toolbarSize};
        self.webView.frame = (CGRect){CGPointMake(0, kNavBarHeight), CGSizeMake(CGRectGetWidth(self.view.bounds), CGRectGetMinY(self.toolbar.frame) - kNavBarHeight)};
    }
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self loadAddress:nil];
    return YES;
}

- (IBAction)loadAddress:(id)sender {
    NSString* urlString = self.pageUrl.text;
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
    [self.pageUrl resignFirstResponder];
    [self.pageTitle setText:@"Loading..."];
}

# pragma mark: -
# pragma mark: UIWebViewDelegate protocol

- (BOOL)webView:(UIWebView *)webView 
        shouldStartLoadWithRequest:(NSURLRequest *)request 
        navigationType:(UIWebViewNavigationType)navigationType {


    if ([[[request URL] scheme] isEqual:@"mailto"]) {
        [[UIApplication sharedApplication] openURL:[request URL]];
        return NO;
    } else if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        [self updateAddress:request];
        return NO;
    }
    
    
    NSURL* mainUrl = [request mainDocumentURL];
    NSString* absoluteString = [mainUrl absoluteString];
    self.pageUrl.text = absoluteString;
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)aWebView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self updateButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView
{
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
    [self updateTitle:aWebView];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
    
    // User clicking on another link before the page loads is OK.
    if ([error code] != NSURLErrorCancelled) {
        [self informError:error];   
    }
}

- (void)updateTitle:(UIWebView*)aWebView
{
    NSString *pageTitleValue = [aWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
    self.pageTitle.text = [pageTitleValue stringByDecodingHTMLEntities];
}

- (void)updateAddress:(NSURLRequest*)request
{
    NSURL *url = [request URL];
    self.pageUrl.text = [url absoluteString];
    [self loadAddress:nil];
}

- (void)updateButtons
{
    self.forward.enabled = self.webView.canGoForward;
    self.back.enabled = self.webView.canGoBack;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


- (IBAction)doCloseOriginalStoryViewController {
//    NSLog(@"Close Original Story: %@", appDelegate);
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)doOpenActionSheet:(id)sender {
//    NSURL *url = [NSURL URLWithString:appDelegate.activeOriginalStoryURL];
    NSURL *url = [NSURL URLWithString:self.pageUrl.text];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController showSendToPopover:sender];
    } else {
        UIActivityViewController *shareSheet = [UIActivitiesControl activityViewControllerForView:self withUrl:url];
        [self presentViewController:shareSheet animated:YES completion:nil];
    }
}

@end
