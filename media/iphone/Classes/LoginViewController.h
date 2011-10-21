//
//  LoginViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/31/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"

@class NewsBlurAppDelegate;

@interface LoginViewController : UIViewController 
<UIScrollViewDelegate, ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    UITextField *usernameInput;
    UITextField *passwordInput;
    UITextField *emailInput;
    NSMutableData * jsonString;
    
    UIActivityIndicatorView *activityIndicator;
    UILabel *authenticatingLabel;
    UILabel *errorLabel;
    UISegmentedControl *loginControl;
    
    UILabel *usernameLabel;
    UILabel *usernameOrEmailLabel;
    UILabel *passwordLabel;
    UILabel *emailLabel;
    UILabel *passwordOptionalLabel;
}

- (void)checkPassword;
- (void)registerAccount;
- (IBAction)selectLoginSignup;
- (void)animateLoop;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITextField *usernameInput;
@property (nonatomic, retain) IBOutlet UITextField *passwordInput;
@property (nonatomic, retain) IBOutlet UITextField *emailInput;

@property (nonatomic, retain) NSMutableData * jsonString;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, retain) IBOutlet UILabel *authenticatingLabel;
@property (nonatomic, retain) IBOutlet UILabel *errorLabel;
@property (nonatomic, retain) IBOutlet UISegmentedControl *loginControl;

@property (nonatomic, retain) IBOutlet UILabel *usernameLabel;
@property (nonatomic, retain) IBOutlet UILabel *usernameOrEmailLabel;
@property (nonatomic, retain) IBOutlet UILabel *passwordLabel;
@property (nonatomic, retain) IBOutlet UILabel *emailLabel;
@property (nonatomic, retain) IBOutlet UILabel *passwordOptionalLabel;

@end
