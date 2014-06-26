//
//  OSKSessionController.m
//  Overshare
//
//  Created by Jared Sinclair on 10/11/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Accounts;

#import "OSKSessionController.h"

#import "OSKActivitiesManager.h"
#import "OSKActivity.h"
#import "OSKActivity_SystemAccounts.h"
#import "OSKActivity_GenericAuthentication.h"
#import "OSKActivity_ManagedAccounts.h"
#import "OSKActivitySheetViewController.h"
#import "OSKAppDotNetActivity.h"
#import "OSKAuthenticationViewController.h"
#import "OSKLogger.h"
#import "OSKPublishingViewController.h"
#import "OSKPurchasingViewController.h"
#import "OSKPresentationManager.h"
#import "OSKManagedAccount.h"
#import "OSKManagedAccountStore.h"
#import "OSKSystemAccountStore.h"
#import "OSKAlertView.h"
#import "OSKSession.h"
#import "OSKURLSchemeActivity.h"

@interface OSKSessionController ()
<
    OSKPurchasingViewControllerDelegate,
    OSKAuthenticationViewControllerDelegate,
    OSKPublishingViewControllerDelegate
>

@property (strong, nonatomic, readwrite) OSKSession *session;
@property (  weak, nonatomic, readwrite) id <OSKSessionControllerDelegate> delegate;
@property (strong, nonatomic, readwrite) OSKActivity *activity;

@end

@implementation OSKSessionController

- (instancetype)initWithActivity:(OSKActivity *)activity
                         session:(OSKSession *)session
                        delegate:(id<OSKSessionControllerDelegate>)delegate {
    
    self = [super init];
    if (self) {
        _session = session;
        _delegate = delegate;
        _activity = activity;
    }
    return self;
}

#pragma mark - Tapped Activity Flow

- (void)start {
    [self handlePurchasingStepForActivity:self.activity];
}

- (void)handlePurchasingStepForActivity:(OSKActivity *)activity {
    if ([activity requiresPurchase]) {
        if ([activity isAlreadyPurchased]) {
            [self handleAuthenticationStepForActivity:activity];
        } else {
            [self showPurchasingViewControllerForActivity:activity];
        }
    }
    else {
        [self handleAuthenticationStepForActivity:activity];
    }
}

- (void)handleAuthenticationStepForActivity:(OSKActivity *)activity {
    OSKAuthenticationMethod authenticationMethod = [activity.class authenticationMethod];
    if (authenticationMethod == OSKAuthenticationMethod_ManagedAccounts) {
        [self handleManagedAccountAuthenticationStepForActivity:activity];
    }
    else if (authenticationMethod == OSKAuthenticationMethod_SystemAccounts) {
        [self handleSystemAccountAuthenticationStepForActivity:activity];
    }
    else if (authenticationMethod == OSKAuthenticationMethod_Generic) {
        [self handleGenericAuthenticationStepForActivity:activity];
    }
    else {
        [self handlePublishingStepForActivity:activity];
    }
}

- (void)handleSystemAccountAuthenticationStepForActivity:(OSKActivity *)activity {
    NSAssert([activity respondsToSelector:@selector(activeSystemAccount)], @"OSKActivity subclasses using the system account authentication method must conform to the OSKActivity_SystemAccounts protocol.");
    OSKActivity <OSKActivity_SystemAccounts> *theActivity = (OSKActivity <OSKActivity_SystemAccounts> *)activity;
    
    if ([[[theActivity class] activityType] isEqualToString:OSKActivityType_iOS_Facebook]) {
        // Facebook accounts must request for read permissions before asking for write permissions
        // (which is a maddening API decision). Thus, we must use a separate flow for Facebook authentication.
        [self handleFacebookAccountAuthenticationStepForActivity:theActivity];
    }
    else {
        OSKSystemAccountStore *accountStore = [OSKSystemAccountStore sharedInstance];
        NSString *systemAccountTypeIdentifier = [theActivity.class systemAccountTypeIdentifier];
        NSArray *existingAccounts = [accountStore accountsForAccountTypeIdentifier:systemAccountTypeIdentifier];
        NSString *lastUsedAccountID = [accountStore lastUsedAccountIdentifierForType:systemAccountTypeIdentifier];

        if (existingAccounts.count > 0) {
            ACAccount *account = nil;
            for (ACAccount *anAccount in existingAccounts) {
                if ([anAccount.identifier isEqualToString:lastUsedAccountID]) {
                    account = anAccount;
                    break;
                }
            }
            if (account == nil) {
                account = [existingAccounts firstObject];
            }
            [theActivity setActiveSystemAccount:account];
            [self handlePublishingStepForActivity:activity];
        }
        else {
            __weak OSKSessionController *weakSelf = self;
            NSString *systemAccountTypeIdentifier = [theActivity.class systemAccountTypeIdentifier];
            [accountStore requestAccessToAccountsWithAccountTypeIdentifier:systemAccountTypeIdentifier options:nil completion:^(BOOL successful, NSError *error) {
                if (successful) {
                    NSArray *systemAccounts = [accountStore accountsForAccountTypeIdentifier:systemAccountTypeIdentifier];
                    if (systemAccounts.count > 0) {
                        ACAccount *account = [systemAccounts firstObject];
                        [theActivity setActiveSystemAccount:account];
                        [weakSelf handlePublishingStepForActivity:activity];
                    } else {
                        [weakSelf showAlertForNoSystemAccounts];
                        OSKLog(@"User has no existing system accounts with account type identifier: %@", systemAccountTypeIdentifier);
                        [weakSelf cancel];
                    }
                }
                else {
                    [weakSelf showAlertForSystemAccountAccessNotGranted];
                    OSKLog(@"User denied access to system accounts with account type identifier: %@", systemAccountTypeIdentifier);
                    [weakSelf cancel];
                }
            }];
        }
    }
}

