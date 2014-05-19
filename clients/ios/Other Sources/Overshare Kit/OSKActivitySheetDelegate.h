//
//  OSKActivitySheetDelegate.h
//  Overshare
//
//  Created by Jared Sinclair on 10/13/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@class OSKActivity;
@class OSKActivitySheetViewController;

@protocol OSKActivitySheetDelegate <NSObject>

- (void)activitySheet:(OSKActivitySheetViewController *)viewController didSelectActivity:(OSKActivity *)activity;
- (void)activitySheetDidCancel:(OSKActivitySheetViewController *)viewController;

@end



