//
//  OSKPurchasingViewController.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class OSKActivity;
@protocol OSKPurchasingViewController;

// DELEGATE PROTOCOL =====================================================================================

@protocol OSKPurchasingViewControllerDelegate <NSObject>

/*
 - (void)purchasingViewController:(UIViewController <OSKPurchasingViewController> *)viewController
         didPurchaseActivityTypes:(NSArray *)activityTypes;
 Call this method after the purchasing view controller has finished a successful In-App Purchase flow.
 This method's activityTypes argument is an NSArray because the IAP may include the purchase of more
 activity types than the one passed into the preparePurchasingViewForActivityType:delegate: method below.
*/
- (void)purchasingViewController:(UIViewController <OSKPurchasingViewController> *)viewController
        didPurchaseActivityTypes:(NSArray *)activityTypes
                    withActivity:(OSKActivity *)activity;

/*
 - (void)purchasingViewControllerDidCancel:(UIViewController <OSKPurchasingViewController> *)viewController;
 Call this method when the purchasing view controller taps cancel without making a purchase.
*/
- (void)purchasingViewControllerDidCancel:(UIViewController <OSKPurchasingViewController> *)viewController
                             withActivity:(OSKActivity *)activity;

@end

// VIEW CONTROLLER PROTOCOL ==============================================================================

@protocol OSKPurchasingViewController <NSObject>

@property (weak, nonatomic) id <OSKPurchasingViewControllerDelegate> purchasingDelegate;
@property (strong, nonatomic) OSKActivity *activity;

- (void)preparePurchasingViewForActivity:(OSKActivity *)activity delegate:(id <OSKPurchasingViewControllerDelegate>)delegate;

@end




