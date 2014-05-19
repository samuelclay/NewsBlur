//
//  OSKAccountChooserViewController.m
//  Overshare
//
//  Created by Jared Sinclair on 10/18/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKAccountChooserViewController.h"

#import "OSKActivity.h"
#import "OSKManagedAccount.h"
#import "OSKPresentationManager.h"
#import "OSKAuthenticationViewController.h"
#import "OSKManagedAccountStore.h"
#import "OSKSystemAccountStore.h"
#import "OSKNavigationController.h"
#import "OSKActivity_ManagedAccounts.h"
#import "OSKLogger.h"
#import "OSKActionSheet.h"

@interface OSKAccountChooserViewController () <OSKAuthenticationViewControllerDelegate>


// SELECTING ACCOUNTS FOR ACTIVITIES
@property (copy, nonatomic) OSKActivity <OSKActivity_ManagedAccounts> *managedAccountActivity;
@property (strong, nonatomic) ACAccount *selectedSystemAccount;
@property (copy, nonatomic) NSString *systemAccountTypeIdentifier;
@property (strong, nonatomic) OSKManagedAccount *selectedManagedAccount;
@property (weak, nonatomic) id <OSKAccountChooserViewControllerDelegate> delegate;

// GENERAL ACCOUNT MANAGEMENT
@property (assign, nonatomic) OSKAuthenticationMethod authenticationMethod;
@property (strong, nonatomic) NSMutableArray *accounts;
@property (assign, nonatomic) BOOL allowsEditing;
@property (assign, nonatomic) BOOL allowsSelection;


@end

@implementation OSKAccountChooserViewController

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
    }
    return self;
}

- (instancetype)initForManagingAccountsOfActivityClass:(Class)activityClass {
    NSAssert([activityClass isSubclassOfClass:[OSKActivity class]], @"OSKAccountChooserViewController requires an OSKActivity subclass passed to initForManagingAccountsOfActivityClass:");
    NSAssert([activityClass authenticationMethod] == OSKAuthenticationMethod_ManagedAccounts, @"OSKAccountChooserViewController requires a subclass of OSKActivity that conforms to OSKActivity_ManagedAccounts");
    self = [self initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = [activityClass activityName];
        _authenticationMethod = OSKAuthenticationMethod_ManagedAccounts;
        _accounts = [[[OSKManagedAccountStore sharedInstance] accountsForActivityType:[activityClass activityType]] mutableCopy];
        _managedAccountActivity = [[activityClass alloc] initWithContentItem:nil];
        _allowsEditing = YES;
        _allowsSelection = YES;
        _selectedManagedAccount = [[OSKManagedAccountStore sharedInstance] activeAccountForActivityType:[activityClass activityType]];
        NSString *addTitle = [OSKPresentationManager sharedInstance].localizedText_Add;
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:addTitle
                                                                                  style:UIBarButtonItemStyleBordered
                                                                                 target:self
                                                                                 action:@selector(addAccountButtonPressed:)];
    }
    return self;
}

- (instancetype)initWithManagedAccountActivity:(OSKActivity <OSKActivity_ManagedAccounts> *)activity
                                 activeAccount:(OSKManagedAccount *)account
                                      delegate:(id<OSKAccountChooserViewControllerDelegate>)delegate {
    self = [self initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = [[OSKPresentationManager sharedInstance] localizedText_Accounts];
        _managedAccountActivity = activity;
        _authenticationMethod = OSKAuthenticationMethod_ManagedAccounts;
        _accounts = [[[OSKManagedAccountStore sharedInstance] accountsForActivityType:[activity.class activityType]] mutableCopy];
        _selectedManagedAccount = account;
        _delegate = delegate;
        _allowsEditing = YES;
        _allowsSelection = YES;
        NSString *addTitle = [OSKPresentationManager sharedInstance].localizedText_Add;
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:addTitle
                                                                                  style:UIBarButtonItemStyleBordered
                                                                                 target:self
                                                                                 action:@selector(addAccountButtonPressed:)];
    }
    return self;
}

