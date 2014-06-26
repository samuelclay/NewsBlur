//
//  OSKSessionController_Phone.m
//  Overshare
//
//  Created by Jared Sinclair on 10/11/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKSessionController_Phone.h"

#import "OSKActivitySheetViewController.h"
#import "UIViewController+OSKUtilities.h"
#import "OSKNavigationController.h"
#import "OSKPresentationManager.h"
#import "OSKPublishingViewController.h"
#import "OSKPurchasingViewController.h"
#import "OSKAuthenticationViewController.h"

@interface OSKSessionController_Phone ()

@property (strong, nonatomic, readwrite) UIViewController *systemViewController;
@property (strong, nonatomic, readwrite) OSKNavigationController *modalNavigationController;
@property (strong, nonatomic, readwrite) UIViewController *presentingViewController;


@end

@implementation OSKSessionController_Phone

- (instancetype)initWithActivity:(OSKActivity *)activity
                         session:(OSKSession *)session
                        delegate:(id<OSKSessionControllerDelegate>)delegate
        presentingViewController:(UIViewController *)presentingViewController {
    
    self = [super initWithActivity:activity session:session delegate:delegate];
    if (self) {
        _presentingViewController = presentingViewController;
    }
    return self;
}

#pragma mark - Required

- (void)presentViewControllerAppropriately:(UIViewController *)viewController setAsNewRoot:(BOOL)isNewRoot {
    if (self.modalNavigationController == nil && self.systemViewController == nil) {
        self.modalNavigationController = [[OSKNavigationController alloc] initWithRootViewController:viewController];
        UIViewController *parentMost = [UIViewController osk_parentMostViewControllerForPresentingViewController:self.presentingViewController];
        [self.delegate sessionController:self willPresentViewController:viewController inNavigationController:self.modalNavigationController];
        [parentMost presentViewController:self.modalNavigationController animated:YES completion:nil];
    }
    else if (isNewRoot) {
        [self.delegate sessionController:self willPresentViewController:viewController inNavigationController:self.modalNavigationController];
        [self.modalNavigationController setViewControllers:@[viewController] animated:YES];
    }
    else {
        [self.delegate sessionController:self willPresentViewController:viewController inNavigationController:self.modalNavigationController];
        [self.modalNavigationController pushViewController:viewController animated:YES];
    }
}

- (void)presentSystemViewControllerAppropriately:(UIViewController *)systemViewController {
    [self.delegate sessionController:self willPresentSystemViewController:systemViewController];
    if (self.systemViewController == nil) {
        UIViewController *parentMost = [UIViewController osk_parentMostViewControllerForPresentingViewController:self.presentingViewController];
        if (self.modalNavigationController) {
            // This might occur if an app dev elects to make Email or SMS sharing available only via
            // In app purchase. If so, we'd need to dismiss the purchasing view controller (if its visible)
            // before presenting the system navigation controller.
            [self.modalNavigationController dismissViewControllerAnimated:YES completion:^{
                [parentMost presentViewController:systemViewController animated:YES completion:nil];
            }];
        } else {
            [self setSystemViewController:systemViewController];
            [parentMost presentViewController:systemViewController animated:YES completion:nil];
        }
    }
}

- (void)dismissViewControllers {
    if (self.modalNavigationController) {
        __weak OSKSessionController_Phone *weakSelf = self;
        [self.modalNavigationController dismissViewControllerAnimated:YES completion:^{
            [weakSelf setModalNavigationController:nil];
        }];
    }
    if (self.systemViewController) {
        __weak OSKSessionController_Phone *weakSelf = self;
        [self.systemViewController dismissViewControllerAnimated:YES completion:^{
            [weakSelf setSystemViewController:nil];
        }];
    }
}

@end






