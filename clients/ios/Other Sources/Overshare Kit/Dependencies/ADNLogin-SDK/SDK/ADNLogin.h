//
//  ADNLogin.h
//  ADNSDK
//
//  Created by Bryan Berg on 3/28/13.
//  Copyright (c) 2013 Mixed Media Labs, Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this
//  software and associated documentation files (the "Software"), to deal in the Software
//  without restriction, including without limitation the rights to use, copy, modify,
//  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or
//  substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
//  BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <Foundation/Foundation.h>

#ifdef __IPHONE_6_0
#import <StoreKit/StoreKit.h>
#endif


@class ADNLogin;

// Error domain
static NSString *const kADNLoginErrorDomain = @"ADNLoginErrorDomain";

// Notification names
static NSString *const kADNLoginWillBeginPollingNotification = @"ADNLoginWillBeginPollingNotification";
static NSString *const kADNLoginDidEndPollingNotification = @"ADNLoginDidEndPollingNotification";

#ifdef __IPHONE_6_0
typedef void (^ADNLoginStoreCompletionBlock)(SKStoreProductViewController *storeViewController, BOOL result, NSError *error);
#endif


/**
 The `ADNLoginDelegate` protocol defines the methods the ADNLogin SDK will use to communicate state with your app.
 Typically this will be implemented by your app delegate.
 */
@protocol ADNLoginDelegate <NSObject>

/**
 Called when fast-switching back from App.net Passport with valid login credentials.
 
 @param userID The user ID of the logged-in user.
 @param accessToken An access token authorized with the requested permissions.
*/
- (void)adnLoginDidSucceedForUserWithID:(NSString *)userID username:(NSString *)username token:(NSString *)accessToken;

/**
 Called when login has failed.

 @param error An error describing the reason for failure.
*/
- (void)adnLoginDidFailWithError:(NSError *)error;

@optional

/**
 Called when polling for App.net Passport has begun. You may wish to display an activity indicator.
 Not implementing this delegate method is the same as returning `NO`.

 @return `YES` to indicate that you will handle detection/launch of App.net Passport. `NO` to let the ADNLogin SDK handle this.
*/
- (BOOL)adnLoginWillBeginPolling;

/**
 Called when polling for App.net Passport has completed. If you displayed an activity indicator
 when polling began, you may wish to stop or hide it now.
 Not implementing this delegate method is the same as returning `NO`.
 
 @param success whether or not Passport was detected when polling ended
 
 @return `YES` to indicate you will handle launch of Passport. `NO` to automatically launch Passport.
 */
- (BOOL)adnLoginDidEndPollingWithSuccess:(BOOL)success;

@end


/**
 The primary object in the ADNLogin SDK. Generally, you will use the `+sharedInstance` method to create this object.
 */
@interface ADNLogin : NSObject
#ifdef __IPHONE_6_0
<SKStoreProductViewControllerDelegate>
#endif

/**
 A SDK-managed singleton instance of the ADNLogin SDK.
 */
+ (instancetype)sharedInstance;

/**
 The SDK delegate.
 */
@property (weak, nonatomic) NSObject<ADNLoginDelegate> *delegate;

/**
 Whether or not App.net Passport-assisted authentication is available.
 This can be used to detect whether App.net Passport is installed.

 If this is `NO`, your app should fall back to another login method, like the password flow.
 */
@property (readonly, nonatomic, getter=isLoginAvailable) BOOL loginAvailable;

/**
 Whether or not App.net Passport is installed and able to support launching the find friends feature directly.
 */
@property (readonly, nonatomic, getter=isFindFriendsActionAvailable) BOOL findFriendsAvailable;

/**
 Whether or not App.net Passport is installed and able to support launching the find friends feature directly.
 */
@property (readonly, nonatomic, getter=isFindFriendsActionAvailable) BOOL inviteFriendsAvailable;

/**
 Whether or not App.net Passport is installed and able to support launching the recommended users feature directly.
 */
@property (readonly, nonatomic, getter=isFindFriendsActionAvailable) BOOL recommendedUsersAvailable;

/**
 Authorization scopes to request when logging in or launching passport.
 Often populated from the `ADNLoginScopes` Info.plist key.
 */
@property (strong, nonatomic) NSArray *scopes;

/**
 Call this method from your app delegate's `application:openURL:sourceApplication:annotation:` method.

 @param url The URL of the request
 @param sourceApplication The bundle ID of the opening application
 @param annotation The supplied annotation

 @return `YES` if the ADNLogin SDK handled the request, `NO` if it did not
 */
- (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;

/**
 Request login.

 @param scopes A list of the requested authentication scopes.

 @return `YES` if App.net Passport was launched to request login, `NO` if it was not installed or unable to open
 */
- (BOOL)login;

/**
 Request that App.net Passport launch the find friends feature.

 @return `YES` if App.net Passport was launched, `NO` if it was not installed, too old or unable to open
 */
- (BOOL)launchFindFriends;

/**
 Request that App.net Passport launch the invite friends feature.

 @return `YES` if App.net Passport was launched, `NO` if it was not installed, too old or unable to open
 */
- (BOOL)launchInviteFriends;

/**
 Request that App.net Passport launch the recommended users feature.

 @return `YES` if App.net Passport was launched, `NO` if it was not installed, too old or unable to open
 */
- (BOOL)launchRecommendedUsers;

#ifdef __IPHONE_6_0

/**
 Request that App.net Passport be installed. Uses StoreKit to present the purchase interface in-app.
 This is the preferred mechanism to install Passport. If it returns `nil`, try calling `openStoreForPassport`.
 
 You should present the view controller as you prefer. The controller's delegate will be set to ADNLogin by default,
 and ADNLogin will automatically dismiss it when it is complete. You may change the controller's delegate if you wish.
 To begin the polling process, ensure that you call ADNLogin's `productViewControllerDidFinish:` method. If you
 have changed the delegate, you are responsible for dismissing the product view controller.

 @param completionBlock A block called when the product controller has finished loading or returned an error.
 
 @return A `SKStoreProductViewController *` if StoreKit was available, `nil` if not (e.g., when running on iOS < 6.0)
 */
- (SKStoreProductViewController *)passportProductViewControllerWithCompletionBlock:(ADNLoginStoreCompletionBlock)completionBlock;

#endif

/**
 Launch the App Store for App.net Passport. Does not use StoreKit -- use this method if StoreKit is unavailable.

 @return `YES` if the App Store was launched, `NO` if not
 */
- (BOOL)openStoreForPassport;

/**
 Request that the SDK stop polling for App.net Passport. The delegate method for indicating the end of polling WILL NOT be called.
*/
- (void)cancelPolling;

@end