- (instancetype)initWithSystemAccounts:(NSArray *)systemAccounts
                         activeAccount:(ACAccount *)account
                 accountTypeIdentifier:(NSString *)accountTypeIdentifier
                              delegate:(id<OSKAccountChooserViewControllerDelegate>)delegate {
    
    self = [self initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = [[OSKPresentationManager sharedInstance] localizedText_Accounts];
        _authenticationMethod = OSKAuthenticationMethod_SystemAccounts;
        _accounts = systemAccounts.mutableCopy;
        _selectedSystemAccount = account;
        _delegate = delegate;
        _allowsEditing = NO;
        _allowsSelection = YES;
        _systemAccountTypeIdentifier = [accountTypeIdentifier copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
    UIColor *bgColor = [presentationManager color_opaqueBackground];
    self.view.backgroundColor = bgColor;
    self.tableView.backgroundColor = bgColor;
    self.tableView.backgroundView.backgroundColor = bgColor;
    self.tableView.separatorColor = presentationManager.color_separators;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.accounts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
        UIColor *bgColor = [presentationManager color_opaqueBackground];
        cell.backgroundColor = bgColor;
        cell.backgroundView.backgroundColor = bgColor;
        cell.textLabel.textColor = [presentationManager color_text];
        cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.bounds];
        cell.selectedBackgroundView.backgroundColor = presentationManager.color_cancelButtonColor_BackgroundHighlighted;
        cell.tintColor = presentationManager.color_action;
        UIFontDescriptor *descriptor = [[OSKPresentationManager sharedInstance] normalFontDescriptor];
        if (descriptor) {
            [cell.textLabel setFont:[UIFont fontWithDescriptor:descriptor size:17]];
        } else {
            [cell.textLabel setFont:[UIFont systemFontOfSize:17]];
        }
    }
    if (self.authenticationMethod == OSKAuthenticationMethod_SystemAccounts) {
        ACAccount *account = [self.accounts objectAtIndex:indexPath.row];
        NSString *name = (account.username.length) ? account.username : account.userFullName;
        [cell.textLabel setText:name];
        if ([account.identifier isEqualToString:self.selectedSystemAccount.identifier]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    else if (self.authenticationMethod == OSKAuthenticationMethod_ManagedAccounts) {
        OSKManagedAccount *account = [self.accounts objectAtIndex:indexPath.row];
        NSString *name = [account nonNilDisplayName];
        [cell.textLabel setText:name];
        if (account == self.selectedManagedAccount) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.allowsSelection) {
        if (self.authenticationMethod == OSKAuthenticationMethod_ManagedAccounts) {
            OSKManagedAccount *account = [self.accounts objectAtIndex:indexPath.row];
            if (account != self.selectedManagedAccount) {
                [self setSelectedManagedAccount:account];
                [self.tableView reloadData];
                [self.delegate accountChooserDidSelectManagedAccount:account];
            }
        }
        else if (self.authenticationMethod == OSKAuthenticationMethod_SystemAccounts) {
            ACAccount *account = [self.accounts objectAtIndex:indexPath.row];
            if ([account.identifier isEqualToString:self.selectedSystemAccount.identifier] == NO) {
                [self setSelectedSystemAccount:account];
                [self.tableView reloadData];
                [self.delegate accountChooserDidSelectSystemAccount:account];
            }
        }
        // A tiny delay feels less jarring...
        __weak OSKAccountChooserViewController *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [weakSelf.navigationController popViewControllerAnimated:YES];
        });
    } else {
        [self showAccountSignOutActionSheet:indexPath];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self allowsEditing];
}

 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
     if ([self allowsEditing]) {
         if (editingStyle == UITableViewCellEditingStyleDelete) {
             OSKManagedAccount *account = self.accounts[indexPath.row];
             OSKManagedAccountStore *store = [OSKManagedAccountStore sharedInstance];
             [store removeAccount:account forActivityType:account.activityType];
             [self.accounts removeObject:account];
             
             if (self.allowsSelection) {
                 OSKManagedAccount *newActiveAccount = [self.accounts firstObject];
                 if (newActiveAccount != self.selectedManagedAccount) {
                     [self setSelectedManagedAccount:newActiveAccount];
                     [self.delegate accountChooserDidSelectManagedAccount:newActiveAccount];
                 }
                 [CATransaction begin];
                 __weak OSKAccountChooserViewController *weakSelf = self;
                 [CATransaction setCompletionBlock:^{
                     if (weakSelf.selectedManagedAccount) {
                         NSInteger index = [weakSelf.accounts indexOfObject:weakSelf.selectedManagedAccount];
                         NSIndexPath *indexPathToUpdate = [NSIndexPath indexPathForRow:index inSection:0];
                         [weakSelf.tableView reloadRowsAtIndexPaths:@[indexPathToUpdate] withRowAnimation:UITableViewRowAnimationNone];
                     }
                 }];
                 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                 [CATransaction commit];
             } else {
                 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
             }
         }
     }
 }

