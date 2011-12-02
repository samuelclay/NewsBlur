    //
//  SHKTwitterAuthView.m
//  ShareKit
//
//  Created by Nathan Weiner on 6/21/10.

//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//

#import "SHKOAuthView.h"
#import "SHK.h"
#import "SHKOAuthSharer.h"

@implementation SHKOAuthView

@synthesize webView, delegate, spinner;

- (void)dealloc
{
	[webView release];
	[delegate release];
	[spinner release];
	[super dealloc];
}

- (id)initWithURL:(NSURL *)authorizeURL delegate:(id)d
{
    if ((self = [super initWithNibName:nil bundle:nil])) 
	{
		[self.navigationItem setLeftBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
																								  target:self
																								  action:@selector(cancel)] autorelease] animated:NO];
		
		self.delegate = d;
		
		UIWebView *aWebView = [[UIWebView alloc] initWithFrame:CGRectZero];
		webView = [aWebView retain];
        [aWebView release];
		webView.delegate = self;
		webView.scalesPageToFit = YES;
		webView.dataDetectorTypes = UIDataDetectorTypeNone;
				
		[webView loadRequest:[NSURLRequest requestWithURL:authorizeURL]];		
		
    }
    return self;
}

- (void)loadView 
{ 	
	self.view = webView;
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	// Remove the SHK view wrapper from the window
	[[SHK currentHelper] viewWasDismissed];
}


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{		
	if ([request.URL.absoluteString rangeOfString:[delegate authorizeCallbackURL].absoluteString].location != NSNotFound)
	{
		// Get query
		NSMutableDictionary *queryParams = nil;
		if (request.URL.query != nil)
		{
			queryParams = [NSMutableDictionary dictionaryWithCapacity:0];
			NSArray *vars = [request.URL.query componentsSeparatedByString:@"&"];
			NSArray *parts;
			for(NSString *var in vars)
			{
				parts = [var componentsSeparatedByString:@"="];
				if (parts.count == 2)
					[queryParams setObject:[parts objectAtIndex:1] forKey:[parts objectAtIndex:0]];
			}
		}
		
		[delegate tokenAuthorizeView:self didFinishWithSuccess:YES queryParams:queryParams error:nil];
		self.delegate = nil;
		
		return NO;
	}
	
	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	[self startSpinner];
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView
{	
	[self stopSpinner];
	
	// Extra sanity check for Twitter OAuth users to make sure they are using BROWSER with a callback instead of pin based auth
	if ([webView.request.URL.host isEqualToString:@"twitter.com"] && [webView stringByEvaluatingJavaScriptFromString:@"document.getElementById('oauth_pin').innerHTML"].length)
		[delegate tokenAuthorizeView:self didFinishWithSuccess:NO queryParams:nil error:[SHK error:@"Your SHKTwitter config is incorrect.  You must set your application type to Browser and define a callback url.  See SHKConfig.h for more details"]];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{	
	if ([error code] != NSURLErrorCancelled && [error code] != 102 && [error code] != NSURLErrorFileDoesNotExist)
	{
		[self stopSpinner];
		[delegate tokenAuthorizeView:self didFinishWithSuccess:NO queryParams:nil error:error];
	}
}

- (void)startSpinner
{
	if (spinner == nil)
	{
		UIActivityIndicatorView *aSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        self.spinner = aSpinner;
        [aSpinner release];

		[self.navigationItem setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithCustomView:spinner] autorelease] animated:NO];
		spinner.hidesWhenStopped = YES;
	}
	
	[spinner startAnimating];
}

- (void)stopSpinner
{
	[spinner stopAnimating];	
}


#pragma mark -

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
    return YES;
}

- (void)cancel
{
	[delegate tokenAuthorizeCancelledView:self];
	[[SHK currentHelper] hideCurrentViewControllerAnimated:YES];
}

@end
