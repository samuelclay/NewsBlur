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
#import <QuartzCore/QuartzCore.h>

@implementation LoginViewController

@synthesize appDelegate;
@synthesize usernameInput;
@synthesize passwordInput;
@synthesize emailInput;
@synthesize signUpUsernameInput;
@synthesize signUpPasswordInput;
@synthesize selectSignUpButton;
@synthesize selectLoginButton;
@synthesize signUpView;
@synthesize logInView;

@synthesize jsonString;
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
    
    self.usernameInput.borderStyle = UITextBorderStyleRoundedRect;
    self.passwordInput.borderStyle = UITextBorderStyleRoundedRect;
    self.emailInput.borderStyle = UITextBorderStyleRoundedRect;
    self.signUpPasswordInput.borderStyle = UITextBorderStyleRoundedRect;
    self.signUpUsernameInput.borderStyle = UITextBorderStyleRoundedRect;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
            self.logInView.frame = CGRectMake(134, 180, 500, 300); 
            self.signUpView.frame = CGRectMake(902, 180, 500, 300); 
            self.selectLoginButton.frame = CGRectMake(134, 80, 250, 50);
            self.selectSignUpButton.frame = CGRectMake(384, 80, 250, 50);
            self.errorLabel.frame = CGRectMake(244, 180, self.errorLabel.frame.size.width, self.errorLabel.frame.size.height);
        } else {
            self.logInView.frame = CGRectMake(134 + LANDSCAPE_MARGIN, 80, 500, 300); 
            self.signUpView.frame = CGRectMake(902 + LANDSCAPE_MARGIN, 80, 500, 300); 
            self.selectLoginButton.frame = CGRectMake(134 + LANDSCAPE_MARGIN, 20, 250, 50);
            self.selectSignUpButton.frame = CGRectMake(384 + LANDSCAPE_MARGIN, 20, 250, 50);
            self.errorLabel.frame = CGRectMake(244 + LANDSCAPE_MARGIN, 180 - 100, self.errorLabel.frame.size.width, self.errorLabel.frame.size.height);
        } 
    }

    [super viewDidLoad];
}

- (void)viewDidUnload {
    [self setSignUpView:nil];
    [self setLogInView:nil];
    [self setSignUpUsernameInput:nil];
    [self setSignUpPasswordInput:nil];
    [self setSelectSignUpButton:nil];
    [self setSelectLoginButton:nil];
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.errorLabel setHidden:YES];
    [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [super viewDidAppear:animated];
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    int signUpX, loginX;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation)){
            if (isOnSignUpScreen) {
                loginX = -634;
                signUpX = 134;
            } else {
                loginX = 134;
                signUpX = 902;
            }
            self.logInView.frame = CGRectMake(loginX, 180, 500, 300);
            self.signUpView.frame = CGRectMake(signUpX, 180, 500, 300); 
            self.selectLoginButton.frame = CGRectMake(134, 80, 250, 50);
            self.selectSignUpButton.frame = CGRectMake(384, 80, 250, 50);
            self.errorLabel.frame = CGRectMake(244, 180, self.errorLabel.frame.size.width, self.errorLabel.frame.size.height);
        }else{
            if (isOnSignUpScreen) {
                loginX = -634 + LANDSCAPE_MARGIN;
                signUpX = 134 + LANDSCAPE_MARGIN;
            } else {
                loginX = 134 + LANDSCAPE_MARGIN;
                signUpX = 902 + LANDSCAPE_MARGIN;
            }

            self.logInView.frame = CGRectMake(loginX, 80, 500, 300);
            self.signUpView.frame = CGRectMake(signUpX, 80, 500, 300); 
            self.selectLoginButton.frame = CGRectMake(134 + LANDSCAPE_MARGIN, 80 - 60, 250, 50);
            self.selectSignUpButton.frame = CGRectMake(384 + LANDSCAPE_MARGIN, 80 - 60, 250, 50);
            self.errorLabel.frame = CGRectMake(244 + LANDSCAPE_MARGIN, 180 - 100, self.errorLabel.frame.size.width, self.errorLabel.frame.size.height);
        }

    }
}


- (void)dealloc {
    [appDelegate release];
    [usernameInput release];
    [passwordInput release];
    [emailInput release];
    [jsonString release];
    [signUpView release];
    [logInView release];
    [signUpUsernameInput release];
    [signUpPasswordInput release];
    [selectSignUpButton release];
    [selectLoginButton release];
    [super dealloc];
}



