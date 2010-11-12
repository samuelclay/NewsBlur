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
}

- (void)checkPassword;

@property (nonatomic, retain) NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITextField *usernameTextField;
@property (nonatomic, retain) IBOutlet UITextField *passwordTextField;
@property (nonatomic, retain) NSMutableData * jsonString;

@end
