//
//  OSKPresentationManager_Protected.h
//  unread
//
//  Created by Jared Sinclair on 12/5/13.
//  Copyright (c) 2013 Nice Boy LLC. All rights reserved.
//

#import "OSKPresentationManager.h"

@class OSKNavigationController;

@interface OSKPresentationManager ()

- (BOOL)_navigationControllersShouldManageTheirOwnAppearanceCustomization;
- (void)_customizeNavigationControllerAppearance:(OSKNavigationController *)navigationController;

@end
