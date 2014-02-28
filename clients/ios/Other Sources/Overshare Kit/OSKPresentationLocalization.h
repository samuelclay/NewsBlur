//
//  OSKPresentationLocalization.h
//  Overshare
//
//  Created by Jared Sinclair 10/31/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@class OSKActivity;

///-----------------------------------------------
/// @name Presentation Localization
///-----------------------------------------------

/**
 A protocol for providing alternate localized text for Overshare's UI strings.
 */
@protocol OSKPresentationLocalization <NSObject>
@optional

/**
 Returns a localized default name for a given activity. Useful if you need to localize the names of the built-in
 Overshare activities. Overshare does not localize it's display text automatically.
 
 @param type An `OSKActivity` type.
 
 @return A localized name for the activity.
 */
- (NSString *)osk_localizedDefaultNameForActivityType:(NSString *)type;

- (NSString *)osk_localizedText_ActionButtonTitleForPublishingActivity:(NSString *)activityType;
- (NSString *)osk_localizedText_Cancel;
- (NSString *)osk_localizedText_Done;
- (NSString *)osk_localizedText_Okay;
- (NSString *)osk_localizedText_Add;
- (NSString *)osk_localizedText_Username;
- (NSString *)osk_localizedText_Email;
- (NSString *)osk_localizedText_Password;
- (NSString *)osk_localizedText_SignOut;
- (NSString *)osk_localizedText_SignIn;
- (NSString *)osk_localizedText_AreYouSure;
- (NSString *)osk_localizedText_Accounts;
- (NSString *)osk_localizedText_NoAccountsFound;
- (NSString *)osk_localizedText_YouCanSignIntoYourAccountsViaTheSettingsApp;
- (NSString *)osk_localizedText_AccessNotGrantedForSystemAccounts_Title;
- (NSString *)osk_localizedText_AccessNotGrantedForSystemAccounts_Message;
- (NSString *)osk_localizedText_UnableToSignIn;
- (NSString *)osk_localizedText_PleaseDoubleCheckYourUsernameAndPasswordAndTryAgain;
- (NSString *)osk_localizedText_FacebookAudience_Public;
- (NSString *)osk_localizedText_FacebookAudience_Friends;
- (NSString *)osk_localizedText_FacebookAudience_OnlyMe;
- (NSString *)osk_localizedText_FacebookAudience_Audience;
- (NSString *)osk_localizedText_OptionalActivities;
- (NSString *)osk_localizedText_ShortenLinks;
- (NSString *)osk_localizedText_LinksShortened;
- (NSString *)osk_localizedText_Remove;

@end
