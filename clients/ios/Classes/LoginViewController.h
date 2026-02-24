//
//  LoginViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/31/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlur-Swift.h"

#define LANDSCAPE_MARGIN 128

@interface LoginViewController : BaseViewController <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *usernameInput;
@property (nonatomic, strong) UITextField *passwordInput;
@property (nonatomic, strong) UITextField *emailInput;
@property (nonatomic, strong) UIButton *onePasswordButton;
@property (nonatomic, strong) UIButton *forgotPasswordButton;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UISegmentedControl *loginControl;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) CAGradientLayer *backgroundGradientLayer;

- (void)checkPassword;
- (void)registerAccount;
- (IBAction)tapLoginButton;
- (IBAction)tapSignUpButton;
- (IBAction)forgotPassword:(id)sender;

@end
