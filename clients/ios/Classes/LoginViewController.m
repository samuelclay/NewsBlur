//
//  LoginViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/31/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "LoginViewController.h"
#import "ASIFormDataRequest.h"
#import "../Other Sources/OnePasswordExtension/OnePasswordExtension.h"
//#import <QuartzCore/QuartzCore.h>

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
@synthesize onePasswordButton;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {

    }
    return self;
    
    }

- (void)viewDidLoad {        
    self.usernameInput.borderStyle = UITextBorderStyleRoundedRect;
    self.passwordInput.borderStyle = UITextBorderStyleRoundedRect;
    self.emailInput.borderStyle = UITextBorderStyleRoundedRect;
    self.signUpPasswordInput.borderStyle = UITextBorderStyleRoundedRect;
    self.signUpUsernameInput.borderStyle = UITextBorderStyleRoundedRect;
    
    [self.loginControl
     setTitleTextAttributes:@{NSFontAttributeName:
                                  [UIFont fontWithName:@"Helvetica-Bold" size:11.0f]}
     forState:UIControlStateNormal];

    //[self.onePasswordButton setHidden:![[OnePasswordExtension sharedExtension] isAppExtensionAvailable]];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self updateControls];
        [self rearrangeViews];
    }
    
    [super viewDidLoad];
}

- (CGFloat)xForWidth:(CGFloat)width {
    return (self.view.bounds.size.width / 2) - (width / 2);
}

- (void)rearrangeViews {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        CGSize viewSize = self.view.bounds.size;
        CGFloat viewWidth = viewSize.width;
        CGFloat yOffset = 0;
        CGFloat xOffset = isOnSignUpScreen ? -viewWidth : 0;
        
        if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation])) {
            yOffset = viewSize.height / 6;
        }
        
        self.buttonsView.frame = CGRectMake([self xForWidth:518], 15 + yOffset, 518, 66);
        self.logInView.frame = CGRectMake([self xForWidth:500] + xOffset, 75 + yOffset, 500, 300);
        self.signUpView.frame = CGRectMake([self xForWidth:500] + viewWidth + xOffset, 75 + yOffset, 500, 300);
        self.errorLabel.frame = CGRectMake([self xForWidth:self.errorLabel.frame.size.width], 75 + yOffset, self.errorLabel.frame.size.width, self.errorLabel.frame.size.height);
    }
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
    [self showError:nil];
    [super viewWillAppear:animated];
    [usernameInput becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return NO;
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
    [self rearrangeViews];
}

- (void)showError:(NSString *)error {
    BOOL hasError = error.length > 0;
    
    if (hasError) {
        self.errorLabel.text = error;
    }
    
    self.errorLabel.hidden = !hasError;
    self.forgotPasswordButton.hidden = !hasError;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.loginOptionalLabel.hidden = hasError;
    }
}

- (IBAction)findLoginFrom1Password:(id)sender {
    [[OnePasswordExtension sharedExtension] findLoginForURLString:@"https://www.newsblur.com" forViewController:self sender:sender completion:^(NSDictionary *loginDictionary, NSError *error) {
        if (loginDictionary.count == 0) {
            if (error.code != AppExtensionErrorCodeCancelledByUser) {
                NSLog(@"Error invoking 1Password App Extension for find login: %@", error);
            }
            return;
        }
        
        self.usernameInput.text = loginDictionary[AppExtensionUsernameKey];
        [passwordInput becomeFirstResponder];
        self.passwordInput.text = loginDictionary[AppExtensionPasswordKey];
    }];
}

