//
//  OSKPresentationViewControllers.h
//  Overshare
//
//  Created by Jared Sinclair 10/31/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@protocol OSKPurchasingViewController;
@protocol OSKAuthenticationViewController;
@protocol OSKPublishingViewController;

///-----------------------------------------------
/// @name Presentation Delegate Protocol
///-----------------------------------------------

/**
 All methods are optional, with two notable exceptions:
 
 1) If you are using your own custom OSKActivity subclasses,
 you must provide the required view controllers if the built-in view controller are not used.
 
 2) If you have marked an activity as requiring in-app purchase, you must provide a purchasing view controller.
 Overshare does not have any built-in purchasing view controllers.
 */
@protocol OSKPresentationViewControllers <NSObject>
@optional

/**
 Called before presenting an Overshare view controller.
 */
- (void)presentationManager:(OSKPresentationManager *)manager
  willPresentViewController:(UIViewController *)viewController
     inNavigationController:(OSKNavigationController *)navigationController;

/**
 Called before presenting a `systemViewController`, like a MFMailComposeController.
 */
- (void)presentationManager:(OSKPresentationManager *)manager
willPresentSystemViewController:(UIViewController *)systemViewController;

/**
 Analgous to the UIPopoverDelegate method.
 */
- (void)presentationManager:(OSKPresentationManager *)manager
willRepositionPopoverToRect:(inout CGRect *)rect
                     inView:(inout UIView **)view;

/**
 Creates and returns a new purchasing view controller.
 
 @param activity The activity requiring the view controller.
 
 @return A new view controller.
 */
- (UIViewController <OSKPurchasingViewController> *)osk_purchasingViewControllerForActivity:(OSKActivity *)activity;

/**
 Creates and returns a new authentication view controller.
 
 @param activity The activity requiring the view controller.
 
 @return A new view controller.
 */
- (UIViewController <OSKAuthenticationViewController> *)osk_authenticationViewControllerForActivity:(OSKActivity *)activity;

/**
 Creates and returns a new publishing view controller.
 
 @param activity The activity requiring the view controller.
 
 @return A new view controller.
 */
- (UIViewController <OSKPublishingViewController> *)osk_publishingViewControllerForActivity:(OSKActivity *)activity;

@end

