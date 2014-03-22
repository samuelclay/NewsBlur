//
//  OSKSessionController_Phone.h
//  Overshare
//
//  Created by Jared Sinclair on 10/11/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKSessionController.h"

@interface OSKSessionController_Phone : OSKSessionController

@property (strong, nonatomic, readonly) UIViewController *presentingViewController;

- (instancetype)initWithActivity:(OSKActivity *)activity
                         session:(OSKSession *)session
                        delegate:(id <OSKSessionControllerDelegate>)delegate
        presentingViewController:(UIViewController *)presentingViewController;

@end





