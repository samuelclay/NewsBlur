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
    
    self.usernameInput.borderStyle = UITextBorderStyleRoundedRect;
    self.passwordInput.borderStyle = UITextBorderStyleRoundedRect;
    self.emailInput.borderStyle = UITextBorderStyleRoundedRect;
    self.signUpPasswordInput.borderStyle = UITextBorderStyleRoundedRect;
    self.signUpUsernameInput.borderStyle = UITextBorderStyleRoundedRect;

    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
        self.signUpView.frame = CGRectMake(134, 180, 500, 300); 
        self.logInView.frame = CGRectMake(902, 180, 500, 300); 
        self.selectSignUpButton.frame = CGRectMake(134, 80, 250, 50);
        self.selectLoginButton.frame = CGRectMake(384, 80, 250, 50);
    } else {
        self.signUpView.frame = CGRectMake(134 + 128, 80, 500, 300); 
        self.logInView.frame = CGRectMake(902 + 128, 80, 500, 300); 
        self.selectSignUpButton.frame = CGRectMake(134 + 128, 20, 250, 50);
        self.selectLoginButton.frame = CGRectMake(384 + 128, 20, 250, 50);
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
    [self.authenticatingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return YES;
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

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation)){
            self.signUpView.frame = CGRectMake(self.signUpView.frame.origin.x - 128, 180, 500, 300); 
            self.logInView.frame = CGRectMake(self.logInView.frame.origin.x - 128, 180, 500, 300);

            self.selectSignUpButton.frame = CGRectMake(134, 80, 250, 50);
            self.selectLoginButton.frame = CGRectMake(384, 80, 250, 50);

        }else{
            self.signUpView.frame = CGRectMake(self.signUpView.frame.origin.x + 128, 80, 500, 300); 
            self.logInView.frame = CGRectMake(self.logInView.frame.origin.x + 128, 80, 500, 300);

            self.selectSignUpButton.frame = CGRectMake(134 + 128, 20, 250, 50);
            self.selectLoginButton.frame = CGRectMake(384 + 128, 20, 250, 50);
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
<<<<<<< HEAD
    [signUpUsernameInput release];
    [signUpPasswordInput release];
    [selectSignUpButton release];
    [selectLoginButton release];
=======
    [tourView release];
>>>>>>> b15e7424b2eec64ecfef7077ffd036fac917d7ad
    [super dealloc];
}



#pragma mark -
#pragma mark Login

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
        [appDelegate showLogin];
        NSDictionary *errors = [results valueForKey:@"errors"];
        if ([errors valueForKey:@"email"]) {
            [self.errorLabel setText:[[errors valueForKey:@"email"] objectAtIndex:0]];   
        } else if ([errors valueForKey:@"username"]) {
            [self.errorLabel setText:[[errors valueForKey:@"username"] objectAtIndex:0]];
        }
        [self.errorLabel setHidden:NO];
    } else {
        [appDelegate reloadFeedsView:YES];
    }
    
    [results release];    
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

#pragma mark -
#pragma mark Login

- (IBAction)tapLoginButton {
    [self checkPassword];
}

#pragma mark -
#pragma mark Signup

- (IBAction)selectLoginSignup {
    [self animateLoop];
}

- (IBAction)selectSignUp {
<<<<<<< HEAD
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
        [UIView animateWithDuration:0.35 animations:^{
            self.signUpView.frame = CGRectMake(134, 180, 500, 300); 
            self.logInView.frame = CGRectMake(902, 180, 500, 300);         
        }]; 
    } else {
        [UIView animateWithDuration:0.35 animations:^{
            self.signUpView.frame = CGRectMake(134 + 128, 80, 500, 300); 
            self.logInView.frame = CGRectMake(902 + 128, 80, 500, 300);         
        }]; 
    }

}

- (IBAction)selectLogin {
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
        [UIView animateWithDuration:0.35 animations:^{
            self.signUpView.frame = CGRectMake(-634, 180, 500, 300); 
            self.logInView.frame = CGRectMake(134, 180, 500, 300);         
        }];
    } else {
        [UIView animateWithDuration:0.35 animations:^{
            self.signUpView.frame = CGRectMake(-634 + 128, 80, 500, 300); 
            self.logInView.frame = CGRectMake(134 + 128, 80, 500, 300);         
        }];
    }
=======
    self.signUpView.frame = CGRectMake(-634, 134, 500, 350); 
    [UIView animateWithDuration:0.35 animations:^{
        self.signUpView.frame = CGRectMake(134, 134, 500, 350); 
        self.logInView.frame = CGRectMake(902, 134, 500, 350); 
        self.tourView.frame = CGRectMake(1670, 134, 500, 350); 
        
    }];
}

- (IBAction)selectLogin {
    [UIView animateWithDuration:0.35 animations:^{
        self.signUpView.frame = CGRectMake(-634, 134, 500, 350); 
        self.logInView.frame = CGRectMake(134, 134, 500, 350); 
        self.tourView.frame = CGRectMake(902, 134, 500, 350); 
        
    }];
}

- (IBAction)selectTour {
    self.tourView.frame = CGRectMake(902, 134, 500, 350); 
    
    [UIView animateWithDuration:0.35 animations:^{
        self.signUpView.frame = CGRectMake(-634, 134, 500, 350); 
        self.logInView.frame = CGRectMake(-634, 134, 500, 350); 
        self.tourView.frame = CGRectMake(134, 134, 500, 350); 
        
    }];
>>>>>>> b15e7424b2eec64ecfef7077ffd036fac917d7ad
}

- (void)animateLoop {
    if ([self.loginControl selectedSegmentIndex] == 0) {
        [UIView animateWithDuration:0.5 animations:^{
            // Login
            usernameInput.frame = CGRectMake(186, 388, 400, 44); 
            usernameOrEmailLabel.alpha = 1.0;
            
            
            passwordInput.frame = CGRectMake(186, 496, 400, 44);
            passwordLabel.frame = CGRectMake(186, 460, 120, 22);
            passwordOptionalLabel.frame = CGRectMake(483, 466, 101, 16);
            
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
            usernameInput.frame = CGRectMake(186, 388, 190, 44); 
            usernameOrEmailLabel.alpha = 0.0;
            
            
            passwordInput.frame = CGRectMake(396, 388, 190, 44);
            passwordLabel.frame = CGRectMake(396, 353, 120, 22);
            passwordOptionalLabel.frame = CGRectMake(483, 359, 101, 16);
            
            emailInput.alpha = 1.0;
            emailLabel.alpha = 1.0;
        }];
        
        passwordInput.returnKeyType = UIReturnKeyNext;
        usernameInput.keyboardType = UIKeyboardTypeAlphabet;
        [usernameInput resignFirstResponder];
        [usernameInput becomeFirstResponder];
    }
}
<<<<<<< HEAD
=======

- (void)viewDidUnload {
    [self setSignUpView:nil];
    [self setLogInView:nil];
    [self setTourView:nil];
    [super viewDidUnload];
}
>>>>>>> b15e7424b2eec64ecfef7077ffd036fac917d7ad
@end