- (void)handleFacebookAccountAuthenticationStepForActivity:(OSKActivity <OSKActivity_SystemAccounts>*)activity {
    NSAssert([[[activity class] activityType] isEqualToString:OSKActivityType_iOS_Facebook], @"Attempting to authenticate a non-Facebook activity via the Facebook flow.");
    OSKSystemAccountStore *accountStore = [OSKSystemAccountStore sharedInstance];

    NSDictionary *readOptions = [activity.class readAccessRequestOptions];
    NSDictionary *writeOptions = [activity.class writeAccessRequestOptions];
    
    __weak OSKSessionController *weakSelf = self;
    
    NSString *systemAccountTypeIdentifier = [activity.class systemAccountTypeIdentifier];
    [accountStore requestAccessToAccountsWithAccountTypeIdentifier:systemAccountTypeIdentifier options:readOptions completion:^(BOOL successful, NSError *error) {
        if (successful == NO) {
            [weakSelf showAlertForSystemAccountAccessNotGranted];
            OSKLog(@"Access request failed for system accounts with account type identifier: %@", systemAccountTypeIdentifier);
            [weakSelf cancel];
        }
        else {
           [accountStore requestAccessToAccountsWithAccountTypeIdentifier:systemAccountTypeIdentifier options:writeOptions completion:^(BOOL successful, NSError *error) {
               if (successful == NO) {
                   [weakSelf showAlertForSystemAccountAccessNotGranted];
                   OSKLog(@"Access request failed for system accounts with account type identifier: %@", systemAccountTypeIdentifier);
                   [weakSelf cancel];
               }
               else {
                   NSArray *systemAccounts = [accountStore accountsForAccountTypeIdentifier:systemAccountTypeIdentifier];
                   if (systemAccounts.count > 0) {
                       ACAccount *account = nil;
                       NSString *lastUsedAccountID = [accountStore lastUsedAccountIdentifierForType:systemAccountTypeIdentifier];
                       for (ACAccount *anAccount in systemAccounts) {
                           if ([anAccount.identifier isEqualToString:lastUsedAccountID]) {
                               account = anAccount;
                               break;
                           }
                       }
                       if (account == nil) {
                           account = [systemAccounts firstObject];
                       }
                       [activity setActiveSystemAccount:account];
                       [weakSelf handlePublishingStepForActivity:activity];
                   }
                   else {
                       [weakSelf showAlertForNoSystemAccounts];
                       OSKLog(@"User has no existing system accounts with account type identifier: %@", systemAccountTypeIdentifier);
                       
                   }
               }
           }];
        }
    }];
}

- (void)showAlertForNoSystemAccounts {
    OSKPresentationManager *presentationManger = [OSKPresentationManager sharedInstance];
    NSString *title = [presentationManger localizedText_NoAccountsFound];
    NSString *message = [presentationManger localizedText_YouCanSignIntoYourAccountsViaTheSettingsApp];
    OSKAlertViewButtonItem *okayButton = [OSKAlertView okayItem];
    OSKAlertView *alert = [[OSKAlertView alloc] initWithTitle:title message:message cancelButtonItem:okayButton otherButtonItems:nil];
    [alert show];
}

- (void)showAlertForSystemAccountAccessNotGranted {
    OSKPresentationManager *presentationManger = [OSKPresentationManager sharedInstance];
    NSString *title = [presentationManger localizedText_AccessNotGrantedForSystemAccounts_Title];
    NSString *message = [presentationManger localizedText_AccessNotGrantedForSystemAccounts_Message];
    OSKAlertViewButtonItem *okayButton = [OSKAlertView okayItem];
    OSKAlertView *alert = [[OSKAlertView alloc] initWithTitle:title message:message cancelButtonItem:okayButton otherButtonItems:nil];
    [alert show];
}

