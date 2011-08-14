//
//  LoginViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/31/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface LoginViewController : UIViewController {
    NewsBlurAppDelegate *appDelegate;
    
    UITextField *usernameTextField;
    UITextField *passwordTextField;
    NSMutableData * jsonString;
    
    UIActivityIndicatorView *activityIndicator;
    UILabel *authenticatingLabel;
    UILabel *errorLabel;
}

- (void)checkPassword;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITextField *usernameTextField;
@property (nonatomic, retain) IBOutlet UITextField *passwordTextField;
@property (nonatomic, retain) NSMutableData * jsonString;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, retain) IBOutlet UILabel *authenticatingLabel;
@property (nonatomic, retain) IBOutlet UILabel *errorLabel;

@end
