//
//  OSKCustomizationsDelegate.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

/**
 This protocol allows you to configure certain non-UI aspects of Overshare activities.
 */
@protocol OSKActivityCustomizations <NSObject>
@optional

/**
 Implementers should return a valid application credential for the given activity type.
 
 @param activityType An activity type.
 
 @return Should return a valid application credential.
 
 @discussion Some activities require application-specific credentials. Since `OSKActivitiesManager`
 cannot create them on its own, these credentials must be vended to it via this method. 
 
 The following built-in services require application credentials:
 
 - Facebook
 - App.net
 - Readability
 - Pocket
 
 The setup documents for Overshare discuss each case in detail.
 
 @see `OSKApplicationCredential`
 @see `OSKActivitiesManager`
 */
- (OSKApplicationCredential *)applicationCredentialForActivityType:(NSString *)activityType;

@end



