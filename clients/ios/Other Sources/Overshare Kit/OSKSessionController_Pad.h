//
//  OSKSessionController_Pad.h
//  Overshare
//
//  Created by Jared Sinclair on 10/11/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKSessionController.h"

@interface OSKSessionController_Pad : OSKSessionController

- (instancetype)initWithActivity:(OSKActivity *)activity
                         session:(OSKSession *)session
                        delegate:(id <OSKSessionControllerDelegate>)delegate
               popoverController:(UIPopoverController *)popoverController
        presentingViewController:(UIViewController *)presentingViewController;

@end
