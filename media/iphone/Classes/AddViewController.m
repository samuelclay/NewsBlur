//
//  LoginViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/31/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "AddViewController.h"
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "JSON.h"

@implementation AddViewController

@synthesize appDelegate;
@synthesize usernameInput;
@synthesize passwordInput;
@synthesize emailInput;
@synthesize jsonString;
@synthesize activityIndicator;
@synthesize authenticatingLabel;
@synthesize errorLabel;
@synthesize loginControl;
@synthesize usernameLabel;
@synthesize usernameOrEmailLabel;
@synthesize passwordLabel;
@synthesize emailLabel;
@synthesize passwordOptionalLabel;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		[appDelegate hideNavigationBar:NO];
    }
    return self;
}

- (void)viewDidLoad {
    [usernameInput becomeFirstResponder];
    
	[appDelegate hideNavigationBar:NO];
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.errorLabel setHidden:YES];
    [self.authenticatingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.activityIndicator stopAnimating];
    [super viewDidAppear:animated];
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)dealloc {
    [appDelegate release];
    [usernameInput release];
    [passwordInput release];
    [jsonString release];
    [super dealloc];
}

#pragma mark -
#pragma mark Add Site

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	if(textField == usernameInput) {
        [passwordInput becomeFirstResponder];
    } else if (textField == passwordInput && [self.loginControl selectedSegmentIndex] == 0) {
        NSLog(@"Password return");
        NSLog(@"appdelegate:: %@", [self appDelegate]);
        [self checkPassword];
    } else if (textField == passwordInput && [self.loginControl selectedSegmentIndex] == 1) {
        [emailInput becomeFirstResponder];
    } else if (textField == emailInput) {
        [self registerAccount];
    }
	return YES;
}

- (void)checkPassword {
    [self.authenticatingLabel setHidden:NO];
    [self.authenticatingLabel setText:@"Authenticating..."];
    [self.errorLabel setHidden:YES];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/api/login",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:[usernameInput text] forKey:@"username"]; 
    [request setPostValue:[passwordInput text] forKey:@"password"]; 
    [request setPostValue:@"login" forKey:@"submit"]; 
    [request setPostValue:@"1" forKey:@"api"]; 
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(requestFinished:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}


- (void)requestFinished:(ASIHTTPRequest *)request {
    [self.authenticatingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSLog(@"Bad login: %@", results);
        [appDelegate showLogin];
        [self.errorLabel setText:[[[results valueForKey:@"errors"] valueForKey:@"__all__"] objectAtIndex:0]];
        [self.errorLabel setHidden:NO];
    } else {
        NSLog(@"Good login");
        [appDelegate reloadFeedsView];
    }
    
    [results release];
}


- (void)registerAccount {
    [self.authenticatingLabel setHidden:NO];
    [self.authenticatingLabel setText:@"Registering..."];
    [self.errorLabel setHidden:YES];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/api/signup",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:[usernameInput text] forKey:@"username"]; 
    [request setPostValue:[passwordInput text] forKey:@"password"]; 
    [request setPostValue:[emailInput text] forKey:@"email"]; 
    [request setPostValue:@"login" forKey:@"submit"]; 
    [request setPostValue:@"1" forKey:@"api"]; 
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishRegistering:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)finishRegistering:(ASIHTTPRequest *)request {
    [self.authenticatingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSLog(@"Bad login: %@", results);
        [appDelegate showLogin];
        NSDictionary *errors = [results valueForKey:@"errors"];
        if ([errors valueForKey:@"email"]) {
            [self.errorLabel setText:[[errors valueForKey:@"email"] objectAtIndex:0]];   
        } else if ([errors valueForKey:@"username"]) {
            [self.errorLabel setText:[[errors valueForKey:@"username"] objectAtIndex:0]];
        }
        [self.errorLabel setHidden:NO];
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

#pragma mark -
#pragma mark Add Folder

- (IBAction)selectLoginSignup {
    [self animateLoop];
}

- (void)animateLoop {
    if ([self.loginControl selectedSegmentIndex] == 0) {
        [UIView animateWithDuration:0.5 animations:^{
            // Login
            usernameInput.frame = CGRectMake(20, 67, 280, 31); 
            usernameOrEmailLabel.alpha = 1.0;
            
            
            passwordInput.frame = CGRectMake(20, 129, 280, 31);
            passwordLabel.frame = CGRectMake(21, 106, 212, 22);
            passwordOptionalLabel.frame = CGRectMake(199, 112, 101, 16);
            
            emailInput.alpha = 0.0;
            emailLabel.alpha = 0.0;
        }];
        
        passwordInput.returnKeyType = UIReturnKeyGo;
        usernameInput.keyboardType = UIKeyboardTypeEmailAddress;
        [usernameInput resignFirstResponder];
        [usernameInput becomeFirstResponder];
    } else {
        [UIView animateWithDuration:0.5 animations:^{
            // Signup
            usernameInput.frame = CGRectMake(20, 67, 130, 31); 
            usernameOrEmailLabel.alpha = 0.0;
            
            
            passwordInput.frame = CGRectMake(170, 67, 130, 31);
            passwordLabel.frame = CGRectMake(171, 44, 212, 22);
            passwordOptionalLabel.frame = CGRectMake(199, 50, 101, 16);
            
            emailInput.alpha = 1.0;
            emailLabel.alpha = 1.0;
        }];
        
        passwordInput.returnKeyType = UIReturnKeyNext;
        usernameInput.keyboardType = UIKeyboardTypeAlphabet;
        [usernameInput resignFirstResponder];
        [usernameInput becomeFirstResponder];
    }
}

#pragma mark -
#pragma mark Folder Picker

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView
numberOfRowsInComponent:(NSInteger)component {
    return [[appDelegate dictFoldersArray] count];
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component {
    return [[appDelegate dictFoldersArray] objectAtIndex:row];
}

- (void)pickerView:(UIPickerView *)pickerView 
      didSelectRow:(NSInteger)row 
       inComponent:(NSInteger)component {
    
}

@end