- (void)finishUpAuthenticationWithFirstNewManagedAccount:(OSKManagedAccount *)account activity:(OSKActivity <OSKActivity_ManagedAccounts> *)activity {
    OSKManagedAccountStore *accountStore = [OSKManagedAccountStore sharedInstance];
    [accountStore addAccount:account forActivityType:[activity.class activityType]];
    [activity setActiveManagedAccount:account];
    [self handlePublishingStepForActivity:activity];
}

- (void)handleManagedAccountAuthenticationStepForActivity:(OSKActivity *)activity {
    NSAssert([activity respondsToSelector:@selector(activeManagedAccount)], @"OSKActivity subclasses using the managed account authentication method must conform to the OSKActivity_ManagedAccounts protocol.");
    OSKActivity <OSKActivity_ManagedAccounts> *theActivity = (OSKActivity <OSKActivity_ManagedAccounts> *)activity;
    OSKManagedAccountStore *accountStore = [OSKManagedAccountStore sharedInstance];
    NSArray *existingAccounts = [accountStore accountsForActivityType:[theActivity.class activityType]];
    if (existingAccounts.count > 0) {
        OSKManagedAccount *activeAccount = [accountStore activeAccountForActivityType:[activity.class activityType]];
        [theActivity setActiveManagedAccount:activeAccount];
        [self handlePublishingStepForActivity:theActivity];
    }
    else if ([theActivity.class authenticationViewControllerType] != OSKManagedAccountAuthenticationViewControllerType_None) {
        [self showAuthenticationViewControllerForActivity:theActivity];
    }
    else {
        __weak OSKSessionController *weakSelf = self;
        [theActivity authenticateNewAccountWithoutViewController:^(OSKManagedAccount *account, NSError *error) {
            if (account) {
                [weakSelf finishUpAuthenticationWithFirstNewManagedAccount:account activity:theActivity];
            } else {
                OSKLog(@"Failed to add account for activity: %@ error: %@", activity, error);
                [weakSelf cancel];
            }
        }];
    }
}

- (void)handleGenericAuthenticationStepForActivity:(OSKActivity *)activity {
    NSAssert([activity respondsToSelector:@selector(authenticate:)], @"OSKActivity subclasses using the generic authentication method must conform to the OSKActivity_GenericAuthentication protocol.");
    OSKActivity <OSKActivity_GenericAuthentication> *theActivity = (OSKActivity <OSKActivity_GenericAuthentication> *)activity;
    if ([theActivity isAuthenticated]) {
        [self handlePublishingStepForActivity:theActivity];
    } else {
        __weak OSKSessionController *weakSelf = self;
        [theActivity authenticate:^(BOOL successful, NSError *error) {
            if (successful) {
                [weakSelf handlePublishingStepForActivity:theActivity];
            } else {
                OSKLog(@"Activity failed to authenticate: %@ error: %@", theActivity, error);
                [weakSelf cancel];
            }
        }];
    }
}

- (void)handlePublishingStepForActivity:(OSKActivity *)activity {
    OSKPublishingMethod method = [activity.class publishingMethod];
    if (method == OSKPublishingMethod_None || method == OSKPublishingMethod_URLScheme) {
        [self dismissViewControllers];
        [self handlePerformStepForActivity:activity];
    } else {
        [self showPublishingViewControllerForActivity:activity];
    }
}

- (void)handlePerformStepForActivity:(OSKActivity *)activity {
    [self.delegate sessionControllerDidBeginPerformingActivity:self hasDismissedAllViewControllers:YES]; // Always YES for now...
    
    if ([activity.class publishingMethod] == OSKPublishingMethod_URLScheme) {
        [self prepareURLSchemeActivityToPerform:activity];
    }
    
    __weak OSKSessionController *weakSelf = self;
    [activity performActivity:^(OSKActivity *theActivity, BOOL successful, NSError *error) {
        [weakSelf.delegate sessionControllerDidFinish:weakSelf successful:successful error:error];
    }];
}

- (void)prepareURLSchemeActivityToPerform:(OSKActivity *)activity {
    if ([activity conformsToProtocol:@protocol(OSKURLSchemeActivity)]) {
        OSKActivity <OSKURLSchemeActivity> *urlSchemeActivity = (OSKActivity <OSKURLSchemeActivity> *)activity;
        if ([urlSchemeActivity targetApplicationSupportsXCallbackURL]) {
            if ([urlSchemeActivity respondsToSelector:@selector(prepareToPerformActionUsingXCallbackURLInfo:)]) {
                id <OSKXCallbackURLInfo> xCallbackInfo = [OSKActivitiesManager sharedInstance].xCallbackURLDelegate;
                [urlSchemeActivity prepareToPerformActionUsingXCallbackURLInfo:xCallbackInfo];
            }
        }
    }
}

