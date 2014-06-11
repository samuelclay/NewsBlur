//
//  OSKPresentationManager.h
//  Overshare
//
//  Created by Jared Sinclair on 10/13/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class OSKActivity;
@class OSKNavigationController;
@class OSKPresentationManager;
@class OSKShareableContent;

#import "OSKPresentationStyle.h"
#import "OSKPresentationColor.h"
#import "OSKPresentationLocalization.h"
#import "OSKPresentationViewControllers.h"
#import "OSKSession.h"

/**
 Refers to an instance of `OSKActivityCompletionHandler` (See OSKActivity.h).
 
 This key is used in the `options` dictionaries of the present... methods
 listed below. The block specified by `OSKPresentationOption_ActivityCompletionHandler` is
 called whenever the selected activity finishes or fails.
 */
extern NSString * const OSKPresentationOption_ActivityCompletionHandler;

/**
 Refers to an instance of `OSKPresentationEndingHandler` (See OSKSession.h).
 
 This key is used in the `options` dictionaries of the present... methods
 listed below. The block specified by `OSKPresentationOption_PresentationEndingHandler` is
 called whenever the OSK UI is dismissed (via cancellation or otherwise)
 */
extern NSString * const OSKPresentationOption_PresentationEndingHandler;

///-----------------------------------------------
/// @name Presentation Manager
///-----------------------------------------------

/**
 The Presentation Manager handle the user-facing layers of Overshare. It is used as a singleton instance.
 */
@interface OSKPresentationManager : NSObject

///-----------------------------------------------
/// @name Properties
///-----------------------------------------------

/**
 Set this delegate to override the default colors.
 */
@property (weak, nonatomic) id <OSKPresentationColor> colorDelegate;

/**
 Set this delegate to override default style info, like light or dark mode.
 */
@property (weak, nonatomic) id <OSKPresentationStyle> styleDelegate;

/**
 Set this delegate to provide localized alternate display text for Overshare's UI strings.
 */
@property (weak, nonatomic) id <OSKPresentationLocalization> localizationDelegate;

/**
 Set this delegate to provide custom view controllers, or respond to view controller changes.
 */
@property (weak, nonatomic) id <OSKPresentationViewControllers> viewControllerDelegate;

///-----------------------------------------------
/// @name Singleton Access
///-----------------------------------------------

/**
 @return returns the singleton instance.
 */
+ (instancetype)sharedInstance;

///-----------------------------------------------
/// @name Presenting Default Activity Sheet
///-----------------------------------------------

/**
 Presents an activity sheet from the presenting view controller. Use this on iPhone.
 
 @param content The content to be shared.
 
 @param presentingViewController Your app's presenting view controller.
 
 @param options A dictionary of options. In addition to the options listed in OSKActivity.h, 
 the accepted keys are `OSKPresentationOption_ActivityCompletionHandler` and 
 `OSKPresentationOption_PresentationEndingHandler`.
 */
- (void)presentActivitySheetForContent:(OSKShareableContent *)content
              presentingViewController:(UIViewController *)presentingViewController
                               options:(NSDictionary *)options;

/**
 Presents an activity sheet in an iPad popover from `rect` in `view`
 
 @param content The content to be shared.
 
 @param presentingViewController Your app's presenting view controller.
 
 @param options A dictionary of options. In addition to the options listed in OSKActivity.h,
 the accepted keys are `OSKPresentationOption_ActivityCompletionHandler` and
 `OSKPresentationOption_PresentationEndingHandler`.
 */
- (void)presentActivitySheetForContent:(OSKShareableContent *)content
              presentingViewController:(UIViewController *)presentingViewController
                       popoverFromRect:(CGRect)rect
                                inView:(UIView *)view
              permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections
                              animated:(BOOL)animated
                               options:(NSDictionary *)options;

/**
 Presents an activity sheet in an iPad popover from `item`.
 
 @param content The content to be shared.
 
 @param presentingViewController Your app's presenting view controller.
 
 @param options A dictionary of options. In addition to the options listed in OSKActivity.h,
 the accepted keys are `OSKPresentationOption_ActivityCompletionHandler` and
 `OSKPresentationOption_PresentationEndingHandler`.
 */
- (void)presentActivitySheetForContent:(OSKShareableContent *)content
              presentingViewController:(UIViewController *)presentingViewController
              popoverFromBarButtonItem:(UIBarButtonItem *)item
              permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections
                              animated:(BOOL)animated
                               options:(NSDictionary *)options;

///---------------------------------------------------
/// @name Skipping the Built-In Activity Sheet
///---------------------------------------------------

/**
 Use this method to skip the activity sheet view controller and proceed straight to the built-in flow 
 through purchasing, authentication, and publishing view controllers.
 
 This method is for applications that wish to present their own activity sheet UI, but still wish
 to use Overshare Kit for all the other view controllers & logic.
 
 @param activity The user's selected activity. It's up to you to create & obtain this activity.
 
 @param presentingViewController The view controller from which OSK will present it's view controllers.
 
 @param options A dictionary of options. The accepted keys are `OSKPresentationOption_ActivityCompletionHandler` 
 and `OSKPresentationOption_PresentationEndingHandler`.
 */
- (void)beginSessionWithSelectedActivity:(OSKActivity *)activity
                presentingViewController:(UIViewController *)presentingViewController
                                 options:(NSDictionary *)options;

@end

///-----------------------------------------------
/// @name Obtaining New View Controllers
///-----------------------------------------------

@interface OSKPresentationManager (ViewControllers)

/**
 @return Returns a new purchasing view controller for `activity`.
 */
