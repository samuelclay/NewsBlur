//
//  OSKXCallbackURLInfo.h
//  Overshare
//
//  Created by Jared on 1/26/14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

@import Foundation;

@class OSKActivity;

///-------------------------------
/// @name X-Callback-URL Schemes
///-------------------------------

/**
 Implementers of this protocol should provide optional x-callback-url info specific 
 to the current application. This info will be passed as query arguments to
 target applications that support the x-callback-url protocol.
 
 @note OvershareKit does *not* handle the processing of x-callback-url callbacks
 if/when the target app relinquishes the user's focus back to the current application.
 If your app provides x-callback-url callbacks, you probably knew this already.
 
 @see http://x-callback-url.com/specifications/
 */
@protocol OSKXCallbackURLInfo <NSObject>

@optional

/**
 Implementers should return a URL-encoded string that will be passed as
 the x-source query value to a target app that supports x-callback-url.
 
 @discussion The friendly name of the source app calling the action. 
 If the action in the target app requires user interface elements, 
 it may be necessary to identify to the user the app requesting the action.
 */
- (NSString *)xCallbackSourceForActivity:(OSKActivity *)activity;

/**
 Implementers should return a URL-encoded string that will be passed as
 the x-success query value to a target app that supports x-callback-url.
 
 @discussion If the action in the target method is intended to return a 
 result to the source app, the x-callback parameter should be included and 
 provide a URL to open to return to the source app. On completion of the action, 
 the target app will open this URL, possibly with additional parameters 
 tacked on to return a result to the source app. If x-success is not provided, 
 it is assumed that the user will stay in the target app on successful 
 completion of the action.
 */
- (NSString *)xCallbackSuccessForActivity:(OSKActivity *)activity;

/**
 Implementers should return a URL-encoded string that will be passed as
 the x-cancel query value to a target app that supports x-callback-url.
 
 @discussion URL to open if the requested action generates an error in 
 the target app. This URL will be open with at least the parameters 
 “errorCode=code&errorMessage=message. If x-error is not present, and an
 error occurs, it is assumed the target app will report the failure to 
 the user and remain in the target app.
 */
- (NSString *)xCallbackCancelForActivity:(OSKActivity *)activity;

/**
 Implementers should return a URL-encoded string that will be passed as
 the x-error query value to a target app that supports x-callback-url.
 
 @discussion URL to open if the requested action is cancelled by the user. 
 In the case where the target app offer the user the option to “cancel” 
 the requested action, without a success or error result, this the the URL 
 that should be opened to return the user to the source app.
 */
- (NSString *)xCallbackErrorForActivity:(OSKActivity *)activity;

@end



