//
//  OSKSessionController.h
//  Overshare
//
//  Created by Jared Sinclair on 10/11/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

#import "OSKActivity.h"

@class OSKSessionController;
@class OSKNavigationController;
@class OSKSession;
@protocol OSKPurchasingViewController;
@protocol OSKAuthenticationViewController;
@protocol OSKPublishingViewController;

@protocol OSKSessionControllerDelegate <NSObject>

- (void)sessionController:(OSKSessionController *)controller
willPresentViewController:(UIViewController *)viewController
     inNavigationController:(OSKNavigationController *)navigationController;

- (void)sessionController:(OSKSessionController *)controller
willPresentSystemViewController:(UIViewController *)systemViewController;

- (void)sessionControllerDidBeginPerformingActivity:(OSKSessionController *)controller
                     hasDismissedAllViewControllers:(BOOL)hasDismissed;

- (void)sessionControllerDidFinish:(OSKSessionController *)controller successful:(BOOL)successful error:(NSError *)error;

- (void)sessionControllerDidCancel:(OSKSessionController *)controller;

@end

@interface OSKSessionController : NSObject

// OSKSessionController should be used via one of its concrete subclasses, OSKSessionController_Phone or OSKSessionController_Pad.

- (instancetype)initWithActivity:(OSKActivity *)activity
                         session:(OSKSession *)session
                        delegate:(id <OSKSessionControllerDelegate>)delegate;

@property (strong, nonatomic, readonly) OSKSession *session;
@property (weak, nonatomic, readonly) id <OSKSessionControllerDelegate> delegate;
@property (strong, nonatomic, readonly) OSKActivity *activity;

- (void)start;

@end

@interface OSKSessionController (RequiredForSubclasses)

- (void)presentViewControllerAppropriately:(UIViewController *)viewController setAsNewRoot:(BOOL)isNewRoot;
- (void)presentSystemViewControllerAppropriately:(UIViewController *)systemViewController;
- (void)dismissViewControllers;

@end