#pragma mark -
#pragma mark Login

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if  (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
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
    [self showError:nil];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Authenticating";
    
    NSString *urlString = [NSString stringWithFormat:@"%@/api/login",
                           self.appDelegate.url];
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
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSDictionary *errors = [results valueForKey:@"errors"];
        if ([errors valueForKey:@"username"]) {
            [self showError:[[errors valueForKey:@"username"] firstObject]];
        } else if ([errors valueForKey:@"__all__"]) {
            [self showError:[[errors valueForKey:@"__all__"] firstObject]];
        }
    } else {
        [self.passwordInput setText:@""];
        [self.signUpPasswordInput setText:@""];
        [appDelegate reloadFeedsView:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
}


- (void)registerAccount {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Registering...";
    [self showError:nil];
    NSString *urlString = [NSString stringWithFormat:@"%@/api/signup",
                           self.appDelegate.url];
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
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    // int statusCode = [request responseStatusCode];
    
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSDictionary *errors = [results valueForKey:@"errors"];
        if ([errors valueForKey:@"email"]) {
            [self showError:[[errors valueForKey:@"email"] objectAtIndex:0]];
        } else if ([errors valueForKey:@"username"]) {
            [self showError:[[errors valueForKey:@"username"] objectAtIndex:0]];
        } else if ([errors valueForKey:@"__all__"]) {
            [self showError:[[errors valueForKey:@"__all__"] objectAtIndex:0]];
        }
    } else {
        [self.passwordInput setText:@""];
        [self.signUpPasswordInput setText:@""];
//        [appDelegate showFirstTimeUser];
        [appDelegate reloadFeedsView:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
    [appDelegate informError:error];
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (IBAction)forgotPassword:(id)sender {
    NSURL *url = [NSURL URLWithString:@"http://www.newsblur.com/folder_rss/forgot_password"];
    SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url entersReaderIfAvailable:NO];
    [self presentViewController:safariViewController animated:YES completion:nil];
}

#pragma mark -
#pragma mark iPad: Sign Up/Login Toggle

- (void)updateControls {
    self.selectSignUpButton.selected = isOnSignUpScreen;
    self.selectLoginButton.selected = !isOnSignUpScreen;
    
    [self showError:nil];
    
    self.signUpUsernameInput.enabled = isOnSignUpScreen;
    self.signUpPasswordInput.enabled = isOnSignUpScreen;
    self.emailInput.enabled = isOnSignUpScreen;
    self.usernameInput.enabled = !isOnSignUpScreen;
    self.passwordInput.enabled = !isOnSignUpScreen;
}

- (IBAction)selectSignUp {
    isOnSignUpScreen = YES;
    
    [self updateControls];
    
    [UIView animateWithDuration:0.35 animations:^{
        [self rearrangeViews];
    }];
    
    [self.signUpUsernameInput becomeFirstResponder];
    
}

- (IBAction)selectLogin {
    isOnSignUpScreen = NO;
    
    [self updateControls];
    
    [UIView animateWithDuration:0.35 animations:^{
        [self rearrangeViews];
    }];
    
    [self.usernameInput becomeFirstResponder];
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
    CGFloat width = CGRectGetWidth(self.view.frame);
    CGFloat margin = 20;
    if ([self.loginControl selectedSegmentIndex] == 0) {
        [UIView animateWithDuration:0.5 animations:^{
            // Login
            usernameInput.frame = CGRectMake(20, 67, width-margin*2, 31);
            usernameOrEmailLabel.alpha = 1.0;
            usernameLabel.alpha = 0.0;
            
            passwordInput.frame = CGRectMake(20, 129, width-margin*2, 31);
            passwordLabel.frame = CGRectMake(21, 106, 212, 22);
            passwordOptionalLabel.frame = CGRectMake(width-margin-101, 112, 101, 16);
            
            emailInput.alpha = 0.0;
            emailLabel.alpha = 0.0;
            
            onePasswordButton.frame = CGRectMake(20+ passwordInput.frame.size.width - 31, 129, 31, 31);
            onePasswordButton.alpha = 1.0;
        }];
        
        passwordInput.returnKeyType = UIReturnKeyGo;
        usernameInput.keyboardType = UIKeyboardTypeEmailAddress;
        [usernameInput resignFirstResponder];
        [usernameInput becomeFirstResponder];
    } else {
        [UIView animateWithDuration:0.5 animations:^{
            // Signup
            usernameInput.frame = CGRectMake(20, 67, width/2-margin*2, 31);
            usernameOrEmailLabel.alpha = 0.0;
            usernameLabel.alpha = 1.0;
            
            passwordInput.frame = CGRectMake(width/2+margin, 67, width/2-margin*2, 31);
            passwordLabel.frame = CGRectMake(width/2+margin, 44, 212, 22);
            passwordOptionalLabel.frame = CGRectMake(width-margin-101, 50, 101, 16);
            
            emailInput.alpha = 1.0;
            emailLabel.alpha = 1.0;
            
            onePasswordButton.frame = CGRectMake(width/2+margin + passwordInput.frame.size.width - 31, 67, 31, 31);
            onePasswordButton.alpha = 0.0; // Don't want to deal with registration yet.
        }];        
        passwordInput.returnKeyType = UIReturnKeyNext;
        usernameInput.keyboardType = UIKeyboardTypeAlphabet;
        [usernameInput resignFirstResponder];
        [usernameInput becomeFirstResponder];
    }
    
    self.forgotPasswordButton.hidden = YES;
}

@end
