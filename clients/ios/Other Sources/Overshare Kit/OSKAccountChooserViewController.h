//
//  OSKAccountChooserViewController.h
//  Overshare
//
//  Created by Jared Sinclair on 10/18/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;
@import Accounts;

@class OSKActivity;
@class OSKManagedAccount;
@class OSKAccountChooserViewController;
@protocol OSKActivity_ManagedAccounts;

@protocol OSKAccountChooserViewControllerDelegate <NSObject>
@optional

- (void)accountChooserDidSelectManagedAccount:(OSKManagedAccount *)managedAccount;
- (void)accountChooserDidSelectSystemAccount:(ACAccount *)systemAccount;

@end

@interface OSKAccountChooserViewController : UITableViewController

- (instancetype)initForManagingAccountsOfActivityClass:(Class)activityClass;

- (instancetype)initWithManagedAccountActivity:(OSKActivity <OSKActivity_ManagedAccounts> *)activity
                                 activeAccount:(OSKManagedAccount *)account
                                      delegate:(id <OSKAccountChooserViewControllerDelegate>)delegate;

- (instancetype)initWithSystemAccounts:(NSArray *)systemAccounts
                         activeAccount:(ACAccount *)account
                 accountTypeIdentifier:(NSString *)accountTypeIdentifier
                              delegate:(id <OSKAccountChooserViewControllerDelegate>)delegate;

@end
