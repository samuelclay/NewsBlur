//
//  LoginViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/31/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "LoginViewController.h"
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
    self.appDelegate = NewsBlurAppDelegate.sharedAppDelegate;
    
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    
    self.usernameInput.borderStyle = UITextBorderStyleRoundedRect;
    self.passwordInput.borderStyle = UITextBorderStyleRoundedRect;
    self.emailInput.borderStyle = UITextBorderStyleRoundedRect;
    self.signUpPasswordInput.borderStyle = UITextBorderStyleRoundedRect;
    self.signUpUsernameInput.borderStyle = UITextBorderStyleRoundedRect;
    
    self.usernameInput.textContentType = UITextContentTypeUsername;
    self.passwordInput.textContentType = UITextContentTypePassword;
    self.emailInput.textContentType = UITextContentTypeEmailAddress;
    
    [self.loginControl
     setTitleTextAttributes:@{NSFontAttributeName:
                                  [UIFont fontWithName:@"WhitneySSm-Medium" size:12.0f]}
     forState:UIControlStateNormal];

    //[self.onePasswordButton setHidden:![[OnePasswordExtension sharedExtension] isAppExtensionAvailable]];
    
    [super viewDidLoad];
}

- (CGFloat)xForWidth:(CGFloat)width {
    return (self.view.bounds.size.width / 2) - (width / 2);
}

- (void)rearrangeViews {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        CGSize viewSize = self.view.bounds.size;
        CGFloat viewWidth = viewSize.width;
        CGFloat yOffset = 0;
        CGFloat xOffset = isOnSignUpScreen ? -viewWidth : 0;
        
        if (UIInterfaceOrientationIsPortrait(self.view.window.windowScene.interfaceOrientation)) {
            yOffset = viewSize.height / 6;
        }
        
        self.buttonsView.frame = CGRectMake([self xForWidth:518], 15 + yOffset, 518, 66);
        self.logInView.frame = CGRectMake([self xForWidth:500] + xOffset, 75 + yOffset, 500, 300);
        self.signUpView.frame = CGRectMake([self xForWidth:500] + viewWidth + xOffset, 75 + yOffset, 500, 300);
        self.errorLabel.frame = CGRectMake([self xForWidth:self.errorLabel.frame.size.width], 75 + yOffset, self.errorLabel.frame.size.width, self.errorLabel.frame.size.height);
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [self showError:nil];
    [super viewWillAppear:animated];
    [usernameInput becomeFirstResponder];
}

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//    // Return YES for supported orientations
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        return YES;
//    }
//    return NO;
//}

- (void)viewDidAppear:(BOOL)animated {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [super viewDidAppear:animated];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [self updateControls];
        [self rearrangeViews];
    }
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

//- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
//    [self rearrangeViews];
//}

- (void)showError:(NSString *)error {
    BOOL hasError = error.length > 0;
    
    if (hasError) {
        self.errorLabel.text = error;
    }
    
    self.errorLabel.hidden = !hasError;
    self.forgotPasswordButton.hidden = !hasError;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
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
        [self.passwordInput becomeFirstResponder];
        self.passwordInput.text = loginDictionary[AppExtensionPasswordKey];
    }];
}

#pragma mark -
#pragma mark Login

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if  ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
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
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[usernameInput text] forKey:@"username"];
    [params setObject:[passwordInput text] forKey:@"password"];
    [params setObject:@"login" forKey:@"submit"];
    [params setObject:@"1" forKey:@"api"];

    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];

        int code = [[responseObject valueForKey:@"code"] intValue];
        if (code == -1) {
            NSDictionary *errors = [responseObject valueForKey:@"errors"];
            if ([errors valueForKey:@"username"]) {
                [self showError:[[errors valueForKey:@"username"] firstObject]];
            } else if ([errors valueForKey:@"__all__"]) {
                [self showError:[[errors valueForKey:@"__all__"] firstObject]];
            }
        } else {
            [self.passwordInput setText:@""];
            [self.signUpPasswordInput setText:@""];
            [self.appDelegate reloadFeedsView:YES];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}


- (void)registerAccount {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Registering...";
    [self showError:nil];
    NSString *urlString = [NSString stringWithFormat:@"%@/api/signup",
                           self.appDelegate.url];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [params setObject:[signUpUsernameInput text] forKey:@"username"];
        [params setObject:[signUpPasswordInput text] forKey:@"password"];
    } else {
        [params setObject:[usernameInput text] forKey:@"username"];
        [params setObject:[passwordInput text] forKey:@"password"];
    }
    [params setObject:[emailInput text] forKey:@"email"];
    [params setObject:@"login" forKey:@"submit"];
    [params setObject:@"1" forKey:@"api"];
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];

        int code = [[responseObject valueForKey:@"code"] intValue];
        if (code == -1) {
            NSDictionary *errors = [responseObject valueForKey:@"errors"];
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
            [self.appDelegate reloadFeedsView:YES];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];

}

- (void)requestFailed:(NSError *)error {
    NSLog(@"Error: %@", error);
    [appDelegate informError:error];
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (IBAction)forgotPassword:(id)sender {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/folder_rss/forgot_password", appDelegate.url]];
    SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url];
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
            self.usernameInput.frame = CGRectMake(20, 67, width-margin*2, 31);
            self.usernameOrEmailLabel.alpha = 1.0;
            self.usernameLabel.alpha = 0.0;
            
            self.passwordInput.frame = CGRectMake(20, 129, width-margin*2, 31);
            self.passwordLabel.frame = CGRectMake(21, 106, 212, 22);
            self.passwordOptionalLabel.frame = CGRectMake(width-margin-101, 112, 101, 16);
            
            self.emailInput.alpha = 0.0;
            self.emailLabel.alpha = 0.0;
            
            self.onePasswordButton.frame = CGRectMake(20+ self.passwordInput.frame.size.width - 31, 129, 31, 31);
            self.onePasswordButton.alpha = 1.0;
        }];
        
        self.passwordInput.returnKeyType = UIReturnKeyGo;
        self.usernameInput.keyboardType = UIKeyboardTypeEmailAddress;
        [self.usernameInput resignFirstResponder];
        [self.usernameInput becomeFirstResponder];
    } else {
        [UIView animateWithDuration:0.5 animations:^{
            // Signup
            self.usernameInput.frame = CGRectMake(20, 67, width/2-margin*2, 31);
            self.usernameOrEmailLabel.alpha = 0.0;
            self.usernameLabel.alpha = 1.0;
            
            self.passwordInput.frame = CGRectMake(width/2+margin, 67, width/2-margin*2, 31);
            self.passwordLabel.frame = CGRectMake(width/2+margin, 44, 212, 22);
            self.passwordOptionalLabel.frame = CGRectMake(width-margin-101, 50, 101, 16);
            
            self.emailInput.alpha = 1.0;
            self.emailLabel.alpha = 1.0;
            
            self.onePasswordButton.frame = CGRectMake(width/2+margin + self.passwordInput.frame.size.width - 31, 67, 31, 31);
            self.onePasswordButton.alpha = 0.0; // Don't want to deal with registration yet.
        }];        
        self.passwordInput.returnKeyType = UIReturnKeyNext;
        self.usernameInput.keyboardType = UIKeyboardTypeAlphabet;
        [self.usernameInput resignFirstResponder];
        [self.usernameInput becomeFirstResponder];
    }
    
    self.forgotPasswordButton.hidden = YES;
}

@end
