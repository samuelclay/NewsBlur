//
//  OSKUsernamePasswordViewController.m
//  Overshare
//
//  Created by Jared Sinclair on 10/19/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKUsernamePasswordViewController.h"

#import "OSKUsernamePasswordCell.h"
#import "OSKPresentationManager.h"
#import "UIColor+OSKUtility.h"
#import "OSKAlertView.h"
#import "OSKActivity.h"
#import "OSKActivitiesManager.h"
#import "OSKActivity_ManagedAccounts.h"
#import "OSKActivityIndicatorItem.h"
#import "OSKRPSTPasswordManagementAppService.h"

@interface OSKUsernamePasswordViewController () <OSKUsernamePasswordCellDelegate>

@property (copy, nonatomic) NSString *username;
@property (copy, nonatomic) NSString *password;
@property (copy, nonatomic) NSString *username_placeholder;
@property (copy, nonatomic) NSString *password_placeholder;
@property (assign, nonatomic) BOOL isAttemptingSignIn;
@property (assign, nonatomic) BOOL showOnePasswordButton;

@end

#define USERNAME_ROW 0
#define PASSWORD_ROW 1

#define TEXT_FIELD_SECTION 0
#define ONE_PASSWORD_SECTION 1

@implementation OSKUsernamePasswordViewController

@synthesize activity = _activity;
@synthesize delegate = _delegate;

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        OSKPresentationManager *presMan = [OSKPresentationManager sharedInstance];
        _username_placeholder = [presMan localizedText_Username];
        _password_placeholder = [presMan localizedText_Password];
        _showOnePasswordButton = [OSKRPSTPasswordManagementAppService passwordManagementAppIsAvailable];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
    UIColor *bgColor = [presentationManager color_groupedTableViewBackground];
    self.view.backgroundColor = bgColor;
    self.tableView.backgroundColor = bgColor;
    self.tableView.backgroundView.backgroundColor = bgColor;
    self.tableView.separatorColor = presentationManager.color_separators;
    [self.tableView registerClass:[OSKUsernamePasswordCell class] forCellReuseIdentifier:OSKUsernamePasswordCellIdentifier];
    self.navigationItem.rightBarButtonItem = [self doneButtonItem];
    NSString *cancelTitle = [[OSKPresentationManager sharedInstance] localizedText_Cancel];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:cancelTitle style:UIBarButtonItemStylePlain target:self action:@selector(cancelButtonPressed:)];
    [self updateDoneButton];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (self.showOnePasswordButton) ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger number = 0;
    if (section == TEXT_FIELD_SECTION) {
        number = 2;
    }
    else if (section == ONE_PASSWORD_SECTION) {
        number = 1;
    }
    return number;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = nil;
    if (indexPath.section == TEXT_FIELD_SECTION) {
        OSKUsernamePasswordCell *textFieldCell = [tableView dequeueReusableCellWithIdentifier:OSKUsernamePasswordCellIdentifier forIndexPath:indexPath];
        cell = textFieldCell;
        [textFieldCell setDelegate:self];
        if (indexPath.row == USERNAME_ROW) {
            [textFieldCell setUseSecureInput:NO];
            [textFieldCell setText:self.username];
            [textFieldCell setPlaceholder:self.username_placeholder];
            if ([_activity respondsToSelector:@selector(usernameNomenclatureForSignInScreen)]) {
                OSKUsernameNomenclature nomenclature = [_activity usernameNomenclatureForSignInScreen];
                if (nomenclature & OSKUsernameNomenclature_Email) {
                    [textFieldCell setKeyboardType:UIKeyboardTypeEmailAddress];
                }
                else if (nomenclature & OSKUsernameNomenclature_Username) {
                    [textFieldCell setKeyboardType:UIKeyboardTypeDefault];
                }
            } else {
                [textFieldCell setKeyboardType:UIKeyboardTypeEmailAddress];
            }
        }
        else if (indexPath.row == PASSWORD_ROW) {
            [textFieldCell setKeyboardType:UIKeyboardTypeDefault];
            [textFieldCell setUseSecureInput:YES];
            [textFieldCell setText:self.password];
            [textFieldCell setPlaceholder:self.password_placeholder];
        }
    }
    else if (indexPath.section == ONE_PASSWORD_SECTION) {
        static NSString *onePasswordCellIdentifier = @"onePasswordCellIdentifier";
        cell = [tableView dequeueReusableCellWithIdentifier:onePasswordCellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:onePasswordCellIdentifier];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.text = @"1Password";
            OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
            cell.textLabel.textColor = [presentationManager color_action];
            cell.backgroundColor = [presentationManager color_groupedTableViewCells];
            cell.selectedBackgroundView = [[UIView alloc] init];
            cell.selectedBackgroundView.backgroundColor = [presentationManager color_cancelButtonColor_BackgroundHighlighted];
            UIFontDescriptor *descriptor = [[OSKPresentationManager sharedInstance] normalFontDescriptor];
            if (descriptor) {
                [cell.textLabel setFont:[UIFont fontWithDescriptor:descriptor size:17]];
            }
        }
    }
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == ONE_PASSWORD_SECTION) {
        NSString *query = [self.activity.class activityName];
        NSURL *URL = [OSKRPSTPasswordManagementAppService passwordManagementAppCompleteURLForSearchQuery:query];
        [[UIApplication sharedApplication] openURL:URL];
    }
}

#pragma mark - OSKUsernamePasswordCellDelegate

- (void)usernamePasswordCell:(OSKUsernamePasswordCell *)cell didChangeText:(NSString *)text {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (indexPath.row == USERNAME_ROW) {
        [self setUsername:text];
    }
    else if (indexPath.row == PASSWORD_ROW) {
        [self setPassword:text];
    }
    [self updateDoneButton];
}

