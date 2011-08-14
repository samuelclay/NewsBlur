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
    NSLog(@"Original Story View: %@", [appDelegate activeOriginalStoryURL]);
    [appDelegate showNavigationBar:NO];
    toolbar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    NSURLRequest *request = [[[NSURLRequest alloc] initWithURL:[appDelegate activeOriginalStoryURL]] autorelease];
    [webView loadRequest:request];
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
    label.textColor = [UIColor colorWithRed:0.01f green:0.02f blue:0.05 alpha:0.95];
    label.shadowColor = [UIColor colorWithRed:0.76f green:0.86f blue:0.96f alpha:0.4f];
    label.shadowOffset = CGSizeMake(0.0f, 1.0f);
    label.textAlignment = UITextAlignmentCenter;
    label.text = [[appDelegate activeStory] objectForKey:@"story_title"];
    [navBar addSubview:label];
    self.pageTitle = label;
    [label release];
    
    CGRect addressFrame = CGRectMake(kMargin, kSpacer*2.0 + kLabelHeight,
                                     labelFrame.size.width - kButtonWidth - kMargin, kAddressHeight);
    UITextField *address = [[UITextField alloc] initWithFrame:addressFrame];
    address.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    address.borderStyle = UITextBorderStyleRoundedRect;
    address.font = [UIFont systemFontOfSize:18];
    [address setAdjustsFontSizeToFitWidth:YES];
    address.keyboardType = UIKeyboardTypeURL;
    address.autocapitalizationType = UITextAutocapitalizationTypeNone;
    address.clearButtonMode = UITextFieldViewModeWhileEditing;
    [navBar addSubview:address];
    self.pageUrl = address;
    
    [self.view addSubview:navBar];
    
    CGRect webViewFrame = CGRectMake(0, 
                                     navBarFrame.origin.y + 
                                     navBarFrame.size.height, 
                                     self.view.frame.size.width, 
                                     self.view.frame.size.height - kNavBarHeight - 44);
    self.webView.frame = webViewFrame;
    
    UIBarButtonItem *close = [[UIBarButtonItem alloc] 
                              initWithTitle:@"Close" 
                              style:UIBarButtonItemStyleBordered 
                              target:self 
                              action:@selector(doCloseOriginalStoryViewController)];
    close.width = kButtonWidth;
    CGRect closeButtonFrame = CGRectMake(addressFrame.origin.x + 
                                         addressFrame.size.width, 
                                         addressFrame.origin.y - 7.0f, 
                                         kButtonWidth + kMargin,
                                         44.0);
    TransparentToolbar* tools = [[TransparentToolbar alloc] 
                                 initWithFrame:closeButtonFrame];
    [tools setItems:[NSArray arrayWithObject:close] animated:NO];
    [tools setTintColor:[UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9]];
    [navBar addSubview:tools];
    [close release];
    [tools release];
    
    navBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    
    [navBar release];
    [address release];

}

- (void)loadAddress:(id)sender event:(UIEvent *)event
{
    NSString* urlString = self.pageUrl.text;
    NSURL* url = [NSURL URLWithString:urlString];
    
    if (!url.scheme) {
        NSString* modifiedURLString = [NSString stringWithFormat:@"http://%@", urlString];
        url = [NSURL URLWithString:modifiedURLString];
    }
    
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
}

# pragma mark: -
# pragma mark: UIWebViewDelegate protocol

- (BOOL)webView:(UIWebView *)webView 
    shouldStartLoadWithRequest:(NSURLRequest *)request 
    navigationType:(UIWebViewNavigationType)navigationType
{
    [self updateAddress:request];
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
    NSURLRequest* request = [aWebView request];
    [self updateAddress:request];
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
    [self informError:error];
}
- (void)updateTitle:(UIWebView*)aWebView
{
    NSString *pageTitleValue = [aWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
    self.pageTitle.text = [pageTitleValue stringByDecodingHTMLEntities];
}
- (void)updateAddress:(NSURLRequest*)request
{
    NSURL *url = [request mainDocumentURL];
    NSString *absoluteString = [url absoluteString];
    self.pageUrl.text = absoluteString;
}
- (void)updateButtons
{
    self.forward.enabled = self.webView.canGoForward;
    self.back.enabled = self.webView.canGoBack;
//    self.stop.enabled = self.webView.loading;
}
- (void)informError:(NSError *)error
{
    NSString* localizedDescription = [error localizedDescription];
    UIAlertView* alertView = [[UIAlertView alloc]
                              initWithTitle:@"Error"
                              message:localizedDescription delegate:nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.webView = nil;
    self.back = nil;
    self.forward = nil;
    self.refresh = nil;
    self.pageAction = nil;
    self.pageTitle = nil;
    self.pageUrl = nil;
    self.toolbar = nil;
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
    NSLog(@"Close Original Story: %@", appDelegate);
    [appDelegate closeOriginalStory];
}


@end
