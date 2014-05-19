//
//  OSKActivity.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;
@import Foundation;

// ACTIVITY OPTIONS
extern NSString * const OSKActivityOption_ExcludedTypes; // NSArray of activity types (strings)
extern NSString * const OSKActivityOption_BespokeActivities; // NSArray of classes, each inheriting from OSKActivity
extern NSString * const OSKActivityOption_RequireOperations; // Passing @(YES) filters out activities that can't perform via OSKActivityOperation

// BUILT-IN ACTIVITY TYPES (Your custom OSKActivity subclasses should have their own unique types.)
extern NSString * const OSKActivityType_iOS_Twitter;
extern NSString * const OSKActivityType_iOS_Facebook;
extern NSString * const OSKActivityType_iOS_Safari;
extern NSString * const OSKActivityType_iOS_SMS;
extern NSString * const OSKActivityType_iOS_Email;
extern NSString * const OSKActivityType_iOS_CopyToPasteboard;
extern NSString * const OSKActivityType_iOS_AirDrop;
extern NSString * const OSKActivityType_iOS_ReadingList;
extern NSString * const OSKActivityType_iOS_SaveToCameraRoll;
extern NSString * const OSKActivityType_API_AppDotNet;
extern NSString * const OSKActivityType_API_500Pixels;
extern NSString * const OSKActivityType_API_Instapaper;
extern NSString * const OSKActivityType_API_Readability;
extern NSString * const OSKActivityType_API_Pocket;
extern NSString * const OSKActivityType_API_Pinboard;
extern NSString * const OSKActivityType_API_GooglePlus;
extern NSString * const OSKActivityType_URLScheme_Instagram;
extern NSString * const OSKActivityType_URLScheme_Riposte;
extern NSString * const OSKActivityType_URLScheme_Tweetbot;
extern NSString * const OSKActivityType_URLScheme_1Password_Search;
extern NSString * const OSKActivityType_URLScheme_1Password_Browser;
extern NSString * const OSKActivityType_URLScheme_Chrome;
extern NSString * const OSKActivityType_URLScheme_Omnifocus;
extern NSString * const OSKActivityType_URLScheme_Things;
extern NSString * const OSKActivityType_URLScheme_Drafts;
extern NSString * const OSKActivityType_SDK_Pocket;

@class OSKActivity;
@class OSKActivityOperation;
@class OSKApplicationCredential;
@class OSKShareableContentItem;

typedef void(^OSKActivityCompletionHandler)(OSKActivity *activity, BOOL successful, NSError *error);

typedef NS_ENUM(NSInteger, OSKAuthenticationMethod) {
    OSKAuthenticationMethod_None,
    OSKAuthenticationMethod_SystemAccounts,     // e.g. system Twitter accounts
    OSKAuthenticationMethod_ManagedAccounts,    // e.g. App.net
    OSKAuthenticationMethod_Generic,            // e.g. Pocket API
};

typedef NS_ENUM(NSInteger, OSKPublishingMethod) {
    OSKPublishingMethod_None,                           // e.g. Copy to Pasteboard
    OSKPublishingMethod_URLScheme,                      // e.g. 1Password
    OSKPublishingMethod_ViewController_System,          // e.g. Email and Messages
    OSKPublishingMethod_ViewController_Bespoke,         // Your custom, one-of-a-kind publishing view controller
    OSKPublishingMethod_ViewController_Microblogging,   // e.g. Twitter & App.net
    OSKPublishingMethod_ViewController_Blogging,        // e.g. Tumblr or WordPress
    OSKPublishingMethod_ViewController_Facebook,        // duh
    OSKPublishingMethod_ViewController_GooglePlus,        // duh
};

///--------------------------------------------------------
/// @name OSKActivity
///--------------------------------------------------------

/**
 A semi-abstract base class for all activities.
 
 @discussion `OSKActivity` is the heart and soul of Overshare Kit. For every content item type (microblogging, 
 emails, etc.) there are one or more subclasses of `OSKActivity` designed to perform an action with that content.
 
 There are a few methods in the base class that should not be overridden, but for the most part *every* method
 of `OSKActivity` should be overridden by subclasses without calling super.
 
 @warning This bears repeating: failure to override required methods in subclasses — without calling the super
 implementation — will lead to assertion failures.
 */
@interface OSKActivity : NSObject

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item;

@end

///------------------------------------------
/// @name Protected Methods (Do not override)
///------------------------------------------

@interface OSKActivity (DoNotOverride)

/**
 The activity's content item.
 
 @discussion `OSKShareableContentItem` is itself an abstract base class. In practice, each
 `OSKActivity` subclass will have an appropriate `OSKShareableContentItem` subclass for this
 property.
 */
@property (strong, nonatomic, readonly) OSKShareableContentItem *contentItem;

/**
 Convenience function for getting IAP requirement status.
 
 @return Returns `YES` if the activity type requires purchase **in general**.
 
 @discussion To edit which activity types require purchase and keep track of purchase status,
 use the relevant methods on OSKActivitiesManager.

 @see OSKActivitiesManager
 */
- (BOOL)requiresPurchase;