#pragma mark - Required for Subclasses

- (void)presentViewControllerAppropriately:(UIViewController *)viewController setAsNewRoot:(BOOL)isNewRoot {
    NSAssert(NO, @"Subclasses must override presentViewControllerAppropriately:setAsNewRoot: without calling super");
}

- (void)presentSystemViewControllerAppropriately:(UIViewController *)systemViewController {
    NSAssert(NO, @"Subclasses must override presentViewControllerAppropriately:setAsNewRoot: without calling super");
}

- (void)dismissViewControllers {
    NSAssert(NO, @"Subclasses must override dismissAllViewControllers without calling super");
}

#pragma mark - Setting Up Purchasing View Controllers

- (void)showPurchasingViewControllerForActivity:(OSKActivity *)activity {
    UIViewController <OSKPurchasingViewController> *viewController = nil;
    viewController = [[OSKPresentationManager sharedInstance] purchasingViewControllerForActivity:activity];
    [viewController preparePurchasingViewForActivity:activity delegate:self];
    [self presentViewControllerAppropriately:viewController setAsNewRoot:YES];
}

#pragma mark - Setting Up Authentication View Controllers

- (void)showAuthenticationViewControllerForActivity:(OSKActivity *)activity {
    UIViewController <OSKAuthenticationViewController> *viewController = nil;
    viewController = [[OSKPresentationManager sharedInstance] authenticationViewControllerForActivity:activity];
    [viewController prepareAuthenticationViewForActivity:(OSKActivity <OSKActivity_ManagedAccounts> *)activity delegate:self];
    [self presentViewControllerAppropriately:viewController setAsNewRoot:YES];
}

#pragma mark - Setting Up Publishing View Controllers

- (void)showPublishingViewControllerForActivity:(OSKActivity *)activity {
    UIViewController <OSKPublishingViewController> *viewController = nil;
    viewController = [[OSKPresentationManager sharedInstance] publishingViewControllerForActivity:activity];
    [viewController preparePublishingViewForActivity:activity delegate:self];
    if ([activity.class publishingMethod] == OSKPublishingMethod_ViewController_System) {
        [self presentSystemViewControllerAppropriately:viewController];
    } else {
        [self presentViewControllerAppropriately:viewController setAsNewRoot:YES];
    }
}

#pragma mark - Purchasing View Controller Delegate

- (void)purchasingViewController:(UIViewController <OSKPurchasingViewController> *)viewController didPurchaseActivityTypes:(NSArray *)activityTypes withActivity:(OSKActivity *)activity {
    OSKActivitiesManager *manager = [OSKActivitiesManager sharedInstance];
    [manager markActivityTypes:activityTypes asAlreadyPurchased:YES];
    [self handleAuthenticationStepForActivity:activity];
}

- (void)purchasingViewControllerDidCancel:(UIViewController <OSKPurchasingViewController> *)viewController withActivity:(OSKActivity *)activity {
    [self cancel];
}

#pragma mark - Authentication View Controller Delegate

- (void)authenticationViewController:(UIViewController <OSKAuthenticationViewController> *)viewController didAuthenticateNewAccount:(OSKManagedAccount *)account withActivity:(OSKActivity *)activity {
    [self finishUpAuthenticationWithFirstNewManagedAccount:account activity:(OSKActivity <OSKActivity_ManagedAccounts> *)activity];
}

- (void)authenticationViewControllerDidCancel:(UIViewController <OSKAuthenticationViewController> *)viewController withActivity:(OSKActivity *)activity {
    [self cancel];
}

#pragma mark - Publishing View Controller Delegate

- (void)publishingViewController:(UIViewController <OSKPublishingViewController> *)viewController didTapPublishActivity:(OSKActivity *)activity {
    if ([activity isReadyToPerform]) {
        [self dismissViewControllers];
        [self handlePerformStepForActivity:activity];
    } else {
        OSKLog(@"Publishing failed, not yet ready to perform: %@", activity);
    }
}

- (void)publishingViewControllerDidCancel:(UIViewController <OSKPublishingViewController> *)viewController
                             withActivity:(OSKActivity *)activity {
    [self cancel];
}

#pragma mark - Convenience

- (void)cancel {
    [self dismissViewControllers];
    [self.delegate sessionControllerDidCancel:self];
}

@end