#pragma mark - Add Accounts

- (void)addAccountButtonPressed:(id)sender {
    OSKManagedAccountAuthenticationViewControllerType type;
    type = [self.managedAccountActivity.class authenticationViewControllerType];
    if (type == OSKManagedAccountAuthenticationViewControllerType_None) {
        [self authenticateNewAccountWithoutViewController];
    } else {
        [self showAuthViewController];
    }
}

- (void)authenticateNewAccountWithoutViewController {
    __weak OSKAccountChooserViewController *weakSelf = self;
    [self.managedAccountActivity authenticateNewAccountWithoutViewController:^(OSKManagedAccount *account, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (account) {
                [weakSelf handleNewManagedAccount:account];
            } else {
                OSKLog(@"Failed to add new account: %@", error.localizedDescription);
            }
        });
    }];
}

- (void)showAuthViewController {
    OSKPresentationManager *presManager = [OSKPresentationManager sharedInstance];
    UIViewController <OSKAuthenticationViewController> *authViewController = [presManager authenticationViewControllerForActivity:self.managedAccountActivity];
    [authViewController prepareAuthenticationViewForActivity:self.managedAccountActivity delegate:self];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        OSKNavigationController *navController = [[OSKNavigationController alloc] initWithRootViewController:authViewController];
        [self presentViewController:navController animated:YES completion:nil];
    } else {
        [self.navigationController pushViewController:authViewController animated:YES];
    }
}

- (void)handleNewManagedAccount:(OSKManagedAccount *)account {
    OSKManagedAccountStore *accountStore = [OSKManagedAccountStore sharedInstance];
    [accountStore addAccount:account forActivityType:[self.managedAccountActivity.class activityType]];
    _accounts = [[accountStore accountsForActivityType:[self.managedAccountActivity.class activityType]] mutableCopy];
    
    if (self.allowsSelection) {
        [self setSelectedManagedAccount:account];
        [self.tableView reloadData];
        [self.delegate accountChooserDidSelectManagedAccount:account];
    } else {
        [self.tableView reloadData];
    }
}

- (void)showAccountSignOutActionSheet:(NSIndexPath *)indexPath {
    __weak OSKAccountChooserViewController *weakSelf = self;
    OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
    NSString *removeTitle = [presentationManager localizedText_SignOut];
    OSKManagedAccount *account = weakSelf.accounts[indexPath.row];

    OSKActionSheetButtonItem *removeItem = [[OSKActionSheetButtonItem alloc] initWithTitle:removeTitle actionBlock:^{
        OSKManagedAccountStore *store = [OSKManagedAccountStore sharedInstance];
        [store removeAccount:account forActivityType:account.activityType];
        [weakSelf.accounts removeObject:account];
        [weakSelf.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }];
    
    OSKActionSheetButtonItem *cancelItem = [OSKActionSheet cancelItem];
    
    OSKActionSheet *sheet = [[OSKActionSheet alloc] initWithTitle:[account nonNilDisplayName] cancelButtonItem:cancelItem destructiveButtonItem:removeItem otherButtonItems:nil];
    [sheet showInView:self.view];
}

#pragma mark - Selected Accounts

- (void)setSelectedManagedAccount:(OSKManagedAccount *)selectedManagedAccount {
    _selectedManagedAccount = selectedManagedAccount;
    if (_selectedManagedAccount) {
        [[OSKManagedAccountStore sharedInstance] setActiveAccount:_selectedManagedAccount forActivityType:_selectedManagedAccount.activityType];
    }
}

- (void)setSelectedSystemAccount:(ACAccount *)selectedSystemAccount {
    _selectedSystemAccount = selectedSystemAccount;
    if (_selectedSystemAccount) {
        [[OSKSystemAccountStore sharedInstance] setLastUsedAccountIdentifier:_selectedSystemAccount.identifier
                                                                     forType:self.systemAccountTypeIdentifier];
    }
}

#pragma mark - Authentication View Controller Delegate

- (void)authenticationViewController:(UIViewController <OSKAuthenticationViewController> *)viewController didAuthenticateNewAccount:(OSKManagedAccount *)account withActivity:(OSKActivity <OSKActivity_ManagedAccounts>*)activity {
    [self handleNewManagedAccount:account];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [viewController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)authenticationViewControllerDidCancel:(UIViewController <OSKAuthenticationViewController> *)viewController withActivity:(OSKActivity <OSKActivity_ManagedAccounts> *)activity {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [viewController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}


@end






