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


- (instancetype)init {
    if (self = [super init]) {
        // Initialization code here if needed
    }
    return self;
}

- (void)loadView {
    [super loadView];

    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // Create scroll view for keyboard handling
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];

    // Content view
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];

    // Logo/Header
    UIImageView *logoImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"logo_newsblur_512"]];
    logoImageView.contentMode = UIViewContentModeScaleAspectFit;
    logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:logoImageView];

    // Welcome label
    UILabel *welcomeLabel = [[UILabel alloc] init];
    welcomeLabel.text = @"Welcome to NewsBlur";
    welcomeLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    welcomeLabel.textAlignment = NSTextAlignmentCenter;
    welcomeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:welcomeLabel];

    // Segmented control for Login/Sign Up
    self.loginControl = [[UISegmentedControl alloc] initWithItems:@[@"Log In", @"Sign Up"]];
    self.loginControl.selectedSegmentIndex = 0;
    self.loginControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.loginControl addTarget:self action:@selector(selectLoginSignup) forControlEvents:UIControlEventValueChanged];
    [contentView addSubview:self.loginControl];

    // Username field
    self.usernameInput = [self createTextField:@"Username or Email" isSecure:NO];
    self.usernameInput.textContentType = UITextContentTypeUsername;
    self.usernameInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.usernameInput.keyboardType = UIKeyboardTypeEmailAddress;
    [contentView addSubview:self.usernameInput];

    // Password field
    self.passwordInput = [self createTextField:@"Password" isSecure:YES];
    self.passwordInput.textContentType = UITextContentTypePassword;
    [contentView addSubview:self.passwordInput];

    // Email field (for sign up)
    self.emailInput = [self createTextField:@"Email" isSecure:NO];
    self.emailInput.textContentType = UITextContentTypeEmailAddress;
    self.emailInput.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.emailInput.alpha = 0;
    [contentView addSubview:self.emailInput];

    // Submit button
    UIButton *submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [submitButton setTitle:@"Log In" forState:UIControlStateNormal];
    submitButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    submitButton.backgroundColor = UIColorFromFixedRGB(NEWSBLUR_LINK_COLOR);
    [submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    submitButton.layer.cornerRadius = 12;
    submitButton.translatesAutoresizingMaskIntoConstraints = NO;
    [submitButton addTarget:self action:@selector(submitAction:) forControlEvents:UIControlEventTouchUpInside];
    submitButton.tag = 100;
    [contentView addSubview:submitButton];

    // Error label
    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.textColor = [UIColor systemRedColor];
    self.errorLabel.font = [UIFont systemFontOfSize:14];
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.hidden = YES;
    [contentView addSubview:self.errorLabel];

    // Forgot password button
    self.forgotPasswordButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.forgotPasswordButton setTitle:@"Forgot Password?" forState:UIControlStateNormal];
    self.forgotPasswordButton.titleLabel.font = [UIFont systemFontOfSize:14];
    self.forgotPasswordButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.forgotPasswordButton addTarget:self action:@selector(forgotPassword:) forControlEvents:UIControlEventTouchUpInside];
    self.forgotPasswordButton.hidden = YES;
    [contentView addSubview:self.forgotPasswordButton];

    // 1Password button
    self.onePasswordButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.onePasswordButton setImage:[UIImage imageNamed:@"onepassword-button"] forState:UIControlStateNormal];
    self.onePasswordButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.onePasswordButton addTarget:self action:@selector(findLoginFrom1Password:) forControlEvents:UIControlEventTouchUpInside];
    self.onePasswordButton.hidden = ![[OnePasswordExtension sharedExtension] isAppExtensionAvailable];
    [contentView addSubview:self.onePasswordButton];

    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Scroll view
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        // Content view
        [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],

        // Logo
        [logoImageView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:60],
        [logoImageView.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [logoImageView.widthAnchor constraintEqualToConstant:120],
        [logoImageView.heightAnchor constraintEqualToConstant:120],

        // Welcome label
        [welcomeLabel.topAnchor constraintEqualToAnchor:logoImageView.bottomAnchor constant:20],
        [welcomeLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:40],
        [welcomeLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-40],

        // Segmented control
        [self.loginControl.topAnchor constraintEqualToAnchor:welcomeLabel.bottomAnchor constant:30],
        [self.loginControl.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:40],
        [self.loginControl.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-40],
        [self.loginControl.heightAnchor constraintEqualToConstant:32],

        // Username field
        [self.usernameInput.topAnchor constraintEqualToAnchor:self.loginControl.bottomAnchor constant:30],
        [self.usernameInput.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:40],
        [self.usernameInput.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-40],
        [self.usernameInput.heightAnchor constraintEqualToConstant:50],

        // Password field
        [self.passwordInput.topAnchor constraintEqualToAnchor:self.usernameInput.bottomAnchor constant:16],
        [self.passwordInput.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:40],
        [self.passwordInput.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-40],
        [self.passwordInput.heightAnchor constraintEqualToConstant:50],

        // Email field
        [self.emailInput.topAnchor constraintEqualToAnchor:self.passwordInput.bottomAnchor constant:16],
        [self.emailInput.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:40],
        [self.emailInput.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-40],
        [self.emailInput.heightAnchor constraintEqualToConstant:50],

        // Submit button
        [submitButton.topAnchor constraintEqualToAnchor:self.emailInput.bottomAnchor constant:30],
        [submitButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:40],
        [submitButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-40],
        [submitButton.heightAnchor constraintEqualToConstant:50],

        // Error label
        [self.errorLabel.topAnchor constraintEqualToAnchor:submitButton.bottomAnchor constant:16],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:40],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-40],

        // Forgot password button
        [self.forgotPasswordButton.topAnchor constraintEqualToAnchor:self.errorLabel.bottomAnchor constant:8],
        [self.forgotPasswordButton.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],

        // 1Password button
        [self.onePasswordButton.trailingAnchor constraintEqualToAnchor:self.passwordInput.trailingAnchor constant:-8],
        [self.onePasswordButton.centerYAnchor constraintEqualToAnchor:self.passwordInput.centerYAnchor],
        [self.onePasswordButton.widthAnchor constraintEqualToConstant:32],
        [self.onePasswordButton.heightAnchor constraintEqualToConstant:32],

        // Content view bottom
        [contentView.bottomAnchor constraintEqualToAnchor:self.forgotPasswordButton.bottomAnchor constant:40]
    ]];

    // Set up text field delegates
    self.usernameInput.delegate = self;
    self.passwordInput.delegate = self;
    self.emailInput.delegate = self;
}