/**
 Convenience function for getting actual IAP status.
 
 @return Returns `YES` if the activity type either a) requires purchase and has already been purchased,
 or b) does not require purchase.
 
 @discussion To edit which activity types require purchase and keep track of purchase status,
 use the relevant methods on OSKActivitiesManager.
 
 @see OSKActivitiesManager
 */
- (BOOL)isAlreadyPurchased;

/**
 Convenience method for obtaining an application credential appropriate for the activity class.
 
 @return Returns a valid credential or nil.
 
 @discussion This convenience method obtains the applicationCredential from OSKActivitiesManager.
 Not every service requires an application credential. For those that do (like Facebook
 or App.net, for example) your app must provide a credential via the `OSKActivitiesManager`'s
 `customizationsDelegate`.
 */
+ (OSKApplicationCredential *)applicationCredential;

@end

///------------------------------------------------------
/// @name Required Methods for Subclasses
///------------------------------------------------------

@interface OSKActivity (RequiredMethodsForSubclasses)

/**
 The type of `OSKShareableContentItem` that the activity can handle.
 
 @return A content item type.
 */
+ (NSString *)supportedContentItemType;

/**
 The general availability of the activity. 
 
 @return Returns `YES` if generally available.
 
 @discussion This is general availability (i.e. not authentication status or user-specified
 exclusion). Most activities will always be available. Some exceptions are AirDrop (since not
 all devices have AirDrop support), or OmniFocus (since that requires that OmniFocus be
 installed on the device).
 */
+ (BOOL)isAvailable;

/**
 Uniquely identifies the activity.
 
 @return Returns the type.
 */
+ (NSString *)activityType;

/**
 A display-ready name for the activity.
 
 @return Returns the activity name, like "Twitter".
 */
+ (NSString *)activityName;

/**
 An icon for the activity.
 
 @param idiom The current user interface idiom.
 
 @return Returns a square, non-bordered, non-translucent icon of an appropriate size.
 
 @discussion Icons should be 60x60 points on iPhone and 76x76 points on iPad.
 */
+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom;

/**
 The authentication method for the activity.
 
 @return A value from the enum `OSKAuthenticationMethod`.
 
 @discussion There are four possible values:
 
    OSKAuthenticationMethod_None
    OSKAuthenticationMethod_SystemAccounts
    OSKAuthenticationMethod_ManagedAccounts
    OSKAuthenticationMethod_Generic
 
 "None" is self explanatory. These activities do not require authentication before they can perform
 their task.
 
 "SystemAccounts" refers to accounts handled by iOS, e.g. Twitter or Facebook.
 
 "ManagedAccounts" refers to accounts managed by Overshare Kit, e.g. App.net or Instapaper, to name
 a few.
 
 "Generic" refers to forms of authentication that can't be managed by either iOS or Overshare. At this
 time, the only example is `OSKPocketActivity`, which uses the Pocket SDK to opaquely authenticate the user.
 
 */
+ (OSKAuthenticationMethod)authenticationMethod;

/**
 Determines whether the activity requires an application-level credential to perform its tasks.
 
 @return Returns `YES` if the activity requires an application credential.
 
 @discussion Some services require application-specific credentials in order to authenticate the user.
 These include application keys and secrets for Oauth token generation, or the application ID for 
 sending Facebook posts.
 
 @see OSKActivitiesManager
 @see OSKApplicationCredential
 */
+ (BOOL)requiresApplicationCredential;

/**
 Determines the type of publishing view controller the activity needs to perform its task.
 
 @return Returns a value from the enum `OSKpublishingMethod`
 */
+ (OSKPublishingMethod)publishingMethod;

/**
 Determines whether or not the activity is ready to perform.
 
 @return Returns `YES` if the activity is ready.
 
 @discussion Some activities require validation of their content item properties before they're 
 ready to perform (like checking App.net post character counts). Validation might also include
 whether there is an active account (if the activitity uses accounts). 
 
 @warning This method may be called many times in a row in order to update a "Done" button
 while the user types. You should return as quickly as possible to avoid UI lags.
 */
- (BOOL)isReadyToPerform;

/**
 Triggers the activity to perform its task.
 
 @param completion A completion handler that will be called at the end of the task, whether it
 succeeds or fails.
 */
- (void)performActivity:(OSKActivityCompletionHandler)completion;

/**
 Determines whether an activity can perform via a planned `OSKActivityOperation` object.
 
 @return Returns `NO`.
 
 @warning As of this writing, `OSKActivityOperation` does not yet exist. All built-in activities
 return `NO` for this method.
 */
+ (BOOL)canPerformViaOperation;

/**
 Creates an `OSKActivityOperation` instance configured to perform the current task.
 
 @param completion A completion handler that will be called at the end of the task, whether it
 succeeds or fails.
 
 @return A fully configured `OSKActivityOperation`. As of this writing, this method will always return `nil`.
 
 @warning As of this writing, `OSKActivityOperation` does not yet exist. All built-in activities
 return `nil` for this method.
 */
- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion;

@end

///------------------------------------------------------
/// @name Optional Methods for Subclasses
///------------------------------------------------------

@interface OSKActivity (OptionalMethodsForSubclasses)

/**
 A settings icon for the activity.
 
 @return Returns a 29x29 point square, non-translucent icon.
 */
+ (UIImage *)settingsIcon;

@end;


