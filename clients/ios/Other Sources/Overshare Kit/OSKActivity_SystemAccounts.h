//
//  OSKActivity_SystemAccounts.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Accounts;

typedef void(^OSKSystemAccountAccessRequestCompletionHandler)(BOOL successful, NSError *error);

///-----------------------------------------------
/// @name System Accounts
///-----------------------------------------------

/**
 A protocol for `OSKActivity` subclasses that use iOS system accounts for authentication.
 */
@protocol OSKActivity_SystemAccounts <NSObject>

/**
 The active system account.
 */
@property (strong, nonatomic) ACAccount *activeSystemAccount;

/**
 @return Returns the iOS account type identifier corresponding to the activity.
 */
+ (NSString *)systemAccountTypeIdentifier;

@optional

/**
 @return Returns an `NSDictionary` of read access request options, or nil. Used only by `OSKFacebookActivity`.
 */
+ (NSDictionary *)readAccessRequestOptions;

/**
 @return Returns an `NSDictionary` of write access request options, or nil. Used only by `OSKFacebookActivity`.
 */
+ (NSDictionary *)writeAccessRequestOptions;

@end








