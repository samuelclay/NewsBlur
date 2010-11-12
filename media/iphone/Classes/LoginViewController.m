//
//  LoginViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/31/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "LoginViewController.h"
#import "NewsBlurAppDelegate.h"
#import "Three20/Three20.h"
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
    
    NSLog(@"appdelegate:: %@", [self appDelegate]);
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
    NSString *url = @"http://nb.local.host:8000/reader/login";
    TTURLRequest *theRequest = [[TTURLRequest alloc] initWithURL:url delegate:self];
    [theRequest setHttpMethod:@"POST"]; 
    [theRequest.parameters setValue:[usernameTextField text] forKey:@"login-username"]; 
    [theRequest.parameters setValue:[passwordTextField text] forKey:@"login-password"]; 
    [theRequest.parameters setValue:@"login" forKey:@"submit"]; 
    [theRequest.parameters setValue:@"1" forKey:@"api"]; 
    theRequest.response = [[[TTURLDataResponse alloc] init] autorelease];
    [theRequest send];
    
    [theRequest release];
}
- (void)requestDidStartLoad:(TTURLRequest*)request {
    NSLog(@"Starting");
}

- (void)requestDidFinishLoad:(TTURLRequest *)request {
    TTURLDataResponse *response = request.response;
    NSString *rawCode = [[NSString alloc] initWithData:response.data 
                                           encoding:NSUTF8StringEncoding];
    
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[rawCode JSONValue]];
    NSLog(@"response: %@", [results valueForKey:@"code"]);
    NSLog(@"appdelegate:: %@", [self appDelegate]);
    [[self appDelegate] reloadFeedsView];    
    [rawCode release];
    [results release];
}

- (void)request:(TTURLRequest *)request didFailLoadWithError:(NSError *)error {
    NSLog(@"Error: %@", error);
    NSLog(@"%@", error );
    
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [jsonString setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data 
{   
    [jsonString appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSString *jsonS = [[NSString alloc] 
                       initWithData:jsonString 
                       encoding:NSUTF8StringEncoding];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[jsonS JSONValue]];
    NSLog(@"Results: %@", results);
    
    [self dismissModalViewControllerAnimated:YES];
    [jsonString release];
    [jsonS release];
    [results release];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    // release the connection, and the data object
    [connection release];
    // receivedData is declared as a method instance elsewhere
    [jsonString release];
    
    [passwordTextField becomeFirstResponder];
    
    // inform the user
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSErrorFailingURLStringKey]);
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
