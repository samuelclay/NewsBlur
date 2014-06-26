//
//  OSKActivity_GenericAuthentication.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

// Used by activities that require authentication but don't have "accounts",
// for example the Pocket API, which handles authentication via an opaque SDK.

typedef void(^OSKGenericAuthenticationCompletionHandler)(BOOL successful, NSError *error);

///------------------------------
/// @name Generic Authentication
///------------------------------

/**
 A generic authentication protocol for relevant subclasses of `OSKActivity`.
 
 Generic Authentication refers to forms of authentication that can't be managed by either iOS or Overshare. At this
 time, the only example is `OSKPocketActivity`, which uses the Pocket SDK to opaquely authenticate the user.
 */
@protocol OSKActivity_GenericAuthentication <NSObject>

/**
 Checks whether the activity is authenticated.
 
 @return Return `YES` if the activity is already authenticated.
 */
- (BOOL)isAuthenticated;

/**
 Authenticates the activity.
 
 @param The completion handler to be called at the end of the authentication attempt, whether or not
 it was successful.
 */
- (void)authenticate:(OSKGenericAuthenticationCompletionHandler)completion;

@end