- (UIViewController <OSKPurchasingViewController> *)purchasingViewControllerForActivity:(OSKActivity *)activity;

/**
 @return Returns a new authentication view controller for `activity`.
 */
- (UIViewController <OSKAuthenticationViewController> *)authenticationViewControllerForActivity:(OSKActivity *)activity;

/**
 @return Returns a new publishing view controller for `activity`.
 */
- (UIViewController <OSKPublishingViewController> *)publishingViewControllerForActivity:(OSKActivity *)activity;

@end

///-----------------------------------------------
/// @name Style Options
///-----------------------------------------------

@interface OSKPresentationManager (Style)

/**
 The style to be used for Overshare's view controllers. Dark mode FTW!
 
 Returns OSKActivitySheetViewControllerStyle_Light by default.
 
 Override this via the `styleDelegate`.
 */
- (OSKActivitySheetViewControllerStyle)sheetStyle;

/**
 Buttons need borders in order to look tappable.
 
 Returns `YES` by default. :-( 
 
 Override this via the `styleDelegate`.
 */
- (BOOL)toolbarsUseUnjustifiablyBorderlessButtons;

/**
 Returns an alternate icon for a given activity type, or nil (the default is nil).
 
 @param type An `OSKActivity` type.
 
 @param idiom The current user interface idiom.
 
 @return If non-nil, it returns a square, opaque image of size 60x60 points (for iPhone) or 76x76 points (for iPad).
 */
- (UIImage *)alternateIconForActivityType:(NSString *)type idiom:(UIUserInterfaceIdiom)idiom;

/**
 Returning YES (the default OSK setting) will show a link-shortening button when recommended, i.e., when
 the user is editing a microblog post (Twitter, App.net, etc.) and a given URL is longer than a certain
 threshold (around 30 characters or more). Links are shortened via Bit.ly. You can prevent this button from
 appearing via OSKPresentationManager's `styleDelegate`.
 */
- (BOOL)allowLinkShorteningButton;

/**
 OvershareKit will attempt to initialize all normal weight, user-facing fonts based on this alternate font descriptor if one is supplied.
 Otherwise, default system fonts will be used.
 
 @return Returns nil if the `styleDelegate` does not return a non-nil UIFontDescriptor from osk_normalFontDescriptor.
 */
- (UIFontDescriptor *)normalFontDescriptor;

/**
 OvershareKit will attempt to initialize all bold weight, user-facing fonts based on this alternate font descriptor if one is supplied.
 Otherwise, default system fonts will be used.
 
 @return Returns nil if the `styleDelegate` does not return a non-nil UIFontDescriptor from osk_boldFontDescriptor.
 */
- (UIFontDescriptor *)boldFontDescriptor;

/**
 Returns the desired font size to be used in OvershareKit’s text views. You can provide an alternate size
 via the corresponding delegate method of the `styleDelegate`.
 */
- (CGFloat)textViewFontSize;

@end

///-----------------------------------------------
/// @name Colors
///-----------------------------------------------

@interface OSKPresentationManager (Color)

- (UIColor *)color_activitySheetTopLine;
- (UIColor *)color_opaqueBackground;
- (UIColor *)color_translucentBackground;
- (UIColor *)color_toolbarBackground;
- (UIColor *)color_toolbarText;
- (UIColor *)color_toolbarBorders;
- (UIColor *)color_groupedTableViewBackground;
- (UIColor *)color_groupedTableViewCells;
- (UIColor *)color_separators;
- (UIColor *)color_action;
- (UIColor *)color_text;
- (UIColor *)color_textViewBackground;
- (UIColor *)color_pageIndicatorColor_current;
- (UIColor *)color_pageIndicatorColor_other;
- (UIColor *)color_cancelButtonColor_BackgroundHighlighted;
- (UIColor *)color_hashtags;
- (UIColor *)color_mentions;
- (UIColor *)color_links;
- (UIColor *)color_characterCounter_normal;
- (UIColor *)color_characterCounter_warning;

@end

///-----------------------------------------------
/// @name Localization and VoiceOver
///-----------------------------------------------

@interface OSKPresentationManager (LocalizationAndAccessibility)

- (NSString *)localizedText_ActionButtonTitleForPublishingActivity:(NSString *)activityType;
- (NSString *)localizedText_Cancel;
- (NSString *)localizedText_Done;
- (NSString *)localizedText_Okay;
- (NSString *)localizedText_Add;
- (NSString *)localizedText_Username;
- (NSString *)localizedText_Email;
- (NSString *)localizedText_Password;
- (NSString *)localizedText_Accounts;
- (NSString *)localizedText_SignOut;
- (NSString *)localizedText_SignIn;
- (NSString *)localizedText_AreYouSure;
- (NSString *)localizedText_NoAccountsFound;
- (NSString *)localizedText_YouCanSignIntoYourAccountsViaTheSettingsApp;
- (NSString *)localizedText_AccessNotGrantedForSystemAccounts_Title;
- (NSString *)localizedText_AccessNotGrantedForSystemAccounts_Message;
- (NSString *)localizedText_UnableToSignIn;
- (NSString *)localizedText_PleaseDoubleCheckYourUsernameAndPasswordAndTryAgain;
- (NSString *)localizedText_FacebookAudience_Public;
- (NSString *)localizedText_FacebookAudience_Friends;
- (NSString *)localizedText_FacebookAudience_OnlyMe;
- (NSString *)localizedText_FacebookAudience_Audience;
- (NSString *)localizedText_OptionalActivities;
- (NSString *)localizedText_ShortenLinks;
- (NSString *)localizedText_LinksShortened;
- (NSString *)localizedText_Remove;

@end








