//
//  OSKAuthenticationViewController.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class OSKActivity;
@class OSKManagedAccount;
@protocol OSKActivity_ManagedAccounts;
@protocol OSKAuthenticationViewController;

// DELEGATE PROTOCOL ======================================================================================

@protocol OSKAuthenticationViewControllerDelegate <NSObject>

- (void)authenticationViewController:(UIViewController <OSKAuthenticationViewController> *)viewController
           didAuthenticateNewAccount:(OSKManagedAccount *)account
                        withActivity:(OSKActivity <OSKActivity_ManagedAccounts>*)activity;

- (void)authenticationViewControllerDidCancel:(UIViewController <OSKAuthenticationViewController> *)viewController
                                 withActivity:(OSKActivity <OSKActivity_ManagedAccounts> *)activity;

@end

// VIEW CONTROLLER PROTOCOL ===============================================================================

@protocol OSKAuthenticationViewController <NSObject>

@property (weak, nonatomic) id <OSKAuthenticationViewControllerDelegate> delegate;
@property (strong, nonatomic, readonly) OSKActivity <OSKActivity_ManagedAccounts> *activity;

- (void)prepareAuthenticationViewForActivity:(OSKActivity <OSKActivity_ManagedAccounts> *)activity delegate:(id <OSKAuthenticationViewControllerDelegate>)delegate;

@end






