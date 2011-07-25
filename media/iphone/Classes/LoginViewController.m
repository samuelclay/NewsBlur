//
//  LoginViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/31/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "LoginViewController.h"
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "JSON.h"

@implementation LoginViewController

@synthesize appDelegate;
@synthesize usernameTextField;
@synthesize passwordTextField;
@synthesize jsonString;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		[appDelegate hideNavigationBar:NO];
    }
    return self;
}

- (void)viewDidLoad {
    [usernameTextField becomeFirstResponder];
    
	[appDelegate hideNavigationBar:NO];
    
    [super viewDidLoad];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	if(textField == usernameTextField) {
        [passwordTextField becomeFirstResponder];
    } else if (textField == passwordTextField) {
        NSLog(@"Password return");
        NSLog(@"appdelegate:: %@", [self appDelegate]);
        [self checkPassword];
    }
	return YES;
}

- (void)checkPassword {
    NSLog(@"appdelegate:: %@", [self appDelegate]);
    NSString *urlString = @"http://nb.local.host:8000/reader/login";
    NSURL *url = [NSURL URLWithString:urlString];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:[usernameTextField text] forKey:@"login-username"]; 
    [request setPostValue:[passwordTextField text] forKey:@"login-password"]; 
    [request setPostValue:@"login" forKey:@"submit"]; 
    [request setPostValue:@"1" forKey:@"api"]; 
    [request setDelegate:self];
    [request startAsynchronous];
}


- (void)requestFinished:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSLog(@"Bad login");
        [appDelegate showLogin];
    } else {
        NSLog(@"Good login");
        [appDelegate reloadFeedsView];
    }
    
    [results release];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
    self.jsonString = nil;
}


- (void)dealloc {
    [usernameTextField release];
    [passwordTextField release];
    [jsonString release];
    [super dealloc];
}


@end
