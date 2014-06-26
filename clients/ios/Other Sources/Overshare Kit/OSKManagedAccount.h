//
//  OSKAccount.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@class OSKManagedAccountCredential;

///-----------------------------------------------
/// @name Managed Accounts
///-----------------------------------------------

/**
 `OSKManagedAccount` is used by Overshare Kit to manage authentication and account info for
 activities that conform to the `OSKActivity_ManagedAccounts` protocol.
 
 @warning `OSKManagedAccount` is not intended to be subclassed.
 */
@interface OSKManagedAccount : NSObject <NSCoding>

///-----------------------------------------------
/// @name Properties
///-----------------------------------------------

/**
 The username (or email) for the account.
 */
@property (  copy, nonatomic, readwrite) NSString *username;

/**
 The full name for the account (if any).
 */
@property (  copy, nonatomic, readwrite) NSString *fullName;

/**
 The account ID that identifies this account in the third-party's account database.
 */
@property (  copy, nonatomic, readwrite) NSString *accountID;

/**
 The `OSKActivity` activity type associated with this account.
 */
@property (  copy, nonatomic,  readonly) NSString *activityType;

/**
 A GUID uniquely identifying this account in Overshare.
 */
@property (  copy, nonatomic,  readonly) NSString *overshareAccountIdentifier;

/**
 The account-specific credential for the account. This is not an application-level credential.
 */
@property (strong, nonatomic,  readonly) OSKManagedAccountCredential *credential;

///-----------------------------------------------
/// @name Instance Methods
///-----------------------------------------------

/**
 @return Returns a new GUID to be used when creating a new managed account.
 */
+ (NSString *)generateNewOvershareAccountIdentifier;

/**
 Compares two accounts to see if they are duplicates.
 
 @param firstAccount
 
 @param secondAccount
 
 @return Returns `YES` if the accounts are duplicates.
 */
+ (BOOL)accountsAreDuplicates:(OSKManagedAccount *)firstAccount secondAccount:(OSKManagedAccount *)secondAccount;

/**
 The designated initializer.
 
 @param identifier A new GUID identifying this account.
 
 @param activityType The activity type associated with this account.
 
 @param credential A credential for the new account. This cannot be modified later.
 */
- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                      activityType:(NSString *)activityType
                                        credential:(OSKManagedAccountCredential *)credential;
/**
 Signs out of the account.
 */
- (void)signOut;

/**
 @return Returns a guaranteed non-nil display string for the user's name.
 */
- (NSString *)nonNilDisplayName;

@end