#pragma mark -
#pragma mark Login

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if  (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSLog(@"in it");
        if(textField == usernameInput) {
            [passwordInput becomeFirstResponder];
        } else if (textField == passwordInput) {
            [self checkPassword];
        } else if (textField == signUpUsernameInput){
            [signUpPasswordInput becomeFirstResponder];
        } else if (textField == signUpPasswordInput) {
            [emailInput becomeFirstResponder];
        } else if (textField == emailInput) {
            [self registerAccount];
        }
    } else {
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

    }
    return YES;
}

- (void)checkPassword {
    [self.errorLabel setHidden:YES];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Authenticating";
    
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
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSDictionary *errors = [results valueForKey:@"errors"];
        if ([errors valueForKey:@"username"]) {
            [self.errorLabel setText:[[errors valueForKey:@"username"] objectAtIndex:0]];   
        } else if ([errors valueForKey:@"__all__"]) {
            [self.errorLabel setText:[[errors valueForKey:@"__all__"] objectAtIndex:0]];
        }
        [self.errorLabel setHidden:NO];
    } else {
        [appDelegate reloadFeedsView:YES];
    }
    
    [results release];
}


- (void)registerAccount {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Registering...";
    [self.errorLabel setHidden:YES];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/api/signup",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [request setPostValue:[signUpUsernameInput text] forKey:@"username"]; 
        [request setPostValue:[signUpPasswordInput text] forKey:@"password"]; 
    } else {
        [request setPostValue:[usernameInput text] forKey:@"username"]; 
        [request setPostValue:[passwordInput text] forKey:@"password"]; 
    }
    [request setPostValue:[emailInput text] forKey:@"email"]; 
    [request setPostValue:@"login" forKey:@"submit"]; 
    [request setPostValue:@"1" forKey:@"api"]; 
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishRegistering:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)finishRegistering:(ASIHTTPRequest *)request {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    // int statusCode = [request responseStatusCode];
    
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSDictionary *errors = [results valueForKey:@"errors"];
        if ([errors valueForKey:@"email"]) {
            [self.errorLabel setText:[[errors valueForKey:@"email"] objectAtIndex:0]];   
        } else if ([errors valueForKey:@"username"]) {
            [self.errorLabel setText:[[errors valueForKey:@"username"] objectAtIndex:0]];
        } else if ([errors valueForKey:@"__all__"]) {
            [self.errorLabel setText:[[errors valueForKey:@"__all__"] objectAtIndex:0]];
        }

        [self.errorLabel setHidden:NO];
    } else {
        [appDelegate showFirstTimeUser];
        //[appDelegate reloadFeedsView:YES];
    }
    
    [results release];    
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

#pragma mark -
#pragma mark iPad: Sign Up/Login Toggle

- (IBAction)selectSignUp {
    isOnSignUpScreen = YES;
    [self.errorLabel setHidden:YES];
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
        [UIView animateWithDuration:0.35 animations:^{
            self.logInView.frame = CGRectMake(-634, 180, 500, 300);    
            self.signUpView.frame = CGRectMake(134, 180, 500, 300); 
        }]; 
    } else {
        [UIView animateWithDuration:0.35 animations:^{
            self.logInView.frame = CGRectMake(-634 + LANDSCAPE_MARGIN, 80, 500, 300); 
            self.signUpView.frame = CGRectMake(134 + LANDSCAPE_MARGIN, 80, 500, 300); 
        }]; 
    }
    
}

- (IBAction)selectLogin {
    isOnSignUpScreen = NO;
    [self.errorLabel setHidden:YES];
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
        [UIView animateWithDuration:0.35 animations:^{
            self.logInView.frame = CGRectMake(134, 180, 500, 300);   
            self.signUpView.frame = CGRectMake(902, 180, 500, 300); 
        }];
    } else {
        [UIView animateWithDuration:0.35 animations:^{
            self.logInView.frame = CGRectMake(134 + LANDSCAPE_MARGIN, 80, 500, 300);    
            self.signUpView.frame = CGRectMake(902 + LANDSCAPE_MARGIN, 80, 500, 300); 
        }];
    }
}

- (IBAction)tapLoginButton {
    [self.view endEditing:YES];
    [self checkPassword];
    
}

- (IBAction)tapSignUpButton {
    [self.view endEditing:YES];
    [self registerAccount];
}

#pragma mark -
#pragma mark iPhone: Sign Up/Login Toggle

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

@end
