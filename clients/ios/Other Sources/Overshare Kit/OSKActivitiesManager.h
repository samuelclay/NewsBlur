//
//  OSKActivitiesManager.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

#import "OSKXCallbackURLInfo.h"

@class OSKApplicationCredential;
@class OSKShareableContent;
@protocol OSKActivityCustomizations;

extern NSString * const OSKActivitiesManagerDidMarkActivityTypesAsPurchasedNotification;
extern NSString * const OSKActivitiesManagerDidMarkActivityTypesAsUnpurchasedNotification;
extern NSString * const OSKActivitiesManagerActivityTypesKey;

///----------------------------
/// @name The Actvities Manager
///----------------------------

/**
 A singleton object responsible for non-UI aspects of creating and validating `OSKActivity` instances.
 */
@interface OSKActivitiesManager : NSObject

/**
 This delegate vends important configuration information that `OSKActivitiesManager` cannot create
 on its own (application credentials, e.g.).
 */
@property (weak, nonatomic) id <OSKActivityCustomizations> customizationsDelegate;

/**
 Some OSKActivities integrate with third-party apps that implement the x-callback-url specification.
 `xCallbackURLDelegate`, if present, will provide information necessary to build valid NSURLs that conform
 to the x-callback-url specification.
 
 Your application, if it supports x-callback-url callbacks, will provide those callbacks via this object.

 @note OvershareKit does *not* handle the processing of x-callback-url callbacks
 if/when the target app relinquishes the user's focus back to the current application. 
 If your app provides x-callback-url callbacks, you probably knew this already.
 */
@property (weak, nonatomic) id <OSKXCallbackURLInfo> xCallbackURLDelegate;

/**
 Accesses the singleton activity manager.
 
 @return A singletong instance of `OSKActivitiesManager`.
 */
+ (instancetype)sharedInstance;

///---------------------------------------
/// @name Activity Creation and Validation
///---------------------------------------

/**
 Obtains an application credential for the given activity type.
 
 @param activityType The activity type of a given `OSKActivity`.
 
 @return A valid application credential, or nil if none is available.
 
 @discussion Internally, `OSKActivitiesManager queries its `customizationsDelegate` for a valid app
 credential, returning `nil` if that delegate doesn't return one. 
 
 For testing purposes, Overshare Kit has some test application credentials already in place for some
 activities. Setting the compiler flag DEBUG to "1" will enable these test credentials.
 
 @warning You must not ship Overshare's test credentials in a production application. They may be
 revoked at any time. We will not be responsible for any consequences if that happens. Please consult the
 tuturials docs for more information on setting up application credentials.
 */
- (OSKApplicationCredential *)applicationCredentialForActivityType:(NSString *)activityType;

/**
 Creates an array of `OSKActivity` instances.
 
 @param content The content to be shared by the output activities.
 
 @param options See the list of option keys at the top of OSKActivity.h.
 
 @return An array of `OSKActivity` instances.
 
 @discussion This method iterates over all the content items of `content`, alloc/initing 
 an instance of every `OSKActivity` that can handle the given content item. Activity types 
 may be excluded on the basis of the values in the options dictionary. It will also create
 activities for any of bespoke OSKActivity subclasses of your own that you pass in the 
 options dictionary via the `OSKActivityOption_BespokeActivities` key.
 */
- (NSArray *)validActivitiesForContent:(OSKShareableContent *)content options:(NSDictionary *)options;

/**
 Marks activity types as always excluded from validation, even if they would otherwise pass.
 
 @param types An array of activity types.
 
 @param excluded Whether or not the activity types in `types` should be excluded.
 
 @discussion This method is used for permanently toggling visibility of activities the user 
 doesn't want to see anywhere in Overshare Kit. For example, an App.net client probably doesn't
 want App.net sharing to be duplicated in the activity sheets.
 
 These exclusion settings persist across app launches.
 */
- (void)markActivityTypes:(NSArray *)types alwaysExcluded:(BOOL)excluded;

/**
 Check if an activity has been permanently excluded from validation.
 
 @param type The activity type to check.
 
 @return Return `YES` if `type` has been marked for permanent exclusion.
 */
- (BOOL)activityTypeIsAlwaysExcluded:(NSString *)type;

/**
 Setting `syncActivityTypeExclusionsViaiCloud` to `YES` will sync the activity 
 types marked/unmarked via the `markActivityTypes:alwaysExcluded:` method via 
 iCloud key-value storage.
 
 @discussion Enabling iCloud sync is helpful if your application uses 
 `markActivityTypes:alwaysExcluded` as the logic behind user-facing switches to 
 control which activities she never wants to see in a share sheet. For example,
 a user may never want to use Facebook or the 1Password web browser.
 
 See the sample OvershareKit app for an example (tap the left navigation bar
 button to show the options screen).
 
 If you wish to enable iCloud key value syncing, it is recommended
 that you set this property on OSKActivitiesManager in your app delegate's
 implementation of `application:didFinishLaunchingWithOptions`. Please note that
 in-app purchase activity settings (see below) will *not* be synced via iCloud.
 
 @warning Your app must have the appropriate entitlements for iCloud key value storage. 
 See the iCloud documentation for more information.
 */
@property (assign, nonatomic) BOOL syncActivityTypeExclusionsViaiCloud;

@end

///-------------------------------------
/// @name In-App Purchases
///-------------------------------------

@interface OSKActivitiesManager (InAppPurchase)

/**
 Marks the the activity types in `types` as to whether or not — in general — they 
 require in-app purchases (IAPs).
 
 @param types An array of activity types.
 
 @param requirePurchase Whether or not the activity types should require purchase.
 
 @discussion Overshare distinguishes between "requiring" IAP in general, and "already" 
 purchased. This method is used for the general requirement.
 
 @warning In-app purchase requirement states **do not** persist across app launches.
 */
- (void)markActivityTypes:(NSArray *)types asRequiringPurchase:(BOOL)requirePurchase;

/**
 Checks the general purchase requirement state for a given activity type.
 
 @param type The activity type.
 
 @return Returns `YES` if the activity type requires purchase in general.
 */
- (BOOL)activityTypeRequiresPurchase:(NSString *)type;

/**
 Marks the activity types in `types` as to whether or not they have already been
 purchased.
 
 @param types An array of activity types.
 
 @param purchased Whether or not the activities have been purchased.
 
 @discussion Overshare distinguishes between "requiring" IAP in general, and "already"
 purchased. This method is used for the "already" purchased state.
 
 @warning In-app purchase states **do not** persist across app launches. It is recommended
 that you perform your own secure purchase validation at launch, then update Overshare's
 purchase states accordingly.
 */
- (void)markActivityTypes:(NSArray *)types asAlreadyPurchased:(BOOL)purchased;

/**
 Checks whether or not the activity type has actually been purchased.
 
 @param type The activity type.
 
 @return Returns `YES` if an activity either a) requires purchase and has been purchased, or b) does not require purchase in general, implying availability.
 */
- (BOOL)activityTypeIsPurchased:(NSString *)type;

@end