- (void)usernamePasswordCellDidTapReturn:(OSKUsernamePasswordCell *)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (indexPath.section == TEXT_FIELD_SECTION) {
        if (indexPath.row == USERNAME_ROW) {
            NSIndexPath *passwordIndexPath = [NSIndexPath indexPathForRow:PASSWORD_ROW inSection:TEXT_FIELD_SECTION];
            OSKUsernamePasswordCell *passwordCell = (OSKUsernamePasswordCell *)[self.tableView cellForRowAtIndexPath:passwordIndexPath];
            [passwordCell.textField becomeFirstResponder];
        }
        else if (indexPath.row == PASSWORD_ROW) {
            if (self.username.length && self.password.length && self.isAttemptingSignIn == NO) {
                [self doneButtonPressed:nil];
            }
        }
    }
}

#pragma mark - Buttons

- (void)updateDoneButton {
    BOOL enable = (self.username.length && self.password.length && self.isAttemptingSignIn == NO);
    [self.navigationItem.rightBarButtonItem setEnabled:enable];
}

- (UIBarButtonItem *)doneButtonItem {
    NSString *title = [[OSKPresentationManager sharedInstance] localizedText_SignIn];
    return [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStyleDone target:self action:@selector(doneButtonPressed:)];
}

- (OSKActivityIndicatorItem *)spinnerViewItem {
    UIActivityIndicatorViewStyle style = (self.navigationController.navigationBar.barStyle == UIBarStyleBlack)
                                        ? UIActivityIndicatorViewStyleWhite
                                        : UIActivityIndicatorViewStyleGray;
    return [OSKActivityIndicatorItem item:style];
}

- (void)setIsAttemptingSignIn:(BOOL)isAttemptingSignIn {
    if (_isAttemptingSignIn != isAttemptingSignIn) {
        _isAttemptingSignIn = isAttemptingSignIn;
        if (_isAttemptingSignIn) {
            OSKActivityIndicatorItem *item = [self spinnerViewItem];
            [self.navigationItem setRightBarButtonItem:item];
            [item startSpinning];
        } else {
            UIBarButtonItem *doneItem = [self doneButtonItem];
            [self.navigationItem setRightBarButtonItem:doneItem];
        }
    }
}

- (void)doneButtonPressed:(id)sender {
    [self authenticateWithUsername:self.username password:self.password completion:^(OSKManagedAccount *account, NSError *error) {
        if (account) {
            [self.delegate authenticationViewController:self didAuthenticateNewAccount:account withActivity:self.activity];
        } else {
            [self showUnableToSignInAlert];
        }
    }];
}

- (void)cancelButtonPressed:(id)sender {
    [self.delegate authenticationViewControllerDidCancel:self withActivity:self.activity];
}

#pragma mark - OSKAuthenticationViewController

- (void)prepareAuthenticationViewForActivity:(OSKActivity<OSKActivity_ManagedAccounts> *)activity delegate:(id<OSKAuthenticationViewControllerDelegate>)delegate {
    _activity = activity;
    _delegate = delegate;
    self.title = [_activity.class activityName];
    
    if ([_activity respondsToSelector:@selector(usernameNomenclatureForSignInScreen)]) {
        OSKUsernameNomenclature nomenclature = [_activity usernameNomenclatureForSignInScreen];
        if (nomenclature & OSKUsernameNomenclature_Username && nomenclature & OSKUsernameNomenclature_Email) {
            OSKPresentationManager *presMan = [OSKPresentationManager sharedInstance];
            NSString *username = presMan.localizedText_Username;
            NSString *email = presMan.localizedText_Email;
            NSString *placeholder = [NSString stringWithFormat:@"%@ | %@", username, email];
            [self setUsername_placeholder:placeholder];
        }
        else if (nomenclature & OSKUsernameNomenclature_Email) {
            [self setUsername_placeholder:[OSKPresentationManager sharedInstance].localizedText_Email];
        }
        else if (nomenclature & OSKUsernameNomenclature_Username) {
            [self setUsername_placeholder:[OSKPresentationManager sharedInstance].localizedText_Username];
        }
    }
}

#pragma mark - Authenticate

- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password completion:(void(^)(OSKManagedAccount *account, NSError *error))completion {
    [self setIsAttemptingSignIn:YES];
    [self.tableView setUserInteractionEnabled:NO];
    OSKApplicationCredential *appCredential = [self.activity.class applicationCredential];
    __weak OSKUsernamePasswordViewController *weakSelf = self;
    [self.activity authenticateNewAccountWithUsername:username password:password appCredential:appCredential completion:^(OSKManagedAccount *account, NSError *error) {
        if (account) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                   completion(account, nil);
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf showUnableToSignInAlert];
                [weakSelf setIsAttemptingSignIn:NO];
                [weakSelf updateDoneButton];
                [weakSelf.tableView setUserInteractionEnabled:YES];
            });
        }
    }];
}

#pragma mark - Convenience

- (void)showUnableToSignInAlert {
    OSKPresentationManager *presMan = [OSKPresentationManager sharedInstance];
    OSKAlertViewButtonItem *okay = [OSKAlertView okayItem];
    NSString *title = [presMan localizedText_UnableToSignIn];
    NSString *message = [presMan localizedText_PleaseDoubleCheckYourUsernameAndPasswordAndTryAgain];
    OSKAlertView *alert = [[OSKAlertView alloc] initWithTitle:title message:message cancelButtonItem:okay otherButtonItems:nil];
    [alert show];
}

@end





