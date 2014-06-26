//
//  OSKSessionController_Pad.m
//  Overshare
//
//  Created by Jared Sinclair on 10/11/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKSessionController_Pad.h"

#import "OSKNavigationController.h"
#import "OSKPresentationManager.h"

@interface OSKSessionController_Pad ()

@property (weak, nonatomic) UIPopoverController *popoverController;
@property (weak, nonatomic) UIViewController *systemViewController;
@property (weak, nonatomic) UIViewController *presentingViewController;
@property (strong, nonatomic) OSKNavigationController *navigationController;

@end

@implementation OSKSessionController_Pad

- (instancetype)initWithActivity:(OSKActivity *)activity
                         session:(OSKSession *)session
                        delegate:(id<OSKSessionControllerDelegate>)delegate
               popoverController:(UIPopoverController *)popoverController
        presentingViewController:(UIViewController *)presentingViewController {
    
    self = [super initWithActivity:activity session:session delegate:delegate];
    if (self) {
        _popoverController = popoverController;
        _presentingViewController = presentingViewController;
    }
    return self;
}

- (void)presentViewControllerAppropriately:(UIViewController *)viewController setAsNewRoot:(BOOL)isNewRoot {
    if (self.navigationController == nil) {
        self.navigationController = [[OSKNavigationController alloc] initWithRootViewController:viewController];
        [self.navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
        [self.delegate sessionController:self willPresentViewController:viewController inNavigationController:self.navigationController];
        [self.presentingViewController presentViewController:self.navigationController animated:YES completion:nil];
    }
    else if (isNewRoot) {
        [self.delegate sessionController:self willPresentViewController:viewController inNavigationController:self.navigationController];
        [self.navigationController setViewControllers:@[viewController] animated:YES];
    } else {
        [self.delegate sessionController:self willPresentViewController:viewController inNavigationController:self.navigationController];
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

- (void)presentSystemViewControllerAppropriately:(UIViewController *)systemViewController {
    [self.delegate sessionController:self willPresentSystemViewController:systemViewController];
    if (self.systemViewController == nil) {
        [self setSystemViewController:systemViewController];
        if ([systemViewController isKindOfClass:[UIActivityViewController class]] && self.popoverController != nil) {
            [self.popoverController.contentViewController presentViewController:systemViewController animated:YES completion:nil];
        } else {
            [self.presentingViewController presentViewController:systemViewController animated:YES completion:nil];
        }
    }
}

- (void)dismissViewControllers {
    if (self.systemViewController) {
        __weak OSKSessionController_Pad *weakSelf = self;
        [self.systemViewController dismissViewControllerAnimated:YES completion:^{
            [weakSelf setSystemViewController:nil];
        }];
    }
    if (self.navigationController) {
        __weak OSKSessionController_Pad *weakSelf = self;
        [self.navigationController dismissViewControllerAnimated:YES completion:^{
            [weakSelf setNavigationController:nil];
        }];
    }
}

@end
