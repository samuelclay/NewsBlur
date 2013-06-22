//
//  IASKAppSettingsWebViewController.h
//  http://www.inappsettingskit.com
//
//  Copyright (c) 2010:
//  Luc Vandal, Edovia Inc., http://www.edovia.com
//  Ortwin Gentz, FutureTap GmbH, http://www.futuretap.com
//  All rights reserved.
// 
//  It is appreciated but not required that you give credit to Luc Vandal and Ortwin Gentz, 
//  as the original authors of this code. You can give credit in a blog post, a tweet or on 
//  a info page of your app. Also, the original authors appreciate letting them know if you use this code.
//
//  This code is licensed under the BSD license that is available at: http://www.opensource.org/licenses/bsd-license.php
//

#import "IASKAppSettingsWebViewController.h"

@implementation IASKAppSettingsWebViewController

@synthesize url;
@synthesize webView;

- (id)initWithFile:(NSString*)urlString key:(NSString*)key {
    self = [super init];
    if (self) {
        self.url = [NSURL URLWithString:urlString];
        if (!self.url || ![self.url scheme]) {
            NSString *path = [[NSBundle mainBundle] pathForResource:[urlString stringByDeletingPathExtension] ofType:[urlString pathExtension]];
            if(path)
                self.url = [NSURL fileURLWithPath:path];
            else
                self.url = nil;
        }
    }
    return self;
}

- (void)loadView
{
    webView = [[UIWebView alloc] init];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleHeight;
    webView.delegate = self;
    
    self.view = webView;
}

- (void)dealloc {
	[webView release], webView = nil;
	[url release], url = nil;
	
	[super dealloc];
}

- (void)viewWillAppear:(BOOL)animated {  
	[webView loadRequest:[NSURLRequest requestWithURL:self.url]];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	self.webView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	self.navigationItem.title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *newURL = [request URL];
	
	// intercept mailto URL and send it to an in-app Mail compose view instead
	if ([[newURL scheme] isEqualToString:@"mailto"]) {

		NSArray *rawURLparts = [[newURL resourceSpecifier] componentsSeparatedByString:@"?"];
		if (rawURLparts.count > 2) {
			return NO; // invalid URL
		}
		
		MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
		mailViewController.mailComposeDelegate = self;

		NSMutableArray *toRecipients = [NSMutableArray array];
		NSString *defaultRecipient = [rawURLparts objectAtIndex:0];
		if (defaultRecipient.length) {
			[toRecipients addObject:defaultRecipient];
		}
		
		if (rawURLparts.count == 2) {
			NSString *queryString = [rawURLparts objectAtIndex:1];
			
			NSArray *params = [queryString componentsSeparatedByString:@"&"];
			for (NSString *param in params) {
				NSArray *keyValue = [param componentsSeparatedByString:@"="];
				if (keyValue.count != 2) {
					continue;
				}
				NSString *key = [[keyValue objectAtIndex:0] lowercaseString];
				NSString *value = [keyValue objectAtIndex:1];
				
				value =  (NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
																							 (CFStringRef)value,
																							 CFSTR(""),
																							 kCFStringEncodingUTF8);
				[value autorelease];
				
				if ([key isEqualToString:@"subject"]) {
					[mailViewController setSubject:value];
				}
				
				if ([key isEqualToString:@"body"]) {
					[mailViewController setMessageBody:value isHTML:NO];
				}
				
				if ([key isEqualToString:@"to"]) {
					[toRecipients addObjectsFromArray:[value componentsSeparatedByString:@","]];
				}
				
				if ([key isEqualToString:@"cc"]) {
					NSArray *recipients = [value componentsSeparatedByString:@","];
					[mailViewController setCcRecipients:recipients];
				}
				
				if ([key isEqualToString:@"bcc"]) {
					NSArray *recipients = [value componentsSeparatedByString:@","];
					[mailViewController setBccRecipients:recipients];
				}
			}
		}
		
		[mailViewController setToRecipients:toRecipients];
    
#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= 50000)
#pragma message "Now that we're iOS5 and up, remove this workaround"
#endif
    if([self respondsToSelector:@selector(presentViewController:animated:completion:)]) {
        [self presentViewController:mailViewController
                           animated:YES
                         completion:nil];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self presentModalViewController:mailViewController animated:YES];
#pragma clang diagnostic pop
    }
		[mailViewController release];
		return NO;
	}
	
	// open inline if host is the same, otherwise, pass to the system
	if (![newURL host] || [[newURL host] isEqualToString:[self.url host]]) {
		return YES;
	}
	[[UIApplication sharedApplication] openURL:newURL];
	return NO;
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= 50000)
#pragma message "Now that we're iOS5 and up, remove this workaround"
#endif
    if([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
        [self dismissViewControllerAnimated:YES
                                 completion:nil];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self dismissModalViewControllerAnimated:YES];
#pragma clang diagnostic pop

    }
}



@end
