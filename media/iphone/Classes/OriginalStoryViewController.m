//
//  OriginalStoryViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/13/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "OriginalStoryViewController.h"
#import "NSString+HTML.h"
#import "TransparentToolbar.h"

#define UIColorFromRGB(rgbValue) [UIColor \
colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0xFF00) >> 8))/255.0 \
blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

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

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
//    NSLog(@"Original Story View: %@", [appDelegate activeOriginalStoryURL]);
    [appDelegate showNavigationBar:NO];
    toolbar.tintColor = UIColorFromRGB(0x183353);
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:appDelegate.activeOriginalStoryURL] ;
    [self updateAddress:request];
    [self.pageTitle setText:[[appDelegate activeStory] objectForKey:@"story_title"]];
    [request release];
}

- (void)viewWillDisappear:(BOOL)animated {
    if ([self.webView isLoading]) {
        [self.webView stopLoading];
    }
}

- (void)viewDidLoad {
    
    CGRect navBarFrame = self.view.bounds;
    navBarFrame.size.height = kNavBarHeight;
    UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    CGRect labelFrame = CGRectMake(kMargin, kSpacer,
                                   navBar.bounds.size.width - 2*kMargin, 
                                   kLabelHeight);
    UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont systemFontOfSize:12];
    label.textColor = [UIColor colorWithRed:0.97f green:0.98f blue:0.99 alpha:0.95];
    label.shadowColor = [UIColor colorWithRed:0.06f green:0.12f blue:0.16f alpha:0.4f];
    label.shadowOffset = CGSizeMake(0.0f, 1.0f);
    label.textAlignment = UITextAlignmentCenter;
    label.text = [[appDelegate activeStory] objectForKey:@"story_title"];
    [navBar addSubview:label];
    self.pageTitle = label;
    [label release];
    
    
    UIBarButtonItem *close = [[UIBarButtonItem alloc] 
                              initWithTitle:@"Close" 
                              style:UIBarButtonItemStyleBordered 
                              target:self 
                              action:@selector(doCloseOriginalStoryViewController)];
    close.width = kButtonWidth;
    CGRect closeButtonFrame = CGRectMake(0, 
                                         kSpacer*2.0 + kLabelHeight - 7.0f, 
                                         kButtonWidth + kMargin,
                                         44.0);
    TransparentToolbar* tools = [[TransparentToolbar alloc] 
                                 initWithFrame:closeButtonFrame];
    [tools setItems:[NSArray arrayWithObject:close] animated:NO];
    [tools setTintColor:UIColorFromRGB(0x183353)];
    [navBar addSubview:tools];
    [close release];
    [tools release];

    
    CGRect addressFrame = CGRectMake(closeButtonFrame.origin.x + 
                                     closeButtonFrame.size.width +
                                     kMargin, 
                                     kSpacer*2.0 + kLabelHeight,
                                     labelFrame.size.width - kButtonWidth - kMargin, 
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
    
    [self.view addSubview:navBar];
    
    CGRect webViewFrame = CGRectMake(0, 
                                     navBarFrame.origin.y + 
                                     navBarFrame.size.height, 
                                     self.view.frame.size.width, 
                                     self.view.frame.size.height - kNavBarHeight - 44);
    self.webView.frame = webViewFrame;
        
    navBar.tintColor = UIColorFromRGB(0x183353);
    
    [navBar release];
    [address release];

}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self loadAddress:nil];
    return YES;
}

- (IBAction)loadAddress:(id)sender {
    NSString* urlString = self.pageUrl.text;
    NSURL* url = [NSURL URLWithString:urlString];

    if (!url.scheme) {
        NSString* modifiedURLString = [NSString stringWithFormat:@"http://%@", urlString];
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
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        [self updateAddress:request];
        return NO;
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)aWebView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self updateButtons];
}
- (void)webViewDidFinishLoad:(UIWebView *)aWebView
{
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
        [NewsBlurAppDelegate informError:error];   
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

- (void)dealloc {
    [appDelegate release];
    [closeButton release];
    [webView release];
    [back release];
    [forward release];
    [refresh release];
    [pageAction release];
    [pageTitle release];
    [pageUrl release];
    [toolbar release];
    [super dealloc];
}

- (IBAction)doCloseOriginalStoryViewController {
//    NSLog(@"Close Original Story: %@", appDelegate);
    [appDelegate closeOriginalStory];
}

- (IBAction)doOpenActionSheet {
    UIActionSheet *options = [[UIActionSheet alloc] 
                              initWithTitle:[appDelegate.activeStory objectForKey:@"story_title"]
                              delegate:self
                              cancelButtonTitle:nil
                              destructiveButtonTitle:nil
                              otherButtonTitles:nil];

    NSArray *buttonTitles;
    if ([[appDelegate.activeOriginalStoryURL absoluteString] isEqualToString:self.pageUrl.text]) {
        buttonTitles = [NSArray arrayWithObjects:@"Open Story in Safari", nil];
    } else {
        buttonTitles = [NSArray arrayWithObjects:@"Open this Page in Safari", @"Open Original in Safari", nil];
    }
    for (id title in buttonTitles) {
        [options addButtonWithTitle:title];
    }
    options.cancelButtonIndex = [options addButtonWithTitle:@"Cancel"];

    [options showInView:self.view];
    [options release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {

    if ([[appDelegate.activeOriginalStoryURL absoluteString] isEqualToString:self.pageUrl.text]) {
        if (buttonIndex == 0) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.pageUrl.text]];
        }
    } else {
        if (buttonIndex == 0) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.pageUrl.text]];
        } else if (buttonIndex == 1) {
            [[UIApplication sharedApplication] openURL:appDelegate.activeOriginalStoryURL];
        }
    }
}

@end
