//
//  OSKThirdPartyAccountManager.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@class OSKManagedAccount;

///-----------------------------------------------
/// @name Managed Account Store
///-----------------------------------------------

/**
 `OSKManagedAccountStore` is used as a singleton instance. It stores all the managed accounts for
 all the activities in Overshare that use them.
 */
@interface OSKManagedAccountStore : NSObject

/**
 @return Returns the singleton instance.
 */
+ (id)sharedInstance;

/**
 Gets the accounts associated with a given activityType.
 
 @param activityType The activity type.
 
 @return An array of `OSKManagedAccount` instances, or nil.
 */
- (NSArray *)accountsForActivityType:(NSString *)activityType;

/**
 Finds an existing account that matches a potentially duplicate account.
 
 @param account The potentially duplicate account.
 
 @return Returns a matching existing account or nil.
 */
- (OSKManagedAccount *)existingAccountMatchingPotentialDuplicateAccount:(OSKManagedAccount *)account;

/**
 Adds the new account for the associated activity type.
 
 @param account The new account to be added.
 
 @param activityType The associated activity type.
 
 @discussion If `account` is determined to be a duplicate of an existing account, then it replaces the
 older existing account.
 */
- (void)addAccount:(OSKManagedAccount *)account forActivityType:(NSString *)activityType;

/**
 Removes the account from the account store.
 
 @param account The account to be removed.
 
 @param activityType The activityType associated with the account.
 */
- (void)removeAccount:(OSKManagedAccount *)account forActivityType:(NSString *)activityType;

/**
 Returns the most recent active account for a given activity type;
 
 @param activityType An OSK activity type.
 */
- (OSKManagedAccount *)activeAccountForActivityType:(NSString *)activityType;

/**
 Registers an account as the the current active account for a given activity type.
 
 @param account The account to be registered.
 
 @param activityType An OSK activity type.
 */
- (void)setActiveAccount:(OSKManagedAccount *)account forActivityType:(NSString *)activityType;

@end



