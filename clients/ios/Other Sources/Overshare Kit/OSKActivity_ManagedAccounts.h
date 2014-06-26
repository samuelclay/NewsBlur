//
//  OSKActivity_OSKManagedAccounts.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

typedef NS_ENUM(NSInteger, OSKManagedAccountAuthenticationViewControllerType) {
    OSKManagedAccountAuthenticationViewControllerType_None,
    OSKManagedAccountAuthenticationViewControllerType_DefaultUsernamePasswordViewController,
    OSKManagedAccountAuthenticationViewControllerType_OneOfAKindCustomBespokeViewController,
};

typedef NS_ENUM(NSInteger, OSKUsernameNomenclature) {
    OSKUsernameNomenclature_Email       = 1 << 0,
    OSKUsernameNomenclature_Username    = 1 << 1,
};

@class OSKApplicationCredential;
@class OSKManagedAccount;

typedef void(^OSKManagedAccountAuthenticationHandler)(OSKManagedAccount *account, NSError *error);

///---------------------------------------------
/// @name Managed Accounts
///---------------------------------------------

/**
 A protocol for `OSKActivity` subclasses that use Overshares managed account system for authentication.
 
 These kinds of activities include `OSKAppDotNetActivity`, `OSKInstapaperActivity` and others.
 */
@protocol OSKActivity_ManagedAccounts <NSObject>

///-----------------------------------------------
/// @name Required Methods
///-----------------------------------------------

@required

/**
 The active account for the activity.
 */
@property (strong, nonatomic) OSKManagedAccount *activeManagedAccount;

/**
 The type of authentication view controller used to authenticate the activity.
 
 @return Returns a value from the enum 'OSKManagedAccountAuthenticationViewControllerType'
 
 @discussion Some activites don't use view controllers, some use username and password view
 controllers, and still others use a webview-based flow. Overshare Kit provides ready-made view
 controllers for these scenarios.
 */
+ (OSKManagedAccountAuthenticationViewControllerType)authenticationViewControllerType;

///-----------------------------------------------
/// @name Optional Methods (Well, Semi-Optional)
///-----------------------------------------------

@optional

/**
 The value returned from this method is used to configure the UI for sign in screens.
 */
- (OSKUsernameNomenclature)usernameNomenclatureForSignInScreen;

/**
 Authenticates a new managed account without a view controller. 
 
 @param completion A completion handler to be called at the end of the authentication attempt.
 
 @discussion At this time, only OSKAppDotNetActivity is able to authenticate in this manner, using
 the App.net Passport application. If that app is not installed, the web flow is used.
 */
- (void)authenticateNewAccountWithoutViewController:(OSKManagedAccountAuthenticationHandler)completion;

/**
 Authenticates a new managed account with the provided credentials.
 
 @param username the username (or email)
 
 @param password the password
 
 @param appCredential An application-specific credential, or `nil` if none is needed.
 
 @param completion A completion handler to be called at the end of the authentication attempt.
 */
- (void)authenticateNewAccountWithUsername:(NSString *)username
                                  password:(NSString *)password
                             appCredential:(OSKApplicationCredential *)appCredential
                                completion:(OSKManagedAccountAuthenticationHandler)completion;

@end