- (UITextField *)createTextField:(NSString *)placeholder isSecure:(BOOL)isSecure {
    UITextField *textField = [[UITextField alloc] init];
    textField.placeholder = placeholder;
    textField.borderStyle = UITextBorderStyleNone;
    textField.backgroundColor = [UIColor secondarySystemBackgroundColor];
    textField.layer.cornerRadius = 12;
    textField.font = [UIFont systemFontOfSize:16];
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.returnKeyType = UIReturnKeyNext;
    textField.secureTextEntry = isSecure;
    textField.translatesAutoresizingMaskIntoConstraints = NO;

    // Add padding
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 0)];
    textField.leftView = paddingView;
    textField.leftViewMode = UITextFieldViewModeAlways;
    textField.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 0)];
    textField.rightViewMode = UITextFieldViewModeAlways;

    return textField;
}

- (void)submitAction:(UIButton *)sender {
    if (self.loginControl.selectedSegmentIndex == 0) {
        [self tapLoginButton];
    } else {
        [self tapSignUpButton];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
}


- (void)viewWillAppear:(BOOL)animated {
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;

    [self showError:nil];
    [super viewWillAppear:animated];

    // Register for keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    [self.usernameInput becomeFirstResponder];
}

- (void)viewDidAppear:(BOOL)animated {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    // Unregister for keyboard notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];

    [[ThemeManager themeManager] systemAppearanceDidChange:self.appDelegate.feedsViewController.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGSize keyboardSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;

    UIScrollView *scrollView = (UIScrollView *)self.view.subviews.firstObject;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height, 0.0);
    scrollView.contentInset = contentInsets;
    scrollView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIScrollView *scrollView = (UIScrollView *)self.view.subviews.firstObject;
    scrollView.contentInset = UIEdgeInsetsZero;
    scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
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

    if (textField == self.usernameInput) {
        [self.passwordInput becomeFirstResponder];
    } else if (textField == self.passwordInput && [self.loginControl selectedSegmentIndex] == 0) {
        [self checkPassword];
    } else if (textField == self.passwordInput && [self.loginControl selectedSegmentIndex] == 1) {
        [self.emailInput becomeFirstResponder];
    } else if (textField == self.emailInput) {
        [self registerAccount];
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
    [params setObject:[self.usernameInput text] forKey:@"username"];
    [params setObject:[self.passwordInput text] forKey:@"password"];
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
    [params setObject:[self.usernameInput text] forKey:@"username"];
    [params setObject:[self.passwordInput text] forKey:@"password"];
    [params setObject:[self.emailInput text] forKey:@"email"];
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
    BOOL isLogin = [self.loginControl selectedSegmentIndex] == 0;

    // Update submit button title
    UIButton *submitButton = [self.view viewWithTag:100];
    [submitButton setTitle:(isLogin ? @"Log In" : @"Sign Up") forState:UIControlStateNormal];

    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        if (isLogin) {
            // Login mode
            self.usernameInput.placeholder = @"Username or Email";
            self.usernameInput.keyboardType = UIKeyboardTypeEmailAddress;
            self.passwordInput.returnKeyType = UIReturnKeyGo;
            self.emailInput.alpha = 0.0;
            self.onePasswordButton.alpha = 1.0;
        } else {
            // Sign up mode
            self.usernameInput.placeholder = @"Username";
            self.usernameInput.keyboardType = UIKeyboardTypeDefault;
            self.passwordInput.returnKeyType = UIReturnKeyNext;
            self.emailInput.alpha = 1.0;
            self.onePasswordButton.alpha = 0.0;
        }
    } completion:^(BOOL finished) {
        [self.usernameInput becomeFirstResponder];
    }];

    [self showError:nil];
}

@end
